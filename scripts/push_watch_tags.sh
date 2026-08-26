#!/usr/bin/env bash
# Push git tags one-by-one so each tag creates its own publish workflow.
# GITHUB_TOKEN tag pushes do not trigger Actions — use a PAT (see watch.yml).
# stdin: "create webdriver/chrome-153" / "recreate webdriver/chrome-152"
set -euo pipefail

sleep_s="${WATCH_TAG_SLEEP:-3}"

push_one() {
  local action="$1"
  local tag="$2"
  local exists=0
  if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
    exists=1
  elif git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    exists=1
  fi
  if [[ "${exists}" -eq 1 || "${action}" == "recreate" ]]; then
    echo "recreate tag ${tag}"
    git push origin ":refs/tags/${tag}" || true
    git tag -d "${tag}" 2>/dev/null || true
  else
    echo "create tag ${tag}"
  fi
  git tag -a "${tag}" -m "${tag}"
  git push origin "refs/tags/${tag}"
  sleep "${sleep_s}"
}

while read -r action tag; do
  [[ -z "${action:-}" || -z "${tag:-}" ]] && continue
  [[ "${action}" == \#* ]] && continue
  push_one "${action}" "${tag}"
done
