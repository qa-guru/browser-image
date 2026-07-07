#!/usr/bin/env bash
set -euo pipefail

GECKODRIVER_PORT="${GECKODRIVER_PORT:-4444}"

exec geckodriver   --host 0.0.0.0   --port "${GECKODRIVER_PORT}"   --allow-hosts localhost 127.0.0.1
