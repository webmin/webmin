#!/usr/bin/env python

'''
Python WebSocket server base
Copyright 2011 Joel Martin
Copyright 2016-2018 Pierre Ossman
Licensed under LGPL version 3 (see docs/LICENSE.LGPL-3)
'''

import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

from websockify.websocket import WebSocket, WebSocketWantReadError, WebSocketWantWriteError

class HttpWebSocket(WebSocket):
    """Class to glue websocket and http request functionality together"""
    def __init__(self, request_handler):
        super().__init__()

        self.request_handler = request_handler

    def send_response(self, code, message=None):
        self.request_handler.send_response(code, message)

    def send_header(self, keyword, value):
        self.request_handler.send_header(keyword, value)

    def end_headers(self):
        self.request_handler.end_headers()


class WebSocketRequestHandlerMixIn:
    """WebSocket request handler mix-in class

    This class modifies and existing request handler to handle
    WebSocket requests. The request handler will continue to function
    as before, except that WebSocket requests are intercepted and the
    methods handle_upgrade() and handle_websocket() are called. The
    standard do_GET() will be called for normal requests.

    The class instance SocketClass can be overridden with the class to
    use for the WebSocket connection.
    """

    SocketClass = HttpWebSocket

    def handle_one_request(self):
        """Extended request handler

        This is where WebSocketRequestHandler redirects requests to the
        new methods. Any sub-classes must call this method in order for
        the calls to function.
        """
        self._real_do_GET = self.do_GET
        self.do_GET = self._websocket_do_GET
        try:
            super().handle_one_request()
        finally:
            self.do_GET = self._real_do_GET

    def _websocket_do_GET(self):
        # Checks if it is a websocket request and redirects
        self.do_GET = self._real_do_GET

        if (self.headers.get('upgrade') and
            self.headers.get('upgrade').lower() == 'websocket'):
            self.handle_upgrade()
        else:
            self.do_GET()

    def handle_upgrade(self):
        """Initial handler for a WebSocket request

        This method is called when a WebSocket is requested. By default
        it will create a WebSocket object and perform the negotiation.
        The WebSocket object will then replace the request object and
        handle_websocket() will be called.
        """
        websocket = self.SocketClass(self)
        try:
            websocket.accept(self.request, self.headers)
        except Exception:
            exc = sys.exc_info()[1]
            self.send_error(400, str(exc))
            return

        self.request = websocket

        # Other requests cannot follow Websocket data
        self.close_connection = True

        self.handle_websocket()

    def handle_websocket(self):
        """Handle a WebSocket connection.
        
        This is called when the WebSocket is ready to be used. A
        sub-class should perform the necessary communication here and
        return once done.
        """
        pass

# Convenient ready made classes

class WebSocketRequestHandler(WebSocketRequestHandlerMixIn,
                              BaseHTTPRequestHandler):
    pass

class WebSocketServer(HTTPServer):
    pass
