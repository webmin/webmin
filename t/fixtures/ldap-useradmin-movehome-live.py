"""Check that LDAP Users enforces the move-home permission on a Linux VM.

Usage: python3 t/fixtures/ldap-useradmin-movehome-live.py /tmp/task-directory
Requires slapd, ldap-utils and Net::LDAP. Starts private loopback LDAP and
MiniServ instances, with credentials and test data confined to the fixture.
"""
from html.parser import HTMLParser
from pathlib import Path
import base64
import http.client
import os
import secrets
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.parse

if sys.platform != 'linux' or os.geteuid() != 0:
    raise RuntimeError('Run as root inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
os.umask(0o077)
checks = 0
processes = []
base = 'dc=fixture,dc=test'
userbase = 'ou=users,' + base
groupbase = 'ou=groups,' + base


def check(condition, message):
    """check(condition, message): stop on failure and report each success."""
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1
    print('PASS: ' + message, flush=True)


def config(path, values):
    """config(path, values): write private fixture configuration."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(''.join(f'{key}={value}\n' for key, value in values.items()))


def free_port():
    """free_port(): reserve an available loopback port for a test server."""
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def ldap(command, data='', args=()):
    """ldap(command, [data], [args]): run a fixture LDAP client without prompts."""
    result = subprocess.run([command, '-x', '-H', ldap_url, '-D', 'cn=admin,' + base,
                             '-y', str(secret_file), *args], input=data.encode(),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
    if result.returncode:
        raise RuntimeError(command + ': ' + result.stderr.decode())
    return result.stdout.decode()


def record(dn, attrs):
    """record(dn, attrs): encode LDAP values without interpreting their contents."""
    lines = ['dn: ' + dn]
    for key, values in attrs.items():
        for value in values if isinstance(values, list) else [values]:
            lines.append(key + ':: ' + base64.b64encode(str(value).encode()).decode())
    return '\n'.join(lines) + '\n\n'


def add_user(name, home):
    """add_user(name, home): add an isolated LDAP account."""
    ldap('ldapadd', record('uid=' + name + ',' + userbase, dict(
        objectClass=['account', 'posixAccount', 'shadowAccount'], uid=name,
        cn=name, uidNumber=63001, gidNumber=63001, homeDirectory=home,
        loginShell='/bin/sh', userPassword='{crypt}*')))


def user_home(name):
    """user_home(name): return the stored home or None when the user is absent."""
    result = ldap('ldapsearch', args=('-LLL', '-o', 'ldif-wrap=no', '-b', userbase,
                                     '(uid=' + name + ')', 'homeDirectory'))
    for line in result.splitlines():
        if line.startswith('homeDirectory:: '):
            return base64.b64decode(line.split(' ', 1)[1]).decode()
        if line.startswith('homeDirectory: '):
            return line.split(' ', 1)[1]
    return None


def acl(**overrides):
    """acl([overrides]): reset the delegated account's permissions for a case."""
    values = dict(line.split('=', 1) for line in
                  (source/'ldap-useradmin/defaultacl').read_text().splitlines() if '=' in line)
    values.update(home=homes, batch=1, noconfig=1)
    values.update(overrides)
    config(conf/'ldap-useradmin/delegate.acl', values)


def request(page, form=None, module='ldap-useradmin'):
    """request(page, [form], [module]): issue an authenticated request to private Webmin."""
    connection = http.client.HTTPConnection('127.0.0.1', web_port, timeout=30)
    headers = dict(Authorization=authorization,
                   Referer=f'http://127.0.0.1:{web_port}/{module}/')
    body = None
    if form is not None:
        body = urllib.parse.urlencode(form)
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    try:
        connection.request('POST' if form is not None else 'GET',
                           f'/{module}/{page}', body, headers)
        response = connection.getresponse()
        return response.status, response.read().decode(errors='replace')
    finally:
        connection.close()


def save(name, home, **overrides):
    """save(name, home, [overrides]): submit the single-user save handler."""
    form = dict(dn='uid=' + name + ',' + userbase, user=name, real=name,
                uid=63001, gid=63001, gidmode=0, home=home, shell='/bin/sh',
                passmode=4, movehome=1, chuid=0, chgid=0, others=0,
                samba=0, cyrus=0, sgid='')
    form.update(overrides)
    return request('save_user.cgi', form)


def batch(name, home, **overrides):
    """batch(name, home, [overrides]): submit one batch modify row."""
    row = ['modify', name, '', '', '', '', '', str(home), '', '', '', '', '', '']
    form = dict(source=2, text=':'.join(row), movehome=1, makehome=0, copy=0,
                delhome=0, others=0, chuid=0, chgid=0)
    form.update(overrides)
    # GET uses the same handler while avoiding multipart upload encoding.
    return request('batch_exec.cgi?' + urllib.parse.urlencode(form))


class Inputs(HTMLParser):
    """Collect input names and selected values to check what a form offers."""

    def __init__(self):
        """Inputs(): initialize the collected field names and selections."""
        super().__init__()
        self.names = set()
        self.checked = {}

    def handle_starttag(self, tag, attrs):
        """handle_starttag(tag, attrs): retain names and checked values."""
        if tag in ('input', 'select', 'textarea'):
            attrs = dict(attrs)
            self.names.add(attrs.get('name'))
            if 'checked' in attrs:
                self.checked[attrs.get('name')] = attrs.get('value')


def stop_servers():
    """stop_servers(): stop only processes started by this fixture."""
    for process in reversed(processes):
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)


