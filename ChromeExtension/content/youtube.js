const TUNER_VERSION = "2026.06.12.01";

const DEFAULT_SETTINGS = {
  mode: "open",
  features: {
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
    youtubeDailyLimit: false
  },
  options: {
    explicitHideStyle: "post",
    youtubeDailyLimitMinutes: 30
  },
  youtubeUsage: null,
  blockedDomains: []
};

const FEATURE_CLASSES = {
  youtubeHome: "qg-youtube-home",
  youtubeVideoSidebar: "qg-youtube-video-sidebar",
  youtubeShorts: "qg-youtube-shorts",
  youtubeComments: "qg-youtube-comments",
  youtubeRecommendations: "qg-youtube-recommendations",
  youtubeSearch: "qg-youtube-search",
  youtubeEndScreens: "qg-youtube-end-screens",
  youtubeEndScreenCards: "qg-youtube-end-screen-cards",
  youtubeLiveChat: "qg-youtube-live-chat",
  youtubeAutoplay: "qg-youtube-autoplay",
  youtubePlaylists: "qg-youtube-playlists",
  youtubeFundraisers: "qg-youtube-fundraisers",
  youtubeMixes: "qg-youtube-mixes",
  youtubeMerch: "qg-youtube-merch",
  youtubeVideoInfo: "qg-youtube-video-info",
  youtubeTopHeader: "qg-youtube-top-header",
  youtubeNotifications: "qg-youtube-notifications",
  youtubeExplore: "qg-youtube-explore",
  youtubeMoreFromYouTube: "qg-youtube-more-from-youtube",
  youtubeSubscriptions: "qg-youtube-subscriptions",
  youtubeAnnotations: "qg-youtube-annotations",
  youtubeUsageTracking: "qg-youtube-usage-tracking",
  youtubeDailyLimit: "qg-youtube-daily-limit"
};

let currentSettings = DEFAULT_SETTINGS;
let currentUsage = null;
let syncInFlight = false;
let applyQueued = false;
let trackingTimer = null;
let lastTrackingTick = null;
let pendingVideoID = null;
let pendingVideoVisibleSeconds = 0;
let lastUsageReportAt = 0;
let limitHitReported = false;

document.documentElement.dataset.quietgateTuner = "loaded";
document.documentElement.dataset.quietgateTunerVersion = TUNER_VERSION;

function mergedSettings(value) {
  return {
    mode: value.mode || DEFAULT_SETTINGS.mode,
    features: {
      ...DEFAULT_SETTINGS.features,
      ...(value.features || {})
    },
    options: {
      ...DEFAULT_SETTINGS.options,
      ...(value.options || {})
    }
  };
}

function modeFeatures(mode) {
  if (mode === "strict") {
    return {
      youtubeHome: true,
      youtubeVideoSidebar: true,
      youtubeShorts: true,
      youtubeComments: true,
      youtubeRecommendations: true,
      youtubeSearch: true,
      youtubeEndScreens: true,
      youtubeEndScreenCards: true,
      youtubeLiveChat: true,
      youtubeAutoplay: true,
      youtubePlaylists: true,
      youtubeFundraisers: true,
      youtubeMixes: true,
      youtubeMerch: true,
      youtubeVideoInfo: true,
      youtubeTopHeader: true,
      youtubeNotifications: true,
      youtubeExplore: true,
      youtubeMoreFromYouTube: true,
      youtubeSubscriptions: true,
      youtubeAnnotations: true,
      youtubeUsageTracking: true,
      youtubeDailyLimit: true
    };
  }

  if (mode === "focus") {
    return {
      youtubeHome: true,
      youtubeVideoSidebar: false,
      youtubeShorts: true,
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
      youtubeUsageTracking: true,
      youtubeDailyLimit: false
    };
  }

  return {
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
    youtubeDailyLimit: false
  };
}

function effectiveFeatures(settings) {
  return {
    ...modeFeatures(settings.mode),
    ...settings.features
  };
}

