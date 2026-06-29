import fs from "node:fs";

const manifestPath = process.argv[2];
if (!manifestPath) {
  throw new Error("Usage: rewrite_chrome_store_manifest.mjs <manifest.json>");
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const scopedHosts = [
  "https://www.youtube.com/*",
  "https://m.youtube.com/*",
  "https://x.com/*",
  "https://twitter.com/*",
  "https://mobile.x.com/*",
  "https://www.instagram.com/*",
  "https://instagram.com/*",
  "https://www.reddit.com/*",
  "https://old.reddit.com/*",
  "https://new.reddit.com/*",
  "https://www.yourtortoise.com/*",
  "https://yourtortoise.com/*"
];

manifest.name = "QuietGate: Focus & Adult Blocker";
manifest.description = "Block distracting feeds and adult content on supported sites with account-synced QuietGate policy.";
manifest.version = "1.0.0";
delete manifest.key;
manifest.permissions = [...new Set([
  ...(manifest.permissions || []).filter((permission) => permission !== "nativeMessaging"),
  "alarms"
])];
manifest.host_permissions = scopedHosts;
manifest.optional_host_permissions = ["http://*/*", "https://*/*"];
manifest.icons = {
  16: "assets/icon16.png",
  32: "assets/icon32.png",
  48: "assets/icon48.png",
  128: "assets/icon128.png"
};
manifest.action = {
  ...(manifest.action || {}),
  default_icon: manifest.icons
};
manifest.externally_connectable = {
  matches: ["https://www.yourtortoise.com/*", "https://yourtortoise.com/*"]
};
manifest.content_scripts = (manifest.content_scripts || []).filter((script) => {
  const files = Array.isArray(script.js) ? script.js : [];
  return !files.includes("content/web-classifier.js");
});

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
