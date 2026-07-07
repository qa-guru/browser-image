#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BROWSER="${1:-}"
VERSION="${2:-1.61.1}"
VARIANT="${3:-}"

if [[ -z "${BROWSER}" ]]; then
  echo "Usage: $0 <browser> [version-tag] [variant]" >&2
  echo "Browsers: chromium firefox webkit chrome msedge all" >&2
  echo "Variants: (default) | min (chromium only)" >&2
  exit 1
fi

if [[ -n "${VARIANT}" && "${VARIANT}" != "min" ]]; then
  echo "Unknown variant: ${VARIANT}" >&2
  exit 1
fi

if [[ "${VARIANT}" == "min" && "${BROWSER}" != "chromium" ]]; then
  echo "Variant min is only supported for chromium" >&2
  exit 1
fi

normalize_version() {
  local v="${1#v}"
  v="${v%-noble}"
  printf '%s' "$v"
}

PW_PACKAGE="$(normalize_version "${VERSION}")"

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
  esac
fi

build_one() {
  local browser="$1"
  local image="qaguru/playwright-${browser}"
  local tag="${image}:${PW_PACKAGE}"
  local dockerfile="${ROOT}/playwright-${browser}/Dockerfile"

  if [[ "${VARIANT}" == "min" ]]; then
    dockerfile="${ROOT}/playwright-${browser}/Dockerfile.min.scratch"
    tag="${image}:${PW_PACKAGE}-min"
  fi

  if [[ ! -f "${dockerfile}" ]]; then
    echo "Unknown browser: ${browser}" >&2
    exit 1
  fi

  docker build \
    --platform "${PLATFORM}" \
    --build-arg "PLAYWRIGHT_VERSION=${PW_PACKAGE}" \
    -f "${dockerfile}" \
    -t "${tag}" \
    "${ROOT}"

  echo "Built ${tag}"
}

if [[ "${BROWSER}" == "all" ]]; then
  for b in chromium firefox webkit chrome msedge; do
    build_one "${b}"
  done
else
  build_one "${BROWSER}"
fi
