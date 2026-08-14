#!/usr/bin/env bash
# Geometry checklist for qaguru/android:${TAG}-preprod on Linux+KVM.
# TAG=16 ./scripts/verify-preprod.sh
set -euo pipefail

TAG="${TAG:?TAG required (8|10-16)}"
IMAGE="${IMAGE:-qaguru/android:${TAG}-preprod}"
AVD="android${TAG}"
NAME="a${TAG}-preprod-go"
BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC:-300}"
fail=0
sid=""

cleanup() {
  if [[ -n "${sid}" ]]; then
    curl -sS -m 10 -o /dev/null -X DELETE "http://127.0.0.1:14444/wd/hub/session/${sid}" >/dev/null 2>&1 || true
  fi
  docker rm -f "${NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "verify.image=${IMAGE} avd=${AVD}"

ini="$(docker run --rm --entrypoint cat "${IMAGE}" "/root/.android/avd/${AVD}.avd/config.ini")"
canon() {
  local key="$1" expect="$2"
  local got
  got="$(printf '%s\n' "${ini}" | grep -E "^${key}=" | tail -n1 | cut -d= -f2- | tr -d ' \r')"
  if [[ "${got}" == "${expect}" ]]; then
    echo "ini.${key}=${got} OK"
  else
    echo "ini.${key}=${got} WANT ${expect} FAIL"
    fail=1
  fi
}
canon hw.lcd.width 1080
canon hw.lcd.height 1920
canon skin.name 1080x1920
canon skin.path 1080x1920
canon skin.dynamic no
canon showDeviceFrame no
device="$(printf '%s\n' "${ini}" | grep -E '^hw.device.name=' | tail -n1 | cut -d= -f2- | tr -d ' \r')"
echo "ini.hw.device.name=${device}"
if printf '%s\n' "${ini}" | grep -Eq '2400|QVGA|240x320|320x240'; then
  echo "ini.forbidden_geometry=FAIL"
  fail=1
fi

docker rm -f "${NAME}" >/dev/null 2>&1 || true
docker run -d --name "${NAME}" \
  --device /dev/kvm \
  --security-opt seccomp=unconfined \
  --shm-size 2g --memory 6g --cpus 4 \
  -e ENABLE_VNC=true \
  -e SCREEN_RESOLUTION=2100x2100x24 \
  -e BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC}" \
  -p 127.0.0.1:14444:4444 \
  -p 127.0.0.1:15900:5900 \
  "${IMAGE}" >/dev/null

ready=0
for _ in $(seq 1 "${BOOT_TIMEOUT_SEC}"); do
  if docker logs "${NAME}" 2>&1 | grep -q 'TIMELINE event=appium_status'; then
    ready=1
    break
  fi
  if ! docker ps -q --filter "name=^${NAME}$" | grep -q .; then
    echo "ERROR: container exited"
    docker logs "${NAME}" 2>&1 | tail -30
    exit 1
  fi
  sleep 1
done
if [[ "${ready}" != "1" ]]; then
  echo "ERROR: no appium_status within ${BOOT_TIMEOUT_SEC}s"
  docker logs "${NAME}" 2>&1 | grep TIMELINE || true
  exit 1
fi
docker logs "${NAME}" 2>&1 | grep TIMELINE

wm="$(docker exec "${NAME}" adb -s emulator-5554 shell wm size | tr -d '\r')"
dens="$(docker exec "${NAME}" adb -s emulator-5554 shell wm density | tr -d '\r')"
echo "wm.size=${wm}"
echo "wm.density=${dens}"
[[ "${wm}" == *"1080x1920"* ]] || { echo "wm.size FAIL"; fail=1; }

