#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
BROWSER="${1:-chrome}"
VERSION="${2:-149}"
VARIANT="${3:-min}"

# shellcheck source=chrome-min-versions.sh
source "${SCRIPTS}/chrome-min-versions.sh"

if [[ -z "${BROWSER}" ]]; then
  echo "Usage: $0 <browser|all> <chrome-major> min" >&2
  exit 1
fi

if [[ "${VARIANT}" != "min" ]]; then
  echo "Only chrome-min images are published from this repo (variant: min)." >&2
  exit 1
fi

if [[ "${BROWSER}" != "chrome" && "${BROWSER}" != "all" ]]; then
  echo "Only chrome is supported." >&2
  exit 1
fi

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

push_one() {
  local browser="$1"
  local version="$2"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:$(resolve_min_tag "${version}")"
  local cft_version major

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"

  docker buildx build \
    --pull \
    --platform "${PLATFORMS}" \
    --build-arg "CHROME_CFT_VERSION=${cft_version}" \
    --build-arg "CHROME_MAJOR=${major}" \
    -f "${ROOT}/${browser}/Dockerfile.min.scratch" \
    -t "${tag}" \
    --push \
    "${ROOT}"

  echo "Pushed ${tag} for ${PLATFORMS}"
}

if [[ "${BROWSER}" == "all" ]]; then
  while IFS= read -r major; do
    push_one chrome "${major}"
  done < <(list_chrome_min_majors)
else
  push_one "${BROWSER}" "${VERSION}"
fi
