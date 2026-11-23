"""Test the installed Webmin configuration handlers on a disposable Linux VM.

Run as root with python3 t/fixtures/module-config-live.py. Install the matching
Webmin and Authentic sources first. The test uses private mounts and loopback.
"""

import base64
import http.client
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import tempfile
import time
from urllib.parse import unquote, urlencode


def config_values(path):
    return dict(line.split('=', 1) for line in path.read_text().splitlines() if '=' in line)


def request(user, url, form=None, multipart=False):
    headers = {'Referer': 'http://127.0.0.1:13217/config.cgi',
               'Authorization': 'Basic ' + base64.b64encode(f'{user}:{password}'.encode()).decode()}
    body = None
    if form is not None:
        if multipart:
            boundary = secrets.token_hex(20)
            headers['Content-Type'] = f'multipart/form-data; boundary={boundary}'
            body = ''.join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'
                           for k, v in form.items()) + f'--{boundary}--\r\n'
        else:
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
            body = urlencode(form)
    conn = http.client.HTTPConnection('127.0.0.1', 13217, timeout=20)
    try:
        conn.request('POST' if form is not None else 'GET', url, body, headers)
        response = conn.getresponse()
        return response.status, unquote(response.getheader('Location', '')), response.read().decode(errors='replace')
    finally:
        conn.close()


def test_theme(user):
    settings.write_text('test_a=one\ntest_b=two\nhidden=keep\n')
    prefs = settings.parent / ('prefs.' + user)
    prefs.write_text('test_b=personal\n')
    status, _, page = request(user, '/config.cgi?' + module)
    assert status == 200 and re.search(r'<input\b[^>]*\bname="test_a"', page) and 'name="save_next"' in page
    assert re.search(r'<a\b[^>]*\bname="test_a"[^>]*>\s*First setting</a>', page)
    assert 'name="test_b"' not in page and 'name="hidden"' not in page
    if user == 'cfgauth':
        assert re.search(r'<span data-sub_title[^>]*>[^\n]*<span\b[^>]*>Module configuration fixture</span>', page)
        options = json.loads(re.search(r'var config_quick_access = (.*?);</script>', page)[1])
        assert [item['section'] for item in options] == ['a', 'b'] and 'config-search' in page
    _, _, page = request(user, f'/config.cgi?module={module}&section=a&nprev=1')
    assert re.search(r'<input\b[^>]*\bname="test_b"', page) and 'personal' in page

    status, location, _ = request(user, '/config_save.cgi', dict(module=module, section='a',
        test_a='updated', save_next=1, section_next='b', _cscript='index.cgi', _cparam_domain='example.org'))
    assert status == 302 and 'section=b' in location and '_cparam_domain=example.org' in location
    assert config_values(settings) == {'test_a': 'updated', 'test_b': 'two', 'hidden': 'keep'}
    assert config_values(prefs)['test_b'] == 'personal'
    assert (settings.parent / 'hook').read_text() == 'one:updated'
    status, location, body = request(user, '/config_save.cgi', dict(module=module, section='b',
        test_b='changed', skipredirect=1), multipart=(user == 'cfgauth'))
    assert status == 200 and not location and body.strip() == 'Config saved successfully'
    assert config_values(settings) == {'test_a': 'updated', 'test_b': 'changed', 'hidden': 'keep'}
    assert config_values(confdir / 'installed.cache')[module] == '1'
    print(f'{user}: navigation, section saves, preferences and hooks passed', flush=True)


def test_filtered_form():
    # Single-page forms can hide settings and let users keep a saved password.
    info = moddir / 'config.info'
    original = info.read_text()
    info.write_text('test_a=Visible,0\nhidden=Hidden,0\nsecret=Password,12\n')
    (moddir / 'prefs.info').write_text('allowed=*\n')
    settings.write_text('test_a=before\nhidden=global\nsecret=global\n')
    prefs = settings.parent / 'prefs.cfgauth'
    prefs.write_text('test_a=before\nhidden=personal\nsecret=personal\n')
    status, _, page = request('cfgauth', '/config.cgi?' + module)
    assert status == 200 and 'name="hidden"' not in page and 'name="secret_nochange"' in page
    status, _, body = request('cfgauth', '/config_save.cgi', dict(
        module=module, test_a='after', secret_nochange=1, skipredirect=1))
    assert status == 200 and body.strip() == 'Config saved successfully'
    assert config_values(settings) == {'test_a': 'after', 'hidden': 'global', 'secret': 'global'}
    assert config_values(prefs) == {'test_a': 'after', 'hidden': 'personal', 'secret': 'personal'}
    info.write_text(original)
    print('Single-page save preserved hidden settings and the unchanged password', flush=True)


