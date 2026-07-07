#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
BROWSER="${1:-chrome}"
VERSION="${2:-149}"
VARIANT="${3:-min}"

# shellcheck source=chrome-min-versions.sh
source "${SCRIPTS}/chrome-min-versions.sh"

if [[ "${VARIANT}" != "min" ]]; then
  echo "Only chrome-min images are built from this repo (variant: min)." >&2
  exit 1
fi

if [[ "${BROWSER}" != "chrome" && "${BROWSER}" != "all" ]]; then
  echo "Only chrome is supported." >&2
  exit 1
fi

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
  esac
fi

build_one() {
  local browser="$1"
  local version="$2"
  local image="qaguru/webdriver-${browser}"
  local tag="${image}:$(resolve_min_tag "${version}")"
  local cft_version major

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"

  docker build \
    --platform "${PLATFORM}" \
    --build-arg "CHROME_CFT_VERSION=${cft_version}" \
    --build-arg "CHROME_MAJOR=${major}" \
    -f "${ROOT}/${browser}/Dockerfile.min.scratch" \
    -t "${tag}" \
    "${ROOT}"

  echo "Built ${tag}"
}

if [[ "${BROWSER}" == "all" ]]; then
  while IFS= read -r major; do
    build_one chrome "${major}"
  done < <(list_chrome_min_majors)
else
  build_one "${BROWSER}" "${VERSION}"
fi
