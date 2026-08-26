#!/usr/bin/env bash
set -euo pipefail

_WEBDRIVER_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_WEBDRIVER_SCRIPTS}/../.." && pwd)"
_PINS="${_REPO_ROOT}/pins.json"
_PIN_GET="${_REPO_ROOT}/scripts/pin_get.py"

_pin() {
  python3 "${_PIN_GET}" "${_PINS}" "$1"
}

FIREFOX_MAJORS=("$(_pin firefox.default_major)" "$(_pin firefox.regression_major)")
GECKODRIVER_VERSION="$(_pin firefox.geckodriver)"

firefox_version_for_major() {
  local pinned
  if pinned="$(_pin "firefox.versions.$1" 2>/dev/null)"; then
    printf '%s' "${pinned}"
    return 0
  fi
  case "$1" in
    151) printf '%s' "151.0" ;;
    150) printf '%s' "150.0" ;;
    *)
      echo "Unknown firefox major: ${1}" >&2
      return 1
      ;;
  esac
}

normalize_firefox_version() {
  local version="${1#v}"
  version="${version%-min}"
  case "${version}" in
    *.*) printf '%s' "${version%%.*}" ;;
    *) printf '%s' "${version}" ;;
  esac
}

resolve_firefox_version() {
  local major
  major="$(normalize_firefox_version "$1")"
  firefox_version_for_major "${major}"
}

resolve_firefox_major() {
  normalize_firefox_version "$1"
}

resolve_warm_tag() {
  resolve_firefox_major "$1"
}

resolve_min_tag() {
  printf '%s-min' "$(resolve_firefox_major "$1")"
}

resolve_variant_tag() {
  local version="$1"
  local variant="$2"
  case "${variant}" in
    min) resolve_min_tag "${version}" ;;
    warm) resolve_warm_tag "${version}" ;;
    *) echo "Unknown variant: ${variant}" >&2; return 1 ;;
  esac
}

resolve_dockerfile() {
  local variant="$1"
  case "${variant}" in
    min) printf '%s' "Dockerfile.min.scratch" ;;
    warm) printf '%s' "Dockerfile.warm" ;;
    *) echo "Unknown variant: ${variant}" >&2; return 1 ;;
  esac
}

list_firefox_majors() {
  printf '%s\n' "${FIREFOX_MAJORS[@]}"
}
