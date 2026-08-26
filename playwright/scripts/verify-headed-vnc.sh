#!/usr/bin/env bash
# Probe headed VNC: one maximized browser window, no xmessage.
# Usage: verify-headed-vnc.sh [image ...]
# Default: local qaguru/playwright-{chromium,firefox,webkit}:1.61.1
set -euo pipefail

W="${SCREEN_W:-1920}"
H="${SCREEN_H:-1080}"
MIN_W="${MIN_W:-1800}"
MIN_H="${MIN_H:-1000}"
WAIT_S="${WAIT_S:-25}"

images=("$@")
if [[ ${#images[@]} -eq 0 ]]; then
  images=(
    qaguru/playwright-chromium:1.61.1
    qaguru/playwright-firefox:1.61.1
    qaguru/playwright-webkit:1.61.1
  )
fi

fail=0
for image in "${images[@]}"; do
  name="pw-headed-$(echo "${image}" | tr '/:' '--')"
  docker rm -f "${name}" >/dev/null 2>&1 || true
  echo "== ${image} =="
  docker run -d --name "${name}" --shm-size=2g \
    -e ENABLE_VNC=true \
    -e ENABLE_VIDEO=false \
    -e PW_HEADLESS=false \
    -e MANUAL_SESSION=true \
    -e "SCREEN_RESOLUTION=${W}x${H}x24" \
    "${image}" >/dev/null

  ok=0
  for ((i = 0; i < WAIT_S; i++)); do
    if docker exec "${name}" node -e "require('http').get('http://127.0.0.1:3000/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 1
  done
  if [[ "${ok}" != 1 ]]; then
    echo "FAIL ${image}: server :3000 not ready"
    docker logs "${name}" 2>&1 | tail -30
    docker rm -f "${name}" >/dev/null
    fail=1
    continue
  fi
  sleep 4

  if docker exec "${name}" sh -c 'pgrep -x xmessage >/dev/null 2>&1'; then
    echo "FAIL ${image}: xmessage is running"
    fail=1
  fi

  geo="$(docker exec "${name}" sh -c 'wmctrl -l -G 2>/dev/null || true')"
  echo "${geo:-"(no wmctrl windows)"}"
  if printf '%s\n' "${geo}" | grep -Eiq 'xmessage|fbsetbg|Eterm|Problem loading'; then
    echo "FAIL ${image}: error/wallpaper dialog on VNC"
    fail=1
  fi
  large_n="$(printf '%s\n' "${geo}" | awk -v minw="${MIN_W}" -v minh="${MIN_H}" '
    tolower($0) ~ /xmessage|fbsetbg/ {next}
    NF>=6 && $5+0>=minw && $6+0>=minh {n++}
    END {print n+0}
  ')"
  max_wh="$(printf '%s\n' "${geo}" | awk 'tolower($0) ~ /xmessage|fbsetbg/ {next} NF>=6 {print $5+0, $6+0}' | awk '$1*$2>m{m=$1*$2; w=$1; h=$2} END{if(w) print w,h}')"
  read -r gw gh <<<"${max_wh:-0 0}"
  if [[ "${gw}" -lt "${MIN_W}" || "${gh}" -lt "${MIN_H}" ]]; then
    echo "FAIL ${image}: largest window ${gw}x${gh} < ${MIN_W}x${MIN_H}"
    docker exec "${name}" sh -c 'cat /tmp/headed-launch.log /tmp/fluxbox.log 2>/dev/null | tail -40' || true
    fail=1
  elif [[ "${large_n}" -ne 1 ]]; then
    echo "FAIL ${image}: expected 1 fullscreen window, got ${large_n}"
    docker exec "${name}" sh -c 'cat /tmp/headed-launch.log 2>/dev/null | tail -20' || true
    fail=1
  else
    echo "OK ${image}: ${gw}x${gh} (1 window)"
  fi
  docker rm -f "${name}" >/dev/null
done

exit "${fail}"
