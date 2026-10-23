"""Test new API account creation through Webmin Users on an isolated guest.

Usage: python3 api-only-create.py /tmp/task-directory
Prepare the directory with api-only-sandbox.py. Never run on the workstation.
"""
from pathlib import Path
import os, signal, sys, time
if sys.platform != 'linux' or os.geteuid() != 0:
 raise RuntimeError('Run only inside a disposable Linux test guest')
task=Path(sys.argv[1]).resolve()
if not any(base in task.parents for base in (Path('/tmp'),Path('/var/tmp'))):
 raise RuntimeError('Use the isolated task directory')
exec(compile((task/'api-only-live.py').read_text().split('\ntry:\n',1)[0],str(task/'api-only-live.py'),'exec'))
root=task/'root'
cgi=root/'new-api.cgi'
failures=[]
def verify(ok,message,details=''):
 """verify(ok, message, [details]): record a failure without exposing secrets."""
 print(('PASS: ' if ok else 'FAIL: ')+message,flush=True)
 if not ok:
  failures.append(message)
  if details: print(redact(str(details))[:500],flush=True)
try:
 helper('setup')
 cgi.write_text('#!/usr/bin/perl\nuse lib '+repr(str(root))+";\n$main::allow_api_only='new-api.cgi'; use WebminCore; &init_config(); print \"Content-type: text/plain\\n\\nNEW_API_OK\\n\";\n")
 cgi.chmod(0o755)
 fields={'name':fixture['clone'],'pass_def':'0','pass':fixture['user_password'],
         'mod':'acl','rpc':'1','group':'','api_only_def':'0','api_only':'new-api.cgi'}
 status,page=edit('acl/edit_user.cgi','save_user.cgi',fields)
 verify(state()['clone']['exists'] and state()['clone']['api_only']=='new-api.cgi','new API user is created with its restriction',page)
 status,page=request('new-api.cgi',who='user',username=fixture['clone'])
 verify(status==200 and 'NEW_API_OK' in page,'new API credential works immediately after creation',page)
 for target in ('index.cgi','acl/index.cgi','rpc.cgi','fastrpc.cgi','xmlrpc.cgi'):
  status,page=request(target,who='user',username=fixture['clone'])
  verify(status==403,'new API account cannot open '+target,page)
 edit('acl/edit_user.cgi?user='+fixture['clone'],'save_user.cgi',{'real':'New API account edited'})
 verify(state()['clone']['api_only']=='new-api.cgi','normal edit preserves a newly created API account')
 status,page=request('new-api.cgi',who='user',username=fixture['clone'])
 verify(status==200 and 'NEW_API_OK' in page,'API remains usable after normal edit',page)
 # A mistyped endpoint must be rejected before creating a usable login.
 fields.update(name=fixture['renamed'],api_only='../rpc.cgi')
 status,page=edit('acl/edit_user.cgi','save_user.cgi',fields)
 verify(not state()['renamed']['exists'],'invalid endpoint does not leave an unrestricted new account',page)
 # New members of an API-only group must inherit the restriction too.
 edit('acl/edit_group.cgi?group='+fixture['group'],'save_group.cgi',{'api_only_def':'0','api_only':'new-api.cgi'})
 fields.update(name=fixture['renamed'],group=fixture['group'],api_only='new-api.cgi')
 status,page=edit('acl/edit_user.cgi','save_user.cgi',fields)
 verify(state()['renamed']['exists'],'new group member is created',page)
 status,page=request('new-api.cgi',who='user',username=fixture['renamed'])
 verify(status==200 and 'NEW_API_OK' in page,'new API group member can use the endpoint',page)
 status,page=request('index.cgi',who='user',username=fixture['renamed'])
 verify(status==403,'new API group member cannot open the UI',page)
 # Restart only the isolated instance and verify saved credentials and policy.
 os.kill(int((task/'miniserv.pid').read_text()),signal.SIGHUP)
 for attempt in range(50):
  time.sleep(.1)
  try:
   status,page=request('new-api.cgi',who='user',username=fixture['clone'])
   if status==200 and 'NEW_API_OK' in page: break
  except OSError: pass
 else: raise RuntimeError('Isolated API endpoint did not recover after restart')
 verify(status==200 and 'NEW_API_OK' in page,'new API account works after Webmin restart',page)
 status,page=request('index.cgi',who='user',username=fixture['clone'])
 verify(status==403,'new API account remains restricted after restart',page)
finally:
 helper('cleanup');path.unlink(missing_ok=True);cgi.unlink(missing_ok=True)
print('New-account failures:',len(failures),flush=True)
if failures: raise SystemExit(1)
