#!/usr/bin/env bash
set -euo pipefail

_WEBDRIVER_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_WEBDRIVER_SCRIPTS}/../.." && pwd)"
_PINS="${_REPO_ROOT}/pins.json"
_PIN_GET="${_REPO_ROOT}/scripts/pin_get.py"

_pin() {
  python3 "${_PIN_GET}" "${_PINS}" "$1"
}

EDGE_MAJORS=("$(_pin msedge.default_major)" "$(_pin msedge.regression_major)")
_EDGE_DEFAULT="$(_pin msedge.default_major)"
EDGEDRIVER_VERSION="$(_pin "msedge.versions.${_EDGE_DEFAULT}")"

edge_version_for_major() {
  local pinned
  if pinned="$(_pin "msedge.versions.$1" 2>/dev/null)"; then
    printf '%s' "${pinned}"
    return 0
  fi
  case "$1" in
    145) printf '%s' "145.0.3800.97" ;;
    144) printf '%s' "144.0.3719.82" ;;
    *)
      echo "Unknown edge major: ${1}" >&2
      return 1
      ;;
  esac
}

edge_deb_version_for_major() {
  local pinned
  if pinned="$(_pin "msedge.deb_versions.$1" 2>/dev/null)"; then
    printf '%s' "${pinned}"
    return 0
  fi
  case "$1" in
    145) printf '%s' "145.0.3800.97-1" ;;
    144) printf '%s' "144.0.3719.82-1" ;;
    *) edge_version_for_major "$1" | sed 's/$/-1/' ;;
  esac
}

normalize_edge_version() {
  local version="${1#v}"
  version="${version%-min}"
  case "${version}" in
    *.*) printf '%s' "${version%%.*}" ;;
    *) printf '%s' "${version}" ;;
  esac
}

resolve_edge_version() {
  local major
  major="$(normalize_edge_version "$1")"
  edge_version_for_major "${major}"
}

resolve_edge_major() {
  normalize_edge_version "$1"
}

resolve_warm_tag() {
  resolve_edge_major "$1"
}

resolve_min_tag() {
  printf '%s-min' "$(resolve_edge_major "$1")"
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

list_edge_majors() {
  printf '%s\n' "${EDGE_MAJORS[@]}"
}

# push.sh / build.sh call list_${browser}_majors → list_msedge_majors
list_msedge_majors() {
  list_edge_majors
}
