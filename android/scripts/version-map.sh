#!/usr/bin/env bash
# Map qaguru/android Docker tag (11–16) → AVD_NAME PLATFORM BUILD_TOOLS (one line).
# Source from build.sh / prepare-image.sh.
set -euo pipefail

resolve_android_tag() {
  local tag="${1:?tag required (11-16)}"
  case "${tag}" in
    11) echo "android11 android-30 build-tools;30.0.3 pixel_4 google_atd" ;;
    12) echo "android12 android-31 build-tools;31.0.0 pixel_5 google_apis" ;;
    13) echo "android13 android-33 build-tools;33.0.0 pixel_6 google_apis" ;;
    14) echo "android14 android-34 build-tools;34.0.0 pixel_6 google_apis" ;;
    15) echo "android15 android-35 build-tools;35.0.0 pixel_6 google_apis" ;;
    16) echo "android16 android-36 build-tools;35.0.0 pixel_6 google_apis" ;;
    *)
      echo "ERROR: unsupported qaguru/android tag '${tag}' (expected 11–16)" >&2
      return 1
      ;;
  esac
}
