#!/usr/bin/env bash
# Pin AVD to a rectangular WxH skin (default 1080x1920).
#
# avdmanager --device pixel_6 writes hw.lcd=1080x2400 and skin.path=pixel_6.
# The cmdline `emulator` package has no Pixel device frames, so API 35+ keeps
# the guest framebuffer at 1080x2400 but opens a 320x240 Qt window. With
# -fixed-scale that is a 1:1 crop (status bar fragment), not a scaled phone.
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

upsert() {
  local key="$1" val="$2"
  if grep -qE "^${key}=" "${conf}"; then
    sed -i -E "s|^${key}=.*|${key}=${val}|" "${conf}"
  else
    printf '%s=%s\n' "${key}" "${val}" >> "${conf}"
  fi
}

upsert skin.name "${skin}"
upsert skin.path "${skin}"
upsert skin.dynamic no
upsert hw.lcd.width "${w}"
upsert hw.lcd.height "${h}"
upsert showDeviceFrame no
