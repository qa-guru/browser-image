#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
if [[ -z "${tag}" ]]; then
  echo "Usage: $0 <git-tag>" >&2
  exit 1
fi

ref="${tag#refs/tags/}"
ref="${ref#playwright/}"

if [[ "${ref}" == *-min ]]; then
  version="${ref%-min}"
  cat <<EOF
## Playwright chromium-min ${version}

Docker image published to Docker Hub:

| Image | Tag |
|-------|-----|
| \`qaguru/playwright-chromium\` | \`${version}-min\` |

Headless CI chromium (no VNC).

Git tag \`playwright/${version}-min\`.

Triggered by CI workflow \`publish\` on tag push.
EOF
  exit 0
fi

version="${ref}"

cat <<EOF
## Playwright ${version} browser images

Docker images published to Docker Hub:

| Image | Tag |
|-------|-----|
| \`qaguru/playwright-chromium\` | \`${version}\` |
| \`qaguru/playwright-firefox\` | \`${version}\` |
| \`qaguru/playwright-webkit\` | \`${version}\` |
| \`qaguru/playwright-chrome\` | \`${version}\` |
| \`qaguru/playwright-msedge\` | \`${version}\` |
| \`qaguru/playwright-chromium\` | \`${version}-min\` |

Git tag \`playwright/${version}\` — Playwright release line.

Triggered by CI workflow \`publish\` on tag push.
EOF
