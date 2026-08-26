#!/usr/bin/env python3
"""Lookup dotted keys in pins.json. Usage: pin_get.py [pins.json] chrome.default_major"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PINS = REPO_ROOT / "pins.json"


def load_pins(path: Path | None = None) -> dict:
    pins_path = path or DEFAULT_PINS
    with pins_path.open(encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise SystemExit(f"pins.json must be an object: {pins_path}")
    return data


def save_pins(data: dict, path: Path | None = None) -> None:
    pins_path = path or DEFAULT_PINS
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    pins_path.write_text(text, encoding="utf-8")


def lookup(data: dict, path: str):
    cur: object = data
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            raise KeyError(path)
        cur = cur[part]
    return cur


def format_value(value: object) -> str:
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def main(argv: list[str]) -> int:
    args = list(argv)
    pins_path = DEFAULT_PINS
    if args and args[0].endswith(".json") and Path(args[0]).is_file():
        pins_path = Path(args.pop(0))
    if len(args) != 1:
        print("Usage: pin_get.py [pins.json] dotted.key", file=sys.stderr)
        return 2
    try:
        value = lookup(load_pins(pins_path), args[0])
    except KeyError:
        print(f"missing pin key: {args[0]}", file=sys.stderr)
        return 1
    print(format_value(value))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
