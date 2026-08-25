const { chromium, firefox, webkit } = require("playwright-core");
const { screenSizeFromEnv } = require("./screen-resolution.cjs");
const { chromiumHeadedArgs, firefoxHeadedArgs } = require("./headed-window.cjs");

const browserTypes = { chromium, firefox, webkit };

const browserTypeName = process.env.PW_BROWSER_TYPE || "chromium";
const browserType = browserTypes[browserTypeName] || chromium;
const screenSize = screenSizeFromEnv();

process.env.DISPLAY = process.env.DISPLAY || ":99";

const launchOptions = { headless: false };
if (browserTypeName === "chromium") {
  launchOptions.args = chromiumHeadedArgs(screenSize);
} else if (browserTypeName === "firefox") {
  launchOptions.args = firefoxHeadedArgs(screenSize);
}

const channel = process.env.PW_BROWSER_CHANNEL;
if (channel) {
  launchOptions.channel = channel;
}
const proxyServer = process.env.PW_PROXY;
if (proxyServer) {
  launchOptions.proxy = { server: proxyServer };
}

async function fitWindowToScreen(page) {
  try {
    if (browserTypeName === "chromium") {
      const session = await page.context().newCDPSession(page);
      const { windowId } = await session.send("Browser.getWindowForTarget");
      // Width/height = Xvfb size often exceeds the work area (window chrome) and
      // Chrome then rejects the call — that used to kill this process (exit 1).
      try {
        await session.send("Browser.setWindowBounds", {
          windowId,
          bounds: { windowState: "maximized" },
        });
      } catch {
        await session.send("Browser.setWindowBounds", {
          windowId,
          bounds: {
            left: 0,
            top: 0,
            width: screenSize.width,
            height: screenSize.height,
            windowState: "normal",
          },
        });
      }
      return;
    }
    await page.setViewportSize(screenSize);
    await page.evaluate(({ width, height }) => {
      window.moveTo(0, 0);
      window.resizeTo(width, height);
    }, screenSize);
  } catch (err) {
    console.error("fitWindowToScreen:", err.message || err);
  }
}

(async () => {
  const browser = await browserType.launch(launchOptions);
  // viewport:null — do not shrink the OS window to Playwright's 1280×720 default.
  const page = await browser.newPage({ viewport: null });
  await page.goto("about:blank");
  await fitWindowToScreen(page);
  browser.on("disconnected", () => process.exit(0));
})().catch((err) => {
  console.error("Failed to launch headed browser for VNC:", err.message || err);
  process.exit(1);
});
