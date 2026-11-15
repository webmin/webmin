#!/usr/bin/env python3
"""Run isolated old/new miniserv RPC peers on a disposable Linux VM."""
import base64
import hashlib
import io
import http.client
import ssl
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import subprocess
import sys
import tempfile
import tarfile
import threading
import time
import urllib.parse

source, legacy = map(Path, sys.argv[1:3])
if sys.platform != 'linux' or os.geteuid() != 0:
    # Namespace and installer tests require an explicitly selected Linux guest.
    raise SystemExit('Run on a disposable root Linux VM')
fixture = Path(__file__).with_name('rpc-tls-client.pl')
processes = []
count = 0
failures = 0


# check(ok, description, [detail]): emit TAP, adding diagnostics on failure.
def check(ok, description, detail=''):
    global count, failures
    count += 1
    print(('ok' if ok else 'not ok') + f' {count} - {description}', flush=True)
    if not ok:
        # Keep diagnostics valid TAP and retain a failing final exit status.
        failures += 1
        for line in str(detail).splitlines():
            print('# ' + line, flush=True)


# config(path, values): write a fixture's Webmin key=value configuration.
def config(path, values):
    path.write_text(''.join(f'{key}={value}\n' for key, value in values.items()))


with tempfile.TemporaryDirectory(prefix='rpc-tls-live-') as temporary:
    # Keep fixture credentials and all peer data inside a private directory.
    task = Path(temporary)
    password = secrets.token_urlsafe(32)
    hashed = subprocess.check_output(
        ['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$rpctls$));'],
        input=password.encode()).decode()
    cert = task/'cert.pem'
    key = task/'key.pem'
    # Create the shared HTTPS identity used by the primary and file listeners.
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                    '-keyout', str(key), '-out', str(cert), '-days', '1',
                    '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    other_key, other_cert = task/'ca-key.pem', task/'ca-cert.pem'
    # A separate identity serves both mismatch tests and CA signing tests.
    subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                    '-keyout', str(other_key), '-out', str(other_cert), '-days', '1',
                    '-subj', '/CN=RPC Fixture CA'], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    csr, signed = task/'server.csr', task/'signed.pem'
    # Sign the same server key to exercise existing CA and hostname checks.
    subprocess.run(['openssl', 'req', '-new', '-key', str(key), '-out', str(csr),
                    '-subj', '/CN=localhost'], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['openssl', 'x509', '-req', '-in', str(csr), '-CA', str(other_cert),
                    '-CAkey', str(other_key), '-CAcreateserial', '-days', '1',
                    '-out', str(signed)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    der = subprocess.check_output(['openssl', 'x509', '-in', str(cert), '-outform', 'DER'])
    # Saved-fingerprint tests use the digest of the exact HTTPS certificate.
    pin = hashlib.sha256(der).hexdigest()
    try:
        peers = {}
        # Each protocol/version combination gets its own configuration and port.
        for name, root, use_ssl in [('new', source, 1), ('old', legacy, 1),
                                ('http', source, 0), ('ca', source, 1)]:
            conf = task/name/'config'
            var = task/name/'var'
            conf.mkdir(parents=True)
            (var/'locks').mkdir(parents=True)
            for module in ('webmin', 'servers'):
                (conf/module).mkdir()
            with socket.socket() as sock:
                # Ask the kernel for an unused port before starting miniserv.
                sock.bind(('127.0.0.1', 0))
                port = sock.getsockname()[1]
            config(conf/'config', dict(os_type='generic-linux', os_version=0,
                   lang='en', log=0, tempdir=var/'tmp', rpc_timeout=3, rpc_idle_factor=2))
            (conf/'var-path').write_text(str(var)+'\n')
            config(conf/'servers/config', dict(capath=other_cert))
            (conf/'perl-path').write_text('/usr/bin/perl\n')
            (conf/'version').write_text((root/'version').read_text())
            (conf/'bootscript-name').write_text(f'webmin-rpc-tls-test-{os.getpid()}\n')
            # Listen on loopback and vary TLS restrictions for targeted checks.
            config(conf/'miniserv.conf', dict(port=port, bind='127.0.0.1',
                   root=root, ssl=use_ssl, keyfile=key, certfile=signed if name == 'ca' else cert,
                   pidfile=var/'pid', logfile=var/'requests', errorlog=var/'errors',
                   userfile=conf/'miniserv.users', env_WEBMIN_CONFIG=conf,
                   env_WEBMIN_VAR=var, session=0, passdelay=0, no_pam=1, syslog=0,
                   log=0, forkcgis=0, addtype_cgi='internal/cgi', no_tls1_2=int(name == 'new'),
                   ssl_cipher_list='ECDHE-RSA-AES128-GCM-SHA256' if name == 'ca' else '',
                   allow='127.0.0.1', precache='none', no_ssl2=1, no_ssl3=1))
            (conf/'miniserv.users').write_text(f'admin:{hashed}:0\ndenied:{hashed}:0\n')
            # The denied account can authenticate but cannot use the RPC API.
            (conf/'webmin.acl').write_text('admin: webmin servers\ndenied: webmin\n')
            (conf/'webmin.groups').write_text('')
            config(conf/'admin.acl', dict(rpc=1))
            config(conf/'denied.acl', dict(rpc=0))
            # A separate process group lets cleanup stop all fixture workers.
            log = open(var/'launcher.log', 'w')
            process = subprocess.Popen(['perl', str(root/'miniserv.pl'), '--nofork',
                str(conf/'miniserv.conf')], stdin=subprocess.DEVNULL, stdout=log,
                stderr=log, start_new_session=True)
            processes.append(process)
            for attempt in range(100):
                if process.poll() is not None:
                    # Report startup failures instead of waiting for a port.
                    raise RuntimeError((var/'launcher.log').read_text())
                try:
                    with socket.create_connection(('127.0.0.1', port), timeout=.1):
                        break
                except OSError:
                    time.sleep(.1)
            else:
                # No connection succeeded within the bounded startup wait.
                raise RuntimeError('miniserv startup timed out')
            peers[name] = dict(conf=conf, var=var, port=port, ssl=use_ssl, process=process)

        # run(name, [mode], [client], **extra): run one client case and decode
        # its JSON result. Defaults are file tests and the changed client.
        # extra overrides fields in the target server definition.
        def run(name, mode='files', client=source, **extra):
            peer = peers[name]
            path = task/f'case-{count}'
            path.mkdir()
            server = dict(id=1, host='localhost', ip='127.0.0.1', port=peer['port'],
                          ssl=peer['ssl'], fast=1, user='admin', **{})
            server['pass'] = password
            server.update(extra)
            # Save per-case paths and credentials for the Perl client only.
            settings = path/'settings.json'
            settings.write_text(json.dumps(dict(server=server, path=str(path),
                                                blocks=512 if name == 'new' else 32,
                                                other_key=str(other_key), other_cert=str(other_cert),
                                                package=str(task/'upgrade.tar.gz'),
                                                extract=str(task/'upgraded'),
                                                boot=f'webmin-rpc-tls-test-{os.getpid()}')))
            settings.chmod(0o600)
            # Load the chosen client with its matching module configuration.
            client_peer = peers['old' if client == legacy else 'new']
            env = dict(os.environ, LIBROOT=str(client), WEBMIN_CONFIG=str(client_peer['conf']),
                       WEBMIN_VAR=str(client_peer['var']),
                       MINISERV_CONFIG=str(client_peer['conf']/'miniserv.conf'))
            for key in ('REMOTE_USER', 'BASE_REMOTE_USER', 'SCRIPT_NAME',
                        'REQUEST_METHOD', 'FOREIGN_MODULE_NAME', 'FOREIGN_ROOT_DIRECTORY'):
                env.pop(key, None)
            command = ['perl', str(fixture), str(client), str(settings), mode]
            if mode == 'local':
                # Disable IPv6 in a private network namespace, never on the VM host.
                command = ['unshare', '--net', '--', 'sh', '-ec',
                           'ip link set lo up; sysctl -q -w net.ipv6.conf.all.disable_ipv6=1; '
                           'perl -MSocket6 -e 1; exec "$@"', 'rpc-local'] + command
            proc = subprocess.run(command,
                                  env=env, capture_output=True, text=True, timeout=180)
            # Invalid JSON usually means the client failed before its handler.
            try:
                result = json.loads(proc.stdout)
            except ValueError:
                raise RuntimeError(proc.stdout + proc.stderr)
            if result.get('error'):
                # Attach only the failing peer's recent fixture diagnostics.
                result['server_log'] = (peer['var']/'errors').read_text()[-3000:]
            return result

        # Cover both upgrade orders and the unchanged plaintext HTTP path.
        for name, client, tls, https in [('new', source, 1, 0),
                 ('old', source, 0, 1), ('http', source, 0, 0),
                 ('new', legacy, 0, 0)]:
            label = f'{"old" if client == legacy else "new"} client / {name} server'
            result = run(name, client=client)
            check(str(result.get('call')) == '42' and not result.get('error'), label+' RPC', result)
            check(result.get('large_reply') == 1048576, label+' multi-record RPC response', result)
            check(result.get('tls') == tls and result.get('https') == https,
                  label+' transport selection', result)
            check(result.get('input') and result.get('input') == result.get('output'),
                  label+' binary file round trip', result)
            check(str(result.get('after_transfer')) == '42', label+' parent session survives transfers', result)
            check(result.get('empty') == 1, label+' empty file round trip', result)
            check(result.get('temporary_name') == 1 and result.get('base_name') == 1,
                  label+' temporary and requested base filenames', result)

        # Disk and open errors must propagate through TLS and HTTPS fallback.
        for name in ('new', 'old'):
            result = run(name, mode='errors')
            for error in ('remote_full', 'local_full', 'missing', 'unwritable'):
                check(bool(result.get(error)), name+' reports '+error, result)
            check('No space left' in result.get('remote_full', ''),
                  name+' upload reports the remote disk error', result)
            check('No such file' in result.get('unwritable', ''),
                  name+' upload reports the destination open error', result)
            check(str(result.get('after_errors')) == '42', name+' session survives file errors', result)
            check(result.get('preserved') == 'preserved',
                  name+' missing source preserves the destination', result)

        # Remote exceptions must preserve both session state and return values.
        for name in ('new', 'old'):
            result = run(name, mode='rpc_errors')
            for error_key, expected in [('eval_die', 'eval failure'), ('call_die', 'call failure'),
                                        ('call_error', 'module failure')]:
                check(expected in result.get(error_key, ''), name+' returns '+error_key, result)
            if name == 'old':
                # Missing modules previously killed the old HTTPS worker.
                check(bool(result.get('require_error')), name+' returns a module load error', result)
            check(result.get('values') == [None, '0', "quote'\\\n"] or
                  result.get('values') == [None, 0, "quote'\\\n"],
                  name+' preserves list values and quoting', result)
            check(result.get('context') == 'list' and result.get('eval_context') == 'scalar' and
                  str(result.get('after_rpc_errors')) == '42',
                  name+' preserves call context and survives remote errors', result)

        # The built-in client needs no IPv6 listener, even when configured.
        local_config = peers['new']['conf']/'miniserv.conf'
        original_config = local_config.read_text()
        with local_config.open('a') as stream:
            stream.write('ipv6=1\n')
        result = run('new', mode='local')
        local_config.write_text(original_config)
        check(result.get('bind') == '127.0.0.1' and result.get('tls') == 0,
              'built-in local RPC works with IPv6 disabled and Socket6 installed', result)
        check(str(result.get('marker')) == '0',
              'local RPC marker is not passed on to started programs', result)
        check(result.get('local_copy') == 'local transfer',
              'local file transfers use loopback when the server hash names a host', result)

        # Receive TLS slowly enough to exceed the sender's five-second timeout.
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen(1)
            listener.settimeout(15)
            received = []
            # slow_reader(): throttle TLS input and record the byte count.
            def slow_reader():
                try:
                    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                    context.load_cert_chain(cert, key)
                    with listener.accept()[0] as tcp, context.wrap_socket(tcp, server_side=True) as stream:
                        stream.settimeout(15)
                        size = 0
                        while size < 8 * 1024 * 1024:
                            block = stream.recv(16384)
                            if not block:
                                # Record the incomplete transfer on EOF.
                                break
                            size += len(block)
                            time.sleep(.015625)
                        received.append(size)
                        stream.sendall(b'OK\n')
                except Exception as error:
                    received.append(str(error))
            reader = threading.Thread(target=slow_reader)
            reader.start()
            result = run('new', mode='slow_write', throttle_port=listener.getsockname()[1])
            reader.join(timeout=30)
            check(result.get('slow_reply') == 'OK\n' and received == [8 * 1024 * 1024],
                  'large TLS writes keep progressing beyond the idle timeout', [result, received])
        # Stalled handshakes and mismatched file certificates must fail cleanly.
        result = run('new', mode='handshake')
        check('timed out' in result.get('handshake_timeout', ''),
              'stalled TLS handshake times out', result)
        result = run('new', mode='wrong_secondary')
        check('certificate differs' in result.get('certificate_error', ''),
              'file connection must present the HTTPS certificate', result)
        check(result.get('file_created') == 0,
              'certificate mismatch prevents remote file creation', result)
        check(str(result.get('after_mismatch')) == '42',
              'control session survives a rejected file certificate', result)
        # Bootstrap verification still applies before any fast RPC connection.
        result = run('ca', mode='calls', checkssl=1)
        check(str(result.get('call')) == '42' and result.get('tls') == 1,
              'CA and hostname verification work with fast TLS', result)
        result = run('ca', mode='calls', checkssl=1, host='wrong.invalid')
        check('Certificate is for' in result.get('error', ''),
              'hostname mismatch fails before RPC', result)

        # Interrupted file children must not invalidate the control session.
        result = run('new', mode='interruptions')
        check(bool(result.get('truncated')), 'truncated TLS download fails', result)
        check(bool(result.get('missing_ack')), 'missing upload acknowledgement fails', result)
        check(str(result.get('after_interruptions')) == '42',
              'parent session survives interrupted transfer children', result)
        # A caller timeout cannot safely retry a request that may have executed.
        result = run('new', mode='timeout')
        check('timed out' in result.get('timeout', ''), 'stalled RPC response times out', result)
        check(result.get('executions') == 'x', 'timed-out command is never replayed', result)

        # Send two requests in one TLS record. The second is already buffered.
        context = ssl._create_unverified_context()
        peer = peers['new']
        connection = http.client.HTTPSConnection('127.0.0.1', peer['port'], context=context)
        auth = base64.b64encode(f'admin:{password}'.encode()).decode()
        connection.request('GET', '/fastrpc.cgi?tls=1', headers={'Authorization': 'Basic '+auth})
        startup = connection.getresponse().read().decode().strip().split()
        connection.close()
        check(startup[-1] == 'TLS1', 'bootstrap advertises the TLS capability', startup)
        # One TLS write deliberately contains two complete control frames.
        with socket.create_connection(('127.0.0.1', int(startup[1]))) as tcp:
            with context.wrap_socket(tcp, server_hostname='localhost') as stream:
                stream.settimeout(2)
                payload = b"$VAR1 = {'action' => 'ping'};"
                frame = f'{len(payload)} {startup[2]}\n'.encode() + payload
                stream.sendall(frame + frame)
                received = []
                for _ in range(2):
                    # Consume each reply exactly, leaving the next one intact.
                    header = b''
                    while not header.endswith(b'\n'):
                        data = stream.recv(1)
                        if not data:
                            # EOF is a failure, not an empty response header.
                            raise RuntimeError('RPC response closed early')
                        header += data
                    length = int(header)
                    # Read only the declared body before looking for a header.
                    body = b''
                    while len(body) < length:
                        body += stream.recv(length-len(body))
                    received.append(body)
                check(all(b"'status' => 1" in body for body in received),
                      'pending TLS requests do not wait for another TCP packet', received)

        # The secondary listener must enforce the HTTPS protocol restrictions.
        connection = http.client.HTTPSConnection('127.0.0.1', peer['port'], context=context)
        connection.request('GET', '/fastrpc.cgi?tls=1', headers={'Authorization': 'Basic '+auth})
        startup = connection.getresponse().read().decode().strip().split()
        connection.close()
        restricted = ssl._create_unverified_context()
        restricted.minimum_version = restricted.maximum_version = ssl.TLSVersion.TLSv1_2
        rejected = False
        try:
            with socket.create_connection(('127.0.0.1', int(startup[1])), timeout=3) as tcp:
                with restricted.wrap_socket(tcp, server_hostname='localhost'):
                    pass
        except ssl.SSLError as error:
            rejected = 'PROTOCOL_VERSION' in str(error)
        check(rejected, 'RPC listener rejects TLS versions disabled in Webmin')

        # TLS 1.2 cipher restrictions must also apply to the RPC listener.
        for cipher, allowed in [('ECDHE-RSA-AES128-GCM-SHA256', True),
                                ('ECDHE-RSA-AES256-GCM-SHA384', False)]:
            # Each attempt needs a fresh single-client fast RPC listener.
            connection = http.client.HTTPSConnection('127.0.0.1', peers['ca']['port'], context=context)
            connection.request('GET', '/fastrpc.cgi?tls=1', headers={'Authorization': 'Basic '+auth})
            startup = connection.getresponse().read().decode().strip().split()
            connection.close()
            # Force TLS 1.2 so the configured cipher list controls selection.
            restricted = ssl._create_unverified_context()
            restricted.minimum_version = restricted.maximum_version = ssl.TLSVersion.TLSv1_2
            restricted.set_ciphers(cipher)
            accepted = False
            try:
                with socket.create_connection(('127.0.0.1', int(startup[1])), timeout=3) as tcp:
                    with restricted.wrap_socket(tcp, server_hostname='localhost'):
                        accepted = True
            except ssl.SSLError:
                pass
            check(accepted == allowed, 'RPC cipher list '+('allows ' if allowed else 'rejects ')+cipher)

        # Check RPC permissions and certificate trust separately.
        result = run('new', mode='calls', user='denied')
        check(bool(result.get('error')), 'RPC permission still required', result)
        result = run('new', mode='calls', checkssl=1)
        check('self-signed' in result.get('error', '').lower(),
              'existing certificate checks reject self-signed certificates', result)
        # These cases run only with PR #2932 present in the isolated source tree.
        if 'server_ssl_fingerprints' in (source/'servers/servers-lib.pl').read_text():
            result = run('new', mode='calls', sslfingerprint=pin, cloudmin_uuid='fixture')
            check(str(result.get('call')) == '42' and result.get('tls') == 1,
                  'pinned Cloudmin peer uses authenticated fast TLS', result)
            result = run('new', mode='calls', sslfingerprint='0'*64, cloudmin_uuid='fixture')
            check('fingerprint' in result.get('error', '').lower(),
                  'wrong pin fails before RPC', result)
            result = run('old', mode='files', sslfingerprint=pin, cloudmin_uuid='fixture')
            check(result.get('https') == 1 and result.get('input') == result.get('output'),
                  'pinned old peer transfers files over HTTPS', result)
        # Automatic detection uses the same TLS and pin verification as RPC.
        pins = ['', pin] if 'server_ssl_fingerprints' in (source/'servers/servers-lib.pl').read_text() else ['']
        for number, fingerprint in enumerate(pins, 900):
            # Edit an existing fixture record so saved pins reach the probe.
            peer = peers['new']
            record = peer['conf']/'servers'/f'{number}.serv'
            config(record, dict(id=number, host='localhost', port=peer['port'],
                   ssl=1, fast=0, user='admin', sslfingerprint=fingerprint))
            record.chmod(0o600)
            # Use the real CGI with automatic transport detection requested.
            body = urllib.parse.urlencode(dict(id=number, host='localhost',
                port=peer['port'], ssl=1, checkssl=0, mode=1, fast=2,
                wuser='admin', wpass=password))
            connection = http.client.HTTPSConnection('127.0.0.1', peer['port'], context=context)
            connection.request('POST', '/servers/save_serv.cgi', body, headers={
                'Authorization': 'Basic '+auth, 'Content-Type': 'application/x-www-form-urlencoded'})
            response = connection.getresponse()
            output = response.read().decode(errors='replace')
            connection.close()
            # Check that the probe result was saved.
            saved = dict(line.split('=', 1) for line in record.read_text().splitlines() if '=' in line)
            check(response.status == 302 and saved.get('fast') == '1',
                  ('pinned' if fingerprint else 'unpinned')+' server auto-detection enables fast TLS',
                  f'HTTP {response.status}: {output[:500]}')

        # Build a real tar installer and upload it through the old peer's HTTPS RPC.
        boot = f'webmin-rpc-tls-test-{os.getpid()}'
        with tarfile.open(task/'upgrade.tar.gz', 'w:gz') as archive:
            for item in source.iterdir():
                if item.is_file() and item.name not in ('version', 'install-type'):
                    # Keep root files while supplying a distinct test version.
                    archive.add(item, arcname='webmin-2.671.999/'+item.name)
            for directory in ('vendor_perl', 'lang', 'images', 'webmin', 'servers',
                              'acl', 'init'):
                archive.add(source/directory, arcname='webmin-2.671.999/'+directory)
            # Make the installer recognize this temporary package as an upgrade.
            version = tarfile.TarInfo('webmin-2.671.999/version')
            version.size = len(b'2.671.999\n')
            archive.addfile(version, io.BytesIO(b'2.671.999\n'))
        result = run('old', mode='upgrade')
        install = result.get('installer') or [1, result]
        check(int(install[0]) == 0 and
              (peers['old']['conf']/'version').read_text().strip() == '2.671.999',
              'updated master uploads and runs the Webmin installer on an old peer', install)
        check(result.get('https') == 1 and result.get('fallback_cleared') == 1,
              'upgrade uses HTTPS and clears its negotiated fallback afterward', result)
        if int(install[0]) == 0:
            # Restart only the fixture peer using its newly installed source.
            peer = peers['old']
            os.killpg(peer['process'].pid, signal.SIGTERM)
            peer['process'].wait(timeout=10)
            upgraded = task/'upgraded/webmin-2.671.999'
            log = open(peer['var']/'upgraded.log', 'w')
            process = subprocess.Popen(['perl', str(upgraded/'miniserv.pl'), '--nofork',
                str(peer['conf']/'miniserv.conf')], stdin=subprocess.DEVNULL,
                stdout=log, stderr=log, start_new_session=True)
            processes.append(process)
            # Wait for the replacement before checking that TLS is negotiated.
            for _ in range(100):
                try:
                    with socket.create_connection(('127.0.0.1', peer['port']), timeout=.1):
                        break
                except OSError:
                    time.sleep(.1)
            result = run('old', mode='calls')
            check(str(result.get('call')) == '42' and result.get('tls') == 1,
                  'upgraded peer negotiates fast TLS after reconnecting', result)
    finally:
        # Stop fixture process groups before deleting their configurations.
        for process in processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for process in processes:
            process.wait(timeout=10)
        # The installer may create a unit for this isolated fixture only.
        boot = f'webmin-rpc-tls-test-{os.getpid()}'
        subprocess.run(['systemctl', 'disable', boot], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        for directory in ('/etc/systemd/system', '/usr/lib/systemd/system',
                          '/lib/systemd/system', '/etc/init.d'):
            for suffix in ('', '.service'):
                (Path(directory)/(boot+suffix)).unlink(missing_ok=True)
        subprocess.run(['systemctl', 'daemon-reload'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print(f'1..{count}', flush=True)
sys.exit(1 if failures else 0)
