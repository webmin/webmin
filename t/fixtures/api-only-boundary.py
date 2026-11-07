"""Test API-only request boundaries on an isolated Linux guest installation.

Usage: python3 api-only-boundary.py /tmp/task-directory
Prepare the directory with api-only-sandbox.py first. The test temporarily
changes only that copy's miniserv settings and removes its fixture accounts.
Run on a disposable guest, never against a workstation or production server.
"""
from pathlib import Path
import http.client as httpclient
import os, signal, socket, sys, threading, time
# Load the repository fixture's real form client, without its test sequence.
if sys.platform != 'linux' or os.geteuid() != 0:
 raise RuntimeError('Run only as root inside a disposable Linux test guest')
p=Path(sys.argv[1]).resolve()
if not any(base in p.parents for base in (Path('/tmp'),Path('/var/tmp'))):
 raise RuntimeError('Use the isolated task directory under /tmp or /var/tmp')
if not (p/'miniserv.pid').is_file() or not (p/'root/miniserv.pl').is_file():
 raise RuntimeError('Prepare an isolated server with api-only-sandbox.py first')
exec(compile((p/'api-only-live.py').read_text().split('\ntry:\n',1)[0],str(p/'api-only-live.py'),'exec'))
root=p/'root'; conf=p/'config'; failures=[]
def verify(ok, label, detail=''):
 """verify(ok, label, [detail]): report an assertion with redacted details."""
 print(('PASS: ' if ok else 'FAIL: ')+label,flush=True)
 if not ok:
  failures.append(label)
  if detail: print(redact(str(detail))[:500],flush=True)
def configure(**kwargs):
 """configure(**settings): reload only the isolated miniserv configuration."""
 f=conf/'miniserv.conf'
 d=dict(x.split('=',1) for x in f.read_text().splitlines() if '=' in x)
 d.update(kwargs); f.write_text(''.join(k+'='+str(v)+'\n' for k,v in d.items()))
 os.kill(int((p/'miniserv.pid').read_text()),signal.SIGUSR1)
 time.sleep(.3)
def http(target, who='user', method='GET', data=None, extra=None, cookie=None):
 """http(target, [who], [method], [data], [extra], [cookie]): make a request.

 Use fixture Basic auth by default, or the supplied session cookie. Return
 the status, headers and body without printing credentials.
 """
 c=httpclient.HTTPConnection('127.0.0.1',18443,timeout=15)
 headers={'User-Agent':'Webmin deep test','Referer':base+'acl/edit_user.cgi'}
 if cookie:
  headers['Cookie']=cookie; headers['User-Agent']='Mozilla/5.0'
 elif who: headers['Authorization']='Basic '+base64.b64encode((fixture[who]+':'+fixture[who+'_password']).encode()).decode()
 if data is not None:
  data=urllib.parse.urlencode(data); headers['Content-Type']='application/x-www-form-urlencoded'
 headers.update(extra or {})
 c.request(method,'/'+target,data,headers); r=c.getresponse(); result=(r.status,dict(r.getheaders()),r.read().decode(errors='replace')); c.close(); return result
