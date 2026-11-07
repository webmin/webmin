"""Test inherited controls and group deletion through an isolated Webmin UI.

Usage: python3 api-only-groups.py /tmp/task-directory
Prepare the sandbox with api-only-sandbox.py. Never run on the workstation.
"""
from pathlib import Path
import os
import sys

if sys.platform != 'linux' or os.geteuid() != 0:
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not any(base in task.parents for base in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Use the isolated task directory')
# Reuse guest-only credentials, HTTP requests and form parsing from the driver.
exec(compile((task / 'api-only-live.py').read_text().split('\ntry:\n', 1)[0],
             str(task / 'api-only-live.py'), 'exec'))


def controls(target, who='admin'):
    """controls(target, [who]): return editable field names from a user form."""
    status, page = request(target, who=who)
    form = Form(page, 'save_user.cgi')
    check(status == 200 and form.found, 'user form is available to ' + who, page)
    return {name for name, value in form.fields}


try:
    helper('setup')
    userform = 'acl/edit_user.cgi?user=' + fixture['user']
    groupform = 'acl/edit_group.cgi?group=' + fixture['group']
    global_fields = {'api_only', 'rpc', 'acl_security_form', 'root_def', 'nodot'}
    check(global_fields <= controls(userform), 'ungrouped user can edit global permissions')

    # Membership hides inherited fields regardless of where ACLs are stored.
    edit(userform, 'save_user.cgi', {'group': fixture['group']})
    check(not global_fields & controls(userform), 'group member has no editable global permissions')
    check(not global_fields & controls('acl/edit_user.cgi?clone=' + fixture['user']),
          'grouped clone also inherits global permissions')
    helper('group-editor')
    check(not (global_fields | {'group'}) & controls(userform, 'editor'),
          'editor without group assignment still sees inherited fields as unavailable')
    edit(userform, 'save_user.cgi', {'group': ''})
    check(global_fields <= controls(userform), 'detached member can edit global permissions again')

    # Delete an empty group through the real handler, then reuse its name.
    edit(groupform, 'save_group.cgi', {'api_only_def': '0', 'api_only': endpoint, 'nodot': '1'})
    check(state()['group']['api_only'] == endpoint and state()['group']['nodot'] == '1',
          'group stores endpoint and ordinary global permissions before deletion')
    request('acl/delete_group.cgi', {'group': fixture['group']})
    check(not state()['group']['exists'], 'group deletion removes the group record')
    check(not (task / 'config' / (fixture['group'] + '.gacl')).exists(),
          'group deletion leaves no global ACL file')
    edit('acl/edit_group.cgi', 'save_group.cgi',
         {'name': fixture['group'], 'desc': 'Recreated fixture group', 'mod': ''})
    group = state()['group']
    check(group['exists'] and not any(group[key] for key in ('api_only', 'rpc', 'nodot')),
          'recreated group has no old global permissions')

    # A group without any global policy still owns its members' global fields.
    edit(userform, 'save_user.cgi', {'api_only_def': '1'})
    edit(userform, 'save_user.cgi', {'group': fixture['group']})
    check(not global_fields & controls(userform), 'group without a global ACL still hides inherited fields')
    check(not state()['user']['api_only'], 'new member does not inherit the deleted endpoint')
    status, page = request('index.cgi', who='user')
    check(status == 200 and 'restricted to its configured API' not in page,
          'deleted group policy does not block the new member', page)

    # Confirmed deletion also cleans up a populated API group and its member.
    edit(groupform, 'save_group.cgi', {'api_only_def': '0', 'api_only': endpoint})
    restricted('recreated group policy')
    request('acl/delete_group.cgi', {'group': fixture['group'], 'confirm': '1'})
    result = state()
    check(not result['group']['exists'] and not result['user']['exists'],
          'confirmed group deletion removes its member')
    check(not (task / 'config' / (fixture['group'] + '.gacl')).exists(),
          'populated group deletion also removes its global ACL')
    print('All group lifecycle tests passed.', flush=True)
finally:
    helper('cleanup')
    path.unlink(missing_ok=True)
