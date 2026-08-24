const { chromium, firefox, webkit } = require("playwright-core");
const { screenSizeFromEnv } = require("./screen-resolution.cjs");

const browserTypes = { chromium, firefox, webkit };

const browserTypeName = process.env.PW_BROWSER_TYPE || "chromium";
const browserType = browserTypes[browserTypeName] || chromium;
const screenSize = screenSizeFromEnv();

process.env.DISPLAY = process.env.DISPLAY || ":99";

const launchOptions = { headless: false };
if (browserTypeName === "chromium") {
  // Same CDP proxy as server.cjs, plus window bounds = Xvfb (VNC) size.
  launchOptions.args = [
    "--remote-debugging-port=0",
    `--window-size=${screenSize.width},${screenSize.height}`,
    "--window-position=0,0",
  ];
} else if (browserTypeName === "firefox") {
  launchOptions.args = ["-width", String(screenSize.width), "-height", String(screenSize.height)];
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
  if (browserTypeName === "chromium") {
    const session = await page.context().newCDPSession(page);
    const { windowId } = await session.send("Browser.getWindowForTarget");
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
    return;
  }
  await page.setViewportSize(screenSize);
  await page.evaluate(({ width, height }) => {
    window.moveTo(0, 0);
    window.resizeTo(width, height);
  }, screenSize);
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
