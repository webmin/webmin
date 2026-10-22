"""Run only on a disposable Linux Webmin VM, as root, never on the workstation.

Upload this script, mysql-import-account.pl and patch.tar.gz to a fresh task
directory. The archive must contain mysql/import.cgi, mysql/mysql-lib.pl and
mysql/lang/en. Installed files and settings are restored even on test failure.
Pass --shared-temp to isolate permissions from a service's PrivateTmp setting;
this temporarily moves Webmin's MySQL temp files outside /tmp and /var/tmp.
Use --secure-temp for MySQL's secure_file_priv directory. If that directory
only permits the daemon and root, use --root-client to skip non-root clients.
Pass --loopback to point the module at 127.0.0.1 over TCP for the run, which
must still be treated as a local server.
"""
import hashlib
import html
import http.cookiejar
import json
import os
import pathlib
import re
import secrets
import shlex
import shutil
import signal
import ssl
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.parse
import urllib.request

assert sys.platform == 'linux' and os.getuid() == 0, 'Disposable Linux VM required'
os.umask(0o077)
base = pathlib.Path(__file__).resolve().parent
base.chmod(0o711)


def config(path):
    """Read a Webmin key=value configuration file without printing secrets."""
    return dict(line.split('=', 1) for line in pathlib.Path(path).read_text().splitlines() if '=' in line)


miniserv = config('/etc/webmin/miniserv.conf')
root = pathlib.Path(miniserv['root'])
dbconfig = config('/etc/webmin/mysql/config')
assert dbconfig.get('host', '') in ('', 'localhost'), 'Local socket connection required'
db = 'csvtest_' + secrets.token_hex(4)
state = dict(user=db, password=secrets.token_urlsafe(32), db=db, buser='root', directory=str(base))
statefile = base / 'state.json'
saved = {}
checks = 0
created_account = created_unix = False
original_local = original_mode = None
shared_temp = None
root_client = '--root-client' in sys.argv[1:]
url = 'https://127.0.0.1:' + miniserv.get('port', '10000')
cookies = http.cookiejar.CookieJar()
http = urllib.request.build_opener(
    urllib.request.HTTPSHandler(context=ssl._create_unverified_context()),
    urllib.request.HTTPCookieProcessor(cookies))


def run(command, **kwargs):
    """Run a checked guest command with a timeout and captured output."""
    return subprocess.run(command, check=True, capture_output=True, text=True, timeout=60, **kwargs)


