"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { parseScreenResolution, screenSizeFromEnv } = require("./screen-resolution.cjs");

describe("parseScreenResolution", () => {
  it("parses WxH and WxHxD", () => {
    assert.deepEqual(parseScreenResolution("1920x1080"), { width: 1920, height: 1080 });
    assert.deepEqual(parseScreenResolution("1920x1080x24"), { width: 1920, height: 1080 });
  });

  it("rejects empty and garbage", () => {
    assert.equal(parseScreenResolution(""), null);
    assert.equal(parseScreenResolution("bad"), null);
    assert.equal(parseScreenResolution(undefined), null);
  });
});

describe("screenSizeFromEnv", () => {
  it("defaults to 1920x1080", () => {
    assert.deepEqual(screenSizeFromEnv({}), { width: 1920, height: 1080 });
  });

  it("reads SCREEN_RESOLUTION", () => {
    assert.deepEqual(screenSizeFromEnv({ SCREEN_RESOLUTION: "1280x1024x24" }), {
      width: 1280,
      height: 1024,
    });
  });
});
