const http = require("node:http");
const { execFileSync } = require("node:child_process");
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
    await page.evaluate(({ width, height }) => {
      window.moveTo(0, 0);
      window.resizeTo(width, height);
    }, screenSize);
  } catch (err) {
    console.error("fitWindowToScreen:", err.message || err);
  }
}

async function firstOrNewPage(browser) {
  const pages = browser.contexts().flatMap((ctx) => ctx.pages());
  const page = pages[0] || (await browser.newPage({ viewport: null }));
  for (const extra of pages.slice(1)) {
    await extra.close().catch(() => {});
  }
  return page;
}

/** Firefox Nightly titles about:blank as "Problem loading page". */
async function fillBlank(page) {
  try {
    await page.setContent("<!DOCTYPE html><html><head><title>Playwright</title></head><body></body></html>", {
      waitUntil: "domcontentloaded",
      timeout: 5000,
    });
  } catch (err) {
    console.error("fillBlank:", err.message || err);
  }
}

/** Keep the setContent window; Firefox also maps an about:blank "Problem loading page". */
function closeExtraFullscreenWindows() {
  let out = "";
  try {
    out = execFileSync("wmctrl", ["-l", "-G"], { encoding: "utf8" });
  } catch {
    return;
  }
  const keep = [];
  const drop = [];
  for (const line of out.trim().split("\n")) {
    if (!line) continue;
    const parts = line.split(/\s+/);
    if (parts.length < 7) continue;
    const id = parts[0];
    const width = Number(parts[4]);
    const height = Number(parts[5]);
    const title = parts.slice(7).join(" ").trim();
    if (!(width >= 800 && height >= 600)) continue;
    if (/playwright/i.test(title) && !/problem loading/i.test(title)) keep.push(id);
    else drop.push(id);
  }
  if (keep.length === 0) {
    return;
  }
  for (const id of drop) {
    try {
      execFileSync("wmctrl", ["-i", "-c", id]);
    } catch {
      // ignore
    }
  }
}

(async () => {
  await waitForServer();
  const browser = await browserType.connect(wsEndpoint);
  const page = await firstOrNewPage(browser);
  await fillBlank(page);
  await fitWindowToScreen(page);
  closeExtraFullscreenWindows();
  console.error("headed manual page ready");
  await new Promise(() => {});
})().catch((err) => {
  console.error("Failed to launch headed browser for VNC:", err.message || err);
  process.exit(1);
});
