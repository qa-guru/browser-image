#!/usr/bin/env bash
# Canonical production build: boot once on Linux+KVM, bake userdata/helpers,
# then build qaguru/android:<tag>. Never uses docker commit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-16}"
IMAGE="${IMAGE:-qaguru/android}"
PLATFORM="${PLATFORM:-linux/amd64}"
BASE_TAG="${IMAGE}:${TAG}-base"
OUTPUT="${ROOT}/prepared"

if [[ "$(uname -s)" != "Linux" || ! -e /dev/kvm ]]; then
  echo "ERROR: prepare-image.sh requires Linux + /dev/kvm" >&2
  exit 1
fi

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}"

docker build \
  --platform "${PLATFORM}" \
  --target android-base \
  -f "${ROOT}/Dockerfile" \
  -t "${BASE_TAG}" \
  "${ROOT}"

docker run --rm \
  --device /dev/kvm \
  --security-opt seccomp=unconfined \
  --shm-size 2g \
  --memory 4g \
  --cpus 2 \
  -e "HOST_UID=$(id -u)" \
  -e "HOST_GID=$(id -g)" \
  -v "${OUTPUT}:/prepared" \
  --entrypoint /prepare-avd.sh \
  "${BASE_TAG}"

docker build \
  --platform "${PLATFORM}" \
  --target prepared-runtime \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}" \
  "${ROOT}"

docker image inspect "${IMAGE}:${TAG}" \
  --format 'Built {{.RepoTags}} image={{.Id}} size={{.Size}}'
