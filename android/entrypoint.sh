#!/usr/bin/env bash
# Selenoid Android node: Xvfb + emulator (KVM) + Appium UiAutomator2 + optional VNC.
# ENABLE_VNC / ENABLE_VIDEO come from Selenoid caps (enableVNC / enableVideo).
# Runtime requires Linux + /dev/kvm. Mac session support is deferred.
#
# No runtime adb install of Appium helpers — Appium installs them on New Session.
# Hub must use a generous -session-attempt-timeout (default 30s is too short).
set -euo pipefail

BOOTSTRAP_PORT="${BOOTSTRAP_PORT:-4725}"
EMULATOR="${EMULATOR:-emulator-5554}"
APPIUM_ARGS="${APPIUM_ARGS:-}"
EMULATOR_ARGS="${EMULATOR_ARGS:-}"
PORT="${PORT:-4444}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY=":${DISPLAY_NUM}"
# Square VNC canvas: skin 1080x1920 + Qt title/toolbar chrome in portrait AND landscape.
# 2100² = max(skin)+chrome margin (~title 48 + side toolbar 72 + pad); wallpaper matches.
SCREEN_RESOLUTION="${SCREEN_RESOLUTION:-2100x2100x24}"
SKIN="${SKIN:-1080x1920}"
VERBOSE="${VERBOSE:-}"
AVD_NAME="${AVD_NAME:-android16}"
BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC:-240}"
STOP=""
START_EPOCH_MS="$(date +%s%3N)"
FIT_EMULATOR_PID=""

timeline() {
  local now
  now="$(date +%s%3N)"
  echo "TIMELINE event=$1 elapsed_ms=$((now - START_EPOCH_MS))"
}

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
  [[ -n "${FIT_EMULATOR_PID:-}" ]] && kill -TERM "${FIT_EMULATOR_PID}" 2>/dev/null || true
  [[ -n "${APPIUM_PID:-}" ]] && kill -TERM "${APPIUM_PID}" 2>/dev/null || true
  [[ -n "${EMULATOR_PID:-}" ]] && kill -TERM "${EMULATOR_PID}" 2>/dev/null || true
  [[ -n "${X11VNC_PID:-}" ]] && kill -TERM "${X11VNC_PID}" 2>/dev/null || true
  [[ -n "${XVFB_PID:-}" ]] && kill -TERM "${XVFB_PID}" 2>/dev/null || true
}

# Keep the Qt phone window on top through portrait ↔ landscape resizes.
# Prefer "Android Emulator - …" — bare title "Emulator" is a separate empty shell.
# Size stays 1:1 skin (-fixed-scale); pin bottom-left so rotate does not jump to top-left.
#
# CRITICAL: never pass wmctrl size as -1,-1. Each such call grows the Qt window by
# ~25px and shifts it up — VNC looks like the image jerking upward. Pass explicit w,h.
# Re-pin only when size changes (orientation); do not -e/-a every tick.
fit_emulator_window_loop() {
  local win="" win_w="" win_h="" screen_h="" target_y="" pinned_w="" pinned_h=""
  screen_h="$(printf '%s' "${SCREEN_RESOLUTION}" | cut -dx -f2)"
  while [[ -z "${STOP}" ]]; do
    win="$(DISPLAY="${DISPLAY}" wmctrl -l 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /Android Emulator -/ {print $1; exit}')"
    if [[ -z "${win}" ]]; then
      win="$(DISPLAY="${DISPLAY}" wmctrl -l 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /Android Emulator/ {print $1; exit}')"
    fi
    if [[ -n "${win}" ]]; then
      # wmctrl -lG: id desk x y w h host title…
      win_w="$(DISPLAY="${DISPLAY}" wmctrl -lG 2>/dev/null | awk -v id="${win}" '$1==id {print $5; exit}')"
      win_h="$(DISPLAY="${DISPLAY}" wmctrl -lG 2>/dev/null | awk -v id="${win}" '$1==id {print $6; exit}')"
      if [[ -n "${win_w}" && -n "${win_h}" && -n "${screen_h}" ]]; then
        if [[ "${win_w}" != "${pinned_w}" || "${win_h}" != "${pinned_h}" ]]; then
          if [[ "${screen_h}" -gt "${win_h}" ]]; then
            target_y=$((screen_h - win_h))
          else
            target_y=0
          fi
          DISPLAY="${DISPLAY}" wmctrl -i -r "${win}" -e "0,0,${target_y},${win_w},${win_h}" 2>/dev/null || true
          DISPLAY="${DISPLAY}" wmctrl -i -r "${win}" -b add,above 2>/dev/null || true
          pinned_w="${win_w}"
          pinned_h="${win_h}"
        fi
      fi
    else
      pinned_w=""
      pinned_h=""
    fi
    sleep 1
  done
}

trap clean SIGINT SIGTERM

adb_ok() {
  timeout "${1:-15}" adb "${@:2}" >/dev/null 2>&1 || return 1
}

quick_unlock() {
  if [[ -s /opt/qaguru/prepared-avd.env ]]; then
    if ! adb_ok 20 shell '
      input keyevent KEYCODE_WAKEUP
      wm dismiss-keyguard || true
      input keyevent 82
    '; then
      echo "ERROR: failed to wake and unlock prepared AVD" >&2
      return 1
    fi
    timeline unlocked
    return 0
  fi

  if ! adb_ok 20 shell '
    input keyevent KEYCODE_WAKEUP
    wm dismiss-keyguard || true
    input keyevent 82
    settings put global package_verifier_enable 0
    settings put global verifier_verify_adb_installs 0
    settings put secure user_setup_complete 1
    settings put global device_provisioned 1
    settings put system screen_off_timeout 2147483647
    settings put global animator_duration_scale 0
    settings put global transition_animation_scale 0
    settings put global window_animation_scale 0
    settings put global hidden_api_policy 1
  '; then
    echo "ERROR: failed to provision and unlock booted emulator" >&2
    return 1
  fi
  timeline unlocked_and_provisioned
}

