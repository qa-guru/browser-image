#!/usr/bin/env bash
set -euo pipefail

EDGEDRIVER_PORT="${EDGEDRIVER_PORT:-4444}"

exec msedgedriver   --port="${EDGEDRIVER_PORT}"   --allowed-ips=   --allowed-origins='*'   --disable-dev-shm-usage
