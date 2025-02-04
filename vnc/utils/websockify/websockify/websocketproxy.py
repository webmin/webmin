#!/usr/bin/env python

'''
A WebSocket to TCP socket proxy with support for "wss://" encryption.
Copyright 2011 Joel Martin
Licensed under LGPL version 3 (see docs/LICENSE.LGPL-3)

You can make a cert/key with openssl using:
openssl req -new -x509 -days 365 -nodes -out self.pem -keyout self.pem
as taken from http://docs.python.org/dev/library/ssl.html#certificates

'''

import signal, socket, optparse, time, os, sys, subprocess, logging, errno, ssl, stat
from socketserver import ThreadingMixIn
from http.server import HTTPServer

import select
from websockify import websockifyserver
from websockify import auth_plugins as auth
from urllib.parse import parse_qs, urlparse

class ProxyRequestHandler(websockifyserver.WebSockifyRequestHandler):

    buffer_size = 65536

    traffic_legend = """
Traffic Legend:
    }  - Client receive
    }. - Client receive partial
    {  - Target receive

    >  - Target send
    >. - Target send partial
    <  - Client send
    <. - Client send partial
"""

    def send_auth_error(self, ex):
        self.send_response(ex.code, ex.msg)
        self.send_header('Content-Type', 'text/html')
        for name, val in ex.headers.items():
            self.send_header(name, val)

        self.end_headers()

    def validate_connection(self):
        if not self.server.token_plugin:
            return

        host, port = self.get_target(self.server.token_plugin)
        if host == 'unix_socket':
            self.server.unix_target = port

        else:
            self.server.target_host = host
            self.server.target_port = port

    def auth_connection(self):
        if not self.server.auth_plugin:
            return

        try:
            # get client certificate data
            client_cert_data = self.request.getpeercert()
            # extract subject information
            client_cert_subject = client_cert_data['subject']
            # flatten data structure
            client_cert_subject = dict([x[0] for x in client_cert_subject])
            # add common name to headers (apache +StdEnvVars style)
            self.headers['SSL_CLIENT_S_DN_CN'] = client_cert_subject['commonName']
        except (TypeError, AttributeError, KeyError):
            # not a SSL connection or client presented no certificate with valid data
            pass

        try:
            self.server.auth_plugin.authenticate(
                headers=self.headers, target_host=self.server.target_host,
                target_port=self.server.target_port)
        except auth.AuthenticationError:
            ex = sys.exc_info()[1]
            self.send_auth_error(ex)
            raise

    def new_websocket_client(self):
        """
        Called after a new WebSocket connection has been established.
        """
        # Checking for a token is done in validate_connection()

        # Connect to the target
        if self.server.wrap_cmd:
            msg = "connecting to command: '%s' (port %s)" % (" ".join(self.server.wrap_cmd), self.server.target_port)
        elif self.server.unix_target:
            msg = "connecting to unix socket: %s" % self.server.unix_target
        else:
            msg = "connecting to: %s:%s" % (
                                    self.server.target_host, self.server.target_port)

        if self.server.ssl_target:
            msg += " (using SSL)"
        self.log_message(msg)

        try:
            tsock = websockifyserver.WebSockifyServer.socket(self.server.target_host,
                                                           self.server.target_port,
                                                           connect=True,
                                                           use_ssl=self.server.ssl_target,
                                                           unix_socket=self.server.unix_target)
        except Exception as e:
            self.log_message("Failed to connect to %s:%s: %s",
                             self.server.target_host, self.server.target_port, e)
            raise self.CClose(1011, "Failed to connect to downstream server")

        # Option unavailable when listening to unix socket
        if not self.server.unix_listen:
            self.request.setsockopt(socket.SOL_TCP, socket.TCP_NODELAY, 1)
        if not self.server.wrap_cmd and not self.server.unix_target:
            tsock.setsockopt(socket.SOL_TCP, socket.TCP_NODELAY, 1)

        self.print_traffic(self.traffic_legend)

        # Start proxying
        try:
            self.do_proxy(tsock)
        finally:
            if tsock:
                tsock.shutdown(socket.SHUT_RDWR)
                tsock.close()
                if self.verbose:
                    self.log_message("%s:%s: Closed target",
                            self.server.target_host, self.server.target_port)

    def get_target(self, target_plugin):
        """
        Gets a token from either the path or the host,
        depending on --host-token, and looks up a target
        for that token using the token plugin. Used by
        validate_connection() to set target_host and target_port.
        """
        # The files in targets contain the lines
        # in the form of token: host:port

        if self.host_token:
            # Use hostname as token
            token = self.headers.get('Host')

            # Remove port from hostname, as it'll always be the one where
            # websockify listens (unless something between the client and
            # websockify is redirecting traffic, but that's beside the point)
            if token:
                token = token.partition(':')[0]

        else:
            # Extract the token parameter from url
            args = parse_qs(urlparse(self.path)[4]) # 4 is the query from url

            if 'token' in args and len(args['token']):
                token = args['token'][0].rstrip('\n')
            else:
                token = None

        if token is None:
            raise self.server.EClose("Token not present")

        result_pair = target_plugin.lookup(token)

        if result_pair is not None:
            return result_pair
        else:
            raise self.server.EClose("Token '%s' not found" % token)

    def do_proxy(self, target):
        """
        Proxy client WebSocket to normal target socket.
        """
        cqueue = []
        c_pend = 0
        tqueue = []
        rlist = [self.request, target]

        if self.server.heartbeat:
            now = time.time()
            self.heartbeat = now + self.server.heartbeat
        else:
            self.heartbeat = None

        while True:
            wlist = []

            if self.heartbeat is not None:
                now = time.time()
                if now > self.heartbeat:
                    self.heartbeat = now + self.server.heartbeat
                    self.send_ping()

            if tqueue: wlist.append(target)
            if cqueue or c_pend: wlist.append(self.request)
            try:
                ins, outs, excepts = select.select(rlist, wlist, [], 1)
            except OSError:
                exc = sys.exc_info()[1]
                if hasattr(exc, 'errno'):
                    err = exc.errno
                else:
                    err = exc[0]

                if err != errno.EINTR:
                    raise
                else:
                    continue

            if excepts: raise Exception("Socket exception")

            if self.request in outs:
                # Send queued target data to the client
                c_pend = self.send_frames(cqueue)

                cqueue = []

            if self.request in ins:
                # Receive client data, decode it, and queue for target
                bufs, closed = self.recv_frames()
                tqueue.extend(bufs)

                if closed:

                    while (len(tqueue) != 0):
                        # Send queued client data to the target
                        dat = tqueue.pop(0)
                        sent = target.send(dat)
                        if sent == len(dat):
                            self.print_traffic(">")
                        else:
                            # requeue the remaining data
                            tqueue.insert(0, dat[sent:])
                            self.print_traffic(".>")

                    # TODO: What about blocking on client socket?
                    if self.verbose:
                        self.log_message("%s:%s: Client closed connection",
                                self.server.target_host, self.server.target_port)
                    raise self.CClose(closed['code'], closed['reason'])


            if target in outs:
                # Send queued client data to the target
                dat = tqueue.pop(0)
                sent = target.send(dat)
                if sent == len(dat):
                    self.print_traffic(">")
                else:
                    # requeue the remaining data
                    tqueue.insert(0, dat[sent:])
                    self.print_traffic(".>")


            if target in ins:
                # Receive target data, encode it and queue for client
                buf = target.recv(self.buffer_size)
                if len(buf) == 0:

                    # Target socket closed, flushing queues and closing client-side websocket
                    # Send queued target data to the client
                    if len(cqueue) != 0:
                        c_pend = True
                        while(c_pend):
                            c_pend = self.send_frames(cqueue)

                        cqueue = []

                    if self.verbose:
                        self.log_message("%s:%s: Target closed connection",
                                self.server.target_host, self.server.target_port)
                    raise self.CClose(1000, "Target closed")

                cqueue.append(buf)
                self.print_traffic("{")

