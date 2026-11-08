"""Test API-only restrictions through CGI requests on an isolated Linux VM.

Usage: python3 api-only-failures.py /tmp/webmin-api-task files|mysql|postgresql
Prepare the sandbox with api-only-sandbox.py. For SQL tests, use
api-only-userdb.py to set up and clean up the test database. Run as root in a
disposable guest, never on the workstation.
"""
from pathlib import Path
import http.client
import json
import os
import signal
import subprocess
import sys
import time

# Require root on Linux before reading fixture configuration.
if sys.platform != 'linux' or os.geteuid() != 0:
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
backend = sys.argv[2]
# Only task-specific temporary sandboxes may be modified.
if task.parent != Path('/tmp') or not task.name.startswith('webmin-api-'):
    raise RuntimeError('Use the isolated API test sandbox')
# Load the shared private client and form helpers without running their tests.
exec(compile((task / 'api-only-live.py').read_text().split('\ntry:\n', 1)[0],
             str(task / 'api-only-live.py'), 'exec'))
fixture['parent'] = fixture['group'] + 'parent'
path.write_text(json.dumps(fixture))
root = task / 'root'
conf = task / 'config'
# Keep the original settings for recovery after either fault injection.
original_config = (conf / 'miniserv.conf').read_text()
write_fault = lookup_fault = False


def operate(mode):
    """operate(mode): run a sandbox operation without printing credentials."""
    result = subprocess.run(['perl', str(root / 't/fixtures/api-only-failures.pl'),
                             str(task), mode, str(path)],
                            capture_output=True, text=True, timeout=30)
    if result.returncode:
        # Remove fixture credentials before reporting helper errors.
        raise RuntimeError(redact(result.stdout + result.stderr))
    return result.stdout


def inspect():
    """inspect(): return stored account and group settings."""
    return json.loads(operate('inspect'))


def configure(ipuser=None):
    """configure([ipuser]): map loopback to ipuser.

    Omit ipuser to restore the original server settings.
    """
    content = original_config
    if ipuser:
        # Replace existing mappings so loopback selects only the intended user.
        content = '\n'.join(line for line in content.splitlines()
                            if not line.startswith('ipaccess='))
        content += '\nipaccess=127.0.0.1=' + ipuser + '\n'
    # Reload this sandbox and allow the new mapping to take effect.
    (conf / 'miniserv.conf').write_text(content)
    os.kill(int((task / 'miniserv.pid').read_text()), signal.SIGUSR1)
    time.sleep(.4)


def mapped_request():
    """mapped_request(): request static content using configured IP authentication."""
    client = http.client.HTTPConnection('127.0.0.1', 18443, timeout=15)
    client.request('GET', '/strict-private.txt')
    response = client.getresponse()
    result = response.status, response.read().decode(errors='replace')
    client.close()
    return result


def external_cgi(who, allowed=False):
    """external_cgi(who, [allowed]): run a CGI without MiniServ identity fields.

    who selects a fixture user. allowed defaults to False. Set it to True to
    run the API-only endpoint. CGIs run directly as Perl subprocesses.
    """
    # Remove MiniServ hints so init_config must resolve the account's backend.
    env = {key: value for key, value in os.environ.items()
           if key not in ('REMOTE_USER_PROTO', 'BASE_REMOTE_USER', 'MINISERV_CONFIG')}
    script = root / ('strict-api.cgi' if allowed else 'strict-plain.cgi')
    env.update(WEBMIN_CONFIG=str(conf), WEBMIN_VAR=str(task / 'var'),
               REMOTE_USER=fixture[who], REQUEST_METHOD='GET',
               SCRIPT_FILENAME=str(script), SCRIPT_NAME='/' + script.name,
               SERVER_ROOT=str(root), SERVER_NAME='localhost', SERVER_PORT='18445',
               SERVER_SOFTWARE='Apache', GATEWAY_INTERFACE='CGI/1.1')
    # Capture the real CGI initialization result without exposing credentials.
    return subprocess.run(['perl', str(script)], cwd=root, env=env,
                          capture_output=True, text=True, timeout=30)


