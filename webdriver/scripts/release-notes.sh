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

if [[ "${ref}" == *-min ]]; then
  major="${ref#chrome-}"
  major="${major%-min}"
  cft="$(resolve_chrome_cft_version "${major}")"
  cat <<EOF
## WebDriver chrome-min ${major}

Docker image published to Docker Hub:

| Image | Tag | CfT |
|-------|-----|-----|
| \`qaguru/webdriver-chrome\` | \`${major}-min\` | \`${cft}\` |

Git tag \`${ref}\` — headless CI image (no VNC / warm API).

Triggered by CI workflow \`publish-webdriver\` on tag push.
EOF
  exit 0
fi

major="${ref#chrome-}"
cft="$(resolve_chrome_cft_version "${major}")"

cat <<EOF
## WebDriver chrome ${major}

Docker images published to Docker Hub:

| Image | Tag | CfT |
|-------|-----|-----|
| \`qaguru/webdriver-chrome\` | \`${major}\` | \`${cft}\` |

Warm pool image: WebDriver \`:4444\`, warm API \`:8080\`, VNC \`:5900\`.

When this tag is pushed, CI also publishes current \`chrome-min\` variants:

| Image | Tag | CfT |
|-------|-----|-----|
EOF

while IFS= read -r min_major; do
  min_cft="$(resolve_chrome_cft_version "${min_major}")"
  printf '| `qaguru/webdriver-chrome` | `%s-min` | `%s` |\n' "${min_major}" "${min_cft}"
done < <(list_chrome_min_majors)

cat <<'EOF'

Git tag `chrome-<major>` — WebDriver release line (independent from Playwright semver).

Triggered by CI workflow `publish-webdriver` on tag push.
EOF
