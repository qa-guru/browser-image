#!/usr/bin/env bash
# Backfill GitHub tags + releases for images already on Docker Hub.
# Does NOT push tags that trigger CI when SKIP_CI=1 (catalog-only releases).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

REPO="qa-guru/browser-image"
SKIP_CI="${SKIP_CI:-0}"

release_exists() {
  local tag="$1"
  gh release view "${tag}" --repo "${REPO}" >/dev/null 2>&1
}

create_release() {
  local tag="$1"
  local target="$2"
  local notes_file="$3"
  local title="$4"

  if release_exists "${tag}"; then
    echo "skip (exists): ${tag}"
    return 0
  fi

  echo "create: ${tag} @ ${target}"
  gh release create "${tag}" \
    --repo "${REPO}" \
    --target "${target}" \
    --title "${title}" \
    --notes-file "${notes_file}"
}

# Playwright semver lines (images on Docker Hub)
PW_TARGET="${PW_TARGET:-fb01c0d10219290b6a105cafae1af67c0fdd276d}"
PW_MIN_TARGET="${PW_MIN_TARGET:-1d644bbe2fbacd8f18ba54deb636c7786351bae1}"

for version in 1.46.0 1.60.0 1.61.0 1.61.1; do
  tag="playwright/${version}"
  ./playwright/scripts/release-notes.sh "${tag}" > "/tmp/notes-${tag//\//-}.md"
  if [[ "${SKIP_CI}" == "1" ]]; then
    create_release "${tag}" "${PW_TARGET}" "/tmp/notes-${tag//\//-}.md" "Playwright ${version}"
  else
    if ! release_exists "${tag}"; then
      git tag -a "${tag}" -m "Playwright ${version}" "${PW_TARGET}" 2>/dev/null || git tag -f -a "${tag}" -m "Playwright ${version}" "${PW_TARGET}"
      git push origin "${tag}"
    fi
  fi
done

for version in 1.60.0 1.61.1; do
  tag="playwright/${version}-min"
  ./playwright/scripts/release-notes.sh "${tag}" > "/tmp/notes-${tag//\//-}.md"
  if [[ "${SKIP_CI}" == "1" ]]; then
    create_release "${tag}" "${PW_MIN_TARGET}" "/tmp/notes-${tag//\//-}.md" "Playwright ${version}-min"
  else
    if ! release_exists "${tag}"; then
      git tag -a "${tag}" -m "Playwright ${version}-min" "${PW_MIN_TARGET}" 2>/dev/null || true
      git push origin "${tag}"
    fi
  fi
done

# WebDriver chrome-148 (warm image still on Docker Hub; catalog-only, no CI)
tag="webdriver/chrome-148"
if ! release_exists "${tag}"; then
  cat > /tmp/notes-webdriver-chrome-148.md <<'EOF'
## WebDriver chrome 148

Docker image on Docker Hub (legacy publish):

| Image | Tag |
|-------|-----|
| `qaguru/webdriver-chrome` | `148` |

Catalog release for an image already published to Docker Hub. Current `browser-image` CI builds `chrome-min` only.
EOF
  create_release "${tag}" "${PW_TARGET}" /tmp/notes-webdriver-chrome-148.md "WebDriver chrome-148"
fi

echo "done"
