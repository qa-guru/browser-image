"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { chromiumHeadedArgs, firefoxHeadedArgs } = require("./headed-window.cjs");

describe("chromiumHeadedArgs", () => {
  it("maximizes and pins origin; window-size matches Xvfb", () => {
    assert.deepEqual(chromiumHeadedArgs({ width: 1920, height: 1080 }), [
      "--remote-debugging-port=0",
      "--window-size=1920,1080",
      "--window-position=0,0",
      "--start-maximized",
    ]);
  });
});

describe("firefoxHeadedArgs", () => {
  it("passes width/height", () => {
    assert.deepEqual(firefoxHeadedArgs({ width: 1280, height: 1024 }), ["-width", "1280", "-height", "1024"]);
  });
});

describe("fluxbox.apps", () => {
  const apps = fs.readFileSync(path.join(__dirname, "fluxbox.apps"), "utf8");
  const rules = apps
    .split("\n")
    .filter((line) => !/^\s*#/.test(line))
    .join("\n");

  it("uses glob * so Unnamed/Firefox titles match (.* is regex and misses them)", () => {
    assert.match(rules, /\[app\] \(name=\*\)/);
    assert.equal((rules.match(/\(name=\.\*\)/) || []).length, 0);
    assert.match(rules, /\[Deco\] \{NONE\}/);
    assert.match(rules, /\[Maximized\] \{yes\}/);
  });
});
