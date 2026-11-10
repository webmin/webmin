#!/usr/bin/env python3
# cluster-webmin-api-only.py task-directory [--postgresql] [--groups]
# Live HTTP/RPC checks in an isolated Linux guest. Extract the checkout into
# task-directory/root first. The task directory must be /tmp/webmin-api-cluster.*.
# --postgresql also requires a running PostgreSQL service and DBD::Pg.
# --groups checks member propagation with the separate #2920 patch installed.
# Run only in a disposable VM. Generated credentials stay inside the guest.
from pathlib import Path
import base64
import http.client
import os
import secrets
import signal
import socket
import subprocess
import sys
import time
import urllib.parse

# Run only inside an isolated Linux guest task directory.
if sys.platform != 'linux' or os.geteuid() != 0:
    raise RuntimeError('Disposable Linux VM required')
task = Path(sys.argv[1]).resolve()
if task.parent != Path('/tmp') or not task.name.startswith('webmin-api-cluster.'):
    raise RuntimeError('Unexpected task directory')
os.umask(0o077)
root = task / 'root'
password = secrets.token_urlsafe(32)
hashed = subprocess.check_output(['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$clusterfixture$));'], input=password.encode()).decode()
processes = []
ports = []

def write(path, text):
    """Write a fixture file inside the task directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def config(path, values):
    """Write Webmin name=value settings."""
    write(path, ''.join(f'{k}={v}\n' for k, v in values.items()))

def request(port, path, user='admin', fields=None):
    """Send an authenticated request to a fixture listener."""
    headers = {'Connection': 'close', 'User-Agent': 'Webmin cluster fixture',
        'Authorization': 'Basic ' + base64.b64encode((user+':'+password).encode()).decode()}
    body = None
    if fields is not None:
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
        body = urllib.parse.urlencode(fields)
    c = http.client.HTTPConnection('127.0.0.1', port, timeout=25)
    try:
        c.request('POST' if fields is not None else 'GET', path, body, headers)
        r = c.getresponse()
        return r.status, r.read()
    finally:
        c.close()

def start(name, fork):
    """Start an isolated MiniServ instance with its own config and logs."""
    base = task/name
    if base.exists():
        import shutil
        shutil.rmtree(base)
    conf, var = base/'config', base/'var'
    for p in (conf/'acl', conf/'cluster-webmin/hosts', conf/'servers', var/'locks'):
        p.mkdir(parents=True, exist_ok=True)
    write(conf/'config', 'os_type=generic-linux\nos_version=0\nlang=en\nrpc_timeout=10\nrpc_idle_factor=1\n')
    write(conf/'var-path', str(var)+'\n')
    write(conf/'users', f'admin:{hashed}\n')
    write(conf/'webmin.acl', 'admin: acl cluster-webmin servers\n')
    write(conf/'webmin.groups', '')
    write(conf/'admin.acl', 'rpc=1\n')
    write(conf/'acl/admin.acl', 'users=*\ngroups=1\nacl=1\nmode=0\n')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    ports.append(port)
    config(conf/'miniserv.conf', dict(port=port, bind='127.0.0.1', ssl=0, root=root,
        userfile=conf/'users', pidfile=var/'miniserv.pid', logfile=var/'requests.log',
        errorlog=var/'errors.log', env_WEBMIN_CONFIG=conf, env_WEBMIN_VAR=var,
        env_PERL5LIB=root, session=0, passdelay=0, no_pam=1, log=1, syslog=0,
        addtype_cgi='internal/cgi', forkcgis=fork, nofork=1, allow='127.0.0.1',
        blockhost_failures=0, blockuser_failures=0, precache='none'))
    with (base/'server.log').open('ab') as log:
        proc = subprocess.Popen(['perl', str(root/'miniserv.pl'), '--nofork', str(conf/'miniserv.conf')],
            stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
    processes.append(proc)
    for attempt in range(100):
        assert proc.poll() is None, 'Fixture server exited'
        try:
            with socket.create_connection(('127.0.0.1', port), timeout=.2):
                break
        except OSError:
            time.sleep(.05)
    else:
        raise RuntimeError('Fixture server did not start')
    return conf, port

def stop():
    """Stop only the fixture process groups, including their RPC children."""
    for p in processes:
        try:
            os.killpg(p.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        p.wait(timeout=10)
    processes.clear()

def cache(conf, host, names, groups=()):
    """Seed the cluster module's source and destination account lists."""
    p = conf/'cluster-webmin/hosts'/str(host)
    p.mkdir(parents=True, exist_ok=True)
    for old in list(p.glob('*.user'))+list(p.glob('*.group')):
        old.unlink()
    for name in names:
        write(p/(name+'.user'), f'name={name}\npass={hashed}\nmodules=acl\nownmods=\nolds=\n')
    for name in groups:
        write(p/(name+'.group'), f'name={name}\nmodules=acl\nownmods=\nmembers=\n')