try:
    # Create fixture accounts, an API-only endpoint and an ordinary CGI.
    helper('setup')
    operate('parent')
    for name, optin in [('strict-api.cgi', "$main::allow_api_only='strict-api.cgi';"),
                        ('strict-plain.cgi', '')]:
        script = root / name
        script.write_text('#!/usr/bin/perl\nuse lib ' + repr(str(root)) + ';\n' +
                          optin + 'use WebminCore; &init_config(); ' +
                          'print "Content-type: text/plain\\n\\nSTRICT_OK\\n";\n')
        script.chmod(0o755)
    (root / 'strict-private.txt').write_text('STRICT_PRIVATE')
    # Use the real editor forms when submitting later account and group changes.
    userform = 'acl/edit_user.cgi?user=' + fixture['user']
    groupform = 'acl/edit_group.cgi?group=' + fixture['group']

    # Creating a grouped account must retain its explicitly requested endpoint.
    fields = dict(name=fixture['clone'], pass_def='0',
                  mod='acl', group=fixture['group'], rpc='1',
                  api_only_def='0', api_only='strict-api.cgi')
    fields['pass'] = fixture['user_password']
    edit('acl/edit_user.cgi', 'save_user.cgi', fields)
    current = inspect()['clone']
    check(current['api_only'] == 'strict-api.cgi' and not current['locked'] and
          not current['deny'], backend + ': grouped new account activates with endpoint')
    status, body = request('strict-api.cgi', who='user', username=fixture['clone'])
    check(status == 200 and 'STRICT_OK' in body, backend + ': new endpoint works', body)
    status, body = request('index.cgi', who='user', username=fixture['clone'])
    check(status == 403, backend + ': grouped new account cannot open UI', body)

    # Assign a restricted parent while submitting an old, unrestricted form.
    edit(userform, 'save_user.cgi', {'api_only_def': '1'})
    edit(userform, 'save_user.cgi', {'group': fixture['group']})
    edit(groupform, 'save_group.cgi', {'group': fixture['parent'], 'api_only_def': '1'})
    current = inspect()
    check(current['group']['api_only'] == 'strict-api.cgi' and
          current['user']['api_only'] == 'strict-api.cgi',
          backend + ': reparenting restricts group and existing member')
    status, body = request('strict-api.cgi', who='user')
    check(status == 200 and 'STRICT_OK' in body, backend + ': inherited endpoint works', body)
    status, body = request('index.cgi', who='user')
    check(status == 403, backend + ': inherited restriction blocks UI', body)

    # Rejected global permissions cannot partially rename or detach the group.
    before = inspect()
    edit(groupform, 'save_group.cgi', {'name': fixture['group'] + 'renamed',
         'desc': 'Should not save', 'group': '', 'api_only_def': '0', 'api_only': '../rpc.cgi'})
    after = inspect()
    check(before == after, backend + ': invalid endpoint causes no account or group changes')

    # Exercise init_config in a CGI process with only the external host's user.
    result = external_cgi('user')
    check('STRICT_OK' not in result.stdout and '403 Forbidden' in result.stdout,
          backend + ': external CGI denies restricted account without backend hint', result.stdout)
    result = external_cgi('user', True)
    check(result.returncode == 0 and 'STRICT_OK' in result.stdout,
          backend + ': external CGI permits opted-in endpoint', result.stdout + result.stderr)
    result = external_cgi('admin')
    check(result.returncode == 0 and 'STRICT_OK' in result.stdout,
          backend + ': ordinary external CGI account still works', result.stdout + result.stderr)

    if backend == 'files':
        # An ACL path that is a directory must block CGI initialization.
        policy = conf / (fixture['user'] + '.acl')
        saved = policy.read_bytes()
        policy.unlink()
        policy.mkdir()
        try:
            result = external_cgi('user', True)
            check(result.returncode != 0 and 'STRICT_OK' not in result.stdout,
                  'files: unreadable policy blocks API endpoint initialization')
        finally:
            # Restore the policy file before fixture cleanup reads it again.
            policy.rmdir()
            policy.write_bytes(saved)
    else:
        # Use a database trigger to fail the new account's policy write.
        operate('fail-write')
        write_fault = True
        fields.update(name=fixture['renamed'], group='')
        edit('acl/edit_user.cgi', 'save_user.cgi', fields)
        current = inspect()['renamed']
        # PostgreSQL may roll back the whole transaction. Otherwise the
        # partially saved account must retain both password and IP locks.
        check(not current['exists'] or (current['locked'] and
              current['deny'] == '0.0.0.0/0 ::/0' and not current['api_only']),
              backend + ': failed ACL write never leaves an enabled account')
        # Check both password and configured IP login against the partial user.
        status, body = request('strict-private.txt', who='user', username=fixture['renamed'])
        check(status != 200 and 'STRICT_PRIVATE' not in body,
              backend + ': failed new account password cannot retrieve content')
        configure(fixture['renamed'])
        status, body = mapped_request()
        check(status == 403 and 'STRICT_PRIVATE' not in body,
              backend + ': failed new account cannot use IP authentication')
        # Recover before injecting an independent account-lookup failure.
        configure()
        operate('restore-write')
        write_fault = False

        # User lookup failure must not grant IP-authenticated static access.
        configure(fixture['user'])
        operate('fail-lookup')
        lookup_fault = True
        status, body = mapped_request()
        check(status == 403 and 'STRICT_PRIVATE' not in body,
              backend + ': failed identity query denies IP-authenticated static access')
        result = external_cgi('user', True)
        check('STRICT_OK' not in result.stdout,
              backend + ': external CGI also rejects failed identity lookup')
        operate('restore-lookup')
        lookup_fault = False
        configure()
    print('All API failure regression checks passed for ' + backend, flush=True)
finally:
    if lookup_fault:
        # Restore the account table before cleanup tries to find fixture users.
        operate('restore-lookup')
    if write_fault:
        # Remove any remaining trigger so cleanup can update ACL storage.
        operate('restore-write')
    # Restore login settings and remove private fixture files and accounts.
    configure()
    operate('cleanup-parent')
    helper('cleanup')
    path.unlink(missing_ok=True)
    for name in ('strict-api.cgi', 'strict-plain.cgi', 'strict-private.txt'):
        (root / name).unlink(missing_ok=True)
