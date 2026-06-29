const HOST_NAME = "com.willpulier.quietgate";
const QUIETGATE_WEB_ORIGIN = "https://www.yourtortoise.com";
const NATIVE_SYNC_TIMEOUT_MS = 3000;
const REMOTE_SYNC_ALARM = "quietgate.remotePolicySync";
const REMOTE_SYNC_PERIOD_MINUTES = 15;
const QUIETGATE_RULE_ID_BASE = 100000;
const QUIETGATE_MAX_RULES = 30000;
const X_INITIATOR_DOMAINS = ["x.com", "twitter.com", "mobile.x.com"];
const REDDIT_INITIATOR_DOMAINS = ["reddit.com", "www.reddit.com", "old.reddit.com", "new.reddit.com"];
const YOUTUBE_TUNER_VERSION = "2026.06.12.01";
const X_TUNER_VERSION = "2026.06.11.01";
const REDDIT_TUNER_VERSION = "2026.06.11.01";
const TUNER_VERSIONS = {
  youtube: YOUTUBE_TUNER_VERSION,
  x: X_TUNER_VERSION,
  reddit: REDDIT_TUNER_VERSION
};
const ADULT_STATIC_RULESETS = [
  { id: "adult-static-1", ruleCount: 30000, domainCount: 15000 },
  { id: "adult-static-2", ruleCount: 30000, domainCount: 15000 },
  { id: "adult-static-3", ruleCount: 30000, domainCount: 15000 },
  { id: "adult-static-4", ruleCount: 30000, domainCount: 15000 }
];
const ADULT_SEED_DOMAINS = [
  "pornhub.com",
  "xvideos.com",
  "xnxx.com",
  "xhamster.com",
  "redtube.com",
  "youporn.com",
  "spankbang.com",
  "chaturbate.com",
  "onlyfans.com",
  "fansly.com",
  "redgifs.com"
];
const QUIETGATE_SUBRESOURCE_TYPES = [
  "sub_frame",
  "stylesheet",
  "script",
  "image",
  "font",
  "object",
  "xmlhttprequest",
  "ping",
  "media",
  "websocket",
  "other"
];
const SOCIAL_ADULT_PREVIEW_DOMAINS = [
  "onlyfans.com",
  "fansly.com",
  "redgifs.com",
  "pornhub.com",
  "xvideos.com",
  "xnxx.com",
  "xhamster.com",
  "redtube.com",
  "youporn.com",
  "spankbang.com",
  "stripchat.com",
  "chaturbate.com",
  "cam4.com",
  "manyvids.com",
  "erome.com",
  "fapello.com"
];
let nativeSyncPromise = null;
let nativeSyncQueued = false;
let nativeSyncForceQueued = false;
let adultDomainPayloadPromise = null;
let adultDomainSet = null;

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
    instagramStories: false,
    redditPopularAll: false,
    redditRecommendations: false,
    redditNSFW: false,
    redditMedia: false,
    redditSidebars: false
  },
  blockedDomains: [],
  blockedCategories: [],
  options: {
    explicitHideStyle: "post",
    youtubeDailyLimitMinutes: 30
  },
  settingsVersion: "mode=open|features=|domains=|categories=|options=explicitHideStyle=post,youtubeDailyLimitMinutes=30",
  updatedAt: new Date(0).toISOString(),
  browserID: null,
  browserProfile: null
};

const TUNER_TARGETS = [
  {
    urls: ["https://www.youtube.com/*", "https://m.youtube.com/*"],
    marker: "quietgateTuner",
    version: YOUTUBE_TUNER_VERSION,
    css: "content/youtube.css",
    js: "content/youtube.js"
  },
  {
    id: "x",
    urls: ["https://x.com/*", "https://twitter.com/*", "https://mobile.x.com/*"],
    marker: "quietgateXTuner",
    version: X_TUNER_VERSION,
    pageJs: "content/x-page.js",
    css: "content/x.css",
    js: "content/x.js"
  },
  {
    urls: ["https://www.instagram.com/*", "https://instagram.com/*"],
    marker: "quietgateInstagramTuner",
    css: "content/instagram.css",
    js: "content/instagram.js"
  },
  {
    urls: ["https://www.reddit.com/*", "https://old.reddit.com/*", "https://new.reddit.com/*"],
    marker: "quietgateRedditTuner",
    version: REDDIT_TUNER_VERSION,
    css: "content/reddit.css",
    js: "content/reddit.js"
  }
];

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
      youtubeDailyLimit: true,
      xSensitiveMedia: true,
      xExplicitContent: true,
      xExplicitSearch: true,
      xVideos: true,
      xPhotos: true,
      xMediaCards: true,
      xExploreTrends: true,
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramStories: true,
      redditPopularAll: true,
      redditRecommendations: true,
      redditNSFW: true,
      redditMedia: true,
      redditSidebars: true
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
      youtubeDailyLimit: false,
      xSensitiveMedia: true,
      xExplicitContent: false,
      xExplicitSearch: false,
      xVideos: true,
      xPhotos: false,
      xMediaCards: false,
      xExploreTrends: false,
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramStories: false,
      redditPopularAll: true,
      redditRecommendations: true,
      redditNSFW: false,
      redditMedia: false,
      redditSidebars: false
    };
  }

  return { ...DEFAULT_SETTINGS.features };
}

function normalizeDomain(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^\*\./, "")
    .replace(/\.$/, "");
}

function normalizeSettings(settings) {
  const mode = ["open", "focus", "strict"].includes(settings?.mode)
    ? settings.mode
    : DEFAULT_SETTINGS.mode;
  const blockedDomains = Array.isArray(settings?.blockedDomains)
    ? [...new Set(settings.blockedDomains.map(normalizeDomain).filter(Boolean))].sort()
    : DEFAULT_SETTINGS.blockedDomains;
  const blockedCategories = Array.isArray(settings?.blockedCategories)
    ? [...new Set(settings.blockedCategories.map((value) => String(value || "").trim()).filter(Boolean))].sort()
    : DEFAULT_SETTINGS.blockedCategories;
  const explicitHideStyle = ["post", "media", "placeholder"].includes(settings?.options?.explicitHideStyle)
    ? settings.options.explicitHideStyle
    : DEFAULT_SETTINGS.options.explicitHideStyle;
  const youtubeDailyLimitMinutes = Math.min(
    Math.max(Number(settings?.options?.youtubeDailyLimitMinutes) || DEFAULT_SETTINGS.options.youtubeDailyLimitMinutes, 5),
    480
  );

  return {
    mode,
    features: {
      ...modeFeatures(mode),
      ...(settings?.features || {})
    },
    blockedDomains,
    blockedCategories,
    options: {
      explicitHideStyle,
      youtubeDailyLimitMinutes
    },
    settingsVersion: settings?.settingsVersion || DEFAULT_SETTINGS.settingsVersion,
    updatedAt: settings?.updatedAt || new Date().toISOString()
  };
}

function normalizeProfileMetadata(profile) {
  if (!profile || typeof profile !== "object") {
    return null;
  }

  const id = typeof profile.id === "string" ? profile.id.trim() : "";
  const name = typeof profile.name === "string" ? profile.name.trim() : "";
  const label = typeof profile.label === "string" ? profile.label.trim() : "";
  if (!id && !label) {
    return null;
  }

  return {
    id: id || null,
    name: name || null,
    label: label || (name && id && name.toLowerCase() !== id.toLowerCase() ? `${name} (${id})` : id)
  };
}

function normalizePlatformControlPayload(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const site = payload.site === "x" || payload.site === "reddit" ? payload.site : null;
  if (!site) {
    return null;
  }
  const checkedAt = typeof payload.checkedAt === "string" ? payload.checkedAt : new Date().toISOString();
  const url = typeof payload.url === "string" ? payload.url : null;
  if (site === "x") {
    return {
      site,
      value: {
        checkedAt,
        url,
        displaySensitiveMedia: typeof payload.displaySensitiveMedia === "boolean" ? payload.displaySensitiveMedia : null,
        hideSensitiveSearch: typeof payload.hideSensitiveSearch === "boolean" ? payload.hideSensitiveSearch : null
      }
    };
  }
  return {
    site,
    value: {
      checkedAt,
      url,
      showMatureContent: typeof payload.showMatureContent === "boolean" ? payload.showMatureContent : null,
      blurMatureMedia: typeof payload.blurMatureMedia === "boolean" ? payload.blurMatureMedia : null
    }
  };
}

