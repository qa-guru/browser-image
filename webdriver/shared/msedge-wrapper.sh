#!/bin/sh
set -eu
EDGE_BIN="${EDGE_BIN:-/opt/microsoft/msedge/microsoft-edge}"

# Same last-wins merge as chrome-wrapper.sh: edgedriver appends its own
# --disable-features, which would overwrite a prepended one.
disabled="UseDnsHttpsSvcb,DnsHttpsSvcb"
n=$#
while [ "$n" -gt 0 ]; do
  case "$1" in
    --disable-features=*) disabled="${disabled},${1#*=}" ;;
    --disable-features) ;;
    *) set -- "$@" "$1" ;;
  esac
  shift
  n=$((n - 1))
done

exec "${EDGE_BIN}" --no-sandbox --disable-dev-shm-usage --disable-gpu "$@" "--disable-features=${disabled}"
