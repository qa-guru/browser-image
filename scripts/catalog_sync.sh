#!/usr/bin/env bash
# Apply catalog updates to GitHub consumers after Hub 200.
# Prod (qa-guru/selenoid.qa.guru deploy/browsers-production.json) is last —
# that push triggers deploy.yml (pull_browsers=always). Do not also dispatch
# deploy-selenoid from watch when this script pushed prod (majors).
# Never write hub/UI version fields here — catalog window only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAN="${1:?plan.json}"
TOKEN="${CATALOG_TOKEN:?CATALOG_TOKEN PAT with contents:write on catalog repos}"
WORKDIR="${CATALOG_WORKDIR:-${RUNNER_TEMP:-/tmp}/browser-image-catalog}"
PY="${ROOT}/scripts/update_catalog.py"

mkdir -p "${WORKDIR}"
export GIT_TERMINAL_PROMPT=0

clone_repo() {
  local repo="$1"
  local dest="$2"
  rm -rf "${dest}"
  git clone --depth 1 \
    "https://x-access-token:${TOKEN}@github.com/${repo}.git" \
    "${dest}"
}

commit_push() {
  local dest="$1"
  shift
  (
    cd "${dest}"
    git add "$@"
    if git diff --cached --quiet; then
      echo "no catalog changes in ${dest}"
      return 0
    fi
    git commit -m "$(python3 - "${PLAN}" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
bits = []
for c in plan.get("changes") or []:
    if not c.get("catalog"):
        continue
    b = c["browser"]
    if b == "playwright":
        bits.append(f"playwright {c['new']['version']}")
    else:
        bits.append(f"{b} {c['new']['major']}")
print("chore(browsers): " + (", ".join(bits) or "sync catalog window"))
PY
)"
    git push origin HEAD
  )
}

python3 "${PY}" --plan "${PLAN}" --self-check >/dev/null

clone_repo qa-guru/selenoid "${WORKDIR}/selenoid"
python3 "${PY}" --plan "${PLAN}" \
  --file "${WORKDIR}/selenoid/config/browsers.json" \
  --docs "${WORKDIR}/selenoid/docs/browser-versions.md"
commit_push "${WORKDIR}/selenoid" config/browsers.json docs/browser-versions.md

clone_repo qa-guru/cm "${WORKDIR}/cm"
python3 "${PY}" --plan "${PLAN}" --file "${WORKDIR}/cm/selenoid/data/browsers.json"
commit_push "${WORKDIR}/cm" selenoid/data/browsers.json

clone_repo qa-guru/selenoid-tests "${WORKDIR}/selenoid-tests"
python3 "${PY}" --plan "${PLAN}" \
  --file "${WORKDIR}/selenoid-tests/fixtures/ci-browsers.json" \
  --tests-root "${WORKDIR}/selenoid-tests"
commit_push "${WORKDIR}/selenoid-tests" \
  fixtures/ci-browsers.json \
  scripts/prepare-ci-cm-workspace.sh \
  scripts/start-ci-selenoid-stack.sh \
  src/test/resources/config

clone_repo qa-guru/selenoid-ui "${WORKDIR}/selenoid-ui"
python3 "${PY}" --plan "${PLAN}" --file "${WORKDIR}/selenoid-ui/browsers.json"
commit_push "${WORKDIR}/selenoid-ui" browsers.json

# LAST — deploy.yml browsers-only: copy + docker pull + SIGHUP hub (no hub/UI bounce).
clone_repo qa-guru/selenoid.qa.guru "${WORKDIR}/selenoid-qa-guru"
python3 "${PY}" --plan "${PLAN}" \
  --file "${WORKDIR}/selenoid-qa-guru/deploy/browsers-production.json"
commit_push "${WORKDIR}/selenoid-qa-guru" deploy/browsers-production.json

echo "catalog sync complete (prod push last)"