class WebSocketProxy(websockifyserver.WebSockifyServer):
    """
    Proxy traffic to and from a WebSockets client to a normal TCP
    socket server target.
    """

    buffer_size = 65536

    def __init__(self, RequestHandlerClass=ProxyRequestHandler, *args, **kwargs):
        # Save off proxy specific options
        self.target_host    = kwargs.pop('target_host', None)
        self.target_port    = kwargs.pop('target_port', None)
        self.wrap_cmd       = kwargs.pop('wrap_cmd', None)
        self.wrap_mode      = kwargs.pop('wrap_mode', None)
        self.unix_target    = kwargs.pop('unix_target', None)
        self.ssl_target     = kwargs.pop('ssl_target', None)
        self.heartbeat      = kwargs.pop('heartbeat', None)

        self.token_plugin = kwargs.pop('token_plugin', None)
        self.host_token = kwargs.pop('host_token', None)
        self.auth_plugin = kwargs.pop('auth_plugin', None)

        # Last 3 timestamps command was run
        self.wrap_times    = [0, 0, 0]

        if self.wrap_cmd:
            wsdir = os.path.dirname(sys.argv[0])
            rebinder_path = [os.path.join(wsdir, "..", "lib"),
                             os.path.join(wsdir, "..", "lib", "websockify"),
                             os.path.join(wsdir, ".."),
                             wsdir]
            self.rebinder = None

            for rdir in rebinder_path:
                rpath = os.path.join(rdir, "rebind.so")
                if os.path.exists(rpath):
                    self.rebinder = rpath
                    break

            if not self.rebinder:
                raise Exception("rebind.so not found, perhaps you need to run make")
            self.rebinder = os.path.abspath(self.rebinder)

            self.target_host = "127.0.0.1"  # Loopback
            # Find a free high port
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.bind(('', 0))
            self.target_port = sock.getsockname()[1]
            sock.close()

            # Insert rebinder at the head of the (possibly empty) LD_PRELOAD pathlist
            ld_preloads = filter(None, [ self.rebinder, os.environ.get("LD_PRELOAD", None) ])

            os.environ.update({
                "LD_PRELOAD": os.pathsep.join(ld_preloads),
                "REBIND_OLD_PORT": str(kwargs['listen_port']),
                "REBIND_NEW_PORT": str(self.target_port)})

        super().__init__(RequestHandlerClass, *args, **kwargs)

    def run_wrap_cmd(self):
        self.msg("Starting '%s'", " ".join(self.wrap_cmd))
        self.wrap_times.append(time.time())
        self.wrap_times.pop(0)
        self.cmd = subprocess.Popen(
                self.wrap_cmd, env=os.environ, preexec_fn=_subprocess_setup)
        self.spawn_message = True

    def started(self):
        """
        Called after Websockets server startup (i.e. after daemonize)
        """
        # Need to call wrapped command after daemonization so we can
        # know when the wrapped command exits
        if self.wrap_cmd:
            dst_string = "'%s' (port %s)" % (" ".join(self.wrap_cmd), self.target_port)
        elif self.unix_target:
            dst_string = self.unix_target
        else:
            dst_string = "%s:%s" % (self.target_host, self.target_port)

        if self.listen_fd != None:
            src_string = "inetd"
        else:
            src_string = "%s:%s" % (self.listen_host, self.listen_port)

        if self.token_plugin:
            msg = "  - proxying from %s to targets generated by %s" % (
                src_string, type(self.token_plugin).__name__)
        else:
            msg = "  - proxying from %s to %s" % (
                src_string, dst_string)

        if self.ssl_target:
            msg += " (using SSL)"

        self.msg("%s", msg)

        if self.wrap_cmd:
            self.run_wrap_cmd()

    def poll(self):
        # If we are wrapping a command, check it's status

        if self.wrap_cmd and self.cmd:
            ret = self.cmd.poll()
            if ret != None:
                self.vmsg("Wrapped command exited (or daemon). Returned %s" % ret)
                self.cmd = None

        if self.wrap_cmd and self.cmd == None:
            # Response to wrapped command being gone
            if self.wrap_mode == "ignore":
                pass
            elif self.wrap_mode == "exit":
                sys.exit(ret)
            elif self.wrap_mode == "respawn":
                now = time.time()
                avg = sum(self.wrap_times)/len(self.wrap_times)
                if (now - avg) < 10:
                    # 3 times in the last 10 seconds
                    if self.spawn_message:
                        self.warn("Command respawning too fast")
                        self.spawn_message = False
                else:
                    self.run_wrap_cmd()


