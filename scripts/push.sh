#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BROWSER="${1:-}"
VERSION="${2:-1.61.1}"
VARIANT="${3:-}"

if [[ -z "${BROWSER}" ]]; then
  echo "Usage: $0 <browser|all> [version-tag] [variant]" >&2
  echo "Variants: (default) | min (chromium only, Dockerfile.min.scratch)" >&2
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
  v="${v%-min}"
  printf '%s' "$v"
}

PW_PACKAGE="$(normalize_version "${VERSION}")"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-playwright-image}"

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running." >&2
  exit 1
fi

# Local Docker Desktop check only; CI authenticates via docker/login-action.
if [[ -z "${CI:-}" ]] && command -v docker-credential-desktop >/dev/null 2>&1; then
  if ! docker-credential-desktop list 2>/dev/null | grep -q 'index.docker.io'; then
    echo "Run: docker login" >&2
    echo "Push to qaguru/playwright-* requires write access to the Docker Hub namespace." >&2
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
  local variant="${2:-}"
  local image="qaguru/playwright-${browser}"
  local tag="${image}:${PW_PACKAGE}"
  local dockerfile="${ROOT}/playwright-${browser}/Dockerfile"
  local platforms="${PLATFORMS}"
  local context="${ROOT}"

  if [[ "${variant}" == "min" ]]; then
    dockerfile="${ROOT}/playwright-${browser}/Dockerfile.min.scratch"
    tag="${image}:${PW_PACKAGE}-min"
  fi

  if [[ "${browser}" == "chrome" || "${browser}" == "msedge" ]]; then
    platforms="${PLATFORMS_ARM:-linux/amd64}"
  fi

  docker buildx build \
    --pull \
    --platform "${platforms}" \
    --build-arg "PLAYWRIGHT_VERSION=${PW_PACKAGE}" \
    -f "${dockerfile}" \
    -t "${tag}" \
    --push \
    "${context}"

  echo "Pushed ${tag} for ${platforms}"
}

if [[ "${BROWSER}" == "all" ]]; then
  for b in chromium firefox webkit chrome msedge; do
    push_one "${b}"
  done
  push_one chromium min
elif [[ -n "${VARIANT}" ]]; then
  push_one "${BROWSER}" "${VARIANT}"
else
  push_one "${BROWSER}"
fi
