#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
WARM_API_SRC="${ROOT}/../../warm-pool-orchestrator/warm-api"
WARM_API_VENDOR="${ROOT}/vendor/warm-api"
BROWSER="${1:-}"
VERSION="${2:-148}"
VARIANT="${3:-}"

# shellcheck source=chrome-min-versions.sh
source "${SCRIPTS}/chrome-min-versions.sh"

if [[ -z "${BROWSER}" ]]; then
  echo "Usage: $0 <browser|all> [version-tag] [variant]" >&2
  echo "Variants: (default, Dockerfile.scratch) | min (chrome only, Dockerfile.min.scratch)" >&2
  exit 1
fi

if [[ -n "${VARIANT}" && "${VARIANT}" != "min" ]]; then
  echo "Unknown variant: ${VARIANT}" >&2
  exit 1
fi

if [[ "${VARIANT}" == "min" && "${BROWSER}" != "chrome" && "${BROWSER}" != "all" ]]; then
  echo "Variant min is only supported for chrome" >&2
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
    echo "Push to qaguru/webdriver-* requires write access to the Docker Hub namespace." >&2
    exit 1
  fi
fi

if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
  docker buildx create --name "${BUILDER}" --driver docker-container --use
else
  docker buildx use "${BUILDER}"
fi

stage_warm_api() {
  local src=""
  if [[ -d "${WARM_API_SRC}" ]]; then
    src="${WARM_API_SRC}"
  elif [[ -d "${WARM_API_VENDOR}" ]]; then
    src="${WARM_API_VENDOR}"
  else
    echo "warm-api not found at ${WARM_API_SRC} or ${WARM_API_VENDOR}" >&2
    exit 1
  fi
  rm -rf "${ROOT}/warm-api"
  cp -R "${src}" "${ROOT}/warm-api"
  cp "${ROOT}/shared/webdriver-warm-main.cjs" "${ROOT}/warm-api/"
}

push_one() {
  local browser="$1"
  local version="$2"
  local variant="${3:-}"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:${version}"
  local dockerfile="${ROOT}/${browser}/Dockerfile.scratch"
  local build_args=()
  local context="${ROOT}"
  local cft_version major

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"

  local platforms="${PLATFORMS}"

  if [[ "${variant}" == "min" ]]; then
    tag="${image}:$(resolve_min_tag "${version}")"
    dockerfile="${ROOT}/${browser}/Dockerfile.min.scratch"
    build_args=(
      --build-arg "CHROME_CFT_VERSION=${cft_version}"
      --build-arg "CHROME_MAJOR=${major}"
    )
  else
    stage_warm_api
    tag="${image}:${major}"
    build_args=(
      --build-arg "CHROME_CFT_VERSION=${cft_version}"
      --build-arg "CHROME_MAJOR=${major}"
    )
    # CfT Chrome zip is not available for every linux-arm64 milestone; warm pool runs amd64.
    platforms="linux/amd64"
  fi

  docker buildx build \
    --pull \
    --platform "${platforms}" \
    "${build_args[@]}" \
    -f "${dockerfile}" \
    -t "${tag}" \
    --push \
    "${context}"

  echo "Pushed ${tag} for ${platforms}"
  rm -rf "${ROOT}/warm-api"
}

if [[ "${BROWSER}" == "all" ]]; then
  push_one chrome "${VERSION}"
  while IFS= read -r major; do
    push_one chrome "${major}" min
  done < <(list_chrome_min_majors)
elif [[ -n "${VARIANT}" ]]; then
  push_one "${BROWSER}" "${VERSION}" "${VARIANT}"
else
  push_one "${BROWSER}" "${VERSION}"
fi
