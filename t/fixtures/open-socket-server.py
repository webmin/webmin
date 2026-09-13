#!/usr/bin/python3
"""Loopback-only HTTP, TLS, CONNECT, FTP and greeting fixtures."""
import json
import os
import pathlib
import signal
import socket
import socketserver
import ssl
import subprocess
import sys
import threading

if sys.platform != 'linux' or os.geteuid() != 0:
    raise SystemExit('Disposable root Linux VM required')
os.umask(0o077)
work = pathlib.Path(sys.argv[1])
key, cert = work / 'server.key', work / 'server.crt'
subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
    '-days', '1', '-subj', '/CN=four.invalid', '-keyout', str(key), '-out', str(cert)],
    check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(cert, key)
context.set_servername_callback(lambda connection, name, _: setattr(connection, 'fixture_sni', name))

class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True

class Server6(Server):
    address_family = socket.AF_INET6
    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        super().server_bind()

class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        connection = self.request
        connection.settimeout(8)
        if self.server.mode == 'greeting':
            connection.sendall(b'220 loopback fixture ready\r\n')
            return
        if self.server.mode == 'ftp':
            self.ftp(connection)
            return
        if self.server.mode == 'https':
            connection = context.wrap_socket(connection, server_side=True)
        tunnel = ''
        for _ in range(2):
            reader = connection.makefile('rb')
            request = reader.readline().decode().strip()
            if not request:
                return
            headers = {}
            while True:
                line = reader.readline().decode().strip()
                if not line:
                    break
                name, value = line.split(':', 1)
                headers[name.lower()] = value.strip()
            if request.startswith('CONNECT '):
                # Terminate the fixture TLS connection here; never forward traffic.
                tunnel = request
                reader.close()
                connection.sendall(b'HTTP/1.0 200 Connection established\r\n\r\n')
                connection = context.wrap_socket(connection, server_side=True)
                continue
            posted = reader.read(int(headers.get('content-length', 0))).decode()
            body = json.dumps({'request': request, 'host': headers.get('host'),
                'peer': connection.getpeername()[0], 'sni': getattr(connection, 'fixture_sni', None),
                'tunnel': tunnel, 'posted': posted}).encode()
            connection.sendall(b'HTTP/1.0 200 OK\r\nContent-Length: ' + str(len(body)).encode() +
                b'\r\nConnection: close\r\n\r\n' + body)
            reader.close()
            connection.close()
            return

    def ftp(self, connection):
        reader = connection.makefile('rb')
        connection.sendall(b'220 loopback FTP fixture\r\n')
        data = None
        content = b'passive FTP marker\n'
        try:
            for line in reader:
                command = line.decode().strip().split(' ', 1)[0]
                if command == 'USER':
                    response = '331 Password required'
                elif command == 'PASS':
                    response = '230 Logged in'
                elif command == 'TYPE':
                    response = '200 Binary mode'
                elif command == 'SIZE':
                    response = '213 ' + str(len(content))
                elif command in ('PASV', 'EPSV'):
                    data = socket.socket(self.server.address_family)
                    data.settimeout(8)
                    data.bind((self.server.server_address[0], 0))
                    data.listen(1)
                    port = data.getsockname()[1]
                    response = (f'229 Entering Extended Passive Mode (|||{port}|)' if command == 'EPSV'
                        else f'227 Entering Passive Mode (127,0,0,1,{port//256},{port%256})')
                elif command == 'RETR':
                    connection.sendall(b'150 Sending data\r\n')
                    stream, _ = data.accept()
                    stream.sendall(content)
                    stream.close()
                    data.close()
                    data = None
                    response = '226 Transfer complete'
                elif command == 'QUIT':
                    connection.sendall(b'221 Goodbye\r\n')
                    return
                else:
                    response = '500 Unsupported fixture command'
                connection.sendall(response.encode() + b'\r\n')
        finally:
            if data:
                data.close()
            reader.close()

servers, reservations, ports = [], [], {}
for name, family, mode in [('http4', 4, 'http'), ('http6', 6, 'http'),
    ('https4', 4, 'https'), ('https6', 6, 'https'), ('proxy4', 4, 'http'),
    ('proxy6', 6, 'http'), ('ftp4', 4, 'ftp'), ('ftp6', 6, 'ftp'), ('greeting', 4, 'greeting')]:
    server = (Server if family == 4 else Server6)(('127.0.0.1' if family == 4 else '::1', 0), Handler)
    server.mode = mode
    ports[name] = server.server_address[1]
    # Reserve the unused IPv4 endpoint so fallback tests reliably get refusal.
    reservation = socket.socket()
    reservation.bind(('127.0.0.1' if family == 6 else '127.0.0.2', ports[name]))
    reservations.append(reservation)
    servers.append(server)
    threading.Thread(target=server.serve_forever, daemon=True).start()
refused = socket.socket()
refused.bind(('127.0.0.1', 0))
ports['refused'] = refused.getsockname()[1]
(work / 'ports.json').write_text(json.dumps(ports))
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
try:
    signal.pause()
finally:
    for server in servers:
        server.server_close()
    for reservation in reservations:
        reservation.close()
    refused.close()
