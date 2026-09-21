#!/bin/sh
set -eu

CHROME_BIN="${CHROME_BIN:-/opt/chrome/chrome}"

# Chromium honours only the LAST --disable-features switch: chromedriver always
# appends its own (e.g. IgnoreDuplicateNavs,Prewarm), so a plain prepend would
# be silently overwritten. Merge every occurrence into one trailing switch.
disabled="UseDnsHttpsSvcb,DnsHttpsSvcb"
n=$#
while [ "$n" -gt 0 ]; do
  case "$1" in
    --disable-features=*) disabled="${disabled},${1#*=}" ;;
    --disable-features) ;; # bare switch carries no value
    *) set -- "$@" "$1" ;;
  esac
  shift
  n=$((n - 1))
done

exec "${CHROME_BIN}" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  "$@" \
  "--disable-features=${disabled}"