function manifestPermissions() {
  const manifest = chrome.runtime.getManifest();
  return Array.isArray(manifest.permissions) ? manifest.permissions : [];
}

function supportsNativeMessaging() {
  return manifestPermissions().includes("nativeMessaging");
}

function extensionVersion() {
  return chrome.runtime.getManifest().version;
}

function base64URL(bytes) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function randomString(byteCount = 32) {
  const bytes = new Uint8Array(byteCount);
  crypto.getRandomValues(bytes);
  return base64URL(bytes);
}

async function ensureInstallationId() {
  const stored = await chrome.storage.local.get({ extensionInstallationId: null });
  if (stored.extensionInstallationId) {
    return stored.extensionInstallationId;
  }
  const installationId = `chrome-${randomString(24)}`;
  await chrome.storage.local.set({ extensionInstallationId: installationId });
  return installationId;
}

function policyEnvelopeToSettings(envelope) {
  const policy = envelope?.policy || {};
  const browserPolicy = policy.browser || {};
  return normalizeSettings({
    mode: policy.mode,
    features: browserPolicy.features || {},
    blockedDomains: browserPolicy.blockedDomains || [],
    blockedCategories: browserPolicy.blockedCategories || [],
    options: browserPolicy.options || {},
    settingsVersion: `policy:${Number(envelope?.settingsVersion) || 0}`,
    updatedAt: envelope?.updatedAt || new Date().toISOString()
  });
}

async function signedOutLocalSettings() {
  const stored = await chrome.storage.local.get({ localAdultBlockingEnabled: false });
  return normalizeSettings({
    ...DEFAULT_SETTINGS,
    blockedCategories: stored.localAdultBlockingEnabled ? ["adultContent"] : [],
    settingsVersion: stored.localAdultBlockingEnabled
      ? "signed-out:adultContent"
      : DEFAULT_SETTINGS.settingsVersion,
    updatedAt: new Date().toISOString()
  });
}

async function requiredHostPermissionSnapshot() {
  const origins = chrome.runtime.getManifest().host_permissions || [];
  const optionalAllSites = ["http://*/*", "https://*/*"];
  const result = {
    requiredHosts: origins,
    optionalAllSites: false,
    incognitoAllowed: false
  };
  try {
    result.optionalAllSites = await chrome.permissions.contains({ origins: optionalAllSites });
  } catch (_error) {
    result.optionalAllSites = false;
  }
  try {
    result.incognitoAllowed = await chrome.extension.isAllowedIncognitoAccess();
  } catch (_error) {
    result.incognitoAllowed = false;
  }
  return result;
}

async function quietGateFetch(path, options = {}, token = null) {
  const headers = {
    Accept: "application/json",
    ...(options.headers || {})
  };
  if (options.body && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`${QUIETGATE_WEB_ORIGIN}${path}`, {
    ...options,
    headers
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok || payload?.ok === false) {
    const error = payload?.error?.message || `QuietGate API returned ${response.status}.`;
    throw new Error(error);
  }
  return payload?.data ?? payload;
}

async function savePlatformControlPayload(payload) {
  const normalized = normalizePlatformControlPayload(payload);
  if (!normalized) {
    return { ok: false, error: "Unsupported platform control payload." };
  }
  const stored = await chrome.storage.local.get({
    platformControls: {},
    settingsVersion: DEFAULT_SETTINGS.settingsVersion,
    blockedRuleCount: 0
  });
  const platformControls = {
    ...(stored.platformControls || {}),
    [normalized.site]: normalized.value
  };
  await chrome.storage.local.set({
    platformControls,
    platformControlsUpdatedAt: new Date().toISOString()
  });
  await recordAppliedSettings(
    stored.settingsVersion || DEFAULT_SETTINGS.settingsVersion,
    Number(stored.blockedRuleCount) || 0
  );
  return { ok: true, platformControls };
}

async function quietGateBrowserID() {
  const userAgent = navigator.userAgent || "";
  if (userAgent.includes("Edg/")) {
    return "edge";
  }
  if (userAgent.includes("Arc/")) {
    return "arc";
  }

  const brands = navigator.userAgentData?.brands || [];
  if (brands.some((brand) => /arc/i.test(brand.brand || ""))) {
    return "arc";
  }

  try {
    if (navigator.brave && await navigator.brave.isBrave()) {
      return "brave";
    }
  } catch (_error) {
    // Some Chromium contexts expose navigator.brave only partially.
  }

  if (userAgent.includes("Chrome/")) {
    return "chrome";
  }

  return null;
}

function quietGateRuleIDs(count) {
  return Array.from({ length: count }, (_, index) => QUIETGATE_RULE_ID_BASE + index);
}

function hostnameMatchesDomain(hostname, domain) {
  return hostname === domain || hostname.endsWith(`.${domain}`);
}

function adultCategoryEnabled(settings) {
  const categories = Array.isArray(settings?.blockedCategories) ? settings.blockedCategories : [];
  if (categories.includes("adultContent")) {
    return true;
  }
  const domains = Array.isArray(settings?.blockedDomains) ? settings.blockedDomains : [];
  return domains.some((domain) => ADULT_SEED_DOMAINS.includes(normalizeDomain(domain)));
}

function customBlockedDomains(settings) {
  const adultEnabled = adultCategoryEnabled(settings);
  const domains = Array.isArray(settings?.blockedDomains) ? settings.blockedDomains : [];
  if (!adultEnabled) {
    return domains;
  }
  return domains.filter((domain) => !ADULT_SEED_DOMAINS.includes(normalizeDomain(domain)));
}

function blockedDomainForURL(value, domains) {
  let hostname;
  try {
    hostname = new URL(value).hostname.toLowerCase();
  } catch (_error) {
    return null;
  }

  const domain = domains.find((blockedDomain) => hostnameMatchesDomain(hostname, blockedDomain));
  return domain ? { domain, hostname } : null;
}

function rulesForDomains(domains, startIndex = 0) {
  const rules = [];
  const maxDomains = Math.floor(Math.max(QUIETGATE_MAX_RULES - startIndex, 0) / 2);
  for (const domain of domains.slice(0, maxDomains)) {
    const id = QUIETGATE_RULE_ID_BASE + startIndex + rules.length;
    rules.push({
      id,
      priority: 4,
      action: {
        type: "redirect",
        redirect: {
          extensionPath: "/blocked/blocked.html"
        }
      },
      condition: {
        urlFilter: `||${domain}^`,
        resourceTypes: ["main_frame"]
      }
    });
    rules.push({
      id: id + 1,
      priority: 3,
      action: {
        type: "block"
      },
      condition: {
        urlFilter: `||${domain}^`,
        resourceTypes: QUIETGATE_SUBRESOURCE_TYPES
      }
    });
  }
  return rules;
}

function xMediaRequestRules(settings, startIndex) {
  const features = settings.features || {};
  const candidates = [];
  const addBlockRule = (urlFilter, resourceTypes) => {
    candidates.push({
      priority: 2,
      action: { type: "block" },
      condition: {
        urlFilter,
        initiatorDomains: X_INITIATOR_DOMAINS,
        resourceTypes
      }
    });
  };

  if (features.xVideos) {
    addBlockRule("||video.twimg.com^", ["media", "xmlhttprequest"]);
    addBlockRule("||pbs.twimg.com/ext_tw_video_thumb/", ["image", "xmlhttprequest"]);
    addBlockRule("||pbs.twimg.com/amplify_video_thumb/", ["image", "xmlhttprequest"]);
  }

  if (features.xPhotos) {
    addBlockRule("||pbs.twimg.com/media/", ["image", "xmlhttprequest"]);
  }

  if (features.xMediaCards) {
    addBlockRule("||pbs.twimg.com/card_img/", ["image", "xmlhttprequest"]);
    addBlockRule("||cards-frame.twitter.com^", ["sub_frame", "xmlhttprequest"]);
  }

  return candidates
    .slice(0, Math.max(QUIETGATE_MAX_RULES - startIndex, 0))
    .map((rule, index) => ({
      id: QUIETGATE_RULE_ID_BASE + startIndex + index,
      ...rule
    }));
}

function socialAdultPreviewRequestRules(settings, startIndex) {
  const features = settings.features || {};
  const candidates = [];
  const addScopedRules = (initiatorDomains) => {
    for (const domain of SOCIAL_ADULT_PREVIEW_DOMAINS) {
      candidates.push({
        priority: 2,
        action: { type: "block" },
        condition: {
          urlFilter: `||${domain}^`,
          initiatorDomains,
          resourceTypes: ["image", "media", "sub_frame", "xmlhttprequest"]
        }
      });
    }
  };

  if (features.xExplicitContent || features.xExplicitSearch || features.xSensitiveMedia) {
    addScopedRules(X_INITIATOR_DOMAINS);
  }
  if (features.redditNSFW || adultCategoryEnabled(settings)) {
    addScopedRules(REDDIT_INITIATOR_DOMAINS);
  }

  return candidates
    .slice(0, Math.max(QUIETGATE_MAX_RULES - startIndex, 0))
    .map((rule, index) => ({
      id: QUIETGATE_RULE_ID_BASE + startIndex + index,
      ...rule
    }));
}

function rulesForSettings(settings) {
  const siteRules = rulesForDomains(customBlockedDomains(settings));
  const xRules = xMediaRequestRules(settings, siteRules.length);
  const socialAdultRules = socialAdultPreviewRequestRules(
    settings,
    siteRules.length + xRules.length
  );
  return [
    ...siteRules,
    ...xRules,
    ...socialAdultRules
  ];
}

async function syncStaticAdultRulesets(settings) {
  if (!chrome.declarativeNetRequest.updateEnabledRulesets) {
    return 0;
  }

  const shouldEnable = adultCategoryEnabled(settings);
  const allRuleSetIDs = ADULT_STATIC_RULESETS.map((ruleset) => ruleset.id);
  if (!shouldEnable) {
    try {
      await chrome.declarativeNetRequest.updateEnabledRulesets({
        disableRulesetIds: allRuleSetIDs,
        enableRulesetIds: []
      });
    } catch (_error) {
      // Static DNR is an optimization; dynamic and classifier paths still apply.
    }
    return 0;
  }

  let available = 30000;
  try {
    if (chrome.declarativeNetRequest.getAvailableStaticRuleCount) {
      available = await chrome.declarativeNetRequest.getAvailableStaticRuleCount();
    }
  } catch (_error) {
    available = 30000;
  }

  const enableRuleSetIDs = [];
  let enabledDomainCount = 0;
  for (const ruleset of ADULT_STATIC_RULESETS) {
    if (available < ruleset.ruleCount) {
      continue;
    }
    enableRuleSetIDs.push(ruleset.id);
    enabledDomainCount += ruleset.domainCount;
    available -= ruleset.ruleCount;
  }

  if (enableRuleSetIDs.length === 0) {
    return 0;
  }

  try {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      disableRulesetIds: allRuleSetIDs.filter((id) => !enableRuleSetIDs.includes(id)),
      enableRulesetIds: enableRuleSetIDs
    });
    return enabledDomainCount;
  } catch (_error) {
    try {
      await chrome.declarativeNetRequest.updateEnabledRulesets({
        disableRulesetIds: allRuleSetIDs.filter((id) => id !== ADULT_STATIC_RULESETS[0].id),
        enableRulesetIds: [ADULT_STATIC_RULESETS[0].id]
      });
      return ADULT_STATIC_RULESETS[0].domainCount;
    } catch (_fallbackError) {
      return 0;
    }
  }
}

