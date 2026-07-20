#!/usr/bin/env bash
# Selenoid Android node: Xvfb + emulator (KVM) + Appium UiAutomator2 + optional VNC.
# ENABLE_VNC / ENABLE_VIDEO come from Selenoid caps (enableVNC / enableVideo).
# Runtime requires Linux + /dev/kvm. Mac session support is deferred.
set -euo pipefail

BOOTSTRAP_PORT="${BOOTSTRAP_PORT:-4725}"
EMULATOR="${EMULATOR:-emulator-5554}"
APPIUM_ARGS="${APPIUM_ARGS:-}"
EMULATOR_ARGS="${EMULATOR_ARGS:-}"
PORT="${PORT:-4444}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY=":${DISPLAY_NUM}"
# Portrait canvas matching phone skin (not landscape browser desktop).
SCREEN_RESOLUTION="${SCREEN_RESOLUTION:-1080x1920x24}"
SKIN="${SKIN:-1080x1920}"
VERBOSE="${VERBOSE:-}"
AVD_NAME="${AVD_NAME:-android16}"
BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC:-180}"
STOP=""

normalize_bool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

ENABLE_VNC="$(normalize_bool "${ENABLE_VNC:-false}")"
ENABLE_VIDEO="$(normalize_bool "${ENABLE_VIDEO:-false}")"

if [[ -z "${VERBOSE}" ]]; then
  if [[ -z "${APPIUM_ARGS}" ]]; then
    APPIUM_ARGS="--log-level error"
  fi
else
  EMULATOR_ARGS="${EMULATOR_ARGS} -verbose"
fi

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm is missing. Android sessions need Linux + KVM." >&2
  echo "Mac: image builds (linux/amd64), runtime deferred — no KVM in Docker Desktop." >&2
  exit 1
fi

clean() {
  STOP="yes"
  [[ -n "${APPIUM_PID:-}" ]] && kill -TERM "${APPIUM_PID}" 2>/dev/null || true
  [[ -n "${EMULATOR_PID:-}" ]] && kill -TERM "${EMULATOR_PID}" 2>/dev/null || true
  [[ -n "${X11VNC_PID:-}" ]] && kill -TERM "${X11VNC_PID}" 2>/dev/null || true
  [[ -n "${XVFB_PID:-}" ]] && kill -TERM "${XVFB_PID}" 2>/dev/null || true
}

trap clean SIGINT SIGTERM

/usr/bin/xvfb-run -e /dev/stdout -l -n "${DISPLAY_NUM}" \
  -s "-ac -screen 0 ${SCREEN_RESOLUTION} -noreset -listen tcp" \
  /usr/bin/fluxbox -display "${DISPLAY}" -log /tmp/fluxbox.log 2>/dev/null &
XVFB_PID=$!

retcode=1
until [[ "${retcode}" -eq 0 || -n "${STOP}" ]]; do
  if DISPLAY="${DISPLAY}" wmctrl -m >/dev/null 2>&1; then
    retcode=0
  else
    echo "Waiting for X server..."
    sleep 0.1
    retcode=1
  fi
done
[[ -n "${STOP}" ]] && exit 0

if [[ "${ENABLE_VNC}" != "true" && "${ENABLE_VIDEO}" != "true" ]]; then
  EMULATOR_ARGS="${EMULATOR_ARGS} -no-window"
fi

# shellcheck disable=SC2086
ANDROID_AVD_HOME=/root/.android/avd DISPLAY="${DISPLAY}" \
  "${ANDROID_HOME}/emulator/emulator" ${EMULATOR_ARGS} \
  -avd "${AVD_NAME}" \
  -sdcard /sdcard.img \
  -skin "${SKIN}" \
  -gpu swiftshader_indirect \
  -no-boot-anim \
  -no-audio \
  -no-jni \
  -accel on \
  -writable-system \
  &
EMULATOR_PID=$!

if [[ "${ENABLE_VNC}" == "true" ]]; then
  x11vnc -display "${DISPLAY}" -passwd selenoid -shared -forever -loop500 \
    -rfbport 5900 -rfbportv6 5900 -logfile /tmp/x11vnc.log &
  X11VNC_PID=$!
fi

boot_elapsed=0
while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" && -z "${STOP}" ]]; do
  if [[ "${boot_elapsed}" -ge "${BOOT_TIMEOUT_SEC}" ]]; then
    echo "ERROR: emulator did not reach boot_completed within ${BOOT_TIMEOUT_SEC}s" >&2
    exit 1
  fi
  sleep 2
  boot_elapsed=$((boot_elapsed + 2))
  if (( boot_elapsed % 30 == 0 )); then
    echo "Still waiting for emulator boot… ${boot_elapsed}s / ${BOOT_TIMEOUT_SEC}s"
  fi
done
[[ -n "${STOP}" ]] && exit 0

echo "Emulator boot_completed after ${boot_elapsed}s"

DEFAULT_CAPABILITIES='"appium:androidNaturalOrientation": true, "appium:deviceName": "Android Emulator", "platformName": "Android", "appium:automationName": "UiAutomator2", "appium:noReset": true, "appium:udid": "'"${EMULATOR}"'", "appium:systemPort": '"${BOOTSTRAP_PORT}"', "appium:newCommandTimeout": 90'

# shellcheck disable=SC2086
/opt/node_modules/.bin/appium \
  -a 0.0.0.0 \
  -p "${PORT}" \
  --base-path /wd/hub \
  --log-timestamp \
  --log-no-colors \
  ${APPIUM_ARGS} \
  --default-capabilities "{${DEFAULT_CAPABILITIES}}" &
APPIUM_PID=$!

wait
