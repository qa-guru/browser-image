#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
BROWSER="${1:-chrome}"
VERSION="${2:-149}"
VARIANT="${3:-warm}"

# shellcheck source=chrome-versions.sh
source "${SCRIPTS}/chrome-versions.sh"

if [[ -z "${BROWSER}" ]]; then
  echo "Usage: $0 <browser|all> <chrome-major> <min|warm|both>" >&2
  exit 1
fi

if [[ "${BROWSER}" != "chrome" && "${BROWSER}" != "all" ]]; then
  echo "Only chrome is supported." >&2
  exit 1
fi

case "${VARIANT}" in
  min|warm|both) ;;
  *)
    echo "Unknown variant: ${VARIANT} (use min, warm, or both)." >&2
    exit 1
    ;;
esac

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
  local cft_version major dockerfile

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"
  dockerfile="$(resolve_dockerfile "${variant}")"

  docker buildx build \
    --pull \
    --platform "${PLATFORMS}" \
    --build-arg "CHROME_CFT_VERSION=${cft_version}" \
    --build-arg "CHROME_MAJOR=${major}" \
    -f "${ROOT}/${browser}/${dockerfile}" \
    -t "${tag}" \
    --push \
    "${ROOT}"

  echo "Pushed ${tag} (${variant}) for ${PLATFORMS}"
}

push_one() {
  local browser="$1"
  local version="$2"
  local variant="$3"

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

if [[ "${BROWSER}" == "all" ]]; then
  while IFS= read -r major; do
    push_one chrome "${major}" "${VARIANT}"
  done < <(list_chrome_majors)
else
  push_one "${BROWSER}" "${VERSION}" "${VARIANT}"
fi