async function applyDynamicBlockRules(settings) {
  const staticAdultDomainCount = await syncStaticAdultRulesets(settings);
  const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
  const quietGateRuleIDsToRemove = existingRules
    .filter((rule) => rule.id >= QUIETGATE_RULE_ID_BASE && rule.id < QUIETGATE_RULE_ID_BASE + QUIETGATE_MAX_RULES)
    .map((rule) => rule.id);
  const siteRuleCount = Math.floor(rulesForDomains(customBlockedDomains(settings)).length / 2);
  const addRules = rulesForSettings(settings);

  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: quietGateRuleIDsToRemove,
    addRules
  });

  return siteRuleCount + staticAdultDomainCount;
}

async function tunerState(tabId, marker) {
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId },
      func: (markerName) => {
        const dataset = document.documentElement.dataset;
        return {
          loaded: Boolean(dataset[markerName]),
          version: dataset[`${markerName}Version`] || null
        };
      },
      args: [marker]
    });
    return results.find((result) => result.result)?.result || { loaded: false, version: null };
  } catch (_error) {
    return { loaded: true, version: null };
  }
}

function tunerNeedsInjection(target, state) {
  if (!state.loaded) {
    return true;
  }
  return Boolean(target.version && state.version !== target.version);
}

function xProfileRescueScript(payload) {
  const version = payload?.version || "";
  const settingsVersion = payload?.settingsVersion || "";
  const features = payload?.features || {};
  const enabled = Boolean(features.xExplicitContent || features.xExplicitSearch || features.xSensitiveMedia);
  const controllerKey = "__quietgateXProfileRescueController";
  const hiddenClass = "qg-x-rescue-hidden";
  const headerClass = "qg-x-rescue-profile-header";
  const postClass = "qg-x-rescue-profile-post";
  const timelineClass = "qg-x-rescue-profile-timeline";
  const shellClass = "qg-x-rescue-profile-shell";
  const styleID = "quietgate-x-profile-rescue-style";
  const mediaSelector = [
    '[data-testid="tweetPhoto"]',
    'img[src*="pbs.twimg.com/media/"]',
    '[data-testid="videoComponent"]',
    '[data-testid="videoPlayer"]',
    "video"
  ].join(",");
  const reservedProfilePaths = new Set([
    "home",
    "explore",
    "notifications",
    "messages",
    "settings",
    "i",
    "search",
    "compose",
    "jobs",
    "premium",
    "verified-orgs"
  ]);
  const profileRoutePaths = new Set([
    "with_replies",
    "media",
    "highlights",
    "articles"
  ]);
  const explicitCueText =
    /(?:🔞|\b(?:nsfw|18\+|xxx|porn(?:hub|star|ography)?|only\s*fans|onlyfans|fansly|redgifs|nudes?|leaked\s+(?:nudes?|onlyfans|content)|sex(?:tape|ual\s+content)?|cam\s?(?:girl|show|model)|uncensored|explicit\s+(?:content|media|pics?|photos?|videos?)|spicy\s+(?:link|content)|link\s+in\s+bio|blowjob|handjob|pussy|cock|dick|tits?|boobs?|b[^a-z0-9\s]{1,4}bs|anal|hardcore|erotic|masturbat(?:e|ing|ion)|striptease|orgasm|cumshot|squirting|deep\s*throat|throat\s*(?:fuck|pie|bulge|bulging)|nutt(?:ed|ing))\b)/i;
  const adultDomains = new Set([
    "onlyfans.com",
    "fansly.com",
    "redgifs.com",
    "pornhub.com",
    "xvideos.com",
    "xnxx.com",
    "xhamster.com",
    "redtube.com",
    "youporn.com",
    "spankbang.com",
    "stripchat.com",
    "chaturbate.com",
    "cam4.com",
    "manyvids.com",
    "erome.com",
    "fapello.com"
  ]);

  const existing = window[controllerKey];
  const flaggedHandles = existing?.flaggedHandles instanceof Set
    ? existing.flaggedHandles
    : new Set();
  if (existing?.version === version && existing?.settingsVersion === settingsVersion) {
    existing.refresh?.();
    return;
  }
  existing?.dispose?.();

  function profileHandle() {
    const parts = location.pathname.split("/").filter(Boolean);
    const profileRoute = parts.length === 1 ||
      (parts.length === 2 && profileRoutePaths.has(parts[1].toLowerCase()));
    if (!profileRoute) {
      return null;
    }
    const handle = parts[0].toLowerCase();
    return handle && !reservedProfilePaths.has(handle) ? handle : null;
  }

  function profileFlagKey(handle) {
    return `quietgate.x.explicitProfile.${handle}`;
  }

  function profilePreviouslyFlagged(handle) {
    if (flaggedHandles.has(handle)) {
      return true;
    }
    try {
      if (sessionStorage.getItem(profileFlagKey(handle)) === "1") {
        flaggedHandles.add(handle);
        return true;
      }
    } catch (_error) {
      // Session storage is best-effort for rescue injection.
    }
    return false;
  }

  function flagProfile(handle) {
    flaggedHandles.add(handle);
    try {
      sessionStorage.setItem(profileFlagKey(handle), "1");
    } catch (_error) {
      // Session storage is best-effort for rescue injection.
    }
  }

  function accessibleText(node) {
    if (!node) {
      return "";
    }
    const attributes = ["aria-label", "title", "alt"];
    const parts = [node.textContent || ""];
    for (const attribute of attributes) {
      const value = node.getAttribute?.(attribute);
      if (value) {
        parts.push(value);
      }
    }
    for (const child of node.querySelectorAll?.("[aria-label], [title], img[alt]") || []) {
      for (const attribute of attributes) {
        const value = child.getAttribute(attribute);
        if (value) {
          parts.push(value);
        }
      }
    }
    return parts.join(" ").replace(/\s+/g, " ").trim();
  }

  function adultDomainForURL(value) {
    if (!value) {
      return null;
    }
    try {
      const hostname = new URL(value, location.href).hostname.toLowerCase().replace(/^www\./, "");
      for (const domain of adultDomains) {
        if (hostname === domain || hostname.endsWith(`.${domain}`)) {
          return domain;
        }
      }
    } catch (_error) {
      return null;
    }
    return null;
  }

  function hasAdultDomainCue(container) {
    for (const link of container.querySelectorAll?.("a[href]") || []) {
      if (adultDomainForURL(link.getAttribute("href"))) {
        return true;
      }
    }
    for (const node of container.querySelectorAll?.("img[src], video[src], video[poster], source[src]") || []) {
      if (adultDomainForURL(node.getAttribute("src")) || adultDomainForURL(node.getAttribute("poster"))) {
        return true;
      }
    }
    return false;
  }

  function ensureStyle() {
    if (document.getElementById(styleID)) {
      return;
    }
    const style = document.createElement("style");
    style.id = styleID;
    style.textContent = `
      .${hiddenClass} {
        display: none !important;
        visibility: hidden !important;
      }
    `;
    document.documentElement.appendChild(style);
  }

  function clear() {
    for (const node of document.querySelectorAll(`.${hiddenClass}, .${headerClass}, .${postClass}, .${timelineClass}, .${shellClass}`)) {
      node.classList.remove(hiddenClass, headerClass, postClass, timelineClass, shellClass);
    }
    document.documentElement.dataset.quietgateXProfileFallbackPostCount = "0";
  }

  function collectHeaderSurfaces(handle) {
    const main = document.querySelector("main") || document.body;
    const paths = new Set([
      `/${handle}/header_photo`,
      `/${handle}/photo`,
      `/${handle}/following`,
      `/${handle}/followers`,
      `/${handle}/verified_followers`
    ]);
    const surfaces = new Set();
    for (const link of main.querySelectorAll("a[href]")) {
      const href = (link.getAttribute("href") || "").split(/[?#]/)[0].toLowerCase();
      if (paths.has(href)) {
        surfaces.add(link);
      }
    }
    for (const node of main.querySelectorAll([
      '[data-testid="UserName"]',
      '[data-testid="UserDescription"]',
      '[data-testid="UserProfileHeader_Items"]',
      'img[src*="pbs.twimg.com/profile_banners/"]'
    ].join(","))) {
      surfaces.add(node.closest?.("a, [role='button']") || node);
    }
    return [...surfaces];
  }

  function hasExplicitProfileCue(posts, mediaPosts, handle) {
    const main = document.querySelector("main") || document.body;
    if (hasAdultDomainCue(main)) {
      return true;
    }
    const headerText = collectHeaderSurfaces(handle)
      .map((surface) => accessibleText(surface))
      .join(" ");
    if (headerText.length <= 5000 && explicitCueText.test(headerText)) {
      return true;
    }
    return mediaPosts.some((post) => {
      const postText = accessibleText(post);
      return postText.length <= 2000 && explicitCueText.test(postText);
    }) || posts.some((post) => hasAdultDomainCue(post));
  }

  function apply() {
    ensureStyle();
    clear();
    document.documentElement.dataset.quietgateXTunerVersion = version;
    document.documentElement.dataset.quietgateXTunerSettingsVersion = settingsVersion;

    const handle = profileHandle();
    if (!enabled || !handle) {
      if (!enabled) {
        flaggedHandles.clear();
      }
      return;
    }

    const posts = [...document.querySelectorAll('article[role="article"], [data-testid="tweet"]')]
      .filter((post) => post.isConnected);
    if (posts.length < 3) {
      return;
    }

    const mediaPosts = posts.filter((post) => post.querySelector(mediaSelector));
    if (
      mediaPosts.length >= 3 &&
      mediaPosts.length / posts.length >= 0.5 &&
      hasExplicitProfileCue(posts, mediaPosts, handle)
    ) {
      flagProfile(handle);
    }
    if (!profilePreviouslyFlagged(handle)) {
      return;
    }

    let hiddenCount = 0;
    for (const surface of collectHeaderSurfaces(handle)) {
      surface.classList.add(hiddenClass, headerClass);
      hiddenCount += 1;
    }
    const primaryColumn = document.querySelector('main [data-testid="primaryColumn"]');
    if (primaryColumn) {
      primaryColumn.classList.add(hiddenClass, shellClass);
      hiddenCount += 1;
    }
    for (const timeline of document.querySelectorAll('[aria-label^="Timeline:"][aria-label*="posts"]')) {
      timeline.classList.add(hiddenClass, timelineClass);
      hiddenCount += 1;
    }
    for (const post of posts) {
      post.classList.add(hiddenClass, postClass);
      hiddenCount += 1;
    }
    document.documentElement.dataset.quietgateXProfileFallbackPostCount = String(posts.length);
    document.documentElement.dataset.quietgateXHiddenMediaCount = String(hiddenCount);
    document.documentElement.dataset.quietgateXExplicitPostCount = String(mediaPosts.length);
  }

  let queued = false;
  function refresh() {
    if (queued) {
      return;
    }
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      apply();
    });
  }

  const observer = new MutationObserver(refresh);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener("pageshow", refresh);
  window.addEventListener("popstate", refresh);
  window[controllerKey] = {
    version,
    settingsVersion,
    flaggedHandles,
    refresh,
    dispose() {
      observer.disconnect();
      window.removeEventListener("pageshow", refresh);
      window.removeEventListener("popstate", refresh);
      clear();
    }
  };

  refresh();
  setTimeout(refresh, 500);
  setTimeout(refresh, 1500);
  setTimeout(refresh, 3000);
}

