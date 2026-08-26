"use strict";

/** Chromium on Xvfb ignores --window-size without a WM; --start-maximized needs fluxbox. */
function chromiumHeadedArgs(screenSize) {
  const args = ["--remote-debugging-port=0", "--window-position=0,0", "--start-maximized"];
  if (screenSize && screenSize.width && screenSize.height) {
    args.splice(1, 0, `--window-size=${screenSize.width},${screenSize.height}`);
  }
  return args;
}

function firefoxHeadedArgs(screenSize) {
  if (!screenSize || !screenSize.width || !screenSize.height) {
    return [];
  }
  return ["-width", String(screenSize.width), "-height", String(screenSize.height)];
}

/**
 * Extra CLI args for launchServer / launch. WebKit ignores `args`.
 * extraChromium is prepended (sandbox, gpu, …).
 */
function headedLaunchArgs(browserTypeName, screenSize, extraChromium = []) {
  if (browserTypeName === "chromium") {
    return [...extraChromium, ...chromiumHeadedArgs(screenSize)];
  }
  if (browserTypeName === "firefox") {
    return firefoxHeadedArgs(screenSize);
  }
  return [];
}

function playwrightWsEndpoint(env = process.env) {
  if (typeof env.PW_WS_ENDPOINT === "string" && env.PW_WS_ENDPOINT.length > 0) {
    return env.PW_WS_ENDPOINT;
  }
  const port = env.PW_PORT || "3000";
  let path = env.PW_PATH || "/";
  if (!path.startsWith("/")) {
    path = `/${path}`;
  }
  return `ws://127.0.0.1:${port}${path}`;
}

module.exports = {
  chromiumHeadedArgs,
  firefoxHeadedArgs,
  headedLaunchArgs,
  playwrightWsEndpoint,
};
