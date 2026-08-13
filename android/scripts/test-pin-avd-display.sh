#!/usr/bin/env bash
# Local pin regression (no Docker). pixel 1080x1920 → OK; lcd 2400 → exit 1, no rewrite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="${ROOT}/scripts/pin-avd-display.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

ok="${tmp}/ok.ini"
cat >"${ok}" <<'EOF'
hw.lcd.width=1080
hw.lcd.height=1920
hw.device.name=pixel
EOF
"${PIN}" "${ok}" 1080x1920
grep -qx 'hw.lcd.width=1080' "${ok}"
grep -qx 'hw.lcd.height=1920' "${ok}"
grep -qx 'skin.name=1080x1920' "${ok}"
grep -qx 'skin.path=1080x1920' "${ok}"
grep -qx 'skin.dynamic=no' "${ok}"
grep -qx 'showDeviceFrame=no' "${ok}"

bad="${tmp}/bad.ini"
cat >"${bad}" <<'EOF'
hw.lcd.width=1080
hw.lcd.height=2400
EOF
if "${PIN}" "${bad}" 1080x1920; then
  echo "ERROR: expected exit 1 on lcd mismatch" >&2
  exit 1
fi
grep -qx 'hw.lcd.height=2400' "${bad}"
! grep -q 'skin.name=1080x1920' "${bad}"

echo "OK pin-avd-display: 1080x1920 upsert skin; 2400 mismatch fails without rewrite"
