#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

const CHROMIUM_EXTENSION_ID = "fedpnejbgmllajjlfkahlnjbgfmjjmmf";
const FIREFOX_EXTENSION_ID = "quietgate@willpulier.com";
const HOST_NAME = "com.willpulier.quietgate";
const STALE_AFTER_MS = Number(process.env.QG_BROWSER_HELPER_STALE_MS || 24 * 60 * 60 * 1000);

const ROOT_DIR = path.resolve(__dirname, "..");
const APP_SUPPORT_DIR = process.env.QG_APP_SUPPORT_DIR ||
  path.join(os.homedir(), "Library", "Application Support", "QuietGate");
const NATIVE_HOST_SOURCE = path.join(ROOT_DIR, "NativeHost", "build", "quietgate-native-host");

const browsers = [
  {
    id: "chrome",
    name: "Chrome",
    appNames: ["Google Chrome.app"],
    extensionID: CHROMIUM_EXTENSION_ID,
    extensionDir: path.join(ROOT_DIR, "ChromeExtension"),
    userDataDir: path.join(os.homedir(), "Library", "Application Support", "Google", "Chrome"),
    hostDir: path.join(os.homedir(), "Library", "Application Support", "Google", "Chrome", "NativeMessagingHosts")
  },
  {
    id: "edge",
    name: "Edge",
    appNames: ["Microsoft Edge.app"],
    extensionID: CHROMIUM_EXTENSION_ID,
    extensionDir: path.join(ROOT_DIR, "ChromeExtension"),
    userDataDir: path.join(os.homedir(), "Library", "Application Support", "Microsoft Edge"),
    hostDir: path.join(os.homedir(), "Library", "Application Support", "Microsoft Edge", "NativeMessagingHosts")
  },
  {
    id: "brave",
    name: "Brave",
    appNames: ["Brave Browser.app"],
    extensionID: CHROMIUM_EXTENSION_ID,
    extensionDir: path.join(ROOT_DIR, "ChromeExtension"),
    userDataDir: path.join(os.homedir(), "Library", "Application Support", "BraveSoftware", "Brave-Browser"),
    hostDir: path.join(os.homedir(), "Library", "Application Support", "BraveSoftware", "Brave-Browser", "NativeMessagingHosts")
  },
  {
    id: "arc",
    name: "Arc",
    appNames: ["Arc.app"],
    extensionID: CHROMIUM_EXTENSION_ID,
    extensionDir: path.join(ROOT_DIR, "ChromeExtension"),
    userDataDir: path.join(os.homedir(), "Library", "Application Support", "Arc", "User Data"),
    hostDir: path.join(os.homedir(), "Library", "Application Support", "Arc", "User Data", "NativeMessagingHosts")
  },
  {
    id: "firefox",
    name: "Firefox",
    appNames: ["Firefox.app"],
    extensionID: FIREFOX_EXTENSION_ID,
    extensionDir: path.join(ROOT_DIR, "FirefoxExtension"),
    userDataDir: path.join(os.homedir(), "Library", "Application Support", "Firefox", "Profiles"),
    hostDir: path.join(os.homedir(), "Library", "Application Support", "Mozilla", "NativeMessagingHosts")
  }
];

function check(state, title, detail, action = null) {
  return { state, title, detail, action };
}

