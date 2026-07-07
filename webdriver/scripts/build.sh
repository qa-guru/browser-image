#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"
BROWSER="${1:-chrome}"
VERSION="${2:-149}"
VARIANT="${3:-warm}"

# shellcheck source=chrome-versions.sh
source "${SCRIPTS}/chrome-versions.sh"

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
  local cft_version major dockerfile

  cft_version="$(resolve_chrome_cft_version "${version}")"
  major="$(resolve_chrome_major "${version}")"
  dockerfile="$(resolve_dockerfile "${variant}")"

  docker build \
    --platform "${PLATFORM}" \
    --build-arg "CHROME_CFT_VERSION=${cft_version}" \
    --build-arg "CHROME_MAJOR=${major}" \
    -f "${ROOT}/${browser}/${dockerfile}" \
    -t "${tag}" \
    "${ROOT}"

  echo "Built ${tag} (${variant})"
}

build_one() {
  local browser="$1"
  local version="$2"
  local variant="$3"

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

if [[ "${BROWSER}" == "all" ]]; then
  while IFS= read -r major; do
    build_one chrome "${major}" "${VARIANT}"
  done < <(list_chrome_majors)
else
  build_one "${BROWSER}" "${VERSION}" "${VARIANT}"
fi
