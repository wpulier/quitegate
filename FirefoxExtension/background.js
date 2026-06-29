const HOST_NAME = "com.willpulier.quietgate";
const FIREFOX_EXTENSION_ID = "quietgate@willpulier.com";
const X_INITIATOR_DOMAINS = ["x.com", "twitter.com", "mobile.x.com"];
const REDDIT_INITIATOR_DOMAINS = ["reddit.com", "www.reddit.com", "old.reddit.com", "new.reddit.com"];
const YOUTUBE_TUNER_VERSION = "2026.06.29.1200";
const X_TUNER_VERSION = "2026.06.29.1200";
const INSTAGRAM_TUNER_VERSION = "2026.06.29.1200";
const REDDIT_TUNER_VERSION = "2026.06.29.1200";
const TUNER_VERSIONS = {
  youtube: YOUTUBE_TUNER_VERSION,
  x: X_TUNER_VERSION,
  instagram: INSTAGRAM_TUNER_VERSION,
  reddit: REDDIT_TUNER_VERSION
};
const USAGE_SITE_DEFINITIONS = {
  youtube: { title: "YouTube", activityLabel: "videos" },
  x: { title: "X", activityLabel: null },
  instagram: { title: "Instagram", activityLabel: null },
  reddit: { title: "Reddit", activityLabel: null }
};
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
    instagramProfileSuggestions: false,
    instagramMessages: false,
    instagramNotifications: false,
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
  browserProfile: null,
  siteUsageSummary: null,
  youtubeUsageSummary: null
};

const TUNER_TARGETS = [
  {
    id: "youtube",
    urls: ["https://www.youtube.com/*", "https://m.youtube.com/*"],
    marker: "quietgateTuner",
    version: YOUTUBE_TUNER_VERSION,
    hiddenCountDataset: "quietgateYouTubeHiddenCount",
    css: "content/youtube.css",
    js: ["content/site-usage.js", "content/youtube.js"]
  },
  {
    id: "x",
    urls: ["https://x.com/*", "https://twitter.com/*", "https://mobile.x.com/*"],
    marker: "quietgateXTuner",
    version: X_TUNER_VERSION,
    hiddenCountDataset: "quietgateXHiddenMediaCount",
    css: "content/x.css",
    js: ["content/site-usage.js", "content/x.js"]
  },
  {
    id: "instagram",
    urls: ["https://www.instagram.com/*", "https://instagram.com/*"],
    marker: "quietgateInstagramTuner",
    version: INSTAGRAM_TUNER_VERSION,
    hiddenCountDataset: "quietgateInstagramHiddenCount",
    css: "content/instagram.css",
    js: ["content/site-usage.js", "content/instagram.js"]
  },
  {
    id: "reddit",
    urls: ["https://www.reddit.com/*", "https://old.reddit.com/*", "https://new.reddit.com/*"],
    marker: "quietgateRedditTuner",
    version: REDDIT_TUNER_VERSION,
    hiddenCountDataset: "quietgateRedditHiddenCount",
    css: "content/reddit.css",
    js: ["content/site-usage.js", "content/reddit.js"]
  }
];

const TUNER_FEATURES = {
  youtube: [
    "youtubeHome",
    "youtubeVideoSidebar",
    "youtubeShorts",
    "youtubeComments",
    "youtubeRecommendations",
    "youtubeSearch",
    "youtubeEndScreens",
    "youtubeEndScreenCards",
    "youtubeLiveChat",
    "youtubeAutoplay",
    "youtubePlaylists",
    "youtubeFundraisers",
    "youtubeMixes",
    "youtubeMerch",
    "youtubeVideoInfo",
    "youtubeTopHeader",
    "youtubeNotifications",
    "youtubeExplore",
    "youtubeMoreFromYouTube",
    "youtubeSubscriptions",
    "youtubeAnnotations",
    "youtubeUsageTracking",
    "youtubeDailyLimit"
  ],
  x: [
    "xSensitiveMedia",
    "xExplicitContent",
    "xExplicitSearch",
    "xVideos",
    "xPhotos",
    "xMediaCards",
    "xExploreTrends"
  ],
  instagram: [
    "instagramReels",
    "instagramExplore",
    "instagramSuggested",
    "instagramProfileSuggestions",
    "instagramMessages",
    "instagramNotifications",
    "instagramStories"
  ],
  reddit: [
    "redditPopularAll",
    "redditRecommendations",
    "redditNSFW",
    "redditMedia",
    "redditSidebars"
  ]
};

