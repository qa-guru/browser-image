#!/usr/bin/env python3
"""Rewrite Selenoid browsers.json windows + tests properties from pins.json.

Does not touch android. Sliding window = default + regression (warm + min when
the file already has -min entries for that browser).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from copy import deepcopy
from pathlib import Path
from typing import Any

from pin_get import DEFAULT_PINS, load_pins

WD_BROWSERS = ("chrome", "firefox", "msedge")
PW_PREFIX = "playwright-"


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def _template_for(versions: dict[str, Any], suffix: str) -> dict[str, Any] | None:
    for key, value in versions.items():
        if suffix == "" and not key.endswith("-min"):
            return deepcopy(value)
        if suffix == "-min" and key.endswith("-min"):
            return deepcopy(value)
    if suffix == "-min":
        return None
    if versions:
        return deepcopy(next(iter(versions.values())))
    return None


def _set_image(entry: dict[str, Any], image: str) -> dict[str, Any]:
    entry["image"] = image
    return entry


def rewrite_webdriver(catalog: dict[str, Any], pins: dict, browsers: set[str]) -> None:
    for name in WD_BROWSERS:
        if name not in browsers or name not in catalog:
            continue
        pin = pins[name]
        default_maj = int(pin["default_major"])
        regression_maj = int(pin["regression_major"])
        block = catalog[name]
        versions = block.get("versions") or {}
        warm_t = _template_for(versions, "")
        min_t = _template_for(versions, "-min")
        if warm_t is None:
            raise SystemExit(f"{name}: no warm template in catalog")
        new_versions: dict[str, Any] = {}
        for major in (default_maj, regression_maj):
            key = f"{major}.0"
            image = f"qaguru/webdriver-{name}:{major}"
            new_versions[key] = _set_image(deepcopy(warm_t), image)
            if min_t is not None:
                min_key = f"{major}.0-min"
                new_versions[min_key] = _set_image(deepcopy(min_t), f"{image}-min")
        block["default"] = f"{default_maj}.0"
        block["versions"] = new_versions
        log(f"{name}: default {block['default']} window {list(new_versions)}")


def rewrite_playwright(catalog: dict[str, Any], pins: dict) -> None:
    default = str(pins["playwright"]["default"])
    regression = str(pins["playwright"]["regression"])
    for name, block in catalog.items():
        if not name.startswith(PW_PREFIX):
            continue
        versions = block.get("versions") or {}
        warm_t = _template_for(versions, "")
        min_t = _template_for(versions, "-min")
        if warm_t is None:
            raise SystemExit(f"{name}: no template")
        repo = f"qaguru/{name}"
        new_versions: dict[str, Any] = {}
        for ver in (default, regression):
            entry = deepcopy(warm_t)
            entry["image"] = f"{repo}:{ver}"
            if "playwrightVersion" in entry:
                entry["playwrightVersion"] = ver
            new_versions[ver] = entry
            if min_t is not None:
                min_entry = deepcopy(min_t)
                min_entry["image"] = f"{repo}:{ver}-min"
                if "playwrightVersion" in min_entry:
                    min_entry["playwrightVersion"] = ver
                new_versions[f"{ver}-min"] = min_entry
        block["default"] = default
        block["versions"] = new_versions
        log(f"{name}: default {default} + {regression}")


_SHORT_LIST = re.compile(
    r"\[\n( +)(\"[^\"]*\"(?:\n\1\"[^\"]*\")*)\n +\]",
)


def compact_short_lists(text: str) -> str:
    """Keep short string arrays (hosts, env) on one line — matches catalog SSOT."""

    def repl(match: re.Match[str]) -> str:
        items = re.findall(r"\"[^\"]*\"", match.group(2))
        joined = ", ".join(items)
        if len(items) > 4 or len(joined) > 100:
            return match.group(0)
        return "[" + joined + "]"

    return _SHORT_LIST.sub(repl, text)


def dump_json(path: Path, data: dict[str, Any]) -> None:
    text = compact_short_lists(json.dumps(data, indent=2, ensure_ascii=False))
    path.write_text(text + "\n", encoding="utf-8")


def update_catalog_file(path: Path, pins: dict, browsers: set[str]) -> bool:
    before = path.read_text(encoding="utf-8")
    catalog = json.loads(before)
    wd = browsers & set(WD_BROWSERS)
    if wd:
        rewrite_webdriver(catalog, pins, wd)
    if "playwright" in browsers:
        rewrite_playwright(catalog, pins)
    dump_json(path, catalog)
    after = path.read_text(encoding="utf-8")
    return before != after


def patch_jq_scripts(tests_root: Path) -> bool:
    changed = False
    chrome_pair = re.compile(
        r'\.chrome\.versions\["\d+\.0"\]\.image // empty,\s*\n'
        r'\s*\.chrome\.versions\["\d+\.0-min"\]\.image // empty,',
        re.M,
    )
    chrome_repl = (
        ".chrome.versions[.chrome.default].image // empty,\n"
        '    .chrome.versions[(.chrome.default + "-min")].image // empty,'
    )
    pw_pair = re.compile(
        r'\.\["playwright-chromium"\]\.versions\["[\d.]+"\]\.image // empty,\s*\n'
        r'\s*\.\["playwright-chromium"\]\.versions\["[\d.]+-min"\]\.image // empty',
        re.M,
    )
    pw_repl = (
        '.["playwright-chromium"].versions[.["playwright-chromium"].default].image // empty,\n'
        '    .["playwright-chromium"].versions[(.["playwright-chromium"].default + "-min")].image // empty'
    )
    for rel in (
        "scripts/prepare-ci-cm-workspace.sh",
        "scripts/start-ci-selenoid-stack.sh",
    ):
        path = tests_root / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        new = chrome_pair.sub(chrome_repl, text, count=1)
        new = pw_pair.sub(pw_repl, new, count=1)
        if new != text:
            path.write_text(new, encoding="utf-8")
            log(f"jq defaults: {path}")
            changed = True
    return changed


def patch_properties(tests_root: Path, old_pins: dict, new_pins: dict, browsers: set[str]) -> bool:
    cfg = tests_root / "src/test/resources/config"
    if not cfg.is_dir():
        return False
    replacements: list[tuple[str, str]] = []
    if "chrome" in browsers:
        old_m = int(old_pins["chrome"]["default_major"])
        new_m = int(new_pins["chrome"]["default_major"])
        replacements.extend(
            [
                (f"chromeVersion={old_m}.0", f"chromeVersion={new_m}.0"),
                (f"chromeMinVersion={old_m}.0-min", f"chromeMinVersion={new_m}.0-min"),
                (f"browserVersion={old_m}.0-min", f"browserVersion={new_m}.0-min"),
                (f"browserVersion={old_m}.0", f"browserVersion={new_m}.0"),
            ]
        )
    if "firefox" in browsers:
        old_m = int(old_pins["firefox"]["default_major"])
        new_m = int(new_pins["firefox"]["default_major"])
        replacements.extend(
            [
                (f"firefoxVersion={old_m}.0", f"firefoxVersion={new_m}.0"),
                (f"firefoxMinVersion={old_m}.0-min", f"firefoxMinVersion={new_m}.0-min"),
            ]
        )
    if "msedge" in browsers:
        old_m = int(old_pins["msedge"]["default_major"])
        new_m = int(new_pins["msedge"]["default_major"])
        replacements.extend(
            [
                (f"msedgeVersion={old_m}.0", f"msedgeVersion={new_m}.0"),
                (f"msedgeMinVersion={old_m}.0-min", f"msedgeMinVersion={new_m}.0-min"),
            ]
        )
        # Align leftover regression-min pins with default-min when Edge default moves.
        old_reg = int(old_pins["msedge"]["regression_major"])
        replacements.append(
            (f"msedgeMinVersion={old_reg}.0-min", f"msedgeMinVersion={new_m}.0-min")
        )
    if "playwright" in browsers:
        old_v = str(old_pins["playwright"]["default"])
        new_v = str(new_pins["playwright"]["default"])
        replacements.append(
            (f"playwright-chromium/{old_v}", f"playwright-chromium/{new_v}")
        )
        replacements.append(
            (f"playwright-chromium/{old_v}-min", f"playwright-chromium/{new_v}-min")
        )

    changed = False
    for path in sorted(cfg.glob("*.properties")):
        text = path.read_text(encoding="utf-8")
        new = text
        for old, repl in replacements:
            new = new.replace(old, repl)
        if new != text:
            path.write_text(new, encoding="utf-8")
            log(f"properties: {path.name}")
            changed = True
    return changed


def patch_browser_versions_md(path: Path, old_pins: dict, new_pins: dict, browsers: set[str]) -> bool:
    if not path.is_file():
        return False
    text = path.read_text(encoding="utf-8")
    new = text
    if "chrome" in browsers:
        o, n = int(old_pins["chrome"]["default_major"]), int(new_pins["chrome"]["default_major"])
        r_old, r_new = int(old_pins["chrome"]["regression_major"]), int(new_pins["chrome"]["regression_major"])
        new = new.replace(
            f"{o}.0, {o}.0-min, {r_old}.0, {r_old}.0-min",
            f"{n}.0, {n}.0-min, {r_new}.0, {r_new}.0-min",
        )
        new = new.replace(f"Chrome default **{o}.0**", f"Chrome default **{n}.0**")
        new = new.replace(f"| `chrome` | `{o}.0` |", f"| `chrome` | `{n}.0` |")
        new = new.replace(f"**chrome {o}.0**", f"**chrome {n}.0**")
        new = new.replace(f"`qaguru/webdriver-chrome:{o}`", f"`qaguru/webdriver-chrome:{n}`")
        new = new.replace(f":{o}-min", f":{n}-min")
        new = new.replace(f"chrome {o}.0-min", f"chrome {n}.0-min")
        new = new.replace(f"| Selenium Chrome | `chrome` | `{o}.0` |", f"| Selenium Chrome | `chrome` | `{n}.0` |")
    if "firefox" in browsers:
        o, n = int(old_pins["firefox"]["default_major"]), int(new_pins["firefox"]["default_major"])
        r_old, r_new = int(old_pins["firefox"]["regression_major"]), int(new_pins["firefox"]["regression_major"])
        new = new.replace(
            f"{o}.0, {o}.0-min, {r_old}.0, {r_old}.0-min",
            f"{n}.0, {n}.0-min, {r_new}.0, {r_new}.0-min",
        )
        new = new.replace(f"Firefox **{o}.0**", f"Firefox **{n}.0**")
        new = new.replace(f"| `firefox` | `{o}.0` |", f"| `firefox` | `{n}.0` |")
        new = new.replace(f"**firefox {o}.0**", f"**firefox {n}.0**")
        new = new.replace(f"`qaguru/webdriver-firefox:{o}`", f"`qaguru/webdriver-firefox:{n}`")
        new = new.replace(f"| Selenium Firefox | `firefox` | `{o}.0` |", f"| Selenium Firefox | `firefox` | `{n}.0` |")
    if "msedge" in browsers:
        o, n = int(old_pins["msedge"]["default_major"]), int(new_pins["msedge"]["default_major"])
        r_old, r_new = int(old_pins["msedge"]["regression_major"]), int(new_pins["msedge"]["regression_major"])
        new = new.replace(
            f"{o}.0, {o}.0-min, {r_old}.0, {r_old}.0-min",
            f"{n}.0, {n}.0-min, {r_new}.0, {r_new}.0-min",
        )
        new = new.replace(f"Edge **{o}.0**", f"Edge **{n}.0**")
        new = new.replace(f"| `msedge` | `{o}.0` |", f"| `msedge` | `{n}.0` |")
        new = new.replace(f"**msedge {o}.0**", f"**msedge {n}.0**")
        new = new.replace(f"`qaguru/webdriver-msedge:{o}`", f"`qaguru/webdriver-msedge:{n}`")
        new = new.replace(f"| Selenium Edge | `msedge` | `{o}.0` |", f"| Selenium Edge | `msedge` | `{n}.0` |")
    if "playwright" in browsers:
        o, n = old_pins["playwright"]["default"], new_pins["playwright"]["default"]
        r_old, r_new = old_pins["playwright"]["regression"], new_pins["playwright"]["regression"]
        new = new.replace(f"Playwright **{o}**", f"Playwright **{n}**")
        new = new.replace(f"| `playwright-chromium` | `{o}` |", f"| `playwright-chromium` | `{n}` |")
        new = new.replace(f"{o}, {o}-min, {r_old}, {r_old}-min", f"{n}, {n}-min, {r_new}, {r_new}-min")
        new = new.replace(f"**{o}** *(default)*", f"**{n}** *(default)*")
        new = new.replace(f"`playwright-chromium:{o}`", f"`playwright-chromium:{n}`")
        new = new.replace(f"| `@playwright/test` в CI | `playwright-chromium` | `{o}` |", f"| `@playwright/test` в CI | `playwright-chromium` | `{n}` |")
    if new == text:
        log(f"docs unchanged: {path}")
        return False
    path.write_text(new, encoding="utf-8")
    log(f"docs: {path}")
    return True


def browsers_from_plan(plan: dict[str, Any] | None) -> set[str]:
    if not plan:
        return set(WD_BROWSERS) | {"playwright"}
    names = {c["browser"] for c in plan.get("changes") or [] if c.get("catalog")}
    return names


def cmd_self_check() -> int:
    failures = 0

    def check(name: str, cond: bool) -> None:
        nonlocal failures
        if cond:
            log(f"ok {name}")
        else:
            log(f"FAIL {name}")
            failures += 1

    catalog = {
        "chrome": {
            "default": "152.0",
            "versions": {
                "152.0": {"image": "qaguru/webdriver-chrome:152", "port": "4444"},
                "152.0-min": {"image": "qaguru/webdriver-chrome:152-min", "port": "4444"},
                "151.0": {"image": "qaguru/webdriver-chrome:151", "port": "4444"},
                "151.0-min": {"image": "qaguru/webdriver-chrome:151-min", "port": "4444"},
            },
        },
        "android": {"default": "16.0", "versions": {"16.0": {"image": "qaguru/android:16"}}},
        "playwright-chromium": {
            "default": "1.62.1",
            "versions": {
                "1.62.1": {"image": "qaguru/playwright-chromium:1.62.1", "playwrightVersion": "1.62.1"},
                "1.62.1-min": {"image": "qaguru/playwright-chromium:1.62.1-min", "playwrightVersion": "1.62.1"},
                "1.61.1": {"image": "qaguru/playwright-chromium:1.61.1", "playwrightVersion": "1.61.1"},
            },
        },
    }
    pins = {
        "chrome": {"default_major": 153, "regression_major": 152, "versions": {"153": "x", "152": "y"}},
        "firefox": {"default_major": 154, "regression_major": 153},
        "msedge": {"default_major": 151, "regression_major": 150},
        "playwright": {"default": "1.63.0", "regression": "1.62.1"},
    }
    rewrite_webdriver(catalog, pins, {"chrome"})
    rewrite_playwright(catalog, pins)
    check("chrome default 153", catalog["chrome"]["default"] == "153.0")
    check("dropped 151", "151.0" not in catalog["chrome"]["versions"])
    check("kept 152", "152.0" in catalog["chrome"]["versions"])
    check("android untouched", catalog["android"]["default"] == "16.0")
    check("pw default", catalog["playwright-chromium"]["default"] == "1.63.0")
    check("pw min", "1.63.0-min" in catalog["playwright-chromium"]["versions"])
    check("pw dropped 1.61.1", "1.61.1" not in catalog["playwright-chromium"]["versions"])
    dumped = compact_short_lists(
        json.dumps(
            {
                "hosts": ["host.docker.internal:host-gateway"],
                "env": ["SCREEN_RESOLUTION=2100x2100x24"],
            },
            indent=2,
            ensure_ascii=False,
        )
    )
    check("hosts compact", '"hosts": ["host.docker.internal:host-gateway"]' in dumped)
    check("env compact", '"env": ["SCREEN_RESOLUTION=2100x2100x24"]' in dumped)
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pins", default=str(DEFAULT_PINS))
    parser.add_argument("--plan", default="")
    parser.add_argument("--file", action="append", default=[], help="browsers.json path (repeatable)")
    parser.add_argument("--tests-root", default="")
    parser.add_argument("--docs", default="")
    parser.add_argument("--browsers", default="", help="comma list; default from --plan catalog changes")
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args(argv)
    if args.self_check:
        return cmd_self_check()

    pins = load_pins(Path(args.pins))
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8")) if args.plan else None
    old_pins = (plan or {}).get("pins") or pins
    new_pins = (plan or {}).get("desired") or pins
    if args.browsers:
        browsers = {b.strip() for b in args.browsers.split(",") if b.strip()}
    else:
        browsers = browsers_from_plan(plan)
    if not browsers:
        log("update_catalog: no catalog browsers in plan")
        return 0

    changed = False
    for raw in args.file:
        path = Path(raw)
        if not path.is_file():
            log(f"missing catalog: {path}")
            return 1
        if update_catalog_file(path, new_pins, browsers):
            changed = True
            log(f"updated {path}")
        else:
            log(f"unchanged {path}")
    if args.tests_root:
        tests = Path(args.tests_root)
        if patch_jq_scripts(tests):
            changed = True
        if patch_properties(tests, old_pins, new_pins, browsers):
            changed = True
    if args.docs:
        if patch_browser_versions_md(Path(args.docs), old_pins, new_pins, browsers):
            changed = True
    if not args.file and not args.tests_root and not args.docs:
        parser.error("need --file, --tests-root, --docs, or --self-check")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
