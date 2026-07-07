#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"

# shellcheck source=chrome-min-versions.sh
source "${SCRIPTS}/chrome-min-versions.sh"

tag="${1:-}"
if [[ -z "${tag}" ]]; then
  echo "Usage: $0 <git-tag>" >&2
  exit 1
fi

ref="${tag#refs/tags/}"
ref="${ref#webdriver/}"

if [[ "${ref}" != *-min ]]; then
  echo "Expected chrome-min tag, got: ${ref}" >&2
  exit 1
fi

major="${ref#chrome-}"
major="${major%-min}"
cft="$(resolve_chrome_cft_version "${major}")"

cat <<EOF
## WebDriver chrome-min ${major}

Docker image published to Docker Hub:

| Image | Tag | CfT |
|-------|-----|-----|
| \`qaguru/webdriver-chrome\` | \`${major}-min\` | \`${cft}\` |

Headless CI image (chromedriver only, no VNC).

Triggered by CI workflow \`publish-webdriver\` on tag push.
EOF