async function currentStoredSettings() {
  return normalizeSettings(await chrome.storage.local.get(DEFAULT_SETTINGS));
}

async function loadAdultDomainSet() {
  if (adultDomainSet) {
    return adultDomainSet;
  }
  if (!adultDomainPayloadPromise) {
    adultDomainPayloadPromise = fetch(chrome.runtime.getURL("rules/adult-domains.json"))
      .then((response) => response.json())
      .then((payload) => {
        adultDomainSet = new Set(Array.isArray(payload?.domains) ? payload.domains : []);
        return adultDomainSet;
      })
      .catch(() => {
        adultDomainSet = new Set(ADULT_SEED_DOMAINS);
        return adultDomainSet;
      });
  }
  return adultDomainPayloadPromise;
}

function adultDomainForHostname(hostname, domainSet) {
  const parts = String(hostname || "").toLowerCase().split(".").filter(Boolean);
  for (let index = 0; index < parts.length - 1; index += 1) {
    const candidate = parts.slice(index).join(".");
    if (domainSet.has(candidate)) {
      return candidate;
    }
  }
  return null;
}

const EXPLICIT_PAGE_CUE =
  /(?:\b(?:xxx|porn(?:hub|star|ography)?|only\s*fans|onlyfans|fansly|redgifs|nudes?|naked|hentai|nsfw|18\+|sex\s?(?:tube|video|cam|chat|dating|stories)|cam\s?(?:girl|show|model)|adult\s?(?:video|tube|cams?|content|site)|erotic|fetish|bdsm|blowjob|handjob|pussy|cock|dick|boobs?|anal|hardcore|masturbat(?:e|ing|ion)|cumshot|squirting|deep\s*throat|throat\s*(?:fuck|pie|bulge|bulging)|face\s*fuck|facefuck|nutt(?:ed|ing)|sluts?|creampie|milf)\b)/i;
