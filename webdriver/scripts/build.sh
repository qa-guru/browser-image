#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
BROWSER="${1:-chrome}"
VERSION="${2:-149}"
VARIANT="${3:-warm}"

source_browser_versions() {
  local browser="$1"
  # shellcheck source=/dev/null
  source "${SCRIPTS}/${browser}-versions.sh"
}

case "${VARIANT}" in
  min|warm|both) ;;
  *)
    echo "Unknown variant: ${VARIANT} (use min, warm, or both)." >&2
    exit 1
    ;;
esac

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
  esac
fi

build_one_variant() {
  local browser="$1"
  local version="$2"
  local variant="$3"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:$(resolve_variant_tag "${version}" "${variant}")"
  local dockerfile build_args=()

  dockerfile="$(resolve_dockerfile "${variant}")"

  case "${browser}" in
    chrome)
      build_args=(
        --build-arg "CHROME_CFT_VERSION=$(resolve_chrome_cft_version "${version}")"
        --build-arg "CHROME_MAJOR=$(resolve_chrome_major "${version}")"
      )
      ;;
    firefox)
      build_args=(
        --build-arg "FIREFOX_VERSION=$(resolve_firefox_version "${version}")"
        --build-arg "GECKODRIVER_VERSION=${GECKODRIVER_VERSION}"
        --build-arg "FIREFOX_MAJOR=$(resolve_firefox_major "${version}")"
      )
      ;;
    msedge)
      local major deb
      major="$(resolve_edge_major "${version}")"
      deb="$(edge_deb_version_for_major "${major}")"
      build_args=(
        --build-arg "EDGE_VERSION=$(resolve_edge_version "${version}")"
        --build-arg "EDGE_DEB_VERSION=${deb}"
        --build-arg "EDGE_MAJOR=${major}"
      )
      ;;
  esac

  docker build \
    --platform "${PLATFORM}" \
    "${build_args[@]}" \
    -f "${ROOT}/${browser}/${dockerfile}" \
    -t "${tag}" \
    "${ROOT}"

  echo "Built ${tag} (${variant})"
}

build_one() {
  local browser="$1"
  local version="$2"
  local variant="$3"

  source_browser_versions "${browser}"

  case "${variant}" in
    both)
      build_one_variant "${browser}" "${version}" warm
      build_one_variant "${browser}" "${version}" min
      ;;
    *)
      build_one_variant "${browser}" "${version}" "${variant}"
      ;;
  esac
}

build_browser_all() {
  local browser="$1"
  local variant="$2"
  source_browser_versions "${browser}"
  local list_fn="list_${browser}_majors"
  while IFS= read -r major; do
    build_one "${browser}" "${major}" "${variant}"
  done < <("${list_fn}")
}

case "${BROWSER}" in
  chrome|firefox|msedge)
    build_one "${BROWSER}" "${VERSION}" "${VARIANT}"
    ;;
  all)
    for b in chrome firefox msedge; do
      build_browser_all "${b}" "${VARIANT}"
    done
    ;;
  *)
    echo "Usage: $0 <chrome|firefox|msedge|all> <major> <min|warm|both>" >&2
    exit 1
    ;;
esac
