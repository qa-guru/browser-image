"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { chromiumHeadedArgs, firefoxHeadedArgs, headedLaunchArgs, playwrightWsEndpoint } = require("./headed-window.cjs");

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

  it("hides fbsetbg xmessage so it is not maximized over the browser", () => {
    assert.match(rules, /\[app\] \(name=xmessage\)[\s\S]*\[Hidden\] \{yes\}/);
  });
});

describe("headedLaunchArgs", () => {
  it("prefixes Chromium sandbox flags", () => {
    assert.deepEqual(headedLaunchArgs("chromium", { width: 800, height: 600 }, ["--no-sandbox"]), [
      "--no-sandbox",
      "--remote-debugging-port=0",
      "--window-size=800,600",
      "--window-position=0,0",
      "--start-maximized",
    ]);
  });

  it("sizes Firefox and ignores WebKit args", () => {
    assert.deepEqual(headedLaunchArgs("firefox", { width: 1920, height: 1080 }), ["-width", "1920", "-height", "1080"]);
    assert.deepEqual(headedLaunchArgs("webkit", { width: 1920, height: 1080 }), []);
  });
});

describe("playwrightWsEndpoint", () => {
  it("defaults to loopback launchServer path", () => {
    assert.equal(playwrightWsEndpoint({ PW_PORT: "3000", PW_PATH: "/" }), "ws://127.0.0.1:3000/");
    assert.equal(playwrightWsEndpoint({ PW_WS_ENDPOINT: "ws://127.0.0.1:9/guid" }), "ws://127.0.0.1:9/guid");
  });
});
