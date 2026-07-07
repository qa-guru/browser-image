#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="${ROOT}/scripts"

tag="${1:-}"
if [[ -z "${tag}" ]]; then
  echo "Usage: $0 <git-tag>" >&2
  exit 1
fi

ref="${tag#refs/tags/}"
ref="${ref#webdriver/}"

variant="warm"
browser="chrome"
major="${ref}"

if [[ "${ref}" == firefox-* ]]; then
  browser="firefox"
  major="${ref#firefox-}"
elif [[ "${ref}" == msedge-* ]]; then
  browser="msedge"
  major="${ref#msedge-}"
elif [[ "${ref}" == chrome-* ]]; then
  browser="chrome"
  major="${ref#chrome-}"
fi

if [[ "${major}" == *-min ]]; then
  variant="min"
  major="${major%-min}"
fi

# shellcheck source=/dev/null
source "${SCRIPTS}/${browser}-versions.sh"

case "${browser}" in
  chrome)
    detail="$(resolve_chrome_cft_version "${major}")"
    image="qaguru/webdriver-chrome"
    ;;
  firefox)
    detail="$(resolve_firefox_version "${major}")"
    image="qaguru/webdriver-firefox"
    ;;
  msedge)
    detail="$(resolve_edge_version "${major}")"
    image="qaguru/webdriver-msedge"
    ;;
esac

tag_suffix="${major}"
if [[ "${variant}" == "min" ]]; then
  tag_suffix="${major}-min"
fi

if [[ "${variant}" == "min" ]]; then
  notes="Headless CI image (driver only, no VNC)."
else
  notes="Prod image with Xvfb + x11vnc (port 5900, password \`selenoid\`) when \`ENABLE_VNC=true\`."
fi

cat <<NOTES
## WebDriver ${browser}${variant:+-}${variant} ${major}

Docker image published to Docker Hub:

| Image | Tag | Version |
|-------|-----|---------|
| \`${image}\` | \`${tag_suffix}\` | \`${detail}\` |

${notes}

Triggered by CI workflow \`publish-webdriver\` on tag push.
NOTES
