"""Test fast RPC between two isolated Webmin instances on a Linux guest.

Usage: python3 api-only-cluster.py SOURCE-SANDBOX DESTINATION-SANDBOX
Use local account files and start both instances without fixture users.
Sandbox directories must be directly under /tmp with names starting webmin-api-.
The source must listen on loopback port 18443 and the destination on port 18444.
Run as root in a disposable guest, never on the workstation.
"""
from pathlib import Path
import json
import os
import signal
import shutil
import subprocess
import sys

# Require root on Linux before reading either sandbox's configuration.
if sys.platform != 'linux' or os.geteuid() != 0:
    raise RuntimeError('Run only inside a disposable Linux test guest')
source, destination = map(lambda value: Path(value).resolve(), sys.argv[1:3])
for directory in (source, destination):
    # Both instances must live in task-specific guest temporary directories.
    if directory.parent != Path('/tmp') or not directory.name.startswith('webmin-api-'):
        raise RuntimeError('Use isolated API test sandboxes')
task = source
# Load the shared credentials and HTTP helpers without running their tests.
exec(compile((source / 'api-only-live.py').read_text().split('\ntry:\n', 1)[0],
             str(source / 'api-only-live.py'), 'exec'))
fixture['server_id'] = str(os.getpid()) + '901'
path.write_text(json.dumps(fixture))
source_acl = source / 'config' / (fixture['user'] + '.acl')
target_acl = destination / 'config' / (fixture['user'] + '.acl')
cache = source / 'config/cluster-webmin/hosts' / fixture['server_id'] / (fixture['user'] + '.user')


def operate(directory, mode):
    """operate(directory, mode): run the sandbox helper and return its output."""
    result = subprocess.run(['perl', str(source / 'root/t/fixtures/api-only-cluster.pl'),
                             str(directory), mode, str(path)],
                            capture_output=True, text=True, timeout=30)
    if result.returncode:
        # Report helper failures after removing fixture credentials.
        raise RuntimeError(redact(result.stdout + result.stderr))
    return result.stdout


def sync(dry_run=False):
    """sync([dry_run]): submit sync.cgi, previewing only when dry_run is true."""
    return request('cluster-webmin/sync.cgi',
                   {'server': fixture['server_id'], 'users_mode': '2',
                    'usel': fixture['user'], 'groups_mode': '0',
                    'test': '1' if dry_run else '0'})


def inspect():
    """inspect(): retrieve only the destination account's non-secret state."""
    return json.loads(operate(destination, 'inspect'))


try:
    # The sandbox registry must contain only the chosen loopback destination.
    for entry in (source / 'config/servers').glob('*.serv'):
        entry.unlink()
    shutil.rmtree(source / 'config/cluster-webmin/hosts', ignore_errors=True)
    helper('setup')
    operate(destination, 'destination')
    operate(source, 'source')
    # The transferred policy must authorize a real endpoint on the destination.
    script = destination / 'root/cluster-api.cgi'
    script.write_text('#!/usr/bin/perl\nuse lib ' + repr(str(destination / 'root')) +
        ";\n$main::allow_api_only='cluster-api.cgi'; use WebminCore; &init_config(); " +
        'print "Content-type: text/plain\\n\\nCLUSTER_OK\\n";\n')
    script.chmod(0o755)
    # Preview must not create the copied user or its cache entry.
    status, body = sync(True)
    check(not inspect()['exists'] and not cache.exists(), 'cluster dry run creates no user or cache entry', body)

    # A source read failure must stop the copy before enabling the new account.
    policy = source_acl.read_bytes()
    source_acl.unlink()
    source_acl.mkdir()
    try:
        status, body = sync()
        current = inspect()
        check(not current['exists'] and not cache.exists(),
              'source ACL read failure leaves no account or cache entry', body)
        check('Cannot read API policy file' in body, 'source read error is reported', body)
    finally:
        source_acl.rmdir()
        source_acl.write_bytes(policy)

    # A directory at the ACL path forces a write failure at the destination.
    target_acl.mkdir()
    try:
        status, body = sync()
        current = inspect()
        check(not current['exists'] and not cache.exists(),
              'destination ACL write failure leaves no account or cache entry', body)
    finally:
        if target_acl.is_dir():
            # Remove the directory so the next write can succeed.
            target_acl.rmdir()

    # After storage recovery, repeating the same operation succeeds.
    status, body = sync()
    current = inspect()
    check(current['exists'] and current['api_only'] == 'cluster-api.cgi' and
          not current['locked'] and not current['deny'] and cache.exists(),
          'retry activates and caches account only after complete ACL transfer', body)
    base = 'http://127.0.0.1:18444/'
    status, body = request('cluster-api.cgi', who='user')
    check(status == 200 and 'CLUSTER_OK' in body, 'synchronized endpoint accepts original credentials', body)
    status, body = request('index.cgi', who='user')
    check(status == 403, 'synchronized account cannot open UI', body)

    # Accounts without an API-only restriction must still allow UI access.
    base = 'http://127.0.0.1:18443/'
    operate(destination, 'delete-copy')
    operate(source, 'ordinary-source')
    status, body = sync()
    current = inspect()
    check(current['exists'] and not current['api_only'] and not current['locked'] and
          not current['deny'] and cache.exists(), 'ordinary account synchronizes normally', body)
    base = 'http://127.0.0.1:18444/'
    status, body = request('index.cgi', who='user')
    check(status == 200, 'ordinary synchronized account can open UI', body)
    print('All live cluster checks passed', flush=True)
finally:
    base = 'http://127.0.0.1:18443/'
    if source_acl.is_dir():
        # Remove any leftover directory used to force a read failure.
        source_acl.rmdir()
    if target_acl.is_dir():
        # Remove the directory used to force a write failure.
        target_acl.rmdir()
    # Remove the copied user, source fixtures and temporary endpoint.
    operate(destination, 'delete-copy')
    helper('cleanup')
    path.unlink(missing_ok=True)
    (destination / 'root/cluster-api.cgi').unlink(missing_ok=True)
