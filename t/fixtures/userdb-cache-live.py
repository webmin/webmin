#!/usr/bin/env python3
"""Test cached PostgreSQL saves through an isolated MiniServ and real Fast RPC.

Run as root in a disposable Linux VM with PostgreSQL and DBD::Pg installed.
Extract a checkout into task-directory/root, then pass task-directory here.
Use --expect-bug with unmodified master to confirm the original lost writes.
All credentials are generated inside the guest. No installed Webmin files change.
"""
from pathlib import Path
import base64
import http.client
import os
import secrets
import signal
import socket
import subprocess
import sys
import time
from urllib.parse import quote, unquote

assert sys.platform == 'linux' and os.geteuid() == 0, 'Disposable Linux VM required'
task = Path(sys.argv[1]).resolve()
assert task.parent == Path('/tmp') and task.name.startswith('webmin-userdb-cache.'), 'Unexpected task directory'
os.umask(0o077)
root = task / 'root'
expect_bug = '--expect-bug' in sys.argv
name = 'webmin_cache_fixture_' + str(os.getpid())
password = secrets.token_urlsafe(32)
dbpass = secrets.token_hex(24)
process = None
created_role = created_db = False
checks = 0


def check(condition, message):
    """Stop on failure and count successful behavior checks."""
    global checks
    assert condition, message
    checks += 1
    print('PASS ' + message, flush=True)


def sql(query, database=None):
    """Query the fixture through an independent PostgreSQL connection."""
    p = subprocess.run(['runuser', '-u', 'postgres', '--', 'psql', '-X', '-At',
                        '-v', 'ON_ERROR_STOP=1', '-d', database or name],
                       input=query, text=True, capture_output=True, timeout=15, cwd='/tmp')
    if p.returncode:
        raise RuntimeError(p.stderr.replace(dbpass, '[redacted]'))
    return p.stdout.strip()


