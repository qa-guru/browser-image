#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$(realpath "$0")")/common.sh"

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
MANUAL_SESSION="$(normalize_bool "${MANUAL_SESSION:-false}")"
PW_HEADLESS="$(normalize_bool "${PW_HEADLESS:-true}")"

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
  terminate_pid "${server_pid:-}"
  terminate_pid "${headed_pid:-}"
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

if [[ "${MANUAL_SESSION}" == "true" && "${PW_HEADLESS}" == "false" && "${ENABLE_VNC}" == "true" ]]; then
  node /opt/playwright/launch-headed-browser.js >>/tmp/headed-launch.log 2>&1 &
  headed_pid=$!
fi

node /opt/playwright/server.cjs &
server_pid=$!
wait "${server_pid}"