png="/tmp/${TAG}-screencap.png"
docker exec "${NAME}" adb -s emulator-5554 exec-out screencap -p >"${png}"
if ! python3 - "${png}" <<'PY'
import struct, sys
p = open(sys.argv[1], "rb").read()
w, h = struct.unpack(">II", p[16:24])
print(f"screencap_png={w}x{h} bytes={len(p)}")
raise SystemExit(0 if (w, h) == (1080, 1920) else 1)
PY
then
  echo "screencap FAIL"
  fail=1
fi

echo "===wmctrl==="
docker exec "${NAME}" bash -c 'DISPLAY=:99 wmctrl -lG' || true
win="$(docker exec "${NAME}" bash -c 'DISPLAY=:99 wmctrl -lG' | awk 'BEGIN{IGNORECASE=1} /Android Emulator -/ {print $5"x"$6; exit}')"
echo "vnc.emulator_window=${win}"
if [[ "${win}" != "1080x1920" ]]; then
  echo "vnc.emulator_window FAIL"
  fail=1
fi
if docker exec "${NAME}" adb -s emulator-5554 shell dumpsys display | grep -Eq '320x240|QVGA|2400'; then
  echo "dumpsys.forbidden_geometry=FAIL"
  fail=1
else
  echo "dumpsys.1080x1920 OK"
fi

resp="$(curl -sS -m 120 -X POST http://127.0.0.1:14444/wd/hub/session \
  -H 'Content-Type: application/json' \
  -d '{"capabilities":{"alwaysMatch":{"platformName":"Android","appium:automationName":"UiAutomator2"}}}' \
  -w '\nhttp=%{http_code}')"
http="$(printf '%s\n' "${resp}" | awk -F= '/^http=/{print $2}')"
body="$(printf '%s\n' "${resp}" | sed '/^http=/d')"
sid="$(printf '%s' "${body}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print((d.get("value") or {}).get("sessionId") or d.get("sessionId") or "")')"
echo "appium.session_http=${http} sid=${sid}"
[[ "${http}" == "200" && -n "${sid}" ]] || { echo "appium.session FAIL"; fail=1; }

if [[ -n "${sid}" ]]; then
  touch_http="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' \
    -X POST "http://127.0.0.1:14444/wd/hub/session/${sid}/actions" \
    -H 'Content-Type: application/json' \
    -d '{"actions":[{"type":"pointer","id":"finger","parameters":{"pointerType":"touch"},"actions":[{"type":"pointerMove","duration":0,"x":540,"y":960},{"type":"pointerDown","button":0},{"type":"pause","duration":100},{"type":"pointerUp","button":0}]}]}')"
  shot_http="$(curl -sS -m 20 -o "/tmp/${TAG}-appium.json" -w '%{http_code}' \
    "http://127.0.0.1:14444/wd/hub/session/${sid}/screenshot")"
  echo "appium.touch_http=${touch_http} screenshot_http=${shot_http}"
  if ! python3 - "${TAG}" <<'PY'
import json, base64, struct, sys
tag = sys.argv[1]
j = json.load(open(f"/tmp/{tag}-appium.json"))
raw = base64.b64decode(j.get("value") or "")
w, h = struct.unpack(">II", raw[16:24])
print(f"appium_png={w}x{h} bytes={len(raw)}")
raise SystemExit(0 if (w, h) == (1080, 1920) else 1)
PY
  then
    fail=1
  fi
  del_http="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' -X DELETE "http://127.0.0.1:14444/wd/hub/session/${sid}")"
  echo "appium.delete_http=${del_http}"
  sid=""
  [[ "${touch_http}" == "200" && "${shot_http}" == "200" && "${del_http}" == "200" ]] || fail=1
fi

cleanup
trap - EXIT
left="$(docker ps -q --filter ancestor="${IMAGE}" | wc -l | tr -d ' ')"
echo "cleanup.remaining=${left}"
[[ "${left}" == "0" ]] || fail=1

if [[ "${fail}" == "0" ]]; then
  echo "GO tag=${TAG} image=${IMAGE}"
  exit 0
fi
echo "NO-GO tag=${TAG} image=${IMAGE}"
exit 1
