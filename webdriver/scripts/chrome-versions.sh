#!/usr/bin/env bash
set -euo pipefail

# Canonical Chrome for Testing versions for webdriver-chrome (warm + min).
# SSOT: pins.json (watch.yml). Legacy majors below stay for local CLI builds.

_WEBDRIVER_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_WEBDRIVER_SCRIPTS}/../.." && pwd)"
_PINS="${_REPO_ROOT}/pins.json"
_PIN_GET="${_REPO_ROOT}/scripts/pin_get.py"

_pin() {
  python3 "${_PIN_GET}" "${_PINS}" "$1"
}

CHROME_MAJORS=("$(_pin chrome.default_major)" "$(_pin chrome.regression_major)")

chrome_cft_version_for_major() {
  local pinned
  if pinned="$(_pin "chrome.versions.$1" 2>/dev/null)"; then
    printf '%s' "${pinned}"
    return 0
  fi
  case "$1" in
    149) printf '%s' "149.0.7827.55" ;;
    148) printf '%s' "148.0.7778.96" ;;
    *)
      echo "Unknown chrome major: ${1}" >&2
      return 1
      ;;
  esac
}

# Legacy Playwright aliases kept for backward-compatible CLI input.
normalize_chrome_version() {
  local version="${1#v}"
  version="${version%-min}"

  case "${version}" in
    1.62.1|1.62.0) printf '%s' "151" ;;
    1.61.1) printf '%s' "149" ;;
    1.60.0) printf '%s' "148" ;;
    *.*.*.*)
      printf '%s' "${version%%.*}"
      ;;
    *.*)
      printf '%s' "${version%%.*}"
      ;;
    *)
      printf '%s' "${version}"
      ;;
  esac
}

resolve_chrome_cft_version() {
  local version="${1#v}"
  version="${version%-min}"

  case "${version}" in
    *.*.*.*) printf '%s' "${version}" ;;
    *)
      local major
      major="$(normalize_chrome_version "${version}")"
      chrome_cft_version_for_major "${major}"
      ;;
  esac
}

resolve_chrome_major() {
  local cft
  cft="$(resolve_chrome_cft_version "$1")"
  printf '%s' "${cft%%.*}"
}


resolve_warm_tag() {
  local major
  major="$(resolve_chrome_major "$1")"
  printf '%s' "${major}"
}

resolve_variant_tag() {
  local version="$1"
  local variant="$2"
  case "${variant}" in
    min) resolve_min_tag "${version}" ;;
    warm) resolve_warm_tag "${version}" ;;
    *)
      echo "Unknown variant: ${variant} (use min or warm)" >&2
      return 1
      ;;
  esac
}

resolve_dockerfile() {
  local variant="$1"
  case "${variant}" in
    min) printf '%s' "Dockerfile.min.scratch" ;;
    warm) printf '%s' "Dockerfile.warm" ;;
    *)
      echo "Unknown variant: ${variant}" >&2
      return 1
      ;;
  esac
}

# Backward-compatible alias
list_chrome_min_majors() {
  list_chrome_majors
}

resolve_min_tag() {
  local major
  major="$(resolve_chrome_major "$1")"
  printf '%s' "${major}-min"
}

list_chrome_majors() {
  printf '%s\n' "${CHROME_MAJORS[@]}"
}
