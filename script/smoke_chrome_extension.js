#!/usr/bin/env node

const fs = require("fs");
const childProcess = require("child_process");
const os = require("os");
const path = require("path");

let chromium;
try {
  ({ chromium } = require("playwright"));
} catch (error) {
  console.error("This smoke test needs Playwright. Run:");
  console.error("npx --yes --package playwright node script/smoke_chrome_extension.js");
  process.exit(2);
}

const ROOT_DIR = path.resolve(__dirname, "..");
const EXTENSION_DIR = path.join(ROOT_DIR, "ChromeExtension");
const SOURCE_NATIVE_HOST = path.join(ROOT_DIR, "NativeHost", "build", "quietgate-native-host");
const CHROME_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const HOST_NAME = "com.willpulier.quietgate";
const EXTENSION_ID = "fedpnejbgmllajjlfkahlnjbgfmjjmmf";
const SMOKE_BROWSER = process.env.QG_SMOKE_BROWSER || "chromium";
const FEATURE_DEFAULTS = {
  youtubeHome: false,
  youtubeVideoSidebar: false,
  youtubeShorts: false,
  youtubeComments: false,
  youtubeRecommendations: false,
  youtubeSearch: false,
  youtubeEndScreens: false,
  youtubeEndScreenCards: false,
  youtubeLiveChat: false,
  youtubeAutoplay: false,
  youtubePlaylists: false,
  youtubeFundraisers: false,
  youtubeMixes: false,
  youtubeMerch: false,
  youtubeVideoInfo: false,
  youtubeTopHeader: false,
  youtubeNotifications: false,
  youtubeExplore: false,
  youtubeMoreFromYouTube: false,
  youtubeSubscriptions: false,
  youtubeAnnotations: false,
  youtubeUsageTracking: false,
  youtubeDailyLimit: false,
  xSensitiveMedia: false,
  xExplicitContent: false,
  xExplicitSearch: false,
  xVideos: false,
  xPhotos: false,
  xMediaCards: false,
  xExploreTrends: false,
  instagramReels: false,
  instagramExplore: false,
  instagramSuggested: false,
  instagramProfileSuggestions: false,
  instagramMessages: false,
  instagramNotifications: false,
  instagramStories: false,
  redditPopularAll: false,
  redditRecommendations: false,
  redditNSFW: false,
  redditMedia: false,
  redditSidebars: false
};
const DEFAULT_OPTIONS = {
  explicitHideStyle: "post",
  youtubeDailyLimitMinutes: 30
};
const DEFAULT_BLOCKED_CATEGORIES = [];

function mkdirp(value) {
  fs.mkdirSync(value, { recursive: true });
}

function writeJSON(filePath, value) {
  mkdirp(path.dirname(filePath));
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function readJSONFile(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function requireFile(filePath, label) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`${label} is missing: ${filePath}`);
  }
}

function manifestHasWebAccessibleResource(manifest, resource) {
  return (manifest.web_accessible_resources || []).some((entry) => {
    if (typeof entry === "string") {
      return entry === resource;
    }
    return Array.isArray(entry.resources) && entry.resources.includes(resource);
  });
}

function contentScriptIndex(manifest, scriptPath) {
  return (manifest.content_scripts || []).findIndex((script) => (
    Array.isArray(script.js) && script.js.includes(scriptPath)
  ));
}

function verifyExtensionXPageDetectorSurface() {
  const chromeManifestPath = path.join(ROOT_DIR, "ChromeExtension", "manifest.json");
  const firefoxManifestPath = path.join(ROOT_DIR, "FirefoxExtension", "manifest.json");
  const chromeXPath = path.join(ROOT_DIR, "ChromeExtension", "content", "x.js");
  const firefoxXPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "x.js");
  const chromeXPagePath = path.join(ROOT_DIR, "ChromeExtension", "content", "x-page.js");
  const firefoxXPagePath = path.join(ROOT_DIR, "FirefoxExtension", "content", "x-page.js");
  const chromeXCSSPath = path.join(ROOT_DIR, "ChromeExtension", "content", "x.css");
  const firefoxXCSSPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "x.css");
  const chromeYouTubePath = path.join(ROOT_DIR, "ChromeExtension", "content", "youtube.js");
  const firefoxYouTubePath = path.join(ROOT_DIR, "FirefoxExtension", "content", "youtube.js");
  const chromeYouTubeCSSPath = path.join(ROOT_DIR, "ChromeExtension", "content", "youtube.css");
  const firefoxYouTubeCSSPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "youtube.css");
  const chromeRedditPath = path.join(ROOT_DIR, "ChromeExtension", "content", "reddit.js");
  const firefoxRedditPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "reddit.js");
  const chromePlatformControlsPath = path.join(ROOT_DIR, "ChromeExtension", "content", "platform-controls.js");
  const firefoxPlatformControlsPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "platform-controls.js");
  const chromeWebClassifierPath = path.join(ROOT_DIR, "ChromeExtension", "content", "web-classifier.js");
  const firefoxWebClassifierPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "web-classifier.js");
  const chromeAdultDomainsPath = path.join(ROOT_DIR, "ChromeExtension", "rules", "adult-domains.json");
  const firefoxAdultDomainsPath = path.join(ROOT_DIR, "FirefoxExtension", "rules", "adult-domains.json");
  const chromeAdultStaticPath = path.join(ROOT_DIR, "ChromeExtension", "rules", "adult-static-1.json");
  const chromeRedditCSSPath = path.join(ROOT_DIR, "ChromeExtension", "content", "reddit.css");
  const firefoxRedditCSSPath = path.join(ROOT_DIR, "FirefoxExtension", "content", "reddit.css");
  const chromeBackgroundPath = path.join(ROOT_DIR, "ChromeExtension", "background.js");

  requireFile(chromeXPagePath, "Chrome X page detector");
  requireFile(firefoxXPagePath, "Firefox X page detector");
  requireFile(chromeYouTubePath, "Chrome YouTube tuner");
  requireFile(firefoxYouTubePath, "Firefox YouTube tuner");
  requireFile(chromeYouTubeCSSPath, "Chrome YouTube style");
  requireFile(firefoxYouTubeCSSPath, "Firefox YouTube style");
  requireFile(chromeRedditPath, "Chrome Reddit tuner");
  requireFile(firefoxRedditPath, "Firefox Reddit tuner");
  requireFile(chromePlatformControlsPath, "Chrome platform controls audit");
  requireFile(firefoxPlatformControlsPath, "Firefox platform controls audit");
  requireFile(chromeWebClassifierPath, "Chrome all-web adult classifier");
  requireFile(firefoxWebClassifierPath, "Firefox all-web adult classifier");
  requireFile(chromeAdultDomainsPath, "Chrome adult domain snapshot");
  requireFile(firefoxAdultDomainsPath, "Firefox adult domain snapshot");
  requireFile(chromeAdultStaticPath, "Chrome static adult rules");

  const chromeManifest = readJSONFile(chromeManifestPath);
  const firefoxManifest = readJSONFile(firefoxManifestPath);
  const chromeYouTubeIndex = contentScriptIndex(chromeManifest, "content/youtube.js");
  const firefoxYouTubeIndex = contentScriptIndex(firefoxManifest, "content/youtube.js");
  const chromePageIndex = contentScriptIndex(chromeManifest, "content/x-page.js");
  const chromeXIndex = contentScriptIndex(chromeManifest, "content/x.js");
  const chromePlatformControlsIndex = contentScriptIndex(chromeManifest, "content/platform-controls.js");
  const chromeWebClassifierIndex = contentScriptIndex(chromeManifest, "content/web-classifier.js");
  const firefoxXIndex = contentScriptIndex(firefoxManifest, "content/x.js");
  const firefoxPlatformControlsIndex = contentScriptIndex(firefoxManifest, "content/platform-controls.js");
  const firefoxWebClassifierIndex = contentScriptIndex(firefoxManifest, "content/web-classifier.js");

  if (chromeYouTubeIndex === -1 || firefoxYouTubeIndex === -1) {
    throw new Error("Chrome and Firefox manifests must load content/youtube.js on YouTube.");
  }
  if (!chromeManifest.content_scripts[chromeYouTubeIndex].css?.includes("content/youtube.css")) {
    throw new Error("Chrome manifest must include content/youtube.css on YouTube.");
  }
  if (!firefoxManifest.content_scripts[firefoxYouTubeIndex].css?.includes("content/youtube.css")) {
    throw new Error("Firefox manifest must include content/youtube.css on YouTube.");
  }

  if (chromePageIndex === -1 || chromeXIndex === -1 || chromePageIndex > chromeXIndex) {
    throw new Error("Chrome manifest must load content/x-page.js before content/x.js on X.");
  }
  if (chromeManifest.content_scripts[chromePageIndex].world !== "MAIN") {
    throw new Error("Chrome X page detector must run in the MAIN world.");
  }
  if (!manifestHasWebAccessibleResource(chromeManifest, "content/x-page.js")) {
    throw new Error("Chrome manifest must expose content/x-page.js as a web-accessible resource.");
  }
  if (firefoxXIndex === -1 || !manifestHasWebAccessibleResource(firefoxManifest, "content/x-page.js")) {
    throw new Error("Firefox manifest must load content/x.js and expose content/x-page.js for fallback injection.");
  }
  if (chromePlatformControlsIndex === -1 || firefoxPlatformControlsIndex === -1) {
    throw new Error("Chrome and Firefox manifests must load content/platform-controls.js on supported settings pages.");
  }
  if (chromeWebClassifierIndex === -1 || firefoxWebClassifierIndex === -1) {
    throw new Error("Chrome and Firefox manifests must load content/web-classifier.js on ordinary web pages.");
  }
  if (!manifestHasWebAccessibleResource(chromeManifest, "rules/adult-domains.json") ||
      !manifestHasWebAccessibleResource(firefoxManifest, "rules/adult-domains.json")) {
    throw new Error("Chrome and Firefox manifests must expose the adult domain snapshot.");
  }
  if (!chromeManifest.declarative_net_request?.rule_resources?.some((ruleset) => ruleset.id === "adult-static-1")) {
    throw new Error("Chrome manifest must include static adult DNR rulesets.");
  }

  const chromeBackground = fs.readFileSync(chromeBackgroundPath, "utf8");
  if (!chromeBackground.includes('pageJs: "content/x-page.js"') || !chromeBackground.includes('world: "MAIN"')) {
    throw new Error("Chrome dynamic injection must install content/x-page.js in the MAIN world.");
  }
  if (!chromeBackground.includes("X_TUNER_VERSION") || !chromeBackground.includes("INSTAGRAM_TUNER_VERSION") || !chromeBackground.includes("tunerNeedsInjection")) {
    throw new Error("Chrome dynamic injection must reinject stale supported-site tabs by tuner version.");
  }

  const chromeX = fs.readFileSync(chromeXPath, "utf8");
  if (!chromeX.includes("quietgateXTunerVersion") || !chromeX.includes("__quietgateXTunerController")) {
    throw new Error("X tuner must be versioned and idempotent for dynamic reinjection.");
  }
  const chromeYouTube = fs.readFileSync(chromeYouTubePath, "utf8");
  const chromeYouTubeCSS = fs.readFileSync(chromeYouTubeCSSPath, "utf8");
  if (!chromeYouTube.includes("quietGateYouTubeTunerVersion") ||
      !chromeYouTube.includes("__quietgateYouTubeTunerController")) {
    throw new Error("YouTube tuner must be versioned and idempotent for dynamic reinjection.");
  }
  for (const featureKey of [
    "youtubeVideoSidebar",
    "youtubeEndScreenCards",
    "youtubeSubscriptions",
    "youtubeUsageTracking",
    "youtubeDailyLimit",
    "TUNER_VERSION"
  ]) {
    if (!chromeYouTube.includes(featureKey)) {
      throw new Error(`YouTube tuner is missing expanded feature key: ${featureKey}.`);
    }
  }
  const chromeInstagram = fs.readFileSync(path.join(EXTENSION_DIR, "content", "instagram.js"), "utf8");
  const chromeReddit = fs.readFileSync(chromeRedditPath, "utf8");
  if (!chromeInstagram.includes("quietgateInstagramTunerVersion") ||
      !chromeBackground.includes("instagram: INSTAGRAM_TUNER_VERSION") ||
      !chromeBackground.includes("hiddenCountDataset: \"quietgateInstagramHiddenCount\"")) {
    throw new Error("Instagram tuner must be versioned and included in dynamic tuner health.");
  }
  if (!chromeYouTube.includes("quietgateYouTubeHiddenCount") ||
      !chromeBackground.includes("hiddenCountDataset: \"quietgateYouTubeHiddenCount\"")) {
    throw new Error("YouTube tuner must report page-level hidden counts in dynamic tuner health.");
  }
  if (!chromeReddit.includes("quietgateRedditTunerVersion") ||
      !chromeReddit.includes("__quietgateRedditTunerController")) {
    throw new Error("Reddit tuner must be versioned and idempotent for dynamic reinjection.");
  }
  if (!chromeReddit.includes("quietgateRedditHiddenCount") ||
      !chromeBackground.includes("hiddenCountDataset: \"quietgateRedditHiddenCount\"")) {
    throw new Error("Reddit tuner must report page-level hidden counts in dynamic tuner health.");
  }
  for (const featureKey of [
    "instagramProfileSuggestions",
    "instagramMessages",
    "instagramNotifications"
  ]) {
    if (!chromeInstagram.includes(featureKey) || !chromeBackground.includes(featureKey)) {
      throw new Error(`Instagram tuner is missing expanded feature key: ${featureKey}.`);
    }
  }
  for (const className of [
    "qg-youtube-video-sidebar",
    "qg-youtube-end-screen-cards",
    "qg-youtube-subscriptions",
    "quietgate-youtube-usage",
    "quietgate-youtube-limit",
    "qg-youtube-usage-detail"
  ]) {
    if (!chromeYouTubeCSS.includes(className)) {
      throw new Error(`YouTube style is missing expanded selector class: ${className}.`);
    }
  }
  if (!chromeYouTube.includes("youtubeUsageSummary") ||
      !chromeYouTube.includes("mergeCurrentUsageIntoSummary") ||
      !chromeBackground.includes("saveYouTubeUsageSummary")) {
    throw new Error("YouTube usage tracking must aggregate native summaries across browser profiles.");
  }

  for (const [left, right, label] of [
    [chromeYouTubePath, firefoxYouTubePath, "content/youtube.js"],
    [chromeYouTubeCSSPath, firefoxYouTubeCSSPath, "content/youtube.css"],
    [chromeXPath, firefoxXPath, "content/x.js"],
    [chromeXPagePath, firefoxXPagePath, "content/x-page.js"],
    [chromeXCSSPath, firefoxXCSSPath, "content/x.css"],
    [chromePlatformControlsPath, firefoxPlatformControlsPath, "content/platform-controls.js"],
    [chromeWebClassifierPath, firefoxWebClassifierPath, "content/web-classifier.js"],
    [chromeAdultDomainsPath, firefoxAdultDomainsPath, "rules/adult-domains.json"],
    [chromeRedditPath, firefoxRedditPath, "content/reddit.js"],
    [chromeRedditCSSPath, firefoxRedditCSSPath, "content/reddit.css"]
  ]) {
    if (fs.readFileSync(left, "utf8") !== fs.readFileSync(right, "utf8")) {
      throw new Error(`Chrome and Firefox X tuner parity failed for ${label}.`);
    }
  }
}