const EXPLICIT_HOST_CUE =
  /(?:xxx|porn|sex|hentai|onlyfans|fansly|redgifs|xvideos|xnxx|xhamster|youporn|redtube|spankbang|chaturbate|camgirl|adulttube|fap|erome|nude|bdsm|fetish|deepthroat|facefuck|throatpie)/i;
const BENIGN_CONTEXT_CUE =
  /\b(?:adult\s+education|adult\s+learning|sexual\s+health|sex\s+education|breast\s+cancer|prostate\s+cancer|human\s+trafficking|sex\s+trafficking|news|research|medical|healthcare|dictionary|wikipedia|policy|politics)\b/i;

function textCueCount(text) {
  const matches = String(text || "").match(new RegExp(EXPLICIT_PAGE_CUE.source, "gi"));
  return matches ? matches.length : 0;
}

function classifierScoreForPayload(payload, adultDomainMatch, blockedDomainMatch) {
  if (blockedDomainMatch) {
    return { score: 120, reason: "custom-domain", matchedDomain: blockedDomainMatch.domain };
  }
  if (adultDomainMatch) {
    return { score: 110, reason: "adult-domain-list", matchedDomain: adultDomainMatch };
  }

  const hostname = String(payload?.hostname || "");
  const urlText = `${hostname} ${payload?.pathname || ""}`.toLowerCase();
  const titleMeta = `${payload?.title || ""} ${payload?.meta || ""}`;
  const headings = payload?.headings || "";
  const bodyText = payload?.bodyText || "";
  const linkHostnames = Array.isArray(payload?.linkHostnames) ? payload.linkHostnames : [];
  let score = 0;
  const reasons = [];

  if (EXPLICIT_HOST_CUE.test(urlText)) {
    score += 45;
    reasons.push("url-cue");
  }

  const titleCues = textCueCount(titleMeta);
  if (titleCues > 0) {
    score += Math.min(70, titleCues * 28);
    reasons.push("title-meta-cue");
  }

  const headingCues = textCueCount(headings);
  if (headingCues > 0) {
    score += Math.min(40, headingCues * 16);
    reasons.push("heading-cue");
  }

  const bodyCues = textCueCount(bodyText);
  if (bodyCues > 0) {
    score += Math.min(50, bodyCues * 10);
    reasons.push("body-cue");
  }

  const adultLinkHostCount = linkHostnames.filter((host) => EXPLICIT_HOST_CUE.test(host)).length;
  if (adultLinkHostCount >= 2) {
    score += Math.min(70, adultLinkHostCount * 18);
    reasons.push("adult-link-cluster");
  }

  const hasBenignContext = BENIGN_CONTEXT_CUE.test(`${titleMeta} ${headings} ${bodyText}`);
  if (hasBenignContext && adultLinkHostCount === 0 && !EXPLICIT_HOST_CUE.test(urlText)) {
    score -= 60;
    reasons.push("benign-context");
  }

  return {
    score,
    reason: reasons.join(",") || "page-signals",
    matchedDomain: null
  };
}

async function classifyWebAdultPage(payload) {
  const settings = await currentStoredSettings();
  const adultEnabled = adultCategoryEnabled(settings);
  if (!adultEnabled) {
    return { ok: true, enabled: false, block: false };
  }

  const domainSet = await loadAdultDomainSet();
  const hostname = String(payload?.hostname || "").toLowerCase();
  const adultDomainMatch = adultDomainForHostname(hostname, domainSet);
  const blockedDomainMatch = blockedDomainForURL(payload?.url || "", customBlockedDomains(settings));
  const scored = classifierScoreForPayload(payload, adultDomainMatch, blockedDomainMatch);
  const block = scored.score >= 80;
  return {
    ok: true,
    enabled: true,
    block,
    score: scored.score,
    reason: scored.reason,
    matchedDomain: scored.matchedDomain,
    settingsVersion: settings.settingsVersion
  };
}

async function reportMissedAdultSite(payload) {
  const url = String(payload?.url || "");
  const domain = normalizeDomain(payload?.domain || (() => {
    try {
      return new URL(url).hostname;
    } catch (_error) {
      return "";
    }
  })());
  if (!domain) {
    return { ok: false, error: "QuietGate could not read this site domain." };
  }

  const settings = await currentStoredSettings();
  const nextSettings = normalizeSettings({
    ...settings,
    blockedDomains: [...settings.blockedDomains, domain],
    settingsVersion: `${settings.settingsVersion}|reported=${domain}|at=${Date.now()}`,
    updatedAt: new Date().toISOString()
  });
  const blockedRuleCount = await applyDynamicBlockRules(nextSettings);
  await saveSettings(nextSettings, "reported", blockedRuleCount, {
    browserID: await quietGateBrowserID()
  });

  const storedReports = await chrome.storage.local.get({ missedAdultSites: [] });
  const reports = Array.isArray(storedReports.missedAdultSites) ? storedReports.missedAdultSites : [];
  reports.push({
    domain,
    url,
    title: String(payload?.title || ""),
    reason: String(payload?.reason || ""),
    reportedAt: new Date().toISOString()
  });
  await chrome.storage.local.set({ missedAdultSites: reports.slice(-200) });

  const nativeResponse = await sendNativeMessage({
    type: "reportMissedAdultSite",
    domain,
    url,
    title: String(payload?.title || "")
  });
  if (nativeResponse?.ok && nativeResponse.settings) {
    const nativeSettings = normalizeSettings(nativeResponse.settings);
    const nativeRuleCount = await applyDynamicBlockRules(nativeSettings);
    await saveSettings(nativeSettings, "native", nativeRuleCount, {
      browserID: await quietGateBrowserID()
    });
  }
  return { ok: true, domain };
}

async function ensureXProfileRescue(tabId, settings) {
  const payload = {
    version: X_TUNER_VERSION,
    settingsVersion: settings.settingsVersion,
    features: settings.features,
    options: settings.options
  };
  await chrome.scripting.executeScript({
    target: { tabId },
    func: xProfileRescueScript,
    args: [payload]
  });
}

async function ensureTunerInSupportedTabs() {
  const settings = await currentStoredSettings();
  for (const target of TUNER_TARGETS) {
    const tabs = await chrome.tabs.query({ url: target.urls });
    for (const tab of tabs) {
      if (!tab.id) {
        continue;
      }
      const state = await tunerState(tab.id, target.marker);
      if (!tunerNeedsInjection(target, state)) {
        if (target.id === "x") {
          try {
            await ensureXProfileRescue(tab.id, settings);
          } catch (_error) {
            // Some browser-internal or discarded tabs reject injection.
          }
        }
        continue;
      }

      try {
        if (target.pageJs) {
          await chrome.scripting.executeScript({
            target: { tabId: tab.id },
            files: [target.pageJs],
            world: "MAIN"
          });
        }
        await chrome.scripting.insertCSS({
          target: { tabId: tab.id },
          files: [target.css]
        });
        await chrome.scripting.executeScript({
          target: { tabId: tab.id },
          files: [target.js]
        });
        if (target.id === "x") {
          await ensureXProfileRescue(tab.id, settings);
        }
      } catch (_error) {
        if (target.id === "x") {
          try {
            await ensureXProfileRescue(tab.id, settings);
          } catch (_rescueError) {
            // Some browser-internal or discarded tabs reject injection.
          }
        }
        // Some browser-internal or discarded tabs reject injection; normal navigation will load the tuner.
      }
    }
  }
}