with tempfile.TemporaryDirectory(prefix='ldap-live-', dir=task) as directory:
    work = Path(directory)
    conf, var, homes = work/'config', work/'var', work/'homes'
    for path in (conf, var/'locks', homes, work/'db'):
        path.mkdir(parents=True)
    secret_file = work/'ldap-password'
    secret_file.write_text(secrets.token_urlsafe(32))
    ldap_port, web_port = free_port(), free_port()
    ldap_url = f'ldap://127.0.0.1:{ldap_port}'
    slapd_config = work/'slapd.conf'
    slapd_config.write_text(''.join(f'include /etc/ldap/schema/{name}.schema\n'
                                  for name in ('core', 'cosine', 'nis')) +
        f'pidfile {work}/slapd.pid\nargsfile {work}/slapd.args\n'
        'modulepath /usr/lib/ldap\nmoduleload back_mdb\ndatabase mdb\n'
        f'maxsize 1073741824\nsuffix "{base}"\nrootdn "cn=admin,{base}"\n'
        f'rootpw {secret_file.read_text()}\ndirectory {work}/db\n'
        'access to * by dn.exact="cn=admin,' + base + '" manage by * read\n')
    try:
        # Both services and all credentials belong to this temporary fixture.
        with (work/'slapd.log').open('w') as log:
            processes.append(subprocess.Popen(['/usr/sbin/slapd', '-f', str(slapd_config),
                '-h', ldap_url, '-d', '0'], stdout=log, stderr=log, start_new_session=True))
        for attempt in range(100):
            try:
                ldap('ldapsearch', args=('-LLL', '-b', '', '-s', 'base', 'namingContexts'))
                break
            except RuntimeError:
                time.sleep(0.1)
        else:
            raise RuntimeError('Private LDAP server did not start')
        ldap('ldapadd', record(base, dict(objectClass=['top', 'domain'], dc='fixture')) +
             record(userbase, dict(objectClass='organizationalUnit', ou='users')) +
             record(groupbase, dict(objectClass='organizationalUnit', ou='groups')) +
             record('cn=fixture,' + groupbase, dict(objectClass='posixGroup',
                                                   cn='fixture', gidNumber=63001)))
        config(conf/'config', dict(os_type='generic-linux', os_version=0, lang='en',
               log=0, noselfwebminup=1, webprefix='', tempdir=var/'tmp'))
        (conf/'var-path').write_text(str(var) + '\n')
        password = secrets.token_urlsafe(32)
        hashed = subprocess.check_output(['perl', '-e',
            'local $/; print crypt(<STDIN>, q($6$ldapfixture$));'], input=password.encode()).decode()
        authorization = 'Basic ' + base64.b64encode(f'delegate:{password}'.encode()).decode()
        (conf/'miniserv.users').write_text(f'delegate:{hashed}:0\n')
        (conf/'webmin.acl').write_text('delegate: ldap-useradmin acl\n')
        config(conf/'miniserv.conf', dict(port=web_port, bind='127.0.0.1', root=source,
            ssl=0, pidfile=var/'pid', logfile=var/'requests', errorlog=var/'errors',
            userfile=conf/'miniserv.users', env_WEBMIN_CONFIG=conf, env_WEBMIN_VAR=var,
            session=0, passdelay=0, no_pam=1, syslog=0, log=0, forkcgis=0,
            addtype_cgi='internal/cgi', allow='127.0.0.1', precache='none'))
        user_config = dict(line.split('=', 1) for line in
            (source/'useradmin/config-generic-linux').read_text().splitlines() if '=' in line)
        for name in ('passwd', 'shadow', 'group', 'gshadow'):
            path = work/name
            path.write_text('')
            user_config[name + '_file'] = path
        user_config.update(user_files='', default_other=0, home_base=homes,
                           base_uid=63001, base_gid=63001, home_style=0, md5=0)
        config(conf/'useradmin/config', user_config)
        nss = work/'ldap-nss.conf'
        nss.write_text('base ' + base + '\n')
        config(conf/'ldap-client/config', dict(auth_ldap=nss))
        values = dict(line.split('=', 1) for line in
                      (source/'ldap-useradmin/config').read_text().splitlines() if '=' in line)
        values.update(ldap_host='127.0.0.1', ldap_port=ldap_port, ldap_tls=0,
                      login='cn=admin,' + base, ldap_pass_file=secret_file,
                      user_base=userbase, group_base=groupbase, person=0,
                      other_class='account', gecos=0,
                      secmode=1, shells='fixed', delete_only=0, default_other=0)
        config(conf/'ldap-useradmin/config', values)
        acl()
        processes.append(subprocess.Popen(['perl', str(source/'miniserv.pl'), '--nofork',
            str(conf/'miniserv.conf')], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True))
        for attempt in range(100):
            try:
                status, body = request('index.cgi')
                break
            except (OSError, http.client.HTTPException):
                time.sleep(0.1)
        else:
            raise RuntimeError('Private Webmin server did not start')
        check(status == 200 and 'LDAP Users' in body, 'private Webmin and LDAP start')

        # Forced-off, selectable and forced-on moves in both handlers. An empty
        # value is what older ACL editors stored, so it must still allow a choice.
        cases = ((2, 1, False), (1, 0, False), (1, 1, True), (0, 0, True),
                 ('', 0, False), ('', 1, True))
        for mode, submitted, moves in cases:
            label = 'empty' if mode == '' else str(mode)
            for handler in ('single', 'batch'):
                name = f'move{handler}{label}{submitted}'
                old, new = homes/name, homes/(name + " new'\" $literal")
                old.mkdir()
                (old/'kept').write_text('fixture')
                add_user(name, old)
                acl(movehome=mode)
                if handler == 'single':
                    save(name, new, movehome=submitted)
                else:
                    batch(name, new, movehome=submitted)
                check(user_home(name) == str(new), handler + ': home attribute updates')
                check(new.is_dir() == moves and old.is_dir() != moves,
                      f'{handler}: movehome={label} enforces submitted value {submitted}')
                check(((new if moves else old)/'kept').read_text() == 'fixture',
                      handler + ': move preserves file contents and special characters')

        # Forms must offer the choice only when the ACL allows one.
        for mode in (0, 1, 2, ''):
            label = 'empty' if mode == '' else str(mode)
            acl(movehome=mode)
            for page in ('edit_user.cgi?' + urllib.parse.urlencode(dict(
                         dn='uid=movesingle21,' + userbase)), 'batch_form.cgi'):
                status, body = request(page)
                inputs = Inputs()
                inputs.feed(body)
                check(status == 200 and ('movehome' in inputs.names) == (mode in (1, '')),
                      f'{page.split("?")[0]}: movehome={label} controls the offered choice')

        # The ACL editor must offer the setting and treat an empty value as a choice.
        for mode in (0, 1, 2, ''):
            label = 'empty' if mode == '' else str(mode)
            acl(movehome=mode)
            status, body = request('edit_acl.cgi?' + urllib.parse.urlencode(dict(
                                   user='delegate', mod='ldap-useradmin')), module='acl')
            inputs = Inputs()
            inputs.feed(body)
            expected = '1' if mode == '' else str(mode)
            check(status == 200 and inputs.checked.get('movehome') == expected,
                  f'edit_acl.cgi: stored movehome={label} selects {expected}')
        print(f'PASS: {checks} live LDAP/Webmin checks', flush=True)
    finally:
        stop_servers()
