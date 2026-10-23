"""Create a loopback Webmin copy on a disposable Linux guest, never locally.

Usage: python3 api-only-sandbox.py /tmp/task-directory
The directory must contain candidate.tar with the source files being tested.
The guest needs an installed Webmin with its config in /etc/webmin; the
Webmin root is read from that miniserv.conf, so Debian and RPM layouts work.

This starts a separate server on 127.0.0.1:18443 and prepares the lifecycle
fixtures in the task directory. Run api-only-live.py and api-only-boundary.py
with that directory as their argument. Stop the PID in miniserv.pid before
removing the task directory; it contains copies of the guest's configuration.
"""
from pathlib import Path
import os, shutil, subprocess, sys, tarfile
if sys.platform != 'linux' or os.geteuid() != 0:
 raise RuntimeError('Run only as root inside a disposable Linux test guest')
p=Path(sys.argv[1]).resolve()
if not any(base in p.parents for base in (Path('/tmp'),Path('/var/tmp'))):
 raise RuntimeError('Use a task directory under /tmp or /var/tmp')
os.umask(0o077)
# Debian and RPM packages install Webmin under different roots.
installed=dict(line.split('=',1) for line in Path('/etc/webmin/miniserv.conf').read_text().splitlines() if '=' in line).get('root','/usr/share/webmin')
root=p/'root'; conf=p/'config'; var=p/'var'
if root.exists():
 raise RuntimeError('Refusing to replace an existing fixture installation')
subprocess.run(['cp','-a',installed,str(root)],check=True)
subprocess.run(['cp','-a','/etc/webmin',str(conf)],check=True)
var.mkdir()
# Isolate daemon state, credentials and module configuration in the fixture.
for f in conf.rglob('*'):
 if f.is_file() and not f.is_symlink():
  data=f.read_bytes()
  data=data.replace(b'/etc/webmin',str(conf).encode()).replace(b'/var/webmin',str(var).encode()).replace(installed.encode(),str(root).encode())
  f.write_bytes(data)
with tarfile.open(p/'candidate.tar') as tar:
 for item in tar.getmembers():
  assert item.isfile() and not Path(item.name).is_absolute() and '..' not in Path(item.name).parts
  dest=root/item.name
  assert root.resolve() in dest.resolve().parents
  dest.parent.mkdir(parents=True,exist_ok=True)
  dest.write_bytes(tar.extractfile(item).read()); dest.chmod(item.mode)
# Keep only fixture authentication data. Never copy guest login credentials out.
(conf/'miniserv.users').write_text('')
(conf/'webmin.acl').write_text('')
(conf/'webmin.groups').write_text('')
values=dict(line.split('=',1) for line in (conf/'miniserv.conf').read_text().splitlines() if '=' in line)
for k in list(values):
 if k.startswith(('websockets_','preroot_')) or k in ('pam','pamany','userdb','unixauth','sudo','certfile','keyfile','extracas','extracas_','ca','logout','inetd','ipv6','listen','passdelay','blockhost_failures','blockuser_failures','blockhost_time','blockuser_time'):
  values.pop(k,None)
values.update(port='18443',bind='127.0.0.1',ssl='0',root=str(root),pidfile=str(p/'miniserv.pid'),logfile=str(p/'miniserv.log'),errorlog=str(p/'miniserv.error'),sessiondb=str(p/'sessions'),env_WEBMIN_CONFIG=str(conf),env_WEBMIN_VAR=str(var),userfile=str(conf/'miniserv.users'),forkcgis='0',internalcgis='0',session='1',nofork='0',log='1',logclear='0',syslog='0',passdelay='0',blockhost_failures='0',blockuser_failures='0',allow='127.0.0.1',ssl_hsts='0')
(conf/'miniserv.conf').write_text(''.join(k+'='+v+'\n' for k,v in values.items()))
# Reuse real lifecycle fixtures with only installation paths and URL adapted.
for name in ('api-only-account.pl','api-only-live.py'):
 s=(root/'t/fixtures'/name).read_text()
 s=s.replace('/usr/share/webmin',str(root)).replace(installed,str(root)).replace('/etc/webmin',str(conf)).replace('/var/webmin',str(var)).replace('https://127.0.0.1:10000/','http://127.0.0.1:18443/')
 (p/name).write_text(s)
# Avoid scripts with a build-host Perl path when testing forked CGI execution.
for f in root.rglob('*.cgi'):
 if f.is_file() and not f.is_symlink():
  data=f.read_bytes()
  if data.startswith(b'#!/usr/local/bin/perl'):
   f.write_bytes(data.replace(b'#!/usr/local/bin/perl',b'#!/usr/bin/perl',1))
print('Isolated source, configuration and lifecycle fixtures prepared')
subprocess.run(['perl',str(root/'miniserv.pl'),str(conf/'miniserv.conf')],check=True,timeout=30)
print('Fixture miniserv started on guest loopback port 18443')
