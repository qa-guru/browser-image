#!/usr/bin/env bash
set -euo pipefail

EDGE_MAJORS=(151 150)
EDGEDRIVER_VERSION="151.0.4129.107"

edge_version_for_major() {
  case "$1" in
    151) printf '%s' "151.0.4129.107" ;;
    150) printf '%s' "150.0.4078.96" ;;
    145) printf '%s' "145.0.3800.97" ;;
    144) printf '%s' "144.0.3719.82" ;;
    *)
      echo "Unknown edge major: ${1}" >&2
      return 1
      ;;
  esac
}

edge_deb_version_for_major() {
  case "$1" in
    151) printf '%s' "151.0.4129.107-1" ;;
    150) printf '%s' "150.0.4078.96-1" ;;
    145) printf '%s' "145.0.3800.97-1" ;;
    144) printf '%s' "144.0.3719.82-1" ;;
    *) edge_version_for_major "$1" | sed 's/$/-1/' ;;
  esac
}

normalize_edge_version() {
  local version="${1#v}"
  version="${version%-min}"
  case "${version}" in
    151|151.0) printf '%s' "151" ;;
    150|150.0) printf '%s' "150" ;;
    145|145.0) printf '%s' "145" ;;
    144|144.0) printf '%s' "144" ;;
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