def sql(statement):
    """Execute fixture SQL using the guest's existing database credentials."""
    # The installed credentials stay in guest memory and child environment only.
    childenv = dict(os.environ, MYSQL_PWD=dbconfig.get('pass', ''))
    command = shlex.split(dbconfig['mysql']) + ['--batch', '--raw', '--skip-column-names',
                                               '--user=' + dbconfig.get('login', 'root')]
    for key, option in (('host', 'host'), ('port', 'port'), ('sock', 'socket')):
        if dbconfig.get(key):
            command.append('--' + option + '=' + dbconfig[key])
    result = subprocess.run(command, input=statement, env=childenv, text=True,
                            capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError('Fixture SQL failed: ' + result.stderr)
    return result.stdout.rstrip('\n')


def check(condition, message):
    """Count a successful assertion or stop the test with its explanation."""
    global checks
    assert condition, message
    checks += 1
    print('PASS ' + message, flush=True)


def snapshot(path):
    """Save a file and its checksum before changing the installed setup."""
    path = pathlib.Path(path)
    if path not in saved:
        dest = base / ('original-' + str(len(saved)))
        if path.exists():
            shutil.copy2(path, dest)
            saved[path] = (dest, hashlib.sha256(path.read_bytes()).hexdigest())
        else:
            saved[path] = (None, None)


def account(action):
    """Create, update or remove the fixture's loopback-only Webmin account."""
    statefile.write_text(json.dumps(state))
    run(['perl', str(base / 'mysql-import-account.pl'), str(root), str(statefile), action])


def request(path, fields=None, upload=None):
    """Send an authenticated request, optionally with form fields and an upload."""
    headers = {'Referer': url + '/mysql/', 'Origin': url}
    data = None
    if fields is not None and path.startswith('/mysql/'):
        boundary = 'CSV' + secrets.token_hex(12)
        parts = [f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
                 for k, v in fields.items()]
        if upload is not None:
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="upload"; filename="items.csv"\r\nContent-Type: text/csv\r\n\r\n'.encode() + upload + b'\r\n')
        parts.append(f'--{boundary}--\r\n'.encode())
        data = b''.join(parts)
        headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary
    elif fields is not None:
        data = urllib.parse.urlencode(fields).encode()
    with http.open(urllib.request.Request(url + path, data=data, headers=headers), timeout=60) as reply:
        return html.unescape(reply.read().decode('utf-8', 'replace'))


def import_csv(mode, content, format=1, delete=0, ignore=0):
    """Import through the CGI and check file permissions and cleanup."""
    source = base / 'source.csv'
    source.write_bytes(content)
    before = source.stat()
    body = request('/mysql/import.cgi', dict(db=db, table='items', mode=mode,
                   file=str(source), format=format, delete=delete, ignore=ignore), content if mode else None)
    (base / 'last-response.html').write_text(body)
    observation = re.search(r'CSV_OBSERVATION (\{[^\n]+\})', body)
    if not observation:
        (base / 'failed-response.html').write_text(body)
        raise AssertionError('Import did not reach the real client; see guest failed-response.html')
    observation = json.loads(observation.group(1))
    if observation['mode'] != 0o640:
        (base / 'failed-response.html').write_text(body)
    check(observation['mode'] == 0o640, 'temporary CSV is not world-readable')
    check(observation['gid'] == daemon_gid, 'temporary CSV belongs to the running daemon group')
    check(observation['client_readable'], 'configured import-command user can still read the CSV')
    if observation['other_readable'] is not None:
        check(not observation['other_readable'], 'unrelated Unix user cannot read the temporary CSV')
    check(not pathlib.Path(observation['path']).exists(), 'temporary CSV removed after import')
    staging = pathlib.Path(observation['path']).parent
    check(staging.name.startswith('#sql-webmin-import-'), 'CSV uses a per-import server-visible directory')
    # The CGI removes its directory on exit, just after finishing the response.
    deadline = time.monotonic() + 2
    while staging.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    check(not staging.exists(), 'temporary import directory removed after the request')
    after = source.stat()
    check((before.st_uid, before.st_gid, before.st_mode) == (after.st_uid, after.st_gid, after.st_mode),
          'source permissions and ownership unchanged')
    return body


try:
    print('Database: ' + sql('SELECT VERSION()'), flush=True)
    original_local, original_mode = sql('SELECT @@GLOBAL.local_infile, @@GLOBAL.sql_mode').split('\t')
    pidfile = sql('SELECT @@pid_file')
    pid = pathlib.Path(pidfile).read_text().strip()
    daemon_gid = int(run(['ps', '-o', 'egid=', '-p', pid]).stdout.strip())
    print('secure_file_priv: ' + repr(sql('SELECT @@secure_file_priv')), flush=True)
    for item in ('miniserv.conf', 'miniserv.users', 'webmin.acl', 'mysql/config', 'mysql/version', 'config'):
        snapshot('/etc/webmin/' + item)
    if '--loopback' in sys.argv[1:]:
        # A TCP loopback address is still the local server and must stage files the same way.
        module_config = pathlib.Path('/etc/webmin/mysql/config')
        text = re.sub(r'^host=.*\n?', '', module_config.read_text(), flags=re.M)
        module_config.write_text(text + 'host=127.0.0.1\n')
        print('TEST OVERRIDE: module connects to 127.0.0.1 over TCP', flush=True)
    if '--shared-temp' in sys.argv[1:] or '--secure-temp' in sys.argv[1:]:
        # Use a permitted location without disabling the server's restrictions.
        parent = sql('SELECT @@secure_file_priv') if '--secure-temp' in sys.argv[1:] else '/var/cache'
        assert pathlib.Path(parent).is_absolute() and pathlib.Path(parent).is_dir()
        shared_temp = pathlib.Path(tempfile.mkdtemp(prefix='webmin-csv-', dir=parent))
        shared_temp.chmod(0o711)
        global_config = pathlib.Path('/etc/webmin/config')
        text = re.sub(r'^tempdir_mysql=.*\n?', '', global_config.read_text(), flags=re.M)
        global_config.write_text(text + '\ntempdir_mysql=' + str(shared_temp / '.webmin') + '\n')
        print('TEST OVERRIDE: temporary import location under ' + parent, flush=True)
    with tarfile.open(base / 'patch.tar.gz') as archive:
        for member in archive.getmembers():
            assert member.isfile() and member.name in ('mysql/import.cgi', 'mysql/mysql-lib.pl', 'mysql/lang/en')
            target = root / member.name
            snapshot(target)
            target.write_bytes(archive.extractfile(member).read())
    # Observe the real file at the client boundary, without logging credentials.
    wrapper = base / 'import-client.py'
    wrapper.write_text('#!/usr/bin/python3\nimport json, os, subprocess, sys\n'
        'path = sys.argv[-1]\ns = os.stat(path)\n'
        'other = subprocess.run(["runuser", "-u", "nobody", "--", "test", "-r", path], '
        'capture_output=True).returncode == 0 if os.getuid() == 0 else None\n'
        'print("CSV_OBSERVATION " + json.dumps(dict(path=path, mode=s.st_mode & 0o777, '
        'gid=s.st_gid, client_readable=os.access(path, os.R_OK), other_readable=other)), flush=True)\n'
        'sys.exit(subprocess.call(' + repr(shlex.split(dbconfig['mysqlimport'])) + ' + sys.argv[1:]))\n')
    wrapper.chmod(0o755)
    module_config = pathlib.Path('/etc/webmin/mysql/config')
    original_text = module_config.read_text()

    def set_client(local=False):
        """Observe the native import client, optionally enabling explicit LOCAL."""
        text = re.sub(r'^mysqlimport=.*$', 'mysqlimport=' + str(wrapper) + (' --local' if local else ''),
                      original_text, flags=re.M)
        module_config.write_text(text)

    set_client()
    run(['useradd', '--no-create-home', '--user-group', '--shell', '/bin/sh', db])
    created_unix = True
    # Do not depend on root's socket-authentication plugin for non-root clients.
    sql(f"CREATE USER '{db}'@'localhost' IDENTIFIED BY '{state['password']}'; "
        f'CREATE DATABASE `{db}`; CREATE TABLE `{db}`.items (id INT PRIMARY KEY, note VARCHAR(40)) ENGINE=InnoDB; '
        f"GRANT ALL ON `{db}`.* TO '{db}'@'localhost'; GRANT FILE ON *.* TO '{db}'@'localhost'")
    # Oracle's mysqlimport sets character_set_database, a restricted variable.
    if 'SESSION_VARIABLES_ADMIN' in sql('SHOW PRIVILEGES').upper():
        sql(f"GRANT SESSION_VARIABLES_ADMIN ON *.* TO '{db}'@'localhost'")
    created_account = True
    account('create')
    request('/session_login.cgi')
    request('/session_login.cgi', {'user': state['user'], 'pass': state['password'], 'page': '/mysql/'})
    check(any(c.name == 'sid' and c.value not in ('', 'x') for c in cookies), 'authenticated Webmin session')
    sql("SET GLOBAL local_infile=0; SET GLOBAL sql_mode='STRICT_ALL_TABLES'")
    for mode in (0, 1):
        for format, content in ((0, b'1,"quoted,value"\n'), (1, b'1,plain\n'), (2, b'1\ttabbed\n')):
            import_csv(mode, content, format=format, delete=1)
            expected = 'quoted,value' if format == 0 else 'plain' if format == 1 else 'tabbed'
            check(sql(f'SELECT note FROM `{db}`.items WHERE id=1') == expected,
                  f'CSV source {mode}, format {format} imports with local_infile OFF')
    body = import_csv(1, b'not_an_integer,invalid\n')
    check(re.search(r'\berror\b', body, re.I) and sql(f'SELECT COUNT(*) FROM `{db}`.items') == '1',
          'strict validation rejects invalid input without adding rows')
    body = import_csv(1, b'1,duplicate\n')
    check(re.search(r'\berror\b', body, re.I) and sql(f'SELECT note FROM `{db}`.items WHERE id=1') == 'tabbed',
          'duplicates fail without ignore and existing data stays unchanged')
    import_csv(1, b'1,duplicate\n2,new\n', ignore=1)
    check(sql(f'SELECT GROUP_CONCAT(id ORDER BY id) FROM `{db}`.items') == '1,2',
          'explicit ignore skips duplicates and imports new rows')
    if not root_client:
        # Also exercise a client that does not run as the Webmin daemon user.
        state['buser'] = db
        account('update')
        import_csv(0, b'3,nonroot\n')
        check(sql(f'SELECT note FROM `{db}`.items WHERE id=3') == 'nonroot', 'non-root import-command user works')
    check(sql('SELECT @@GLOBAL.local_infile') == '0', 'imports never enabled local_infile')
    sql('SET GLOBAL local_infile=1')
    set_client(local=True)
    import_csv(1, b'4,explicit_local\n')
    check(sql(f'SELECT note FROM `{db}`.items WHERE id=4') == 'explicit_local',
          'an explicitly configured LOCAL client still works')
    set_client()
    sql(f"SET GLOBAL local_infile=0; REVOKE FILE ON *.* FROM '{db}'@'localhost'")
    body = import_csv(1, b'5,no_file_privilege\n')
    check(re.search(r'\berror\b', body, re.I) and sql(f'SELECT COUNT(*) FROM `{db}`.items WHERE id=5') == '0',
          'server-side imports still require the database FILE privilege')
finally:
    sql(f'DROP DATABASE IF EXISTS `{db}`')
    sql(f"DROP USER IF EXISTS '{db}'@'localhost'")
    if original_local is not None:
        sql('SET GLOBAL local_infile=' + original_local)
        sql("SET GLOBAL sql_mode='" + original_mode.replace("'", "''") + "'")
    if created_account:
        account('delete')
    for target, (original, checksum) in saved.items():
        if original:
            shutil.copy2(original, target)
            assert hashlib.sha256(target.read_bytes()).hexdigest() == checksum
        else:
            target.unlink(missing_ok=True)
    os.kill(int(pathlib.Path(miniserv['pidfile']).read_text()), signal.SIGUSR1)
    if created_unix:
        # su/PAM can leave a user-manager process after the client exits.
        subprocess.run(['loginctl', 'terminate-user', db], capture_output=True, timeout=30)
        time.sleep(2)
        run(['userdel', db])
    statefile.unlink(missing_ok=True)
    if shared_temp:
        shutil.rmtree(shared_temp)
    print('Restored installed files, configuration and database settings; removed fixture users and database', flush=True)
print(f'ALL {checks} LIVE CHECKS PASSED', flush=True)
