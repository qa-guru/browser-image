#!/bin/sh
set -eu

CHROME_BIN="${CHROME_BIN:-/opt/chrome/chrome}"

exec "${CHROME_BIN}" \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  "$@"
