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

module.exports = { chromiumHeadedArgs, firefoxHeadedArgs };
