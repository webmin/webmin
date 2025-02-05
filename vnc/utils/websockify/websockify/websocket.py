#!/usr/bin/env python

'''
Python WebSocket library
Copyright 2011 Joel Martin
Copyright 2016 Pierre Ossman
Licensed under LGPL version 3 (see docs/LICENSE.LGPL-3)

Supports following protocol versions:
    - http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-07
    - http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-10
    - http://tools.ietf.org/html/rfc6455
'''

import sys
import array
import email
import errno
import random
import socket
import ssl
import struct
from base64 import b64encode
from hashlib import sha1
from urllib.parse import urlparse

try:
    import numpy
except ImportError:
    import warnings
    warnings.warn("no 'numpy' module, HyBi protocol will be slower")
    numpy = None

class WebSocketWantReadError(ssl.SSLWantReadError):
    pass
class WebSocketWantWriteError(ssl.SSLWantWriteError):
    pass

class WebSocket:
    """WebSocket protocol socket like class.

    This provides access to the WebSocket protocol by behaving much
    like a real socket would. It shares many similarities with
    ssl.SSLSocket.

    The WebSocket protocols requires extra data to be sent and received
    compared to the application level data. This means that a socket
    that is ready to be read may not hold enough data to decode any
    application data, and a socket that is ready to be written to may
    not have enough space for an entire WebSocket frame. This is
    handled by the exceptions WebSocketWantReadError and
    WebSocketWantWriteError. When these are raised the caller must wait
    for the socket to become ready again and call the relevant function
    again.

    A connection is established by using either connect() or accept(),
    depending on if a client or server session is desired. See the
    respective functions for details.

    The following methods are passed on to the underlying socket:

        - fileno
        - getpeername, getsockname
        - getsockopt, setsockopt
        - gettimeout, settimeout
        - setblocking
    """

    GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    def __init__(self):
        """Creates an unconnected WebSocket"""

        self._state = "new"

        self._partial_msg = b''

        self._recv_buffer = b''
        self._recv_queue = []
        self._send_buffer = b''

        self._previous_sendmsg = None

        self._sent_close = False
        self._received_close = False

        self.close_code = None
        self.close_reason = None

        self.socket = None

    def __getattr__(self, name):
        # These methods are just redirected to the underlying socket
        if name in ["fileno",
                    "getpeername", "getsockname",
                    "getsockopt", "setsockopt",
                    "gettimeout", "settimeout",
                    "setblocking"]:
            assert self.socket is not None
            return getattr(self.socket, name)
        else:
            raise AttributeError("%s instance has no attribute '%s'" %
                                 (self.__class__.__name__, name))

    def connect(self, uri, origin=None, protocols=[]):
        """Establishes a new connection to a WebSocket server.

        This method connects to the host specified by uri and
        negotiates a WebSocket connection. origin should be specified
        in accordance with RFC 6454 if known. A list of valid
        sub-protocols can be specified in the protocols argument.

        The data will be sent in the clear if the "ws" scheme is used,
        and encrypted if the "wss" scheme is used.

        Both WebSocketWantReadError and WebSocketWantWriteError can be
        raised whilst negotiating the connection. Repeated calls to
        connect() must retain the same arguments.
        """

        self.client = True;

        uri = urlparse(uri)

        port = uri.port
        if uri.scheme in ("ws", "http"):
            if not port:
                port = 80
        elif uri.scheme in ("wss", "https"):
            if not port:
                port = 443
        else:
            raise Exception("Unknown scheme '%s'" % uri.scheme)

        # This is a state machine in order to handle
        # WantRead/WantWrite events

        if self._state == "new":
            self.socket = socket.create_connection((uri.hostname, port))

            if uri.scheme in ("wss", "https"):
                context = ssl.create_default_context()
                self.socket = context.wrap_socket(self.socket,
                                                  server_hostname=uri.hostname)
                self._state = "ssl_handshake"
            else:
                self._state = "headers"

        if self._state == "ssl_handshake":
            self.socket.do_handshake()
            self._state = "headers"

        if self._state == "headers":
            self._key = ''
            for i in range(16):
                self._key += chr(random.randrange(256))
            self._key = b64encode(self._key.encode("latin-1")).decode("ascii")

            path = uri.path
            if not path:
                path = "/"

            self.send_request("GET", path)
            self.send_header("Host", uri.hostname)
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "upgrade")
            self.send_header("Sec-WebSocket-Key", self._key)
            self.send_header("Sec-WebSocket-Version", 13)

            if origin is not None:
                self.send_header("Origin", origin)
            if len(protocols) > 0:
                self.send_header("Sec-WebSocket-Protocol", ", ".join(protocols))

            self.end_headers()

            self._state = "send_headers"

        if self._state == "send_headers":
            self._flush()
            self._state = "response"

        if self._state == "response":
            if not self._recv():
                raise Exception("Socket closed unexpectedly")

            if self._recv_buffer.find(b'\r\n\r\n') == -1:
                raise WebSocketWantReadError

            (request, self._recv_buffer) = self._recv_buffer.split(b'\r\n', 1)
            request = request.decode("latin-1")

            words = request.split()
            if (len(words) < 2) or (words[0] != "HTTP/1.1"):
                raise Exception("Invalid response")
            if words[1] != "101":
                raise Exception("WebSocket request denied: %s" % " ".join(words[1:]))

            (headers, self._recv_buffer) = self._recv_buffer.split(b'\r\n\r\n', 1)
            headers = headers.decode('latin-1') + '\r\n'
            headers = email.message_from_string(headers)

            if headers.get("Upgrade", "").lower() != "websocket":
                print(type(headers))
                raise Exception("Missing or incorrect upgrade header")

            accept = headers.get('Sec-WebSocket-Accept')
            if accept is None:
                raise Exception("Missing Sec-WebSocket-Accept header");

            expected = sha1((self._key + self.GUID).encode("ascii")).digest()
            expected = b64encode(expected).decode("ascii")

            del self._key

            if accept != expected:
                raise Exception("Invalid Sec-WebSocket-Accept header");

            self.protocol = headers.get('Sec-WebSocket-Protocol')
            if len(protocols) == 0:
                if self.protocol is not None:
                    raise Exception("Unexpected Sec-WebSocket-Protocol header")
            else:
                if self.protocol not in protocols:
                    raise Exception("Invalid protocol chosen by server")

            self._state = "done"

            return

        raise Exception("WebSocket is in an invalid state")

    def accept(self, socket, headers):
        """Establishes a new WebSocket session with a client.

        This method negotiates a WebSocket connection with an incoming
        client. The caller must provide the client socket and the
        headers from the HTTP request.

        A server can identify that a client is requesting a WebSocket
        connection by looking at the "Upgrade" header. It will include
        the value "websocket" in such cases.

        WebSocketWantWriteError can be raised if the response cannot be
        sent right away. accept() must be called again once more space
        is available using the same arguments.
        """

        # This is a state machine in order to handle
        # WantRead/WantWrite events

        if self._state == "new":
            self.client = False
            self.socket = socket

            if headers.get("upgrade", "").lower() != "websocket":
                raise Exception("Missing or incorrect upgrade header")

            ver = headers.get('Sec-WebSocket-Version')
            if ver is None:
                raise Exception("Missing Sec-WebSocket-Version header");

            # HyBi-07 report version 7
            # HyBi-08 - HyBi-12 report version 8
            # HyBi-13 reports version 13
            if ver in ['7', '8', '13']:
                self.version = "hybi-%02d" % int(ver)
            else:
                raise Exception("Unsupported protocol version %s" % ver)

            key = headers.get('Sec-WebSocket-Key')
            if key is None:
                raise Exception("Missing Sec-WebSocket-Key header");

            # Generate the hash value for the accept header
            accept = sha1((key + self.GUID).encode("ascii")).digest()
            accept = b64encode(accept).decode("ascii")

            self.protocol = ''
            protocols = headers.get('Sec-WebSocket-Protocol', '').split(',')
            if protocols:
                self.protocol = self.select_subprotocol(protocols)
                # We are required to choose one of the protocols
                # presented by the client
                if self.protocol not in protocols:
                    raise Exception('Invalid protocol selected')

            self.send_response(101, "Switching Protocols")
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.send_header("Sec-WebSocket-Accept", accept)

            if self.protocol:
                self.send_header("Sec-WebSocket-Protocol", self.protocol)

            self.end_headers()

            self._state = "flush"

        if self._state == "flush":
            self._flush()
            self._state = "done"

            return

        raise Exception("WebSocket is in an invalid state")

    def select_subprotocol(self, protocols):
        """Returns which sub-protocol should be used.

        This method does not select any sub-protocol by default and is
        meant to be overridden by an implementation that wishes to make
        use of sub-protocols. It will be called during handling of
        accept().
        """
        return ""

    def handle_ping(self, data):
        """Called when a WebSocket ping message is received.

        This will be called whilst processing recv()/recvmsg(). The
        default implementation sends a pong reply back."""
        self.pong(data)

    def handle_pong(self, data):
        """Called when a WebSocket pong message is received.

        This will be called whilst processing recv()/recvmsg(). The
        default implementation does nothing."""
        pass

    def recv(self):
        """Read data from the WebSocket.

        This will return any available data on the socket (which may
        be the empty string if the peer sent an empty message or
        messages). If the socket is closed then None will be
        returned. The reason for the close is found in the
        'close_code' and 'close_reason' properties.

        Unlike recvmsg() this method may return data from more than one
        WebSocket message. It is however not guaranteed to return all
        buffered data. Callers should continue calling recv() whilst
        pending() returns True.

        Both WebSocketWantReadError and WebSocketWantWriteError can be
        raised when calling recv().
        """
        return self.recvmsg()

    def recvmsg(self):
        """Read a single message from the WebSocket.

        This will return a single WebSocket message from the socket
        (which will be the empty string if the peer sent an empty
        message). If the socket is closed then None will be
        returned. The reason for the close is found in the
        'close_code' and 'close_reason' properties.

        Unlike recv() this method will not return data from more than
        one WebSocket message. Callers should continue calling
        recvmsg() whilst pending() returns True.

        Both WebSocketWantReadError and WebSocketWantWriteError can be
        raised when calling recvmsg().
        """
        # May have been called to flush out a close
        if self._received_close:
            self._flush()
            return None

        # Anything already queued?
        if self.pending():
            return self._recvmsg()
            # Note: If self._recvmsg() raised WebSocketWantReadError,
            #       we cannot proceed to self._recv() here as we may
            #       have already called it once as part of the caller's
            #       "while websock.pending():" loop

        # Nope, let's try to read a bit
        if not self._recv_frames():
            return None

        # Anything queued now?
        return self._recvmsg()

    def pending(self):
        """Check if any WebSocket data is pending.

        This method will return True as long as there are WebSocket
        frames that have yet been processed. A single recv() from the
        underlying socket may return multiple WebSocket frames and it
        is therefore important that a caller continues calling recv()
        or recvmsg() as long as pending() returns True.

        Note that this function merely tells if there are raw WebSocket
        frames pending. Those frames may not contain any application
        data.
        """
        return len(self._recv_queue) > 0

    def send(self, bytes):
        """Write data to the WebSocket

        This will queue the given data and attempt to send it to the
        peer. Unlike sendmsg() this method might coalesce the data with
        data from other calls, or split it over multiple messages.

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket. send() must be called again
        once more space is available using the same arguments.
        """
        if len(bytes) == 0:
            return 0

        return self.sendmsg(bytes)

    def sendmsg(self, msg):
        """Write a single message to the WebSocket

        This will queue the given message and attempt to send it to the
        peer. Unlike send() this method will preserve the data as a
        single WebSocket message.

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket. sendmsg() must be called again
        once more space is available using the same arguments.
        """
        if not isinstance(msg, bytes):
            raise TypeError

        if self._sent_close:
            return 0

        if self._previous_sendmsg is not None:
            if self._previous_sendmsg != msg:
                raise ValueError

            self._flush()
            self._previous_sendmsg = None

            return len(msg)

        try:
            self._sendmsg(0x2, msg)
        except WebSocketWantWriteError:
            self._previous_sendmsg = msg
            raise

        return len(msg)

    def send_response(self, code, message):
        self._queue_str("HTTP/1.1 %d %s\r\n" % (code, message))

    def send_header(self, keyword, value):
        self._queue_str("%s: %s\r\n" % (keyword, value))

    def end_headers(self):
        self._queue_str("\r\n")

    def send_request(self, type, path):
        self._queue_str("%s %s HTTP/1.1\r\n" % (type.upper(), path))

    def ping(self, data=b''):
        """Write a ping message to the WebSocket

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket. ping() must be called again once
        more space is available using the same arguments.
        """
        if not isinstance(data, bytes):
            raise TypeError

        if self._previous_sendmsg is not None:
            if self._previous_sendmsg != data:
                raise ValueError

            self._flush()
            self._previous_sendmsg = None

            return

        try:
            self._sendmsg(0x9, data)
        except WebSocketWantWriteError:
            self._previous_sendmsg = data
            raise

    def pong(self, data=b''):
        """Write a pong message to the WebSocket

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket. pong() must be called again once
        more space is available using the same arguments.
        """
        if not isinstance(data, bytes):
            raise TypeError

        if self._previous_sendmsg is not None:
            if self._previous_sendmsg != data:
                raise ValueError

            self._flush()
            self._previous_sendmsg = None

            return

        try:
            self._sendmsg(0xA, data)
        except WebSocketWantWriteError:
            self._previous_sendmsg = data
            raise

    def shutdown(self, how, code=1000, reason=None):
        """Gracefully terminate the WebSocket connection.

        This will start the process to terminate the WebSocket
        connection. The caller must continue to calling recv() or
        recvmsg() after this function in order to wait for the peer to
        acknowledge the close. Calls to send() and sendmsg() will be
        ignored.

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket for the close message. shutdown()
        must be called again once more space is available using the same
        arguments.

        The how argument is currently ignored.
        """

        # Already closing?
        if self._sent_close:
            self._flush()
            return

        # Special code to indicate that we closed the connection
        if not self._received_close:
            self.close_code = 1000
            self.close_reason = "Locally initiated close"

        self._sent_close = True

        msg = b''
        if code is not None:
            msg += struct.pack(">H", code)
            if reason is not None:
                msg += reason.encode("UTF-8")

        self._sendmsg(0x8, msg)

    def close(self, code=1000, reason=None):
        """Terminate the WebSocket connection immediately.

        This will close the WebSocket connection directly after sending
        a close message to the peer.

        WebSocketWantWriteError can be raised if there is insufficient
        space in the underlying socket for the close message. close()
        must be called again once more space is available using the same
        arguments.
        """
        self.shutdown(socket.SHUT_RDWR, code, reason)
        self._close()

    def _recv(self):
        # Fetches more data from the socket to the buffer
        assert self.socket is not None

        while True:
            try:
                data = self.socket.recv(4096)
            except OSError as exc:
                if exc.errno == errno.EWOULDBLOCK:
                    raise WebSocketWantReadError
                raise

            if len(data) == 0:
                return False

            self._recv_buffer += data

            # Support for SSLSocket like objects
            if hasattr(self.socket, "pending"):
                if not self.socket.pending():
                    break
            else:
                break

        return True

    def _recv_frames(self):
        # Fetches more data and decodes the frames
        if not self._recv():
            if self.close_code is None:
                self.close_code = 1006
                self.close_reason = "Connection closed abnormally"
                self._sent_close = self._received_close = True
            self._close()
            return False

        while True:
            frame = self._decode_hybi(self._recv_buffer)
            if frame is None:
                break
            self._recv_buffer = self._recv_buffer[frame['length']:]
            self._recv_queue.append(frame)

        return True

    def _recvmsg(self):
        # Process pending frames and returns any application data
        while self._recv_queue:
            frame = self._recv_queue.pop(0)

            if not self.client and not frame['masked']:
                self.shutdown(socket.SHUT_RDWR, 1002, "Procotol error: Frame not masked")
                continue
            if self.client and frame['masked']:
                self.shutdown(socket.SHUT_RDWR, 1002, "Procotol error: Frame masked")
                continue

            if frame["opcode"] == 0x0:
                if not self._partial_msg:
                    self.shutdown(socket.SHUT_RDWR, 1002, "Procotol error: Unexpected continuation frame")
                    continue

                self._partial_msg += frame["payload"]

                if frame["fin"]:
                    msg = self._partial_msg
                    self._partial_msg = b''
                    return msg
            elif frame["opcode"] == 0x1:
                self.shutdown(socket.SHUT_RDWR, 1003, "Unsupported: Text frames are not supported")
            elif frame["opcode"] == 0x2:
                if self._partial_msg:
                    self.shutdown(socket.SHUT_RDWR, 1002, "Procotol error: Unexpected new frame")
                    continue

                if frame["fin"]:
                    return frame["payload"]
                else:
                    self._partial_msg = frame["payload"]
            elif frame["opcode"] == 0x8:
                if self._received_close:
                    continue

                self._received_close = True

                if self._sent_close:
                    self._close()
                    return None

                if not frame["fin"]:
                    self.shutdown(socket.SHUT_RDWR, 1003, "Unsupported: Fragmented close")
                    continue

                code = None
                reason = None
                if len(frame["payload"]) >= 2:
                    code = struct.unpack(">H", frame["payload"][:2])[0]
                    if len(frame["payload"]) > 2:
                        reason = frame["payload"][2:]
                        try:
                            reason = reason.decode("UTF-8")
                        except UnicodeDecodeError:
                            self.shutdown(socket.SHUT_RDWR, 1002, "Procotol error: Invalid UTF-8 in close")
                            continue

                if code is None:
                    self.close_code = 1005
                    self.close_reason = "No close status code specified by peer"
                else:
                    self.close_code = code
                    if reason is not None:
                        self.close_reason = reason

                self.shutdown(None, code, reason)
                return None
            elif frame["opcode"] == 0x9:
                if not frame["fin"]:
                    self.shutdown(socket.SHUT_RDWR, 1003, "Unsupported: Fragmented ping")
                    continue

                self.handle_ping(frame["payload"])
            elif frame["opcode"] == 0xA:
                if not frame["fin"]:
                    self.shutdown(socket.SHUT_RDWR, 1003, "Unsupported: Fragmented pong")
                    continue

                self.handle_pong(frame["payload"])
            else:
                self.shutdown(socket.SHUT_RDWR, 1003, "Unsupported: Unknown opcode 0x%02x" % frame["opcode"])

        raise WebSocketWantReadError

    def _flush(self):
        # Writes pending data to the socket
        if not self._send_buffer:
            return

        assert self.socket is not None

        try:
            sent = self.socket.send(self._send_buffer)
        except OSError as exc:
            if exc.errno == errno.EWOULDBLOCK:
                raise WebSocketWantWriteError
            raise

        self._send_buffer = self._send_buffer[sent:]

        if self._send_buffer:
            raise WebSocketWantWriteError

        # We had a pending close and we've flushed the buffer,
        # time to end things
        if self._received_close and self._sent_close:
            self._close()

    def _send(self, data):
        # Queues data and attempts to send it
        self._send_buffer += data
        self._flush()

    def _queue_str(self, string):
        # Queue some data to be sent later.
        # Only used by the connecting methods.
        self._send_buffer += string.encode("latin-1")

    def _sendmsg(self, opcode, msg):
        # Sends a standard data message
        if self.client:
            mask = b''
            for i in range(4):
                mask += random.randrange(256).to_bytes()
            frame = self._encode_hybi(opcode, msg, mask)
        else:
            frame = self._encode_hybi(opcode, msg)

        return self._send(frame)

    def _close(self):
        # Close the underlying socket
        self.socket.close()
        self.socket = None

    def _mask(self, buf, mask):
        # Mask a frame
        return self._unmask(buf, mask)

    def _unmask(self, buf, mask):
        # Unmask a frame
        if numpy:
            plen = len(buf)
            pstart = 0
            pend = plen
            b = c = b''
            if plen >= 4:
                dtype=numpy.dtype('<u4')
                if sys.byteorder == 'big':
                    dtype = dtype.newbyteorder('>')
                mask = numpy.frombuffer(mask, dtype, count=1)
                data = numpy.frombuffer(buf, dtype, count=int(plen / 4))
                #b = numpy.bitwise_xor(data, mask).data
                b = numpy.bitwise_xor(data, mask).tobytes()

            if plen % 4:
                dtype=numpy.dtype('B')
                if sys.byteorder == 'big':
                    dtype = dtype.newbyteorder('>')
                mask = numpy.frombuffer(mask, dtype, count=(plen % 4))
                data = numpy.frombuffer(buf, dtype,
                        offset=plen - (plen % 4), count=(plen % 4))
                c = numpy.bitwise_xor(data, mask).tobytes()
            return b + c
        else:
            # Slower fallback
            data = array.array('B')
            data.frombytes(buf)
            for i in range(len(data)):
                data[i] ^= mask[i % 4]
            return data.tobytes()

    def _encode_hybi(self, opcode, buf, mask_key=None, fin=True):
        """ Encode a HyBi style WebSocket frame.
        Optional opcode:
            0x0 - continuation
            0x1 - text frame
            0x2 - binary frame
            0x8 - connection close
            0x9 - ping
            0xA - pong
        """

        b1 = opcode & 0x0f
        if fin:
            b1 |= 0x80

        mask_bit = 0
        if mask_key is not None:
            mask_bit = 0x80
            buf = self._mask(buf, mask_key)

        payload_len = len(buf)
        if payload_len <= 125:
            header = struct.pack('>BB', b1, payload_len | mask_bit)
        elif payload_len > 125 and payload_len < 65536:
            header = struct.pack('>BBH', b1, 126 | mask_bit, payload_len)
        elif payload_len >= 65536:
            header = struct.pack('>BBQ', b1, 127 | mask_bit, payload_len)

        if mask_key is not None:
            return header + mask_key + buf
        else:
            return header + buf

    def _decode_hybi(self, buf):
        """ Decode HyBi style WebSocket packets.
        Returns:
            {'fin'          : boolean,
             'opcode'       : number,
             'masked'       : boolean,
             'length'       : encoded_length,
             'payload'      : decoded_buffer}
        """

        f = {'fin'          : 0,
             'opcode'       : 0,
             'masked'       : False,
             'length'       : 0,
             'payload'      : None}

        blen = len(buf)
        hlen = 2

        if blen < hlen:
            return None

        b1, b2 = struct.unpack(">BB", buf[:2])
        f['opcode'] = b1 & 0x0f
        f['fin'] = not not (b1 & 0x80)
        f['masked'] = not not (b2 & 0x80)

        if f['masked']:
            hlen += 4
            if blen < hlen:
                return None

        length = b2 & 0x7f

        if length == 126:
            hlen += 2
            if blen < hlen:
                return None
            length, = struct.unpack('>H', buf[2:4])
        elif length == 127:
            hlen += 8
            if blen < hlen:
                return None
            length, = struct.unpack('>Q', buf[2:10])

        f['length'] = hlen + length

        if blen < f['length']:
            return None

        if f['masked']:
            # unmask payload
            mask_key = buf[hlen-4:hlen]
            f['payload'] = self._unmask(buf[hlen:(hlen+length)], mask_key)
        else:
            f['payload'] = buf[hlen:(hlen+length)]

        return f