function exists(filePath) {
  return fs.existsSync(filePath);
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function statusFileName(browser) {
  return browser.id === "chrome" ? "chrome-status.json" : `${browser.id}-status.json`;
}

function statusPath(browser) {
  return path.join(APP_SUPPORT_DIR, statusFileName(browser));
}

function currentSettingsVersion() {
  const settingsPath = path.join(APP_SUPPORT_DIR, "extension-settings.json");
  if (!exists(settingsPath)) {
    return null;
  }

  try {
    return readJSON(settingsPath).settingsVersion || null;
  } catch {
    return null;
  }
}

function browserAppInstalled(browser) {
  const roots = [
    "/Applications",
    "/System/Applications",
    path.join(os.homedir(), "Applications")
  ];

  return roots.some((root) =>
    browser.appNames.some((name) => exists(path.join(root, name)))
  );
}

function checkSupportedBrowserInstalled() {
  const installed = browsers.filter(browserAppInstalled).map((browser) => browser.name);
  if (installed.length > 0) {
    return check("pass", "Supported browser", `${installed.join(", ")} installed.`);
  }

  return check(
    "fail",
    "Supported browser",
    "Chrome, Edge, Brave, Arc, or Firefox is required for the browser-first MVP.",
    "Install one supported browser, then open QuietGate Setup."
  );
}

function checkExtensionSources() {
  const missing = browsers
    .map((browser) => browser.extensionDir)
    .filter((value, index, values) => values.indexOf(value) === index)
    .filter((extensionDir) => !exists(path.join(extensionDir, "manifest.json")));

  if (missing.length === 0) {
    return check("pass", "Browser helper files", "QuietGate browser helper files are present.");
  }

  return check(
    "fail",
    "Browser helper files",
    `Missing helper manifest: ${missing.join(", ")}.`,
    "Rebuild or reinstall QuietGate."
  );
}

function checkNativeHostSource() {
  if (exists(NATIVE_HOST_SOURCE)) {
    return check("pass", "Mac helper", "QuietGate Mac helper is built.");
  }

  return check(
    "fail",
    "Mac helper",
    `Missing ${NATIVE_HOST_SOURCE}.`,
    "Run script/build_native_host.sh."
  );
}

function nativeManifestPath(browser) {
  return path.join(browser.hostDir, `${HOST_NAME}.json`);
}

function manifestMatchesBrowser(browser, manifest) {
  if (browser.id === "firefox") {
    return manifest.name === HOST_NAME &&
      manifest.type === "stdio" &&
      Array.isArray(manifest.allowed_extensions) &&
      manifest.allowed_extensions.includes(browser.extensionID) &&
      typeof manifest.path === "string" &&
      exists(manifest.path);
  }

  return manifest.name === HOST_NAME &&
    manifest.type === "stdio" &&
    Array.isArray(manifest.allowed_origins) &&
    manifest.allowed_origins.includes(`chrome-extension://${browser.extensionID}/`) &&
    typeof manifest.path === "string" &&
    exists(manifest.path);
}

function checkNativeManifests() {
  const installed = [];
  const broken = [];

  for (const browser of browsers) {
    const manifestPath = nativeManifestPath(browser);
    if (!exists(manifestPath)) {
      continue;
    }

    try {
      const manifest = readJSON(manifestPath);
      if (manifestMatchesBrowser(browser, manifest)) {
        installed.push(browser.name);
      } else {
        broken.push(browser.name);
      }
    } catch {
      broken.push(browser.name);
    }
  }

  if (installed.length > 0) {
    const brokenText = broken.length > 0 ? ` Needs repair: ${broken.join(", ")}.` : "";
    return check(
      "pass",
      "Browser update file",
      `Installed for ${installed.join(", ")}.${brokenText} A browser is connected only after it opens and confirms QuietGate settings.`
    );
  }

  return check(
    "info",
    "Browser update file",
    "No browser update file is installed yet.",
    "Open QuietGate Setup and connect a supported browser."
  );
}

function browserStatus(browser, requiredSettingsVersion) {
  const filePath = statusPath(browser);
  if (!exists(filePath)) {
    return { browser, ready: false, detail: "not connected" };
  }

  try {
    const status = readJSON(filePath);
    const seenAt = Date.parse(status.lastSeenAt || "");
    const fresh = Number.isFinite(seenAt) && Date.now() - seenAt <= STALE_AFTER_MS;
    const extensionMatches = status.extensionID === browser.extensionID;
    const versionMatches = !requiredSettingsVersion ||
      status.lastAppliedSettingsVersion === requiredSettingsVersion;
    const hasError = typeof status.lastError === "string" && status.lastError.length > 0;

    const ready = fresh && extensionMatches && versionMatches && !hasError;
    const details = [];
    details.push(fresh ? "checked in recently" : "stale");
    if (!extensionMatches) details.push("wrong helper ID");
    if (!versionMatches) details.push("settings not current");
    if (hasError) details.push(status.lastError);

    return {
      browser,
      ready,
      detail: details.join(", "),
      blockedRuleCount: status.blockedRuleCount
    };
  } catch (error) {
    return { browser, ready: false, detail: `status unreadable: ${error.message}` };
  }
}

function checkBrowserConnection() {
  const requiredSettingsVersion = currentSettingsVersion();
  const statuses = browsers.map((browser) => browserStatus(browser, requiredSettingsVersion));
  const ready = statuses.filter((status) => status.ready);

  if (ready.length > 0) {
    const summary = ready
      .map((status) => `${status.browser.name}${Number.isInteger(status.blockedRuleCount) ? ` (${status.blockedRuleCount} rules)` : ""}`)
      .join(", ");
    return check("pass", "Browser connection", `${summary} connected and current.`);
  }

  const seen = statuses
    .filter((status) => status.detail !== "not connected")
    .map((status) => `${status.browser.name}: ${status.detail}`);
  const detail = seen.length > 0
    ? seen.join("; ")
    : "No supported browser has opened and confirmed QuietGate settings yet.";

  return check(
    "fail",
    "Browser connection",
    detail,
    "Open QuietGate Setup and connect Chrome, Edge, Brave, Arc, or Firefox."
  );
}

function checkLegacyProviderOptOut() {
  return check(
    "pass",
    "Old account setup",
    "Disabled for normal app launch. Browser connections are the product setup path."
  );
}

function printHuman(checks) {
  console.log("QuietGate browser-first setup check");
  for (const item of checks) {
    const marker = item.state === "pass" ? "PASS" : (item.state === "fail" ? "FAIL" : "INFO");
    console.log(`[${marker}] ${item.title}: ${item.detail}`);
    if (item.action) {
      console.log(`       Next: ${item.action}`);
    }
  }

  const ready = checks
    .filter((item) => item.state !== "info")
    .every((item) => item.state === "pass");
  console.log(ready ? "Result: ready" : "Result: not ready");
}

function main() {
  const checks = [
    checkSupportedBrowserInstalled(),
    checkExtensionSources(),
    checkNativeHostSource(),
    checkNativeManifests(),
    checkBrowserConnection(),
    checkLegacyProviderOptOut()
  ];
  const ready = checks
    .filter((item) => item.state !== "info")
    .every((item) => item.state === "pass");

  if (process.argv.includes("--json")) {
    console.log(JSON.stringify({ ready, checks }, null, 2));
  } else {
    printHuman(checks);
  }

  process.exit(ready ? 0 : 1);
}

main();