try:
 helper('setup')
 userform='acl/edit_user.cgi?user='+fixture['user']
 groupform='acl/edit_group.cgi?group='+fixture['group']
 # Confirm group edits actually affect existing members, rather than only the
 # stored group record.
 edit(userform,'save_user.cgi',{'api_only_def':'1'})
 edit(userform,'save_user.cgi',{'group':fixture['group']})
 edit(groupform,'save_group.cgi',{'api_only_def':'0','api_only':endpoint})
 verify(state()['user']['api_only']==endpoint,'group restriction reaches existing members',state())
 status,page=request(userform)
 verify('name="api_only"' not in page,'grouped-user endpoint is not offered as editable')
 edit(userform,'save_user.cgi',{'group':''})
 edit(userform,'save_user.cgi',{'api_only_def':'0','api_only':'deep-api.cgi'})
 # Approved endpoint, non-opted-in CGI, wrong opt-in and CGI without Webmin
 # initialization distinguish policy decisions from generic authentication.
 scripts={
 'deep-api.cgi':"$main::allow_api_only='deep-api.cgi'; use WebminCore; &init_config(); print \"Content-type: text/plain\\n\\nDEEP_ALLOWED\\n\";",
 'deep-wrong.cgi':"$main::allow_api_only='deep-wrong.cgi'; use WebminCore; &init_config(); print \"Content-type: text/plain\\n\\nDEEP_WRONG\\n\";",
 'deep-plain.cgi':"use WebminCore; &init_config(); print \"Content-type: text/plain\\n\\nDEEP_PLAIN\\n\";",
 'deep-noinit.cgi':"print \"Content-type: text/plain\\n\\nDEEP_NOINIT\\n\";"}
 for name,source in scripts.items():
  f=root/name; f.write_text('#!/usr/bin/perl\nuse lib '+repr(str(root))+';\n'+source+'\n'); f.chmod(0o755)
 for fork in ('0','1'):
  configure(forkcgis=fork)
  for name in scripts:
   status,headers,body=http(name)
   verify(status==200 and 'DEEP_ALLOWED' in body if name=='deep-api.cgi' else status==403 and 'DEEP_' not in body,f'fork={fork} {name} status={status}',body)
  for target in ('index.cgi','rpc.cgi','fastrpc.cgi','xmlrpc.cgi','acl/index.cgi','deep-api.cgi/../rpc.cgi','%72pc.cgi','//rpc.cgi'):
   status,headers,body=http(target)
   verify(status in (400,403,404) and 'DEEP_ALLOWED' not in body,f'fork={fork} deny {target} status={status}',body)
  for method in ('POST','HEAD'):
   status,headers,body=http('deep-plain.cgi',method=method,data={'allow_api_only':'deep-api.cgi','api_only':'deep-api.cgi'} if method=='POST' else None,extra={'Allow-Api-Only':'deep-api.cgi'})
   verify(status==403 and 'DEEP_PLAIN' not in body,f'fork={fork} {method} cannot supply opt-in status={status}',body)
 # The configured path must still opt in. This reaches the CGI guard rather
 # than being rejected by the earlier server path check.
 edit(userform,'save_user.cgi',{'api_only_def':'0','api_only':'deep-plain.cgi'})
 for fork in ('0','1'):
  configure(forkcgis=fork)
  status,headers,body=http('deep-plain.cgi',method='POST',data={'allow_api_only':'deep-plain.cgi'})
  verify(status==403 and 'DEEP_PLAIN' not in body,f'fork={fork} configured CGI without opt-in is denied',body)
 edit(userform,'save_user.cgi',{'api_only_def':'0','api_only':'deep-api.cgi'})
 configure(forkcgis='0')
 # Static files and DAV are also outside the single permitted endpoint.
 (root/'deep-private.txt').write_text('DEEP_STATIC')
 status,headers,body=http('deep-private.txt')
 verify(status==403 and 'DEEP_STATIC' not in body,'authenticated static route is denied',body)
 configure(davpaths='/deep-dav',dav_root=str(p),dav_remoteuser='0')
 status,headers,body=http('deep-dav/',method='PROPFIND')
 verify(status==403,'DAV route is denied before its handler',body)
 configure(davpaths='')
 # The server handles session login before dispatching the CGI. Retain the
 # cookie entirely within the guest and test every access path with it.
 status,headers,body=http('session_login.cgi',who=None,method='POST',data={'user':fixture['user'],'pass':fixture['user_password']},extra={'Cookie':'testing=1','User-Agent':'Mozilla/5.0'})
 cookie=headers.get('Set-Cookie','').split(';')[0]
 verify(cookie.startswith('sid='),'real session login creates a cookie',{'status':status,'body':body[:200]})
 if cookie.startswith('sid='):
  for name in ('deep-api.cgi','index.cgi','rpc.cgi','deep-noinit.cgi'):
   status,headers,body=http(name,cookie=cookie)
   verify(status==200 and 'DEEP_ALLOWED' in body if name=='deep-api.cgi' else status==403 and 'DEEP_' not in body,'session '+name+f' status={status}',body)
  edit(userform,'save_user.cgi',{'api_only_def':'1'})
  status,headers,body=http('index.cgi',cookie=cookie)
  verify(status==200 and 'restricted to its configured API' not in body,'existing session sees explicit policy clearing',body)
  edit(userform,'save_user.cgi',{'api_only_def':'0','api_only':'deep-api.cgi'})
  status,headers,body=http('index.cgi',cookie=cookie)
  verify(status==403,'existing session sees newly applied API restriction',body)
 # A configured WebSocket route with no user list accepts any authenticated
 # login today. A harmless backend records whether API-only credentials reach it.
 listener=socket.socket(); listener.bind(('127.0.0.1',0)); listener.listen(); listener.settimeout(3)
 reached=[]
 def backend():
  """backend(): record any request forwarded past the WebSocket guard."""
  try:
   c,_=listener.accept(); reached.append(True); c.recv(8192); c.sendall(b'HTTP/1.1 400 Test backend reached\r\nContent-Length: 0\r\n\r\n'); c.close()
  except socket.timeout: pass
 configure(**{'websockets_/deep-socket':f'host=127.0.0.1 port={listener.getsockname()[1]} path=/deep-socket'})
 t=threading.Thread(target=backend); t.start()
 status,headers,body=http('deep-socket',extra={'Upgrade':'websocket','Connection':'Upgrade','Origin':base.rstrip('/'),'Sec-WebSocket-Key':'dGhlIHNhbXBsZSBub25jZQ==','Sec-WebSocket-Version':'13'})
 t.join(); listener.close()
 verify(status==403 and not reached,'WebSocket denied before reaching backend',{'status':status,'backend_reached':bool(reached)})
 # Ordinary users remain able to render existing administration pages.
 for target in ('index.cgi','acl/index.cgi',userform,groupform):
  status,headers,body=http(target,who='admin')
  verify(status==200 and 'restricted to its configured API' not in body,'ordinary admin '+target.split('?')[0],body)
finally:
 configure(forkcgis='0',davpaths='',**{'websockets_/deep-socket':''})
 helper('cleanup'); path.unlink(missing_ok=True)
 for name in ('deep-api.cgi','deep-wrong.cgi','deep-plain.cgi','deep-noinit.cgi','deep-private.txt'): (root/name).unlink(missing_ok=True)
print('Deep checks finished; failures:',len(failures),flush=True)
if failures: raise SystemExit(1)
