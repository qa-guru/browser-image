const http = require("node:http");
const { chromium, firefox, webkit } = require("playwright-core");
const { screenSizeFromEnv } = require("./screen-resolution.cjs");
const { playwrightWsEndpoint } = require("./headed-window.cjs");

const browserTypes = { chromium, firefox, webkit };

const browserTypeName = process.env.PW_BROWSER_TYPE || "chromium";
const browserType = browserTypes[browserTypeName] || chromium;
const screenSize = screenSizeFromEnv();
const port = process.env.PW_PORT || "3000";
const wsEndpoint = playwrightWsEndpoint();

process.env.DISPLAY = process.env.DISPLAY || ":99";

function waitForServer(timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const tryOnce = () => {
      const req = http.get(`http://127.0.0.1:${port}/`, (res) => {
        res.resume();
        if (res.statusCode === 200) {
          resolve();
          return;
        }
        if (Date.now() > deadline) {
          reject(new Error(`Playwright server HTTP ${res.statusCode}`));
          return;
        }
        setTimeout(tryOnce, 100);
      });
      req.on("error", () => {
        if (Date.now() > deadline) {
          reject(new Error("Playwright server did not become ready"));
          return;
        }
        setTimeout(tryOnce, 100);
      });
    };
    tryOnce();
  });
}

async function fitWindowToScreen(page) {
  try {
    if (browserTypeName === "chromium") {
      const session = await page.context().newCDPSession(page);
      const { windowId } = await session.send("Browser.getWindowForTarget");
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
    // Do not setViewportSize: it fights WM maximize (window chrome vs Xvfb).
    await page.evaluate(({ width, height }) => {
      window.moveTo(0, 0);
      window.resizeTo(width, height);
    }, screenSize);
  } catch (err) {
    console.error("fitWindowToScreen:", err.message || err);
  }
}

(async () => {
  await waitForServer();
  // Same browser as launchServer — a second launch() stacked a small Firefox/WebKit
  // window on top of the server process (VNC showed the nested frame).
  const browser = await browserType.connect(wsEndpoint);
  const page = await browser.newPage({ viewport: null });
  await page.goto("about:blank");
  await fitWindowToScreen(page);
  await new Promise(() => {});
})().catch((err) => {
  console.error("Failed to launch headed browser for VNC:", err.message || err);
  process.exit(1);
});