def _subprocess_setup():
    # Python installs a SIGPIPE handler by default. This is usually not what
    # non-Python successfulbprocesses expect.
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)


SSL_OPTIONS = {
    'default': ssl.OP_ALL,
    'tlsv1_1': ssl.PROTOCOL_SSLv23 | ssl.OP_NO_SSLv2 | ssl.OP_NO_SSLv3 |
    ssl.OP_NO_TLSv1,
    'tlsv1_2': ssl.PROTOCOL_SSLv23 | ssl.OP_NO_SSLv2 | ssl.OP_NO_SSLv3 |
    ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1,
    'tlsv1_3': ssl.PROTOCOL_SSLv23 | ssl.OP_NO_SSLv2 | ssl.OP_NO_SSLv3 |
    ssl.OP_NO_TLSv1 | ssl.OP_NO_TLSv1_1 | ssl.OP_NO_TLSv1_2,
}

def select_ssl_version(version):
    """Returns SSL options for the most secure TSL version available on this
    Python version"""
    if version in SSL_OPTIONS:
        return SSL_OPTIONS[version]
    else:
        # It so happens that version names sorted lexicographically form a list
        # from the least to the most secure
        keys = list(SSL_OPTIONS.keys())
        keys.sort()
        fallback = keys[-1]
        logger = logging.getLogger(WebSocketProxy.log_prefix)
        logger.warn("TLS version %s unsupported. Falling back to %s",
                    version, fallback)

        return SSL_OPTIONS[fallback]

