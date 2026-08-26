const { chromium, firefox, webkit } = require("playwright-core");

const browserTypes = { chromium, firefox, webkit };

function env(name, defaultValue = "") {
  const value = process.env[name];
  return typeof value === "string" && value.length > 0 ? value : defaultValue;
}

function parseBoolean(name, defaultValue) {
  const value = process.env[name];
  if (typeof value !== "string" || value.length === 0) {
    return defaultValue;
  }
  switch (value.toLowerCase()) {
    case "1":
    case "true":
    case "yes":
    case "on":
      return true;
    case "0":
    case "false":
    case "no":
    case "off":
      return false;
    default:
      return defaultValue;
  }
}

function parsePort(name, defaultValue) {
  const raw = env(name, String(defaultValue));
  const port = Number(raw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`${name} must be a valid port`);
  }
  return port;
}

const { parseScreenResolution } = require("./screen-resolution.cjs");
const { headedLaunchArgs } = require("./headed-window.cjs");

const browserTypeName = env("PW_BROWSER_TYPE", "chromium");
const browserType = browserTypes[browserTypeName];
if (!browserType || typeof browserType.launchServer !== "function") {
  throw new Error(`PW_BROWSER_TYPE must be one of: chromium, firefox, webkit`);
}

const host = env("PW_HOST", "0.0.0.0");
const port = parsePort("PW_PORT", 3000);
const wsPath = env("PW_PATH", "/");
const headless = parseBoolean("PW_HEADLESS", true);

const launchOptions = {
  headless,
  host,
  port,
  wsPath,
};

// Hub → capsFromQuery(socksProxy) → env PW_PROXY (socks5://host:port or full URL).
const proxyServer = env("PW_PROXY");
if (proxyServer) {
  launchOptions.proxy = { server: proxyServer };
}

const screenSize = parseScreenResolution(env("SCREEN_RESOLUTION"));
const extraChromium =
  browserTypeName === "chromium"
    ? ["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"]
    : [];
const launchArgs = headedLaunchArgs(browserTypeName, screenSize, extraChromium);
if (launchArgs.length > 0) {
  // Chromium: --remote-debugging-port=0 so Chrome writes DevToolsActivePort;
  // hub CDP is the static proxy on :7070. Do not pin a debug port.
  // Firefox: -width/-height so the launchServer window matches Xvfb (WebKit ignores args).
  launchOptions.args = launchArgs;
}

const channel = env("PW_BROWSER_CHANNEL");
if (channel) {
  launchOptions.channel = channel;
}

const executablePathEnv = env("PW_EXECUTABLE_PATH_ENV");
if (executablePathEnv && process.env[executablePathEnv]) {
  delete launchOptions.channel;
  launchOptions.executablePath = process.env[executablePathEnv];
}

async function main() {
  const server = await browserType.launchServer(launchOptions);
  console.log(
    `Playwright ${env("PW_BROWSER_NAME", browserTypeName)} server listening at ${server.wsEndpoint()} (headless=${headless})`,
  );

  const shutdown = async () => {
    try {
      await server.close();
    } finally {
      process.exit(0);
    }
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
  await new Promise(() => {});
}

main().catch((error) => {
  console.error("Failed to start Playwright server:", error);
  process.exit(1);
});
