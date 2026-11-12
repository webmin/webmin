"""Test MiniServ after DAV removal on a disposable Linux guest.

Usage: python3 t/fixtures/miniserv-no-dav.py /tmp/task-directory
Uses this checkout's MiniServ with temporary accounts and loopback listeners.
Old DAV settings must not expose the separate DAV root or change authentication.
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
import tempfile
import time
import urllib.parse

# Reject workstation runs before starting a server or creating credentials.
if sys.platform != 'linux':
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
os.umask(0o077)


def request(port, method, path, headers=None, body=None):
    """request(port, method, path, [headers], [body]): return an HTTP response."""
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
    try:
        connection.request(method, path, body, headers or {})
        response = connection.getresponse()
        return response.status, dict(response.getheaders()), response.read()
    finally:
        connection.close()


def check(condition, message):
    """check(condition, message): stop on failure and print successful checks."""
    if not condition:
        raise AssertionError(message)
    print('PASS: ' + message, flush=True)


# Generate the password only in the guest and never print it.
username = 'dav_removal_fixture'
password = secrets.token_urlsafe(32)
password_hash = subprocess.check_output(
    ['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$davremoval$));'],
    input=password.encode()).decode()
check(password_hash.startswith('$6$'), 'fixture password is hashed')
basic = {'Authorization': 'Basic ' + base64.b64encode(
    f'{username}:{password}'.encode()).decode()}

for session in (0, 1):
    # Keep the old DAV root separate from the ordinary document root.
    with tempfile.TemporaryDirectory(prefix='no-dav-', dir=task) as directory:
        work = Path(directory)
        root = work / 'root'
        (root / 'dav').mkdir(parents=True)
        old_root = work / 'old-dav-root'
        old_root.mkdir()
        (old_root / 'secret.txt').write_text('private DAV content')
        (root / 'dav/public.txt').write_text('ordinary document root')
        (root / 'dav/echo.cgi').write_text(
            '#!/usr/bin/perl\nprint "Content-type: text/plain\\n\\n";\n'
            'print "$ENV{REMOTE_USER}:$ENV{REQUEST_METHOD}";\n')
        (root / 'session_login.cgi').write_text(
            '#!/usr/bin/perl\nprint "Content-type: text/plain\\n\\nlogin form";\n')
        for cgi in root.rglob('*.cgi'):
            cgi.chmod(0o700)
        (work / 'users').write_text(f'{username}:{password_hash}\n')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        config = dict(port=port, bind='127.0.0.1', root=root, ssl=0,
                      pidfile=work/'pid', logfile=work/'requests.log',
                      errorlog=work/'errors.log', userfile=work/'users',
                      session=session, sessiondb=work/'sessions', passdelay=0,
                      no_pam=1, log=0, syslog=0, forkcgis=1,
                      addtype_cgi='internal/cgi', agents_nosession='^fixture-never$',
                      davpaths='/dav', dav_root=old_root, dav_users=username,
                      dav_remoteuser=0, dav_nolock=1)
        conf = work / 'miniserv.conf'
        conf.write_text(''.join(f'{key}={value}\n' for key, value in config.items()))
        with (work / 'stderr.log').open('wb') as stderr:
            server = subprocess.Popen(
                ['perl', str(source/'miniserv.pl'), '--nofork', str(conf)],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=stderr, start_new_session=True)
            try:
                # Wait for the fixture listener, with a bounded startup deadline.
                for attempt in range(100):
                    if server.poll() is not None:
                        raise RuntimeError('Fixture server stopped during startup')
                    try:
                        request(port, 'GET', '/dav/public.txt')
                        break
                    except OSError:
                        time.sleep(.05)
                else:
                    raise RuntimeError('Fixture server did not become ready')

                status, headers, body = request(port, 'GET', '/dav/public.txt')
                check(body != b'ordinary document root', 'anonymous access denied')
                auth = basic
                if session:
                    # Old DAV paths must no longer enable Basic auth in session mode.
                    status, headers, body = request(port, 'GET', '/dav/echo.cgi', basic)
                    check(body == b'login form', 'old DAV path respects session authentication')
                    status, headers, body = request(
                        port, 'POST', '/session_login.cgi',
                        {'Content-Type': 'application/x-www-form-urlencoded',
                         'Cookie': 'testing=1'},
                        urllib.parse.urlencode({'user': username, 'pass': password}))
                    check(status == 302 and 'Set-Cookie' in headers, 'session login works')
                    auth = {'Cookie': headers['Set-Cookie'].split(';', 1)[0]}

                status, headers, body = request(port, 'GET', '/dav/public.txt', auth)
                check(status == 200 and body == b'ordinary document root',
                      f'session={session}: GET uses the document root, not dav_root')
                check('DAV' not in headers, 'ordinary response has no DAV capabilities')
                for method in ('GET', 'POST'):
                    status, headers, body = request(port, method, '/dav/echo.cgi', auth)
                    check(status == 200 and body == f'{username}:{method}'.encode(),
                          f'authenticated CGI {method} works')
                for method in ('GET', 'OPTIONS', 'PROPFIND', 'PROPPATCH', 'MKCOL',
                               'DELETE', 'COPY', 'MOVE', 'LOCK', 'UNLOCK', 'PUT', 'SEARCH'):
                    status, headers, body = request(port, method, '/dav/secret.txt', auth)
                    expected = 400 if method in ('PUT', 'SEARCH') else 404
                    check(status == expected and b'private DAV content' not in body,
                          f'{method} cannot access the old DAV root')
                check((old_root/'secret.txt').read_text() == 'private DAV content'
                      and sorted(p.name for p in old_root.iterdir()) == ['secret.txt'],
                      'old DAV root is unchanged')
            finally:
                # Stop only the fixture's process group, including request children.
                try:
                    os.killpg(server.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(server.pid, signal.SIGKILL)
                    server.wait(timeout=5)

print('DAV removal checks passed; fixture servers and files removed.')