def write(path, text):
    """Write only fixture files under the task directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def encode(value):
    """Encode scalars and collections in the legacy Webmin RPC data format."""
    if value is None:
        return 'UNDEF'
    if isinstance(value, dict):
        parts = [item for pair in value.items() for item in pair]
        kind = 'HASH'
    elif isinstance(value, list):
        parts, kind = value, 'ARRAY'
    else:
        return 'VAL,' + quote(str(value), safe='')
    return kind + ',' + ','.join(quote(encode(item), safe='') for item in parts)


def decode(value):
    """Decode ordinary scalar, array and hash RPC replies."""
    kind, _, data = value.partition(',')
    if kind == 'UNDEF':
        return None
    if kind == 'VAL':
        return unquote(data)
    parts = [decode(unquote(item)) for item in data.split(',')] if data else []
    return dict(zip(parts[::2], parts[1::2])) if kind == 'HASH' else parts


def request(port):
    """Authenticate locally and obtain a real Fast RPC session."""
    c = http.client.HTTPConnection('127.0.0.1', port, timeout=15)
    try:
        auth = base64.b64encode(('admin:' + password).encode()).decode()
        c.request('GET', '/fastrpc.cgi', headers={'Authorization': 'Basic ' + auth,
                  'User-Agent': 'Webmin userdb fixture', 'Connection': 'close'})
        response = c.getresponse()
        # Connect as soon as the handshake arrives; forked RPC keeps stdout open.
        body = response.readline().decode().split()
        assert response.status == 200 and body[0] == '1', 'Fast RPC login failed'
        return int(body[1]), body[2]
    finally:
        c.close()


def start(fork):
    """Start a private MiniServ with a local RPC admin and a SQL user database."""
    global process
    base = task / ('fork' + str(fork))
    conf, var = base / 'config', base / 'var'
    var.mkdir(parents=True, exist_ok=True)
    hashed = subprocess.check_output(['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$cachefixture$));'],
                                     input=password.encode()).decode()
    write(conf / 'config', 'os_type=generic-linux\nos_version=0\nlang=en\nrpc_timeout=10\n')
    write(conf / 'var-path', str(var) + '\n')
    write(conf / 'users', 'admin:' + hashed + '\n')
    write(conf / 'webmin.acl', 'admin: acl\n')
    write(conf / 'webmin.groups', '')
    write(conf / 'admin.acl', 'rpc=1\n')
    write(conf / 'acl/admin.acl', 'users=*\ngroups=1\nacl=1\nmode=0\n')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    values = dict(port=port, bind='127.0.0.1', ssl=0, root=root,
        userfile=conf/'users', pidfile=var/'miniserv.pid', logfile=var/'requests.log',
        errorlog=var/'errors.log', env_WEBMIN_CONFIG=conf, env_WEBMIN_VAR=var,
        env_PERL5LIB=root, session=0, passdelay=0, no_pam=1, log=1, syslog=0,
        addtype_cgi='internal/cgi', forkcgis=fork, nofork=1, allow='127.0.0.1',
        userdb=f'postgresql://{name}:{dbpass}@127.0.0.1/{name}',
        userdb_cache_timeout=3600, precache='none')
    write(conf/'miniserv.conf', ''.join(f'{k}={v}\n' for k, v in values.items()))
    with (base/'server.log').open('ab') as log:
        process = subprocess.Popen(['perl', str(root/'miniserv.pl'), '--nofork', str(conf/'miniserv.conf')],
            stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
    for _ in range(100):
        assert process.poll() is None, 'MiniServ exited'
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=.2):
                return port
        except OSError:
            time.sleep(.05)
    raise RuntimeError('MiniServ startup timed out')


def stop():
    """Stop only the fixture server and its RPC children."""
    global process
    if process is not None:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
        process = None


# The forked CGI fixture must use the guest's Perl executable.
p = root / 'fastrpc.cgi'
p.write_text('#!/usr/bin/perl\n' + p.read_text().split('\n', 1)[1])
try:
    sql(f"CREATE ROLE {name} LOGIN PASSWORD '{dbpass}'", 'postgres')
    created_role = True
    sql(f'CREATE DATABASE {name} OWNER {name}', 'postgres')
    created_db = True
    schema = f'SET ROLE {name};'
    for kind in ('user', 'group'):
        field = 'pass' if kind == 'user' else 'description'
        schema += f'CREATE TABLE webmin_{kind} (id serial PRIMARY KEY, name text, {field} text);'
        schema += f'CREATE TABLE webmin_{kind}_attr (id int, attr text, value text, PRIMARY KEY(id,attr));'
        schema += f'CREATE TABLE webmin_{kind}_acl (id int, module text, attr text, value text, PRIMARY KEY(id,module,attr));'
        schema += f"INSERT INTO webmin_{kind} (name,{field}) VALUES ('fixture','!');"
    schema += 'CREATE TABLE parent (id int PRIMARY KEY); INSERT INTO parent VALUES (1);'
    schema += 'CREATE TABLE child (id int REFERENCES parent DEFERRABLE INITIALLY DEFERRED);'
    sql(schema)
    for fork in (0, 1):
        port = start(fork)
        rpcport, session = request(port)
        with socket.create_connection(('127.0.0.1', rpcport), timeout=15) as sock:
            stream = sock.makefile('rwb', buffering=0)

            def rpc(action, allow_error=False, **args):
                """Send a call on the same persistent Fast RPC connection."""
                payload = encode(dict(action=action, module='acl', **args)).encode()
                stream.write(f'{len(payload)} {session}\n'.encode() + payload)
                length = int(stream.readline())
                result = bytearray()
                while len(result) < length:
                    part = stream.read(length - len(result))
                    assert part, 'RPC closed before replying'
                    result.extend(part)
                reply = decode(result.decode())
                assert allow_error or reply['status'] == '1', str(reply.get('rv', 'RPC operation failed')).replace(dbpass, '[redacted]').replace(password, '[redacted]')
                return reply if allow_error else reply.get('rv', reply.get('arv'))

            rpc('require', file='acl-lib.pl')
            pidcode = 'my $s = &get_userdb_string(); my $h = &connect_userdb($s); my ($p) = $h->selectrow_array("select pg_backend_pid()"); &disconnect_userdb($s, $h); $p;'
            backend = rpc('eval', code=pidcode)
            for kind in ('user', 'group'):
                writer = 'save_module_acl' if kind == 'user' else 'save_group_module_acl'
                for value in ('first', 'second'):
                    rpc('call', func=writer, args=[{'fixture': value}, 'fixture', '', 1])
                    saved = sql(f"SELECT value FROM webmin_{kind}_acl WHERE attr='fixture'")
                    check(saved == ('' if expect_bug else value),
                          f'forkcgis={fork}: {kind} {value} save ' + ('reproduces invisible write' if expect_bug else 'visible before RPC session closes'))
            check(rpc('eval', code=pidcode) == backend, 'same PostgreSQL connection reused')
            if not expect_bug:
                # A deferred constraint fails at commit, after INSERT succeeds.
                failure = rpc('eval', allow_error=True, code='local $main::error_must_die = 1; my $s = &get_userdb_string(); my $h = &connect_userdb($s); $h->do("insert into child values (2)"); &disconnect_userdb($s, $h); 1;')
                check(failure['status'] == '0' and 'Failed to commit' in failure['rv'], 'commit failure returned through RPC')
                check(sql('SELECT count(*) FROM child') == '0', 'failed transaction was not saved')
                # Webmin treats this as fatal. Inspect cleanup independently.
                check(sql(f'SELECT count(*) FROM pg_stat_activity WHERE pid={int(backend)}') == '0',
                      'failed PostgreSQL connection closed')
            rpc('quit')
            stream.close()
        stop()
        check(sql('SELECT count(*) FROM webmin_user_acl') == ('0' if expect_bug else '1'),
              'session shutdown ' + ('reproduces lost writes' if expect_bug else 'retains committed writes'))
        sql('DELETE FROM webmin_user_acl; DELETE FROM webmin_group_acl;')
finally:
    stop()
    if created_db:
        sql(f'DROP DATABASE {name} WITH (FORCE)', 'postgres')
    if created_role:
        sql(f'DROP ROLE {name}', 'postgres')
print(f'PASS {checks} live checks; database, role and fixture processes removed', flush=True)
