#!/usr/bin/env bash
set -euo pipefail

FIREFOX_MAJORS=(151 150)
GECKODRIVER_VERSION="0.37.0"

firefox_version_for_major() {
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
    151|151.0) printf '%s' "151" ;;
    150|150.0) printf '%s' "150" ;;
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
