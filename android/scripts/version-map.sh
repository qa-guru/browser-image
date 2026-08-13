#!/usr/bin/env bash
# Map qaguru/android Docker tag (8, 10–16) → AVD_NAME PLATFORM BUILD_TOOLS DEVICE IMAGE_TYPE.
# Source from build.sh / prepare-image.sh.
# Floor: UiAutomator2 ≥6.0 / our pin 8.1.0 → Android 8.0 (API 26). Older APIs will not start.
#
# Device is not per-API: always `pixel` (native 1080x1920 @ 420dpi) so guest lcd,
# Qt window and VNC skin stay one rectangle. pixel_4/5/6 only changed lcd height
# and broke API 35+ (missing device frames → 320x240 window).
set -euo pipefail

resolve_android_tag() {
  local tag="${1:?tag required (8|10-16)}"
  case "${tag}" in
    8)  echo "android8 android-26 build-tools;30.0.3 pixel google_apis" ;;
    10) echo "android10 android-29 build-tools;30.0.3 pixel google_apis" ;;
    11) echo "android11 android-30 build-tools;30.0.3 pixel google_atd" ;;
    12) echo "android12 android-31 build-tools;31.0.0 pixel google_apis" ;;
    13) echo "android13 android-33 build-tools;33.0.0 pixel google_apis" ;;
    14) echo "android14 android-34 build-tools;34.0.0 pixel google_apis" ;;
    15) echo "android15 android-35 build-tools;35.0.0 pixel google_apis" ;;
    16) echo "android16 android-36 build-tools;35.0.0 pixel google_apis" ;;
    *)
      echo "ERROR: unsupported qaguru/android tag '${tag}' (expected 8 or 10–16; UiAutomator2 floor=API 26)" >&2
      return 1
      ;;
  esac
}
