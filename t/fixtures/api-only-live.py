#!/usr/bin/env python3
"""Test API-only account editing on a disposable Webmin VM, never locally.

Run with a task directory containing api-only-account.pl. Generated fixture
credentials stay in a mode-0600 file on that VM and are removed on completion.
"""
import base64
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

# Generate isolated fixture names and credentials inside the guest task
# directory.
task = Path(sys.argv[1])
path = task / 'api-only-credentials.json'
fixture = {key: 'apilife' + secrets.token_hex(5)
           for key in ('admin', 'user', 'editor', 'renamed', 'clone', 'group')}
fixture.update({key + '_password': secrets.token_urlsafe(32)
                for key in ('admin', 'user', 'editor')})
os.umask(0o077)
path.write_text(json.dumps(fixture))
# Requests target the installed guest instance, never the development
# workstation.
base = 'https://127.0.0.1:10000/'
context = ssl._create_unverified_context()  # Guest loopback fixture certificate
endpoint = 'virtual-server/remote.cgi'


def redact(value):
    """redact(value): remove fixture passwords from diagnostic text."""
    for key, password in fixture.items():
        if key.endswith('_password'):
            # Mask credentials while leaving fixture names useful for diagnosis.
            value = value.replace(password, '[redacted]')
    return value


def helper(mode):
    """helper(mode): run a fixture operation and return its captured output."""
    result = subprocess.run(['perl', str(task / 'api-only-account.pl'), mode, str(path)],
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        # Preserve failure details without exposing generated passwords.
        raise RuntimeError(redact(result.stdout + result.stderr))
    return result.stdout


def request(target, params=None, who='admin', username=None):
    """request(target, [params], [who], [username]): return HTTP status and body.

    params selects POST instead of GET. who defaults to admin and selects a
    fixture password; username can override its login name for rename tests.
    """
    auth = base64.b64encode((
        (username or fixture[who]) + ':' + fixture[who + '_password']).encode()).decode()
    req = urllib.request.Request(base + target,
        headers={'Authorization': 'Basic ' + auth, 'User-Agent': 'Webmin API lifecycle test',
                 'Referer': base + 'acl/edit_user.cgi'},
        data=urllib.parse.urlencode(params).encode() if params is not None else None)
    try:
        with urllib.request.urlopen(req, context=context, timeout=60) as response:
            return response.status, response.read().decode(errors='replace')
    except urllib.error.HTTPError as error:
        # Denials are expected test responses, not transport failures.
        return error.code, error.read().decode(errors='replace')


def check(ok, message, output=''):
    """check(ok, message, [output]): report an assertion; redact optional output."""
    if not ok:
        # Bound failure output and remove credentials before raising.
        raise AssertionError(message + ': ' + redact(output[:1500]))
    print('PASS: ' + message, flush=True)


class Form(HTMLParser):
    """Read input values from the matching Webmin edit form."""
    def __init__(self, page, action):
        """Form(page, action): parse controls for the matching submit action."""
        super().__init__()
        self.action, self.active, self.found = action, False, False
        self.fields, self.select, self.textarea = [], None, None
        self.feed(page)

    def handle_starttag(self, tag, attrs):
        """handle_starttag(tag, attrs): collect enabled controls in the form."""
        attrs = dict(attrs)
        if tag == 'form':
            # Ignore unrelated forms, including search and navigation controls.
            self.active = attrs.get('action', '').split('?')[0].endswith(self.action)
            self.found |= self.active
        if not self.active:
            # Only controls within the target form belong in its submission.
            return
        name = attrs.get('name')
        if tag == 'input' and name and 'disabled' not in attrs:
            # Follow browser rules for controls included in form submission.
            kind = attrs.get('type', 'text').lower()
            if kind in ('submit', 'button', 'reset', 'file', 'image'):
                # The driver does not click a button or upload a file.
                return
            if kind in ('checkbox', 'radio') and 'checked' not in attrs:
                # Unselected choices contribute no submitted value.
                return
            self.fields.append((name, attrs.get('value', '')))
        elif tag == 'select' and name:
            # Defer selection until all options have been read.
            self.select = [name, 'multiple' in attrs, []]
        elif tag == 'option' and self.select:
            # Keep explicit selections and the first-option fallback in order.
            self.select[2].append([attrs.get('value', ''), 'selected' in attrs])
        elif tag == 'textarea' and name:
            # Textarea contents arrive through handle_data.
            self.textarea = [name, '']

    def handle_data(self, data):
        """handle_data(data): append text only while inside a textarea."""
        if self.textarea:
            # Preserve multiline contents as one submitted field.
            self.textarea[1] += data

    def handle_endtag(self, tag):
        """handle_endtag(tag): finish control values or close the target form."""
        if tag == 'select' and self.select:
            # Submit selected options, using the browser default when needed.
            name, multiple, options = self.select
            chosen = [value for value, selected in options if selected]
            if not chosen and not multiple and options:
                # A single select defaults to its first option.
                chosen = [options[0][0]]
            self.fields.extend((name, value) for value in chosen)
            self.select = None
        elif tag == 'textarea' and self.textarea:
            # Save the complete value once the textarea closes.
            self.fields.append(tuple(self.textarea))
            self.textarea = None
        elif tag == 'form':
            # Stop collecting controls beyond this form.
            self.active = False


def edit(target, action, changes=None, omit=()):
    """edit(target, action, [changes], [omit]): submit the rendered edit form.

    changes defaults to no overrides; omit defaults to no removed controls.
    All other submitted settings retain their rendered values.
    """
    status, page = request(target)
    form = Form(page, action)
    check(status == 200 and form.found, 'render ' + action, page)
    changes = changes or {}
    fields = [(key, value) for key, value in form.fields
              if key not in changes and key not in omit]
    fields.extend(changes.items())
    return request('acl/' + action, fields)


def state():
    """state(): return stored fixture ACLs independently of rendered HTML."""
    return json.loads(helper('inspect'))


def restricted(label, username=None):
    """restricted(label, [username]): check CGI denials with the fixture password.

    username defaults to the original login; clones and renames override it.
    Both in-process and forked CGI modes must return HTTP 403.
    """
    for target in ('index.cgi', 'acl/index.cgi', 'rpc.cgi', 'fastrpc.cgi', 'xmlrpc.cgi'):
        status, page = request(target, who='user', username=username)
        check(status == 403 and 'restricted' in page.lower(), label + ': ' + target, page)


try:
    helper('setup')
    userform = 'acl/edit_user.cgi?user=' + fixture['user']
    status, page = request(userform)
    check('name="api_only"' in page and endpoint in page,
          'Webmin Users shows the configured API-only endpoint', page)
    restricted('initial policy')
    # Ordinary user edits must preserve the endpoint and all CGI denials.
    edit(userform, 'save_user.cgi', {'real': 'API lifecycle edited'})
    check(state()['user']['api_only'] == endpoint, 'normal user edit preserves API restriction')
    restricted('after normal user edit')

    # Older clients omit the new controls entirely.
    edit(userform, 'save_user.cgi', {'real': 'older client'}, omit=('api_only', 'api_only_def'))
    check(state()['user']['api_only'] == endpoint, 'older form cannot discard API restriction')

    # A delegated account editor must not clear the policy by submitting a
    # global-permissions form that its own UI does not offer.
    status, page = request('acl/save_user.cgi', {
        'old': fixture['user'], 'name': fixture['user'], 'acl_security_form': '1',
        'api_only_def': '1'}, who='editor')
    check('not allowed' in page.lower() and state()['user']['api_only'] == endpoint,
          'editor without ACL permission cannot clear restriction', page)

    # Reset and group-copy helpers must retain an existing user restriction.
    request('acl/save_acl.cgi', {'_acl_user': fixture['user'], '_acl_mod': '', 'reset': '1'})
    check(state()['user']['api_only'] == endpoint, 'resetting global ACL retains restriction')
    helper('copy')
    check(state()['user']['api_only'] == endpoint, 'copying unrestricted group retains restriction')
    helper('propagate')
    check(state()['user']['api_only'] == endpoint, 'group propagation retains restriction')

    # Exercise real group assignment, then detach before editing global fields.
    edit(userform, 'save_user.cgi', {'group': fixture['group']})
    check(state()['user']['api_only'] == endpoint, 'assigning group in UI retains restriction')
    edit(userform, 'save_user.cgi', {'group': ''})

    # An endpoint selected on a group must reach existing unrestricted members.
    edit(userform, 'save_user.cgi', {'api_only_def': '1'})
    edit(userform, 'save_user.cgi', {'group': fixture['group']})
    status, page = request(userform)
    check(status == 200 and 'name="api_only"' not in page,
          'grouped users do not get an endpoint control that cannot be saved')

    # Group fields need the same validation and permission checks as user
    # fields.
    groupform = 'acl/edit_group.cgi?group=' + fixture['group']
    edit(groupform, 'save_group.cgi', {'api_only_def': '0', 'api_only': endpoint})
    check(state()['group']['api_only'] == endpoint, 'group UI saves explicit API restriction')
    check(state()['user']['api_only'] == endpoint, 'group restriction reaches existing members')
    restricted('after setting group endpoint')
    edit(userform, 'save_user.cgi', {'group': ''})
    status, page = request('acl/save_group.cgi', {
        'old': fixture['group'], 'name': fixture['group'], 'acl_security_form': '1',
        'api_only_def': '1'}, who='editor')
    check('not allowed' in page.lower() and state()['group']['api_only'] == endpoint,
          'group editor without ACL permission cannot clear restriction', page)
    # Older group forms and resets must also retain the endpoint.
    edit(groupform, 'save_group.cgi', {'desc': 'group edited'}, omit=('api_only', 'api_only_def'))
    check(state()['group']['api_only'] == endpoint, 'older group form preserves restriction')
    request('acl/save_acl.cgi', {'_acl_group': fixture['group'], '_acl_mod': '', 'reset': '1'})
    check(state()['group']['api_only'] == endpoint, 'group global ACL reset preserves restriction')

    # Bad paths must be rejected; explicit clearing must restore ordinary
    # access.
    edit(userform, 'save_user.cgi', {'api_only_def': '0', 'api_only': '../rpc.cgi'})
    check(state()['user']['api_only'] == endpoint, 'malformed endpoint cannot replace saved restriction')
    edit(userform, 'save_user.cgi', {'api_only_def': '1'})
    check(not state()['user']['api_only'], 'Unrestricted explicitly clears endpoint')
    status, page = request('index.cgi', who='user')
    check(status == 200 and 'restricted to its configured API' not in page,
          'explicit clearing restores normal UI access', page)
    edit(userform, 'save_user.cgi', {'api_only_def': '0', 'api_only': endpoint})
    restricted('after re-enabling restriction')

    # Cloning and renaming must retain both the stored endpoint and its denials.
    edit('acl/edit_user.cgi?clone=' + fixture['user'], 'save_user.cgi', {
        'name': fixture['clone'], 'pass_def': '0', 'pass': fixture['user_password']})
    check(state()['clone']['api_only'] == endpoint, 'cloning account preserves restriction')
    restricted('cloned account', fixture['clone'])
    edit(userform, 'save_user.cgi', {'name': fixture['renamed']})
    check(state()['renamed']['api_only'] == endpoint and not state()['user']['exists'],
          'renaming account preserves restriction')
    restricted('renamed account', fixture['renamed'])
    print('All authenticated API-only lifecycle tests passed.', flush=True)
finally:
    # Cleanup uses the guest helper independently of the restricted login.
    helper('cleanup')
    path.unlink(missing_ok=True)
