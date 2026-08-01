#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$(realpath "$0")")/common.sh"

CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY="${DISPLAY:-:${DISPLAY_NUM}}"
SCREEN_RESOLUTION="${SCREEN_RESOLUTION:-1920x1080x24}"

normalize_bool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

ENABLE_VNC="$(normalize_bool "${ENABLE_VNC:-false}")"
ENABLE_VIDEO="$(normalize_bool "${ENABLE_VIDEO:-false}")"

needs_display=false
if [[ "${ENABLE_VNC}" == "true" || "${ENABLE_VIDEO}" == "true" ]]; then
  needs_display=true
fi

wait_for_x() {
  local i
  for ((i = 0; i < 50; i++)); do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "X display ${DISPLAY} did not become ready in time" >&2
  return 1
}

cleanup() {
  terminate_pid "${driver_pid:-}"
  terminate_pid "${devtools_proxy_pid:-}"
  terminate_pid "${vnc_pid:-}"
  terminate_pid "${xvfb_pid:-}"
}

trap cleanup EXIT
trap 'exit 143' TERM INT

if [[ "${needs_display}" == "true" ]]; then
  Xvfb "${DISPLAY}" -screen 0 "${SCREEN_RESOLUTION}" -ac +extension RANDR -noreset -listen tcp >/dev/null 2>&1 &
  xvfb_pid=$!
  wait_for_x
fi

if [[ "${ENABLE_VNC}" == "true" ]]; then
  x11vnc \
    -display "${DISPLAY}" \
    -rfbport 5900 \
    -forever \
    -shared \
    -passwd selenoid \
    >/dev/null 2>&1 &
  vnc_pid=$!
fi

# Static CDP proxy on 7070: bridges the hub (hub-HAR / se:cdp / /devtools/<id>/)
# to chromedriver's RANDOM --remote-debugging-port. Optional binary — absence
# must not break the session.
if command -v devtools-proxy >/dev/null 2>&1; then
  devtools-proxy &
  devtools_proxy_pid=$!
fi

chromedriver \
  --port="${CHROMEDRIVER_PORT}" \
  --allowed-ips= \
  --allowed-origins='*' \
  --disable-dev-shm-usage &
driver_pid=$!
wait "${driver_pid}"
