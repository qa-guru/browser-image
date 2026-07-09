#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-latest}"
IMAGE="qaguru/video-recorder"

if [[ -z "${PLATFORM:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) PLATFORM="linux/arm64" ;;
    *) PLATFORM="linux/amd64" ;;
  esac
fi

docker build \
  --platform "${PLATFORM}" \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}" \
  "${ROOT}"

echo "Built ${IMAGE}:${TAG}"