def checked(port, fields, label):
    """Run the real synchronization CGI and retain its response for diagnosis."""
    status, body = request(port, '/cluster-webmin/sync.cgi', fields=fields)
    write(task/(label+'.html'), body.decode(errors='replace'))
    assert status == 200 and b'Perl execution failed' not in body, label+' failed'
    return body

# Use installed Perl paths when exercising forked CGI execution.
for relative in ('cluster-webmin/sync.cgi', 'cluster-webmin/save_acl.cgi', 'fastrpc.cgi', 'rpc.cgi'):
    p = root/relative
    p.write_text('#!/usr/bin/perl\n'+p.read_text().split('\n', 1)[1])
for name, endpoint in [('cluster-api', "'acl/cluster-api.cgi'"), ('cluster-ui', 'undef')]:
    p = root/'acl'/(name+'.cgi')
    write(p, '#!/usr/bin/perl\nuse strict;\nuse warnings;\nuse WebminCore;\n$main::allow_api_only = '+endpoint+';\ninit_config();\nprint "Content-type: text/plain\\r\\n\\r\\nENTRY_REACHED\\n";\n')
    p.chmod(0o700)

try:
    for fork in (0, 1):
        src, sp = start('source'+str(fork), fork)
        dst, dp = start('destination'+str(fork), fork)
        config(src/'servers/1.serv', dict(id=1, host='127.0.0.1', port=dp, ssl=0,
            fast=1, user='admin', pass_=password))
        # Config field is literally pass; keep generated credentials guest-only.
        p = src/'servers/1.serv'
        p.write_text(p.read_text().replace('pass_=', 'pass='))
        names = ['restricted', 'ordinary', 'failure']
        with (src/'users').open('a') as f:
            f.write(''.join(f'{u}:{hashed}\n' for u in names))
        with (src/'webmin.acl').open('a') as f:
            f.write(''.join(f'{u}: acl\n' for u in names))
        write(src/'webmin.groups', 'team::acl::\n')
        for u in names:
            write(src/'acl'/f'{u}.acl', 'users=self\n')
            write(src/f'{u}.acl', 'rpc=0\n'+('api_only=acl/cluster-api.cgi\n' if u != 'ordinary' else ''))
        write(src/'team.gacl', 'api_only=acl/cluster-api.cgi\nrpc=0\n')
        write(src/'acl/team.gacl', 'users=self\n')
        cache(src, 0, names, ['team'])
        cache(src, 1, [])
        checked(sp, dict(server=1, users_mode=2, usel='restricted', test=1), 'dry'+str(fork))
        assert 'restricted:' not in (dst/'users').read_text() and not (dst/'restricted.acl').exists(), 'Dry run writes destination'
        checked(sp, dict(server=1, users_mode=2, usel='restricted ordinary', groups_mode=1), 'sync'+str(fork))
        assert 'api_only=acl/cluster-api.cgi' in (dst/'restricted.acl').read_text(), 'API policy not synchronized'
        assert (dst/'ordinary.acl').read_text() == 'rpc=0\n', 'Ordinary global permissions changed'
        assert 'api_only=acl/cluster-api.cgi' in (dst/'team.gacl').read_text(), 'Group global ACL missing'
        assert (dst/'acl/restricted.acl').read_text().find('users=self') >= 0, 'Module ACL missing'
        for user in ('restricted', 'ordinary'):
            status, body = request(dp, '/acl/cluster-api.cgi', user)
            assert status == 200 and b'ENTRY_REACHED' in body, f'{user} cannot use API'
            status, body = request(dp, '/acl/cluster-ui.cgi', user)
            assert (b'ENTRY_REACHED' in body) == (user == 'ordinary'), f'{user} wrong UI access'
        print(f'PASS forkcgis={fork}: dry run; user/group global and module sync; restricted API allowed/UI denied; ordinary UI allowed', flush=True)
        # An unwritable ACL destination must prevent account activation.
        (dst/'failure.acl').mkdir()
        body = checked(sp, dict(server=1, users_mode=2, usel='failure'), 'failure'+str(fork))
        lines = [x for x in (dst/'users').read_text().splitlines() if x.startswith('failure:')]
        assert not lines or lines[0].split(':')[1].startswith('!'), 'Failed copy has usable credentials'
        status, body = request(dp, '/acl/cluster-api.cgi', 'failure')
        assert b'ENTRY_REACHED' not in body, 'Failed copy can authenticate'
        print(f'PASS forkcgis={fork}: failed ACL save never activates account', flush=True)
        # Save each global ACL through the real cluster editor and real RPC.
        for kind, name, ext in [('user', 'restricted', 'acl'), ('user', 'ordinary', 'acl'), ('group', 'team', 'gacl')]:
            status, body = request(sp, '/cluster-webmin/save_acl.cgi', fields={
                '_acl_'+kind: name, '_acl_host': 1, '_acl_mod': '',
                'download_address_mode': 'public', 'api_only': 'forged/api.cgi'})
            write(task/f'save-{fork}-{name}.html', body.decode(errors='replace'))
            saved = (dst/f'{name}.{ext}').read_text()
            assert ('api_only=acl/cluster-api.cgi' in saved) == (name != 'ordinary'), 'Cluster save lost policy'
            assert 'forged' not in saved, 'Submitted policy accepted'
            assert 'download_address_mode=public' in saved, 'Ordinary permission edit failed'
        print(f'PASS forkcgis={fork}: cluster user/group global saves preserve stored API policy', flush=True)
        if '--groups' in sys.argv:
            # This path relies on the separately submitted group preservation fix.
            write(dst/'webmin.groups', 'members:restricted ordinary:acl::\n')
            write(src/'cluster-webmin/hosts/1/members.group', 'name=members\nmodules=acl\nownmods=\nmembers=restricted ordinary\n')
            status,body=request(sp,'/cluster-webmin/save_acl.cgi',fields={
                '_acl_group':'members','_acl_host':1,'_acl_mod':'',
                'download_address_mode':'public'})
            assert 'api_only=acl/cluster-api.cgi' in (dst/'restricted.acl').read_text(), 'Group propagation lost member policy'
            assert 'api_only=' not in (dst/'ordinary.acl').read_text(), 'Group propagation leaked sibling policy'
            print(f'PASS forkcgis={fork}: #2920 integration preserves individual API policies during cluster group edits',flush=True)
        stop()
