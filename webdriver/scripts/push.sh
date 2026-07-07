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

PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-browser-image}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running." >&2
  exit 1
fi

if [[ -z "${CI:-}" ]] && command -v docker-credential-desktop >/dev/null 2>&1; then
  if ! docker-credential-desktop list 2>/dev/null | grep -q 'index.docker.io'; then
    echo "Run: docker login" >&2
    exit 1
  fi
fi

if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
  docker buildx create --name "${BUILDER}" --driver docker-container --use
else
  docker buildx use "${BUILDER}"
fi

push_one_variant() {
  local browser="$1"
  local version="$2"
  local variant="$3"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:$(resolve_variant_tag "${version}" "${variant}")"
  local dockerfile build_args=() platforms="${PLATFORMS}"

  dockerfile="$(resolve_dockerfile "${variant}")"
  if [[ "${browser}" == "msedge" ]]; then
    platforms="linux/amd64"
  fi

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

  docker buildx build \
    --pull \
    --platform "${platforms}" \
    "${build_args[@]}" \
    -f "${ROOT}/${browser}/${dockerfile}" \
    -t "${tag}" \
    --push \
    "${ROOT}"

  echo "Pushed ${tag} (${variant}) for ${platforms}"
}

push_one() {
  local browser="$1"
  local version="$2"
  local variant="$3"
  source_browser_versions "${browser}"
  case "${variant}" in
    both)
      push_one_variant "${browser}" "${version}" warm
      push_one_variant "${browser}" "${version}" min
      ;;
    *)
      push_one_variant "${browser}" "${version}" "${variant}"
      ;;
  esac
}

push_browser_all() {
  local browser="$1"
  local variant="$2"
  source_browser_versions "${browser}"
  local list_fn="list_${browser}_majors"
  while IFS= read -r major; do
    push_one "${browser}" "${major}" "${variant}"
  done < <("${list_fn}")
}

case "${BROWSER}" in
  chrome|firefox|msedge)
    push_one "${BROWSER}" "${VERSION}" "${VARIANT}"
    ;;
  all)
    for b in chrome firefox msedge; do
      push_browser_all "${b}" "${VARIANT}"
    done
    ;;
  *)
    echo "Usage: $0 <chrome|firefox|msedge|all> <major> <min|warm|both>" >&2
    exit 1
    ;;
esac
