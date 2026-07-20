#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-16}"
IMAGE="qaguru/android"

docker push "${IMAGE}:${TAG}"
echo "Pushed ${IMAGE}:${TAG}"