def websockify_init():
    # Setup basic logging to stderr.
    stderr_handler = logging.StreamHandler()
    stderr_handler.setLevel(logging.DEBUG)
    log_formatter = logging.Formatter("%(message)s")
    stderr_handler.setFormatter(log_formatter)
    root = logging.getLogger()
    root.addHandler(stderr_handler)
    root.setLevel(logging.INFO)

    # Setup optparse.
    usage = "\n    %prog [options]"
    usage += " [source_addr:]source_port target_addr:target_port"
    usage += "\n    %prog [options]"
    usage += " --token-plugin=CLASS [source_addr:]source_port"
    usage += "\n    %prog [options]"
    usage += " --unix-target=FILE [source_addr:]source_port"
    usage += "\n    %prog [options]"
    usage += " [source_addr:]source_port -- WRAP_COMMAND_LINE"
    parser = optparse.OptionParser(usage=usage)
    parser.add_option("--verbose", "-v", action="store_true",
            help="verbose messages")
    parser.add_option("--traffic", action="store_true",
            help="per frame traffic")
    parser.add_option("--record",
            help="record sessions to FILE.[session_number]", metavar="FILE")
    parser.add_option("--daemon", "-D",
            dest="daemon", action="store_true",
            help="become a daemon (background process)")
    parser.add_option("--run-once", action="store_true",
            help="handle a single WebSocket connection and exit")
    parser.add_option("--timeout", type=int, default=0,
            help="after TIMEOUT seconds exit when not connected")
    parser.add_option("--idle-timeout", type=int, default=0,
            help="server exits after TIMEOUT seconds if there are no "
                 "active connections")
    parser.add_option("--cert", default="self.pem",
            help="SSL certificate file")
    parser.add_option("--key", default=None,
            help="SSL key file (if separate from cert)")
    parser.add_option("--key-password", default=None,
            help="SSL key password")
    parser.add_option("--ssl-only", action="store_true",
            help="disallow non-encrypted client connections")
    parser.add_option("--ssl-target", action="store_true",
            help="connect to SSL target as SSL client")
    parser.add_option("--verify-client", action="store_true",
            help="require encrypted client to present a valid certificate "
            "(needs Python 2.7.9 or newer or Python 3.4 or newer)")
    parser.add_option("--cafile", metavar="FILE",
            help="file of concatenated certificates of authorities trusted "
            "for validating clients (only effective with --verify-client). "
            "If omitted, system default list of CAs is used.")
    parser.add_option("--ssl-version", type="choice", default="default",
            choices=["default", "tlsv1_1", "tlsv1_2", "tlsv1_3"], action="store",
            help="minimum TLS version to use (default, tlsv1_1, tlsv1_2, tlsv1_3)")
    parser.add_option("--ssl-ciphers", action="store",
            help="list of ciphers allowed for connection. For a list of "
            "supported ciphers run `openssl ciphers`")
    parser.add_option("--unix-listen",
            help="listen to unix socket", metavar="FILE", default=None)
    parser.add_option("--unix-listen-mode", default=None,
            help="specify mode for unix socket (defaults to 0600)")
    parser.add_option("--unix-target",
            help="connect to unix socket target", metavar="FILE")
    parser.add_option("--inetd",
            help="inetd mode, receive listening socket from stdin", action="store_true")
    parser.add_option("--web", default=None, metavar="DIR",
            help="run webserver on same port. Serve files from DIR.")
    parser.add_option("--web-auth", action="store_true",
            help="require authentication to access webserver.")
    parser.add_option("--wrap-mode", default="exit", metavar="MODE",
            choices=["exit", "ignore", "respawn"],
            help="action to take when the wrapped program exits "
            "or daemonizes: exit (default), ignore, respawn")
    parser.add_option("--prefer-ipv6", "-6",
            action="store_true", dest="source_is_ipv6",
            help="prefer IPv6 when resolving source_addr")
    parser.add_option("--libserver", action="store_true",
            help="use Python library SocketServer engine")
    parser.add_option("--target-config", metavar="FILE",
            dest="target_cfg",
            help="Configuration file containing valid targets "
            "in the form 'token: host:port' or, alternatively, a "
            "directory containing configuration files of this form "
            "(DEPRECATED: use `--token-plugin TokenFile --token-source "
            " path/to/token/file` instead)")
    parser.add_option("--token-plugin", default=None, metavar="CLASS",
                      help="use a Python class, usually one from websockify.token_plugins, "
                           "such as TokenFile, to process tokens into host:port pairs")
    parser.add_option("--token-source", default=None, metavar="ARG",
                      help="an argument to be passed to the token plugin "
                           "on instantiation")
    parser.add_option("--host-token", action="store_true",
                      help="use the host HTTP header as token instead of the "
                           "token URL query parameter")
    parser.add_option("--auth-plugin", default=None, metavar="CLASS",
                      help="use a Python class, usually one from websockify.auth_plugins, "
                           "such as BasicHTTPAuth, to determine if a connection is allowed")
    parser.add_option("--auth-source", default=None, metavar="ARG",
                      help="an argument to be passed to the auth plugin "
                           "on instantiation")
    parser.add_option("--heartbeat", type=int, default=0, metavar="INTERVAL",
            help="send a ping to the client every INTERVAL seconds")
    parser.add_option("--log-file", metavar="FILE",
            dest="log_file",
            help="File where logs will be saved")
    parser.add_option("--syslog", default=None, metavar="SERVER",
            help="Log to syslog server. SERVER can be local socket, "
                 "such as /dev/log, or a UDP host:port pair.")
    parser.add_option("--legacy-syslog", action="store_true",
                      help="Use the old syslog protocol instead of RFC 5424. "
                           "Use this if the messages produced by websockify seem abnormal.")
    parser.add_option("--file-only", action="store_true",
                      help="use this to disable directory listings in web server.")

    (opts, args) = parser.parse_args()


    # Validate options.

    if opts.token_source and not opts.token_plugin:
        parser.error("You must use --token-plugin to use --token-source")

    if opts.host_token and not opts.token_plugin:
        parser.error("You must use --token-plugin to use --host-token")

    if opts.auth_source and not opts.auth_plugin:
        parser.error("You must use --auth-plugin to use --auth-source")

    if opts.web_auth and not opts.auth_plugin:
        parser.error("You must use --auth-plugin to use --web-auth")

    if opts.web_auth and not opts.web:
        parser.error("You must use --web to use --web-auth")

    if opts.legacy_syslog and not opts.syslog:
        parser.error("You must use --syslog to use --legacy-syslog")


    opts.ssl_options = select_ssl_version(opts.ssl_version)
    del opts.ssl_version


    if opts.log_file:
        # Setup logging to user-specified file.
        opts.log_file = os.path.abspath(opts.log_file)
        log_file_handler = logging.FileHandler(opts.log_file)
        log_file_handler.setLevel(logging.DEBUG)
        log_file_handler.setFormatter(log_formatter)
        root = logging.getLogger()
        root.addHandler(log_file_handler)

    del opts.log_file

    if opts.syslog:
        # Determine how to connect to syslog...
        if opts.syslog.count(':'):
            # User supplied a host:port pair.
            syslog_host, syslog_port = opts.syslog.rsplit(':', 1)
            try:
                syslog_port = int(syslog_port)
            except ValueError:
                parser.error("Error parsing syslog port")
            syslog_dest = (syslog_host, syslog_port)
        else:
            # User supplied a local socket file.
            syslog_dest = os.path.abspath(opts.syslog)

        from websockify.sysloghandler import WebsockifySysLogHandler

        # Determine syslog facility.
        if opts.daemon:
            syslog_facility = WebsockifySysLogHandler.LOG_DAEMON
        else:
            syslog_facility = WebsockifySysLogHandler.LOG_USER

        # Start logging to syslog.
        syslog_handler = WebsockifySysLogHandler(address=syslog_dest,
                                                 facility=syslog_facility,
                                                 ident='websockify',
                                                 legacy=opts.legacy_syslog)
        syslog_handler.setLevel(logging.DEBUG)
        syslog_handler.setFormatter(log_formatter)
        root = logging.getLogger()
        root.addHandler(syslog_handler)

    del opts.syslog
    del opts.legacy_syslog

    if opts.verbose:
        root = logging.getLogger()
        root.setLevel(logging.DEBUG)


    # Transform to absolute path as daemon may chdir
    if opts.target_cfg:
        opts.target_cfg = os.path.abspath(opts.target_cfg)

    if opts.target_cfg:
        opts.token_plugin = 'TokenFile'
        opts.token_source = opts.target_cfg

    del opts.target_cfg

    if sys.argv.count('--'):
        opts.wrap_cmd = args[1:]
    else:
        opts.wrap_cmd = None

    if not websockifyserver.ssl and opts.ssl_target:
        parser.error("SSL target requested and Python SSL module not loaded.");

    if opts.ssl_only and not os.path.exists(opts.cert):
        parser.error("SSL only and %s not found" % opts.cert)

    if opts.inetd:
        opts.listen_fd = sys.stdin.fileno()
    elif opts.unix_listen:
        if opts.unix_listen_mode:
            try:
                # Parse octal notation (like 750)
                opts.unix_listen_mode = int(opts.unix_listen_mode, 8)
            except ValueError:
                parser.error("Error parsing listen unix socket mode")
        else:
            # Default to 0600 (Owner Read/Write)
            opts.unix_listen_mode = stat.S_IREAD | stat.S_IWRITE
    else:
        if len(args) < 1:
            parser.error("Too few arguments")
        arg = args.pop(0)
        # Parse host:port and convert ports to numbers
        if arg.count(':') > 0:
            opts.listen_host, opts.listen_port = arg.rsplit(':', 1)
            opts.listen_host = opts.listen_host.strip('[]')
        else:
            opts.listen_host, opts.listen_port = '', arg

        try:
            opts.listen_port = int(opts.listen_port)
        except ValueError:
            parser.error("Error parsing listen port")

    del opts.inetd

    if opts.wrap_cmd or opts.unix_target or opts.token_plugin:
        opts.target_host = None
        opts.target_port = None
    else:
        if len(args) < 1:
            parser.error("Too few arguments")
        arg = args.pop(0)
        if arg.count(':') > 0:
            opts.target_host, opts.target_port = arg.rsplit(':', 1)
            opts.target_host = opts.target_host.strip('[]')
        else:
            parser.error("Error parsing target")

        try:
            opts.target_port = int(opts.target_port)
        except ValueError:
            parser.error("Error parsing target port")

    if len(args) > 0 and opts.wrap_cmd == None:
        parser.error("Too many arguments")

    if opts.token_plugin is not None:
        if '.' not in opts.token_plugin:
            opts.token_plugin = (
                'websockify.token_plugins.%s' % opts.token_plugin)

        token_plugin_module, token_plugin_cls = opts.token_plugin.rsplit('.', 1)

        __import__(token_plugin_module)
        token_plugin_cls = getattr(sys.modules[token_plugin_module], token_plugin_cls)

        opts.token_plugin = token_plugin_cls(opts.token_source)

    del opts.token_source

    if opts.auth_plugin is not None:
        if '.' not in opts.auth_plugin:
            opts.auth_plugin = 'websockify.auth_plugins.%s' % opts.auth_plugin

        auth_plugin_module, auth_plugin_cls = opts.auth_plugin.rsplit('.', 1)

        __import__(auth_plugin_module)
        auth_plugin_cls = getattr(sys.modules[auth_plugin_module], auth_plugin_cls)

        opts.auth_plugin = auth_plugin_cls(opts.auth_source)

    del opts.auth_source

    # Create and start the WebSockets proxy
    libserver = opts.libserver
    del opts.libserver
    if libserver:
        # Use standard Python SocketServer framework
        server = LibProxyServer(**opts.__dict__)
        server.serve_forever()
    else:
        # Use internal service framework
        server = WebSocketProxy(**opts.__dict__)
        server.start_server()