def test_custom_editor():
    # A custom form reads the same section on first load, navigation and save.
    info = moddir / 'config.info'
    info.write_text(info.read_text() + 'omitted=Option omitted by the custom form,0\n')
    (moddir / 'config_info.pl').write_text("""
use WebminCore;
sub config_form {
    my $key = 'test_'.$in{'section'};
    print ui_textbox($key, $_[0]->{$key}, 20);
}
sub config_save {
    my $key = 'test_'.$in{'section'};
    $_[0]->{$key} = $in{$key};
    $_[0]->{'computed'} = 'default';
    delete $_[0]->{'obsolete'};
}
1;
""")
    (moddir / 'prefs.info').write_text('allowed=*\n')
    for user in users[:3]:
        settings.write_text('test_a=one\ntest_b=two\ncomputed=default\nomitted=global\n')
        prefs = settings.parent / ('prefs.' + user)
        prefs.write_text('test_a=personal-one\ntest_b=personal-two\n'
                         'computed=personal\nomitted=mine\nobsolete=yes\n')
        _, _, page = request(user, '/config.cgi?' + module)
        assert 'name="test_a"' in page and 'personal-one' in page and 'name="save_next"' in page
        _, _, page = request(user, f'/config.cgi?module={module}&section=a&nnext=1')
        assert 'name="test_b"' in page and 'personal-two' in page and 'name="omitted"' not in page
        if user == 'cfgauth':
            assert 'config-search' in page
        status, location, _ = request(user, '/config_save.cgi', dict(module=module, section='b',
            test_b='two', save_next=1, section_next='a'))
        assert status == 302 and 'section=a' in location
        assert config_values(settings) == {'test_a': 'one', 'test_b': 'two',
                                           'computed': 'default', 'omitted': 'global'}
        assert config_values(prefs) == {'test_a': 'personal-one', 'test_b': 'two',
                                        'computed': 'default', 'omitted': 'mine'}
        print(f'{user}: custom section navigation, save and personal preferences passed', flush=True)


if sys.platform != 'linux' or os.getuid() != 0:
    sys.exit('Run as root on a disposable Linux test VM')
if len(sys.argv) == 1:
    with tempfile.TemporaryDirectory(prefix='module-config-') as tmp:
        subprocess.run(['unshare', '--mount', '--net', '--pid', '--fork', '--kill-child',
                        sys.executable, __file__, tmp], check=True, timeout=180)
    sys.exit(0)

# Require private namespaces before overlaying any part of the installation.
task = Path(sys.argv[1]).resolve()
if (not task.is_relative_to('/tmp') or
        any(os.stat(f'/proc/self/ns/{ns}').st_ino == os.stat(f'/proc/1/ns/{ns}').st_ino
            for ns in ('mnt', 'net'))):
    sys.exit('The fixture requires its own mount and network namespaces')
os.umask(0o077)
confdir = Path('/etc/webmin')
config = config_values(confdir / 'miniserv.conf')
root = Path(config['root'])
vardir = Path(config['env_WEBMIN_VAR'])
subprocess.run(['ip', 'link', 'set', 'lo', 'up'], check=True)
for i, directory in enumerate((root, confdir, vardir)):
    upper, work = task / f'upper{i}', task / f'work{i}'
    upper.mkdir()
    work.mkdir()
    subprocess.run(['mount', '-t', 'overlay', 'overlay', '-o',
                    f'lowerdir={directory},upperdir={upper},workdir={work}', directory], check=True)

module = 'module-config-fixture'
moddir = root / module
moddir.mkdir()
(moddir / 'module.info').write_text('desc=Module configuration fixture\ncategory=system\n')
(moddir / 'config.info').write_text('a=First,11\ntest_a=First setting,0\nhidden=Hidden,0\n'
                                    'b=Second,11\ntest_b=Second setting,0\n')
(moddir / 'prefs.info').write_text('allowed=test_a,test_b\n')
(moddir / (module + '-lib.pl')).write_text("""
sub config_pre_load { delete $_[0]->{'hidden'}; }
sub config_post_save {
    my ($new, $old) = @_;
    open(my $f, '>', '/etc/webmin/module-config-fixture/hook') or die $!;
    print $f "$old->{test_a}:$new->{test_a}";
}
1;
""")
settings = confdir / module / 'config'
settings.parent.mkdir()
users = ['cfgstock', 'cfggray', 'cfgauth', 'cfgnoconfig']
password = secrets.token_urlsafe()
hashed = subprocess.check_output(['openssl', 'passwd', '-6', '-stdin'],
                                 input=password + '\n', text=True).strip()
(task / 'users').write_text(''.join(f'{u}:{hashed}\n' for u in users))
with (confdir / 'webmin.acl').open('a') as acl:
    for user in users:
        acl.write(f'\n{user}: {module}\n')
(settings.parent / 'cfgnoconfig.acl').write_text('noconfig=1\n')
config.update(bind='127.0.0.1', ipv6='0', session='0', ssl='0', port='13217', listen='13217',
              userfile=str(task / 'users'), preroot='', preroot_cfggray='gray-theme',
              preroot_cfgauth='authentic-theme', allow='127.0.0.1', deny='', passdelay='0',
              blockhost_failures='0', syslog='0', pidfile=str(task / 'miniserv.pid'))
(confdir / 'miniserv.conf').write_text(''.join(f'{k}={v}\n' for k, v in config.items()))
for theme in ('gray-theme', 'authentic-theme'):
    for cgi in ('config.cgi', 'config_save.cgi'):
        assert not (root / theme / cgi).exists(), f'Install the updated {theme} first'

proc = subprocess.Popen(['perl', root / 'miniserv.pl', '--nofork', confdir / 'miniserv.conf'])
try:
    for _ in range(100):
        try:
            with socket.create_connection(('127.0.0.1', 13217), .1):
                break
        except OSError:
            time.sleep(.1)
    for user in users[:3]:
        test_theme(user)
    _, _, page = request('cfgnoconfig', '/config_save.cgi', dict(module=module, section='a', test_a='blocked'))
    assert 'not allowed' in page.lower() and config_values(settings)['test_a'] == 'updated'
    print('Module configuration permission check passed')
    test_filtered_form()
    test_custom_editor()
finally:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
