#!/usr/bin/env bash
set -euo pipefail

GECKODRIVER_PORT="${GECKODRIVER_PORT:-4444}"

# Min image has no Xvfb/VNC stack — Firefox must run headless.
export MOZ_HEADLESS=1

container_host="$(hostname -f 2>/dev/null || hostname)"

exec geckodriver   --host 0.0.0.0   --port "${GECKODRIVER_PORT}"   --allow-hosts localhost 127.0.0.1 "${container_host}"
