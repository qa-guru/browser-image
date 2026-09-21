#!/bin/sh
set -eu

# Installed in place of the real Chromium-family binary (moved to "<name>.real")
# so every Playwright launch path (chrome / chrome-headless-shell / msedge)
# gets grid-required flags. Chromium honours only the LAST --disable-features
# switch and Playwright appends its own, so merge every occurrence into one
# trailing switch.
REAL_BIN="${0}.real"
if [ ! -x "${REAL_BIN}" ]; then
  echo "chromium-wrapper: ${REAL_BIN} not found or not executable" >&2
  exit 1
fi

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

exec "${REAL_BIN}" "$@" "--disable-features=${disabled}"