async function redirectBlockedYouTubeRoute(tabId, value) {
  if (!tabId || !value) {
    return;
  }
  let url;
  try {
    url = new URL(value);
  } catch (_error) {
    return;
  }
  if (!["www.youtube.com", "m.youtube.com"].includes(url.hostname)) {
    return;
  }

  const settings = await currentStoredSettings();
  const features = settings.features || {};
  const shouldRedirect =
    (features.youtubeShorts && url.pathname.startsWith("/shorts")) ||
    (features.youtubeExplore && /^\/feed\/(?:explore|trending)/.test(url.pathname)) ||
    (features.youtubeSubscriptions && url.pathname.startsWith("/feed/subscriptions"));
  if (!shouldRedirect) {
    return;
  }

  try {
    await chrome.tabs.update(tabId, { url: "https://www.youtube.com/" });
  } catch (_error) {
    // The content script redirect remains the primary path for tabs that cannot be updated.
  }
}

async function ensureWebClassifierInOpenTabs(settings) {
  if (!adultCategoryEnabled(settings) && customBlockedDomains(settings).length === 0) {
    return;
  }
  try {
    const hasAllSites = await chrome.permissions.contains({ origins: ["http://*/*", "https://*/*"] });
    if (!hasAllSites) {
      return;
    }
  } catch (_error) {
    return;
  }
  const tabs = await chrome.tabs.query({ url: ["http://*/*", "https://*/*"] });
  for (const tab of tabs) {
    if (!tab.id) {
      continue;
    }
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["content/web-classifier.js"]
      });
    } catch (_error) {
      // Some tabs cannot be scripted; new navigation still loads the classifier.
    }
  }
}

async function saveSettings(settings, source, blockedRuleCount, metadata = {}) {
  const normalized = normalizeSettings(settings);
  const browserID = metadata.browserID || null;
  const browserProfile = normalizeProfileMetadata(metadata.profile);
  await chrome.storage.local.set({
    ...normalized,
    browserID,
    browserProfile,
    blockedRuleCount,
    source,
    nativeSyncError: null,
    nativeSyncAt: new Date().toISOString()
  });
  return normalized;
}

function sendNativeMessage(message) {
  return new Promise((resolve) => {
    if (!supportsNativeMessaging()) {
      resolve({ ok: false, error: "QuietGate native messaging is not available in this extension build." });
      return;
    }

    let settled = false;
    const timeout = setTimeout(() => {
      if (settled) {
        return;
      }
      settled = true;
      resolve({ ok: false, error: "QuietGate native host did not respond." });
    }, NATIVE_SYNC_TIMEOUT_MS);

    chrome.runtime.sendNativeMessage(HOST_NAME, message, (response) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);

      const error = chrome.runtime.lastError;
      if (error) {
        resolve({ ok: false, error: error.message });
        return;
      }
      resolve(response || { ok: false, error: "QuietGate native host returned no response." });
    });
  });
}

async function adultProtectionHealth(settings, blockedRuleCount) {
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const adultEnabled = adultCategoryEnabled(normalized);
  let enabledStaticRulesets = [];
  try {
    if (chrome.declarativeNetRequest.getEnabledRulesets) {
      enabledStaticRulesets = await chrome.declarativeNetRequest.getEnabledRulesets();
    }
  } catch (_error) {
    enabledStaticRulesets = [];
  }

  let adultDomainCount = 0;
  if (adultEnabled) {
    try {
      adultDomainCount = (await loadAdultDomainSet()).size;
    } catch (_error) {
      adultDomainCount = ADULT_SEED_DOMAINS.length;
    }
  } else if (adultDomainSet) {
    adultDomainCount = adultDomainSet.size;
  }

  return {
    enabled: adultEnabled,
    mode: normalized.mode,
    domainListCount: adultDomainCount,
    seedDomainCount: ADULT_SEED_DOMAINS.length,
    staticRulesetsEnabled: enabledStaticRulesets.filter((id) => id.startsWith("adult-static-")),
    dynamicRuleCount: Number(blockedRuleCount) || 0,
    scriptVersions: TUNER_VERSIONS,
    canaryDomains: ["redgifs.com", "www.redgifs.com"],
    checkedAt: new Date().toISOString()
  };
}

function youtubeLimitSeconds(settings) {
  if (!settings?.features?.youtubeDailyLimit) {
    return null;
  }
  const minutes = Math.min(
    Math.max(Number(settings?.options?.youtubeDailyLimitMinutes) || DEFAULT_SETTINGS.options.youtubeDailyLimitMinutes, 5),
    480
  );
  return minutes * 60;
}

async function youtubeUsageSnapshot(settings = null) {
  const stored = await chrome.storage.local.get({ youtubeUsage: null });
  const usage = stored.youtubeUsage;
  if (!usage || typeof usage !== "object") {
    return null;
  }
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const limitSeconds = youtubeLimitSeconds(normalized);
  const totalSeconds = Math.max(Math.floor(Number(usage.totalSeconds) || 0), 0);
  return {
    date: typeof usage.date === "string" ? usage.date : "",
    totalSeconds,
    lifetimeSeconds: Math.max(Math.floor(Number(usage.lifetimeSeconds) || 0), 0),
    videoCount: Math.max(Math.floor(Number(usage.videoCount) || 0), 0),
    lifetimeVideoCount: Math.max(Math.floor(Number(usage.lifetimeVideoCount) || 0), 0),
    limitSeconds,
    limitReached: Boolean(limitSeconds && totalSeconds >= limitSeconds),
    lastUpdatedAt: typeof usage.lastUpdatedAt === "string" ? usage.lastUpdatedAt : null
  };
}

async function extensionAuthStatus() {
  const stored = await chrome.storage.local.get({
    extensionDevice: null,
    extensionDeviceToken: null,
    extensionInstallationId: null,
    extensionLastSyncAt: null,
    extensionSyncError: null,
    policySettingsVersion: null,
    source: null,
    blockedRuleCount: 0,
    localAdultBlockingEnabled: false
  });
  const permissions = await requiredHostPermissionSnapshot();
  return {
    ok: true,
    signedIn: Boolean(stored.extensionDeviceToken && stored.extensionDevice),
    device: stored.extensionDevice || null,
    installationId: stored.extensionInstallationId || null,
    extensionVersion: extensionVersion(),
    source: stored.source || null,
    policySettingsVersion: stored.policySettingsVersion || null,
    lastSyncAt: stored.extensionLastSyncAt || null,
    syncError: stored.extensionSyncError || null,
    blockedRuleCount: Number(stored.blockedRuleCount) || 0,
    localAdultBlockingEnabled: Boolean(stored.localAdultBlockingEnabled),
    permissions
  };
}

async function saveRemoteSettings(envelope, options = {}) {
  const settings = policyEnvelopeToSettings(envelope);
  const stored = await chrome.storage.local.get({
    lastAppliedSettingsVersion: null,
    blockedRuleCount: 0
  });
  let blockedRuleCount = Number(stored.blockedRuleCount) || 0;
  if (options.forceApply || stored.lastAppliedSettingsVersion !== settings.settingsVersion) {
    blockedRuleCount = await applyDynamicBlockRules(settings);
  }
  const savedSettings = await saveSettings(settings, "remote", blockedRuleCount, {
    browserID: await quietGateBrowserID()
  });
  await chrome.storage.local.set({
    policySettingsVersion: Number(envelope?.settingsVersion) || 0,
    policyUpdatedAt: envelope?.updatedAt || null,
    extensionLastSyncAt: new Date().toISOString(),
    extensionSyncError: null,
    lastAppliedSettingsVersion: savedSettings.settingsVersion,
    lastAppliedAt: new Date().toISOString()
  });
  await ensureTunerInSupportedTabs();
  await ensureWebClassifierInOpenTabs(savedSettings);
  await recordRemoteHealth(savedSettings, blockedRuleCount, { lastSyncAt: new Date().toISOString() });
  return { ok: true, settings: savedSettings, blockedRuleCount, source: "remote" };
}

