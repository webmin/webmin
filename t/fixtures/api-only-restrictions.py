"""Test API-only subgroup editing and restrictions on open fast RPC sessions.

Usage: python3 api-only-restrictions.py /tmp/webmin-api-task files|mysql|postgresql
Run only as root in a disposable Linux guest. Include api-only-failures.pl
under t/fixtures/ in candidate.tar before running api-only-sandbox.py.
For SQL tests, also set up the test database with api-only-userdb.py.
"""
from pathlib import Path
import os
import socket
import subprocess
import sys
import urllib.parse

if sys.platform != 'linux' or os.geteuid() != 0:
    # Require a Linux root session for this guest-only fixture.
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
backend = sys.argv[2]
if task.parent != Path('/tmp') or not task.name.startswith('webmin-api-'):
    # Keep fixture writes and cleanup inside an isolated task directory.
    raise RuntimeError('Use an isolated API test sandbox')
# Reuse the fixture credentials, form parser and HTTP client.
exec(compile((task / 'api-only-live.py').read_text().split('\ntry:\n', 1)[0],
             str(task / 'api-only-live.py'), 'exec'))
# Share the extra parent group's name with the Perl setup and cleanup helper.
fixture['parent'] = fixture['group'] + '_parent'
path.write_text(json.dumps(fixture))
rpc_socket = None


def operate(mode):
    """operate(mode): run a named helper operation and return its stdout."""
    result = subprocess.run(['perl', str(task / 'root/t/fixtures/api-only-failures.pl'),
                             str(task), mode, str(path)], capture_output=True,
                            text=True, timeout=30)
    if result.returncode:
        # Remove fixture credentials before reporting a helper failure.
        raise RuntimeError(redact(result.stdout + result.stderr))
    return result.stdout


def serialize(value):
    """serialize(value): encode scalars and dictionaries for Webmin RPC."""
    if isinstance(value, dict):
        # Hash entries use alternating encoded keys and values.
        fields = [part for pair in value.items() for part in pair]
        return 'HASH,' + ','.join(urllib.parse.quote(serialize(part), safe='') for part in fields)
    # Scalar values travel as escaped strings.
    return 'VAL,' + urllib.parse.quote(str(value), safe='')


def deserialize(value):
    """deserialize(value): decode scalar and hash responses from the fixture RPC."""
    kind, _, data = value.partition(',')
    if kind == 'VAL':
        # Scalar replies contain one escaped string.
        return urllib.parse.unquote(data)
    if kind == 'HASH':
        # Pair the decoded keys and values back into a dictionary.
        fields = [deserialize(urllib.parse.unquote(part)) for part in data.split(',')]
        return dict(zip(fields[::2], fields[1::2]))
    raise RuntimeError('Unexpected fixture RPC response type')


def command(stream, sid, value):
    """command(stream, sid, value): send a command dict with a session ID.

    Read the reply from the binary stream. Return None if the peer closes.
    """
    wire = serialize(value).encode()
    try:
        # Frame the command with its byte count and established session ID.
        rpc_socket.sendall(str(len(wire)).encode() + b' ' + sid.encode() + b'\n' + wire)
        length = stream.readline()
        if not length:
            # EOF means the server closed the connection.
            return None
        return deserialize(stream.read(int(length)).decode())
    except (ConnectionResetError, BrokenPipeError):
        # The server can close before the queued command reaches it.
        return None


try:
    # Create the endpoint used by the subgroup and RPC restrictions.
    helper('setup')
    root = task / 'root'
    (root / 'strict-api.cgi').write_text('#!/usr/bin/perl\nuse lib ' + repr(str(root)) +
        ";\n$main::allow_api_only='strict-api.cgi'; use WebminCore; &init_config(); " +
        'print "Content-type: text/plain\\n\\nSTRICT_OK\\n";\n')
    (root / 'strict-api.cgi').chmod(0o755)
    userform = 'acl/edit_user.cgi?user=' + fixture['user']
    groupform = 'acl/edit_group.cgi?group=' + fixture['group']

    # Inherited controls stay hidden even without a parent selector.
    operate('parent')
    edit(groupform, 'save_group.cgi', {'group': fixture['parent']})
    operate('subgroup-editor')
    # Compare editors with and without permission to change the parent group.
    for who in ('admin', 'editor'):
        status, page = request(groupform, who=who)
        form = Form(page, 'save_group.cgi')
        fields = dict(form.fields)
        check(status == 200 and form.found, who + ' can open subgroup editor', page)
        check(not {'api_only', 'acl_security_form', 'rpc'} & fields.keys(),
              who + ' sees no editable inherited global controls')
        if who == 'editor':
            # A forged submission must not bypass the hidden inherited controls.
            check('group' not in fields, 'delegated editor has no parent selector')
            fields.update(acl_security_form='1', api_only_def='1')
            request('acl/save_group.cgi', fields, who=who)
            check(state()['group']['api_only'] == 'strict-api.cgi',
                  'forged unrestricted submission cannot clear inherited endpoint')

    # An open fast RPC session must close when the account becomes API-only.
    edit(userform, 'save_user.cgi', {'api_only_def': '1', 'rpc': '1'})
    status, body = request('fastrpc.cgi', who='user')
    parts = body.strip().split()
    check(status == 200 and len(parts) >= 4 and parts[0] == '1', 'ordinary account opens fast RPC')
    # Confirm this connection can execute a command before restricting it.
    rpc_socket = socket.create_connection(('127.0.0.1', int(parts[1])), timeout=5)
    stream = rpc_socket.makefile('rb')
    check(command(stream, parts[2], {'action': 'eval', 'code': '6 * 7'}) ==
          {'status': '1', 'rv': '42'}, 'ordinary RPC executes harmless expression')
    # Change policy through the real form, then reuse the established session.
    edit(userform, 'save_user.cgi', {'api_only_def': '0', 'api_only': 'strict-api.cgi'})
    check(command(stream, parts[2], {'action': 'eval', 'code': '6 * 7'}) is None,
          'existing fast RPC closes before executing another command')
    stream.close()
    rpc_socket.close()
    rpc_socket = None
    # The same restriction must also prevent a fresh RPC session.
    status, body = request('fastrpc.cgi', who='user')
    check(status == 403, 'restricted account cannot open a new RPC connection')

    print('All targeted live restriction tests passed for ' + backend, flush=True)
finally:
    if rpc_socket is not None:
        # Close a connection left open by an earlier test failure.
        rpc_socket.close()
    # Remove the extra accounts and groups along with the shared fixtures.
    operate('cleanup-parent')
    helper('cleanup')
    path.unlink(missing_ok=True)
    # Remove the endpoint created for these tests.
    (task / 'root/strict-api.cgi').unlink(missing_ok=True)
