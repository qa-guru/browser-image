#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
WARM_API_SRC="${ROOT}/../../warm-pool-orchestrator/warm-api"
BROWSER="${1:-chrome}"
VERSION="${2:-148}"
VARIANT="${3:-}"

# shellcheck source=chrome-min-versions.sh
source "${SCRIPTS}/chrome-min-versions.sh"

if [[ -n "${VARIANT}" && "${VARIANT}" != "min" ]]; then
  echo "Unknown variant: ${VARIANT}" >&2
  exit 1
fi

if [[ "${VARIANT}" == "min" && "${BROWSER}" != "chrome" ]]; then
  echo "Variant min is only supported for chrome" >&2
  exit 1
fi

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
  esac
fi

stage_warm_api() {
  if [[ ! -d "${WARM_API_SRC}" ]]; then
    echo "warm-api not found at ${WARM_API_SRC}" >&2
    exit 1
  fi
  rm -rf "${ROOT}/warm-api"
  cp -R "${WARM_API_SRC}" "${ROOT}/warm-api"
  cp "${ROOT}/shared/webdriver-warm-main.cjs" "${ROOT}/warm-api/"
}

build_one() {
  local browser="$1"
  local version="$2"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:${version}"
  local dockerfile="${ROOT}/${browser}/Dockerfile.scratch"
  local build_args=()
  local cft_version major

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"

  if [[ "${VARIANT}" == "min" ]]; then
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
  fi

  if [[ ! -f "${dockerfile}" ]]; then
    echo "Unknown browser: ${browser}" >&2
    exit 1
  fi

  docker build \
    --platform "${PLATFORM}" \
    "${build_args[@]}" \
    -f "${dockerfile}" \
    -t "${tag}" \
    "${ROOT}"

  echo "Built ${tag}"
  rm -rf "${ROOT}/warm-api"
}

if [[ "${BROWSER}" == "all" ]]; then
  if [[ "${VARIANT}" == "min" ]]; then
    while IFS= read -r major; do
      build_one chrome "${major}"
    done < <(list_chrome_min_majors)
  else
    build_one chrome "${VERSION}"
  fi
else
  build_one "${BROWSER}" "${VERSION}"
fi
