#!/usr/bin/env bash
# Run on the Linux Selenoid host. Measures disposable POST->sessionId sessions,
# verifies touch/screenshot/VNC, and always deletes the session.
set -euo pipefail

WEBDRIVER_URL="${1:-http://127.0.0.1:4444/wd/hub}"
COUNT="${COUNT:-5}"
APP_URL="${APP_URL:-}"
AUTH_ARGS=()
[[ -n "${SELENOID_USER:-}" ]] && AUTH_ARGS=(-u "${SELENOID_USER}:${SELENOID_PASSWORD:?}")
HUB_ROOT="${WEBDRIVER_URL%/wd/hub}"
tmp="$(mktemp -d)"
sid=""
cid=""

cleanup() {
  if [[ -z "${sid}" && -n "${cid}" ]]; then
    sid="$(curl -sf "${AUTH_ARGS[@]}" "${HUB_ROOT}/status" |
      jq -r --arg cid "${cid}" '
        .browsers.android["16.0"] | to_entries[]?.value.sessions[]?
        | select(.container | startswith($cid)) | .id' |
      awk 'NR==1 {print; exit}')"
  fi
  if [[ -n "${sid}" ]]; then
    curl -sS "${AUTH_ARGS[@]}" -X DELETE "${WEBDRIVER_URL}/session/${sid}" >/dev/null 2>&1 || true
  fi
  rm -rf "${tmp}"
}
trap cleanup EXIT

wait_removed() {
  local old_cid="$1"
  for _ in $(seq 1 60); do
    docker inspect "${old_cid}" >/dev/null 2>&1 || return 0
    sleep 0.25
  done
  echo "ERROR: container ${old_cid} remained after DELETE" >&2
  return 1
}

run_session() {
  local name="$1" payload="$2" started response_ms action_code screenshot_code vnc_code
  sid=""
  cid=""
  if [[ "$(docker ps -q --filter ancestor=qaguru/android:16 | wc -l | tr -d ' ')" != "0" ]]; then
    echo "ERROR: Android container exists before ${name}" >&2
    return 1
  fi

  started="$(date +%s%3N)"
  curl -sS "${AUTH_ARGS[@]}" \
    -X POST "${WEBDRIVER_URL}/session" \
    -H 'Content-Type: application/json' \
    -d "${payload}" \
    -o "${tmp}/${name}.json" \
    -w '%{http_code} %{time_total}\n' >"${tmp}/${name}.meta" &
  local curl_pid=$!

  for _ in $(seq 1 1200); do
    cid="$(docker ps --filter ancestor=qaguru/android:16 --format '{{.ID}}' |
      awk 'NR==1 {print; exit}')"
    [[ -n "${cid}" ]] && break
    kill -0 "${curl_pid}" 2>/dev/null || break
    sleep 0.1
  done
  [[ -n "${cid}" ]] || { wait "${curl_pid}" || true; echo "ERROR: no container for ${name}" >&2; return 1; }
  echo "${name}.container_started_ms=$(( $(date +%s%3N) - started )) cid=${cid}"

  wait "${curl_pid}"
  response_ms="$(( $(date +%s%3N) - started ))"
  sid="$(jq -r '.value.sessionId // .sessionId // empty' "${tmp}/${name}.json")"
  echo "${name}.session_response_ms=${response_ms} curl=$(<"${tmp}/${name}.meta") sid=${sid}"
  if [[ -z "${sid}" ]]; then
    jq -c . "${tmp}/${name}.json"
    return 1
  fi

  action_code="$(curl -sS "${AUTH_ARGS[@]}" -o "${tmp}/${name}-action.json" -w '%{http_code}' \
    -X POST "${WEBDRIVER_URL}/session/${sid}/actions" \
    -H 'Content-Type: application/json' \
    -d '{"actions":[{"type":"pointer","id":"finger","parameters":{"pointerType":"touch"},"actions":[{"type":"pointerMove","duration":0,"x":540,"y":960},{"type":"pointerDown","button":0},{"type":"pause","duration":100},{"type":"pointerUp","button":0}]}]}')"
  screenshot_code="$(curl -sS "${AUTH_ARGS[@]}" -o "${tmp}/${name}-screenshot.json" -w '%{http_code}' \
    "${WEBDRIVER_URL}/session/${sid}/screenshot")"
  vnc_code="$(curl --max-time 2 -sS "${AUTH_ARGS[@]}" -o /dev/null -w '%{http_code}' \
    "${HUB_ROOT}/vnc/${sid}" \
    -H 'Connection: Upgrade' \
    -H 'Upgrade: websocket' \
    -H "Origin: ${HUB_ROOT}" \
    -H 'Sec-WebSocket-Version: 13' \
    -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' 2>/dev/null || true)"
  echo "${name}.manual_touch_http=${action_code} screenshot_http=${screenshot_code} vnc_websocket_http=${vnc_code}"
  docker logs "${cid}" 2>&1 | awk '/TIMELINE/ {print "'"${name}"'." $0}'

  local old_cid="${cid}"
  local delete_code
  delete_code="$(curl -sS "${AUTH_ARGS[@]}" -o /dev/null -w '%{http_code}' \
    -X DELETE "${WEBDRIVER_URL}/session/${sid}")"
  sid=""
  wait_removed "${old_cid}"
  cid=""
  echo "${name}.delete_http=${delete_code} container_removed=true"
  durations+=("${response_ms}")
}

base_payload='{"capabilities":{"alwaysMatch":{"browserName":"android","browserVersion":"16.0","selenoid:options":{"enableVNC":true,"screenResolution":"1080x1920x24"}}}}'
durations=()
for i in $(seq 1 "${COUNT}"); do
  run_session "cold-${i}" "${base_payload}"
done

sorted="$(printf '%s\n' "${durations[@]}" | sort -n)"
median_index=$(( (COUNT + 1) / 2 ))
p95_index=$(( (95 * COUNT + 99) / 100 ))
median="$(awk -v n="${median_index}" 'NR==n {print; exit}' <<<"${sorted}")"
p95="$(awk -v n="${p95_index}" 'NR==n {print; exit}' <<<"${sorted}")"
echo "summary.count=${COUNT} median_ms=${median} p95_ms=${p95} samples_ms=$(printf '%s,' "${durations[@]}" | sed 's/,$//')"

if [[ -n "${APP_URL}" ]]; then
  app_payload="$(jq -cn --arg app "${APP_URL}" '{
    capabilities:{alwaysMatch:{
      browserName:"android",
      browserVersion:"16.0",
      "appium:app":$app,
      "appium:noReset":false,
      "selenoid:options":{enableVNC:true,screenResolution:"1080x1920x24"}
    }}
  }')"
  run_session "app-url-no-reset-false" "${app_payload}"
fi

remaining="$(docker ps -q --filter ancestor=qaguru/android:16 | wc -l | tr -d ' ')"
used="$(curl -sf "${AUTH_ARGS[@]}" "${HUB_ROOT}/status" | jq -r '.used')"
echo "cleanup.remaining_android_containers=${remaining} hub_used=${used}"
[[ "${remaining}" == "0" ]]