function smokeBrowserProcessIDs(userDataDir) {
  let output;
  try {
    output = childProcess.execFileSync("/bin/ps", ["-axo", "pid=,command="], {
      encoding: "utf8"
    });
  } catch {
    return [];
  }

  return output
    .split("\n")
    .map((line) => line.trim())
    .map((line) => {
      const match = line.match(/^(\d+)\s+(.+)$/);
      return match ? { pid: Number(match[1]), command: match[2] } : null;
    })
    .filter(Boolean)
    .filter(({ command }) => command.includes(`--user-data-dir=${userDataDir}`))
    .map(({ pid }) => pid);
}

function killSmokeBrowserProcesses(userDataDir) {
  const terminate = (signal) => {
    for (const pid of smokeBrowserProcessIDs(userDataDir)) {
      try {
        process.kill(pid, signal);
      } catch {
        // The browser may already have exited.
      }
    }
  };

  terminate("SIGTERM");
  try {
    childProcess.execFileSync("/bin/sleep", ["0.5"]);
  } catch {
    // Best-effort cleanup only.
  }
  terminate("SIGKILL");
}

function featureSettings(overrides = {}) {
  return {
    ...FEATURE_DEFAULTS,
    ...overrides
  };
}

function modeFeatureSettings(mode, overrides = {}) {
  if (mode === "strict") {
    return featureSettings(
      Object.fromEntries(Object.keys(FEATURE_DEFAULTS).map((feature) => [feature, true]))
    );
  }

  if (mode === "focus") {
    return featureSettings({
      youtubeHome: true,
      youtubeShorts: true,
      youtubeUsageTracking: true,
      xSensitiveMedia: true,
      xExplicitContent: false,
      xExplicitSearch: false,
      xVideos: true,
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramProfileSuggestions: true,
      instagramMessages: true,
      instagramNotifications: true,
      instagramStories: true,
      redditPopularAll: true,
      redditRecommendations: true,
      redditNSFW: false,
      ...overrides
    });
  }

  return featureSettings(overrides);
}

function strictFeatureSettings() {
  return modeFeatureSettings("strict");
}

function normalizedDomains(domains) {
  return [...new Set(domains.map((domain) => String(domain || "")
    .trim()
    .toLowerCase()
    .replace(/^\*\./, "")
    .replace(/\.$/, ""))
    .filter(Boolean))]
    .sort();
}

function settingsVersionFor(
  mode,
  features,
  blockedDomains,
  options = DEFAULT_OPTIONS,
  blockedCategories = DEFAULT_BLOCKED_CATEGORIES
) {
  const featureToken = Object.entries(features)
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([feature, enabled]) => `${feature}=${enabled ? "1" : "0"}`)
    .join(",");
  const categoryToken = [...new Set(blockedCategories.map((category) => String(category || "").trim()).filter(Boolean))]
    .sort()
    .join(",");
  return `mode=${mode}|features=${featureToken}|domains=${normalizedDomains(blockedDomains).join(",")}|categories=${categoryToken}|options=explicitHideStyle=${options.explicitHideStyle},youtubeDailyLimitMinutes=${options.youtubeDailyLimitMinutes}`;
}

function localDateKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function tuningSettings(
  mode,
  features,
  source = "smoke",
  options = DEFAULT_OPTIONS,
  blockedCategories = DEFAULT_BLOCKED_CATEGORIES
) {
  const mergedFeatures = modeFeatureSettings(mode, features);
  const mergedOptions = { ...DEFAULT_OPTIONS, ...options };
  return {
    mode,
    features: mergedFeatures,
    options: mergedOptions,
    blockedDomains: [],
    blockedCategories,
    settingsVersion: settingsVersionFor(mode, mergedFeatures, [], mergedOptions, blockedCategories),
    source,
    nativeSyncError: null,
    nativeSyncAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
}

function tuningSettingsWithBlocks(
  mode,
  features,
  blockedDomains,
  source = "smoke",
  options = DEFAULT_OPTIONS,
  blockedCategories = DEFAULT_BLOCKED_CATEGORIES
) {
  const mergedFeatures = modeFeatureSettings(mode, features);
  const mergedOptions = { ...DEFAULT_OPTIONS, ...options };
  const domains = normalizedDomains(blockedDomains);
  return {
    mode,
    features: mergedFeatures,
    options: mergedOptions,
    blockedDomains: domains,
    blockedCategories,
    settingsVersion: settingsVersionFor(mode, mergedFeatures, domains, mergedOptions, blockedCategories),
    source,
    nativeSyncError: null,
    nativeSyncAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
}

function youtubeFixtureHTML(urlString) {
  const pathname = new URL(urlString).pathname;

  if (pathname.startsWith("/watch")) {
    return `<!doctype html>
<html>
  <head><title>YouTube Watch Fixture</title></head>
  <body>
    <ytd-masthead id="top-header">top header</ytd-masthead>
    <ytd-watch-flexy>
      <div id="primary">
        <video id="main-video"></video>
        <button id="autoplay-toggle" class="ytp-autonav-toggle-button" aria-checked="true">autoplay</button>
        <div id="end-screen-feed" class="ytp-endscreen-content">end screen feed</div>
        <div id="end-screen" class="ytp-ce-element">end screen card</div>
        <button id="cards-button" class="ytp-cards-button">cards</button>
        <div id="annotation" class="annotation">annotation</div>
        <div id="video-info"><ytd-watch-metadata>video info</ytd-watch-metadata></div>
        <div id="comments">comments</div>
        <ytd-comments id="ytd-comments">more comments</ytd-comments>
        <ytd-donation-shelf-renderer id="fundraiser">fundraiser</ytd-donation-shelf-renderer>
        <ytd-merch-shelf-renderer id="merch">merch and offers</ytd-merch-shelf-renderer>
      </div>
      <div id="secondary">
        <div id="related">recommendations</div>
      </div>
      <ytd-watch-next-secondary-results-renderer id="watch-next">watch next</ytd-watch-next-secondary-results-renderer>
      <ytd-compact-video-renderer id="compact-video">compact video</ytd-compact-video-renderer>
      <ytd-compact-radio-renderer id="watch-mix"><a href="/watch?v=mix&list=RDquietgate">mix</a></ytd-compact-radio-renderer>
      <div id="chat"><ytd-live-chat-frame id="live-chat">live chat</ytd-live-chat-frame></div>
      <div id="playlist"><ytd-playlist-panel-renderer id="playlist-panel">playlist</ytd-playlist-panel-renderer></div>
    </ytd-watch-flexy>
    <script>
      window.quietGateAutoplayClicks = 0;
      document.querySelector("#autoplay-toggle").addEventListener("click", (event) => {
        window.quietGateAutoplayClicks += 1;
        event.currentTarget.setAttribute("aria-checked", "false");
      });
    </script>
  </body>
</html>`;
  }

  if (pathname.startsWith("/shorts")) {
    return `<!doctype html>
<html>
  <head><title>YouTube Shorts Fixture</title></head>
  <body>
    <div id="shorts-page">shorts page</div>
  </body>
</html>`;
  }

  if (pathname.startsWith("/results")) {
    return `<!doctype html>
<html>
  <head><title>YouTube Search Fixture</title></head>
  <body>
    <ytd-search>
      <ytd-video-renderer id="normal-result"><a href="/watch?v=quietgate">normal result</a></ytd-video-renderer>
      <ytd-shelf-renderer id="search-shelf">related to your search</ytd-shelf-renderer>
      <ytd-rich-section-renderer id="search-rich-section">people also search for</ytd-rich-section-renderer>
      <ytd-video-renderer id="search-shorts-video"><a href="/shorts/result">short result</a></ytd-video-renderer>
      <ytd-radio-renderer id="mix-result"><a href="/watch?v=mix&list=RDquietgate">mix result</a></ytd-radio-renderer>
    </ytd-search>
  </body>
</html>`;
  }

  return `<!doctype html>
<html>
  <head><title>YouTube Fixture</title></head>
  <body>
    <ytd-masthead id="top-header">top header</ytd-masthead>
    <ytd-notification-topbar-button-renderer id="notifications">notifications</ytd-notification-topbar-button-renderer>
    <nav>
      <a id="explore-link" href="/feed/explore" title="Explore">Explore</a>
      <a id="trending-link" href="/feed/trending" title="Trending">Trending</a>
      <a id="more-from-youtube" href="/premium" title="YouTube Premium">More from YouTube</a>
      <a id="subscriptions-link" href="/feed/subscriptions">Subscriptions</a>
    </nav>
    <ytd-browse page-subtype="home">
      <ytd-rich-grid-renderer id="home-grid">home feed</ytd-rich-grid-renderer>
      <div id="contents">home contents</div>
    </ytd-browse>
    <a id="shorts-link" href="/shorts/demo">Shorts</a>
    <div id="comments">comments</div>
    <div id="related">recommendations</div>
  </body>
</html>`;
}

function xFixtureHTML() {
  return `<!doctype html>
<html>
  <head>
    <title>X Fixture</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      article { display: block; margin: 12px 0; }
      [data-testid="tweetPhoto"],
      [data-testid="videoComponent"],
      [data-testid="card.wrapper"],
      [data-testid="card.layoutLarge.media"] { display: block; min-height: 12px; }
      img, video { display: block; width: 12px; height: 12px; }
    </style>
  </head>
  <body>
    <a id="explore-link" href="/explore" aria-label="Search and explore">Explore</a>
    <a id="trends-link" href="/i/trends">Trends</a>
    <div id="trend" data-testid="trend">Trending</div>
    <div id="trend-timeline" aria-label="Timeline: Trending now">Trending now</div>

    <div data-testid="cellInnerDiv" id="sensitive-cell">
      <article role="article" id="sensitive-post">
        <img id="sensitive-avatar" src="https://pbs.twimg.com/profile_images/avatar_normal.jpg" alt="avatar">
        <p>Post with X warning.</p>
        <div id="sensitive-media" data-testid="tweetPhoto">
          <span>The following media includes potentially sensitive content.</span>
          <img src="https://pbs.twimg.com/media/sensitive.jpg" alt="sensitive media">
        </div>
      </article>
    </div>

    <article role="article" id="normal-photo-post">
      <img id="normal-avatar" src="https://pbs.twimg.com/profile_images/normal_avatar.jpg" alt="avatar">
      <p>Normal photo post.</p>
      <div id="normal-photo" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/normal-photo.jpg" alt="normal media">
      </div>
    </article>

    <article role="article" id="adult-word-post">
      <p>Again, armed children are being mixed in with adult terrorists.</p>
      <div id="adult-word-photo" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/adult-word.jpg" alt="normal media">
      </div>
    </article>

    <article role="article" id="adult-word-text-post">
      <p>Adult education policy thread with no media.</p>
    </article>

    <article role="article" id="explicit-cue-post">
      <p>Uncensored OnlyFans preview, link in bio.</p>
      <a id="explicit-cue-link" href="https://redgifs.com/watch/quietgate">preview</a>
      <div id="explicit-cue-media" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/explicit-cue.jpg" alt="preview media">
      </div>
    </article>

    <article role="article" id="explicit-hashtag-post">
      <p>#throatpie plunger mouth had him tweakin when he nutted #ThroatFuck #ThroatBulge #ThroatPie</p>
      <div id="explicit-hashtag-media" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/explicit-hashtag.jpg" alt="preview media">
      </div>
    </article>

    <article role="article" id="json-sensitive-post">
      <a href="/quietgate/status/1234567890123456789">JSON flagged post</a>
      <p>Post with no rendered sensitive warning.</p>
      <div id="json-sensitive-media" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/json-sensitive.jpg" alt="visible media">
      </div>
    </article>

    <article role="article" id="json-false-sensitive-post">
      <a href="/quietgate/status/2222222222222222222">JSON false-flagged post</a>
      <p>Post with sensitive-looking metadata explicitly set false.</p>
      <div id="json-false-sensitive-media" data-testid="tweetPhoto">
        <img src="https://pbs.twimg.com/media/json-false-sensitive.jpg" alt="normal media">
      </div>
    </article>

    <article role="article" id="media-key-sensitive-post">
      <p>Post whose X warning arrives through media metadata.</p>
      <div id="media-key-sensitive-media" data-testid="videoComponent">
        <video poster="https://pbs.twimg.com/amplify_video_thumb/3333333333333333333/img/media-key.jpg">
          <source src="https://video.twimg.com/amplify_video/quietgate.mp4">
        </video>
      </div>
    </article>

    <article role="article" id="video-post">
      <p>Video post.</p>
      <div id="video-media" data-testid="videoComponent">
        <video id="tweet-video" src="https://video.twimg.com/ext_tw_video/demo.mp4"></video>
      </div>
    </article>

    <article role="article" id="card-post">
      <p>Card post.</p>
      <div id="card-wrapper" data-testid="card.wrapper">
        <div id="card-media" data-testid="card.layoutLarge.media">
          <img src="https://pbs.twimg.com/card_img/card.jpg" alt="card media">
        </div>
      </div>
    </article>

    <script>
      window.addQuietGateDynamicTweet = () => {
        const article = document.createElement("article");
        article.setAttribute("role", "article");
        article.id = "dynamic-video-post";
        article.innerHTML = '<p>Dynamic video post.</p><div id="dynamic-video-media" data-testid="videoComponent"><video src="https://video.twimg.com/ext_tw_video/dynamic.mp4"></video></div>';
        document.body.appendChild(article);
      };
      window.requestQuietGateSensitivePayload = () => fetch("/i/api/graphql/quietgate/SensitiveFixture").then((response) => response.json());
    </script>
  </body>
</html>`;
}

function xSearchMediaFixtureHTML(url) {
  const searchURL = new URL(url);
  const query = searchURL.searchParams.get("q") || "landscape";
  return `<!doctype html>
<html>
  <head>
    <title>${query} - Search / X</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      main { display: block; }
      nav a { display: inline-block; padding: 8px 12px; }
      #search-media-grid { display: grid; grid-template-columns: repeat(3, 48px); gap: 4px; }
      #search-media-grid a { display: block; min-height: 24px; }
      #search-media-grid img, #search-media-grid video { display: block; width: 48px; height: 48px; }
    </style>
  </head>
  <body>
    <main role="main">
      <label>
        Search
        <input role="searchbox" aria-label="Search query" value="${query}">
      </label>
      <nav aria-label="Search filters">
        <a href="/search?q=${encodeURIComponent(query)}">Latest</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=people">People</a>
        <a aria-selected="true" href="/search?q=${encodeURIComponent(query)}&f=media">Media</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=lists">Lists</a>
      </nav>
      <section id="search-media-grid" aria-label="Timeline: Search timeline">
        <a id="search-media-result-1" href="/whoa/status/4444444444444444444/photo/1">
          <img id="search-media-image-1" src="https://pbs.twimg.com/media/search-media-1.jpg" alt="${query} media result one">
        </a>
        <a id="search-media-result-2" href="/whoa/status/5555555555555555555/photo/1">
          <img id="search-media-image-2" src="https://pbs.twimg.com/media/search-media-2.jpg" alt="${query} media result two">
        </a>
      </section>
    </main>
  </body>
</html>`;
}

function xSearchPeopleFixtureHTML(url) {
  const searchURL = new URL(url);
  const query = searchURL.searchParams.get("q") || "landscape";
  const explicitQuery = /deep\s*throat|throat\s*(?:pie|fuck|bulge)|onlyfans|porn|xxx/i.test(query);
  const people = explicitQuery
    ? [
        {
          id: "search-people-result-1",
          name: "DeepthroatSlushie Top 1%",
          handle: "@DeepthroatMila",
          bio: "Undisputed Deep Throat account. onlyfans.com/mila_slushie"
        },
        {
          id: "search-people-result-2",
          name: "The Deepthroat Society",
          handle: "@Deepthroat17269",
          bio: "Daily explicit clips and DM promos."
        },
        {
          id: "search-people-result-3",
          name: "Deepthroater19",
          handle: "@Deepthroater19",
          bio: "onlyfans.com/deepthroater19"
        }
      ]
    : [
        {
          id: "search-people-result-1",
          name: "Landscape Photographer",
          handle: "@landscapephotos",
          bio: "Outdoor photos and trail notes."
        },
        {
          id: "search-people-result-2",
          name: "Quiet Parks",
          handle: "@quietparks",
          bio: "National park updates and scenic images."
        }
      ];

  const peopleMarkup = people.map((person) => `
        <div data-testid="UserCell" id="${person.id}">
          <img src="https://pbs.twimg.com/profile_images/${person.id}.jpg" alt="${person.name} avatar">
          <strong>${person.name}</strong>
          <span>${person.handle}</span>
          <p>${person.bio}</p>
          <button>Follow</button>
        </div>`).join("");

  return `<!doctype html>
<html>
  <head>
    <title>${query} - People / X</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      main { display: block; }
      nav a { display: inline-block; padding: 8px 12px; }
      [data-testid="UserCell"] { display: block; padding: 12px; min-height: 24px; }
      img { display: inline-block; width: 24px; height: 24px; }
    </style>
  </head>
  <body>
    <main role="main">
      <label>
        Search
        <input role="searchbox" aria-label="Search query" value="${query}">
      </label>
      <nav aria-label="Search filters">
        <a href="/search?q=${encodeURIComponent(query)}">Latest</a>
        <a aria-selected="true" href="/search?q=${encodeURIComponent(query)}&f=people">People</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=media">Media</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=lists">Lists</a>
      </nav>
      <section id="search-people-list" aria-label="Timeline: Search timeline">
        ${peopleMarkup}
      </section>
    </main>
  </body>
</html>`;
}

function xSearchLatestFixtureHTML(url) {
  const searchURL = new URL(url);
  const query = searchURL.searchParams.get("q") || "landscape";
  const explicitQuery = /deep\s*throat|throat\s*(?:pie|fuck|bulge)|onlyfans|porn|xxx/i.test(query);
  const postText = explicitQuery
    ? "#throatpie explicit search post with deepthroat promo text."
    : "Landscape search result with a normal photo walk recap.";
  return `<!doctype html>
<html>
  <head>
    <title>${query} - Latest / X</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      main { display: block; }
      nav a { display: inline-block; padding: 8px 12px; }
      article { display: block; padding: 12px; min-height: 24px; }
    </style>
  </head>
  <body>
    <main role="main">
      <label>
        Search
        <input role="searchbox" aria-label="Search query" value="${query}">
      </label>
      <nav aria-label="Search filters">
        <a aria-selected="true" href="/search?q=${encodeURIComponent(query)}">Latest</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=people">People</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=media">Media</a>
        <a href="/search?q=${encodeURIComponent(query)}&f=lists">Lists</a>
      </nav>
      <section id="search-latest-list" aria-label="Timeline: Search timeline">
        <article role="article" id="search-latest-result-1">
          <p>${postText}</p>
        </article>
        <article role="article" id="search-latest-result-2">
          <p>${explicitQuery ? "Another explicit account result for this search." : "Second normal search result."}</p>
        </article>
      </section>
    </main>
  </body>
</html>`;
}

function xSettingsFixtureHTML() {
  return `<!doctype html>
<html>
  <head><title>X Settings Fixture</title></head>
  <body>
    <main>
      <label id="x-display-sensitive-label">
        Display media that may contain sensitive content
        <input id="x-display-sensitive-toggle" type="checkbox" checked>
      </label>
      <label id="x-hide-sensitive-search-label">
        Hide sensitive content
        <input id="x-hide-sensitive-search-toggle" type="checkbox">
      </label>
    </main>
  </body>
</html>`;
}

function xMediaDenseProfileFixtureHTML() {
  const posts = Array.from({ length: 5 }, (_, index) => {
    const id = index + 1;
    return `
      <article role="article" id="profile-post-${id}">
        <p>${id === 1 ? "Send yes for b🖤🖤bs in dms." : `Profile media post ${id}.`}</p>
        <div id="profile-media-${id}" data-testid="tweetPhoto">
          <img src="https://pbs.twimg.com/media/profile-${id}.jpg" alt="profile media ${id}">
        </div>
      </article>`;
  }).join("");

  return `<!doctype html>
<html>
  <head>
    <title>summer (@summerxiris) / X</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      article { display: block; margin: 12px 0; }
      [data-testid="tweetPhoto"] { display: block; min-height: 12px; }
      img { display: block; width: 12px; height: 12px; }
    </style>
  </head>
  <body>
    <main role="main">
      <a id="profile-banner" href="/summerxiris/header_photo">
        <img src="https://pbs.twimg.com/profile_banners/quietgate/1500x500" alt="profile banner">
      </a>
      <a id="profile-avatar" href="/summerxiris/photo">
        <img src="https://pbs.twimg.com/profile_images/quietgate_400x400.jpg" alt="profile avatar">
      </a>
      <div id="profile-name" data-testid="UserName">summer @summerxiris</div>
      <div id="profile-description" data-testid="UserDescription">i study neuroscience and play valorant :)</div>
      <div id="profile-items" data-testid="UserProfileHeader_Items">
        <a href="https://t.co/quietgate" data-testid="UserUrl">link.me/imsummerxiris</a>
        <a href="/summerxiris/following">246 Following</a>
        <a href="/summerxiris/followers">1M Followers</a>
      </div>
      ${posts}
    </main>
  </body>
</html>`;
}

function xMediaDensePoliticalProfileFixtureHTML() {
  const posts = Array.from({ length: 5 }, (_, index) => {
    const id = index + 1;
    return `
      <article role="article" id="political-profile-post-${id}">
        <p>Campaign event photo ${id} with supporters and policy updates.</p>
        <div id="political-profile-media-${id}" data-testid="tweetPhoto">
          <img src="https://pbs.twimg.com/media/politics-${id}.jpg" alt="campaign media ${id}">
        </div>
      </article>`;
  }).join("");

  return `<!doctype html>
<html>
  <head>
    <title>Spencer Pratt (@spencerpratt) / X</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      article { display: block; margin: 12px 0; }
      [data-testid="tweetPhoto"] { display: block; min-height: 12px; }
      img { display: block; width: 12px; height: 12px; }
    </style>
  </head>
  <body>
    <main role="main">
      <a id="political-profile-banner" href="/spencerpratt/header_photo">
        <img src="https://pbs.twimg.com/profile_banners/politics/1500x500" alt="profile banner">
      </a>
      <a id="political-profile-avatar" href="/spencerpratt/photo">
        <img src="https://pbs.twimg.com/profile_images/politics_400x400.jpg" alt="profile avatar">
      </a>
      <div id="political-profile-name" data-testid="UserName">Spencer Pratt @spencerpratt</div>
      <div id="political-profile-description" data-testid="UserDescription">Public updates, civic issues, and campaign commentary.</div>
      <div id="political-profile-items" data-testid="UserProfileHeader_Items">
        <a href="https://example.com/spencer" data-testid="UserUrl">example.com/spencer</a>
        <a href="/spencerpratt/following">246 Following</a>
        <a href="/spencerpratt/followers">1M Followers</a>
      </div>
      ${posts}
    </main>
  </body>
</html>`;
}

function xSensitiveFixturePayload() {
  return {
    data: {
      home: {
        home_timeline_urt: {
          instructions: [
            {
              entries: [
                {
                  content: {
                    itemContent: {
                      tweet_results: {
                        result: {
                          __typename: "Tweet",
                          rest_id: "1234567890123456789",
                          legacy: {
                            id_str: "1234567890123456789",
                            full_text: "Post with metadata-only sensitive media",
                            possibly_sensitive: true,
                            extended_entities: {
                              media: [
                                {
                                  expanded_url: "https://x.com/quietgate/status/1234567890123456789/photo/1",
                                  media_url_https: "https://pbs.twimg.com/media/json-sensitive.jpg",
                                  sensitive_media_warning: {
                                    adult_content: true,
                                    graphic_violence: false,
                                    other: false
                                  }
                                }
                              ]
                            }
                          }
                        }
                      }
                    }
                  }
                },
                {
                  content: {
                    itemContent: {
                      tweet_results: {
                        result: {
                          __typename: "Tweet",
                          rest_id: "2222222222222222222",
                          mediaVisibilityResults: {
                            result: {
                              adult_content: false,
                              graphic_violence: false,
                              sensitive_media_warning: {
                                adult_content: false,
                                graphic_violence: false,
                                other: false
                              }
                            }
                          },
                          legacy: {
                            id_str: "2222222222222222222",
                            full_text: "Normal media with false sensitive metadata",
                            possibly_sensitive: false,
                            extended_entities: {
                              media: [
                                {
                                  expanded_url: "https://x.com/quietgate/status/2222222222222222222/photo/1",
                                  media_url_https: "https://pbs.twimg.com/media/json-false-sensitive.jpg",
                                  sensitive_media_warning: {
                                    adult_content: false,
                                    graphic_violence: false,
                                    other: false
                                  }
                                }
                              ]
                            }
                          }
                        }
                      }
                    }
                  }
                },
                {
                  content: {
                    itemContent: {
                      tweet_results: {
                        result: {
                          __typename: "Tweet",
                          id: "4444444444444444444",
                          text: "Sensitive media with API v2 id field",
                          possibly_sensitive: true,
                          attachments: {
                            media_keys: ["13_3333333333333333333"]
                          }
                        }
                      }
                    }
                  }
                },
                {
                  content: {
                    itemContent: {
                      tweet_results: {
                        result: {
                          __typename: "Tweet",
                          rest_id: "5555555555555555555",
                          legacy: {
                            id_str: "5555555555555555555",
                            full_text: "Sensitive media keyed by media id",
                            possibly_sensitive: false,
                            extended_entities: {
                              media: [
                                {
                                  id_str: "3333333333333333333",
                                  media_key: "13_3333333333333333333",
                                  sensitive_media_warning: {
                                    adult_content: true,
                                    graphic_violence: false,
                                    other: false
                                  }
                                }
                              ]
                            }
                          }
                        }
                      }
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    }
  };
}

function instagramFixtureHTML() {
  return `<!doctype html>
<html>
  <head>
    <title>Instagram Fixture</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      section, article, nav a { display: block; margin: 8px 0; }
    </style>
  </head>
  <body>
    <nav>
      <a id="ig-home-link" href="/">Home</a>
      <a id="ig-reels-link" href="/reels/" aria-label="Reels">Reels</a>
      <a id="ig-explore-link" href="/explore/" aria-label="Explore">Explore</a>
      <a id="ig-messages-link" href="/direct/inbox/" aria-label="Messages">Messages</a>
      <button id="ig-notifications-button" aria-label="Notifications">Notifications</button>
    </nav>
    <main>
      <section id="ig-stories" aria-label="Stories">
        <a href="/stories/demo"><img src="story.jpg" alt="Stories"></a>
        Stories
      </section>
      <article id="ig-normal-post">
        <p>Normal post from someone you follow.</p>
      </article>
      <article id="ig-suggested-post">
        <p>Suggested for you</p>
        <p>Recommended account post.</p>
      </article>
      <section id="ig-suggested-module">
        <h2>Suggested posts</h2>
        <article>
          <p>Recommended for you</p>
          <button>Follow</button>
        </article>
      </section>
      <article id="ig-ad-post">
        <header>
          <span>celestronuniverse</span>
          <span>Ad</span>
        </header>
        <p>Telescope sale.</p>
      </article>
    </main>
    <aside id="ig-suggested-rail">
      <h2>Suggested for you</h2>
      <div>
        <span>Stephen Grynberg</span>
        <span>Followed by dbeen</span>
        <button>Follow</button>
      </div>
    </aside>
    <section id="ig-profile-suggestions">
      <h2>People you may know</h2>
      <div>
        <span>QuietGate Friend</span>
        <button>Follow</button>
      </div>
    </section>
  </body>
</html>`;
}

function redditFixtureHTML() {
  return `<!doctype html>
<html>
  <head>
    <title>Reddit Fixture</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      article, shreddit-post, .thing, aside, nav a { display: block; margin: 8px 0; }
      figure { display: block; min-height: 12px; }
    </style>
  </head>
  <body>
    <nav>
      <a id="reddit-home-link" href="/">Home</a>
      <a id="reddit-popular-link" href="/r/popular/">Popular</a>
      <a id="reddit-all-link" href="/r/all/">All</a>
    </nav>
    <main>
      <article id="reddit-normal-post">
        <p>Normal text post.</p>
      </article>
      <article id="reddit-recommended-post">
        <p>Recommended because you've shown interest in similar communities.</p>
      </article>
      <article id="reddit-media-post">
        <p>Media post.</p>
        <figure id="reddit-media-surface">
          <img src="https://i.redd.it/demo.jpg" alt="post media">
        </figure>
      </article>
      <shreddit-post id="reddit-nsfw-post" over-18="true" subreddit-prefixed-name="r/pics">
        <p>Native NSFW labeled media post.</p>
        <figure id="reddit-nsfw-media-surface" slot="post-media-container">
          <img src="https://i.redd.it/nsfw.jpg" alt="post media">
        </figure>
      </shreddit-post>
      <div class="thing over18" id="reddit-old-nsfw-post">
        <p>Old Reddit over 18 post.</p>
      </div>
      <article id="reddit-adult-domain-post">
        <p>Adult-domain media link post.</p>
        <a id="reddit-adult-domain-link" href="https://redgifs.com/watch/quietgate">
          <figure id="reddit-adult-domain-media">
            <img src="https://i.redd.it/redgifs-preview.jpg" alt="post media">
          </figure>
        </a>
      </article>
      <article id="reddit-generated-domain-post">
        <p>Generated-list adult-domain media link post.</p>
        <a id="reddit-generated-domain-link" href="https://bongacams.com/quietgate">
          <figure id="reddit-generated-domain-media">
            <img src="https://i.redd.it/generated-domain-preview.jpg" alt="post media">
          </figure>
        </a>
      </article>
      <article id="reddit-search-media-result" data-testid="search-post-unit">
        <p>Search media result.</p>
        <figure id="reddit-search-media-surface">
          <img src="https://preview.redd.it/search-media.jpg" alt="search media">
        </figure>
      </article>
      <faceplate-tracker id="reddit-search-community-result" noun="subreddit" data-testid="subreddit-search-result">
        <a href="/r/gonewildstories/">r/gonewildstories</a>
        <p>Community result card.</p>
      </faceplate-tracker>
      <faceplate-tracker id="reddit-search-user-result" noun="user" data-testid="user-search-result">
        <a href="/user/onlyfans_creator/">OnlyFans creator profile</a>
        <p>Spicy link in bio.</p>
      </faceplate-tracker>
      <article id="reddit-adult-text-only-post">
        <p>OnlyFans policy discussion without media.</p>
      </article>
    </main>
    <aside id="reddit-sidebar" data-testid="right-sidebar">
      Community sidebar
    </aside>
  </body>
</html>`;
}

function redditAdultContextFixtureHTML(url) {
  const parsedURL = new URL(url);
  const subreddit = (parsedURL.pathname.match(/^\/r\/([^/?#]+)/i)?.[1] || "FaceFuck")
    .replace(/</g, "");
  return `<!doctype html>
<html>
  <head>
    <title>r/${subreddit} - Reddit</title>
    <style>
      body { font-family: system-ui, sans-serif; }
      main, article, shreddit-comment, aside, nav a { display: block; margin: 8px 0; }
      figure { display: block; min-height: 12px; }
    </style>
  </head>
  <body>
    <nav>
      <a id="reddit-home-link" href="/">Home</a>
      <a id="reddit-popular-link" href="/r/popular/">Popular</a>
    </nav>
    <main>
      <header id="reddit-adult-community-header">
        <h1 id="reddit-adult-community-title">r/${subreddit}</h1>
        <span id="reddit-adult-community-label">18+ NSFW Adult content</span>
      </header>
      <article id="reddit-adult-thread">
        <p id="reddit-adult-thread-title">Throatpie adult thread title</p>
        <figure id="reddit-adult-thread-media">
          <img src="https://i.redd.it/adult-thread.jpg" alt="adult thread media">
        </figure>
      </article>
      <shreddit-comment id="reddit-adult-comment">
        <p>Explicit adult comment text that should not remain readable.</p>
      </shreddit-comment>
      <div data-testid="comment" id="reddit-adult-nested-comment">
        Adult nested comment that should also be hidden.
      </div>
    </main>
    <aside id="reddit-adult-sidebar" data-testid="right-sidebar">
      <h2>r/${subreddit}</h2>
      <p>Adult content</p>
      <figure id="reddit-adult-sidebar-media">
        <img src="https://preview.redd.it/adult-sidebar.jpg" alt="sidebar media">
      </figure>
    </aside>
  </body>
</html>`;
}

function redditSettingsFixtureHTML() {
  return `<!doctype html>
<html>
  <head><title>Reddit Settings Fixture</title></head>
  <body>
    <main>
      <label id="reddit-show-mature-label">
        Show mature (18+) content
        <input id="reddit-show-mature-toggle" type="checkbox" checked>
      </label>
      <label id="reddit-blur-mature-label">
        Blur mature images and media
        <input id="reddit-blur-mature-toggle" type="checkbox">
      </label>
    </main>
  </body>
</html>`;
}

async function readTuningState(page) {
  return page.evaluate(() => ({
    path: location.pathname,
    classes: [...document.documentElement.classList].sort(),
    marker: document.documentElement.dataset.quietgateTuner || null,
    hiddenCount: document.documentElement.dataset.quietgateYouTubeHiddenCount || null,
    homeDisplay: document.querySelector("#home-grid") ? getComputedStyle(document.querySelector("#home-grid")).display : null,
    shortsDisplay: document.querySelector("#shorts-link") ? getComputedStyle(document.querySelector("#shorts-link")).display : null,
    commentsDisplay: document.querySelector("#comments") ? getComputedStyle(document.querySelector("#comments")).display : null,
    relatedDisplay: document.querySelector("#related") ? getComputedStyle(document.querySelector("#related")).display : null,
    watchNextDisplay: document.querySelector("#watch-next") ? getComputedStyle(document.querySelector("#watch-next")).display : null,
    compactVideoDisplay: document.querySelector("#compact-video") ? getComputedStyle(document.querySelector("#compact-video")).display : null,
    searchShelfDisplay: document.querySelector("#search-shelf") ? getComputedStyle(document.querySelector("#search-shelf")).display : null,
    searchRichSectionDisplay: document.querySelector("#search-rich-section") ? getComputedStyle(document.querySelector("#search-rich-section")).display : null,
    searchShortsDisplay: document.querySelector("#search-shorts-video") ? getComputedStyle(document.querySelector("#search-shorts-video")).display : null,
    mixResultDisplay: document.querySelector("#mix-result") ? getComputedStyle(document.querySelector("#mix-result")).display : null,
    normalSearchDisplay: document.querySelector("#normal-result") ? getComputedStyle(document.querySelector("#normal-result")).display : null,
    topHeaderDisplay: document.querySelector("#top-header") ? getComputedStyle(document.querySelector("#top-header")).display : null,
    notificationsDisplay: document.querySelector("#notifications") ? getComputedStyle(document.querySelector("#notifications")).display : null,
    exploreDisplay: document.querySelector("#explore-link") ? getComputedStyle(document.querySelector("#explore-link")).display : null,
    trendingDisplay: document.querySelector("#trending-link") ? getComputedStyle(document.querySelector("#trending-link")).display : null,
    moreFromYouTubeDisplay: document.querySelector("#more-from-youtube") ? getComputedStyle(document.querySelector("#more-from-youtube")).display : null,
    subscriptionsDisplay: document.querySelector("#subscriptions-link") ? getComputedStyle(document.querySelector("#subscriptions-link")).display : null,
    secondaryDisplay: document.querySelector("#secondary") ? getComputedStyle(document.querySelector("#secondary")).display : null,
    endScreenDisplay: document.querySelector("#end-screen") ? getComputedStyle(document.querySelector("#end-screen")).display : null,
    endScreenFeedDisplay: document.querySelector("#end-screen-feed") ? getComputedStyle(document.querySelector("#end-screen-feed")).display : null,
    cardsButtonDisplay: document.querySelector("#cards-button") ? getComputedStyle(document.querySelector("#cards-button")).display : null,
    annotationDisplay: document.querySelector("#annotation") ? getComputedStyle(document.querySelector("#annotation")).display : null,
    fundraiserDisplay: document.querySelector("#fundraiser") ? getComputedStyle(document.querySelector("#fundraiser")).display : null,
    merchDisplay: document.querySelector("#merch") ? getComputedStyle(document.querySelector("#merch")).display : null,
    videoInfoDisplay: document.querySelector("#video-info") ? getComputedStyle(document.querySelector("#video-info")).display : null,
    watchMixDisplay: document.querySelector("#watch-mix") ? getComputedStyle(document.querySelector("#watch-mix")).display : null,
    chatDisplay: document.querySelector("#chat") ? getComputedStyle(document.querySelector("#chat")).display : null,
    playlistDisplay: document.querySelector("#playlist") ? getComputedStyle(document.querySelector("#playlist")).display : null,
    autoplayChecked: document.querySelector("#autoplay-toggle")?.getAttribute("aria-checked") || null,
    autoplayClicks: window.quietGateAutoplayClicks || 0,
    mainVideoDisplay: document.querySelector("#main-video") ? getComputedStyle(document.querySelector("#main-video")).display : null,
    shortsPageDisplay: document.querySelector("#shorts-page") ? getComputedStyle(document.querySelector("#shorts-page")).display : null
  }));
}

async function readXState(page) {
  return page.evaluate(() => {
    const display = (selector) => {
      const node = document.querySelector(selector);
      return node ? getComputedStyle(node).display : null;
    };

    return {
      path: location.pathname,
      classes: [...document.documentElement.classList].sort(),
      marker: document.documentElement.dataset.quietgateXTuner || null,
      hiddenCount: document.documentElement.dataset.quietgateXHiddenMediaCount || null,
      sensitivePostCount: document.documentElement.dataset.quietgateXSensitivePostCount || null,
      sensitiveMediaCount: document.documentElement.dataset.quietgateXSensitiveMediaCount || null,
      explicitPostCount: document.documentElement.dataset.quietgateXExplicitPostCount || null,
      searchMediaCount: document.documentElement.dataset.quietgateXSearchMediaCount || null,
      searchResultCount: document.documentElement.dataset.quietgateXSearchResultCount || null,
      bodyText: document.body?.innerText || "",
      sensitiveMediaDisplay: display("#sensitive-media"),
      jsonSensitiveMediaDisplay: display("#json-sensitive-media"),
      jsonFalseSensitiveMediaDisplay: display("#json-false-sensitive-media"),
      mediaKeySensitiveMediaDisplay: display("#media-key-sensitive-media"),
      normalPhotoDisplay: display("#normal-photo"),
      adultWordPhotoDisplay: display("#adult-word-photo"),
      adultWordTextPostDisplay: display("#adult-word-text-post"),
      explicitCuePostDisplay: display("#explicit-cue-post"),
      explicitCueMediaDisplay: display("#explicit-cue-media"),
      explicitHashtagPostDisplay: display("#explicit-hashtag-post"),
      explicitHashtagMediaDisplay: display("#explicit-hashtag-media"),
      explicitCuePlaceholderDisplay: display(".qg-x-explicit-placeholder"),
      profilePostDisplay: display("#profile-post-1"),
      profileMediaDisplay: display("#profile-media-1"),
      videoMediaDisplay: display("#video-media"),
      cardWrapperDisplay: display("#card-wrapper"),
      dynamicVideoDisplay: display("#dynamic-video-media"),
      normalAvatarDisplay: display("#normal-avatar"),
      sensitiveAvatarDisplay: display("#sensitive-avatar"),
      exploreDisplay: display("#explore-link"),
      trendsLinkDisplay: display("#trends-link"),
      trendDisplay: display("#trend"),
      trendTimelineDisplay: display("#trend-timeline"),
      searchMediaResultDisplay: display("#search-media-result-1"),
      searchMediaImageDisplay: display("#search-media-image-1"),
      searchPeopleResultDisplay: display("#search-people-result-1"),
      searchLatestResultDisplay: display("#search-latest-result-1"),
      explicitSearchPlaceholderDisplay: display(".qg-x-explicit-search-placeholder")
    };
  });
}

async function readInstagramState(page) {
  return page.evaluate(() => {
    const display = (selector) => {
      const node = document.querySelector(selector);
      return node ? getComputedStyle(node).display : null;
    };
    return {
      path: location.pathname,
      classes: [...document.documentElement.classList].sort(),
      marker: document.documentElement.dataset.quietgateInstagramTuner || null,
      hiddenCount: document.documentElement.dataset.quietgateInstagramHiddenCount || null,
      reelsDisplay: display("#ig-reels-link"),
      exploreDisplay: display("#ig-explore-link"),
      messagesDisplay: display("#ig-messages-link"),
      notificationsDisplay: display("#ig-notifications-button"),
      storiesDisplay: display("#ig-stories"),
      suggestedDisplay: display("#ig-suggested-post"),
      suggestedModuleDisplay: display("#ig-suggested-module"),
      suggestedRailDisplay: display("#ig-suggested-rail"),
      profileSuggestionsDisplay: display("#ig-profile-suggestions"),
      adPostDisplay: display("#ig-ad-post"),
      normalPostDisplay: display("#ig-normal-post")
    };
  });
}

async function readRedditState(page) {
  return page.evaluate(() => {
    const display = (selector) => {
      const node = document.querySelector(selector);
      return node ? getComputedStyle(node).display : null;
    };
    return {
      path: location.pathname,
      classes: [...document.documentElement.classList].sort(),
      marker: document.documentElement.dataset.quietgateRedditTuner || null,
      hiddenCount: document.documentElement.dataset.quietgateRedditHiddenCount || null,
      nsfwCount: document.documentElement.dataset.quietgateRedditNSFWCount || null,
      adultContext: document.documentElement.dataset.quietgateRedditAdultContext || null,
      lastDecision: document.documentElement.dataset.quietgateRedditLastDecision || null,
      popularDisplay: display("#reddit-popular-link"),
      allDisplay: display("#reddit-all-link"),
      recommendedDisplay: display("#reddit-recommended-post"),
      mediaDisplay: display("#reddit-media-surface"),
      nsfwPostDisplay: display("#reddit-nsfw-post"),
      nsfwMediaDisplay: display("#reddit-nsfw-media-surface"),
      oldNSFWPostDisplay: display("#reddit-old-nsfw-post"),
      adultDomainPostDisplay: display("#reddit-adult-domain-post"),
      adultDomainMediaDisplay: display("#reddit-adult-domain-media"),
      adultTextOnlyPostDisplay: display("#reddit-adult-text-only-post"),
      nsfwPlaceholderDisplay: display(".qg-reddit-nsfw-placeholder"),
      adultContextShellDisplay: display(".qg-reddit-adult-context-shell"),
      adultCommunityHeaderDisplay: display("#reddit-adult-community-header"),
      adultThreadDisplay: display("#reddit-adult-thread"),
      adultCommentDisplay: display("#reddit-adult-comment"),
      adultSidebarDisplay: display("#reddit-adult-sidebar"),
      adultSidebarMediaDisplay: display("#reddit-adult-sidebar-media"),
      sidebarDisplay: display("#reddit-sidebar"),
      normalPostDisplay: display("#reddit-normal-post")
    };
  });
}

async function readBlockedState(page) {
  return page.evaluate(() => ({
    blocked: document.documentElement.dataset.quietgateBlocked === "true",
    domain: document.documentElement.dataset.quietgateBlockedDomain || null,
    quietGateBlockPage: location.href.includes("/blocked/blocked.html"),
    title: document.title,
    text: document.body?.innerText || ""
  }));
}

async function verifyPopupManagedState(context) {
  const popup = await context.newPage();
  try {
    await popup.goto(`chrome-extension://${EXTENSION_ID}/popup/popup.html`, { waitUntil: "domcontentloaded" });
    await popup.waitForFunction(() => document.querySelector("#syncStatus")?.dataset.state === "managed", null, { timeout: 10000 });
    const state = await popup.evaluate(() => ({
      status: document.querySelector("#syncStatus")?.textContent,
      modeDisabled: document.querySelector("#mode")?.disabled,
      featureDisabled: document.querySelector("#youtubeComments")?.disabled,
      optionDisabled: document.querySelector("#explicitHideStyle")?.disabled,
      limitMinutesDisabled: document.querySelector("#youtubeDailyLimitMinutes")?.disabled
    }));
    if (!/^Connected(\.| in\b)/.test(state.status || "") || !state.modeDisabled || !state.featureDisabled || !state.optionDisabled || !state.limitMinutesDisabled) {
      throw new Error(`Popup managed state mismatch: ${JSON.stringify(state)}`);
    }
  } finally {
    await popup.close();
  }
}

async function applySmokeSettings(worker, settings) {
  await worker.evaluate(async (nextSettings) => {
    const normalized = typeof normalizeSettings === "function"
      ? normalizeSettings(nextSettings)
      : nextSettings;
    const blockedRuleCount = typeof applyDynamicBlockRules === "function"
      ? await applyDynamicBlockRules(normalized)
      : 0;

    await chrome.storage.local.set({
      ...normalized,
      blockedRuleCount,
      source: nextSettings.source || "smoke",
      nativeSyncError: null,
      nativeSyncAt: new Date().toISOString()
    });
  }, settings);
}

async function applyCurrentSmokeSettings(worker, settingsPath, settings) {
  if (process.env.QG_SMOKE_WITH_NATIVE) {
    writeJSON(settingsPath, settings);
    await worker.evaluate(async (expectedSettingsVersion) => {
      for (let attempt = 0; attempt < 5; attempt += 1) {
        await syncNativeSettings();
        const stored = await chrome.storage.local.get({ settingsVersion: null });
        if (stored.settingsVersion === expectedSettingsVersion) {
          return;
        }
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
      const stored = await chrome.storage.local.get(null);
      throw new Error(`Native sync did not apply ${expectedSettingsVersion}: ${JSON.stringify(stored)}`);
    }, settings.settingsVersion);
  } else {
    await applySmokeSettings(worker, settings);
  }
}

async function waitForPlatformControlAudit(worker) {
  return worker.evaluate(async () => {
    for (let attempt = 0; attempt < 50; attempt += 1) {
      const stored = await chrome.storage.local.get({ platformControls: {} });
      const platformControls = stored.platformControls || {};
      if (
        platformControls?.x?.displaySensitiveMedia === true &&
        platformControls?.x?.hideSensitiveSearch === false &&
        platformControls?.reddit?.showMatureContent === true &&
        platformControls?.reddit?.blurMatureMedia === false
      ) {
        return platformControls;
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    const stored = await chrome.storage.local.get({ platformControls: {} });
    throw new Error(`Platform control audit did not record X/Reddit settings: ${JSON.stringify(stored.platformControls || {})}`);
  });
}

async function resetYouTubeUsage(worker) {
  await worker.evaluate(async (today) => {
    await chrome.storage.local.set({
      youtubeUsage: {
        date: today,
        totalSeconds: 0,
        lifetimeSeconds: 0,
        videoCount: 0,
        lifetimeVideoCount: 0,
        countedVideoIDs: [],
        lastUpdatedAt: null,
        limitHitAt: null
      }
    });
  }, localDateKey());
}

async function waitForTrackedYouTubeUsage(worker, videoID) {
  return worker.evaluate(async (expectedVideoID) => {
    for (let attempt = 0; attempt < 18; attempt += 1) {
      const stored = await chrome.storage.local.get({ youtubeUsage: null });
      const usage = stored.youtubeUsage || {};
      if (
        Number(usage.totalSeconds || 0) >= 10 &&
        Number(usage.videoCount || 0) >= 1 &&
        Array.isArray(usage.countedVideoIDs) &&
        usage.countedVideoIDs.includes(expectedVideoID)
      ) {
        return usage;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
    const stored = await chrome.storage.local.get({ youtubeUsage: null });
    return stored.youtubeUsage;
  }, videoID);
}

async function waitForYouTubeLimitSnapshot(worker) {
  return worker.evaluate(async () => {
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const settings = typeof currentStoredSettings === "function"
        ? await currentStoredSettings()
        : null;
      const snapshot = typeof youtubeUsageSnapshot === "function"
        ? await youtubeUsageSnapshot(settings)
        : null;
      const stored = await chrome.storage.local.get({ youtubeUsage: null });
      const usage = stored.youtubeUsage || {};
      if (
        snapshot?.limitReached === true &&
        snapshot.limitSeconds === 1800 &&
        Number(usage.videoCount || 0) === 7 &&
        typeof usage.limitHitAt === "string"
      ) {
        return { snapshot, usage };
      }
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    const settings = typeof currentStoredSettings === "function"
      ? await currentStoredSettings()
      : null;
    const snapshot = typeof youtubeUsageSnapshot === "function"
      ? await youtubeUsageSnapshot(settings)
      : null;
    const stored = await chrome.storage.local.get({ youtubeUsage: null });
    return { snapshot, usage: stored.youtubeUsage };
  });
}

async function waitForNativeYouTubeUsage(statusPath, expectedVideoCount) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (fs.existsSync(statusPath)) {
      const status = readJSONFile(statusPath);
      const usage = status.youtubeUsage;
      if (
        usage &&
        Number(usage.videoCount || 0) >= expectedVideoCount &&
        Number(usage.totalSeconds || 0) >= 10
      ) {
        return usage;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  const status = fs.existsSync(statusPath) ? readJSONFile(statusPath) : null;
  throw new Error(`Native status did not record YouTube usage: ${JSON.stringify(status)}`);
}

async function main() {
  if (SMOKE_BROWSER === "chrome" && !fs.existsSync(CHROME_PATH)) {
    throw new Error(`Google Chrome was not found at ${CHROME_PATH}.`);
  }
  verifyExtensionXPageDetectorSurface();
  childProcess.execFileSync(path.join(ROOT_DIR, "script", "build_native_host.sh"), { stdio: "inherit" });

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "quietgate-chrome-"));
  const bridgeHomeDir = os.homedir();
  const userDataDir = path.join(tempDir, "profile");
  const nativeHostPath = process.env.QG_SMOKE_WITH_NATIVE
    ? path.join(tempDir, "quietgate-native-host")
    : SOURCE_NATIVE_HOST;
  const nativeHostDebugLog = "/tmp/quietgate-native-host-debug.log";
  fs.writeFileSync(nativeHostDebugLog, "");
  mkdirp(userDataDir);
  if (process.env.QG_SMOKE_WITH_NATIVE) {
    fs.copyFileSync(SOURCE_NATIVE_HOST, nativeHostPath);
  }

  const settingsPath = path.join(bridgeHomeDir, "Library", "Application Support", "QuietGate", "extension-settings.json");
  const statusPath = path.join(bridgeHomeDir, "Library", "Application Support", "QuietGate", "chrome-status.json");
  const nativeManifestPaths = [
    path.join(
      bridgeHomeDir,
      "Library",
      "Application Support",
      "Google",
      "Chrome",
      "NativeMessagingHosts",
      `${HOST_NAME}.json`
    ),
    path.join(
      bridgeHomeDir,
      "Library",
      "Application Support",
      "Chromium",
      "NativeMessagingHosts",
      `${HOST_NAME}.json`
    ),
    path.join(
      bridgeHomeDir,
      "Library",
      "Application Support",
      "Google",
      "Chrome for Testing",
      "NativeMessagingHosts",
      `${HOST_NAME}.json`
    ),
    path.join(
      userDataDir,
      "NativeMessagingHosts",
      `${HOST_NAME}.json`
    ),
    path.join(
      userDataDir,
      "Default",
      "NativeMessagingHosts",
      `${HOST_NAME}.json`
    )
  ];

  const restoreFiles = [
    settingsPath,
    statusPath,
    ...(process.env.QG_SMOKE_WITH_NATIVE ? nativeManifestPaths : [])
  ].map((filePath) => ({
    filePath,
    existed: fs.existsSync(filePath),
    data: fs.existsSync(filePath) ? fs.readFileSync(filePath) : null
  }));

  if (process.env.QG_SMOKE_WITH_NATIVE) {
    writeJSON(settingsPath, tuningSettings("strict", strictFeatureSettings(), "native-smoke"));

    for (const nativeManifestPath of nativeManifestPaths) {
      writeJSON(nativeManifestPath, {
        name: HOST_NAME,
        description: "QuietGate Chrome settings bridge",
        path: nativeHostPath,
        type: "stdio",
        allowed_origins: [`chrome-extension://${EXTENSION_ID}/`]
      });
    }
  }

  fs.chmodSync(nativeHostPath, 0o755);

  let context;
  let page;
  try {
    context = await chromium.launchPersistentContext(userDataDir, {
      ...(SMOKE_BROWSER === "chrome" ? { executablePath: CHROME_PATH } : {}),
      headless: false,
      args: [
        `--load-extension=${EXTENSION_DIR}`,
        `--disable-extensions-except=${EXTENSION_DIR}`,
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-background-networking"
      ]
    });

    page = await context.newPage();
    if (!process.env.QG_SMOKE_LIVE_YOUTUBE) {
      await page.route("https://www.youtube.com/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: youtubeFixtureHTML(route.request().url())
        });
      });
      await page.route("https://x.com/**", async (route) => {
        if (new URL(route.request().url()).pathname.startsWith("/settings/")) {
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body: xSettingsFixtureHTML()
          });
          return;
        }

        if (route.request().url().includes("/i/api/graphql/quietgate/SensitiveFixture")) {
          await route.fulfill({
            status: 200,
            contentType: "application/json; charset=utf-8",
            body: JSON.stringify(xSensitiveFixturePayload())
          });
          return;
        }

        const xPathname = new URL(route.request().url()).pathname;
        if (
          xPathname === "/summerxiris" ||
          xPathname === "/summerxiris/with_replies" ||
          xPathname === "/summerxiris/media" ||
          xPathname === "/summerxiris/highlights" ||
          xPathname === "/summerxiris/articles"
        ) {
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body: xMediaDenseProfileFixtureHTML()
          });
          return;
        }

        if (xPathname === "/search") {
          const searchFilter = (new URL(route.request().url()).searchParams.get("f") || "").toLowerCase();
          let body;
          if (searchFilter === "media") {
            body = xSearchMediaFixtureHTML(route.request().url());
          } else if (searchFilter === "people" || searchFilter === "user" || searchFilter === "users") {
            body = xSearchPeopleFixtureHTML(route.request().url());
          } else {
            body = xSearchLatestFixtureHTML(route.request().url());
          }
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body
          });
          return;
        }

        if (xPathname === "/spencerpratt" || xPathname === "/spencerpratt/with_replies") {
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body: xMediaDensePoliticalProfileFixtureHTML()
          });
          return;
        }

        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: xFixtureHTML(route.request().url())
        });
      });
      await page.route("https://www.instagram.com/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: instagramFixtureHTML(route.request().url())
        });
      });
      await page.route("https://www.reddit.com/**", async (route) => {
        const redditURL = new URL(route.request().url());
        if (redditURL.pathname.startsWith("/settings/")) {
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body: redditSettingsFixtureHTML()
          });
          return;
        }

        if (/^\/r\/(?:facefuck|gonewild)(?:\/|$)/i.test(redditURL.pathname)) {
          await route.fulfill({
            status: 200,
            contentType: "text/html; charset=utf-8",
            body: redditAdultContextFixtureHTML(route.request().url())
          });
          return;
        }

        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: redditFixtureHTML(route.request().url())
        });
      });
      await page.route("https://blocked.example/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: "<!doctype html><title>Blocked Fixture</title><main>should not be visible</main>"
        });
      });
      await page.route("https://adult-signal.example/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: `<!doctype html>
            <html>
              <head>
                <title>Free XXX Porn Videos and Live Adult Cams</title>
                <meta name="description" content="Hardcore porn tube with nude videos, cam girls, and explicit adult content.">
              </head>
              <body>
                <h1>XXX porn videos</h1>
                <a href="https://onlyfans.com/example">OnlyFans</a>
                <a href="https://redgifs.com/watch/example">Redgifs</a>
                <main id="adult-page">explicit fixture should be blocked</main>
              </body>
            </html>`
        });
      });
      await page.route("https://www.redgifs.com/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: "<!doctype html><title>Redgifs Fixture</title><main id=\"redgifs-live-page\">redgifs should not be visible</main>"
        });
      });
      await page.route("https://benign-adult.example/**", async (route) => {
        await route.fulfill({
          status: 200,
          contentType: "text/html; charset=utf-8",
          body: `<!doctype html>
            <html>
              <head>
                <title>Adult education and sexual health research</title>
                <meta name="description" content="Medical sexual health research and adult learning resources.">
              </head>
              <body>
                <h1>Adult education policy</h1>
                <main id="benign-page">breast cancer prevention and sex education news</main>
              </body>
            </html>`
        });
      });
    }

    await page.goto("https://www.youtube.com/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.documentElement.dataset.quietgateTuner === "loaded");

    const worker = context.serviceWorkers()[0] || await context.waitForEvent("serviceworker", { timeout: 5000 });
    if (!process.env.QG_SMOKE_WITH_NATIVE) {
      await applySmokeSettings(worker, tuningSettings(
        "strict",
        strictFeatureSettings()
      ));
    }

    if (process.env.QG_SMOKE_DIRECT_NATIVE) {
      console.error("direct native:", JSON.stringify(await worker.evaluate(() => new Promise((resolve) => {
        const timeout = setTimeout(() => resolve({
          response: null,
          error: "Timed out waiting for native message callback."
        }), 5000);
        chrome.runtime.sendNativeMessage(
          "com.willpulier.quietgate",
          { type: "getSettings" },
          (response) => {
            clearTimeout(timeout);
            resolve({
              response,
              error: chrome.runtime.lastError?.message || null
            });
          }
        );
      }))));
    }

    if (!process.env.QG_SMOKE_LIVE_YOUTUBE) {
      await page.goto("https://x.com/settings/content_you_see", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgatePlatformControls === "checked"
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/settings/preferences", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgatePlatformControls === "checked"
      ), null, { timeout: 25000 });

      await waitForPlatformControlAudit(worker);

      await page.goto("https://www.youtube.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => document.documentElement.dataset.quietgateTuner === "loaded");
    }

    if (process.env.QG_SMOKE_LIVE_YOUTUBE) {
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-home") &&
        document.documentElement.classList.contains("qg-youtube-video-sidebar") &&
        document.documentElement.classList.contains("qg-youtube-shorts") &&
        document.documentElement.classList.contains("qg-youtube-comments") &&
        document.documentElement.classList.contains("qg-youtube-recommendations") &&
        document.documentElement.classList.contains("qg-youtube-search") &&
        document.documentElement.classList.contains("qg-youtube-end-screens") &&
        document.documentElement.classList.contains("qg-youtube-end-screen-cards") &&
        document.documentElement.classList.contains("qg-youtube-live-chat") &&
        document.documentElement.classList.contains("qg-youtube-autoplay") &&
        document.documentElement.classList.contains("qg-youtube-playlists") &&
        document.documentElement.classList.contains("qg-youtube-fundraisers") &&
        document.documentElement.classList.contains("qg-youtube-mixes") &&
        document.documentElement.classList.contains("qg-youtube-merch") &&
        document.documentElement.classList.contains("qg-youtube-video-info") &&
        document.documentElement.classList.contains("qg-youtube-top-header") &&
        document.documentElement.classList.contains("qg-youtube-notifications") &&
        document.documentElement.classList.contains("qg-youtube-explore") &&
        document.documentElement.classList.contains("qg-youtube-more-from-youtube") &&
        document.documentElement.classList.contains("qg-youtube-subscriptions") &&
        document.documentElement.classList.contains("qg-youtube-annotations") &&
        document.documentElement.classList.contains("qg-youtube-usage-tracking") &&
        document.documentElement.classList.contains("qg-youtube-daily-limit")
      ), null, { timeout: 25000 });
    } else {
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-home") &&
        document.documentElement.classList.contains("qg-youtube-video-sidebar") &&
        document.documentElement.classList.contains("qg-youtube-shorts") &&
        document.documentElement.classList.contains("qg-youtube-comments") &&
        document.documentElement.classList.contains("qg-youtube-recommendations") &&
        document.documentElement.classList.contains("qg-youtube-search") &&
        document.documentElement.classList.contains("qg-youtube-end-screens") &&
        document.documentElement.classList.contains("qg-youtube-end-screen-cards") &&
        document.documentElement.classList.contains("qg-youtube-live-chat") &&
        document.documentElement.classList.contains("qg-youtube-autoplay") &&
        document.documentElement.classList.contains("qg-youtube-playlists") &&
        document.documentElement.classList.contains("qg-youtube-fundraisers") &&
        document.documentElement.classList.contains("qg-youtube-mixes") &&
        document.documentElement.classList.contains("qg-youtube-merch") &&
        document.documentElement.classList.contains("qg-youtube-video-info") &&
        document.documentElement.classList.contains("qg-youtube-top-header") &&
        document.documentElement.classList.contains("qg-youtube-notifications") &&
        document.documentElement.classList.contains("qg-youtube-explore") &&
        document.documentElement.classList.contains("qg-youtube-more-from-youtube") &&
        document.documentElement.classList.contains("qg-youtube-subscriptions") &&
        document.documentElement.classList.contains("qg-youtube-annotations") &&
        document.documentElement.classList.contains("qg-youtube-usage-tracking") &&
        document.documentElement.classList.contains("qg-youtube-daily-limit") &&
        Number(document.documentElement.dataset.quietgateYouTubeHiddenCount || 0) >= 10 &&
        getComputedStyle(document.querySelector("#home-grid")).display === "none" &&
        getComputedStyle(document.querySelector("#shorts-link")).display === "none" &&
        getComputedStyle(document.querySelector("#comments")).display === "none" &&
        getComputedStyle(document.querySelector("#related")).display === "none" &&
        getComputedStyle(document.querySelector("#top-header")).display === "none" &&
        getComputedStyle(document.querySelector("#notifications")).display === "none" &&
        getComputedStyle(document.querySelector("#explore-link")).display === "none" &&
        getComputedStyle(document.querySelector("#trending-link")).display === "none" &&
        getComputedStyle(document.querySelector("#more-from-youtube")).display === "none" &&
        getComputedStyle(document.querySelector("#subscriptions-link")).display === "none" &&
        document.querySelector("#quietgate-youtube-usage")?.textContent.includes("Today")
      ), null, { timeout: 25000 });

      await page.goto("https://www.youtube.com/results?search_query=quietgate", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-search") &&
        getComputedStyle(document.querySelector("#normal-result")).display !== "none" &&
        getComputedStyle(document.querySelector("#search-shelf")).display === "none" &&
        getComputedStyle(document.querySelector("#search-rich-section")).display === "none" &&
        getComputedStyle(document.querySelector("#search-shorts-video")).display === "none" &&
        getComputedStyle(document.querySelector("#mix-result")).display === "none"
      ), null, { timeout: 25000 });

      await resetYouTubeUsage(worker);
      await page.goto("https://www.youtube.com/watch?v=quietgate", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-comments") &&
        document.documentElement.classList.contains("qg-youtube-video-sidebar") &&
        document.documentElement.classList.contains("qg-youtube-recommendations") &&
        document.documentElement.classList.contains("qg-youtube-end-screens") &&
        document.documentElement.classList.contains("qg-youtube-end-screen-cards") &&
        document.documentElement.classList.contains("qg-youtube-live-chat") &&
        document.documentElement.classList.contains("qg-youtube-autoplay") &&
        document.documentElement.classList.contains("qg-youtube-playlists") &&
        document.documentElement.classList.contains("qg-youtube-fundraisers") &&
        document.documentElement.classList.contains("qg-youtube-mixes") &&
        document.documentElement.classList.contains("qg-youtube-merch") &&
        document.documentElement.classList.contains("qg-youtube-video-info") &&
        document.documentElement.classList.contains("qg-youtube-top-header") &&
        document.documentElement.classList.contains("qg-youtube-annotations") &&
        document.documentElement.classList.contains("qg-youtube-usage-tracking") &&
        document.documentElement.classList.contains("qg-youtube-daily-limit") &&
        Number(document.documentElement.dataset.quietgateYouTubeHiddenCount || 0) >= 12 &&
        getComputedStyle(document.querySelector("#main-video")).display !== "none" &&
        getComputedStyle(document.querySelector("#comments")).display === "none" &&
        getComputedStyle(document.querySelector("#ytd-comments")).display === "none" &&
        getComputedStyle(document.querySelector("#secondary")).display === "none" &&
        getComputedStyle(document.querySelector("#related")).display === "none" &&
        getComputedStyle(document.querySelector("#watch-next")).display === "none" &&
        getComputedStyle(document.querySelector("#compact-video")).display === "none" &&
        getComputedStyle(document.querySelector("#watch-mix")).display === "none" &&
        getComputedStyle(document.querySelector("#end-screen-feed")).display === "none" &&
        getComputedStyle(document.querySelector("#end-screen")).display === "none" &&
        getComputedStyle(document.querySelector("#cards-button")).display === "none" &&
        getComputedStyle(document.querySelector("#annotation")).display === "none" &&
        getComputedStyle(document.querySelector("#fundraiser")).display === "none" &&
        getComputedStyle(document.querySelector("#merch")).display === "none" &&
        getComputedStyle(document.querySelector("#video-info")).display === "none" &&
        getComputedStyle(document.querySelector("#top-header")).display === "none" &&
        getComputedStyle(document.querySelector("#chat")).display === "none" &&
        getComputedStyle(document.querySelector("#playlist")).display === "none" &&
        document.querySelector("#autoplay-toggle").getAttribute("aria-checked") === "false" &&
        window.quietGateAutoplayClicks === 1
      ), null, { timeout: 25000 });
      const trackedYouTubeUsage = await waitForTrackedYouTubeUsage(worker, "quietgate");
      if (
        !trackedYouTubeUsage ||
        Number(trackedYouTubeUsage.totalSeconds || 0) < 10 ||
        Number(trackedYouTubeUsage.videoCount || 0) < 1 ||
        !Array.isArray(trackedYouTubeUsage.countedVideoIDs) ||
        !trackedYouTubeUsage.countedVideoIDs.includes("quietgate")
      ) {
        throw new Error(`YouTube watch tracking did not count the visible video: ${JSON.stringify(trackedYouTubeUsage)}`);
      }
      if (process.env.QG_SMOKE_WITH_NATIVE) {
        await waitForNativeYouTubeUsage(statusPath, 1);
      }

      await page.goto("https://www.youtube.com/shorts/quietgate", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        !location.pathname.startsWith("/shorts")
      ), null, { timeout: 25000 });

      await page.goto("https://www.youtube.com/feed/trending", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        !location.pathname.startsWith("/feed/trending")
      ), null, { timeout: 25000 });

      await page.goto("https://www.youtube.com/feed/subscriptions", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        !location.pathname.startsWith("/feed/subscriptions")
      ), null, { timeout: 25000 });

      await worker.evaluate(async (today) => {
        await chrome.storage.local.set({
          youtubeUsage: {
            date: today,
            totalSeconds: 1800,
            lifetimeSeconds: 1800,
            videoCount: 7,
            lifetimeVideoCount: 7,
            countedVideoIDs: ["quietgate"],
            lastUpdatedAt: new Date().toISOString(),
            limitHitAt: null
          }
        });
      }, localDateKey());
      await page.goto("https://www.youtube.com/watch?v=quietgate-limit", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-limit-reached") &&
        document.querySelector("#quietgate-youtube-limit")?.textContent.includes("limit reached") &&
        document.querySelector("#quietgate-youtube-limit")?.textContent.includes("7 videos") &&
        document.querySelector("#quietgate-youtube-usage")?.textContent.includes("7 videos") &&
        getComputedStyle(document.querySelector("#main-video")).visibility === "hidden"
      ), null, { timeout: 25000 });
      const limitSnapshot = await waitForYouTubeLimitSnapshot(worker);
      if (
        limitSnapshot?.snapshot?.limitReached !== true ||
        limitSnapshot.snapshot.limitSeconds !== 1800 ||
        Number(limitSnapshot.snapshot.videoCount || 0) !== 7 ||
        typeof limitSnapshot?.usage?.limitHitAt !== "string"
      ) {
        throw new Error(`YouTube limit snapshot was not durable: ${JSON.stringify(limitSnapshot)}`);
      }

      const commentsOnlySettings = tuningSettings(
        "open",
        {
          youtubeComments: true
        }
      );
      if (process.env.QG_SMOKE_WITH_NATIVE) {
        writeJSON(settingsPath, commentsOnlySettings);
        await worker.evaluate(() => syncNativeSettings());
      } else {
        await applySmokeSettings(worker, commentsOnlySettings);
      }

      await page.goto("https://www.youtube.com/watch?v=quietgate-custom", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        document.documentElement.classList.contains("qg-youtube-comments") &&
        !document.documentElement.classList.contains("qg-youtube-recommendations") &&
        Number(document.documentElement.dataset.quietgateYouTubeHiddenCount || 0) >= 1 &&
        getComputedStyle(document.querySelector("#main-video")).display !== "none" &&
        getComputedStyle(document.querySelector("#comments")).display === "none" &&
        getComputedStyle(document.querySelector("#related")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("focus", {}));
      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-sensitive-media") &&
        document.documentElement.classList.contains("qg-x-videos") &&
        !document.documentElement.classList.contains("qg-x-explicit-content") &&
        !document.documentElement.classList.contains("qg-x-photos") &&
        !document.documentElement.classList.contains("qg-x-media-cards") &&
        getComputedStyle(document.querySelector("#sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#video-media")).display === "none" &&
        getComputedStyle(document.querySelector("#json-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-text-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXExplicitPostCount || 0) >= 2 &&
        getComputedStyle(document.querySelector("#card-wrapper")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-avatar")).display !== "none" &&
        getComputedStyle(document.querySelector("#sensitive-avatar")).display !== "none" &&
        !document.body.innerText.includes("QuietGate hid sensitive X media")
      ), null, { timeout: 25000 });

      await page.evaluate(() => window.requestQuietGateSensitivePayload());
      await page.waitForFunction(() => (
        Number(document.documentElement.dataset.quietgateXSensitivePostCount || 0) >= 2 &&
        Number(document.documentElement.dataset.quietgateXSensitiveMediaCount || 0) >= 1 &&
        getComputedStyle(document.querySelector("#json-sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#json-false-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xExplicitContent: true }));
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        Number(document.documentElement.dataset.quietgateXExplicitPostCount || 0) >= 2 &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display === "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-text-post")).display !== "none" &&
        !document.querySelector(".qg-x-explicit-placeholder")
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/search?q=throatpie&src=typed_query&f=media", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#search-media-result-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXSearchMediaCount || 0) >= 2 &&
        getComputedStyle(document.querySelector(".qg-x-explicit-search-placeholder")).display !== "none" &&
        document.body.innerText.includes("QuietGate blocked explicit media results")
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/search?q=landscape&src=typed_query&f=media", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#search-media-result-1")).display !== "none" &&
        document.documentElement.dataset.quietgateXSearchMediaCount === "0" &&
        !document.querySelector(".qg-x-explicit-search-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xPhotos: true }));
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-photos") &&
        !document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#search-media-result-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXSearchMediaCount || 0) >= 2 &&
        !document.querySelector(".qg-x-explicit-search-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xExplicitContent: true }));
      await page.goto("https://x.com/search?q=deepthroat&src=typed_query&f=people", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        !document.documentElement.classList.contains("qg-x-explicit-search") &&
        getComputedStyle(document.querySelector("#search-people-result-1")).display !== "none" &&
        document.documentElement.dataset.quietgateXSearchResultCount === "0" &&
        !document.querySelector(".qg-x-explicit-search-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xExplicitSearch: true }));
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-explicit-search") &&
        !document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#search-people-result-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXSearchResultCount || 0) >= 2 &&
        getComputedStyle(document.querySelector(".qg-x-explicit-search-placeholder")).display !== "none" &&
        document.body.innerText.includes("QuietGate blocked explicit search results")
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/search?q=deepthroat&src=typed_query", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-search") &&
        getComputedStyle(document.querySelector("#search-latest-result-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXSearchResultCount || 0) >= 2 &&
        getComputedStyle(document.querySelector(".qg-x-explicit-search-placeholder")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/search?q=deepthroat&src=typed_query&f=media", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-search") &&
        !document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#search-media-result-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXSearchMediaCount || 0) >= 2 &&
        getComputedStyle(document.querySelector(".qg-x-explicit-search-placeholder")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/search?q=landscape&src=typed_query&f=people", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-search") &&
        getComputedStyle(document.querySelector("#search-people-result-1")).display !== "none" &&
        document.documentElement.dataset.quietgateXSearchResultCount === "0" &&
        !document.querySelector(".qg-x-explicit-search-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xExplicitContent: true }));
      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content")
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/summerxiris", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#profile-banner")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-avatar")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-name")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-description")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-items")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-post-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXExplicitPostCount || 0) >= 5
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/summerxiris/with_replies", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#profile-post-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXProfileFallbackPostCount || 0) >= 5
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/spencerpratt", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#political-profile-banner")).display !== "none" &&
        getComputedStyle(document.querySelector("#political-profile-post-1")).display !== "none" &&
        document.documentElement.dataset.quietgateXProfileFallbackPostCount === "0"
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/summerxiris/media", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#profile-post-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXProfileFallbackPostCount || 0) >= 5
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(
        worker,
        settingsPath,
        tuningSettings("open", { xExplicitContent: true }, "smoke", { explicitHideStyle: "media" })
      );
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#profile-banner")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-avatar")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-name")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-post-1")).display === "none" &&
        getComputedStyle(document.querySelector("#profile-media-1")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXHiddenMediaCount || 0) >= 5
      ), null, { timeout: 25000 });

      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-media")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-media")).display === "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        !document.querySelector(".qg-x-explicit-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(
        worker,
        settingsPath,
        tuningSettings("open", { xExplicitContent: true }, "smoke", { explicitHideStyle: "placeholder" })
      );
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector(".qg-x-explicit-placeholder")).display !== "none" &&
        document.body.innerText.includes("QuietGate blocked explicit content")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("focus", {}));
      await page.evaluate(() => window.addQuietGateDynamicTweet());
      await page.waitForFunction(() => (
        getComputedStyle(document.querySelector("#dynamic-video-media")).display === "none" &&
        Number(document.documentElement.dataset.quietgateXHiddenMediaCount || 0) >= 3
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("strict", {}));
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-sensitive-media") &&
        document.documentElement.classList.contains("qg-x-explicit-content") &&
        document.documentElement.classList.contains("qg-x-explicit-search") &&
        document.documentElement.classList.contains("qg-x-videos") &&
        document.documentElement.classList.contains("qg-x-photos") &&
        document.documentElement.classList.contains("qg-x-media-cards") &&
        document.documentElement.classList.contains("qg-x-explore-trends") &&
        getComputedStyle(document.querySelector("#sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#video-media")).display === "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display === "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector("#json-false-sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#card-wrapper")).display === "none" &&
        getComputedStyle(document.querySelector("#normal-avatar")).display !== "none" &&
        getComputedStyle(document.querySelector("#explore-link")).display === "none" &&
        getComputedStyle(document.querySelector("#trends-link")).display === "none" &&
        getComputedStyle(document.querySelector("#trend")).display === "none" &&
        getComputedStyle(document.querySelector("#trend-timeline")).display === "none"
      ), null, { timeout: 25000 });

      const requestBlockRules = await worker.evaluate(() => (
        chrome.declarativeNetRequest.getDynamicRules().then((rules) => rules
          .filter((rule) => rule.action?.type === "block")
          .map((rule) => ({
            urlFilter: rule.condition?.urlFilter || "",
            resourceTypes: rule.condition?.resourceTypes || [],
            initiatorDomains: rule.condition?.initiatorDomains || []
          })))
      ));
      const xMediaRules = requestBlockRules.filter((rule) => (
        rule.urlFilter.includes("twimg.com") || rule.urlFilter.includes("twitpic.com") || rule.urlFilter.includes("video.twimg.com") || rule.urlFilter.includes("cards-frame.twitter.com")
      ));
      const xMediaRuleFilters = xMediaRules.map((rule) => rule.urlFilter).sort();
      for (const expectedFilter of ["||video.twimg.com^", "||pbs.twimg.com/media/", "||pbs.twimg.com/card_img/"]) {
        if (!xMediaRuleFilters.includes(expectedFilter)) {
          throw new Error(`Missing X media dynamic rule ${expectedFilter}: ${JSON.stringify(xMediaRules)}`);
        }
      }
      if (!xMediaRules.every((rule) => rule.initiatorDomains.includes("x.com") && rule.initiatorDomains.includes("twitter.com"))) {
        throw new Error(`X media dynamic rules were not scoped to X/Twitter initiators: ${JSON.stringify(xMediaRules)}`);
      }
      const socialAdultRules = requestBlockRules.filter((rule) => rule.urlFilter === "||redgifs.com^");
      if (
        !socialAdultRules.some((rule) => rule.initiatorDomains.includes("x.com") && rule.initiatorDomains.includes("twitter.com")) ||
        !socialAdultRules.some((rule) => rule.initiatorDomains.includes("reddit.com") && rule.initiatorDomains.includes("www.reddit.com")) ||
        !socialAdultRules.every((rule) => rule.initiatorDomains.length > 0)
      ) {
        throw new Error(`Adult preview dynamic rules were not scoped to X/Reddit initiators: ${JSON.stringify(socialAdultRules)}`);
      }

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", {}));
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        ![...document.documentElement.classList].some((className) => className.startsWith("qg-x-")) &&
        document.documentElement.dataset.quietgateXHiddenMediaCount === "0" &&
        getComputedStyle(document.querySelector("#sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#video-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-text-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-media")).display !== "none" &&
        !document.querySelector(".qg-x-explicit-placeholder") &&
        getComputedStyle(document.querySelector("#json-false-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#media-key-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#card-wrapper")).display !== "none" &&
        getComputedStyle(document.querySelector("#explore-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#trend")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { xSensitiveMedia: true }));
      await page.goto("https://x.com/home", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateXTuner === "loaded" &&
        document.documentElement.classList.contains("qg-x-sensitive-media") &&
        !document.documentElement.classList.contains("qg-x-videos") &&
        getComputedStyle(document.querySelector("#sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#json-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#media-key-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#video-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-text-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display === "none"
      ), null, { timeout: 25000 });

      await page.evaluate(() => window.requestQuietGateSensitivePayload());
      await page.waitForFunction(() => (
        Number(document.documentElement.dataset.quietgateXSensitivePostCount || 0) >= 2 &&
        Number(document.documentElement.dataset.quietgateXSensitiveMediaCount || 0) >= 1 &&
        getComputedStyle(document.querySelector("#json-sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#media-key-sensitive-media")).display === "none" &&
        getComputedStyle(document.querySelector("#json-false-sensitive-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#video-media")).display !== "none" &&
        getComputedStyle(document.querySelector("#normal-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-photo")).display !== "none" &&
        getComputedStyle(document.querySelector("#adult-word-text-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#explicit-cue-post")).display === "none" &&
        getComputedStyle(document.querySelector("#explicit-hashtag-post")).display === "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", {}));

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("focus", {}));
      await page.goto("https://www.instagram.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        document.documentElement.classList.contains("qg-instagram-reels") &&
        document.documentElement.classList.contains("qg-instagram-explore") &&
        document.documentElement.classList.contains("qg-instagram-suggested") &&
        document.documentElement.classList.contains("qg-instagram-profile-suggestions") &&
        document.documentElement.classList.contains("qg-instagram-messages") &&
        document.documentElement.classList.contains("qg-instagram-notifications") &&
        document.documentElement.classList.contains("qg-instagram-stories") &&
        Number(document.documentElement.dataset.quietgateInstagramHiddenCount || 0) >= 9 &&
        getComputedStyle(document.querySelector("#ig-reels-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-explore-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-messages-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-notifications-button")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-module")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-rail")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-profile-suggestions")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-ad-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-stories")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-normal-post")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://www.instagram.com/reels/demo", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        !location.pathname.startsWith("/reels")
      ), null, { timeout: 25000 });

      await page.goto("https://www.instagram.com/explore/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        !location.pathname.startsWith("/explore")
      ), null, { timeout: 25000 });

      await page.goto("https://www.instagram.com/direct/inbox/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        !location.pathname.startsWith("/direct")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("strict", {}));
      await page.goto("https://www.instagram.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        document.documentElement.classList.contains("qg-instagram-reels") &&
        document.documentElement.classList.contains("qg-instagram-explore") &&
        document.documentElement.classList.contains("qg-instagram-suggested") &&
        document.documentElement.classList.contains("qg-instagram-profile-suggestions") &&
        document.documentElement.classList.contains("qg-instagram-messages") &&
        document.documentElement.classList.contains("qg-instagram-notifications") &&
        document.documentElement.classList.contains("qg-instagram-stories") &&
        Number(document.documentElement.dataset.quietgateInstagramHiddenCount || 0) >= 9 &&
        getComputedStyle(document.querySelector("#ig-reels-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-explore-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-messages-link")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-notifications-button")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-module")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-rail")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-profile-suggestions")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-ad-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-stories")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-normal-post")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", {}));
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        ![...document.documentElement.classList].some((className) => className.startsWith("qg-instagram-")) &&
        document.documentElement.dataset.quietgateInstagramHiddenCount === "0" &&
        getComputedStyle(document.querySelector("#ig-reels-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-explore-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-messages-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-notifications-button")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-module")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-rail")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-profile-suggestions")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-ad-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-stories")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { instagramSuggested: true }));
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateInstagramTuner === "loaded" &&
        document.documentElement.classList.contains("qg-instagram-suggested") &&
        !document.documentElement.classList.contains("qg-instagram-profile-suggestions") &&
        !document.documentElement.classList.contains("qg-instagram-messages") &&
        !document.documentElement.classList.contains("qg-instagram-notifications") &&
        getComputedStyle(document.querySelector("#ig-suggested-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-module")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-ad-post")).display === "none" &&
        getComputedStyle(document.querySelector("#ig-suggested-rail")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-profile-suggestions")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-messages-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-notifications-button")).display !== "none" &&
        getComputedStyle(document.querySelector("#ig-stories")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", {}));

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("focus", {}));
      await page.goto("https://www.reddit.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-popular-all") &&
        document.documentElement.classList.contains("qg-reddit-recommendations") &&
        !document.documentElement.classList.contains("qg-reddit-nsfw") &&
        !document.documentElement.classList.contains("qg-reddit-media") &&
        !document.documentElement.classList.contains("qg-reddit-sidebars") &&
        getComputedStyle(document.querySelector("#reddit-popular-link")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-all-link")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-recommended-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-media-surface")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-sidebar")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-normal-post")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/r/popular/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        !/^\/r\/popular/i.test(location.pathname)
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/r/all/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        !/^\/r\/all/i.test(location.pathname)
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", { redditNSFW: true }));
      await page.goto("https://www.reddit.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        Number(document.documentElement.dataset.quietgateRedditNSFWCount || 0) >= 3 &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-old-nsfw-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-media-surface")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-text-only-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-normal-post")).display !== "none" &&
        !document.querySelector(".qg-reddit-nsfw-placeholder")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(
        worker,
        settingsPath,
        tuningSettings("focus", { redditNSFW: false }, "smoke", DEFAULT_OPTIONS, ["adultContent"])
      );
      await page.goto("https://www.reddit.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        Number(document.documentElement.dataset.quietgateRedditAdultDomainCount || 0) > 1000 &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-generated-domain-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-text-only-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-normal-post")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/search/?q=onlyfans&type=media", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        document.documentElement.dataset.quietgateRedditAdultContext === "explicit-search-query" &&
        getComputedStyle(document.querySelector(".qg-reddit-adult-context-shell")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-search-media-result")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-search-community-result")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-search-user-result")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-normal-post")).display === "none" &&
        document.body.innerText.includes("Adult Reddit content blocked")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(
        worker,
        settingsPath,
        tuningSettings("open", { redditNSFW: true }, "smoke", { explicitHideStyle: "media" })
      );
      await page.goto("https://www.reddit.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-nsfw-media-surface")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-media")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-old-nsfw-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-media-surface")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(
        worker,
        settingsPath,
        tuningSettings("open", { redditNSFW: true }, "smoke", { explicitHideStyle: "placeholder" })
      );
      await page.waitForFunction(() => (
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display === "none" &&
        getComputedStyle(document.querySelector(".qg-reddit-nsfw-placeholder")).display !== "none" &&
        document.body.innerText.includes("QuietGate blocked NSFW content")
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/r/gonewild/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        /^\/r\/gonewild/i.test(location.pathname) &&
        document.documentElement.dataset.quietgateRedditAdultContext === "adult-subreddit" &&
        getComputedStyle(document.querySelector(".qg-reddit-adult-context-shell")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-community-header")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-thread")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-comment")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-sidebar")).display === "none" &&
        document.body.innerText.includes("Adult Reddit content blocked")
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/r/FaceFuck/comments/quietgate/throatpie/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        document.documentElement.dataset.quietgateRedditAdultContext === "adult-subreddit" &&
        document.documentElement.dataset.quietgateRedditLastDecision.includes("adult-subreddit") &&
        getComputedStyle(document.querySelector(".qg-reddit-adult-context-shell")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-community-header")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-thread")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-comment")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-nested-comment")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-sidebar")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-sidebar-media")).display === "none" &&
        document.body.innerText.includes("Adult Reddit content blocked") &&
        !document.body.innerText.includes("Explicit adult comment text")
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("strict", {}));
      await page.goto("https://www.reddit.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.classList.contains("qg-reddit-popular-all") &&
        document.documentElement.classList.contains("qg-reddit-recommendations") &&
        document.documentElement.classList.contains("qg-reddit-nsfw") &&
        document.documentElement.classList.contains("qg-reddit-media") &&
        document.documentElement.classList.contains("qg-reddit-sidebars") &&
        Number(document.documentElement.dataset.quietgateRedditHiddenCount || 0) >= 5 &&
        getComputedStyle(document.querySelector("#reddit-popular-link")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-all-link")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-recommended-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-media-surface")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-sidebar")).display === "none" &&
        getComputedStyle(document.querySelector("#reddit-normal-post")).display !== "none"
      ), null, { timeout: 25000 });

      await applyCurrentSmokeSettings(worker, settingsPath, tuningSettings("open", {}));
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        ![...document.documentElement.classList].some((className) => className.startsWith("qg-reddit-")) &&
        document.documentElement.dataset.quietgateRedditHiddenCount === "0" &&
        getComputedStyle(document.querySelector("#reddit-popular-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-all-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-recommended-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-media-surface")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-nsfw-post")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-domain-post")).display !== "none" &&
        !document.querySelector(".qg-reddit-nsfw-placeholder") &&
        getComputedStyle(document.querySelector("#reddit-sidebar")).display !== "none"
      ), null, { timeout: 25000 });

      await page.goto("https://www.reddit.com/r/FaceFuck/comments/quietgate/throatpie/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateRedditTuner === "loaded" &&
        document.documentElement.dataset.quietgateRedditAdultContext === "none" &&
        !document.querySelector(".qg-reddit-adult-context-shell") &&
        getComputedStyle(document.querySelector("#reddit-adult-community-header")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-thread")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-comment")).display !== "none" &&
        getComputedStyle(document.querySelector("#reddit-adult-sidebar")).display !== "none"
      ), null, { timeout: 25000 });

      const blockedSettings = tuningSettingsWithBlocks(
        "open",
        {},
        ["blocked.example"]
      );
      if (process.env.QG_SMOKE_WITH_NATIVE) {
        writeJSON(settingsPath, blockedSettings);
        await worker.evaluate(() => syncNativeSettings());
      } else {
        await applySmokeSettings(worker, blockedSettings);
      }

      await page.goto("https://blocked.example/path", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        location.href.startsWith("chrome-extension://fedpnejbgmllajjlfkahlnjbgfmjjmmf/blocked/blocked.html") &&
        document.title === "QuietGate blocked this site" &&
        document.body.innerText.includes("This site is blocked") &&
        document.body.innerText.includes("QuietGate rules")
      ), null, { timeout: 25000 });

      const adultCategorySettings = tuningSettings(
        "focus",
        {},
        "smoke",
        DEFAULT_OPTIONS,
        ["adultContent"]
      );
      if (process.env.QG_SMOKE_WITH_NATIVE) {
        writeJSON(settingsPath, adultCategorySettings);
        await worker.evaluate(() => syncNativeSettings({ forceApply: true }));
      } else {
        await applySmokeSettings(worker, adultCategorySettings);
      }

      const enabledAdultRulesets = await worker.evaluate(() => (
        chrome.declarativeNetRequest.getEnabledRulesets()
      ));
      if (!enabledAdultRulesets.includes("adult-static-1")) {
        throw new Error(`Adult static DNR ruleset was not enabled: ${JSON.stringify(enabledAdultRulesets)}`);
      }

      await page.goto("https://www.redgifs.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        location.href.startsWith("chrome-extension://fedpnejbgmllajjlfkahlnjbgfmjjmmf/blocked/blocked.html") &&
        document.title === "QuietGate blocked this site" &&
        document.body.innerText.includes("This site is blocked") &&
        !document.querySelector("#redgifs-live-page")
      ), null, { timeout: 25000 });

      const legacyAdultSettings = tuningSettingsWithBlocks(
        "focus",
        {},
        ["pornhub.com"],
        "smoke",
        DEFAULT_OPTIONS,
        []
      );
      if (process.env.QG_SMOKE_WITH_NATIVE) {
        writeJSON(settingsPath, legacyAdultSettings);
        await worker.evaluate(() => syncNativeSettings({ forceApply: true }));
      } else {
        await applySmokeSettings(worker, legacyAdultSettings);
      }
      const legacyAdultRulesets = await worker.evaluate(() => (
        chrome.declarativeNetRequest.getEnabledRulesets()
      ));
      if (!legacyAdultRulesets.includes("adult-static-1")) {
        throw new Error(`Legacy adult seed settings did not enable static adult rules: ${JSON.stringify(legacyAdultRulesets)}`);
      }

      await page.goto("https://www.redgifs.com/", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        location.href.startsWith("chrome-extension://fedpnejbgmllajjlfkahlnjbgfmjjmmf/blocked/blocked.html") &&
        document.title === "QuietGate blocked this site" &&
        document.body.innerText.includes("This site is blocked") &&
        !document.querySelector("#redgifs-live-page")
      ), null, { timeout: 25000 });

      if (process.env.QG_SMOKE_WITH_NATIVE) {
        writeJSON(settingsPath, adultCategorySettings);
        await worker.evaluate(() => syncNativeSettings({ forceApply: true }));
      } else {
        await applySmokeSettings(worker, adultCategorySettings);
      }

      await page.goto("https://adult-signal.example/path", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateWebAdultBlocked === "true" &&
        document.body.innerText.includes("Adult content blocked") &&
        document.body.innerText.includes("QuietGate blocked this page")
      ), null, { timeout: 25000 });
      await page.click('[data-qg-action="report"]');
      await page.waitForFunction(() => (
        document.querySelector('[data-qg-action="report"]')?.textContent === "Saved"
      ), null, { timeout: 25000 });
      const reportedAdultSites = await worker.evaluate(() => (
        chrome.storage.local.get({ missedAdultSites: [] }).then((stored) => stored.missedAdultSites)
      ));
      if (!reportedAdultSites.some((report) => report.domain === "adult-signal.example")) {
        throw new Error(`Missed adult site report was not stored: ${JSON.stringify(reportedAdultSites)}`);
      }

      await page.goto("https://benign-adult.example/research", { waitUntil: "domcontentloaded" });
      await page.waitForFunction(() => (
        document.querySelector("#benign-page") &&
        document.documentElement.dataset.quietgateWebAdultBlocked !== "true" &&
        document.body.innerText.includes("breast cancer prevention")
      ), null, { timeout: 25000 });
    }

    const openSettings = tuningSettings(
      "open",
      {}
    );
    if (process.env.QG_SMOKE_WITH_NATIVE) {
      writeJSON(settingsPath, openSettings);
      await worker.evaluate(() => syncNativeSettings());
      await verifyPopupManagedState(context);
    } else {
      await applySmokeSettings(worker, openSettings);
    }

    if (!process.env.QG_SMOKE_LIVE_YOUTUBE) {
      await page.goto("https://www.youtube.com/", { waitUntil: "domcontentloaded" });
    }

    if (process.env.QG_SMOKE_LIVE_YOUTUBE) {
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        ![...document.documentElement.classList].some((className) => className.startsWith("qg-youtube-"))
      ), null, { timeout: 30000 });
    } else {
      await page.waitForFunction(() => (
        document.documentElement.dataset.quietgateTuner === "loaded" &&
        ![...document.documentElement.classList].some((className) => className.startsWith("qg-youtube-")) &&
        document.documentElement.dataset.quietgateYouTubeHiddenCount === "0" &&
        getComputedStyle(document.querySelector("#home-grid")).display !== "none" &&
        getComputedStyle(document.querySelector("#shorts-link")).display !== "none" &&
        getComputedStyle(document.querySelector("#comments")).display !== "none" &&
        getComputedStyle(document.querySelector("#related")).display !== "none"
      ), null, { timeout: 30000 });
    }

    const state = await readTuningState(page);
    console.log("chrome extension smoke ok", JSON.stringify(state));
  } catch (error) {
    if (context) {
      const workers = context.serviceWorkers();
      console.error("service workers:", workers.map((worker) => worker.url()));
      if (workers[0]) {
        try {
          console.error("extension storage:", JSON.stringify(await workers[0].evaluate(() => chrome.storage.local.get(null))));
        } catch (storageError) {
          console.error("extension storage unavailable:", storageError.message);
        }
      }
    }
    if (page) {
      try {
        console.error("page:", page.url(), JSON.stringify(await readTuningState(page)));
        if (page.url().startsWith("https://x.com/")) {
          console.error("x page:", JSON.stringify(await readXState(page)));
        }
        if (page.url().startsWith("https://www.instagram.com/")) {
          console.error("instagram page:", JSON.stringify(await readInstagramState(page)));
        }
        if (page.url().startsWith("https://www.reddit.com/")) {
          console.error("reddit page:", JSON.stringify(await readRedditState(page)));
        }
        console.error("blocked:", JSON.stringify(await readBlockedState(page)));
      } catch (stateError) {
        console.error("page state unavailable:", stateError.message);
      }
    }
    if (fs.existsSync(nativeHostDebugLog)) {
      console.error("native host log:", fs.readFileSync(nativeHostDebugLog, "utf8"));
    } else {
      console.error("native host log: <missing>");
    }
    throw error;
  } finally {
    if (context) {
      await context.close();
    }
    killSmokeBrowserProcesses(userDataDir);
    for (const item of restoreFiles) {
      if (item.existed) {
        mkdirp(path.dirname(item.filePath));
        fs.writeFileSync(item.filePath, item.data);
      } else {
        fs.rmSync(item.filePath, { force: true });
      }
    }
    fs.rmSync(tempDir, { recursive: true, force: true });
    fs.rmSync(nativeHostDebugLog, { force: true });
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
