"""Exercise API-account lists and Cluster sync on a disposable Linux VM.

Usage: python3 t/fixtures/api-only-list-live.py /tmp/task-directory
Runs isolated MiniServ instances. Installed services and accounts are untouched.
Place Virtualmin's api-access-lib.pl and module.info under virtual-server/ in
the uploaded Webmin source tree to test its account listing too.
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

if sys.platform != 'linux':
    raise RuntimeError('Run only on a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
os.umask(0o077)
checks = 0


def check(condition, message):
    """check(condition, message): stop on failure and report successful checks."""
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1
    print('PASS: ' + message, flush=True)


def write_config(path, values):
    """write_config(path, values): write a private fixture configuration."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(''.join(f'{k}={v}\n' for k, v in values.items()))


def request(server, path, form=None):
    """request(server, path, [form]): make an authenticated HTTP request."""
    connection = http.client.HTTPConnection(server['host'], server['port'], timeout=25)
    headers = {'Authorization': authorization}
    body = None
    if form is not None:
        body = urllib.parse.urlencode(form, doseq=True)
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    try:
        connection.request('POST' if form is not None else 'GET', path, body, headers)
        response = connection.getresponse()
        return response.status, response.read().decode(errors='replace')
    finally:
        connection.close()


def snapshot(server):
    """snapshot(server): capture protected account files for mutation checks."""
    conf = server['conf']
    names = ['miniserv.users', 'webmin.acl', 'api.acl', 'acl/api.acl',
             'webmin.groups', 'config']
    return {name: (conf/name).read_bytes() for name in names}


# Generate credentials in the guest only. Do not print their values.
password = secrets.token_urlsafe(32)
hashed = subprocess.check_output(
    ['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$management$));'],
    input=password.encode()).decode()
