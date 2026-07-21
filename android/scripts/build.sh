#!/usr/bin/env bash
# Build qaguru/android:<tag> with prepared userdata on Linux+KVM.
# Other hosts only build the base stage as a Dockerfile validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-16}"
IMAGE="qaguru/android"
PLATFORM="${PLATFORM:-linux/amd64}"

if [[ "$(uname -s)" == "Linux" && -e /dev/kvm ]]; then
  exec "${ROOT}/scripts/prepare-image.sh" "${TAG}"
fi

docker build \
  --platform "${PLATFORM}" \
  --target android-base \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}-base" \
  "${ROOT}"

echo "Built ${IMAGE}:${TAG}-base (${PLATFORM}) for static/build validation."
echo "Production ${IMAGE}:${TAG} requires scripts/prepare-image.sh on Linux + /dev/kvm."