function applySettings() {
  const features = effectiveFeatures(currentSettings);

  for (const [feature, className] of Object.entries(FEATURE_CLASSES)) {
    document.documentElement.classList.toggle(className, Boolean(features[feature]));
  }

  if (features.youtubeShorts && location.pathname.startsWith("/shorts")) {
    location.replace("https://www.youtube.com/");
  }

  if (features.youtubeExplore && /^\/feed\/(?:explore|trending)/.test(location.pathname)) {
    location.replace("https://www.youtube.com/");
  }

  if (features.youtubeSubscriptions && location.pathname.startsWith("/feed/subscriptions")) {
    location.replace("https://www.youtube.com/");
  }

  if (features.youtubeAutoplay) {
    disableAutoplay();
  }

  if (usageTrackingEnabled(features)) {
    startUsageTracking();
  } else {
    stopUsageTracking();
  }
  applyUsageUI(features);
}

function disableAutoplay() {
  const button = [
    ".ytp-autonav-toggle-button[aria-checked=\"true\"]",
    "button.ytp-autonav-toggle-button[aria-checked=\"true\"]",
    "button[aria-label*=\"Autoplay is on\"]",
    "button[title*=\"Autoplay is on\"]"
  ].map((selector) => document.querySelector(selector)).find(Boolean);

  if (button) {
    button.click();
  }
}

function localDateKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function clampedLimitMinutes(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return DEFAULT_SETTINGS.options.youtubeDailyLimitMinutes;
  }
  return Math.min(Math.max(Math.round(parsed), 5), 480);
}

function emptyUsage(date = localDateKey(), previous = {}) {
  return {
    date,
    totalSeconds: 0,
    lifetimeSeconds: Math.max(Number(previous.lifetimeSeconds) || 0, 0),
    videoCount: 0,
    lifetimeVideoCount: Math.max(Number(previous.lifetimeVideoCount) || 0, 0),
    countedVideoIDs: [],
    lastUpdatedAt: null,
    limitHitAt: null
  };
}

function normalizedUsage(value) {
  const today = localDateKey();
  if (!value || typeof value !== "object" || value.date !== today) {
    return emptyUsage(today, value || {});
  }

  return {
    date: today,
    totalSeconds: Math.max(Number(value.totalSeconds) || 0, 0),
    lifetimeSeconds: Math.max(Number(value.lifetimeSeconds) || 0, 0),
    videoCount: Math.max(Number(value.videoCount) || 0, 0),
    lifetimeVideoCount: Math.max(Number(value.lifetimeVideoCount) || 0, 0),
    countedVideoIDs: Array.isArray(value.countedVideoIDs)
      ? value.countedVideoIDs.map((id) => String(id || "")).filter(Boolean).slice(-500)
      : [],
    lastUpdatedAt: typeof value.lastUpdatedAt === "string" ? value.lastUpdatedAt : null,
    limitHitAt: typeof value.limitHitAt === "string" ? value.limitHitAt : null
  };
}

function usageTrackingEnabled(features) {
  return Boolean(features.youtubeUsageTracking || features.youtubeDailyLimit);
}

function dailyLimitSeconds(features) {
  if (!features.youtubeDailyLimit) {
    return null;
  }
  return clampedLimitMinutes(currentSettings.options?.youtubeDailyLimitMinutes) * 60;
}

function usageLimitReached(features) {
  const limitSeconds = dailyLimitSeconds(features);
  return Boolean(limitSeconds && currentUsage && currentUsage.totalSeconds >= limitSeconds);
}

function publicUsageSnapshot(features = effectiveFeatures(currentSettings)) {
  const usage = normalizedUsage(currentUsage);
  const limitSeconds = dailyLimitSeconds(features);
  return {
    date: usage.date,
    totalSeconds: Math.floor(usage.totalSeconds),
    lifetimeSeconds: Math.floor(usage.lifetimeSeconds),
    videoCount: usage.videoCount,
    lifetimeVideoCount: usage.lifetimeVideoCount,
    limitSeconds,
    limitReached: Boolean(limitSeconds && usage.totalSeconds >= limitSeconds),
    lastUpdatedAt: usage.lastUpdatedAt
  };
}

