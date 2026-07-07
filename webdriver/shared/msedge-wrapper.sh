#!/bin/sh
set -eu
EDGE_BIN="${EDGE_BIN:-/opt/microsoft/msedge/microsoft-edge}"
exec "${EDGE_BIN}" --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"
