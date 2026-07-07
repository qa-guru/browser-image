#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"

# shellcheck source=chrome-versions.sh
source "${SCRIPTS}/chrome-versions.sh"

tag="${1:-}"
if [[ -z "${tag}" ]]; then
  echo "Usage: $0 <git-tag>" >&2
  exit 1
fi

ref="${tag#refs/tags/}"
ref="${ref#webdriver/}"

variant="warm"
major="${ref#chrome-}"
if [[ "${major}" == *-min ]]; then
  variant="min"
  major="${major%-min}"
fi

cft="$(resolve_chrome_cft_version "${major}")"

if [[ "${variant}" == "min" ]]; then
  cat <<NOTES
## WebDriver chrome-min ${major}

Docker image published to Docker Hub:

| Image | Tag | CfT |
|-------|-----|-----|
| \`qaguru/webdriver-chrome\` | \`${major}-min\` | \`${cft}\` |

Headless CI image (chromedriver only, no VNC).

Triggered by CI workflow \`publish-webdriver\` on tag push.
NOTES
else
  cat <<NOTES
## WebDriver chrome ${major}

Docker image published to Docker Hub:

| Image | Tag | CfT |
|-------|-----|-----|
| \`qaguru/webdriver-chrome\` | \`${major}\` | \`${cft}\` |

Prod image with Xvfb + x11vnc (port 5900, password \`selenoid\`) when \`ENABLE_VNC=true\`.

Triggered by CI workflow \`publish-webdriver\` on tag push.
NOTES
fi
