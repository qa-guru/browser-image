#!/usr/bin/env bash
# Canonical production build: boot once on Linux+KVM, bake userdata/helpers,
# then build qaguru/android:<tag>. Never uses docker commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-16}"
IMAGE="${IMAGE:-qaguru/android}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
BOOT_TIMEOUT_SEC="${BOOT_TIMEOUT_SEC:-600}"
BASE_TAG="${IMAGE}:${TAG}-base"
OUTPUT="${ROOT}/prepared"

# shellcheck source=version-map.sh
source "$(dirname "$0")/version-map.sh"

if [[ "$(uname -s)" != "Linux" || ! -e /dev/kvm ]]; then
  echo "ERROR: prepare-image.sh requires Linux + /dev/kvm" >&2
  exit 1
fi

read -r AVD_NAME PLATFORM_ARG BUILD_TOOLS DEVICE EMULATOR_IMAGE_TYPE <<<"$(resolve_android_tag "${TAG}")"

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}"

docker build \
  --platform "${DOCKER_PLATFORM}" \
  --target android-base \
  --build-arg "AVD_NAME=${AVD_NAME}" \
  --build-arg "PLATFORM=${PLATFORM_ARG}" \
  --build-arg "BUILD_TOOLS=${BUILD_TOOLS}" \
  --build-arg "DEVICE=${DEVICE}" \
  --build-arg "EMULATOR_IMAGE_TYPE=${EMULATOR_IMAGE_TYPE}" \
  -f "${ROOT}/Dockerfile" \
  -t "${BASE_TAG}" \
  "${ROOT}"

docker run --rm \
  --device /dev/kvm \
  --security-opt seccomp=unconfined \
  --shm-size 2g \
  --memory 6g \
  --cpus 4 \
  -e "HOST_UID=$(id -u)" \
  -e "HOST_GID=$(id -g)" \
  -e "AVD_NAME=${AVD_NAME}" \
  -e "BOOT_TIMEOUT_SEC=${BOOT_TIMEOUT_SEC}" \
  -v "${OUTPUT}:/prepared" \
  -v "${ROOT}/scripts/prepare-avd.sh:/prepare-avd.sh:ro" \
  --entrypoint /prepare-avd.sh \
  "${BASE_TAG}"

docker build \
  --platform "${DOCKER_PLATFORM}" \
  --target prepared-runtime \
  --build-arg "AVD_NAME=${AVD_NAME}" \
  --build-arg "PLATFORM=${PLATFORM_ARG}" \
  --build-arg "BUILD_TOOLS=${BUILD_TOOLS}" \
  --build-arg "DEVICE=${DEVICE}" \
  --build-arg "EMULATOR_IMAGE_TYPE=${EMULATOR_IMAGE_TYPE}" \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}" \
  "${ROOT}"

docker image inspect "${IMAGE}:${TAG}" \
  --format 'Built {{.RepoTags}} image={{.Id}} size={{.Size}}'
