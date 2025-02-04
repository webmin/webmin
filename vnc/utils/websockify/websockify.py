#!/usr/bin/env sh
set -e
cd "$(dirname "$0")"
exec python3 -m websockify "$@"
