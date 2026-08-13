#!/usr/bin/env bash
# Frameless rectangular skin. Device `pixel` already has hw.lcd=1080x1920;
# this script does not rewrite lcd.
#
# Cmdline `emulator` has no Pixel device frames. If skin.path still points at
# a missing pixel/pixel_6 directory, API 35+ opens a 320x240 Qt window.
# skin.name=skin.path=WxH is the emulator's built-in rectangular skin.
set -euo pipefail

conf="${1:?config.ini path}"
skin="${2:-1080x1920}"
w="${skin%x*}"
h="${skin#*x}"

if [[ ! -f "${conf}" ]]; then
  echo "ERROR: missing ${conf}" >&2
  exit 1
fi
if [[ ! "${w}" =~ ^[0-9]+$ || ! "${h}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: skin must be WxH (got '${skin}')" >&2
  exit 1
fi

ini_val() {
  grep -E "^${1}=" "${conf}" | tail -n1 | cut -d= -f2- | tr -d '\r'
}

lcd_w="$(ini_val hw.lcd.width || true)"
lcd_h="$(ini_val hw.lcd.height || true)"
if [[ -n "${lcd_w}" && -n "${lcd_h}" && ( "${lcd_w}" != "${w}" || "${lcd_h}" != "${h}" ) ]]; then
  echo "ERROR: hw.lcd is ${lcd_w}x${lcd_h}, expected ${skin} (use --device pixel)" >&2
  exit 1
fi

upsert() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" "${conf}"; then
    # -i.bak is GNU+BSD; Linux image and Mac pin-regression both work.
    sed -i.bak -E "s|^${key}=.*|${key}=${val}|" "${conf}"
    rm -f "${conf}.bak"
  else
    printf '%s=%s\n' "${key}" "${val}" >> "${conf}"
  fi
}

if [[ -z "${lcd_w}" ]]; then
  upsert hw.lcd.width "${w}"
fi
if [[ -z "${lcd_h}" ]]; then
  upsert hw.lcd.height "${h}"
fi
upsert skin.name "${skin}"
upsert skin.path "${skin}"
upsert skin.dynamic no
upsert showDeviceFrame no
