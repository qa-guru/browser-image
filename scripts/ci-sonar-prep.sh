#!/usr/bin/env bash
# Offline prep for Sonar: validate shell/JSON and optional Go coverage.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t shells < <(find playwright webdriver video-recorder scripts -type f -name '*.sh' 2>/dev/null | sort)
  if ((${#shells[@]})); then
    shellcheck -x "${shells[@]}"
  fi
else
  echo "shellcheck not installed — skip (CI image should provide it)" >&2
fi

python - <<'PY'
import json
from pathlib import Path
# Lightweight JSON syntax check for tracked manifests (skip huge trees).
roots = [Path("playwright"), Path("webdriver"), Path("video-recorder"), Path(".github")]
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*.json"):
        if "node_modules" in path.parts:
            continue
        json.loads(path.read_text(encoding="utf-8"))
        print(f"json ok: {path}")
PY

run_go_module() {
  local dir="$1"
  local out="$2"
  if [[ -f "$dir/go.mod" ]]; then
    echo "Go tests: $dir"
    (cd "$dir" && go test -coverprofile="$ROOT/$out" -covermode=atomic ./...)
    return 0
  fi
  echo "No go.mod in $dir — skip Go coverage ($out)"
  return 1
}

export GOTOOLCHAIN="${GOTOOLCHAIN:-auto}"
reports=()
if run_go_module playwright/shared/devtools-proxy coverage-playwright.txt; then
  reports+=("coverage-playwright.txt")
fi
if run_go_module webdriver/shared/devtools-proxy coverage-webdriver.txt; then
  reports+=("coverage-webdriver.txt")
fi
if ((${#reports[@]})); then
  IFS=,
  echo "sonar.go.coverage.reportPaths=${reports[*]}" >"$ROOT/sonar-coverage.env"
  unset IFS
else
  rm -f "$ROOT/sonar-coverage.env"
fi
