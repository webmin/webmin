#!/usr/bin/env sh
set -e -x
cd "$(dirname "$0")"
(cd .. && python3 setup.py sdist --dist-dir docker/)
docker build -t novnc/websockify .
