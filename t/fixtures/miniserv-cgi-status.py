"""Test CGI responses and request logs on a disposable Linux guest.

Usage: python3 t/fixtures/miniserv-cgi-status.py /tmp/task-directory
The source tree containing this fixture supplies miniserv.pl and miniserv-lib.pl.
Each CGI mode gets a separate loopback server and temporary configuration.
No Webmin account or installed configuration is used. Never run locally.
"""
from pathlib import Path
import http.client
import os
import re
import socket
import subprocess
import sys
import tempfile
import time

if sys.platform != 'linux':
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
os.umask(0o077)


def request(port, name):
    """request(port, name): return status, headers and body without redirects."""
    conn = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
    try:
        conn.request('GET', '/' + name)
        response = conn.getresponse()
        return response.status, response.getheaders(), response.read().decode()
    finally:
        conn.close()


def check(condition, message):
    """check(condition, message): report a result or stop on failure."""
    if not condition:
        raise AssertionError(message)
    print('PASS: ' + message, flush=True)


# Cases cover defaults, explicit errors, redirects, malformed headers and exit.
cases = [
    ('normal', '', 200, False),
    ('denied', 'Status: 403 Forbidden\r\n', 403, False),
    ('created', 'Status: 201 Created\r\n', 201, False),
    ('redirect', 'Location: /next\r\n', 302, False),
    ('redirect307', 'Status: 307 Temporary Redirect\r\nLocation: /next\r\n', 307, False),
    ('invalid', 'Status: invalid\r\nLocation: /next\r\n', 302, False),
    ('badcode', 'Status: 999 Invalid\r\n', 200, False),
    ('mixedcase', 'sTaTuS: 410 Gone\r\n', 410, False),
    ('deniedexit', 'Status: 403 Forbidden\r\n', 403, True),
    ('redirectexit', 'Status: 307 Temporary Redirect\r\nLocation: /next\r\n', 307, True),
    ('invalidexit', 'Status: invalid\r\nLocation: /next\r\n', 302, True),
]
for fork in (0, 1):
    # Own every test file and process; cleanup also runs on assertion failures.
    with tempfile.TemporaryDirectory(prefix='cgi-status-', dir=task) as directory:
        work = Path(directory)
        root = work / 'root'
        root.mkdir()
        for name, headers, expected, exits in cases:
            cgi = root / (name + '.cgi')
            response = headers + 'Content-type: text/plain\r\n\r\n'
            literal = response.replace('\\', '\\\\').replace('"', '\\"').replace('\r', '\\r').replace('\n', '\\n')
            cgi.write_text('#!/usr/bin/perl\nprint "' + literal + '";\n'
                           'print $miniserv::doing_cgi_eval ? "internal" : "forked";\n'
                           + ('exit(0);\n' if exits else ''))
            cgi.chmod(0o700)
        # Ask the guest for an available port instead of touching an existing server.
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        config = dict(port=port, bind='127.0.0.1', root=root, ssl=0,
                      pidfile=work/'miniserv.pid', logfile=work/'requests.log',
                      errorlog=work/'errors.log', session=0, passdelay=0,
                      log=1, logclear=0, syslog=0, addtype_cgi='internal/cgi',
                      unauthcgi='^/', forkcgis=fork, internalcgis=0)
        conf = work / 'miniserv.conf'
        conf.write_text(''.join(f'{key}={value}\n' for key, value in config.items()))
        server = subprocess.Popen(['perl', str(source/'miniserv.pl'), '--nofork', str(conf)],
                                  stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
        try:
            # Wait for a real HTTP response before testing, with a bounded deadline.
            for attempt in range(100):
                if server.poll() is not None:
                    raise RuntimeError('Fixture server stopped during startup')
                try:
                    if request(port, 'normal.cgi')[0] == 200:
                        break
                except OSError:
                    pass
                time.sleep(.05)
            else:
                raise RuntimeError('Fixture server did not become ready')
            for name, headers, expected, exits in cases:
                status, received, body = request(port, name + '.cgi')
                label = f'forkcgis={fork} {name}'
                check(status == expected, f'{label}: HTTP {status}, expected {expected}')
                check(not any(key.lower() == 'status' for key, value in received),
                      label + ': control header is not forwarded')
                if name == 'normal':
                    # Prove both execution modes were used, rather than trusting config.
                    check(body == ('forked' if fork else 'internal'), label + ': execution mode')
                # Logging can finish just after the response socket closes.
                pattern = rf'"GET /{name}\.cgi HTTP/1\.[01]"\s+(\d+)\b'
                for attempt in range(100):
                    matches = re.findall(pattern, (work/'requests.log').read_text())
                    if matches:
                        break
                    time.sleep(.02)
                check(bool(matches) and int(matches[-1]) == expected,
                      label + ': request log has the response status')
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                # Kill only the test process if it does not honor termination.
                server.kill()
                server.wait(timeout=5)
print('All CGI status and logging checks passed; fixture servers removed.')
