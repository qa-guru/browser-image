#!/usr/bin/env bash
# Build qaguru/android:<tag> with prepared userdata on Linux+KVM.
# Other hosts only build the base stage as a Dockerfile validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-16}"
IMAGE="qaguru/android"
PLATFORM="${PLATFORM:-linux/amd64}"

# shellcheck source=version-map.sh
source "$(dirname "$0")/version-map.sh"

if [[ "$(uname -s)" == "Linux" && -e /dev/kvm ]]; then
  exec "${ROOT}/scripts/prepare-image.sh" "${TAG}"
fi

read -r AVD_NAME PLATFORM_ARG BUILD_TOOLS DEVICE EMULATOR_IMAGE_TYPE <<<"$(resolve_android_tag "${TAG}")"

docker build \
  --platform "${PLATFORM}" \
  --target android-base \
  --build-arg "AVD_NAME=${AVD_NAME}" \
  --build-arg "PLATFORM=${PLATFORM_ARG}" \
  --build-arg "BUILD_TOOLS=${BUILD_TOOLS}" \
  --build-arg "DEVICE=${DEVICE}" \
  --build-arg "EMULATOR_IMAGE_TYPE=${EMULATOR_IMAGE_TYPE}" \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}-base" \
  "${ROOT}"

echo "Built ${IMAGE}:${TAG}-base (${PLATFORM}, AVD=${AVD_NAME}, ${PLATFORM_ARG})."
echo "Production ${IMAGE}:${TAG} requires scripts/prepare-image.sh on Linux + /dev/kvm."