start_appium() {
  # Install timeouts leave room for first-session helper APK install under API 36.
  DEFAULT_CAPABILITIES='"appium:androidNaturalOrientation": true, "appium:deviceName": "Android Emulator", "platformName": "Android", "appium:automationName": "UiAutomator2", "appium:noReset": true, "appium:udid": "'"${EMULATOR}"'", "appium:systemPort": '"${BOOTSTRAP_PORT}"', "appium:newCommandTimeout": 180, "appium:adbExecTimeout": 180000, "appium:uiautomator2ServerInstallTimeout": 180000, "appium:uiautomator2ServerLaunchTimeout": 180000, "appium:ignoreHiddenApiPolicyError": true, "appium:skipLogcatCapture": true, "appium:skipUnlock": true, "appium:autoGrantPermissions": true'
  if [[ -s /opt/qaguru/prepared-avd.env ]]; then
    DEFAULT_CAPABILITIES="${DEFAULT_CAPABILITIES}"', "appium:skipDeviceInitialization": true, "appium:skipServerInstallation": true'
  fi

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
  echo "Appium starting pid=${APPIUM_PID}"
  timeline appium_process

  # Wait until Appium HTTP is up (hub service-startup-timeout).
  local i=0
  while [[ "${i}" -lt 60 && -z "${STOP}" ]]; do
    if curl -sf "http://127.0.0.1:${PORT}/wd/hub/status" >/dev/null 2>&1; then
      echo "Appium /wd/hub/status OK after ${i}s"
      timeline appium_status
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  echo "WARN: Appium status not ready within 60s — hub may still connect" >&2
}

monitor_uiautomator2() {
  while [[ -z "${STOP}" ]]; do
    if adb shell pidof io.appium.uiautomator2.server >/dev/null 2>&1; then
      timeline uiautomator2_process
      return 0
    fi
    sleep 0.25
  done
}

wait_for_boot_and_unlock() {
  local boot_elapsed=0
  while [[ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" && -z "${STOP}" ]]; do
    if [[ "${boot_elapsed}" -ge "${BOOT_TIMEOUT_SEC}" ]]; then
      echo "ERROR: emulator did not reach boot_completed within ${BOOT_TIMEOUT_SEC}s" >&2
      return 1
    fi
    sleep 2
    boot_elapsed=$((boot_elapsed + 2))
    if (( boot_elapsed % 30 == 0 )); then
      echo "Still waiting for emulator boot… ${boot_elapsed}s / ${BOOT_TIMEOUT_SEC}s"
    fi
  done
  [[ -n "${STOP}" ]] && return 0
  echo "Emulator boot_completed after ${boot_elapsed}s"
  timeline boot_completed
  quick_unlock
}

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

# Render wallpaper reliably (fluxbox style `background` is flaky under Xvfb).
# --bg-center keeps the 2100² wallpaper at native size — no stretch, logo undistorted.
DISPLAY="${DISPLAY}" feh --no-fehbg --bg-center /usr/share/images/fluxbox/aerokube.png 2>/dev/null || true

if [[ "${ENABLE_VNC}" != "true" && "${ENABLE_VIDEO}" != "true" ]]; then
  EMULATOR_ARGS="${EMULATOR_ARGS} -no-window"
fi

# shellcheck disable=SC2086
# Force guest RAM explicitly: emulator otherwise clamps hw.ramSize using host
# /proc/meminfo heuristics (cgroup limits are invisible → ~2560M).
ANDROID_AVD_HOME=/root/.android/avd DISPLAY="${DISPLAY}" \
  "${ANDROID_HOME}/emulator/emulator" ${EMULATOR_ARGS} \
  -avd "${AVD_NAME}" \
  -memory 6144 \
  -cores 4 \
  -sdcard /sdcard.img \
  -skin "${SKIN}" \
  -fixed-scale \
  -gpu swiftshader_indirect \
  -no-snapshot \
  -no-boot-anim \
  -no-audio \
  -no-jni \
  -no-metrics \
  -accel on \
  &
EMULATOR_PID=$!
timeline emulator_process

if [[ "${ENABLE_VNC}" == "true" ]]; then
  x11vnc -display "${DISPLAY}" -passwd selenoid -shared -forever -loop500 \
    -rfbport 5900 -rfbportv6 5900 -logfile /tmp/x11vnc.log &
  X11VNC_PID=$!
fi

if [[ "${ENABLE_VNC}" == "true" || "${ENABLE_VIDEO}" == "true" ]]; then
  fit_emulator_window_loop &
  FIT_EMULATOR_PID=$!
fi

adb_elapsed=0
until [[ "$(adb get-state 2>/dev/null || true)" == "device" ]]; do
  [[ -n "${STOP}" ]] && exit 0
  if [[ "${adb_elapsed}" -ge "${BOOT_TIMEOUT_SEC}" ]]; then
    echo "ERROR: emulator did not become an adb device within ${BOOT_TIMEOUT_SEC}s" >&2
    exit 1
  fi
  sleep 1
  adb_elapsed=$((adb_elapsed + 1))
done
[[ -n "${STOP}" ]] && exit 0
timeline adb_device

# A measured early-start experiment exposed Appium after package-manager
# readiness (~21s) but before sys.boot_completed (~39s). UiAutomator2 then hung
# until its 180s launch timeout. Keep boot completion as the service gate.
wait_for_boot_and_unlock
start_appium
monitor_uiautomator2 &
UIAUTOMATOR2_MONITOR_PID=$!

wait
