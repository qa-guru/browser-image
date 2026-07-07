#!/bin/sh
set -eu
export MOZ_DISABLE_CONTENT_SANDBOX=1
FIREFOX_BIN="${FIREFOX_BIN:-/opt/firefox/firefox}"
exec "${FIREFOX_BIN}" -no-remote "$@"