let currentSettings = DEFAULT_SETTINGS;
let nativeSyncPromise = null;
let nativeSyncQueued = false;
let adultDomainPayloadPromise = null;
let adultDomainSet = null;

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
      instagramProfileSuggestions: true,
      instagramMessages: true,
      instagramNotifications: true,
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
      instagramProfileSuggestions: true,
      instagramMessages: true,
      instagramNotifications: true,
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

async function savePlatformControlPayload(payload) {
  const normalized = normalizePlatformControlPayload(payload);
  if (!normalized) {
    return { ok: false, error: "Unsupported platform control payload." };
  }
  const stored = await browser.storage.local.get({
    platformControls: {},
    settingsVersion: DEFAULT_SETTINGS.settingsVersion,
    blockedRuleCount: 0
  });
  const platformControls = {
    ...(stored.platformControls || {}),
    [normalized.site]: normalized.value
  };
  await browser.storage.local.set({
    platformControls,
    platformControlsUpdatedAt: new Date().toISOString()
  });
  await recordAppliedSettings(
    stored.settingsVersion || DEFAULT_SETTINGS.settingsVersion,
    Number(stored.blockedRuleCount) || 0
  );
  return { ok: true, platformControls };
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

async function loadAdultDomainSet() {
  if (adultDomainSet) {
    return adultDomainSet;
  }
  if (!adultDomainPayloadPromise) {
    adultDomainPayloadPromise = fetch(browser.runtime.getURL("rules/adult-domains.json"))
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

function blockedDomainForURL(value) {
  let hostname;
  try {
    hostname = new URL(value).hostname.toLowerCase();
  } catch (_error) {
    return null;
  }

  const domain = customBlockedDomains(currentSettings).find((blockedDomain) => (
    hostnameMatchesDomain(hostname, blockedDomain)
  ));
  if (!domain) {
    return null;
  }

  return { domain, hostname };
}

function adultDomainForURL(value) {
  if (!adultCategoryEnabled(currentSettings) || !adultDomainSet) {
    return null;
  }
  let hostname;
  try {
    hostname = new URL(value).hostname.toLowerCase();
  } catch (_error) {
    return null;
  }
  const domain = adultDomainForHostname(hostname, adultDomainSet);
  return domain ? { domain, hostname } : null;
}

function quietGateBlockPageURL(match) {
  const params = new URLSearchParams({ site: match.hostname || match.domain });
  return browser.runtime.getURL(`blocked/blocked.html?${params.toString()}`);
}

function hostnameAndPath(value) {
  try {
    const url = new URL(value);
    return {
      hostname: url.hostname.toLowerCase(),
      pathname: url.pathname
    };
  } catch (_error) {
    return null;
  }
}

function xInitiatedRequest(details) {
  return requestInitiatedBy(details, X_INITIATOR_DOMAINS);
}

function requestInitiatedBy(details, domains) {
  const initiator = hostnameAndPath(details.initiator || details.originUrl || details.documentUrl || "");
  return Boolean(initiator && domains.some((domain) => (
    hostnameMatchesDomain(initiator.hostname, domain)
  )));
}

function xMediaRequestShouldBlock(details) {
  if (!xInitiatedRequest(details)) {
    return false;
  }

  const request = hostnameAndPath(details.url);
  if (!request) {
    return false;
  }

  const features = currentSettings.features || {};
  const isTwitterImageHost = hostnameMatchesDomain(request.hostname, "pbs.twimg.com");

  if (features.xVideos) {
    if (hostnameMatchesDomain(request.hostname, "video.twimg.com")) {
      return true;
    }
    if (isTwitterImageHost && (
      request.pathname.startsWith("/ext_tw_video_thumb/") ||
      request.pathname.startsWith("/amplify_video_thumb/")
    )) {
      return true;
    }
  }

  if (features.xPhotos && isTwitterImageHost && request.pathname.startsWith("/media/")) {
    return true;
  }

  if (features.xMediaCards) {
    if (isTwitterImageHost && request.pathname.startsWith("/card_img/")) {
      return true;
    }
    if (hostnameMatchesDomain(request.hostname, "cards-frame.twitter.com")) {
      return true;
    }
  }

  return false;
}

function socialAdultPreviewRequestShouldBlock(details) {
  const request = hostnameAndPath(details.url);
  if (!request) {
    return false;
  }

  if (!SOCIAL_ADULT_PREVIEW_DOMAINS.some((domain) => hostnameMatchesDomain(request.hostname, domain))) {
    return false;
  }

  const features = currentSettings.features || {};
  if (
    (features.xExplicitContent || features.xExplicitSearch || features.xSensitiveMedia) &&
    requestInitiatedBy(details, X_INITIATOR_DOMAINS)
  ) {
    return true;
  }
  if ((features.redditNSFW || adultCategoryEnabled(currentSettings)) && requestInitiatedBy(details, REDDIT_INITIATOR_DOMAINS)) {
    return true;
  }

  return false;
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
  if (!adultCategoryEnabled(currentSettings)) {
    return { ok: true, enabled: false, block: false };
  }
  const domainSet = await loadAdultDomainSet();
  const hostname = String(payload?.hostname || "").toLowerCase();
  const adultDomainMatch = adultDomainForHostname(hostname, domainSet);
  const blockedDomainMatch = blockedDomainForURL(payload?.url || "");
  const scored = classifierScoreForPayload(payload, adultDomainMatch, blockedDomainMatch);
  return {
    ok: true,
    enabled: true,
    block: scored.score >= 80,
    score: scored.score,
    reason: scored.reason,
    matchedDomain: scored.matchedDomain,
    settingsVersion: currentSettings.settingsVersion
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

  const nextSettings = normalizeSettings({
    ...currentSettings,
    blockedDomains: [...currentSettings.blockedDomains, domain],
    settingsVersion: `${currentSettings.settingsVersion}|reported=${domain}|at=${Date.now()}`,
    updatedAt: new Date().toISOString()
  });
  await saveSettings(nextSettings, "reported", await blockedRuleCountForSettings(nextSettings), {
    browserID: "firefox"
  });
  const storedReports = await browser.storage.local.get({ missedAdultSites: [] });
  const reports = Array.isArray(storedReports.missedAdultSites) ? storedReports.missedAdultSites : [];
  reports.push({
    domain,
    url,
    title: String(payload?.title || ""),
    reason: String(payload?.reason || ""),
    reportedAt: new Date().toISOString()
  });
  await browser.storage.local.set({ missedAdultSites: reports.slice(-200) });

  const nativeResponse = await sendNativeMessage({
    type: "reportMissedAdultSite",
    browserID: "firefox",
    domain,
    url,
    title: String(payload?.title || "")
  });
  if (nativeResponse?.ok && nativeResponse.settings) {
    const nativeSettings = normalizeSettings(nativeResponse.settings);
    await saveSettings(nativeSettings, "native", await blockedRuleCountForSettings(nativeSettings), {
      browserID: "firefox"
    });
    currentSettings = nativeSettings;
  }
  return { ok: true, domain };
}

async function tunerState(tabId, marker, hiddenCountDataset = null) {
  try {
    const results = await browser.tabs.executeScript(tabId, {
      code: `(() => {
        const dataset = document.documentElement.dataset;
        const marker = ${JSON.stringify(marker)};
        const hiddenDatasetName = ${JSON.stringify(hiddenCountDataset)};
        return {
          loaded: Boolean(dataset[marker]),
          version: dataset[marker + "Version"] || null,
          hiddenCount: hiddenDatasetName ? Number(dataset[hiddenDatasetName]) || 0 : 0
        };
      })()`
    });
    return results.find(Boolean) || { loaded: false, version: null, hiddenCount: 0 };
  } catch (_error) {
    return { loaded: true, version: null, hiddenCount: 0 };
  }
}

function tunerNeedsInjection(target, state) {
  if (!state.loaded) {
    return true;
  }
  return Boolean(target.version && state.version !== target.version);
}

function activeFeatureKeysForTuner(settings, tunerID) {
  const features = settings?.features || {};
  return (TUNER_FEATURES[tunerID] || []).filter((feature) => Boolean(features[feature]));
}

async function tunerHealthSnapshot(settings = null) {
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const checkedAt = new Date().toISOString();
  const health = {};

  for (const target of TUNER_TARGETS) {
    const id = target.id;
    let loadedTabCount = 0;
    let staleTabCount = 0;
    let hiddenCount = 0;
    let lastCheckedURL = null;

    try {
      const tabs = await browser.tabs.query({ url: target.urls });
      for (const tab of tabs) {
        if (!tab.id) {
          continue;
        }
        lastCheckedURL = tab.url || lastCheckedURL;
        const state = await tunerState(tab.id, target.marker, target.hiddenCountDataset);
        if (state.loaded) {
          loadedTabCount += 1;
        }
        if (target.version && (!state.loaded || state.version !== target.version)) {
          staleTabCount += 1;
        }
        hiddenCount += Math.max(Number(state.hiddenCount) || 0, 0);
      }
    } catch (_error) {
      // Tuner health should never block settings application.
    }

    health[id] = {
      expectedVersion: target.version || null,
      loadedTabCount,
      staleTabCount,
      activeFeatureKeys: activeFeatureKeysForTuner(normalized, id),
      hiddenCount,
      lastCheckedURL,
      lastCheckedAt: checkedAt
    };
  }

  return health;
}

async function ensureTunerInSupportedTabs() {
  for (const target of TUNER_TARGETS) {
    const tabs = await browser.tabs.query({ url: target.urls });
    for (const tab of tabs) {
      if (!tab.id) {
        continue;
      }
      const state = await tunerState(tab.id, target.marker, target.hiddenCountDataset);
      if (!tunerNeedsInjection(target, state)) {
        continue;
      }

      try {
        await browser.tabs.insertCSS(tab.id, { file: target.css });
        for (const file of target.js) {
          await browser.tabs.executeScript(tab.id, { file });
        }
      } catch (_error) {
        // Some browser-internal or discarded tabs reject injection; normal navigation will load the tuner.
      }
    }
  }
}

async function ensureWebClassifierInOpenTabs(settings) {
  if (!adultCategoryEnabled(settings) && customBlockedDomains(settings).length === 0) {
    return;
  }
  const tabs = await browser.tabs.query({ url: ["http://*/*", "https://*/*"] });
  for (const tab of tabs) {
    if (!tab.id) {
      continue;
    }
    try {
      await browser.tabs.executeScript(tab.id, { file: "content/web-classifier.js" });
    } catch (_error) {
      // Some tabs cannot be scripted; new navigation still loads the classifier.
    }
  }
}

browser.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (details.type === "main_frame" || details.type === "sub_frame") {
      const match = blockedDomainForURL(details.url) || adultDomainForURL(details.url);
      if (match) {
        return { redirectUrl: quietGateBlockPageURL(match) };
      }
    }

    if (adultDomainForURL(details.url)) {
      return { cancel: true };
    }

    if (xMediaRequestShouldBlock(details) || socialAdultPreviewRequestShouldBlock(details)) {
      return { cancel: true };
    }

    return {};
  },
  {
    urls: ["http://*/*", "https://*/*"],
    types: [
      "main_frame",
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
    ]
  },
  ["blocking"]
);

async function saveSettings(settings, source, blockedRuleCount, metadata = {}) {
  const normalized = normalizeSettings(settings);
  const browserID = metadata.browserID || null;
  const browserProfile = normalizeProfileMetadata(metadata.profile);
  currentSettings = normalized;
  await browser.storage.local.set({
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

async function blockedRuleCountForSettings(settings) {
  const normalized = normalizeSettings(settings);
  if (!adultCategoryEnabled(normalized)) {
    return customBlockedDomains(normalized).length;
  }
  const domainSet = await loadAdultDomainSet();
  return customBlockedDomains(normalized).length + domainSet.size;
}

async function currentStoredSettings() {
  return normalizeSettings(await browser.storage.local.get(DEFAULT_SETTINGS));
}

async function sendNativeMessage(message) {
  try {
    const response = await browser.runtime.sendNativeMessage(HOST_NAME, message);
    return response || { ok: false, error: "QuietGate native host returned no response." };
  } catch (error) {
    return { ok: false, error: error?.message || String(error) };
  }
}

async function adultProtectionHealth(settings, blockedRuleCount) {
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const adultEnabled = adultCategoryEnabled(normalized);
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
    staticRulesetsEnabled: [],
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

function normalizedUsageSiteID(value) {
  const siteID = String(value || "").trim().toLowerCase();
  if (siteID === "twitter") {
    return "x";
  }
  return Object.prototype.hasOwnProperty.call(USAGE_SITE_DEFINITIONS, siteID) ? siteID : null;
}

function normalizeSiteUsageValue(siteID, usage, settings = null) {
  const normalizedSiteID = normalizedUsageSiteID(siteID || usage?.siteID);
  if (!normalizedSiteID || !usage || typeof usage !== "object") {
    return null;
  }
  const totalSeconds = Math.max(Math.floor(Number(usage.totalSeconds) || 0), 0);
  const activityCount = Math.max(Math.floor(Number(usage.activityCount ?? usage.videoCount) || 0), 0);
  const lifetimeActivityCount = Math.max(Math.floor(Number(usage.lifetimeActivityCount ?? usage.lifetimeVideoCount) || 0), 0);
  const definition = USAGE_SITE_DEFINITIONS[normalizedSiteID];
  const snapshot = {
    siteID: normalizedSiteID,
    title: definition.title,
    date: typeof usage.date === "string" ? usage.date : "",
    totalSeconds,
    lifetimeSeconds: Math.max(Math.floor(Number(usage.lifetimeSeconds) || 0), 0),
    activityCount,
    lifetimeActivityCount,
    activityLabel: typeof usage.activityLabel === "string" ? usage.activityLabel : definition.activityLabel,
    lastUpdatedAt: typeof usage.lastUpdatedAt === "string" ? usage.lastUpdatedAt : null
  };

  if (normalizedSiteID === "youtube") {
    const limitSeconds = settings ? youtubeLimitSeconds(settings) : null;
    snapshot.videoCount = activityCount;
    snapshot.lifetimeVideoCount = lifetimeActivityCount;
    snapshot.limitSeconds = limitSeconds;
    snapshot.limitReached = Boolean(limitSeconds && totalSeconds >= limitSeconds);
  }

  return snapshot;
}

async function youtubeUsageSnapshot(settings = null) {
  const stored = await browser.storage.local.get({ youtubeUsage: null });
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const usage = normalizeSiteUsageValue("youtube", stored.youtubeUsage, normalized);
  if (!usage) {
    return null;
  }
  return {
    date: usage.date,
    totalSeconds: usage.totalSeconds,
    lifetimeSeconds: usage.lifetimeSeconds,
    videoCount: usage.activityCount,
    lifetimeVideoCount: usage.lifetimeActivityCount,
    limitSeconds: usage.limitSeconds,
    limitReached: usage.limitReached,
    lastUpdatedAt: usage.lastUpdatedAt
  };
}

async function siteUsageSnapshot(settings = null) {
  const stored = await browser.storage.local.get({
    siteUsageBySite: {},
    youtubeUsage: null
  });
  const normalized = settings ? normalizeSettings(settings) : await currentStoredSettings();
  const siteUsageBySite = stored.siteUsageBySite && typeof stored.siteUsageBySite === "object"
    ? stored.siteUsageBySite
    : {};
  const sites = Object.keys(USAGE_SITE_DEFINITIONS)
    .map((siteID) => {
      const usage = siteUsageBySite[siteID] || (siteID === "youtube" ? stored.youtubeUsage : null);
      return normalizeSiteUsageValue(siteID, usage, normalized);
    })
    .filter((usage) => usage && usage.date);
  if (!sites.length) {
    return null;
  }
  return {
    schemaVersion: 1,
    sites
  };
}

async function saveYouTubeUsageSummary(response) {
  if (!response || !Object.prototype.hasOwnProperty.call(response, "youtubeUsageSummary")) {
    return;
  }
  const summary = response.youtubeUsageSummary && typeof response.youtubeUsageSummary === "object"
    ? response.youtubeUsageSummary
    : null;
  await browser.storage.local.set({ youtubeUsageSummary: summary });
}

async function saveSiteUsageSummary(response) {
  if (!response || !Object.prototype.hasOwnProperty.call(response, "siteUsageSummary")) {
    return;
  }
  const summary = response.siteUsageSummary && typeof response.siteUsageSummary === "object"
    ? response.siteUsageSummary
    : null;
  await browser.storage.local.set({ siteUsageSummary: summary });
}

async function saveUsageSummaries(response) {
  await saveSiteUsageSummary(response);
  await saveYouTubeUsageSummary(response);
}

async function recordAppliedSettings(settingsVersion, blockedRuleCount, lastError = null, settings = null) {
  const stored = await browser.storage.local.get({ platformControls: {} });
  const usage = await youtubeUsageSnapshot(settings);
  const siteUsage = await siteUsageSnapshot(settings);
  const tunerHealth = await tunerHealthSnapshot(settings);
  const response = await sendNativeMessage({
    type: "recordAppliedSettings",
    browserID: "firefox",
    extensionID: FIREFOX_EXTENSION_ID,
    settingsVersion,
    extensionVersion: browser.runtime.getManifest().version,
    scriptVersions: TUNER_VERSIONS,
    tunerHealth,
    adultProtection: await adultProtectionHealth(settings, blockedRuleCount),
    platformControls: stored.platformControls || {},
    siteUsage,
    youtubeUsage: usage,
    blockedRuleCount,
    lastError
  });
  await saveUsageSummaries(response);
  return response;
}

async function syncNativeSettings() {
  if (nativeSyncPromise) {
    nativeSyncQueued = true;
    return nativeSyncPromise;
  }

  nativeSyncPromise = (async () => {
    let result;
    do {
      nativeSyncQueued = false;
      result = await syncNativeSettingsOnce();
    } while (nativeSyncQueued);
    return result;
  })().finally(() => {
    nativeSyncPromise = null;
  });
  return nativeSyncPromise;
}

async function syncNativeSettingsOnce() {
  const response = await sendNativeMessage({
    type: "getSettings",
    browserID: "firefox",
    extensionVersion: browser.runtime.getManifest().version,
    scriptVersions: TUNER_VERSIONS
  });

  if (!response?.ok || !response.settings) {
    const message = response?.error || "QuietGate native host did not return settings.";
    await browser.storage.local.set({
      nativeSyncError: message,
      nativeSyncAt: new Date().toISOString()
    });
    return { ok: false, error: message };
  }
  await saveUsageSummaries(response);

  const settings = normalizeSettings(response.settings);
  try {
    const blockedRuleCount = await blockedRuleCountForSettings(settings);
    let browserProfile = normalizeProfileMetadata(response.profile);
    const savedSettings = await saveSettings(settings, "native", blockedRuleCount, {
      browserID: response.browserID || "firefox",
      profile: browserProfile
    });
    await ensureTunerInSupportedTabs();
    await ensureWebClassifierInOpenTabs(savedSettings);
    const recordResponse = await recordAppliedSettings(
      savedSettings.settingsVersion,
      blockedRuleCount,
      null,
      savedSettings
    );
    if (!recordResponse?.ok) {
      const message = recordResponse?.error || "QuietGate could not record Firefox Helper status.";
      await browser.storage.local.set({ nativeSyncError: message });
      return { ok: false, error: message };
    }
    browserProfile = normalizeProfileMetadata(recordResponse.profile) || browserProfile;
    await browser.storage.local.set({
      browserID: recordResponse.browserID || response.browserID || "firefox",
      browserProfile,
      lastAppliedSettingsVersion: savedSettings.settingsVersion,
      lastAppliedAt: new Date().toISOString()
    });
    return {
      ok: true,
      settings: savedSettings,
      blockedRuleCount,
      browserID: recordResponse.browserID || response.browserID || "firefox",
      profile: browserProfile
    };
  } catch (error) {
    const message = error?.message || String(error);
    await browser.storage.local.set({
      nativeSyncError: message,
      nativeSyncAt: new Date().toISOString()
    });
    await recordAppliedSettings(settings.settingsVersion, 0, message, settings);
    return { ok: false, error: message };
  }
}

async function recordSiteUsageChange() {
  const settings = await currentStoredSettings();
  const stored = await browser.storage.local.get({
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
    error: response?.error || "Tortoise could not record site usage."
  };
}

async function recordYouTubeUsageChange() {
  return recordSiteUsageChange();
}

browser.runtime.onInstalled.addListener(() => {
  syncNativeSettings();
});

browser.runtime.onStartup.addListener(() => {
  syncNativeSettings();
});

browser.runtime.onMessage.addListener((message) => {
  if (message?.type === "quietgate.syncNativeSettings") {
    return syncNativeSettings();
  }

  if (message?.type === "quietgate.platformControls") {
    return savePlatformControlPayload(message.payload);
  }

  if (message?.type === "quietgate.youtubeUsageChanged") {
    return recordYouTubeUsageChange();
  }

  if (message?.type === "quietgate.siteUsageChanged") {
    return recordSiteUsageChange();
  }

  if (message?.type === "quietgate.classifyWebAdultPage") {
    return classifyWebAdultPage(message.payload);
  }

  if (message?.type === "quietgate.reportMissedAdultSite") {
    return reportMissedAdultSite(message.payload);
  }

  return false;
});

loadAdultDomainSet();
syncNativeSettings();