finally:
    stop()
if '--postgresql' in sys.argv:
    # Exercise actual SQL storage with a generated guest-only database and role.
    name = 'webmin_cluster_fixture_' + str(os.getpid())
    dbpass = secrets.token_hex(24)
    created_role = created_db = False

    def psql(query, database='postgres'):
        """Execute fixture SQL as the guest postgres administrator."""
        p = subprocess.run(['runuser', '-u', 'postgres', '--', 'psql', '-X', '-At',
            '-v', 'ON_ERROR_STOP=1', '-d', database], input=query.encode(),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd='/tmp')
        if p.returncode:
            raise RuntimeError('Fixture SQL failed: '+p.stderr.decode().replace(dbpass, '[redacted]'))
        return p.stdout.decode().strip()

    try:
        psql(f"CREATE ROLE {name} LOGIN PASSWORD '{dbpass}';")
        created_role = True
        psql(f'CREATE DATABASE {name} OWNER {name};')
        created_db = True
        schema = f'SET ROLE {name};'
        for kind in ('user', 'group'):
            field = 'pass' if kind == 'user' else 'description'
            schema += f'CREATE TABLE webmin_{kind} (id serial PRIMARY KEY, name text, {field} text);'
            schema += f'CREATE TABLE webmin_{kind}_attr (id int, attr text, value text, PRIMARY KEY(id,attr));'
            schema += f'CREATE TABLE webmin_{kind}_acl (id int, module text, attr text, value text, PRIMARY KEY(id,module,attr));'
        schema += "ALTER SEQUENCE webmin_user_id_seq RESTART WITH 42;"
        psql(schema, name)
        src, sp = start('sqlsource', 0)
        dst, dp = start('sqldestination', 0)
        # Cached PostgreSQL RPC connections have a separate commit bug on master.
        with (dst/'miniserv.conf').open('a') as f:
            f.write('userdb_nocache=1\n')
            f.write(f'userdb=postgresql://{name}:{dbpass}@127.0.0.1/{name}\n')
        os.kill(processes[-1].pid, signal.SIGUSR1)
        config(src/'servers/1.serv', {'id':1, 'host':'127.0.0.1', 'port':dp,
            'ssl':0, 'fast':1, 'user':'admin', 'pass':password})
        with (src/'users').open('a') as f:
            f.write(f'restricted:{hashed}\nordinary:{hashed}\nfailure:{hashed}\n')
        with (src/'webmin.acl').open('a') as f:
            f.write('restricted: acl\nordinary: acl\nfailure: acl\n')
        for u in ('restricted', 'ordinary', 'failure'):
            write(src/'acl'/f'{u}.acl', 'users=self\n')
            write(src/f'{u}.acl', 'rpc=0\n'+('api_only=acl/cluster-api.cgi\n' if u != 'ordinary' else ''))
        write(src/'webmin.groups', 'team::acl::\n')
        write(src/'team.gacl', 'api_only=acl/cluster-api.cgi\n')
        cache(src, 0, ['restricted', 'ordinary', 'failure'], ['team'])
        cache(src, 1, [])
        checked(sp, dict(server=1, users_mode=2, usel='restricted ordinary', groups_mode=1), 'sqlsync')
        count = psql("select count(*) from webmin_user where name in ('restricted','ordinary')",name)
        assert count=='2', 'SQL account count: '+repr(count)+'; names: '+psql('select id,name from webmin_user',name)
        assert psql("select value from webmin_user_acl a join webmin_user u using(id) where name='restricted' and module='' and attr='api_only'",name)=='acl/cluster-api.cgi', 'SQL policy missing'
        assert not (dst/'restricted.acl').exists(), 'SQL ACL saved to local file'
        for user in ('restricted','ordinary'):
            status, body=request(dp,'/acl/cluster-api.cgi',user)
            assert status==200 and b'ENTRY_REACHED' in body, 'SQL API failed'
            status, body=request(dp,'/acl/cluster-ui.cgi',user)
            assert (b'ENTRY_REACHED' in body)==(user=='ordinary'), 'SQL UI policy failed'
        print('PASS PostgreSQL: copied accounts activate with destination IDs; API/UI policy enforced',flush=True)
        for kind, user in [('user','restricted'),('user','ordinary'),('group','team')]:
            status,body=request(sp,'/cluster-webmin/save_acl.cgi',fields={
                '_acl_'+kind:user,'_acl_host':1,'_acl_mod':'','api_only':'forged/api.cgi',
                'download_address_mode':'public'})
            write(task/f'sql-save-{user}.html',body.decode(errors='replace'))
            expected='' if user=='ordinary' else 'acl/cluster-api.cgi'
            value=psql(f"select value from webmin_{kind}_acl a join webmin_{kind} u using(id) where name='{user}' and module='' and attr='api_only'",name)
            assert value==expected, 'SQL editor changed policy'
            assert psql(f"select value from webmin_{kind}_acl a join webmin_{kind} u using(id) where name='{user}' and module='' and attr='download_address_mode'",name)=='public', 'SQL edit missing'
        print('PASS PostgreSQL: cluster editor saves user/group ACLs in database and retains restrictions',flush=True)
        psql("CREATE FUNCTION reject_fixture() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.attr = 'api_only' AND EXISTS(SELECT 1 FROM webmin_user WHERE id=NEW.id AND name='failure') THEN RAISE EXCEPTION 'fixture ACL rejection'; END IF; RETURN NEW; END $$; CREATE TRIGGER reject_fixture BEFORE INSERT ON webmin_user_acl FOR EACH ROW EXECUTE FUNCTION reject_fixture();",name)
        checked(sp,dict(server=1,users_mode=2,usel='failure'),'sqlfailure')
        assert psql("select count(*) from webmin_user where name='failure' and pass not like '!%'",name)=='0', 'SQL failed transfer activated'
        print('PASS PostgreSQL: injected ACL write failure prevents activation',flush=True)
    finally:
        stop()
        if created_db:
            psql(f'DROP DATABASE {name} WITH (FORCE);')
        if created_role:
            psql(f'DROP ROLE {name};')
    print('PASS PostgreSQL database, role and listeners removed',flush=True)

for port in ports:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=.2):
            raise RuntimeError('Fixture listener remains')
    except ConnectionRefusedError:
        pass
print('PASS all fixture listeners stopped', flush=True)
