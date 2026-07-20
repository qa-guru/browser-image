#!/usr/bin/env bash
# Build qaguru/android:<tag> for Linux+KVM (linux/amd64, x86_64 AVD).
# Mac: build only — sessions need Linux+/dev/kvm (Mac runtime deferred).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-16}"
IMAGE="qaguru/android"
PLATFORM="${PLATFORM:-linux/amd64}"

docker build \
  --platform "${PLATFORM}" \
  -f "${ROOT}/Dockerfile" \
  -t "${IMAGE}:${TAG}" \
  "${ROOT}"

echo "Built ${IMAGE}:${TAG} (${PLATFORM}, x86_64 AVD)"
echo "Runtime: Linux + /dev/kvm only. Mac sessions deferred."
