#!/bin/bash
# Retry apt: qemu/arm64 builds flake on ports.ubuntu.com mirror sync.
set -euo pipefail
max=5
attempt=1
until apt-get update; do
  if (( attempt >= max )); then
    echo "apt-get update failed after ${max} attempts" >&2
    exit 1
  fi
  echo "apt-get update retry ${attempt}/${max}" >&2
  sleep $((attempt * 8))
  attempt=$((attempt + 1))
done
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
