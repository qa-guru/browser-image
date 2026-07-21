#!/usr/bin/env bash
# Run inside android-base on Linux+KVM. Produces reproducible userdata with the
# exact Appium Settings and UiAutomator2 server APKs installed.
set -euo pipefail

AVD_NAME="${AVD_NAME:-android16}"
EMULATOR="${EMULATOR:-emulator-5554}"
OUTPUT_DIR="${OUTPUT_DIR:-/prepared}"
BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC:-300}"
SERVER_DIR="/root/.appium/node_modules/appium-uiautomator2-driver/node_modules/appium-uiautomator2-server/apks"
SETTINGS_APK="/root/.appium/node_modules/appium-uiautomator2-driver/node_modules/io.appium.settings/apks/settings_apk-debug.apk"
SERVER_APK="${SERVER_DIR}/appium-uiautomator2-server-v10.3.2.apk"
SERVER_TEST_APK="${SERVER_DIR}/appium-uiautomator2-server-debug-androidTest.apk"

if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: prepared userdata requires Linux + /dev/kvm" >&2
  exit 1
fi
for apk in "${SETTINGS_APK}" "${SERVER_APK}" "${SERVER_TEST_APK}"; do
  [[ -s "${apk}" ]] || { echo "ERROR: missing helper APK: ${apk}" >&2; exit 1; }
done

clean() {
  adb -s "${EMULATOR}" emu kill >/dev/null 2>&1 || true
  [[ -n "${EMULATOR_PID:-}" ]] && wait "${EMULATOR_PID}" 2>/dev/null || true
}
trap clean EXIT

ANDROID_AVD_HOME=/root/.android/avd \
  "${ANDROID_HOME}/emulator/emulator" \
  -avd "${AVD_NAME}" \
  -memory 6144 \
  -cores 4 \
  -sdcard /sdcard.img \
  -skin 1080x1920 \
  -gpu swiftshader_indirect \
  -no-window \
  -no-snapshot \
  -no-boot-anim \
  -no-audio \
  -no-jni \
  -no-metrics \
  -accel on &
EMULATOR_PID=$!

timeout "${BOOT_TIMEOUT_SEC}" adb -s "${EMULATOR}" wait-for-device
boot_elapsed=0
until [[ "$(adb -s "${EMULATOR}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
  if [[ "${boot_elapsed}" -ge "${BOOT_TIMEOUT_SEC}" ]]; then
    echo "ERROR: prepare emulator did not boot within ${BOOT_TIMEOUT_SEC}s" >&2
    exit 1
  fi
  sleep 2
  boot_elapsed=$((boot_elapsed + 2))
done
echo "Prepare boot_completed after ${boot_elapsed}s"

# One shell transport instead of a sequence of independent adb round trips.
adb -s "${EMULATOR}" shell '
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
'

timeout 180 adb -s "${EMULATOR}" install -r -g "${SETTINGS_APK}"
timeout 180 adb -s "${EMULATOR}" install -r -g "${SERVER_APK}"
timeout 180 adb -s "${EMULATOR}" install -r -t -g "${SERVER_TEST_APK}"

for package in \
  io.appium.settings \
  io.appium.uiautomator2.server \
  io.appium.uiautomator2.server.test
do
  adb -s "${EMULATOR}" shell pm path "${package}" >/dev/null
done

# Prime ART/dex compilation and the test runner once in the baked userdata.
# Merely installing the APKs leaves a 20–30s first-instrumentation penalty.
adb -s "${EMULATOR}" forward tcp:4725 tcp:6790
adb -s "${EMULATOR}" shell am instrument -w -e disableAnalytics true \
  io.appium.uiautomator2.server.test/androidx.test.runner.AndroidJUnitRunner \
  >/tmp/uiautomator2-prime.log 2>&1 &
UIAUTOMATOR2_PID=$!
uia_ready=false
for _ in $(seq 1 120); do
  if curl -sf http://127.0.0.1:4725/status >/dev/null 2>&1; then
    uia_ready=true
    break
  fi
  sleep 0.5
done
if [[ "${uia_ready}" != "true" ]]; then
  echo "ERROR: baked UiAutomator2 server did not become ready" >&2
  awk '{print}' /tmp/uiautomator2-prime.log >&2
  exit 1
fi
adb -s "${EMULATOR}" shell am force-stop io.appium.uiautomator2.server
adb -s "${EMULATOR}" shell am force-stop io.appium.uiautomator2.server.test
wait "${UIAUTOMATOR2_PID}" || true
adb -s "${EMULATOR}" forward --remove tcp:4725
echo "Prepared UiAutomator2 instrumentation cache"

adb -s "${EMULATOR}" shell sync
adb -s "${EMULATOR}" emu kill >/dev/null
wait "${EMULATOR_PID}" || true
EMULATOR_PID=""
trap - EXIT

avd_dir="/root/.android/avd/${AVD_NAME}.avd"
userdata="${avd_dir}/userdata-qemu.img"
[[ -s "${userdata}" ]] || { echo "ERROR: emulator did not create ${userdata}" >&2; exit 1; }

# Guest RAM/CPU for System UI headroom (matches browsers.json mem/cpu).
conf="${avd_dir}/config.ini"
if grep -qE '^hw\.ramSize' "${conf}"; then sed -i -E 's/^hw\.ramSize.*/hw.ramSize=6144M/' "${conf}"; else echo 'hw.ramSize=6144M' >> "${conf}"; fi
if grep -qE '^vm\.heapSize' "${conf}"; then sed -i -E 's/^vm\.heapSize.*/vm.heapSize=512M/' "${conf}"; else echo 'vm.heapSize=512M' >> "${conf}"; fi
if grep -qE '^hw\.cpu\.ncore' "${conf}"; then sed -i -E 's/^hw\.cpu\.ncore.*/hw.cpu.ncore=4/' "${conf}"; else echo 'hw.cpu.ncore=4' >> "${conf}"; fi

rm -rf "${OUTPUT_DIR:?}/${AVD_NAME}.avd"
mkdir -p "${OUTPUT_DIR}/${AVD_NAME}.avd"
rm -f "${avd_dir}"/*.lock "${avd_dir}"/cache.img* "${avd_dir}"/hardware-qemu.ini
cp --sparse=always -a "${avd_dir}/." "${OUTPUT_DIR}/${AVD_NAME}.avd/"
cp "/root/.android/avd/${AVD_NAME}.ini" "${OUTPUT_DIR}/${AVD_NAME}.ini"

settings_sha="$(sha256sum "${SETTINGS_APK}" | awk '{print $1}')"
server_sha="$(sha256sum "${SERVER_APK}" | awk '{print $1}')"
server_test_sha="$(sha256sum "${SERVER_TEST_APK}" | awk '{print $1}')"
cat >"${OUTPUT_DIR}/manifest.env" <<EOF
PREPARED_AVD=true
AVD_NAME=${AVD_NAME}
PLATFORM=${PLATFORM}
ANDROID_ABI=${ANDROID_ABI}
APPIUM_VERSION=3.5.2
UIAUTOMATOR2_VERSION=8.1.0
UIAUTOMATOR2_SERVER_VERSION=10.3.2
SETTINGS_APK_SHA256=${settings_sha}
SERVER_APK_SHA256=${server_sha}
SERVER_TEST_APK_SHA256=${server_test_sha}
SNAPSHOT_POLICY=no-snapshot
EOF

if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
  chown -R "${HOST_UID}:${HOST_GID}" "${OUTPUT_DIR}"
fi
echo "Prepared ${userdata} and Appium helper APKs in ${OUTPUT_DIR}"
