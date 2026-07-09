#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-latest}"
IMAGE="qaguru/video-recorder"
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

tags=(-t "${IMAGE}:${VERSION}")
if [[ "${VERSION}" != "latest" ]]; then
  tags+=(-t "${IMAGE}:latest")
fi

docker buildx build \
  --pull \
  --platform "${PLATFORMS}" \
  -f "${ROOT}/Dockerfile" \
  "${tags[@]}" \
  --push \
  "${ROOT}"

echo "Pushed ${IMAGE}:${VERSION} for ${PLATFORMS}"
if [[ "${VERSION}" != "latest" ]]; then
  echo "Also tagged ${IMAGE}:latest"
fi