authorization = 'Basic ' + base64.b64encode(f'admin:{password}'.encode()).decode()
servers = []
with tempfile.TemporaryDirectory(prefix='live-', dir=task) as temporary:
    work = Path(temporary)
    try:
        for number in (1, 2):
            # Separate source and destination configurations share only code.
            conf = work / str(number) / 'config'
            var = work / str(number) / 'var'
            conf.mkdir(parents=True)
            (var/'locks').mkdir(parents=True)
            for module in ('acl', 'cluster-webmin', 'servers', 'virtual-server'):
                (conf/module).mkdir()
            host = f'127.0.0.{number}'
            with socket.socket() as sock:
                sock.bind((host, 0))
                port = sock.getsockname()[1]
            write_config(conf/'config', dict(os_type='generic-linux', os_version=0,
                         lang='en', log=0, noselfwebminup=1, webprefix='',
                         tempdir=var/'tmp', rpc_timeout=10,
                         rpc_idle_factor=1))
            (conf/'var-path').write_text(str(var)+'\n')
            write_config(conf/'miniserv.conf', dict(port=port, bind=host,
                root=source, ssl=0, pidfile=var/'pid', logfile=var/'requests',
                errorlog=var/'errors', userfile=conf/'miniserv.users',
                env_WEBMIN_CONFIG=conf, env_WEBMIN_VAR=var, session=0,
                passdelay=0, no_pam=1, syslog=0, log=0, forkcgis=0,
                addtype_cgi='internal/cgi', allow='127.0.0.0/8',
                precache='none'))
            (conf/'miniserv.users').write_text(
                f'admin:{hashed}:0\napi:{hashed}:0\nordinary:{hashed}:0\n')
            (conf/'webmin.acl').write_text(
                'admin: acl cluster-webmin servers\napi: virtual-server\nordinary: acl\n')
            (conf/'webmin.groups').write_text('')
            write_config(conf/'admin.acl', dict(rpc=1))
            write_config(conf/'api.acl', dict(api_only='virtual-server/remote.cgi', rpc=0))
            write_config(conf/'acl/api.acl', dict(policy='keep'))
            write_config(conf/'virtual-server/api.acl', dict(api_id='fixture'))
            write_config(conf/'acl/admin.acl', dict(users='*', create=1, delete=1,
                acl=1, groups=1, unix=1, mode=0, rename=1, gassign='*', switch=1))
            process = subprocess.Popen(
                ['perl', str(source/'miniserv.pl'), '--nofork', str(conf/'miniserv.conf')],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, start_new_session=True)
            server = dict(id=number, conf=conf, var=var, host=host, port=port, process=process)
            servers.append(server)
            for attempt in range(100):
                if process.poll() is not None:
                    raise RuntimeError('Fixture MiniServ stopped during startup')
                try:
                    status, body = request(server, '/acl/index.cgi')
                    break
                except OSError:
                    time.sleep(.1)
            else:
                raise RuntimeError('Fixture MiniServ did not start')
            check(status == 200 and 'Webmin Users' in body, 'live Webmin Users page loads')

        controller, peer = servers
        # Source-only accounts test exclusion, ordinary sync and hidden-name clashes.
        conf = peer['conf']
        (conf/'miniserv.users').write_text(f'admin:{hashed}:0\ncollision:{hashed}:0\n')
        (conf/'webmin.acl').write_text('admin: acl cluster-webmin servers\ncollision: acl\n')
        (conf/'api.acl').unlink()
        write_config(conf/'collision.acl', dict(api_only='virtual-server/remote.cgi'))
        write_config(conf/'acl/collision.acl', dict(policy='keep'))
        with (controller['conf']/'miniserv.users').open('a') as handle:
            handle.write(f'collision:{hashed}:0\n')
        with (controller['conf']/'webmin.acl').open('a') as handle:
            handle.write('collision: acl\n')
        # Real RPC registration and a pre-existing inventory exercise Refresh.
        for server in servers:
            write_config(controller['conf']/'servers'/f"{server['id']}.serv",
                dict(id=server['id'], host=server['host'], port=server['port'],
                     user='admin', **{'pass': password}, ssl=0, fast=1))
            cache = controller['conf']/'cluster-webmin'/'hosts'/str(server['id'])
            write_config(cache/'webmin', dict(version='2.671'))
            write_config(cache/'acl.mod', dict(dir='acl', desc='Webmin Users'))
            for name in ('api', 'ordinary'):
                write_config(cache/f'{name}.user', dict(name=name, modules='acl',
                             **{'pass': hashed}))
            status, body = request(controller, '/cluster-webmin/refresh.cgi',
                                   dict(id=server['id']))
            check(status == 200 and (cache/'admin.user').exists(),
                  'Cluster refresh loads real remote accounts')
            check(not (cache/'api.user').exists(), 'refresh removes API account from cache')
        source_cache = controller['conf']/'cluster-webmin'/'hosts'/'1'
        peer_cache = controller['conf']/'cluster-webmin'/'hosts'/'2'
        check((source_cache/'ordinary.user').exists(), 'ordinary source account remains listed')
        check(not (peer_cache/'collision.user').exists(), 'remote API account is hidden too')
        status, body = request(controller, '/cluster-webmin/index.cgi')
        check(status == 200 and 'edit_user.cgi?user=api&' not in body,
              'Cluster page does not offer the API account')
        status, body = request(controller, '/acl/edit_unix.cgi')
        check(status == 200 and 'ordinary' in body and
              'value="api"' not in body and "value='api'" not in body,
              'Unix mapping selector excludes the API account')

        # Account and permission editors still reject named API targets.
        before = snapshot(controller)
        for path, form in [
            ('/acl/edit_user.cgi?user=api&readwrite=1', None),
            ('/acl/save_user.cgi', dict(old='api', name='renamed', pass_def=4)),
            ('/acl/save_acl.cgi', dict(_acl_user='api', _acl_mod='', reset=1)),
            ('/acl/delete_user.cgi?user=api', None),
        ]:
            status, body = request(controller, path, form)
            check('not allowed' in body.lower(), f'{path}: API account rejected')
            check(snapshot(controller) == before, 'API account data is unchanged')

        # Hidden destination names must be checked before copying any group ACLs.
        protected = {name: (conf/name).read_bytes() for name in
                     ('miniserv.users', 'webmin.acl', 'collision.acl', 'acl/collision.acl')}
        status, body = request(controller, '/cluster-webmin/create_user.cgi',
                              dict(name='collision', pass_def=4, server=2))
        check('already' in body.lower(), 'Cluster creation rejects a hidden-name collision')
        check(all((conf/name).read_bytes() == content for name, content in protected.items()),
              'creation leaves the existing API account and permissions intact')
        status, body = request(controller, '/cluster-webmin/sync.cgi',
                              dict(users_mode=1, groups_mode=0, server=2))
        check(status == 200 and 'ordinary:' in (conf/'miniserv.users').read_text(),
              'ordinary account synchronizes through real RPC')
        check('api:' not in (conf/'miniserv.users').read_text(),
              'API credentials are not synchronized')
        check((conf/'miniserv.users').read_text().count('collision:') == 1,
              'sync does not duplicate the hidden destination account')
        check(all((conf/name).read_bytes() == protected[name] for name in
                  ('collision.acl', 'acl/collision.acl')),
              'sync leaves the destination API policy intact')

        # Exercise Virtualmin's actual listing function against real Webmin ACLs.
        environment = dict(os.environ, WEBMIN_CONFIG=str(controller['conf']),
                           WEBMIN_VAR=str(controller['var']),
                           FOREIGN_MODULE_NAME='virtual-server', FOREIGN_ROOT_DIRECTORY=str(source))
        probe = work/'owner.pl'
        probe.write_text("""use lib $ARGV[0];
use WebminCore;
&init_config();
sub require_acl { &foreign_require('acl', 'acl-lib.pl'); }
do "$ARGV[0]/virtual-server/api-access-lib.pl" or die $@ || $!;
my @api = &list_api_access_users();
die "API owner cannot list its account" unless @api == 1 && $api[0]->{name} eq 'api';
my $account = &acl::get_user('api');
$account->{real} = 'Owner updated';
&acl::modify_user('api', $account);
die "API owner cannot update its account" unless &acl::get_user('api')->{real} eq 'Owner updated';
print "API owner listing and update passed\n";
""")
        result = subprocess.run(['perl', str(probe), str(source)], cwd=source,
                                env=environment, capture_output=True, text=True, timeout=30)
        check(result.returncode == 0, 'Virtualmin can still list and update its API account: ' + result.stderr)
    finally:
        # Terminate only fixture process groups, including their RPC children.
        for server in servers:
            process = server['process']
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
print(f'{checks} live checks passed; fixture processes and files removed.')
