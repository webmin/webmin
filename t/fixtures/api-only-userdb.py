"""Point an isolated sandbox at a throwaway SQL user database on a Linux guest.

Usage: python3 api-only-userdb.py /tmp/task-directory mysql|postgresql setup|cleanup
Prepare the directory with api-only-sandbox.py first. setup creates a database
and login named after the task directory, installs Webmin's user tables, sets
userdb in the sandbox's miniserv.conf and reloads only that server. Rerun the
account fixtures afterwards to exercise database-backed logins. cleanup removes
the sandbox setting and drops the database and login. The guest's own Webmin
configuration is never changed. Never run on the workstation.
"""
from pathlib import Path
import os, secrets, signal, subprocess, sys, time
if sys.platform != 'linux' or os.geteuid() != 0:
 raise RuntimeError('Run only as root inside a disposable Linux test guest')
if len(sys.argv) != 4 or sys.argv[2] not in ('mysql','postgresql') or sys.argv[3] not in ('setup','cleanup'):
 raise RuntimeError('Usage: api-only-userdb.py TASK-DIRECTORY mysql|postgresql setup|cleanup')
task=Path(sys.argv[1]).resolve(); kind=sys.argv[2]; mode=sys.argv[3]
if not any(base in task.parents for base in (Path('/tmp'),Path('/var/tmp'))):
 raise RuntimeError('Use the isolated task directory under /tmp or /var/tmp')
conf=task/'config'/'miniserv.conf'
if not (task/'miniserv.pid').is_file() or not conf.is_file():
 raise RuntimeError('Prepare an isolated server with api-only-sandbox.py first')
os.umask(0o077)
# The database and its login are named after the task directory so parallel
# sandboxes never share state.
name='webmin_apitest_'+''.join(c for c in task.name.lower() if c.isalnum())[-8:]
secret=task/'userdb-password'
# Webmin's own schema for each backend, from userdb_table_sql in acl/acl-lib.pl.
if kind=='mysql':
 schema=["create table webmin_user (id int(20) not null primary key auto_increment, name varchar(255) not null, pass varchar(255))",
  "create table webmin_group (id int(20) not null primary key auto_increment, name varchar(255) not null, description varchar(255))",
  "create table webmin_user_attr (id int(20) not null, attr varchar(255) not null, value varchar(4096), primary key(id, attr))",
  "create table webmin_group_attr (id int(20) not null, attr varchar(255) not null, value varchar(4096), primary key(id, attr))",
  "create table webmin_user_acl (id int(20) not null, module varchar(32) not null, attr varchar(32) not null, value varchar(255), primary key(id, module, attr))",
  "create table webmin_group_acl (id int(20) not null, module varchar(32) not null, attr varchar(32) not null, value varchar(255), primary key(id, module, attr))"]
else:
 schema=["create table webmin_user (id serial not null primary key, name varchar(255), pass varchar(255))",
  "create table webmin_group (id serial not null primary key, name varchar(255), description varchar(255))",
  "create table webmin_user_attr (id int8 not null, attr varchar(255) not null, value varchar(4096), primary key(id, attr))",
  "create table webmin_group_attr (id int8 not null, attr varchar(255) not null, value varchar(4096), primary key(id, attr))",
  "create table webmin_user_acl (id int8 not null, module varchar(255) not null, attr varchar(255) not null, value varchar(255), primary key(id, module, attr))",
  "create table webmin_group_acl (id int8 not null, module varchar(255) not null, attr varchar(255) not null, value varchar(255), primary key(id, module, attr))"]
mysql_defaults=None
def mysql_command():
 """mysql_command(): return a mysql client command that logs in as the administrator.

 Root's Unix socket login is tried first. Otherwise the guest Webmin MySQL
 module's saved administrator login is written to a mode-0600 defaults file in
 the task directory, so the password never appears on a command line.
 """
 global mysql_defaults
 if mysql_defaults is None:
  probe=subprocess.run(['mysql','--batch','-e','select 1'],capture_output=True,text=True)
  if probe.returncode==0:
   mysql_defaults=''
  else:
   module=dict(line.split('=',1) for line in Path('/etc/webmin/mysql/config').read_text().splitlines() if '=' in line)
   path=task/'mysql-defaults.cnf'
   path.write_text('[client]\nuser='+module.get('login','root')+'\npassword='+module.get('pass','')+'\n')
   mysql_defaults='--defaults-extra-file='+str(path)
 return ['mysql']+([mysql_defaults] if mysql_defaults else [])+['--batch']
def sql(statements, database=None):
 """sql(statements, [database]): run SQL as the local database superuser.

 database defaults to the server's administrative database. Statements,
 including any generated password, travel on stdin and never on a command line.
 """
 text=';\n'.join(statements)+';\n'
 if kind=='mysql':
  cmd=mysql_command()+([database] if database else [])
 else:
  cmd=['runuser','-u','postgres','--','psql','-v','ON_ERROR_STOP=1','-q','-d',database or 'postgres']
 result=subprocess.run(cmd,input=text,text=True,capture_output=True)
 if result.returncode:
  # Report the server's message without echoing the submitted statements.
  raise RuntimeError(kind+' statement failed: '+result.stderr.strip()[-500:])
def configure(userdb):
 """configure(userdb): set or remove the sandbox userdb and reload that server."""
 lines=[line for line in conf.read_text().splitlines() if not line.startswith('userdb=')]
 if userdb is not None:
  lines.append('userdb='+userdb)
 conf.write_text(''.join(line+'\n' for line in lines))
 os.kill(int((task/'miniserv.pid').read_text()),signal.SIGUSR1)
 time.sleep(.5)
if mode=='setup':
 password=secrets.token_urlsafe(24)  # URL-safe characters keep the userdb string parseable
 secret.write_text(password)
 if kind=='mysql':
  sql(['create database '+name,"create user '"+name+"'@'localhost' identified by '"+password+"'",
       'grant all on '+name+'.* to '+"'"+name+"'@'localhost'",'flush privileges'])
  sql(schema,name)
 else:
  sql(['create user '+name+" with password '"+password+"'",'create database '+name+' owner '+name])
  # Tables belong to the superuser; the login needs both table and sequence rights.
  sql(schema+['grant all on all tables in schema public to '+name,
      'grant all on all sequences in schema public to '+name],name)
 configure(kind+'://'+name+':'+password+'@localhost/'+name)
 print('Sandbox now authenticates against '+kind+' database '+name)
else:
 configure(None)
 if kind=='mysql':
  sql(['drop database if exists '+name,"drop user if exists '"+name+"'@'localhost'"])
 else:
  sql(['drop database if exists '+name,'drop user if exists '+name])
 secret.unlink(missing_ok=True)
 (task/'mysql-defaults.cnf').unlink(missing_ok=True)
 print('Sandbox restored to file-based accounts; dropped '+kind+' database '+name)
