import logging.handlers as handlers, socket, os, time


class WebsockifySysLogHandler(handlers.SysLogHandler):
    """
    A handler class that sends proper Syslog-formatted messages,
    as defined by RFC 5424.
    """

    _legacy_head_fmt = '<{pri}>{ident}[{pid}]: '
    _rfc5424_head_fmt = '<{pri}>1 {timestamp} {hostname} {ident} {pid} - - '
    _head_fmt = _rfc5424_head_fmt
    _legacy = False
    _timestamp_fmt = '%Y-%m-%dT%H:%M:%SZ'
    _max_hostname = 255
    _max_ident = 24 #safer for old daemons
    _send_length = False
    _tail = '\n'


    ident = None


    def __init__(self, address=('localhost', handlers.SYSLOG_UDP_PORT),
                 facility=handlers.SysLogHandler.LOG_USER,
                 socktype=None, ident=None, legacy=False):
        """
        Initialize a handler.

        If address is specified as a string, a UNIX socket is used. To log to a
        local syslogd, "WebsockifySysLogHandler(address="/dev/log")" can be
        used. If facility is not specified, LOG_USER is used. If socktype is
        specified as socket.SOCK_DGRAM or socket.SOCK_STREAM, that specific
        socket type will be used. For Unix sockets, you can also specify a
        socktype of None, in which case socket.SOCK_DGRAM will be used, falling
        back to socket.SOCK_STREAM. If ident is specified, this string will be
        used as the application name in all messages sent. Set legacy to True
        to use the old version of the protocol.
        """

        self.ident = ident

        if legacy:
            self._legacy = True
            self._head_fmt = self._legacy_head_fmt

        super().__init__(address, facility, socktype)


    def emit(self, record):
        """
        Emit a record.

        The record is formatted, and then sent to the syslog server. If
        exception information is present, it is NOT sent to the server.
        """

        try:
            # Gather info.
            text = self.format(record).replace(self._tail, ' ')
            if not text: # nothing to log
                return

            pri = self.encodePriority(self.facility,
                                      self.mapPriority(record.levelname))

            timestamp = time.strftime(self._timestamp_fmt, time.gmtime());

            hostname = socket.gethostname()[:self._max_hostname]

            if self.ident:
                ident = self.ident[:self._max_ident]
            else:
                ident = ''

            pid = os.getpid() # shouldn't need truncation

            # Format the header.
            head = {
                'pri': pri,
                'timestamp': timestamp,
                'hostname': hostname,
                'ident': ident,
                'pid': pid,
            }
            msg = self._head_fmt.format(**head).encode('ascii', 'ignore')

            # Encode text as plain ASCII if possible, else use UTF-8 with BOM.
            try:
                msg += text.encode('ascii')
            except UnicodeEncodeError:
                msg += text.encode('utf-8-sig')

            # Add length or tail character, if necessary.
            if self.socktype != socket.SOCK_DGRAM:
                if self._send_length:
                    msg = ('%d ' % len(msg)).encode('ascii') + msg
                else:
                    msg += self._tail.encode('ascii')

            # Send the message.
            if self.unixsocket:
                try:
                    self.socket.send(msg)
                except OSError:
                    self._connect_unixsocket(self.address)
                    self.socket.send(msg)

            else:
                if self.socktype == socket.SOCK_DGRAM:
                    self.socket.sendto(msg, self.address)
                else:
                    self.socket.sendall(msg)

        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            self.handleError(record)
