var quietGateYouTubeTunerVersion = "2026.06.29.1200";
var existingQuietGateYouTubeController = window.__quietgateYouTubeTunerController;
if (existingQuietGateYouTubeController?.version === quietGateYouTubeTunerVersion) {
  existingQuietGateYouTubeController.refresh?.();
} else {
existingQuietGateYouTubeController?.dispose?.();

const TUNER_VERSION = quietGateYouTubeTunerVersion;

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
  youtubeUsageSummary: null,
  siteUsageSummary: null,
  siteUsageBySite: {},
  browserID: null,
  browserProfile: null,
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

const HIDDEN_SURFACE_SELECTORS = {
  youtubeHome: [
    'ytd-browse[page-subtype="home"] ytd-rich-grid-renderer',
    'ytd-browse[page-subtype="home"] ytd-two-column-browse-results-renderer',
    'ytd-browse[page-subtype="home"] #contents',
    'ytd-browse[page-subtype="home"] ytd-rich-section-renderer'
  ],
  youtubeShorts: [
    'a[href^="/shorts"]',
    'ytd-guide-entry-renderer a[title="Shorts"]',
    'ytd-mini-guide-entry-renderer a[title="Shorts"]',
    "ytd-reel-shelf-renderer",
    "ytd-rich-shelf-renderer[is-shorts]",
    'ytd-video-renderer:has(a[href^="/shorts"])',
    'ytd-rich-item-renderer:has(a[href^="/shorts"])'
  ],
  youtubeComments: [
    "#comments",
    "ytd-comments"
  ],
  youtubeVideoSidebar: [
    "#secondary",
    "#secondary-inner",
    "#related",
    "ytd-watch-next-secondary-results-renderer"
  ],
  youtubeRecommendations: [
    "ytd-watch-next-secondary-results-renderer",
    "ytd-compact-video-renderer",
    "ytd-compact-playlist-renderer",
    "ytd-compact-radio-renderer"
  ],
  youtubeSearch: [
    "ytd-search ytd-reel-shelf-renderer",
    "ytd-search ytd-rich-shelf-renderer",
    "ytd-search ytd-shelf-renderer",
    "ytd-search ytd-horizontal-card-list-renderer",
    "ytd-search ytd-rich-section-renderer",
    'ytd-search ytd-video-renderer:has(a[href^="/shorts"])'
  ],
  youtubeEndScreens: [
    ".ytp-endscreen-content",
    ".ytp-endscreen-previous",
    ".ytp-endscreen-next"
  ],
  youtubeEndScreenCards: [
    ".ytp-ce-element",
    ".ytp-cards-teaser",
    ".ytp-cards-button"
  ],
  youtubeLiveChat: [
    "#chat",
    "#chat-container",
    "ytd-live-chat-frame"
  ],
  youtubePlaylists: [
    "#playlist",
    "ytd-playlist-panel-renderer",
    "ytd-playlist-panel-video-renderer"
  ],
  youtubeFundraisers: [
    "ytd-donation-shelf-renderer",
    "ytd-donation-companion-renderer",
    "ytd-donation-compact-renderer",
    "[is-donation-shelf]",
    "#donation-shelf",
    "#fundraiser"
  ],
  youtubeMixes: [
    "ytd-radio-renderer",
    "ytd-compact-radio-renderer",
    'ytd-rich-item-renderer:has(a[href*="list=RD"])',
    'ytd-video-renderer:has(a[href*="list=RD"])',
    'ytd-compact-video-renderer:has(a[href*="list=RD"])',
    'ytd-rich-item-renderer:has(a[href*="start_radio=1"])',
    'ytd-video-renderer:has(a[href*="start_radio=1"])',
    "#mix-result"
  ],
  youtubeMerch: [
    "ytd-merch-shelf-renderer",
    "ytd-ticket-shelf-renderer",
    "ytd-commerce-shelf-renderer",
    "ytd-offer-module-renderer",
    'ytd-engagement-panel-section-list-renderer[target-id*="shopping"]',
    "[is-merch-shelf]",
    "#merch-shelf",
    "#merch"
  ],
  youtubeVideoInfo: [
    "ytd-watch-metadata",
    "ytd-video-primary-info-renderer",
    "ytd-video-secondary-info-renderer",
    "#above-the-fold",
    "#info",
    "#meta",
    "#description",
    "#video-info"
  ],
  youtubeTopHeader: [
    "ytd-masthead",
    "#masthead",
    "#masthead-container",
    "#top-header"
  ],
  youtubeNotifications: [
    "ytd-notification-topbar-button-renderer",
    'button[aria-label*="Notifications"]',
    'a[href*="/notifications"]',
    "#notifications"
  ],
  youtubeExplore: [
    'ytd-guide-entry-renderer:has(a[href="/feed/explore"])',
    'ytd-guide-entry-renderer:has(a[href="/feed/trending"])',
    'ytd-mini-guide-entry-renderer:has(a[href="/feed/explore"])',
    'ytd-mini-guide-entry-renderer:has(a[href="/feed/trending"])',
    'a[href="/feed/explore"]',
    'a[href="/feed/trending"]',
    'a[title="Explore"]',
    'a[title="Trending"]',
    "#explore-link",
    "#trending-link"
  ],
  youtubeMoreFromYouTube: [
    'ytd-guide-section-renderer:has(a[href^="/premium"])',
    'ytd-guide-section-renderer:has(a[href*="music.youtube.com"])',
    'ytd-guide-entry-renderer:has(a[href^="/premium"])',
    'ytd-guide-entry-renderer:has(a[href*="music.youtube.com"])',
    'ytd-guide-entry-renderer:has(a[href*="/gaming"])',
    'ytd-guide-entry-renderer:has(a[href*="/movies"])',
    'a[title="YouTube Premium"]',
    'a[title="YouTube Music"]',
    'a[title="YouTube Kids"]',
    "#more-from-youtube"
  ],
  youtubeSubscriptions: [
    'ytd-guide-entry-renderer:has(a[href="/feed/subscriptions"])',
    'ytd-mini-guide-entry-renderer:has(a[href="/feed/subscriptions"])',
    'a[href="/feed/subscriptions"]',
    "#subscriptions-link"
  ],
  youtubeAnnotations: [
    ".annotation",
    ".video-annotations",
    ".ytp-ce-element",
    ".ytp-cards-teaser",
    ".ytp-cards-button",
    ".ytp-paid-content-overlay",
    "#annotation"
  ]
};

let currentSettings = DEFAULT_SETTINGS;
let currentUsage = null;
let currentUsageSummary = null;
let currentSiteUsageSummary = null;
let currentSiteUsageBySite = {};
let currentBrowserID = null;
let currentBrowserProfile = null;
let selectedUsageSiteID = "youtube";
let syncInFlight = false;
let applyQueued = false;
let trackingTimer = null;
let lastTrackingTick = null;
let pendingVideoID = null;
let pendingVideoVisibleSeconds = 0;
let lastUsageReportAt = 0;
let limitHitReported = false;

const USAGE_SITES = [
  { id: "all", title: "All", shortTitle: "All", activityLabel: null },
  { id: "youtube", title: "YouTube", shortTitle: "YouTube", activityLabel: "videos" },
  { id: "x", title: "X", shortTitle: "X", activityLabel: null },
  { id: "instagram", title: "Instagram", shortTitle: "Instagram", activityLabel: null },
  { id: "reddit", title: "Reddit", shortTitle: "Reddit", activityLabel: null }
];
const USAGE_SITE_IDS = USAGE_SITES.filter((site) => site.id !== "all").map((site) => site.id);

document.documentElement.dataset.quietgateTuner = "loaded";
document.documentElement.dataset.quietgateTunerVersion = TUNER_VERSION;
document.documentElement.dataset.quietgateYouTubeHiddenCount = "0";

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

function isHiddenSurface(node) {
  if (!node || node === document.documentElement || node === document.body) {
    return false;
  }
  const style = window.getComputedStyle?.(node);
  return Boolean(style && (style.display === "none" || style.visibility === "hidden"));
}

function refreshHiddenCount(features) {
  const hiddenItems = new Set();

  for (const [feature, selectors] of Object.entries(HIDDEN_SURFACE_SELECTORS)) {
    if (!features[feature]) {
      continue;
    }
    for (const selector of selectors) {
      for (const node of document.querySelectorAll(selector)) {
        if (isHiddenSurface(node)) {
          hiddenItems.add(node);
        }
      }
    }
  }

  if (features.youtubeDailyLimit && document.documentElement.classList.contains("qg-youtube-limit-reached")) {
    const limitOverlay = document.getElementById("quietgate-youtube-limit");
    if (limitOverlay) {
      hiddenItems.add(limitOverlay);
    }
  }

  document.documentElement.dataset.quietgateYouTubeHiddenCount = String(hiddenItems.size);
}

function redirectToYouTubeHomeIfStillOn(blockedPathTest) {
  const redirect = () => {
    if (blockedPathTest(location.pathname)) {
      location.replace("https://www.youtube.com/");
    }
  };
  redirect();
  window.addEventListener("DOMContentLoaded", redirect, { once: true });
  window.addEventListener("load", redirect, { once: true });
  window.addEventListener("pageshow", redirect, { once: true });
  setTimeout(redirect, 100);
  setTimeout(redirect, 500);
  setTimeout(redirect, 1500);
  setTimeout(redirect, 3000);
}

function applySettings() {
  const features = effectiveFeatures(currentSettings);

  for (const [feature, className] of Object.entries(FEATURE_CLASSES)) {
    document.documentElement.classList.toggle(className, Boolean(features[feature]));
  }

  if (features.youtubeShorts && location.pathname.startsWith("/shorts")) {
    redirectToYouTubeHomeIfStillOn((path) => path.startsWith("/shorts"));
  }

  if (features.youtubeExplore && /^\/feed\/(?:explore|trending)/.test(location.pathname)) {
    redirectToYouTubeHomeIfStillOn((path) => /^\/feed\/(?:explore|trending)/.test(path));
  }

  if (features.youtubeSubscriptions && location.pathname.startsWith("/feed/subscriptions")) {
    redirectToYouTubeHomeIfStillOn((path) => path.startsWith("/feed/subscriptions"));
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
  refreshHiddenCount(features);
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

function normalizedLimitSeconds(value) {
  const seconds = Number(value);
  if (!Number.isFinite(seconds) || seconds <= 0) {
    return null;
  }
  return Math.floor(seconds);
}

function normalizedUsageEntry(value, fallbackSiteID = "youtube") {
  if (!value || typeof value !== "object") {
    return null;
  }
  const usage = value.siteUsage && typeof value.siteUsage === "object"
    ? value.siteUsage
    : (value.youtubeUsage && typeof value.youtubeUsage === "object" ? value.youtubeUsage : value);
  const siteID = typeof value.siteID === "string" && value.siteID.trim()
    ? value.siteID.trim().toLowerCase()
    : (typeof usage.siteID === "string" && usage.siteID.trim() ? usage.siteID.trim().toLowerCase() : fallbackSiteID);
  const date = typeof usage.date === "string" ? usage.date : "";
  const totalSeconds = Math.max(Math.floor(Number(usage.totalSeconds) || 0), 0);
  const activityCount = Math.max(Math.floor(Number(usage.activityCount ?? usage.videoCount) || 0), 0);
  const videoCount = siteID === "youtube" ? activityCount : 0;
  const lifetimeSeconds = Math.max(Math.floor(Number(usage.lifetimeSeconds) || 0), 0);
  const lifetimeActivityCount = Math.max(Math.floor(Number(usage.lifetimeActivityCount ?? usage.lifetimeVideoCount) || 0), 0);
  const lifetimeVideoCount = siteID === "youtube" ? lifetimeActivityCount : 0;
  const browserID = typeof value.browserID === "string" ? value.browserID.trim() : "";
  const browserName = typeof value.browserName === "string" ? value.browserName.trim() : "";
  const profileID = typeof value.profileID === "string" ? value.profileID.trim() : "";
  const profileName = typeof value.profileName === "string" ? value.profileName.trim() : "";
  const label = typeof value.label === "string" ? value.label.trim() : "";

  return {
    id: typeof value.id === "string" && value.id.trim()
      ? value.id.trim()
      : [siteID, browserID, profileID].filter(Boolean).join(":"),
    siteID,
    siteTitle: usageSiteDefinition(siteID).title,
    sourceType: typeof value.sourceType === "string" ? value.sourceType : "browser",
    browserID,
    browserName,
    profileID,
    profileName,
    label: label || [browserName || browserID, profileName || profileID].filter(Boolean).join(" - "),
    date,
    totalSeconds,
    lifetimeSeconds,
    activityCount,
    lifetimeActivityCount,
    activityLabel: typeof usage.activityLabel === "string" ? usage.activityLabel : usageSiteDefinition(siteID).activityLabel,
    videoCount,
    lifetimeVideoCount,
    limitSeconds: normalizedLimitSeconds(usage.limitSeconds),
    limitReached: Boolean(usage.limitReached),
    lastUpdatedAt: typeof usage.lastUpdatedAt === "string"
      ? usage.lastUpdatedAt
      : (typeof value.lastUpdatedAt === "string" ? value.lastUpdatedAt : null)
  };
}

function normalizedUsageSummary(value, features = effectiveFeatures(currentSettings)) {
  const today = localDateKey();
  if (!value || typeof value !== "object" || value.date !== today) {
    return null;
  }
  const entries = Array.isArray(value.entries)
    ? value.entries
      .map((entry) => normalizedUsageEntry(entry, "youtube"))
      .filter((entry) => entry && entry.date === today)
      .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds)
    : [];
  const totalSeconds = Math.max(Math.floor(Number(value.totalSeconds) || 0), 0);
  const videoCount = Math.max(Math.floor(Number(value.videoCount) || 0), 0);
  const lifetimeSeconds = Math.max(Math.floor(Number(value.lifetimeSeconds) || 0), 0);
  const lifetimeVideoCount = Math.max(Math.floor(Number(value.lifetimeVideoCount) || 0), 0);
  const limitSeconds = dailyLimitSeconds(features) || normalizedLimitSeconds(value.limitSeconds);

  return {
    date: today,
    totalSeconds,
    lifetimeSeconds,
    videoCount,
    lifetimeVideoCount,
    limitSeconds,
    limitReached: Boolean(value.limitReached) || Boolean(limitSeconds && totalSeconds >= limitSeconds),
    lastUpdatedAt: typeof value.lastUpdatedAt === "string" ? value.lastUpdatedAt : null,
    entries
  };
}

function normalizedStoredProfile(profile) {
  if (!profile || typeof profile !== "object") {
    return null;
  }
  const id = typeof profile.id === "string" ? profile.id.trim() : "";
  const name = typeof profile.name === "string" ? profile.name.trim() : "";
  const label = typeof profile.label === "string" ? profile.label.trim() : "";
  if (!id && !name && !label) {
    return null;
  }
  return {
    id: id || null,
    name: name || null,
    label: label || [name, id].filter(Boolean).join(" ")
  };
}

function browserDisplayName(browserID) {
  switch (browserID) {
    case "chrome":
      return "Chrome";
    case "edge":
      return "Edge";
    case "brave":
      return "Brave";
    case "arc":
      return "Arc";
    case "firefox":
      return "Firefox";
    default:
      return "This browser";
  }
}

function currentUsageEntryID() {
  if (!currentBrowserID) {
    return null;
  }
  return `${currentBrowserID}:${currentBrowserProfile?.id || "default"}`;
}

function currentUsageEntry(features) {
  const id = currentUsageEntryID();
  if (!id) {
    return null;
  }
  const usage = publicUsageSnapshot(features);
  const browserName = browserDisplayName(currentBrowserID);
  const profileLabel = currentBrowserProfile?.label || currentBrowserProfile?.name || currentBrowserProfile?.id || "";
  return {
    id: `youtube:${id}`,
    siteID: "youtube",
    siteTitle: "YouTube",
    sourceType: "browser",
    sourceID: id,
    browserID: currentBrowserID,
    browserName,
    profileID: currentBrowserProfile?.id || "default",
    profileName: currentBrowserProfile?.name || null,
    label: [browserName, profileLabel].filter(Boolean).join(" - "),
    activityCount: usage.videoCount,
    lifetimeActivityCount: usage.lifetimeVideoCount,
    activityLabel: "videos",
    ...usage
  };
}

function mergeCurrentUsageIntoSummary(summary, features) {
  const currentEntry = currentUsageEntry(features);
  if (!currentEntry || currentEntry.date !== summary.date) {
    return summary;
  }

  const existingEntry = summary.entries.find((entry) => entry.id === currentEntry.id);
  const entries = [
    currentEntry,
    ...summary.entries.filter((entry) => entry.id !== currentEntry.id)
  ].sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
  const totalSeconds = Math.max(
    summary.totalSeconds - (existingEntry?.totalSeconds || 0) + currentEntry.totalSeconds,
    0
  );
  const videoCount = Math.max(
    summary.videoCount - (existingEntry?.videoCount || 0) + currentEntry.videoCount,
    0
  );
  const lifetimeSeconds = Math.max(
    summary.lifetimeSeconds - (existingEntry?.lifetimeSeconds || 0) + currentEntry.lifetimeSeconds,
    0
  );
  const lifetimeVideoCount = Math.max(
    summary.lifetimeVideoCount - (existingEntry?.lifetimeVideoCount || 0) + currentEntry.lifetimeVideoCount,
    0
  );
  const limitSeconds = dailyLimitSeconds(features) || summary.limitSeconds;

  return {
    ...summary,
    siteID: "youtube",
    title: "YouTube",
    totalSeconds,
    activityCount: videoCount,
    lifetimeActivityCount: lifetimeVideoCount,
    activityLabel: "videos",
    videoCount,
    lifetimeSeconds,
    lifetimeVideoCount,
    limitSeconds,
    limitReached: Boolean(limitSeconds && totalSeconds >= limitSeconds) || entries.some((entry) => entry.limitReached),
    lastUpdatedAt: currentEntry.lastUpdatedAt || summary.lastUpdatedAt,
    entries
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
  return Boolean(usageSnapshotForDisplay(features).limitReached);
}

function publicUsageSnapshot(features = effectiveFeatures(currentSettings)) {
  const usage = normalizedUsage(currentUsage);
  const limitSeconds = dailyLimitSeconds(features);
  return {
    siteID: "youtube",
    title: "YouTube",
    date: usage.date,
    totalSeconds: Math.floor(usage.totalSeconds),
    lifetimeSeconds: Math.floor(usage.lifetimeSeconds),
    activityCount: usage.videoCount,
    lifetimeActivityCount: usage.lifetimeVideoCount,
    activityLabel: "videos",
    videoCount: usage.videoCount,
    lifetimeVideoCount: usage.lifetimeVideoCount,
    limitSeconds,
    limitReached: Boolean(limitSeconds && usage.totalSeconds >= limitSeconds),
    lastUpdatedAt: usage.lastUpdatedAt
  };
}

function usageSnapshotForDisplay(features = effectiveFeatures(currentSettings)) {
  const summary = normalizedUsageSummary(currentUsageSummary, features);
  if (summary) {
    return mergeCurrentUsageIntoSummary(summary, features);
  }
  const local = publicUsageSnapshot(features);
  const currentEntry = currentUsageEntry(features);
  return {
    ...local,
    entries: currentEntry ? [currentEntry] : []
  };
}

function normalizedSiteUsageSummary(value, siteID) {
  const today = localDateKey();
  if (!value || typeof value !== "object" || !Array.isArray(value.sites)) {
    return null;
  }
  const site = value.sites.find((candidate) => candidate?.siteID === siteID);
  if (!site || site.date !== today) {
    return null;
  }
  const entries = Array.isArray(site.entries)
    ? site.entries
      .map((entry) => normalizedUsageEntry(entry, siteID))
      .filter((entry) => entry && entry.date === today)
      .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds)
    : [];
  const activityCount = Math.max(Math.floor(Number(site.activityCount ?? site.videoCount) || 0), 0);
  const lifetimeActivityCount = Math.max(Math.floor(Number(site.lifetimeActivityCount ?? site.lifetimeVideoCount) || 0), 0);
  return {
    siteID,
    title: usageSiteDefinition(siteID).title,
    date: today,
    totalSeconds: Math.max(Math.floor(Number(site.totalSeconds) || 0), 0),
    lifetimeSeconds: Math.max(Math.floor(Number(site.lifetimeSeconds) || 0), 0),
    activityCount,
    lifetimeActivityCount,
    activityLabel: typeof site.activityLabel === "string" ? site.activityLabel : usageSiteDefinition(siteID).activityLabel,
    videoCount: siteID === "youtube" ? activityCount : 0,
    lifetimeVideoCount: siteID === "youtube" ? lifetimeActivityCount : 0,
    limitSeconds: siteID === "youtube" ? normalizedLimitSeconds(site.limitSeconds) : null,
    limitReached: Boolean(site.limitReached),
    lastUpdatedAt: typeof site.lastUpdatedAt === "string" ? site.lastUpdatedAt : null,
    entries
  };
}

function localSiteUsageSnapshot(siteID) {
  if (siteID === "youtube") {
    return usageSnapshotForDisplay();
  }
  const rawUsage = currentSiteUsageBySite[siteID] || null;
  const usage = normalizedUsage({
    date: localDateKey(),
    ...(rawUsage || {})
  });
  const activityCount = activityCountValue(usage);
  const browserName = currentBrowserID ? browserDisplayName(currentBrowserID) : "This browser";
  const profileID = currentBrowserProfile?.id || "default";
  const profileLabel = currentBrowserProfile?.label || currentBrowserProfile?.name || profileID;
  const entry = currentBrowserID && rawUsage ? {
    id: `${siteID}:${currentBrowserID}:${profileID}`,
    siteID,
    siteTitle: usageSiteDefinition(siteID).title,
    sourceType: "browser",
    sourceID: `${currentBrowserID}:${profileID}`,
    browserID: currentBrowserID,
    browserName,
    profileID,
    profileName: currentBrowserProfile?.name || null,
    label: [browserName, profileLabel].filter(Boolean).join(" - "),
    date: usage.date,
    totalSeconds: usage.totalSeconds,
    lifetimeSeconds: usage.lifetimeSeconds,
    activityCount,
    lifetimeActivityCount: Math.max(Math.floor(Number(usage.lifetimeActivityCount ?? usage.lifetimeVideoCount) || 0), 0),
    activityLabel: usageSiteDefinition(siteID).activityLabel,
    videoCount: 0,
    lifetimeVideoCount: 0,
    lastUpdatedAt: usage.lastUpdatedAt
  } : null;
  return {
    siteID,
    title: usageSiteDefinition(siteID).title,
    date: usage.date,
    totalSeconds: usage.totalSeconds,
    lifetimeSeconds: usage.lifetimeSeconds,
    activityCount,
    lifetimeActivityCount: Math.max(Math.floor(Number(usage.lifetimeActivityCount ?? usage.lifetimeVideoCount) || 0), 0),
    activityLabel: usageSiteDefinition(siteID).activityLabel,
    videoCount: 0,
    lifetimeVideoCount: 0,
    entries: entry ? [entry] : []
  };
}

function siteUsageSnapshotForDisplay(siteID, features = effectiveFeatures(currentSettings)) {
  if (siteID === "youtube") {
    const generic = normalizedSiteUsageSummary(currentSiteUsageSummary, "youtube");
    if (generic) {
      return mergeCurrentUsageIntoSummary(generic, features);
    }
    return usageSnapshotForDisplay(features);
  }
  return normalizedSiteUsageSummary(currentSiteUsageSummary, siteID) || localSiteUsageSnapshot(siteID);
}

function allUsageSnapshotForDisplay(features = effectiveFeatures(currentSettings)) {
  const sites = USAGE_SITE_IDS.map((siteID) => siteUsageSnapshotForDisplay(siteID, features));
  return {
    siteID: "all",
    title: "All",
    date: localDateKey(),
    totalSeconds: sites.reduce((sum, site) => sum + site.totalSeconds, 0),
    lifetimeSeconds: sites.reduce((sum, site) => sum + site.lifetimeSeconds, 0),
    activityCount: sites.reduce((sum, site) => sum + activityCountValue(site), 0),
    lifetimeActivityCount: sites.reduce((sum, site) => sum + Math.max(Math.floor(Number(site.lifetimeActivityCount ?? site.lifetimeVideoCount) || 0), 0), 0),
    activityLabel: null,
    videoCount: sites.find((site) => site.siteID === "youtube")?.videoCount || 0,
    lifetimeVideoCount: sites.find((site) => site.siteID === "youtube")?.lifetimeVideoCount || 0,
    entries: sites.flatMap((site) => site.entries || []),
    sites
  };
}

function selectedUsageSnapshotForDisplay(features = effectiveFeatures(currentSettings)) {
  return selectedUsageSiteID === "all"
    ? allUsageSnapshotForDisplay(features)
    : siteUsageSnapshotForDisplay(selectedUsageSiteID, features);
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

function todayElapsedSeconds(now = new Date()) {
  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);
  return Math.max(Math.floor((now.getTime() - startOfToday.getTime()) / 1000), 0);
}

function videoCountText(count) {
  const total = Math.max(Math.floor(Number(count) || 0), 0);
  return `${total} ${total === 1 ? "video" : "videos"}`;
}

function shortVideoCountText(count) {
  const total = Math.max(Math.floor(Number(count) || 0), 0);
  return `${total} vid${total === 1 ? "" : "s"}`;
}

function usageSiteDefinition(siteID) {
  return USAGE_SITES.find((site) => site.id === siteID) || USAGE_SITES[0];
}

function activityCountValue(value) {
  return Math.max(Math.floor(Number(value?.activityCount ?? value?.videoCount) || 0), 0);
}

function activityCountText(siteID, count) {
  const label = usageSiteDefinition(siteID).activityLabel;
  if (!label) {
    return "";
  }
  return label === "videos" ? videoCountText(count) : `${Math.max(Math.floor(Number(count) || 0), 0)} ${label}`;
}

function shortActivityCountText(siteID, count) {
  const label = usageSiteDefinition(siteID).activityLabel;
  if (!label) {
    return "";
  }
  return label === "videos" ? shortVideoCountText(count) : String(Math.max(Math.floor(Number(count) || 0), 0));
}

function usageRowValue(siteID, seconds, activityCount, connected = true) {
  if (!connected) {
    return "No data";
  }
  return [formatDuration(seconds), shortActivityCountText(siteID, activityCount)].filter(Boolean).join(" · ");
}

function extractedEmail(value) {
  const text = typeof value === "string" ? value : "";
  const match = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
  return match ? match[0].toLowerCase() : null;
}

function strippedProfileName(value, email = null) {
  let name = typeof value === "string" ? value.trim() : "";
  if (!name) {
    return "";
  }
  name = name.replace(/^(Chrome|Firefox|Edge|Brave|Arc|This browser)\s*-\s*/i, "").trim();
  if (email) {
    name = name.replace(new RegExp(email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i"), "");
  }
  name = name
    .replace(/\([^)]*\)/g, "")
    .replace(/[,-]\s*$/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
  return name;
}

function usageAccountKey(entry) {
  return extractedEmail(entry?.label) ||
    extractedEmail(entry?.profileName) ||
    extractedEmail(entry?.id) ||
    [entry?.browserID, entry?.profileID || entry?.label].filter(Boolean).join(":") ||
    "this-browser";
}

function browserProfileSummary(entries) {
  const profiles = new Set();
  const browsers = new Set();
  for (const entry of entries) {
    const browserName = typeof entry.browserName === "string" && entry.browserName.trim()
      ? entry.browserName.trim()
      : browserDisplayName(entry.browserID);
    browsers.add(browserName);
    if (entry.profileID) {
      profiles.add(`${browserName}:${entry.profileID}`);
    }
  }
  const browserText = Array.from(browsers).join(", ") || "This browser";
  if (profiles.size > 1) {
    return `${browserText} · ${profiles.size} profiles`;
  }
  return browserText;
}

function usageEntryLooksLikeIOS(entry) {
  const text = [
    entry?.browserID,
    entry?.browserName,
    entry?.profileID,
    entry?.profileName,
    entry?.label,
    entry?.id
  ].filter(Boolean).join(" ").toLowerCase();
  return /\bios\b|iphone|ipad/.test(text);
}

function summedUsage(entries) {
  return (entries || []).reduce((usage, entry) => ({
    totalSeconds: usage.totalSeconds + Math.max(Math.floor(Number(entry.totalSeconds) || 0), 0),
    lifetimeSeconds: usage.lifetimeSeconds + Math.max(Math.floor(Number(entry.lifetimeSeconds) || 0), 0),
    activityCount: usage.activityCount + activityCountValue(entry),
    lifetimeActivityCount: usage.lifetimeActivityCount + Math.max(Math.floor(Number(entry.lifetimeActivityCount ?? entry.lifetimeVideoCount) || 0), 0),
    videoCount: usage.videoCount + Math.max(Math.floor(Number(entry.videoCount) || 0), 0),
    lifetimeVideoCount: usage.lifetimeVideoCount + Math.max(Math.floor(Number(entry.lifetimeVideoCount) || 0), 0)
  }), {
    totalSeconds: 0,
    lifetimeSeconds: 0,
    activityCount: 0,
    lifetimeActivityCount: 0,
    videoCount: 0,
    lifetimeVideoCount: 0
  });
}

function deviceRowsForUsage(entries) {
  const allEntries = entries || [];
  const iosEntries = allEntries.filter(usageEntryLooksLikeIOS);
  const browserEntries = allEntries.filter((entry) => !usageEntryLooksLikeIOS(entry));
  const browserUsage = summedUsage(browserEntries);
  const iosUsage = summedUsage(iosEntries);

  return [
    {
      id: "web",
      title: "Web browser",
      meta: browserEntries.length ? browserProfileSummary(browserEntries) : "This browser",
      connected: browserEntries.length > 0,
      iconLabel: "WEB",
      ...browserUsage
    },
    {
      id: "ios",
      title: "iOS",
      meta: iosEntries.length ? "Connected" : "Not connected",
      connected: iosEntries.length > 0,
      iconLabel: "iOS",
      ...iosUsage
    }
  ];
}

function accountGroupsForUsage(entries) {
  const groups = new Map();
  for (const entry of entries || []) {
    const key = usageAccountKey(entry);
    const email = extractedEmail(entry?.label) || extractedEmail(entry?.profileName) || null;
    const title = strippedProfileName(entry?.profileName, email) ||
      strippedProfileName(entry?.label, email) ||
      email ||
      "This browser";
    const existing = groups.get(key);
    if (!existing) {
      groups.set(key, {
        id: key,
        title,
        email,
        totalSeconds: Math.max(Math.floor(Number(entry.totalSeconds) || 0), 0),
        lifetimeSeconds: Math.max(Math.floor(Number(entry.lifetimeSeconds) || 0), 0),
        activityCount: activityCountValue(entry),
        lifetimeActivityCount: Math.max(Math.floor(Number(entry.lifetimeActivityCount ?? entry.lifetimeVideoCount) || 0), 0),
        videoCount: Math.max(Math.floor(Number(entry.videoCount) || 0), 0),
        lifetimeVideoCount: Math.max(Math.floor(Number(entry.lifetimeVideoCount) || 0), 0),
        entries: [entry]
      });
      continue;
    }
    existing.totalSeconds += Math.max(Math.floor(Number(entry.totalSeconds) || 0), 0);
    existing.lifetimeSeconds += Math.max(Math.floor(Number(entry.lifetimeSeconds) || 0), 0);
    existing.activityCount += activityCountValue(entry);
    existing.lifetimeActivityCount += Math.max(Math.floor(Number(entry.lifetimeActivityCount ?? entry.lifetimeVideoCount) || 0), 0);
    existing.videoCount += Math.max(Math.floor(Number(entry.videoCount) || 0), 0);
    existing.lifetimeVideoCount += Math.max(Math.floor(Number(entry.lifetimeVideoCount) || 0), 0);
    existing.entries.push(entry);
    if (!existing.email && email) {
      existing.email = email;
    }
    if ((!existing.title || existing.title === "This browser") && title) {
      existing.title = title;
    }
  }

  return Array.from(groups.values())
    .map((group) => ({
      ...group,
      meta: browserProfileSummary(group.entries)
    }))
    .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
}

function accountInitials(group) {
  const source = group.title || group.email || "Q";
  const parts = source
    .replace(/@.*/, "")
    .split(/[\s._-]+/)
    .map((part) => part.trim())
    .filter(Boolean);
  const initials = parts.slice(0, 2).map((part) => part[0]).join("").toUpperCase();
  return initials || "Q";
}

function setUsageOverlayExpanded(overlay, expanded) {
  overlay.classList.toggle("qg-youtube-usage-expanded", expanded);
  overlay.setAttribute("aria-expanded", expanded ? "true" : "false");
}

function toggleUsageOverlay(event) {
  const overlay = event.currentTarget;
  setUsageOverlayExpanded(overlay, !overlay.classList.contains("qg-youtube-usage-expanded"));
}

function handleUsageOverlayKeyDown(event) {
  if (event.key === "Enter" || event.key === " ") {
    event.preventDefault();
    toggleUsageOverlay(event);
  } else if (event.key === "Escape") {
    setUsageOverlayExpanded(event.currentTarget, false);
  }
}

function ensureUsageOverlay() {
  if (!document.body) {
    return null;
  }
  let overlay = document.getElementById("quietgate-youtube-usage");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "quietgate-youtube-usage";
    overlay.setAttribute("role", "button");
    overlay.setAttribute("aria-live", "polite");
    overlay.setAttribute("aria-expanded", "false");
    overlay.tabIndex = 0;
    overlay.addEventListener("click", toggleUsageOverlay);
    overlay.addEventListener("keydown", handleUsageOverlayKeyDown);

    const summary = document.createElement("div");
    summary.className = "qg-youtube-usage-summary";
    overlay.appendChild(summary);

    const detail = document.createElement("div");
    detail.className = "qg-youtube-usage-detail";
    overlay.appendChild(detail);
    document.body.appendChild(overlay);
  }
  return overlay;
}

function renderUsageDetail(detail, snapshot) {
  detail.replaceChildren();
  const entries = snapshot.entries?.length
    ? snapshot.entries
    : [{
      label: "This browser",
      siteID: snapshot.siteID,
      totalSeconds: snapshot.totalSeconds,
      lifetimeSeconds: snapshot.lifetimeSeconds,
      activityCount: activityCountValue(snapshot),
      lifetimeActivityCount: Math.max(Math.floor(Number(snapshot.lifetimeActivityCount ?? snapshot.lifetimeVideoCount) || 0), 0),
      videoCount: snapshot.videoCount || 0,
      lifetimeVideoCount: snapshot.lifetimeVideoCount || 0
    }];
  const groups = accountGroupsForUsage(entries);
  const deviceRows = deviceRowsForUsage(entries);

  const tabs = document.createElement("div");
  tabs.className = "qg-youtube-usage-tabs";
  tabs.setAttribute("role", "tablist");
  for (const site of USAGE_SITES) {
    const tab = document.createElement("button");
    tab.type = "button";
    tab.className = "qg-youtube-usage-tab";
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", selectedUsageSiteID === site.id ? "true" : "false");
    tab.textContent = site.shortTitle;
    tab.addEventListener("click", (event) => {
      event.stopPropagation();
      selectedUsageSiteID = site.id;
      applyUsageUI(effectiveFeatures(currentSettings));
    });
    tabs.appendChild(tab);
  }
  detail.appendChild(tabs);

  const hero = document.createElement("div");
  hero.className = "qg-youtube-usage-hero";

  const heroCopy = document.createElement("div");
  heroCopy.className = "qg-youtube-usage-hero-copy";

  const kicker = document.createElement("div");
  kicker.className = "qg-youtube-usage-kicker";
  kicker.textContent = "Tortoise";

  const total = document.createElement("div");
  total.className = "qg-youtube-usage-total";
  total.textContent = formatDuration(snapshot.totalSeconds);

  const dayWindow = document.createElement("div");
  dayWindow.className = "qg-youtube-usage-day-window";
  dayWindow.textContent = `Today so far · ${formatDuration(todayElapsedSeconds())} since 12:00 AM`;

  const totalMeta = document.createElement("div");
  totalMeta.className = "qg-youtube-usage-total-meta";
  totalMeta.textContent = activityCountText(snapshot.siteID, activityCountValue(snapshot))
    || (snapshot.siteID === "all" ? "Across supported apps" : `${snapshot.title} active time`);

  heroCopy.append(kicker, total, dayWindow, totalMeta);

  const heroRail = document.createElement("div");
  heroRail.className = "qg-youtube-usage-hero-rail";

  const source = document.createElement("div");
  source.className = "qg-youtube-usage-source";

  const sourceIcon = document.createElement("span");
  sourceIcon.className = snapshot.siteID === "youtube"
    ? "qg-youtube-usage-youtube-icon"
    : "qg-youtube-usage-site-dot";
  sourceIcon.setAttribute("aria-hidden", "true");

  const sourceLabel = document.createElement("span");
  sourceLabel.textContent = snapshot.title;

  source.append(sourceIcon, sourceLabel);

  const count = document.createElement("div");
  count.className = "qg-youtube-usage-account-count";
  count.textContent = `${groups.length} ${groups.length === 1 ? "account" : "accounts"}`;

  heroRail.append(source, count);

  hero.append(heroCopy, heroRail);
  detail.appendChild(hero);

  const devicesTitle = document.createElement("div");
  devicesTitle.className = "qg-youtube-usage-section-title";
  devicesTitle.textContent = "Devices";
  detail.appendChild(devicesTitle);

  const devices = document.createElement("div");
  devices.className = "qg-youtube-usage-list qg-youtube-usage-device-list";

  for (const device of deviceRows) {
    const row = document.createElement("div");
    row.className = `qg-youtube-usage-row qg-youtube-usage-device-row${device.connected ? "" : " qg-youtube-usage-device-row-muted"}`;

    const avatar = document.createElement("span");
    avatar.className = `qg-youtube-usage-avatar qg-youtube-usage-device-icon qg-youtube-usage-device-icon-${device.id}`;
    avatar.textContent = device.iconLabel;

    const copy = document.createElement("span");
    copy.className = "qg-youtube-usage-row-copy";

    const label = document.createElement("span");
    label.className = "qg-youtube-usage-row-title";
    label.textContent = device.title;

    const sublabel = document.createElement("span");
    sublabel.className = "qg-youtube-usage-row-subtitle";
    sublabel.textContent = device.meta;

    copy.append(label, sublabel);

    const value = document.createElement("span");
    value.className = "qg-youtube-usage-row-value";
    value.textContent = usageRowValue(snapshot.siteID, device.totalSeconds, device.activityCount, device.connected);

    row.append(avatar, copy, value);
    devices.appendChild(row);
  }

  detail.appendChild(devices);

  const accountsTitle = document.createElement("div");
  accountsTitle.className = "qg-youtube-usage-section-title";
  accountsTitle.textContent = "Accounts";
  detail.appendChild(accountsTitle);

  const list = document.createElement("div");
  list.className = "qg-youtube-usage-list";

  for (const group of groups.slice(0, 8)) {
    const row = document.createElement("div");
    row.className = "qg-youtube-usage-row";

    const avatar = document.createElement("span");
    avatar.className = "qg-youtube-usage-avatar";
    avatar.textContent = accountInitials(group);

    const copy = document.createElement("span");
    copy.className = "qg-youtube-usage-row-copy";

    const label = document.createElement("span");
    label.className = "qg-youtube-usage-row-title";
    label.textContent = group.title || group.email || "This browser";

    const sublabel = document.createElement("span");
    sublabel.className = "qg-youtube-usage-row-subtitle";
    sublabel.textContent = [group.email, group.meta].filter(Boolean).join(" · ");

    copy.append(label, sublabel);

    const value = document.createElement("span");
    value.className = "qg-youtube-usage-row-value";
    value.textContent = usageRowValue(snapshot.siteID, group.totalSeconds, group.activityCount, true);

    row.append(avatar, copy, value);
    list.appendChild(row);
  }

  detail.appendChild(list);
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
  const snapshot = usageSnapshotForDisplay(features);
  const detailSnapshot = selectedUsageSnapshotForDisplay(features);
  const usageOverlay = ensureUsageOverlay();
  if (usageOverlay) {
    const limitText = snapshot.limitSeconds
      ? ` / ${formatDuration(snapshot.limitSeconds)}`
      : "";
    const summary = usageOverlay.querySelector(".qg-youtube-usage-summary");
    const detail = usageOverlay.querySelector(".qg-youtube-usage-detail");
    const summaryText = `Today ${formatDuration(snapshot.totalSeconds)}${limitText} · ${videoCountText(snapshot.videoCount)}`;
    if (summary) {
      summary.textContent = summaryText;
    }
    if (detail) {
      renderUsageDetail(detail, detailSnapshot);
    }
    usageOverlay.setAttribute("aria-label", summaryText);
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
    const stored = await chrome.storage.local.get({ siteUsageBySite: {} });
    currentSiteUsageBySite = {
      ...(stored.siteUsageBySite && typeof stored.siteUsageBySite === "object" ? stored.siteUsageBySite : {}),
      youtube: {
        ...snapshot,
        activityCount: snapshot.videoCount,
        lifetimeActivityCount: snapshot.lifetimeVideoCount,
        activityLabel: "videos"
      }
    };
    await chrome.storage.local.set({
      youtubeUsage: currentUsage,
      siteUsageBySite: currentSiteUsageBySite
    });
  } catch (_error) {
    // Usage tracking is best-effort when browser storage is unavailable.
  }
  try {
    await chrome.runtime.sendMessage({
      type: "quietgate.siteUsageChanged",
      siteID: "youtube",
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
  currentUsageSummary = stored.youtubeUsageSummary || null;
  currentSiteUsageSummary = stored.siteUsageSummary || null;
  currentSiteUsageBySite = stored.siteUsageBySite && typeof stored.siteUsageBySite === "object"
    ? stored.siteUsageBySite
    : {};
  currentBrowserID = typeof stored.browserID === "string" && stored.browserID.trim()
    ? stored.browserID.trim().toLowerCase()
    : null;
  currentBrowserProfile = normalizedStoredProfile(stored.browserProfile);
  applySettings();
}

function handleStorageChange(changes, areaName) {
  if (areaName !== "local") {
    return;
  }

  if (changes.youtubeUsage) {
    currentUsage = normalizedUsage(changes.youtubeUsage.newValue);
    applySettings();
  }

  if (changes.youtubeUsageSummary) {
    currentUsageSummary = changes.youtubeUsageSummary.newValue || null;
    applySettings();
  }

  if (changes.siteUsageSummary) {
    currentSiteUsageSummary = changes.siteUsageSummary.newValue || null;
    applySettings();
  }

  if (changes.siteUsageBySite) {
    currentSiteUsageBySite = changes.siteUsageBySite.newValue && typeof changes.siteUsageBySite.newValue === "object"
      ? changes.siteUsageBySite.newValue
      : {};
    applySettings();
  }

  if (changes.mode || changes.features || changes.options || changes.browserID || changes.browserProfile) {
    loadSettings();
  }
}

function handleVisibilityChange() {
  if (document.visibilityState === "hidden" && currentUsage) {
    persistUsage("hidden");
  }
  scheduleApplySettings();
}

function handlePageHide() {
  if (currentUsage) {
    persistUsage("pagehide");
  }
}

function clearFeatureClasses() {
  document.documentElement.classList.remove(
    ...Object.values(FEATURE_CLASSES),
    "qg-youtube-limit-reached"
  );
  document.documentElement.dataset.quietgateYouTubeHiddenCount = "0";
}

chrome.storage.onChanged.addListener(handleStorageChange);

const observer = new MutationObserver(scheduleApplySettings);
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

window.addEventListener("yt-navigate-finish", scheduleApplySettings);
window.addEventListener("yt-page-data-updated", scheduleApplySettings);
window.addEventListener("popstate", scheduleApplySettings);
window.addEventListener("pageshow", scheduleApplySettings);
window.addEventListener("visibilitychange", handleVisibilityChange);
window.addEventListener("pagehide", handlePageHide);

window.__quietgateYouTubeTunerController = {
  version: TUNER_VERSION,
  refresh: () => {
    loadSettings();
    syncNativeSettings();
    scheduleApplySettings();
  },
  dispose() {
    observer.disconnect();
    window.removeEventListener("yt-navigate-finish", scheduleApplySettings);
    window.removeEventListener("yt-page-data-updated", scheduleApplySettings);
    window.removeEventListener("popstate", scheduleApplySettings);
    window.removeEventListener("pageshow", scheduleApplySettings);
    window.removeEventListener("visibilitychange", handleVisibilityChange);
    window.removeEventListener("pagehide", handlePageHide);
    chrome.storage.onChanged.removeListener?.(handleStorageChange);
    stopUsageTracking();
    clearFeatureClasses();
  }
};

syncNativeSettings().finally(loadSettings);
}
