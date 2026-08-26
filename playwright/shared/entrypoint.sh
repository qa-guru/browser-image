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
  terminate_pid "${devtools_proxy_pid:-}"
  terminate_pid "${vnc_pid:-}"
  terminate_pid "${fluxbox_pid:-}"
  terminate_pid "${xvfb_pid:-}"
}

trap cleanup EXIT
trap 'exit 143' TERM INT

wait_for_wm() {
  local i
  for ((i = 0; i < 50; i++)); do
    if xprop -root -display "${DISPLAY}" _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -qi 'window id'; then
      return 0
    fi
    sleep 0.1
  done
  echo "fluxbox did not advertise a WM in time; continuing" >&2
}

# Burst-maximize top-level windows so Firefox/WebKit fill Xvfb even if they
# mapped before fluxbox apps rules applied. Do not run forever (dialogs).
start_window_fitter() {
  if ! command -v wmctrl >/dev/null 2>&1; then
    return 0
  fi
  local w h
  w="${SCREEN_RESOLUTION%%x*}"
  h="${SCREEN_RESOLUTION#*x}"
  h="${h%%x*}"
  (
    set +e
    for ((i = 0; i < 80; i++)); do
      while read -r id; do
        [ -n "${id}" ] || continue
        wmctrl -i -r "${id}" -b add,maximized_vert,maximized_horz >/dev/null 2>&1
        wmctrl -i -r "${id}" -e "0,0,0,${w},${h}" >/dev/null 2>&1
      done < <(wmctrl -l 2>/dev/null | awk 'tolower($0) ~ /xmessage|fbsetbg/ {next} {print $1}')
      sleep 0.25
    done
  ) &
}

start_fluxbox() {
  # Chrome/Firefox on raw Xvfb ignore --window-size and --start-maximized.
  # fluxbox owns the display; apps file strips WM chrome and maximizes.
  if ! command -v fluxbox >/dev/null 2>&1; then
    return 0
  fi
  local fbhome="${HOME:-/home/pwuser}"
  mkdir -p "${fbhome}/.fluxbox"
  # Fluxbox calls fbsetbg on start unless overlay has `background: unset`.
  # Without feh/Esetroot that pops xmessage ("install Eterm") over VNC.
  cat > "${fbhome}/.fluxbox/init" <<EOF
session.styleOverlay: ${fbhome}/.fluxbox/overlay
session.screen0.toolbar.visible: false
session.screen0.workspaces: 1
session.screen0.defaultDeco: NONE
session.screen0.fullMaximization: true
session.screen0.rootCommand: fbsetroot -solid black
EOF
  cat > "${fbhome}/.fluxbox/overlay" <<'EOF'
background: unset
EOF
  cat > "${fbhome}/.fluxbox/startup" <<'EOF'
#!/bin/sh
fbsetroot -solid black
exec fluxbox
EOF
  chmod +x "${fbhome}/.fluxbox/startup"
  local apps_src="/opt/playwright/fluxbox.apps"
  if [[ -f "${apps_src}" ]]; then
    cp "${apps_src}" "${fbhome}/.fluxbox/apps"
  else
    cat > "${fbhome}/.fluxbox/apps" <<'EOF'
[app] (name=xmessage)
  [Hidden] {yes}
  [Minimized] {yes}
[end]
[app] (name=*)
  [Deco] {NONE}
  [Maximized] {yes}
[end]
EOF
  fi
  fluxbox >/tmp/fluxbox.log 2>&1 &
  fluxbox_pid=$!
  if command -v fbsetroot >/dev/null 2>&1; then
    fbsetroot -solid black >/dev/null 2>&1 || true
  fi
  pkill -f '^xmessage' >/dev/null 2>&1 || true
  local i
  for ((i = 0; i < 20; i++)); do
    if kill -0 "${fluxbox_pid}" 2>/dev/null; then
      wait_for_wm
      return 0
    fi
    sleep 0.1
  done
}

if [[ "${needs_display}" == "true" ]]; then
  Xvfb "${DISPLAY}" -screen 0 "${SCREEN_RESOLUTION}" -ac +extension RANDR -noreset -listen tcp >/dev/null 2>&1 &
  xvfb_pid=$!
  wait_for_x
  start_fluxbox
  start_window_fitter
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
# to Chromium's RANDOM --remote-debugging-port. Optional binary — absence must
# not break the session. Firefox/WebKit images do not ship this binary.
if command -v devtools-proxy >/dev/null 2>&1; then
  devtools-proxy &
  devtools_proxy_pid=$!
fi

node /opt/playwright/server.cjs &
server_pid=$!

# Connect to launchServer (do not launch() a second browser — that nested a
# small Firefox/WebKit window on VNC). Helper waits for HTTP :PW_PORT.
if [[ "${MANUAL_SESSION}" == "true" && "${PW_HEADLESS}" == "false" && "${ENABLE_VNC}" == "true" ]]; then
  node /opt/playwright/launch-headed-browser.js >>/tmp/headed-launch.log 2>&1 &
  headed_pid=$!
fi

wait "${server_pid}"
