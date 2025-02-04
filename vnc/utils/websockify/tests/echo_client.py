#!/usr/bin/env python

import os
import sys
import optparse
import select

sys.path.insert(0,os.path.join(os.path.dirname(__file__), ".."))
from websockify.websocket import WebSocket, \
    WebSocketWantReadError, WebSocketWantWriteError

parser = optparse.OptionParser(usage="%prog URL")
(opts, args) = parser.parse_args()

if len(args) == 1:
    URL = args[0]
else:
    parser.error("Invalid arguments")

sock = WebSocket()
print("Connecting to %s..." % URL)
sock.connect(URL)
print("Connected.")

def send(msg):
    while True:
        try:
            sock.sendmsg(msg)
            break
        except WebSocketWantReadError:
            msg = ''
            ins, outs, excepts = select.select([sock], [], [])
            if excepts: raise Exception("Socket exception")
        except WebSocketWantWriteError:
            msg = ''
            ins, outs, excepts = select.select([], [sock], [])
            if excepts: raise Exception("Socket exception")

def read():
    while True:
        try:
            return sock.recvmsg()
        except WebSocketWantReadError:
            ins, outs, excepts = select.select([sock], [], [])
            if excepts: raise Exception("Socket exception")
        except WebSocketWantWriteError:
            ins, outs, excepts = select.select([], [sock], [])
            if excepts: raise Exception("Socket exception")

counter = 1
while True:
    msg = "Message #%d" % counter
    counter += 1
    send(msg)
    print("Sent message: %r" % msg)

    while True:
        ins, outs, excepts = select.select([sock], [], [], 1.0)
        if excepts: raise Exception("Socket exception")

        if ins == []:
            break

        while True:
            msg = read()
            print("Received message: %r" % msg)

            if not sock.pending():
                break
