#!/usr/bin/env bash
# Build and push qaguru/android tags 11–15 (16 already published).
# Requires Linux + /dev/kvm and docker login to Docker Hub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Linux" || ! -e /dev/kvm ]]; then
  echo "ERROR: build-all.sh requires Linux + /dev/kvm" >&2
  exit 1
fi

for tag in 11 12 13 14 15; do
  echo "==> Building qaguru/android:${tag}"
  "${ROOT}/scripts/prepare-image.sh" "${tag}"
  "${ROOT}/scripts/push.sh" "${tag}"
done

echo "==> Done. Tags 11–15 pushed to qaguru/android"
