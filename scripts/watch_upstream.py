#!/usr/bin/env python3
"""Watch upstream browser stables and diff against pins.json.

Commands:
  resolve     fetch upstream, print plan (human or --json)
  apply-pins  write pins.json from a plan
  tags        print tag operations (recreate|create tag)
  wait-hub    poll Docker Hub until published tags exist (new or rebuilt)
  self-check  offline unit checks

Exit: 0 ok/noop · 1 apply/hub/git failure · 2 usage/network
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

from pin_get import DEFAULT_PINS, REPO_ROOT, load_pins, save_pins

UA = "qaguru-browser-watch/1.0"
CFT_LKG = "https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json"
CFT_ZIP = "https://storage.googleapis.com/chrome-for-testing-public/{ver}/linux64/chrome-linux64.zip"
CFT_DRIVER = "https://storage.googleapis.com/chrome-for-testing-public/{ver}/linux64/chromedriver-linux64.zip"
FF_VERSIONS = "https://product-details.mozilla.org/1.0/firefox_versions.json"
FF_TARBALL = (
    "https://ftp.mozilla.org/pub/firefox/releases/{ver}/linux-x86_64/en-US/firefox-{ver}.tar.xz"
)
NPM_PW_LATEST = "https://registry.npmjs.org/@playwright/test/latest"
MCR_TAGS = "https://mcr.microsoft.com/v2/playwright/tags/list"
EDGE_PACKAGES = (
    "https://packages.microsoft.com/repos/edge/dists/stable/main/binary-amd64/Packages"
)
EDGE_DEB = (
    "https://packages.microsoft.com/repos/edge/pool/main/m/"
    "microsoft-edge-stable/microsoft-edge-stable_{deb}_amd64.deb"
)
EDGE_DRIVER = "https://msedgedriver.microsoft.com/{ver}/edgedriver_linux64.zip"
HUB_TAG = "https://hub.docker.com/v2/repositories/qaguru/{repo}/tags/{tag}"

WD_ARCHS = {"chrome": 2, "firefox": 2, "msedge": 1}
PW_ARCHS = {
    "chromium": 2,
    "firefox": 2,
    "webkit": 2,
    "chrome": 1,
    "msedge": 1,
}


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def http_get(url: str, timeout: int = 45) -> tuple[int, bytes]:
    with tempfile.NamedTemporaryFile() as tmp:
        proc = subprocess.run(
            [
                "curl",
                "-sS",
                "-L",
                "--max-time",
                str(timeout),
                "-A",
                UA,
                "-o",
                tmp.name,
                "-w",
                "%{http_code}",
                url,
            ],
            capture_output=True,
            text=True,
        )
        code_s = (proc.stdout or "").strip()
        try:
            code = int(code_s)
        except ValueError:
            code = 0
        body = Path(tmp.name).read_bytes()
        if proc.returncode not in (0, 22) and code == 0:
            err = (proc.stderr or "").strip()
            raise RuntimeError(f"curl {url}: rc={proc.returncode} {err}")
        return code, body


def http_head_ok(url: str, timeout: int = 30) -> bool:
    proc = subprocess.run(
        [
            "curl",
            "-sS",
            "-I",
            "-L",
            "--max-time",
            str(timeout),
            "-A",
            UA,
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            url,
        ],
        capture_output=True,
        text=True,
    )
    try:
        code = int((proc.stdout or "").strip())
    except ValueError:
        return False
    return 200 <= code < 400


def http_json(url: str, timeout: int = 45) -> Any:
    code, body = http_get(url, timeout=timeout)
    if code != 200:
        raise RuntimeError(f"GET {url} → HTTP {code}")
    return json.loads(body.decode("utf-8"))


def parse_major(version: str) -> int:
    return int(version.split(".", 1)[0])


def version_tuple(version: str) -> tuple[int, ...]:
    core = version.split("-", 1)[0]
    parts = []
    for piece in core.split("."):
        if piece.isdigit():
            parts.append(int(piece))
        else:
            break
    return tuple(parts or (0,))


def semver_tuple(version: str) -> tuple[int, int, int]:
    raw = version.split("-", 1)[0]
    bits = raw.split(".")
    nums = [int(b) for b in bits[:3] if b.isdigit()]
    while len(nums) < 3:
        nums.append(0)
    return nums[0], nums[1], nums[2]


# --- upstream resolvers -------------------------------------------------

def resolve_chrome() -> dict[str, Any]:
    lkg = http_json(CFT_LKG)
    stable = (lkg.get("channels") or {}).get("Stable") or {}
    version = str(stable.get("version") or "")
    if not version or parse_major(version) < 100:
        raise RuntimeError(f"CFT Stable missing/invalid: {stable!r}")
    major = parse_major(version)
    return {"major": major, "version": version}


def resolve_firefox() -> dict[str, Any]:
    data = http_json(FF_VERSIONS)
    latest = str(data.get("LATEST_FIREFOX_VERSION") or "")
    if not latest:
        raise RuntimeError(f"firefox_versions.json missing LATEST_FIREFOX_VERSION: {data!r}")
    major = parse_major(latest)
    if not http_head_ok(FF_TARBALL.format(ver=latest)):
        raise RuntimeError(f"Firefox tarball missing for {latest}")
    return {"major": major, "version": latest}


def parse_edge_debs(body: bytes) -> list[str]:
    pkg = None
    found: list[str] = []
    for line in body.decode("utf-8", "replace").splitlines():
        if line.startswith("Package: "):
            pkg = line.split(": ", 1)[1].strip()
        elif line.startswith("Version: ") and pkg == "microsoft-edge-stable":
            found.append(line.split(": ", 1)[1].strip())
        elif not line:
            pkg = None
    uniq = sorted(set(found), key=version_tuple, reverse=True)
    return uniq


def resolve_edge() -> dict[str, Any]:
    code, body = http_get(EDGE_PACKAGES, timeout=60)
    if code != 200:
        raise RuntimeError(f"Edge Packages HTTP {code}")
    debs = parse_edge_debs(body)
    if not debs:
        raise RuntimeError("no microsoft-edge-stable in Packages")
    latest_deb = debs[0]
    latest = latest_deb.split("-", 1)[0]
    major = parse_major(latest)
    return {"major": major, "version": latest, "deb": latest_deb}


def resolve_playwright() -> dict[str, Any]:
    data = http_json(NPM_PW_LATEST)
    latest = str(data.get("version") or "")
    if not latest or "-" in latest:
        raise RuntimeError(f"npm @playwright/test latest not a stable semver: {latest!r}")
    return {"version": latest, "mcr_tag": f"v{latest}-noble"}


def mcr_has_noble(version: str) -> bool:
    data = http_json(MCR_TAGS, timeout=90)
    tags = data.get("tags") if isinstance(data, dict) else data
    if not isinstance(tags, list):
        raise RuntimeError("MCR tags/list: unexpected shape")
    return f"v{version}-noble" in tags


def chrome_artifacts_ok(cft: str) -> bool:
    return http_head_ok(CFT_ZIP.format(ver=cft)) and http_head_ok(CFT_DRIVER.format(ver=cft))


def edge_artifacts_ok(version: str, deb: str) -> bool:
    return http_head_ok(EDGE_DEB.format(deb=deb)) and http_head_ok(EDGE_DRIVER.format(ver=version))


# --- plan ---------------------------------------------------------------

def _wd_tags(browser: str, major: int) -> list[str]:
    return [f"webdriver/{browser}-{major}", f"webdriver/{browser}-{major}-min"]


def _wd_hub(browser: str, major: int) -> list[dict[str, Any]]:
    arches = WD_ARCHS[browser]
    repo = f"webdriver-{browser}"
    return [
        {"repo": repo, "tag": str(major), "min_archs": arches},
        {"repo": repo, "tag": f"{major}-min", "min_archs": arches},
    ]


def _pw_tags(version: str) -> list[str]:
    return [f"playwright/{version}", f"playwright/{version}-min"]


def _pw_hub(version: str) -> list[dict[str, Any]]:
    images = []
    for name, arches in PW_ARCHS.items():
        images.append({"repo": f"playwright-{name}", "tag": version, "min_archs": arches})
    images.append({"repo": "playwright-chromium", "tag": f"{version}-min", "min_archs": 2})
    return images


def plan_chrome(pins: dict, upstream: dict, errors: list[str]) -> dict[str, Any] | None:
    pin = pins["chrome"]
    pin_def = int(pin["default_major"])
    pin_ver = str(pin["versions"][str(pin_def)])
    up_maj, up_ver = int(upstream["major"]), str(upstream["version"])
    if up_maj < pin_def:
        log(f"chrome: skip downgrade pin {pin_def} ← upstream {up_maj}")
        return None
    if up_maj == pin_def and up_ver == pin_ver:
        log(f"chrome: pin {pin_def} ({pin_ver}) = CFT Stable — ok")
        return None
    if not chrome_artifacts_ok(up_ver):
        errors.append(f"chrome: CFT artifacts 404 for {up_ver} (breaking CfT gate)")
        return None
    change: dict[str, Any] = {
        "browser": "chrome",
        "old": {"major": pin_def, "version": pin_ver},
        "new": {"major": up_maj, "version": up_ver},
        "tags": _wd_tags("chrome", up_maj),
        "hub_images": _wd_hub("chrome", up_maj),
    }
    if up_maj == pin_def:
        change["kind"] = "patch"
        change["rebuild_existing"] = True
        change["catalog"] = False
        log(f"chrome: CFT patch {pin_ver} → {up_ver} (rebuild :{up_maj})")
    else:
        prev_ver = str(pin["versions"][str(pin_def)])
        if not chrome_artifacts_ok(prev_ver):
            log(f"warn: chrome regression {pin_def} artifacts missing ({prev_ver})")
        change["kind"] = "major"
        change["rebuild_existing"] = False
        change["catalog"] = True
        log(f"chrome: major {pin_def} → {up_maj} (regression {pin_def})")
    return change


def plan_firefox(pins: dict, upstream: dict, errors: list[str]) -> dict[str, Any] | None:
    pin = pins["firefox"]
    pin_def = int(pin["default_major"])
    pin_ver = str(pin["versions"][str(pin_def)])
    up_maj, up_ver = int(upstream["major"]), str(upstream["version"])
    if up_maj < pin_def:
        log(f"firefox: skip downgrade pin {pin_def} ← upstream {up_maj}")
        return None
    if up_maj == pin_def and up_ver == pin_ver:
        log(f"firefox: pin {pin_def} ({pin_ver}) = latest — ok")
        return None
    if not http_head_ok(FF_TARBALL.format(ver=up_ver)):
        errors.append(f"firefox: FTP tarball missing for {up_ver}")
        return None
    change: dict[str, Any] = {
        "browser": "firefox",
        "old": {"major": pin_def, "version": pin_ver},
        "new": {"major": up_maj, "version": up_ver},
        "tags": _wd_tags("firefox", up_maj),
        "hub_images": _wd_hub("firefox", up_maj),
    }
    if up_maj == pin_def:
        change["kind"] = "patch"
        change["rebuild_existing"] = True
        change["catalog"] = False
        log(f"firefox: patch {pin_ver} → {up_ver} (rebuild :{up_maj})")
    else:
        change["kind"] = "major"
        change["rebuild_existing"] = False
        change["catalog"] = True
        log(f"firefox: major {pin_def} → {up_maj} (regression {pin_def})")
    return change


def plan_msedge(pins: dict, upstream: dict, errors: list[str]) -> dict[str, Any] | None:
    pin = pins["msedge"]
    pin_def = int(pin["default_major"])
    pin_ver = str(pin["versions"][str(pin_def)])
    up_maj, up_ver = int(upstream["major"]), str(upstream["version"])
    up_deb = str(upstream["deb"])
    if up_maj < pin_def:
        log(f"msedge: skip downgrade pin {pin_def} ← upstream {up_maj}")
        return None
    if up_maj == pin_def and up_ver == pin_ver:
        log(f"msedge: pin {pin_def} ({pin_ver}) = stable amd64 — ok")
        return None
    if not edge_artifacts_ok(up_ver, up_deb):
        errors.append(f"msedge: deb/driver missing for {up_ver} ({up_deb})")
        return None
    change: dict[str, Any] = {
        "browser": "msedge",
        "old": {"major": pin_def, "version": pin_ver},
        "new": {"major": up_maj, "version": up_ver, "deb": up_deb},
        "tags": _wd_tags("msedge", up_maj),
        "hub_images": _wd_hub("msedge", up_maj),
    }
    if up_maj == pin_def:
        change["kind"] = "patch"
        change["rebuild_existing"] = True
        change["catalog"] = False
        log(f"msedge: patch {pin_ver} → {up_ver} (rebuild :{up_maj}, amd64)")
    else:
        change["kind"] = "major"
        change["rebuild_existing"] = False
        change["catalog"] = True
        log(f"msedge: major {pin_def} → {up_maj} (regression {pin_def})")
    return change


def plan_playwright(pins: dict, upstream: dict, errors: list[str]) -> dict[str, Any] | None:
    pin = pins["playwright"]
    pin_def = str(pin["default"])
    up_ver = str(upstream["version"])
    if semver_tuple(up_ver) < semver_tuple(pin_def):
        log(f"playwright: skip downgrade pin {pin_def} ← npm {up_ver}")
        return None
    if up_ver == pin_def:
        log(f"playwright: pin {pin_def} = npm latest — ok")
        return None
    if not mcr_has_noble(up_ver):
        errors.append(f"playwright: MCR tag v{up_ver}-noble missing")
        return None
    log(f"playwright: {pin_def} → {up_ver} (regression {pin_def})")
    return {
        "browser": "playwright",
        "kind": "major",
        "rebuild_existing": False,
        "catalog": True,
        "old": {"version": pin_def},
        "new": {"version": up_ver},
        "tags": _pw_tags(up_ver),
        "hub_images": _pw_hub(up_ver),
    }


def apply_change_to_pins(pins: dict, change: dict[str, Any]) -> None:
    browser = change["browser"]
    if browser == "playwright":
        old_def = pins["playwright"]["default"]
        pins["playwright"]["regression"] = old_def
        pins["playwright"]["default"] = change["new"]["version"]
        return
    block = pins[browser]
    old_def = int(block["default_major"])
    new_maj = int(change["new"]["major"])
    new_ver = str(change["new"]["version"])
    if change["kind"] == "patch":
        block["versions"][str(new_maj)] = new_ver
        if browser == "msedge":
            block["deb_versions"][str(new_maj)] = str(change["new"].get("deb") or f"{new_ver}-1")
        return
    old_ver = str(block["versions"][str(old_def)])
    block["default_major"] = new_maj
    block["regression_major"] = old_def
    block["versions"] = {str(new_maj): new_ver, str(old_def): old_ver}
    if browser == "msedge":
        old_deb = str(block.get("deb_versions", {}).get(str(old_def), f"{old_ver}-1"))
        new_deb = str(change["new"].get("deb") or f"{new_ver}-1")
        block["deb_versions"] = {str(new_maj): new_deb, str(old_def): old_deb}


def build_plan(pins: dict, only: set[str] | None) -> dict[str, Any]:
    errors: list[str] = []
    changes: list[dict[str, Any]] = []
    upstream: dict[str, Any] = {}
    wanted = only or {"chrome", "firefox", "msedge", "playwright"}

    if "chrome" in wanted:
        upstream["chrome"] = resolve_chrome()
        ch = plan_chrome(pins, upstream["chrome"], errors)
        if ch:
            changes.append(ch)
    if "firefox" in wanted:
        upstream["firefox"] = resolve_firefox()
        ch = plan_firefox(pins, upstream["firefox"], errors)
        if ch:
            changes.append(ch)
    if "msedge" in wanted:
        upstream["msedge"] = resolve_edge()
        ch = plan_msedge(pins, upstream["msedge"], errors)
        if ch:
            changes.append(ch)
    if "playwright" in wanted:
        upstream["playwright"] = resolve_playwright()
        ch = plan_playwright(pins, upstream["playwright"], errors)
        if ch:
            changes.append(ch)

    desired = json.loads(json.dumps(pins))
    for change in changes:
        apply_change_to_pins(desired, change)

    need_catalog = any(c.get("catalog") for c in changes)
    need_publish = bool(changes)
    need_pull = need_publish and not need_catalog
    noop = not changes and not errors
    return {
        "noop": noop,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pins": pins,
        "desired": desired,
        "upstream": upstream,
        "changes": changes,
        "need_catalog": need_catalog,
        "need_publish": need_publish,
        "need_pull": need_pull,
        "errors": errors,
    }


def cmd_resolve(args: argparse.Namespace) -> int:
    pins = load_pins(Path(args.pins))
    only = {args.browser} if args.browser != "all" else None
    try:
        plan = build_plan(pins, only)
    except RuntimeError as exc:
        log(f"resolve failed: {exc}")
        return 2
    if args.json:
        json.dump(plan, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        if plan["noop"]:
            print("noop: pins already match upstream stables")
        else:
            print(f"changes: {len(plan['changes'])}")
            for change in plan["changes"]:
                print(
                    f"  {change['browser']}: {change['kind']} "
                    f"tags={','.join(change['tags'])} catalog={change['catalog']}"
                )
        if plan["errors"]:
            print("errors:")
            for err in plan["errors"]:
                print(f"  {err}")
    if plan["errors"] and not plan["changes"]:
        return 1
    return 0


def cmd_apply_pins(args: argparse.Namespace) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    if plan.get("noop") or not plan.get("changes"):
        log("apply-pins: nothing to write")
        return 0
    save_pins(plan["desired"], Path(args.pins))
    log(f"wrote {args.pins}")
    return 0


def cmd_tags(args: argparse.Namespace) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    for change in plan.get("changes") or []:
        action = "recreate" if change.get("rebuild_existing") else "create"
        for tag in change.get("tags") or []:
            print(f"{action} {tag}")
    return 0


def hub_tag_info(repo: str, tag: str) -> dict[str, Any] | None:
    url = HUB_TAG.format(repo=quote(repo, safe=""), tag=quote(tag, safe=""))
    code, body = http_get(url, timeout=30)
    if code == 404:
        return None
    if code != 200:
        raise RuntimeError(f"Hub {repo}:{tag} HTTP {code}")
    data = json.loads(body.decode("utf-8"))
    images = data.get("images") or []
    archs = [
        img.get("architecture")
        for img in images
        if img.get("architecture") and img.get("architecture") != "unknown"
    ]
    return {
        "last_updated": data.get("last_updated") or "",
        "digest": data.get("digest") or "",
        "archs": archs,
        "n_archs": len(archs),
    }


def snapshot_hub(plan: dict[str, Any]) -> dict[str, dict[str, Any] | None]:
    snap: dict[str, dict[str, Any] | None] = {}
    for change in plan.get("changes") or []:
        for img in change.get("hub_images") or []:
            key = f"{img['repo']}:{img['tag']}"
            snap[key] = hub_tag_info(img["repo"], img["tag"])
    return snap


def hub_ready(img: dict[str, Any], before: dict[str, Any] | None) -> bool:
    info = hub_tag_info(img["repo"], img["tag"])
    if info is None:
        return False
    if info["n_archs"] < int(img.get("min_archs") or 1):
        return False
    if before is None:
        return True
    if info.get("last_updated") and info["last_updated"] > (before.get("last_updated") or ""):
        return True
    if info.get("digest") and before.get("digest") and info["digest"] != before["digest"]:
        return True
    return False


def cmd_wait_hub(args: argparse.Namespace) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    images: list[dict[str, Any]] = []
    for change in plan.get("changes") or []:
        images.extend(change.get("hub_images") or [])
    if not images:
        log("wait-hub: no images")
        return 0
    snap_path = Path(args.snapshot) if args.snapshot else None
    if snap_path and snap_path.is_file():
        before = json.loads(snap_path.read_text(encoding="utf-8"))
    else:
        before = snapshot_hub(plan)
    deadline = time.time() + args.timeout
    pending = {f"{i['repo']}:{i['tag']}": i for i in images}
    log(f"wait-hub: {len(pending)} tags, timeout {args.timeout}s")
    while pending and time.time() < deadline:
        done = []
        with ThreadPoolExecutor(max_workers=min(8, len(pending))) as pool:
            futs = {
                pool.submit(hub_ready, img, before.get(key)): key
                for key, img in pending.items()
            }
            for fut in as_completed(futs):
                key = futs[fut]
                try:
                    ok = fut.result()
                except RuntimeError as exc:
                    log(f"wait-hub {key}: {exc}")
                    ok = False
                if ok:
                    log(f"hub 200 {key}")
                    done.append(key)
        for key in done:
            pending.pop(key, None)
        if pending:
            time.sleep(args.interval)
    if pending:
        log("wait-hub timeout: " + ", ".join(sorted(pending)))
        return 1
    log("wait-hub: all tags ready")
    return 0


def cmd_snapshot_hub(args: argparse.Namespace) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    snap = snapshot_hub(plan)
    json.dump(snap, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


def cmd_force_catalog_plan(args: argparse.Namespace) -> int:
    """Synthetic plan: rewrite catalogs from current pins, no publish."""
    pins = load_pins(Path(args.pins))
    changes = []
    for browser in ("chrome", "firefox", "msedge"):
        block = pins[browser]
        major = int(block["default_major"])
        changes.append(
            {
                "browser": browser,
                "kind": "major",
                "rebuild_existing": False,
                "catalog": True,
                "old": {"major": major, "version": block["versions"][str(major)]},
                "new": {"major": major, "version": block["versions"][str(major)]},
                "tags": [],
                "hub_images": [],
            }
        )
    pw = pins["playwright"]
    changes.append(
        {
            "browser": "playwright",
            "kind": "major",
            "rebuild_existing": False,
            "catalog": True,
            "old": {"version": pw["default"]},
            "new": {"version": pw["default"]},
            "tags": [],
            "hub_images": [],
        }
    )
    plan = {
        "noop": False,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pins": pins,
        "desired": pins,
        "upstream": {},
        "changes": changes,
        "need_catalog": True,
        "need_publish": False,
        "need_pull": False,
        "errors": [],
        "force_catalog": True,
    }
    json.dump(plan, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


def cmd_self_check() -> int:
    failures = 0

    def check(name: str, cond: bool) -> None:
        nonlocal failures
        if cond:
            log(f"ok {name}")
        else:
            log(f"FAIL {name}")
            failures += 1

    pins = {
        "chrome": {
            "default_major": 152,
            "regression_major": 151,
            "versions": {"152": "152.0.1", "151": "151.0.1"},
        },
        "firefox": {
            "default_major": 154,
            "regression_major": 153,
            "geckodriver": "0.37.1",
            "versions": {"154": "154.0.1", "153": "153.0.1"},
        },
        "msedge": {
            "default_major": 151,
            "regression_major": 150,
            "versions": {"151": "151.0.1", "150": "150.0.1"},
            "deb_versions": {"151": "151.0.1-1", "150": "150.0.1-1"},
        },
        "playwright": {"default": "1.62.1", "regression": "1.61.1", "mcr_distro": "noble"},
    }
    ch_major = {
        "browser": "chrome",
        "kind": "major",
        "new": {"major": 153, "version": "153.0.9"},
    }
    desired = json.loads(json.dumps(pins))
    apply_change_to_pins(desired, ch_major)
    check("chrome window default", desired["chrome"]["default_major"] == 153)
    check("chrome window regression", desired["chrome"]["regression_major"] == 152)
    check("chrome dropped 151", "151" not in desired["chrome"]["versions"])
    check("chrome kept 152", desired["chrome"]["versions"]["152"] == "152.0.1")

    ch_patch = {
        "browser": "chrome",
        "kind": "patch",
        "new": {"major": 152, "version": "152.0.9"},
    }
    desired2 = json.loads(json.dumps(pins))
    apply_change_to_pins(desired2, ch_patch)
    check("chrome patch keeps majors", desired2["chrome"]["default_major"] == 152)
    check("chrome patch version", desired2["chrome"]["versions"]["152"] == "152.0.9")

    apply_change_to_pins(desired, {"browser": "playwright", "new": {"version": "1.63.0"}})
    check("pw default", desired["playwright"]["default"] == "1.63.0")
    check("pw regression old default", desired["playwright"]["regression"] == "1.62.1")

    debs = parse_edge_debs(
        b"Package: microsoft-edge-stable\nVersion: 150.0.1-1\n\n"
        b"Package: microsoft-edge-stable\nVersion: 151.0.4129.107-1\n\n"
        b"Package: other\nVersion: 999.0.0-1\n\n"
    )
    check("edge max", debs[0] == "151.0.4129.107-1")
    check("no downgrade tuple", semver_tuple("1.61.1") < semver_tuple("1.62.1"))
    return 1 if failures else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pins", default=str(DEFAULT_PINS))
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_resolve = sub.add_parser("resolve")
    p_resolve.add_argument("--json", action="store_true")
    p_resolve.add_argument("--browser", default="all", choices=["all", "chrome", "firefox", "msedge", "playwright"])

    p_apply = sub.add_parser("apply-pins")
    p_apply.add_argument("--plan", required=True)

    p_tags = sub.add_parser("tags")
    p_tags.add_argument("--plan", required=True)

    p_snap = sub.add_parser("snapshot-hub")
    p_snap.add_argument("--plan", required=True)

    p_wait = sub.add_parser("wait-hub")
    p_wait.add_argument("--plan", required=True)
    p_wait.add_argument("--snapshot", default="")
    p_wait.add_argument("--timeout", type=int, default=2700)
    p_wait.add_argument("--interval", type=int, default=20)

    sub.add_parser("self-check")
    sub.add_parser("force-catalog-plan")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "resolve":
        return cmd_resolve(args)
    if args.cmd == "apply-pins":
        return cmd_apply_pins(args)
    if args.cmd == "tags":
        return cmd_tags(args)
    if args.cmd == "snapshot-hub":
        return cmd_snapshot_hub(args)
    if args.cmd == "wait-hub":
        return cmd_wait_hub(args)
    if args.cmd == "self-check":
        return cmd_self_check()
    if args.cmd == "force-catalog-plan":
        return cmd_force_catalog_plan(args)
    parser.error("unknown command")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