function currentVideoID() {
  if (location.pathname.startsWith("/watch")) {
    return new URL(location.href).searchParams.get("v") || null;
  }
  const shortsMatch = location.pathname.match(/^\/shorts\/([^/?#]+)/);
  return shortsMatch ? decodeURIComponent(shortsMatch[1]) : null;
}

function recordVisibleVideoTime(elapsedSeconds) {
  const videoID = currentVideoID();
  if (!videoID) {
    pendingVideoID = null;
    pendingVideoVisibleSeconds = 0;
    return false;
  }

  if (pendingVideoID !== videoID) {
    pendingVideoID = videoID;
    pendingVideoVisibleSeconds = 0;
  }
  pendingVideoVisibleSeconds += elapsedSeconds;

  if (
    pendingVideoVisibleSeconds < 10 ||
    currentUsage.countedVideoIDs.includes(videoID)
  ) {
    return false;
  }

  currentUsage.countedVideoIDs.push(videoID);
  currentUsage.countedVideoIDs = currentUsage.countedVideoIDs.slice(-500);
  currentUsage.videoCount += 1;
  currentUsage.lifetimeVideoCount += 1;
  return true;
}

function formatDuration(seconds) {
  const total = Math.max(Math.floor(seconds), 0);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (hours > 0) {
    return `${hours}h ${String(minutes).padStart(2, "0")}m`;
  }
  return `${minutes}m`;
}

function ensureUsageOverlay() {
  if (!document.body) {
    return null;
  }
  let overlay = document.getElementById("quietgate-youtube-usage");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "quietgate-youtube-usage";
    overlay.setAttribute("role", "status");
    document.body.appendChild(overlay);
  }
  return overlay;
}

function ensureLimitOverlay() {
  if (!document.body) {
    return null;
  }
  let overlay = document.getElementById("quietgate-youtube-limit");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "quietgate-youtube-limit";
    overlay.setAttribute("role", "alert");
    document.body.appendChild(overlay);
  }
  return overlay;
}

function removeUsageNodes() {
  document.getElementById("quietgate-youtube-usage")?.remove();
  document.getElementById("quietgate-youtube-limit")?.remove();
  document.documentElement.classList.remove("qg-youtube-limit-reached");
}

function pauseYouTubePlayback() {
  for (const video of document.querySelectorAll("video")) {
    try {
      video.pause();
    } catch (_error) {
      // Some player states reject pause calls.
    }
  }
}

function applyUsageUI(features) {
  if (!usageTrackingEnabled(features)) {
    removeUsageNodes();
    return;
  }

  currentUsage = normalizedUsage(currentUsage);
  const snapshot = publicUsageSnapshot(features);
  const usageOverlay = ensureUsageOverlay();
  if (usageOverlay) {
    const limitText = snapshot.limitSeconds
      ? ` / ${formatDuration(snapshot.limitSeconds)}`
      : "";
    usageOverlay.textContent =
      `Today ${formatDuration(snapshot.totalSeconds)}${limitText} · ${snapshot.videoCount} videos`;
  }

  const limitReached = Boolean(snapshot.limitReached);
  document.documentElement.classList.toggle("qg-youtube-limit-reached", limitReached);
  if (!limitReached) {
    document.getElementById("quietgate-youtube-limit")?.remove();
    limitHitReported = false;
    return;
  }

  pauseYouTubePlayback();
  if (!currentUsage.limitHitAt) {
    currentUsage.limitHitAt = new Date().toISOString();
  }
  const limitOverlay = ensureLimitOverlay();
  if (limitOverlay) {
    limitOverlay.textContent =
      `YouTube limit reached for today. ${formatDuration(snapshot.totalSeconds)} tracked · ${snapshot.videoCount} videos.`;
  }
  if (!limitHitReported) {
    limitHitReported = true;
    persistUsage("limit");
  }
}

function startUsageTracking() {
  currentUsage = normalizedUsage(currentUsage);
  if (trackingTimer !== null) {
    return;
  }
  lastTrackingTick = performance.now();
  trackingTimer = window.setTimeout(trackUsageTick, 1000);
}

function stopUsageTracking() {
  if (trackingTimer !== null) {
    window.clearTimeout(trackingTimer);
  }
  trackingTimer = null;
  lastTrackingTick = null;
  pendingVideoID = null;
  pendingVideoVisibleSeconds = 0;
  removeUsageNodes();
}

function shouldReportUsage(now) {
  return now - lastUsageReportAt >= 10000;
}

function trackUsageTick() {
  trackingTimer = null;
  const features = effectiveFeatures(currentSettings);
  if (!usageTrackingEnabled(features)) {
    stopUsageTracking();
    return;
  }

  currentUsage = normalizedUsage(currentUsage);
  const now = performance.now();
  const elapsedSeconds = lastTrackingTick === null
    ? 0
    : Math.min(Math.max((now - lastTrackingTick) / 1000, 0), 10);
  lastTrackingTick = now;

  let changed = false;
  if (
    document.visibilityState === "visible" &&
    elapsedSeconds > 0 &&
    !usageLimitReached(features)
  ) {
    currentUsage.totalSeconds += elapsedSeconds;
    currentUsage.lifetimeSeconds += elapsedSeconds;
    changed = true;
    if (recordVisibleVideoTime(elapsedSeconds)) {
      changed = true;
      lastUsageReportAt = 0;
    }
  }

  applyUsageUI(features);
  if (changed && shouldReportUsage(now)) {
    lastUsageReportAt = now;
    persistUsage("tick");
  }

  trackingTimer = window.setTimeout(trackUsageTick, 1000);
}

async function persistUsage(reason) {
  if (!currentUsage) {
    return;
  }
  currentUsage = normalizedUsage(currentUsage);
  currentUsage.lastUpdatedAt = new Date().toISOString();
  const snapshot = publicUsageSnapshot();
  try {
    await chrome.storage.local.set({ youtubeUsage: currentUsage });
  } catch (_error) {
    // Usage tracking is best-effort when browser storage is unavailable.
  }
  try {
    await chrome.runtime.sendMessage({
      type: "quietgate.youtubeUsageChanged",
      usage: snapshot,
      reason
    });
  } catch (_error) {
    // The local overlay still works if the service worker is asleep.
  }
}

function scheduleApplySettings() {
  if (applyQueued) {
    return;
  }

  applyQueued = true;
  requestAnimationFrame(() => {
    applyQueued = false;
    applySettings();
  });
}

async function syncNativeSettings() {
  if (syncInFlight) {
    return;
  }

  syncInFlight = true;
  try {
    await chrome.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
  } catch (error) {
    // Storage fallback still works when the native bridge has not been installed.
  } finally {
    syncInFlight = false;
  }
}

async function loadSettings() {
  const stored = await chrome.storage.local.get(DEFAULT_SETTINGS);
  currentSettings = mergedSettings(stored);
  currentUsage = normalizedUsage(stored.youtubeUsage);
  applySettings();
}

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== "local") {
    return;
  }

  if (changes.youtubeUsage) {
    currentUsage = normalizedUsage(changes.youtubeUsage.newValue);
    applySettings();
  }

  if (changes.mode || changes.features || changes.options) {
    loadSettings();
  }
});

const observer = new MutationObserver(scheduleApplySettings);
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

window.addEventListener("yt-navigate-finish", scheduleApplySettings);
window.addEventListener("yt-page-data-updated", scheduleApplySettings);
window.addEventListener("popstate", scheduleApplySettings);
window.addEventListener("pageshow", scheduleApplySettings);
window.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden" && currentUsage) {
    persistUsage("hidden");
  }
  scheduleApplySettings();
});
window.addEventListener("pagehide", () => {
  if (currentUsage) {
    persistUsage("pagehide");
  }
});

syncNativeSettings().finally(loadSettings);
