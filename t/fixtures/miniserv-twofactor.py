"""Test OTP verification with isolated login servers on a disposable Linux VM.

Usage: python3 t/fixtures/miniserv-twofactor.py /tmp/task-directory
Requires an installed Webmin at /usr/share/webmin. Uses this checkout's server
and verifies that the installed TOTP algorithm matches this checkout. Installed
accounts and configuration are left unchanged. Never run on the workstation.
"""
from pathlib import Path
import base64
import hashlib
import hmac
import http.client
import os
import re
import secrets
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse

# Reject workstation runs before creating files or starting servers.
if sys.platform != 'linux':
    raise RuntimeError('Run only on the disposable Linux guest')
# Keep temporary credentials private.
os.umask(0o077)
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    # Confine fixture files and cleanup to a temporary work directory.
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
installed = Path('/usr/share/webmin')

def otp(secret):
    """otp(secret): generate the current six-digit TOTP independently of Webmin."""
    digest = hmac.new(secret, struct.pack('>Q', int(time.time()) // 30), hashlib.sha1).digest()
    offset = digest[-1] & 15
    number = struct.unpack('>I', digest[offset:offset+4])[0] & 0x7fffffff
    return f'{number % 1000000:06d}'

def request(port, path, fields=None, cookie=None):
    """request(port, path, [fields], [cookie]): send HTTP without redirects.

    Fields select a form POST; omitting them sends a GET. An omitted cookie
    uses the testing cookie required by the login page.
    """
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=15)
    headers = {'Cookie': cookie or 'testing=1', 'Connection': 'close'}
    body = None
    if fields is not None:
        # Encode login fields as the server's form handler expects.
        body = urllib.parse.urlencode(fields)
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    # Keep redirects visible so a login response cannot hide a rejection.
    try:
        connection.request('POST' if fields is not None else 'GET', path, body, headers)
        response = connection.getresponse()
        return response.status, response.getheaders(), response.read()
    finally:
        # Release the socket even if the request fails.
        connection.close()

def check(condition, message):
    """check(condition, message): report success or stop the fixture on failure."""
    if not condition:
        # Stop at the first failed check while allowing fixture cleanup.
        raise AssertionError(message)
    print('PASS: ' + message, flush=True)

# Use the real installed helper only when its TOTP algorithm matches the source.
pattern = r'^sub validate_twofactor_totp\n\{\n.*?^\}'
source_validator = re.search(pattern, (source/'webmin/twofactor-funcs-lib.pl').read_text(), re.M|re.S).group()
installed_validator = re.search(pattern, (installed/'webmin/twofactor-funcs-lib.pl').read_text(), re.M|re.S).group()
check(source_validator == installed_validator, 'installed TOTP validator matches the source')

# Keep credentials inside the guest and outside command-line arguments.
password = secrets.token_urlsafe(32)
secret = secrets.token_bytes(10)
encoded_secret = base64.b32encode(secret).decode()
password_hash = subprocess.check_output(
    ['perl', '-e', 'local $/; my $p = <STDIN>; print crypt($p, q($6$fixturetotp$));'],
    input=password.encode()).decode()
check(password_hash.startswith('$6$'), 'guest created a disposable password hash')

# Give each scenario its own account file, sessions, logs, and server process.
for scenario in ('healthy', 'not-enrolled', 'crash', 'syntax', 'dependency', 'missing', 'empty', 'invalid-provider'):
    with tempfile.TemporaryDirectory(prefix=f'totp-{scenario}-', dir=task) as directory:
        work = Path(directory)
        (work/'acl').mkdir()
        username = 'totp_review_fixture'
        row = [''] * 14
        row[0:2] = [username, password_hash]
        if scenario != 'not-enrolled':
            # Enroll the fixture account except in the configuration control.
            row[11:14] = ['totp', encoded_secret, '']
        if scenario == 'invalid-provider':
            # Exercise the real helper's response to an unknown provider.
            row[11] = 'unavailable_provider'
        (work/'users').write_text(':'.join(row)+'\n')

        # Replace the helper only for scenarios that need a specific failure.
        wrapper = installed/'acl/twofactor.pl'
        if scenario == 'crash':
            # Fail after the helper has loaded successfully.
            wrapper = work/'acl/failure.pl'
            wrapper.write_text('die "OTP fixture runtime failure\\n";\n')
        elif scenario == 'syntax':
            # Reject a helper that Perl cannot compile.
            wrapper = work/'acl/syntax.pl'
            wrapper.write_text('my $broken = ;\n')
        elif scenario == 'dependency':
            # Fail while loading a required module.
            wrapper = work/'acl/dependency.pl'
            wrapper.write_text('require "missing-otp-fixture-module.pm";\n')
        elif scenario == 'missing':
            # Leave the configured helper path absent.
            wrapper = work/'acl/missing.pl'
        elif scenario == 'empty':
            # A helper with no validation code must not authorize a login.
            wrapper = work/'acl/empty.pl'
            wrapper.write_text('')

        # Listen only on guest loopback and keep server state in the task folder.
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        config = dict(port=port, bind='127.0.0.1', root=installed, ssl=0,
                      pidfile=work/'pid', logfile=work/'requests.log',
                      errorlog=work/'errors.log', session=1,
                      session_login='/session_login.cgi',
                      sessiondb=work/'sessions', userfile=work/'users',
                      passdelay=0, log=0, syslog=0, no_pam=1,
                      addtype_cgi='internal/cgi', forkcgis=1,
                      internalcgis=0, twofactor_provider='totp',
                      twofactor_wrapper=wrapper,
                      env_WEBMIN_CONFIG='/etc/webmin',
                      env_WEBMIN_VAR='/var/webmin', cookiepath='/',
                      restartflag=work/'restart', reloadflag=work/'reload',
                      stopflag=work/'stop', logout_script='', login_script='')
        conf = work/'miniserv.conf'
        conf.write_text(''.join(f'{key}={value}\n' for key, value in config.items()))
        # Use a separate process group so cleanup also reaches child processes.
        with (work/'stderr.log').open('wb') as stderr:
            server = subprocess.Popen(['perl', str(source/'miniserv.pl'), '--nofork', str(conf)],
                                      stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                      stderr=stderr, start_new_session=True)
            try:
                # Allow a short startup delay, but stop if the server exits.
                for attempt in range(100):
                    if server.poll() is not None:
                        # Report startup failure before attempting a login.
                        raise RuntimeError('Fixture server exited')
                    try:
                        with socket.create_connection(('127.0.0.1', port), timeout=.2):
                            break
                    except OSError:
                        # Retry while the guest's listener is still starting.
                        time.sleep(.05)
                else:
                    # Bound startup time when the process never opens its port.
                    raise RuntimeError('Fixture server did not start')
                # Check access before login so a public resource cannot mask a failure.
                _, _, anonymous_body = request(port, '/version')
                check(anonymous_body.strip() != (installed/'version').read_bytes().strip(),
                      f'{scenario}: protected resource requires a session')
                if scenario == 'healthy':
                    # Cover valid tokens, invalid tokens, and a wrong password.
                    cases = [('11111', password, False), ('654321', password, False),
                             ('alphabetic', password, False), ('', password, False),
                             ('valid', password, True), ('11111', 'incorrect-password', False)]
                elif scenario == 'not-enrolled':
                    # Global 2FA settings alone must not enroll an account.
                    cases = [('11111', password, True)]
                else:
                    # Broken helpers must not grant access with valid passwords.
                    cases = [('11111', password, False), ('', password, False),
                             ('11111', 'incorrect-password', False)]

                # Check both the login response and any session it creates.
                for token, pass_value, expected in cases:
                    supplied_token = otp(secret) if token == 'valid' else token
                    if token == '654321' and supplied_token == otp(secret):
                        # Avoid using the current valid token as a rejection case.
                        supplied_token = '654322'
                    status, headers, body = request(port, '/session_login.cgi',
                        {'user': username, 'pass': pass_value, 'twofactor': supplied_token, 'page': '/version'})
                    sid = next((value.split(';', 1)[0] for key, value in headers
                                if key.lower() == 'set-cookie' and value.startswith('sid=')), None)
                    accepted = status == 302 and bool(sid)
                    label = f'{scenario}: token={token or "empty"}, password={"correct" if pass_value == password else "wrong"}'
                    check(accepted == expected, label + f', login={"accepted" if accepted else "rejected"}, HTTP={status}')
                    if accepted:
                        # Confirm the cookie grants access, not just a redirect.
                        protected_status, _, protected_body = request(port, '/version', cookie=sid)
                        check(protected_status == 200 and protected_body.strip() == (installed/'version').read_bytes().strip(),
                              f'{scenario}: issued session accesses protected resource')
                if scenario in ('crash', 'syntax', 'dependency', 'missing', 'empty', 'invalid-provider'):
                    # Verify that rejection came with the expected helper error.
                    errors = (work/'errors.log').read_text() if (work/'errors.log').exists() else ''
                    expected_error = {
                        'crash': 'OTP fixture runtime failure',
                        'syntax': 'syntax error',
                        'dependency': "Can't locate missing-otp-fixture-module.pm",
                        'missing': 'No exit status',
                        'empty': 'No exit status',
                        'invalid-provider': 'Unknown twofactor provider',
                    }[scenario]
                    check('Perl failure' in errors and expected_error in errors,
                          f'{scenario}: expected helper failure recorded in error log')
            except Exception:
                # Redact fixture credentials and session IDs in failure logs.
                for log in ('stderr.log', 'errors.log'):
                    if (work/log).exists():
                        # Startup failures may leave only one of these logs.
                        text = (work/log).read_text(errors='replace')[-2500:]
                        for value in (password, password_hash, encoded_secret):
                            text = text.replace(value, '<redacted>')
                        text = re.sub(r'(?i)(sid=|session\s+)[0-9a-f]+', r'\1<redacted>', text)
                        print(log + ': ' + text, flush=True)
                raise
            finally:
                # Stop the server group before removing its temporary files.
                try:
                    os.killpg(server.pid, signal.SIGTERM)
                except ProcessLookupError:
                    # The group may already have exited after a startup failure.
                    pass
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    # Force cleanup if the server ignores graceful termination.
                    os.killpg(server.pid, signal.SIGKILL)
                    server.wait(timeout=5)
print('Finished. All fixture processes, credentials, and configurations removed.', flush=True)
