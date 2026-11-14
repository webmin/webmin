#!/usr/bin/env python3
"""Exercise pinned proxy and RPC connections on an explicitly enabled Linux VM.

Run with WEBMIN_SSL_FINGERPRINT_VM_TEST=1 and an optional Webmin source path.
All listeners, credentials and files belong to this fixture. No installed
Webmin configuration or services are changed.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import socket
import ssl
import subprocess
import sys
import tempfile
import threading


# The client uses production connection code with in-memory server records.
# Only configuration, authorization and error rendering are replaced.
CLIENT = r'''
use strict;
use warnings;
no warnings 'once';
use JSON::PP qw(decode_json);
use MIME::Base64 ();
# Read fixture credentials from stdin, keeping them out of command arguments.
my $root = shift(@ARGV);
my $input = decode_json(do { local $/; <STDIN> });
require "$root/web-lib-funcs.pl";
require "$root/miniserv-lib.pl";
# Supply an in-memory server record for the native proxy and RPC code.
our (%access, %gconfig, %text, %tconfig, $module_name);
$module_name = 'servers';
%access = (links => 1);
my $record = { id => 123, host => 'guest.test', ip => '127.0.0.1',
    port => $input->{'port'}, ssl => $input->{'ssl'},
    sslfingerprint => $input->{'pin'}, cloudmin_uuid => $input->{'guest'},
    user => 'fixture', pass => $input->{'password'}, fast => $input->{'fast'} };
# Load the real pin policy without initializing installed configuration.
open(my $source, '<', "$root/servers/servers-lib.pl") or die $!;
my $lib = do { local $/; <$source> };
$lib =~ /\n(sub server_ssl_fingerprints\n\{.*?\n\})\n/s or die 'Missing helper';
eval $1; die $@ if $@;
{
    no warnings 'redefine';
    *servers::server_ssl_fingerprints = \&server_ssl_fingerprints;
    # foreign_require(module, [file]) skips installed module initialization.
    *main::foreign_require = sub { };
    # is_readonly_mode() permits the fixture's simulated root request.
    *main::is_readonly_mode = sub { 0 };
    # get_server(id) returns this case's in-memory server record.
    *main::get_server = sub { $record };
    # can_use_server(record) grants access to the synthetic server.
    *main::can_use_server = sub { 1 };
    # get_webprefix() models Webmin served at the root path.
    *main::get_webprefix = sub { '' };
    # get_miniserv_config(&config) supplies only the fixture's host port.
    *main::get_miniserv_config = sub { %{$_[0]} = (port => 10000) };
    # error(messages...) reports a proxy refusal on stderr.
    *main::error = sub { die join('', @_)."\n" };
    # cleanup_websocket_route(&wsconfig) skips removal of a nonexistent route.
    *miniserv::cleanup_websocket_route = sub { };
    # get_websocket_allowed_origins() permits the fixture browser's origin.
    *miniserv::get_websocket_allowed_origins = sub { 'https://host.test' };
    # http_error(status, message, [details...]) reports a websocket refusal.
    *miniserv::http_error = sub { die join(' ', @_)."\n" };
}
if ($input->{'mode'} eq 'link') {
    # Execute the native CGI, including its real connection and login writes.
    $INC{'./servers-lib.pl'} = 1;
    @ENV{qw(PATH_INFO REQUEST_METHOD HTTP_HOST SERVER_PORT HTTPS QUERY_STRING)} =
        ('/123/', 'GET', 'host.test:10000', 10000, 'ON', '');
    my $result = do "$root/servers/link.cgi";
    # Preserve connection refusals and distinguish a CGI file-load failure.
    die $@ if $@;
    die "Cannot load link.cgi: $!\n" if !defined($result) && $!;
}
elsif ($input->{'mode'} eq 'rpc') {
    # This is the RPC operation used by the server-status check.
    # The error callback(messages...) reports an RPC refusal on stderr.
    remote_error_setup(sub { die join('', @_)."\n" });
    remote_foreign_require($record, 'webmin', 'webmin-lib.pl');
}
else {
    # Reach the real websocket handshake without creating a persistent route.
    open(miniserv::DEBUG, '>', '/dev/null') or die $!;
    %miniserv::header = (origin => 'https://host.test',
        'sec-websocket-key' => 'dGhlIHNhbXBsZSBub25jZQ==',
        'sec-websocket-version' => '13');
    $miniserv::session_id = 'synthetic-session';
    # Send the fixture login through the native backend connection code.
    miniserv::handle_websocket_request({host => '127.0.0.1',
        port => $input->{'port'}, ssl => $input->{'ssl'},
        sslfingerprint => $input->{'pin'}, hostheader => 'guest.test',
        origin => 'https://host.test', wspath => '/ws-123', nokey => 1,
        auth => 'basic:'.MIME::Base64::encode_base64(
            'fixture:'.$input->{'password'}, '')}, '/ws-123');
}
'''


def main():
    """main() checks real TLS and plaintext connections on a test VM."""
    if os.environ.get('WEBMIN_SSL_FINGERPRINT_VM_TEST') != '1':
        # Opening listeners and creating keys require explicit test opt-in.
        print('SKIP: set WEBMIN_SSL_FINGERPRINT_VM_TEST=1 on a test VM')
        return
    if sys.platform != 'linux' or os.geteuid() != 0:
        # The native Webmin paths in this fixture expect a root Linux process.
        raise SystemExit('A root Linux test VM is required')
    # Use the requested checkout, or the checkout containing this script.
    source = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(
        __file__).resolve().parents[2]
    # Keep generated keys private and remove all fixture files on exit.
    os.umask(0o077)
    with tempfile.TemporaryDirectory(prefix='webmin-pins-') as directory:
        task = Path(directory)
        client = task / 'client.pl'
        client.write_text(CLIENT)
        # Use a disposable login and retain only match results in test output.
        password = secrets.token_urlsafe(24)
        authorization = b'authorization: basic ' + base64.b64encode(
            ('fixture:' + password).encode())
        contexts, pins = {}, {}
        # Distinct keys with the same subject prove that names alone do not
        # identify the expected server. Both certificates are self-signed.
        for name in ('guest', 'impostor'):
            key, cert = task / (name + '.key'), task / (name + '.crt')
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048',
                            '-nodes', '-days', '1', '-subj', '/CN=guest.test',
                            '-keyout', str(key), '-out', str(cert)],
                           check=True, capture_output=True)
            # Serve each certificate and derive its pin from the DER bytes.
            contexts[name] = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            contexts[name].load_cert_chain(cert, key)
            pins[name] = hashlib.sha256(ssl.PEM_cert_to_DER_cert(
                cert.read_text())).hexdigest()
        # Keep the address and port unchanged when swapping certificates.
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            listener.settimeout(0.1)
            port = listener.getsockname()[1]
            # Cases: label, mode, certificate, pin present, TLS, fast RPC,
            # Cloudmin marker, and expected refusal text or None.
            cases = [
                ('matching page', 'link', 'guest', True, 1, 0, 1, None),
                ('wrong page certificate', 'link', 'impostor', True, 1, 0, 1,
                 'fingerprint'),
                ('unverified guest page', 'link', 'impostor', False, 1, 0, 1,
                 'fingerprint'),
                ('plaintext pinned page', 'link', 'guest', True, 0, 0, 1,
                 'SSL is required'),
                ('matching RPC', 'rpc', 'guest', True, 1, 0, 1, None),
                ('wrong RPC certificate', 'rpc', 'impostor', True, 1, 0, 1,
                 'fingerprint'),
                ('unverified guest RPC', 'rpc', 'impostor', False, 1, 0, 1,
                 'fingerprint'),
                ('pinned fast RPC uses HTTPS', 'rpc', 'guest', True, 1, 1, 1,
                 None),
                ('wrong fast RPC certificate', 'rpc', 'impostor', True,
                 1, 1, 1, 'fingerprint'),
                ('plaintext pinned RPC', 'rpc', 'guest', True, 0, 1, 1,
                 'SSL is required'),
                ('matching websocket', 'websocket', 'guest', True, 1, 0, 1,
                 None),
                ('wrong websocket certificate', 'websocket', 'impostor',
                 True, 1, 0, 1, 'fingerprint'),
                ('plaintext pinned websocket', 'websocket', 'guest', True,
                 0, 0, 1, 'SSL is required'),
                ('ordinary unpinned page', 'link', 'guest', False, 1, 0, 0,
                 None),
            ]
            for label, mode, cert, pinned, tls, fast, guest, rejection in cases:
                # Reset observations so one case cannot satisfy another.
                result = {'bytes': 0, 'login': False, 'path': None}
                stop = threading.Event()

                def receive():
                    """receive() records byte count, path and login match.

                    Store observations in the enclosing case's result dict.
                    """
                    while not stop.is_set():
                        try:
                            conn, _ = listener.accept()
                            break
                        except TimeoutError:
                            # Poll the stop flag when no client connects.
                            continue
                    else:
                        # Refusal before connection leaves nothing to receive.
                        return
                    try:
                        # Use this case's certificate on the shared endpoint.
                        conn.settimeout(4)
                        with conn:
                            stream = contexts[cert].wrap_socket(
                                conn, server_side=True) if tls else conn
                            with stream:
                                data = b''
                                # Webmin also emits LF-only headers.
                                while not re.search(br'\r?\n\r?\n', data):
                                    part = stream.recv(8192)
                                    if not part:
                                        # Pin rejection can close before HTTP.
                                        break
                                    data += part
                                    result['bytes'] = len(data)
                                # Record the match without logging the login.
                                result['login'] = authorization.lower() in data.lower()
                                if data:
                                    # Serve the page; end RPC and websocket
                                    # exchanges after observing their login.
                                    result['path'] = data.splitlines()[0].split()[1]
                                    status = b'200 OK' if mode == 'link' else b'401 Unauthorized'
                                    stream.sendall(b'HTTP/1.1 ' + status +
                                        b'\r\nContent-Type: text/plain\r\n'
                                        b'Content-Length: 11\r\n\r\nPIN-FIXTURE')
                    except (OSError, ssl.SSLError):
                        # Rejected peers can close immediately after TLS.
                        pass

                # Run the real client with fixture input supplied over stdin.
                thread = threading.Thread(target=receive)
                thread.start()
                try:
                    proc = subprocess.run(['perl', str(client), str(source)],
                        input=json.dumps({'mode': mode, 'port': port,
                            'pin': pins['guest'] if pinned else None,
                            'ssl': tls, 'fast': fast, 'guest': guest,
                            'password': password}), capture_output=True,
                        text=True, timeout=12)
                finally:
                    # Stop the receiver even when the client fails or times out.
                    stop.set()
                    thread.join(timeout=5)
                assert not thread.is_alive(), label + ': receiver did not stop'
                if rejection:
                    # No HTTP bytes, including credentials, may reach the peer.
                    assert rejection in proc.stderr, label + ': wrong refusal'
                    assert result['bytes'] == 0, label + ': request leaked'
                else:
                    # Allowed connections must deliver the fixture login.
                    assert result['login'], label + ': login did not arrive'
                    if mode == 'rpc':
                        # A pinned fast setting must still choose HTTPS RPC.
                        assert result['path'] == b'/rpc.cgi', label
                    if mode == 'link':
                        # The page proxy must return the fixture response body.
                        assert 'PIN-FIXTURE' in proc.stdout, label
                print('PASS: ' + label, flush=True)


if __name__ == '__main__':
    # Importing the fixture must not start listeners or generate credentials.
    main()
