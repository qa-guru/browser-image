"use strict";

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