async function syncRemotePolicy(options = {}) {
  const stored = await chrome.storage.local.get({ extensionDeviceToken: null });
  if (!stored.extensionDeviceToken) {
    return { ok: false, error: "QuietGate extension is not signed in." };
  }
  try {
    const response = await quietGateFetch("/api/extension/policy", {
      method: "GET",
      cache: "no-store"
    }, stored.extensionDeviceToken);
    if (response?.device) {
      await chrome.storage.local.set({ extensionDevice: response.device });
    }
    return await saveRemoteSettings(response?.policy, options);
  } catch (error) {
    const message = error?.message || String(error);
    await chrome.storage.local.set({
      extensionSyncError: message,
      extensionLastSyncAt: new Date().toISOString()
    });
    return { ok: false, error: message };
  }
}

async function syncSignedOutSettings(options = {}) {
  const settings = await signedOutLocalSettings();
  const stored = await chrome.storage.local.get({
    lastAppliedSettingsVersion: null,
    blockedRuleCount: 0
  });
  let blockedRuleCount = Number(stored.blockedRuleCount) || 0;
  if (options.forceApply || stored.lastAppliedSettingsVersion !== settings.settingsVersion) {
    blockedRuleCount = await applyDynamicBlockRules(settings);
  }
  const savedSettings = await saveSettings(settings, "local", blockedRuleCount, {
    browserID: await quietGateBrowserID()
  });
  await chrome.storage.local.set({
    lastAppliedSettingsVersion: savedSettings.settingsVersion,
    lastAppliedAt: new Date().toISOString(),
    extensionSyncError: null
  });
  await ensureTunerInSupportedTabs();
  await ensureWebClassifierInOpenTabs(savedSettings);
  return { ok: true, settings: savedSettings, blockedRuleCount, source: "local" };
}

async function syncQuietGateSettings(options = {}) {
  const stored = await chrome.storage.local.get({ extensionDeviceToken: null });
  if (stored.extensionDeviceToken) {
    const response = await syncRemotePolicy(options);
    if (response?.ok) {
      return response;
    }
    return response;
  }
  const fixtureState = await chrome.storage.local.get({ source: null });
  if (fixtureState.source === "smoke") {
    return {
      ok: true,
      settings: await currentStoredSettings(),
      blockedRuleCount: Number((await chrome.storage.local.get({ blockedRuleCount: 0 })).blockedRuleCount) || 0,
      source: "smoke"
    };
  }
  if (supportsNativeMessaging()) {
    return syncNativeSettings(options);
  }
  return syncSignedOutSettings(options);
}

async function recordRemoteHealth(settings = null, blockedRuleCount = null, metadata = {}) {
  const stored = await chrome.storage.local.get({
    extensionDeviceToken: null,
    source: null,
    blockedRuleCount: 0,
    missedAdultSites: []
  });
  if (!stored.extensionDeviceToken) {
    return { ok: true, skipped: true };
  }
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const ruleCount = blockedRuleCount == null
    ? Number(stored.blockedRuleCount) || 0
    : Number(blockedRuleCount) || 0;
  const permissions = await requiredHostPermissionSnapshot();
  const payload = {
    extensionVersion: extensionVersion(),
    rulesetVersion: normalized.settingsVersion,
    scriptVersions: TUNER_VERSIONS,
    canaryStatus: {
      redgifs: adultCategoryEnabled(normalized),
      x: Boolean(normalized.features?.xSensitiveMedia || normalized.features?.xExplicitContent || normalized.features?.xExplicitSearch),
      reddit: Boolean(normalized.features?.redditNSFW)
    },
    adultProtection: await adultProtectionHealth(normalized, ruleCount),
    platformMetadata: {
      source: stored.source || metadata.source || null,
      browserID: await quietGateBrowserID(),
      manifestVersion: chrome.runtime.getManifest().manifest_version
    },
    enabledPermissions: permissions,
    recentBlockCounters: {
      missedAdultSiteReports: Array.isArray(stored.missedAdultSites) ? stored.missedAdultSites.length : 0,
      blockedRuleCount: ruleCount
    },
    lastSyncAt: metadata.lastSyncAt || null
  };
  try {
    await quietGateFetch("/api/extension/health", {
      method: "POST",
      body: JSON.stringify(payload)
    }, stored.extensionDeviceToken);
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error?.message || String(error) };
  }
}

async function recordAppliedSettings(settingsVersion, blockedRuleCount, lastError = null, settings = null) {
  const browserID = await quietGateBrowserID();
  const stored = await chrome.storage.local.get({ platformControls: {} });
  const usage = await youtubeUsageSnapshot(settings);
  const message = {
    type: "recordAppliedSettings",
    settingsVersion,
    extensionVersion: chrome.runtime.getManifest().version,
    scriptVersions: TUNER_VERSIONS,
    adultProtection: await adultProtectionHealth(settings, blockedRuleCount),
    platformControls: stored.platformControls || {},
    youtubeUsage: usage,
    blockedRuleCount,
    lastError
  };
  if (browserID) {
    message.browserID = browserID;
  }
  if (!supportsNativeMessaging()) {
    const remoteResponse = await recordRemoteHealth(settings, blockedRuleCount, { source: "extension" });
    return remoteResponse?.ok ? { ok: true } : remoteResponse;
  }
  return sendNativeMessage(message);
}

async function syncNativeSettings(options = {}) {
  if (nativeSyncPromise) {
    nativeSyncQueued = true;
    nativeSyncForceQueued = nativeSyncForceQueued || options.forceApply === true;
    return nativeSyncPromise;
  }

  nativeSyncForceQueued = options.forceApply === true;
  nativeSyncPromise = (async () => {
    let result;
    do {
      const forceApply = nativeSyncForceQueued;
      nativeSyncQueued = false;
      nativeSyncForceQueued = false;
      result = await syncNativeSettingsOnce({
        ...options,
        forceApply: options.forceApply === true || forceApply
      });
    } while (nativeSyncQueued);
    return result;
  })().finally(() => {
    nativeSyncPromise = null;
  });
  return nativeSyncPromise;
}

async function syncNativeSettingsOnce(options = {}) {
  const browserID = await quietGateBrowserID();
  const response = await sendNativeMessage({
    type: "getSettings",
    extensionVersion: chrome.runtime.getManifest().version,
    scriptVersions: TUNER_VERSIONS,
    browserID
  });

  if (!response?.ok || !response.settings) {
    const message = response?.error || "QuietGate native host did not return settings.";
    await chrome.storage.local.set({
      nativeSyncError: message,
      nativeSyncAt: new Date().toISOString()
    });
    return { ok: false, error: message };
  }

  const settings = normalizeSettings(response.settings);
  try {
    const stored = await chrome.storage.local.get({
      lastAppliedSettingsVersion: null,
      blockedRuleCount: 0
    });
    let blockedRuleCount = Number(stored.blockedRuleCount) || 0;
    if (options.forceApply || stored.lastAppliedSettingsVersion !== settings.settingsVersion) {
      blockedRuleCount = await applyDynamicBlockRules(settings);
    }
    let browserProfile = normalizeProfileMetadata(response.profile);
    const effectiveBrowserID = response.browserID || browserID || null;
    const savedSettings = await saveSettings(settings, "native", blockedRuleCount, {
      browserID: effectiveBrowserID,
      profile: browserProfile
    });
    const recordResponse = await recordAppliedSettings(
      savedSettings.settingsVersion,
      blockedRuleCount,
      null,
      savedSettings
    );
    if (!recordResponse?.ok) {
      const message = recordResponse?.error || "QuietGate could not record Browser Helper status.";
      await chrome.storage.local.set({ nativeSyncError: message });
      return { ok: false, error: message };
    }
    browserProfile = normalizeProfileMetadata(recordResponse.profile) || browserProfile;
    await chrome.storage.local.set({
      browserID: recordResponse.browserID || effectiveBrowserID,
      browserProfile,
      lastAppliedSettingsVersion: savedSettings.settingsVersion,
      lastAppliedAt: new Date().toISOString()
    });
    await ensureTunerInSupportedTabs();
    await ensureWebClassifierInOpenTabs(savedSettings);
    return {
      ok: true,
      settings: savedSettings,
      blockedRuleCount,
      browserID: recordResponse.browserID || effectiveBrowserID,
      profile: browserProfile
    };
  } catch (error) {
    const message = error?.message || String(error);
    await chrome.storage.local.set({
      nativeSyncError: message,
      nativeSyncAt: new Date().toISOString()
    });
    await recordAppliedSettings(settings.settingsVersion, 0, message, settings);
    return { ok: false, error: message };
  }
}

