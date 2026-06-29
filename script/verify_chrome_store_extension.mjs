import fs from "node:fs";
import path from "node:path";

const distDir = process.argv[2];
if (!distDir) {
  throw new Error("Usage: verify_chrome_store_extension.mjs <dist/chrome-store>");
}

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function walk(dir, files = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, files);
    } else {
      files.push(fullPath);
    }
  }
  return files;
}

const manifest = readJSON(path.join(distDir, "manifest.json"));
const permissions = new Set(manifest.permissions || []);
const hosts = new Set(manifest.host_permissions || []);
const optionalHosts = new Set(manifest.optional_host_permissions || []);
const contentScriptFiles = (manifest.content_scripts || []).flatMap((script) => script.js || []);

if (manifest.name !== "QuietGate: Focus & Adult Blocker") {
  fail("Store manifest name is not the production listing name.");
}
if (manifest.version !== "1.0.0") {
  fail("Store manifest version must start at 1.0.0.");
}
if (manifest.key) {
  fail("Store manifest must not include the development key; Chrome Web Store should assign the production ID.");
}
if (permissions.has("nativeMessaging")) {
  fail("Store manifest must not include nativeMessaging.");
}
if (!permissions.has("alarms")) {
  fail("Store manifest must include alarms for periodic policy sync.");
}
if (!manifest.externally_connectable?.matches?.includes("https://www.yourtortoise.com/*")) {
  fail("Store manifest must allow external connection from www.yourtortoise.com.");
}
if (hosts.has("http://*/*") || hosts.has("https://*/*")) {
  fail("All-site host access must be optional, not required.");
}
if (!optionalHosts.has("http://*/*") || !optionalHosts.has("https://*/*")) {
  fail("Optional all-site host permissions are missing.");
}
for (const [size, filePath] of Object.entries(manifest.icons || {})) {
  if (!["16", "32", "48", "128"].includes(size) || !fs.existsSync(path.join(distDir, filePath))) {
    fail(`Manifest icon is missing or invalid: ${size} -> ${filePath}`);
  }
}
for (const requiredHost of [
  "https://x.com/*",
  "https://twitter.com/*",
  "https://www.reddit.com/*",
  "https://www.youtube.com/*",
  "https://www.yourtortoise.com/*"
]) {
  if (!hosts.has(requiredHost)) {
    fail(`Required scoped host is missing: ${requiredHost}`);
  }
}
if (contentScriptFiles.includes("content/web-classifier.js")) {
  fail("Global web-classifier.js must not be statically injected in the store build.");
}
for (const requiredFile of [
  "background.js",
  "blocked/blocked.html",
  "content/x-page.js",
  "content/web-classifier.js",
  "assets/icon128.png",
  "rules/adult-domains.json",
  "rules/adult-static-1.json"
]) {
  if (!fs.existsSync(path.join(distDir, requiredFile))) {
    fail(`Packaged extension is missing ${requiredFile}.`);
  }
}

const reviewRiskPatterns = [
  { label: "eval(", pattern: /\beval\s*\(/ },
  { label: "new Function", pattern: /new\s+Function\s*\(/ },
  { label: "remote script tag", pattern: /<script[^>]+src=["']https?:\/\//i }
];
for (const filePath of walk(distDir)) {
  if (!/\.(js|html)$/i.test(filePath)) {
    continue;
  }
  const text = fs.readFileSync(filePath, "utf8");
  for (const check of reviewRiskPatterns) {
    if (check.pattern.test(text)) {
      fail(`Review-risk pattern ${check.label} found in ${path.relative(distDir, filePath)}.`);
    }
  }
}

if (process.exitCode) {
  process.exit(process.exitCode);
}
console.log("Chrome Store extension manifest and package checks passed.");
