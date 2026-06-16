#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLAYWRIGHT_PREFIX="${PLAYWRIGHT_PREFIX:-/tmp/quietgate-playwright}"

echo "Checking browser extension JavaScript syntax..."
node --check "$ROOT_DIR/ChromeExtension/background.js"
node --check "$ROOT_DIR/ChromeExtension/content/blocker.js"
node --check "$ROOT_DIR/ChromeExtension/content/web-classifier.js"
node --check "$ROOT_DIR/ChromeExtension/content/youtube.js"
node --check "$ROOT_DIR/ChromeExtension/content/x-page.js"
node --check "$ROOT_DIR/ChromeExtension/content/x.js"
node --check "$ROOT_DIR/ChromeExtension/content/platform-controls.js"
node --check "$ROOT_DIR/ChromeExtension/content/instagram.js"
node --check "$ROOT_DIR/ChromeExtension/content/reddit.js"
node --check "$ROOT_DIR/ChromeExtension/popup/popup.js"
node --check "$ROOT_DIR/FirefoxExtension/background.js"
node --check "$ROOT_DIR/FirefoxExtension/content/blocker.js"
node --check "$ROOT_DIR/FirefoxExtension/content/web-classifier.js"
node --check "$ROOT_DIR/FirefoxExtension/content/youtube.js"
node --check "$ROOT_DIR/FirefoxExtension/content/x-page.js"
node --check "$ROOT_DIR/FirefoxExtension/content/x.js"
node --check "$ROOT_DIR/FirefoxExtension/content/platform-controls.js"
node --check "$ROOT_DIR/FirefoxExtension/content/instagram.js"
node --check "$ROOT_DIR/FirefoxExtension/content/reddit.js"
node --check "$ROOT_DIR/FirefoxExtension/popup/popup.js"
node --check "$ROOT_DIR/FirefoxExtension/connect/connect.js"

echo "Preparing Playwright Chromium..."
if [ ! -x "$PLAYWRIGHT_PREFIX/node_modules/.bin/playwright" ]; then
  npm install --prefix "$PLAYWRIGHT_PREFIX" playwright
fi
"$PLAYWRIGHT_PREFIX/node_modules/.bin/playwright" install chromium

echo "Installing QuietGate browser automatic updates host..."
"$ROOT_DIR/script/install_chrome_sync.sh"

echo "Checking automatic updates host response..."
node <<'NODE'
const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const host = path.join(
  process.env.HOME,
  "Library",
  "Application Support",
  "QuietGate",
  "NativeHost",
  "quietgate-native-host"
);
const settingsPath = path.join(
  process.env.HOME,
  "Library",
  "Application Support",
  "QuietGate",
  "extension-settings.json"
);

function readHostSettings() {
  const body = Buffer.from(JSON.stringify({ type: "getSettings" }));
  const header = Buffer.alloc(4);
  header.writeUInt32LE(body.length, 0);

  const result = spawnSync(host, ["chrome-extension://fedpnejbgmllajjlfkahlnjbgfmjjmmf/"], {
    input: Buffer.concat([header, body])
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    process.stderr.write(result.stderr.toString("utf8"));
    process.exit(result.status || 1);
  }
  if (result.stdout.length < 4) {
    throw new Error("Native host returned an empty response.");
  }

  const length = result.stdout.readUInt32LE(0);
  return JSON.parse(result.stdout.subarray(4, 4 + length).toString("utf8"));
}

function assertUsablePayload(payload, label) {
  if (
    !payload.ok ||
    !payload.settings ||
    !payload.settings.features ||
    !payload.settings.options ||
    payload.settings.options.explicitHideStyle !== "post" && payload.settings.options.explicitHideStyle !== "media" && payload.settings.options.explicitHideStyle !== "placeholder" ||
    typeof payload.settings.options.youtubeDailyLimitMinutes !== "number" ||
    typeof payload.settings.features.youtubeUsageTracking !== "boolean" ||
    typeof payload.settings.features.youtubeDailyLimit !== "boolean" ||
    !Array.isArray(payload.settings.blockedDomains) ||
    !String(payload.settings.settingsVersion || "").includes("youtubeDailyLimitMinutes=")
  ) {
    throw new Error(`Native host response was not usable for ${label}: ${JSON.stringify(payload)}`);
  }
}

const hadSettings = fs.existsSync(settingsPath);
const previousSettings = hadSettings ? fs.readFileSync(settingsPath) : null;
try {
  assertUsablePayload(readHostSettings(), "current settings");

  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  fs.writeFileSync(settingsPath, `${JSON.stringify({
    mode: "focus",
    features: {
      youtubeShorts: true,
      xSensitiveMedia: true
    },
    blockedDomains: ["legacy.example"],
    blockedCategories: [],
    options: {
      explicitHideStyle: "media"
    },
    settingsVersion: "legacy",
    updatedAt: "2024-01-01T00:00:00Z"
  }, null, 2)}\n`);
  const legacyPayload = readHostSettings();
  assertUsablePayload(legacyPayload, "legacy settings");
  if (
    legacyPayload.settings.options.youtubeDailyLimitMinutes !== 30 ||
    legacyPayload.settings.features.youtubeUsageTracking !== false ||
    legacyPayload.settings.features.youtubeDailyLimit !== false ||
    !legacyPayload.settings.blockedDomains.includes("legacy.example")
  ) {
    throw new Error(`Native host did not normalize legacy settings: ${JSON.stringify(legacyPayload)}`);
  }
} finally {
  if (hadSettings) {
    fs.writeFileSync(settingsPath, previousSettings);
  } else {
    fs.rmSync(settingsPath, { force: true });
  }
}

console.log("native host ok");
NODE

echo "Running browser extension smoke test..."
QG_SMOKE_BROWSER=chromium NODE_PATH="$PLAYWRIGHT_PREFIX/node_modules" node "$ROOT_DIR/script/smoke_chrome_extension.js"

echo "Running browser extension smoke test with automatic updates..."
QG_SMOKE_BROWSER=chromium QG_SMOKE_WITH_NATIVE=1 NODE_PATH="$PLAYWRIGHT_PREFIX/node_modules" node "$ROOT_DIR/script/smoke_chrome_extension.js"

echo "QuietGate browser verification passed."