class LibProxyServer(ThreadingMixIn, HTTPServer):
    """
    Just like WebSocketProxy, but uses standard Python SocketServer
    framework.
    """

    def __init__(self, RequestHandlerClass=ProxyRequestHandler, **kwargs):
        # Save off proxy specific options
        self.target_host    = kwargs.pop('target_host', None)
        self.target_port    = kwargs.pop('target_port', None)
        self.wrap_cmd       = kwargs.pop('wrap_cmd', None)
        self.wrap_mode      = kwargs.pop('wrap_mode', None)
        self.unix_target    = kwargs.pop('unix_target', None)
        self.ssl_target     = kwargs.pop('ssl_target', None)
        self.token_plugin   = kwargs.pop('token_plugin', None)
        self.auth_plugin    = kwargs.pop('auth_plugin', None)
        self.heartbeat      = kwargs.pop('heartbeat', None)

        self.token_plugin = None
        self.auth_plugin = None
        self.daemon = False

        # Server configuration
        listen_host    = kwargs.pop('listen_host', '')
        listen_port    = kwargs.pop('listen_port', None)
        web            = kwargs.pop('web', '')

        # Configuration affecting base request handler
        self.only_upgrade   = not web
        self.verbose   = kwargs.pop('verbose', False)
        record = kwargs.pop('record', '')
        if record:
            self.record = os.path.abspath(record)
        self.run_once  = kwargs.pop('run_once', False)
        self.handler_id = 0

        for arg in kwargs.keys():
            print("warning: option %s ignored when using --libserver" % arg)

        if web:
            os.chdir(web)

        super().__init__((listen_host, listen_port), RequestHandlerClass)


    def process_request(self, request, client_address):
        """Override process_request to implement a counter"""
        self.handler_id += 1
        super().process_request(request, client_address)


if __name__ == '__main__':
    websockify_init()
