"use strict";

/** Parse `1920x1080` / `1920x1080x24` from SCREEN_RESOLUTION. */
function parseScreenResolution(value) {
  if (typeof value !== "string" || value.length === 0) {
    return null;
  }
  const match = /^(\d+)x(\d+)(?:x\d+)?$/.exec(value.trim());
  if (!match) {
    return null;
  }
  return { width: Number(match[1]), height: Number(match[2]) };
}

function screenSizeFromEnv(env = process.env) {
  return parseScreenResolution(env.SCREEN_RESOLUTION) || { width: 1920, height: 1080 };
}

module.exports = { parseScreenResolution, screenSizeFromEnv };
