#!/usr/bin/env bash
set -euo pipefail

CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"

exec chromedriver \
  --port="${CHROMEDRIVER_PORT}" \
  --allowed-ips= \
  --allowed-origins='*'