async function recordYouTubeUsageChange() {
  const settings = await currentStoredSettings();
  const stored = await chrome.storage.local.get({
    settingsVersion: settings.settingsVersion || DEFAULT_SETTINGS.settingsVersion,
    blockedRuleCount: 0
  });
  const response = await recordAppliedSettings(
    stored.settingsVersion || settings.settingsVersion,
    Number(stored.blockedRuleCount) || 0,
    null,
    settings
  );
  return response?.ok ? { ok: true } : {
    ok: false,
    error: response?.error || "QuietGate could not record YouTube usage."
  };
}

async function startExtensionConnect() {
  const installationId = await ensureInstallationId();
  const nonce = randomString(24);
  const payload = {
    installationId,
    nonce,
    extensionId: chrome.runtime.id,
    extensionVersion: extensionVersion(),
    createdAt: Date.now()
  };
  await chrome.storage.local.set({ pendingExtensionAuth: payload });
  const params = new URLSearchParams({
    installationId,
    nonce,
    extensionId: chrome.runtime.id,
    extensionVersion: extensionVersion()
  });
  await chrome.tabs.create({ url: `${QUIETGATE_WEB_ORIGIN}/extension/connect?${params.toString()}` });
  return { ok: true, installationId };
}

async function completeExtensionLink(payload, sender = null) {
  const senderURL = sender?.url || sender?.origin || "";
  if (senderURL && !senderURL.startsWith(QUIETGATE_WEB_ORIGIN)) {
    return { ok: false, error: "QuietGate rejected a link message from an unknown origin." };
  }

  const stored = await chrome.storage.local.get({ pendingExtensionAuth: null });
  const pending = stored.pendingExtensionAuth;
  if (!pending) {
    return { ok: false, error: "No pending QuietGate extension connection." };
  }

  const code = String(payload?.code || "");
  const nonce = String(payload?.nonce || "");
  const installationId = String(payload?.installationId || "");
  const extensionId = String(payload?.extensionId || chrome.runtime.id);
  const extensionVersionValue = String(payload?.extensionVersion || extensionVersion());
  if (
    !code ||
    nonce !== pending.nonce ||
    installationId !== pending.installationId ||
    extensionId !== chrome.runtime.id
  ) {
    return { ok: false, error: "QuietGate extension connection did not match the pending request." };
  }

  const result = await quietGateFetch("/api/extension/exchange", {
    method: "POST",
    body: JSON.stringify({
      code,
      nonce,
      installationId,
      extensionId,
      extensionVersion: extensionVersionValue
    })
  });
  await chrome.storage.local.set({
    extensionDeviceToken: result.deviceToken,
    extensionDevice: result.device,
    extensionInstallationId: installationId,
    pendingExtensionAuth: null,
    extensionSyncError: null
  });
  await syncRemotePolicy({ forceApply: true });
  return { ok: true, device: result.device };
}

async function revokeExtensionDevice() {
  const stored = await chrome.storage.local.get({ extensionDeviceToken: null });
  if (stored.extensionDeviceToken) {
    try {
      await quietGateFetch("/api/extension/revoke", { method: "POST" }, stored.extensionDeviceToken);
    } catch (_error) {
      // Local token removal still needs to happen when the server is unreachable.
    }
  }
  await chrome.storage.local.remove([
    "extensionDeviceToken",
    "extensionDevice",
    "policySettingsVersion",
    "policyUpdatedAt",
    "extensionSyncError"
  ]);
  return syncSignedOutSettings({ forceApply: true });
}

async function requestAllSitesPermission() {
  const origins = ["http://*/*", "https://*/*"];
  const granted = await chrome.permissions.request({ origins });
  if (!granted) {
    return { ok: false, error: "All-sites permission was not granted." };
  }
  const settings = await currentStoredSettings();
  await ensureWebClassifierInOpenTabs(settings);
  await recordRemoteHealth(settings, null, { source: "permission" });
  return { ok: true, permissions: await requiredHostPermissionSnapshot() };
}

async function setLocalAdultBlocking(enabled) {
  await chrome.storage.local.set({ localAdultBlockingEnabled: Boolean(enabled) });
  return syncSignedOutSettings({ forceApply: true });
}

function ensureRemoteSyncAlarm() {
  if (!chrome.alarms?.create) {
    return;
  }
  chrome.alarms.create(REMOTE_SYNC_ALARM, {
    periodInMinutes: REMOTE_SYNC_PERIOD_MINUTES
  });
}

chrome.runtime.onInstalled.addListener(() => {
  ensureRemoteSyncAlarm();
  syncQuietGateSettings({ forceApply: true });
});

chrome.runtime.onStartup.addListener(() => {
  ensureRemoteSyncAlarm();
  syncQuietGateSettings();
});

if (chrome.alarms?.onAlarm) {
  chrome.alarms.onAlarm.addListener((alarm) => {
    if (alarm?.name === REMOTE_SYNC_ALARM) {
      syncQuietGateSettings();
    }
  });
}

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  const url = tab.url || changeInfo.url || "";
  if (changeInfo.status !== "complete" && !changeInfo.url) {
    return;
  }

  if (/^https:\/\/(?:www\.youtube\.com|m\.youtube\.com)\//i.test(url)) {
    redirectBlockedYouTubeRoute(tabId, url);
  }

  if (/^https:\/\/(?:x\.com|twitter\.com|mobile\.x\.com)\//i.test(url)) {
    ensureTunerInSupportedTabs();
  }
});

function messageError(error) {
  return {
    ok: false,
    error: error?.message || String(error || "QuietGate could not complete this browser request.")
  };
}

function respondToMessage(promise, sendResponse) {
  Promise.resolve(promise)
    .then((response) => sendResponse(response))
    .catch((error) => sendResponse(messageError(error)));
  return true;
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "quietgate.syncNativeSettings") {
    if (supportsNativeMessaging()) {
      return respondToMessage(syncNativeSettings({ forceApply: message.forceApply === true }), sendResponse);
    }
    return respondToMessage((async () => ({
      ok: true,
      skipped: true,
      settings: await currentStoredSettings()
    }))(), sendResponse);
  }

  if (message?.type === "quietgate.syncQuietGateSettings") {
    return respondToMessage(syncQuietGateSettings({ forceApply: message.forceApply === true }), sendResponse);
  }

  if (message?.type === "quietgate.extensionStatus") {
    return respondToMessage(extensionAuthStatus(), sendResponse);
  }

  if (message?.type === "quietgate.startExtensionConnect") {
    return respondToMessage(startExtensionConnect(), sendResponse);
  }

  if (message?.type === "quietgate.linkExtension") {
    return respondToMessage(completeExtensionLink(message, sender), sendResponse);
  }

  if (message?.type === "quietgate.syncRemotePolicy") {
    return respondToMessage(syncRemotePolicy({ forceApply: message.forceApply === true }), sendResponse);
  }

  if (message?.type === "quietgate.revokeExtensionDevice") {
    return respondToMessage(revokeExtensionDevice(), sendResponse);
  }

  if (message?.type === "quietgate.requestAllSitesPermission") {
    return respondToMessage(requestAllSitesPermission(), sendResponse);
  }

  if (message?.type === "quietgate.setLocalAdultBlocking") {
    return respondToMessage(setLocalAdultBlocking(message.enabled), sendResponse);
  }

  if (message?.type === "quietgate.platformControls") {
    return respondToMessage(savePlatformControlPayload(message.payload), sendResponse);
  }

  if (message?.type === "quietgate.youtubeUsageChanged") {
    return respondToMessage(recordYouTubeUsageChange(), sendResponse);
  }

  if (message?.type === "quietgate.classifyWebAdultPage") {
    return respondToMessage(classifyWebAdultPage(message.payload), sendResponse);
  }

  if (message?.type === "quietgate.reportMissedAdultSite") {
    return respondToMessage(reportMissedAdultSite(message.payload), sendResponse);
  }

  return false;
});

if (chrome.runtime.onMessageExternal) {
  chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {
    if (message?.type === "quietgate.linkExtension") {
      return respondToMessage(completeExtensionLink(message, sender), sendResponse);
    }
    return false;
  });
}
