#!/usr/bin/env python3
"""Run isolated old/new miniserv RPC peers on a disposable Linux VM."""
import base64
import hashlib
import http.client
import http.server
import ssl
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

source, legacy = map(Path, sys.argv[1:3])
benchmark = os.environ.get('WEBMIN_RPC_TLS_BENCHMARK') == '1'
if sys.platform != 'linux' or os.geteuid() != 0:
    # Namespace tests require an explicitly selected Linux guest.
    raise SystemExit('Run on a disposable root Linux VM')
fixture = Path(__file__).with_name('rpc-tls-client.pl')
processes = []
proxy = None
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
    try:
        peers = {}
        # Benchmarks need only the two peers being compared.
        peer_specs = [('new', source, 1), ('old', legacy, 1)]
        if not benchmark:
            peer_specs.extend([('http', source, 0), ('ca', source, 1)])
        # Each protocol/version combination gets its own configuration and port.
        for name, root, use_ssl in peer_specs:
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
                   lang='en', log=0, tempdir=var/'tmp',
                   rpc_timeout=60 if benchmark else 3, rpc_idle_factor=2))
            (conf/'var-path').write_text(str(var)+'\n')
            config(conf/'servers/config', dict(capath=other_cert))
            (conf/'perl-path').write_text('/usr/bin/perl\n')
            (conf/'version').write_text((root/'version').read_text())
            # Listen on loopback and vary TLS restrictions for targeted checks.
            config(conf/'miniserv.conf', dict(port=port, bind='127.0.0.1',
                   root=root, ssl=use_ssl, keyfile=key, certfile=signed if name == 'ca' else cert,
                   pidfile=var/'pid', logfile=var/'requests', errorlog=var/'errors',
                   userfile=conf/'miniserv.users', env_WEBMIN_CONFIG=conf,
                   env_WEBMIN_VAR=var, session=0, passdelay=0, no_pam=1, syslog=0,
                   log=0, forkcgis=0, addtype_cgi='internal/cgi',
                   no_tls1_2=int(benchmark or name == 'new'),
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
                                                blocks=4096 if benchmark else 512 if name == 'new' else 32,
                                                other_key=str(other_key), other_cert=str(other_cert))))
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

        if benchmark:
            # Compare two TLS-capable trees using identical 256 MiB payloads.
            samples = {'current': [], 'baseline': []}
            for trial in range(8):
                # Discard one warmup pair and alternate order to limit drift.
                order = ('new', 'old') if trial % 2 else ('old', 'new')
                for name in order:
                    label = 'current' if name == 'new' else 'baseline'
                    case_path = task/f'case-{count}'
                    result = run(name, mode='benchmark',
                                 client=source if name == 'new' else legacy)
                    valid = result.get('verified') == 1 and not result.get('error')
                    check(valid, f'benchmark {label} trial {trial}', result)
                    print('# sample '+json.dumps(dict(variant=label,
                          warmup=trial == 0, **result)), flush=True)
                    # Keep only one round trip on disk at a time.
                    shutil.rmtree(case_path)
                    if not valid:
                        raise RuntimeError('Benchmark transfer failed')
                    if trial:
                        samples[label].append(result)
            summary = {}
            for label, results in samples.items():
                summary[label] = {'buffer_bytes': results[0]['buffer_bytes'],
                                  'cipher': results[0]['cipher'], 'runs': len(results)}
                for direction in ('upload', 'download'):
                    rates = [r['bytes'] / 1048576 / r[direction+'_seconds']
                             for r in results]
                    summary[label][direction+'_mib_s'] = {
                        'median': statistics.median(rates),
                        'min': min(rates), 'max': max(rates)}
            print('# benchmark_summary '+json.dumps(summary), flush=True)
            print(f'1..{count}', flush=True)
            sys.exit(0)

        # Cover TLS, plain HTTP fast RPC and older clients.
        for name, client, fast, tls, https in [('new', source, 1, 1, 0),
                 ('http', source, 1, 0, 0),
                 ('new', legacy, 1, 0, 0)]:
            label = f'{"old" if client == legacy else "new"} client / {name} server'
            result = run(name, client=client, fast=fast)
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

        # Saved pins must work with TLS calls and both file-transfer sockets.
        for name, certificate, check_ca in [('new', cert, 0), ('ca', signed, 1)]:
            pin = hashlib.sha256(ssl.PEM_cert_to_DER_cert(
                certificate.read_text())).hexdigest()
            result = run(name, sslfingerprint=pin, checkssl=check_ca)
            label = 'pinned '+name+' server'
            check(str(result.get('call')) == '42' and not result.get('error'),
                  label+' RPC', result)
            check(result.get('tls') == 1 and result.get('https') == 0,
                  label+' keeps TLS fast RPC', result)
            check(result.get('input') and result.get('input') == result.get('output'),
                  label+' binary file round trip', result)

        # Either file direction can be the first operation in a fresh process.
        # Cover TLS and plaintext HTTP fast RPC.
        for name, tls, https in [('new', 1, 0), ('http', 0, 0)]:
            for mode in ('first_write', 'first_read'):
                result = run(name, mode=mode)
                check(result.get('first_transfer') == 'first RPC transfer' and
                      not result.get('error'), name+' '+mode+' round trip', result)
                # Later RPC calls must still use the expected transport.
                check(result.get('tls') == tls and result.get('https') == https and
                      str(result.get('call')) == '42',
                      name+' '+mode+' keeps the negotiated session', result)

        # TLS transfers must report disk and open errors.
        result = run('new', mode='errors')
        for error in ('remote_full', 'local_full', 'missing', 'unwritable'):
            check(bool(result.get(error)), 'TLS reports '+error, result)
        check('No space left' in result.get('remote_full', ''),
              'TLS upload reports the remote disk error', result)
        check('No such file' in result.get('unwritable', ''),
              'TLS upload reports the destination open error', result)
        check(str(result.get('after_errors')) == '42', 'TLS session survives file errors', result)
        check(result.get('preserved') == 'preserved',
              'TLS missing source preserves the destination', result)
        # The server must keep the cause even after reporting it to the client.
        errors = (peers['new']['var']/'errors').read_text()
        transfer_errors = [line for line in errors.splitlines()
                           if 'TLS file transfer failed:' in line]
        check(any('No space left' in line for line in transfer_errors),
              'TLS upload logs the remote disk error', errors[-3000:])
        check(any('Failed to open' in line and 'No such file' in line
                  for line in transfer_errors),
              'TLS upload logs the destination open error', errors[-3000:])

        # Remote exceptions must preserve both session state and return values.
        result = run('new', mode='rpc_errors')
        for error_key, expected in [('eval_die', 'eval failure'), ('call_die', 'call failure'),
                                    ('call_error', 'module failure')]:
            check(expected in result.get(error_key, ''), 'TLS returns '+error_key, result)
        check(result.get('values') == [None, '0', "quote'\\\n"] or
              result.get('values') == [None, 0, "quote'\\\n"],
              'TLS preserves list values and quoting', result)
        check(result.get('context') == 'list' and result.get('eval_context') == 'scalar' and
              str(result.get('after_rpc_errors')) == '42',
              'TLS preserves call context and survives remote errors', result)

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

        # Password rotation must not break an already authenticated session.
        result = run('new', mode='password_change')
        check(str(result.get('after_password_change')) == '42',
              'authenticated TLS session survives a changed saved password', result)

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
        connection.request('GET', '/fastrpc.cgi?fixture=1&tls=1', headers={'Authorization': 'Basic '+auth})
        startup = connection.getresponse().read().decode().strip().split()
        connection.close()
        check(startup[-1] == 'TLS1', 'bootstrap parses TLS alongside other query parameters', startup)
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

        # A non-TLS backend rejects TLS setup before starting an RPC listener.
        connection = http.client.HTTPConnection('127.0.0.1', peers['http']['port'])
        connection.request('GET', '/fastrpc.cgi?tls=1',
                           headers={'Authorization': 'Basic '+auth})
        startup = connection.getresponse().read().decode().strip()
        connection.close()
        check(startup == '0 TLS fast RPC requires HTTPS and a TLS key on Webmin itself',
              'non-TLS backend rejects TLS fast RPC', startup)

        # Test HTTPS requests reaching a plain HTTP backend.
        proxy_requests = []

        # RPCProxy(request, address, server): forward requests to the HTTP peer.
        class RPCProxy(http.server.BaseHTTPRequestHandler):
            # forward(): send this request to the HTTP backend.
            def forward(self):
                proxy_requests.append(self.path)
                body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                backend = http.client.HTTPConnection('127.0.0.1', peers['http']['port'], timeout=10)
                try:
                    # Use the backend's Host header when forwarding.
                    headers = dict(self.headers)
                    headers['Host'] = f"localhost:{peers['http']['port']}"
                    backend.request(self.command, self.path, body, headers)
                    # Buffer the reply to determine its length.
                    response = backend.getresponse()
                    data = response.read()
                    self.send_response(response.status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'content-length', 'transfer-encoding'):
                            # Preserve other response headers.
                            self.send_header(name, value)
                    # Replace the backend's framing with a known length.
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    # Close the backend even if forwarding fails.
                    backend.close()

            do_GET = do_POST = forward

            # log_message(format, [args...]): keep logs out of TAP output.
            def log_message(self, format, *args):
                pass

        # Terminate TLS here; the backend receives plain HTTP.
        proxy = http.server.ThreadingHTTPServer(('127.0.0.1', 0), RPCProxy)
        proxy_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        proxy_context.load_cert_chain(cert, key)
        proxy.socket = proxy_context.wrap_socket(proxy.socket, server_side=True)
        proxy_thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        proxy_thread.start()
        peers['proxy'] = dict(peers['http'], port=proxy.server_address[1], ssl=1)

        # Calls and first-use transfers must fail without switching modes.
        for name, expected in [('old', 'not supported by this server; upgrade Webmin'),
                               ('proxy', 'requires HTTPS and a TLS key on Webmin itself')]:
            for mode in ('calls', 'first_write', 'first_read'):
                proxy_requests.clear()
                result = run(name, mode=mode)
                check(expected in result.get('error', ''), name+' rejects '+mode, result)
                check(result.get('requests') == ['/fastrpc.cgi?tls=1'],
                      name+' / '+mode+': no regular RPC request', result)
                if mode != 'calls':
                    # Reject setup before touching either destination.
                    check(result.get('destination_created') == 0,
                          name+' / '+mode+': no destination created', result)
                if name == 'proxy':
                    # Check the proxy saw no retry through rpc.cgi.
                    check(proxy_requests == ['/fastrpc.cgi?tls=1'],
                          'proxy / '+mode+': only the fast RPC setup request', proxy_requests)

        # Regular RPC calls still work, but file transfers fail.
        for name in ('new', 'old', 'http', 'proxy'):
            result = run(name, mode='regular_files', fast=0)
            check(not result.get('error') and str(result.get('call')) == '42',
                  name+' explicit regular RPC still handles calls', result)
            # Check both directions with an existing regular RPC session.
            for direction in ('write', 'read'):
                check('File transfers require fast RPC' in
                      result.get(direction+'_error', ''),
                      name+' regular RPC rejects '+direction, result)
            # Failed transfers must preserve files and the session.
            check(result.get('remote') == 'remote' and result.get('output') == 'output',
                  name+' rejected transfers preserve existing files', result)
            check(str(result.get('after_rejection')) == '42',
                  name+' regular RPC session survives rejected transfers', result)
            # Also reject transfers made before any other RPC call.
            for mode in ('first_write', 'first_read'):
                result = run(name, mode=mode, fast=0)
                check('File transfers require fast RPC' in result.get('error', ''),
                      name+' regular RPC rejects '+mode, result)
                check(result.get('destination_created') == 0,
                      name+' regular RPC / '+mode+': no destination created', result)

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
        # Automatic detection uses the same certificate checks as RPC.
        peer = peers['new']
        number = 900
        record = peer['conf']/'servers'/f'{number}.serv'
        config(record, dict(id=number, host='localhost', port=peer['port'],
               ssl=1, fast=0, user='admin'))
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
              'server auto-detection enables fast TLS',
              f'HTTP {response.status}: {output[:500]}')

        # The same probe must preserve and verify a saved certificate pin.
        saved['sslfingerprint'] = hashlib.sha256(ssl.PEM_cert_to_DER_cert(
            cert.read_text())).hexdigest()
        config(record, saved)
        connection = http.client.HTTPSConnection('127.0.0.1', peer['port'], context=context)
        connection.request('POST', '/servers/save_serv.cgi', body, headers={
            'Authorization': 'Basic '+auth, 'Content-Type': 'application/x-www-form-urlencoded'})
        response = connection.getresponse()
        output = response.read().decode(errors='replace')
        connection.close()
        updated = dict(line.split('=', 1) for line in record.read_text().splitlines() if '=' in line)
        check(response.status == 302 and updated.get('fast') == '1',
              'pinned server auto-detection enables fast TLS', output[:500])
        check(updated.get('sslfingerprint') == saved['sslfingerprint'],
              'server auto-detection preserves the saved pin')

        # Failed SSL detection must leave the saved server unchanged.
        for name, expected in [('old', 'not supported by this server'),
                               ('proxy', 'requires HTTPS and a TLS key')]:
            before = record.read_text()
            body = urllib.parse.urlencode(dict(id=number, host='localhost',
                port=peers[name]['port'], ssl=1, checkssl=0, mode=1, fast=2,
                wuser='admin', wpass=password))
            connection = http.client.HTTPSConnection('127.0.0.1', peer['port'], context=context)
            connection.request('POST', '/servers/save_serv.cgi', body, headers={
                'Authorization': 'Basic '+auth, 'Content-Type': 'application/x-www-form-urlencoded'})
            response = connection.getresponse()
            output = response.read().decode(errors='replace')
            connection.close()
            check(response.status != 302 and expected in output,
                  name+' automatic detection reports TLS setup failure')
            check(record.read_text() == before,
                  name+' automatic detection does not save regular RPC')

    finally:
        # Stop the fixture proxy before shutting down its HTTP backend.
        if proxy is not None:
            proxy.shutdown()
            proxy.server_close()
            proxy_thread.join(timeout=10)
        # Stop fixture process groups before deleting their configurations.
        for process in processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        for process in processes:
            process.wait(timeout=10)
print(f'1..{count}', flush=True)
sys.exit(1 if failures else 0)
