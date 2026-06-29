(() => {
const TUNER_VERSION = "2026.06.29.1200";
const existingController = window.__quietgateXTunerController;
if (existingController?.version === TUNER_VERSION) {
  existingController.refresh?.();
  return;
}
existingController?.dispose?.();

const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;

const DEFAULT_SETTINGS = {
  mode: "open",
  features: {
    xSensitiveMedia: false,
    xExplicitContent: false,
    xExplicitSearch: false,
    xVideos: false,
    xPhotos: false,
    xMediaCards: false,
    xExploreTrends: false
  },
  options: {
    explicitHideStyle: "post"
  },
  blockedDomains: []
};

const FEATURE_CLASSES = {
  xSensitiveMedia: "qg-x-sensitive-media",
  xExplicitContent: "qg-x-explicit-content",
  xExplicitSearch: "qg-x-explicit-search",
  xVideos: "qg-x-videos",
  xPhotos: "qg-x-photos",
  xMediaCards: "qg-x-media-cards",
  xExploreTrends: "qg-x-explore-trends"
};

const HIDDEN_CLASS = "qg-x-hidden-media";
const PLACEHOLDER_CLASS = "qg-x-explicit-placeholder";
const MANAGED_MEDIA_CLASSES = [
  HIDDEN_CLASS,
  "qg-x-sensitive-media-surface",
  "qg-x-explicit-post",
  "qg-x-explicit-profile",
  "qg-x-explicit-profile-shell",
  "qg-x-explicit-profile-header",
  "qg-x-explicit-sidebar",
  "qg-x-explicit-media-surface",
  "qg-x-explicit-search-media",
  "qg-x-explicit-search-result",
  "qg-x-video-media-surface",
  "qg-x-photo-media-surface",
  "qg-x-card-media-surface"
];
const VALID_EXPLICIT_HIDE_STYLES = new Set(["post", "media", "placeholder"]);

const PHOTO_SELECTOR = [
  '[data-testid="tweetPhoto"]',
  'img[src*="pbs.twimg.com/media/"]',
  'img[src*="pbs.twimg.com/ext_tw_video_thumb/"]',
  'img[src*="pbs.twimg.com/amplify_video_thumb/"]'
].join(",");

const VIDEO_SELECTOR = [
  '[data-testid="videoComponent"]',
  '[data-testid="videoPlayer"]',
  "video"
].join(",");

const CARD_SELECTOR = [
  '[data-testid="card.wrapper"]',
  '[data-testid="card.layoutLarge.media"]',
  '[data-testid="card.layoutSmall.media"]'
].join(",");

const MEDIA_SELECTOR = [
  PHOTO_SELECTOR,
  VIDEO_SELECTOR,
  CARD_SELECTOR
].join(",");
const RAW_PROFILE_MEDIA_SELECTOR = [
  '[data-testid="tweetPhoto"]',
  'img[src*="pbs.twimg.com/media/"]',
  '[data-testid="videoComponent"]',
  '[data-testid="videoPlayer"]',
  "video"
].join(",");

const SENSITIVE_WARNING_TEXT =
  /\b(content warning|sensitive content|potentially sensitive|sensitive material|sensitive media|adult content|adult material|graphic content|graphic media|graphic violence|violent content|nudity|nsfw|media hidden|show sensitive|view sensitive|may contain sensitive|might include sensitive|following may contain sensitive|following media includes potentially sensitive|post author flagged)\b/i;
const EXPLICIT_CUE_TEXT =
  /(?:🔞|\b(?:nsfw|18\+|xxx|porn(?:hub|star|ography)?|only\s*fans|onlyfans|fansly|redgifs|nudes?|leaked\s+(?:nudes?|onlyfans|content)|sex(?:tape|ual\s+content)?|cam\s?(?:girl|show|model)|uncensored|explicit\s+(?:content|media|pics?|photos?|videos?)|spicy\s+(?:link|content)|link\s+in\s+bio|blowjob|handjob|pussy|cock|dick|tits?|boobs?|b[^a-z0-9\s]{1,4}bs|anal|hardcore|erotic|masturbat(?:e|ing|ion)|striptease|orgasm|cumshot|squirting|deep\s*throat|throat\s*(?:fuck|pie|bulge|bulging)|nutt(?:ed|ing))\b)/i;
const ADULT_DOMAIN_HINTS = new Set([
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

const PAGE_DETECTOR_MESSAGE_SOURCE = "quietgate-x-page-detector";
const STATUS_ID_PATTERN = /\/(?:status|statuses)\/(\d{1,20})(?:[/?#]|$)/i;
const NUMERIC_ID_PATTERN = /^\d{1,20}$/;
const MEDIA_KEY_PATTERN = /^(?:\d+_)?(\d{1,20})$/;
const MEDIA_PATH_ID_PATTERN = /\/(?:ext_tw_video_thumb|amplify_video_thumb|tweet_video_thumb)\/(\d{1,20})(?:\/|$)/i;
const MAX_SENSITIVE_METADATA_VALUES = 1000;
const sensitivePostIDs = new Set();
const sensitiveMediaURLHints = new Set();
const sensitiveMediaIDs = new Set();
const explicitProfileHandles = new Set();
const PROFILE_ROUTE_PATHS = new Set([
  "with_replies",
  "media",
  "highlights",
  "articles"
]);
const RESERVED_PROFILE_PATHS = new Set([
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

let currentSettings = DEFAULT_SETTINGS;
let syncInFlight = false;
let applyQueued = false;
let usageController = null;

document.documentElement.dataset.quietgateXTuner = "loaded";
document.documentElement.dataset.quietgateXTunerVersion = TUNER_VERSION;
document.documentElement.dataset.quietgateXHiddenMediaCount = "0";
document.documentElement.dataset.quietgateXSensitivePostCount = "0";
document.documentElement.dataset.quietgateXSensitiveMediaCount = "0";
document.documentElement.dataset.quietgateXExplicitPostCount = "0";
document.documentElement.dataset.quietgateXProfileFallbackPostCount = "0";
document.documentElement.dataset.quietgateXSearchMediaCount = "0";
document.documentElement.dataset.quietgateXSearchResultCount = "0";
document.documentElement.dataset.quietgateXLastDecision = "";

function normalizedMediaURLHint(value) {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  try {
    const urlValue = /^(?:https?:\/\/|\/)/i.test(trimmed)
      ? trimmed
      : /^(?:[^/]+\.)?twimg\.com\//i.test(trimmed)
        ? `https://${trimmed}`
        : "";
    if (!urlValue) {
      return null;
    }
    const url = new URL(urlValue, location.href);
    if (!/(^|\.)twimg\.com$/i.test(url.hostname)) {
      return null;
    }
    return `${url.hostname}${url.pathname}`;
  } catch (_error) {
    return null;
  }
}

function normalizedPostID(value) {
  const normalized = String(value || "").trim();
  return NUMERIC_ID_PATTERN.test(normalized) ? normalized : null;
}

function normalizedMediaID(value) {
  const normalized = String(value || "").trim();
  const match = normalized.match(MEDIA_KEY_PATTERN);
  return match ? match[1] : null;
}

function mediaIDsFromURL(value) {
  const ids = new Set();
  if (typeof value !== "string") {
    return ids;
  }

  try {
    const url = new URL(value, location.href);
    if (!/(^|\.)twimg\.com$/i.test(url.hostname)) {
      return ids;
    }
    const match = url.pathname.match(MEDIA_PATH_ID_PATTERN);
    if (match) {
      ids.add(match[1]);
    }
  } catch (_error) {
    // Ignore invalid and blob-like media URLs.
  }

  return ids;
}

function addBoundedValues(target, values, normalizeValue) {
  if (!Array.isArray(values)) {
    return false;
  }

  let changed = false;
  for (const rawValue of values) {
    const value = normalizeValue(rawValue);
    if (!value || target.has(value)) {
      continue;
    }
    target.add(value);
    changed = true;
  }

  while (target.size > MAX_SENSITIVE_METADATA_VALUES) {
    target.delete(target.values().next().value);
  }

  return changed;
}

function handlePageDetectorMessage(event) {
  if (event.source !== window || event.data?.source !== PAGE_DETECTOR_MESSAGE_SOURCE) {
    return;
  }
  if (event.data?.type !== "sensitive-media") {
    return;
  }

  const postIDsChanged = addBoundedValues(sensitivePostIDs, event.data.tweetIDs, normalizedPostID);
  const mediaURLsChanged = addBoundedValues(sensitiveMediaURLHints, event.data.mediaURLs, normalizedMediaURLHint);
  const mediaIDsChanged = addBoundedValues(sensitiveMediaIDs, event.data.mediaIDs, normalizedMediaID);
  document.documentElement.dataset.quietgateXSensitivePostCount = String(sensitivePostIDs.size);
  document.documentElement.dataset.quietgateXSensitiveMediaCount = String(sensitiveMediaIDs.size);

  if (postIDsChanged || mediaURLsChanged || mediaIDsChanged) {
    scheduleApplySettings();
  }
}

function injectPageDetectorScript() {
  try {
    const script = document.createElement("script");
    script.src = quietGateBrowser.runtime.getURL("content/x-page.js");
    script.async = false;
    script.onload = () => script.remove();
    (document.head || document.documentElement).appendChild(script);
  } catch (_error) {
    // The warning-text fallback still works when page-world injection is unavailable.
  }
}

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
    },
    blockedDomains: Array.isArray(value.blockedDomains)
      ? value.blockedDomains.map(normalizeDomain).filter(Boolean)
      : DEFAULT_SETTINGS.blockedDomains
  };
}

function modeFeatures(mode) {
  if (mode === "strict") {
    return {
      xSensitiveMedia: true,
      xExplicitContent: true,
      xExplicitSearch: true,
      xVideos: true,
      xPhotos: true,
      xMediaCards: true,
      xExploreTrends: true
    };
  }

  if (mode === "focus") {
    return {
      xSensitiveMedia: true,
      xExplicitContent: false,
      xExplicitSearch: false,
      xVideos: true,
      xPhotos: false,
      xMediaCards: false,
      xExploreTrends: false
    };
  }

  return {
    xSensitiveMedia: false,
    xExplicitContent: false,
    xExplicitSearch: false,
    xVideos: false,
    xPhotos: false,
    xMediaCards: false,
    xExploreTrends: false
  };
}

function explicitHideStyle() {
  const value = currentSettings.options?.explicitHideStyle || DEFAULT_SETTINGS.options.explicitHideStyle;
  return VALID_EXPLICIT_HIDE_STYLES.has(value) ? value : DEFAULT_SETTINGS.options.explicitHideStyle;
}

function normalizeDomain(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^\*\./, "")
    .replace(/\.$/, "");
}

function hostnameMatchesDomain(hostname, domain) {
  return hostname === domain || hostname.endsWith(`.${domain}`);
}

function adultDomainForURL(value) {
  if (typeof value !== "string" || !value.trim()) {
    return null;
  }

  try {
    const url = new URL(value, location.href);
    const hostname = url.hostname.toLowerCase();
    return [...ADULT_DOMAIN_HINTS].find((domain) => (
      hostnameMatchesDomain(hostname, domain)
    )) || null;
  } catch (_error) {
    return null;
  }
}

function effectiveFeatures(settings) {
  return {
    ...modeFeatures(settings.mode),
    ...settings.features
  };
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

function hasSensitiveWarning(container) {
  return SENSITIVE_WARNING_TEXT.test(accessibleText(container));
}

function statusIDsForPost(container) {
  const ids = new Set();
  for (const link of container.querySelectorAll?.('a[href*="/status/"], a[href*="/statuses/"]') || []) {
    const href = link.getAttribute("href") || "";
    const match = href.match(STATUS_ID_PATTERN);
    if (match) {
      ids.add(match[1]);
    }
  }
  return [...ids];
}

function hasSensitivePostID(container) {
  return statusIDsForPost(container).some((id) => sensitivePostIDs.has(id));
}

function hasSensitiveMediaURLHint(container) {
  for (const node of container.querySelectorAll?.("img[src], video[src], video[poster], source[src]") || []) {
    const candidates = [
      node.getAttribute("src"),
      node.getAttribute("poster")
    ];
    for (const candidate of candidates) {
      const normalized = normalizedMediaURLHint(candidate);
      if (normalized && sensitiveMediaURLHints.has(normalized)) {
        return true;
      }
    }
  }
  return false;
}

function hasSensitiveMediaID(container) {
  for (const node of container.querySelectorAll?.("img[src], video[src], video[poster], source[src]") || []) {
    const candidates = [
      node.getAttribute("src"),
      node.getAttribute("poster")
    ];
    for (const candidate of candidates) {
      for (const mediaID of mediaIDsFromURL(candidate)) {
        if (sensitiveMediaIDs.has(mediaID)) {
          return true;
        }
      }
    }
  }
  return false;
}

function hasSensitiveMetadataSignal(container) {
  return hasSensitivePostID(container) || hasSensitiveMediaURLHint(container) || hasSensitiveMediaID(container);
}

function adultDecision(surface, action, reason, confidence, source) {
  return { surface, action, reason, confidence, source };
}

function recordAdultDecision(decision) {
  document.documentElement.dataset.quietgateXLastDecision = decision
    ? `${decision.surface}:${decision.action}:${decision.reason}:${decision.source}:${decision.confidence}`
    : "";
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

function isProfileImage(node) {
  const source = node?.getAttribute?.("src") || "";
  return /pbs\.twimg\.com\/profile_images\//i.test(source);
}

function closestWithin(node, selectors, boundary) {
  const selectorList = Array.isArray(selectors) ? selectors : [selectors];
  for (const selector of selectorList) {
    const match = node.closest?.(selector);
    if (match && match !== boundary && boundary.contains(match)) {
      return match;
    }
  }
  return null;
}

function photoSurfaceFor(node, container) {
  if (node.matches?.('[data-testid="tweetPhoto"]')) {
    return node;
  }
  if (node.tagName === "IMG" && !isProfileImage(node)) {
    return closestWithin(node, ['[data-testid="tweetPhoto"]', 'a[href*="/photo/"]'], container) || node;
  }
  return null;
}

function videoSurfaceFor(node, container) {
  if (node.matches?.('[data-testid="videoComponent"], [data-testid="videoPlayer"]')) {
    return node;
  }
  if (node.tagName === "VIDEO") {
    return closestWithin(node, ['[data-testid="videoComponent"]', '[data-testid="videoPlayer"]'], container) || node;
  }
  return null;
}

function cardSurfaceFor(node) {
  if (node.matches?.('[data-testid="card.wrapper"]')) {
    return node;
  }
  return node.closest?.('[data-testid="card.wrapper"]') || node;
}

function collectSurfaces(container, selector, surfaceFor) {
  const surfaces = new Set();
  if (container.matches?.(selector)) {
    const surface = surfaceFor(container, container);
    if (surface) {
      surfaces.add(surface);
    }
  }

  for (const node of container.querySelectorAll(selector)) {
    const surface = surfaceFor(node, container);
    if (surface) {
      surfaces.add(surface);
    }
  }
  return [...surfaces];
}

function collectPhotoSurfaces(container) {
  return collectSurfaces(container, PHOTO_SELECTOR, photoSurfaceFor);
}

function collectVideoSurfaces(container) {
  return collectSurfaces(container, VIDEO_SELECTOR, videoSurfaceFor);
}

function collectCardSurfaces(container) {
  return collectSurfaces(container, CARD_SELECTOR, cardSurfaceFor);
}

function collectAllMediaSurfaces(container) {
  return [
    ...collectPhotoSurfaces(container),
    ...collectVideoSurfaces(container),
    ...collectCardSurfaces(container)
  ];
}

function hasExplicitContentCue(container, mediaSurfaces) {
  if (hasAdultDomainCue(container)) {
    return true;
  }

  if (mediaSurfaces.length === 0) {
    return false;
  }

  const text = accessibleText(container);
  return text.length <= 5000 && EXPLICIT_CUE_TEXT.test(text);
}

function isSearchRoute() {
  return location.pathname === "/search";
}

function searchFilterValue() {
  if (!isSearchRoute()) {
    return "";
  }
  return (new URLSearchParams(location.search).get("f") || "").toLowerCase();
}

function isSearchMediaRoute() {
  return searchFilterValue() === "media";
}

function searchQueryText() {
  const searchParams = new URLSearchParams(location.search);
  const query = searchParams.get("q") || searchParams.get("query") || "";
  if (query.trim()) {
    return query.trim();
  }

  const searchBox = document.querySelector(
    'input[role="searchbox"], input[aria-label*="Search"], [data-testid="SearchBox_Search_Input"]'
  );
  return (searchBox?.value || searchBox?.textContent || "").trim();
}

function hasExplicitSearchQueryCue() {
  if (!isSearchRoute()) {
    return false;
  }

  const text = searchQueryText();
  return text.length > 0 && text.length <= 1000 && EXPLICIT_CUE_TEXT.test(text);
}

function hasExplicitSearchMediaCue() {
  return isSearchMediaRoute() && hasExplicitSearchQueryCue();
}

function individualProfileHandle() {
  const parts = location.pathname.split("/").filter(Boolean);
  const profileRoute = parts.length === 1 ||
    (parts.length === 2 && PROFILE_ROUTE_PATHS.has(parts[1].toLowerCase()));
  if (!profileRoute) {
    return null;
  }

  const handle = parts[0].toLowerCase();
  return handle.length > 0 && !RESERVED_PROFILE_PATHS.has(handle) ? handle : null;
}

function isIndividualProfilePath() {
  return Boolean(individualProfileHandle());
}

function explicitProfileFlagKey(handle) {
  return `quietgate.x.explicitProfile.${handle}`;
}

function profilePreviouslyFlagged(handle) {
  if (explicitProfileHandles.has(handle)) {
    return true;
  }
  try {
    if (sessionStorage.getItem(explicitProfileFlagKey(handle)) === "1") {
      explicitProfileHandles.add(handle);
      return true;
    }
  } catch (_error) {
    // Session storage can be unavailable in some embedded contexts.
  }
  return false;
}

function flagExplicitProfile(handle) {
  explicitProfileHandles.add(handle);
  try {
    sessionStorage.setItem(explicitProfileFlagKey(handle), "1");
  } catch (_error) {
    // Best-effort cross-tab persistence for single browser session.
  }
}

function hasExplicitProfileCue(visiblePosts, mediaPosts) {
  const main = document.querySelector("main") || document.body;
  if (hasAdultDomainCue(main)) {
    return true;
  }

  const headerText = collectProfileHeaderSurfaces()
    .map((surface) => accessibleText(surface))
    .join(" ");
  if (headerText.length <= 5000 && EXPLICIT_CUE_TEXT.test(headerText)) {
    return true;
  }

  return mediaPosts.some((post) => {
    const text = accessibleText(post);
    return text.length <= 2000 && EXPLICIT_CUE_TEXT.test(text);
  }) || visiblePosts.some((post) => hasAdultDomainCue(post));
}

function visibleMediaDenseProfilePosts(posts) {
  const handle = individualProfileHandle();
  if (!handle) {
    return [];
  }

  const visiblePosts = posts.filter((post) => post.isConnected);
  if (visiblePosts.length < 3) {
    return [];
  }

  const mediaPosts = visiblePosts.filter((post) => post.querySelector(RAW_PROFILE_MEDIA_SELECTOR));
  if (
    mediaPosts.length >= 3 &&
    mediaPosts.length / visiblePosts.length >= 0.5 &&
    hasExplicitProfileCue(visiblePosts, mediaPosts)
  ) {
    flagExplicitProfile(handle);
  }

  return profilePreviouslyFlagged(handle)
    ? visiblePosts
    : [];
}

function collectProfileHeaderSurfaces() {
  const handle = individualProfileHandle();
  if (!handle) {
    return [];
  }

  const main = document.querySelector("main") || document.body;
  const profilePaths = new Set([
    `/${handle}/header_photo`,
    `/${handle}/photo`,
    `/${handle}/following`,
    `/${handle}/followers`,
    `/${handle}/verified_followers`
  ]);
  const surfaces = new Set();

  for (const link of main.querySelectorAll("a[href]")) {
    const href = (link.getAttribute("href") || "").split(/[?#]/)[0].toLowerCase();
    if (profilePaths.has(href)) {
      surfaces.add(link);
    }
  }

  for (const node of main.querySelectorAll([
    '[data-testid="UserName"]',
    '[data-testid="UserDescription"]',
    '[data-testid="UserProfileHeader_Items"]',
    'img[src*="pbs.twimg.com/profile_banners/"]'
  ].join(","))) {
    surfaces.add(closestWithin(node, ["a", "[role='button']"], main) || node);
  }

  return dedupeSurfaces([...surfaces]);
}

function collectProfileTimelineSurfaces() {
  const handle = individualProfileHandle();
  if (!handle) {
    return [];
  }

  const surfaces = new Set();
  const primaryColumn = document.querySelector('main [data-testid="primaryColumn"]');
  if (primaryColumn) {
    surfaces.add(primaryColumn);
  }
  for (const timeline of document.querySelectorAll('[aria-label^="Timeline:"][aria-label*="posts"]')) {
    surfaces.add(timeline);
  }
  return [...surfaces].filter((surface) => !surface.closest(`.${HIDDEN_CLASS}`));
}

function collectExplicitContextSidebarSurfaces() {
  const surfaces = new Set();
  for (const selector of [
    '[data-testid="sidebarColumn"]',
    "aside",
    '[aria-label*="Who to follow" i]',
    '[aria-label*="Timeline: Trending" i]',
    '[aria-label*="Relevant people" i]',
    '[aria-label*="Subscribe to" i]'
  ]) {
    for (const node of document.querySelectorAll(selector)) {
      if (!node.closest(`.${HIDDEN_CLASS}`)) {
        surfaces.add(node);
      }
    }
  }
  return dedupeSurfaces([...surfaces]);
}

function markExplicitContextSidebars(hiddenSurfaces, reason) {
  const decision = adultDecision("x-sidebar", "hide", reason, 88, location.pathname || "page");
  recordAdultDecision(decision);
  for (const surface of collectExplicitContextSidebarSurfaces()) {
    markSurface(surface, "qg-x-explicit-sidebar");
    hiddenSurfaces.add(surface);
  }
}

function collectSensitiveFallbackSurfaces(container) {
  const surfaces = new Set();
  for (const node of container.querySelectorAll("button, [role='button'], [aria-label], [title], span, div")) {
    if (!SENSITIVE_WARNING_TEXT.test(accessibleText(node))) {
      continue;
    }
    const surface = closestWithin(node, [MEDIA_SELECTOR, "[role='button']"], container) || node;
    surfaces.add(surface);
  }
  return [...surfaces];
}

function collectSearchMediaSurfaces() {
  if (!isSearchMediaRoute()) {
    return [];
  }

  const main = document.querySelector("main") || document.body;
  const surfaces = new Set([
    ...collectPhotoSurfaces(main),
    ...collectVideoSurfaces(main),
    ...collectCardSurfaces(main)
  ]);

  for (const link of main.querySelectorAll('a[href*="/status/"], a[href*="/statuses/"]')) {
    if (link.querySelector(MEDIA_SELECTOR)) {
      surfaces.add(link);
    }
  }

  return dedupeSurfaces([...surfaces]).filter((surface) => !surface.closest(`.${HIDDEN_CLASS}`));
}

function isSearchResultContainer(node, main) {
  if (!main.contains(node)) {
    return false;
  }
  if (node.matches?.('article[role="article"], [data-testid="UserCell"]')) {
    return true;
  }
  if (!node.matches?.('[data-testid="cellInnerDiv"]')) {
    return false;
  }
  if (node.querySelector('article[role="article"], [data-testid="UserCell"]')) {
    return false;
  }
  if (node.querySelector('input[role="searchbox"], [data-testid="SearchBox_Search_Input"], nav, [role="tablist"]')) {
    return false;
  }
  return accessibleText(node).length > 0 || node.querySelector(MEDIA_SELECTOR);
}

function collectSearchResultContainers() {
  if (!isSearchRoute()) {
    return [];
  }

  const main = document.querySelector("main") || document.body;
  const containers = new Set();
  for (const selector of [
    'article[role="article"]',
    '[data-testid="UserCell"]',
    '[data-testid="cellInnerDiv"]'
  ]) {
    for (const node of main.querySelectorAll(selector)) {
      if (!node.closest(`.${HIDDEN_CLASS}`) && isSearchResultContainer(node, main)) {
        containers.add(node);
      }
    }
  }
  return dedupeSurfaces([...containers]);
}

function hasExplicitSearchResultCue(container) {
  if (hasExplicitSearchQueryCue() || hasAdultDomainCue(container)) {
    return true;
  }

  const text = accessibleText(container);
  return text.length > 0 && text.length <= 5000 && EXPLICIT_CUE_TEXT.test(text);
}

function postContainers() {
  const articles = [...document.querySelectorAll('article[role="article"]')];
  const cells = [...document.querySelectorAll('[data-testid="cellInnerDiv"]')]
    .filter((cell) => !cell.querySelector('article[role="article"]') && !cell.closest('article[role="article"]'));
  return [...articles, ...cells];
}

function dedupeSurfaces(surfaces) {
  return [...new Set(surfaces)].filter((surface) => (
    !surfaces.some((other) => other !== surface && other.contains(surface))
  ));
}

function markSurface(surface, reasonClass) {
  surface.classList.add(HIDDEN_CLASS, reasonClass);
}

function configureExplicitPlaceholder(placeholder, title, detail) {
  placeholder.setAttribute("role", "note");
  placeholder.innerHTML = "";

  const logo = document.createElement("span");
  logo.className = "qg-x-placeholder-logo";
  logo.setAttribute("aria-hidden", "true");
  logo.textContent = "Q";

  const copy = document.createElement("span");
  copy.className = "qg-x-placeholder-copy";

  const titleNode = document.createElement("strong");
  titleNode.className = "qg-x-placeholder-title";
  titleNode.textContent = title;

  const detailNode = document.createElement("span");
  detailNode.className = "qg-x-placeholder-detail";
  detailNode.textContent = detail;

  copy.append(titleNode, detailNode);
  placeholder.append(logo, copy);
}

function createExplicitPlaceholder(title, detail, extraClass = "") {
  const placeholder = document.createElement("div");
  placeholder.className = extraClass
    ? `${PLACEHOLDER_CLASS} ${extraClass}`
    : PLACEHOLDER_CLASS;
  configureExplicitPlaceholder(placeholder, title, detail);
  return placeholder;
}

function ensureExplicitPlaceholder(
  post,
  title = "QuietGate blocked explicit content",
  detail = "Hidden by X explicit-content tuning."
) {
  const previous = post.previousElementSibling;
  if (previous?.classList?.contains(PLACEHOLDER_CLASS)) {
    configureExplicitPlaceholder(previous, title, detail);
    return previous;
  }

  const placeholder = createExplicitPlaceholder(title, detail);
  post.parentNode?.insertBefore(placeholder, post);
  return placeholder;
}

function ensureSearchPlaceholder(
  title = "QuietGate blocked explicit search results",
  detail = "This X search matched your explicit-search tuning."
) {
  const main = document.querySelector("main") || document.body;
  const existing = main.querySelector(`.${PLACEHOLDER_CLASS}.qg-x-explicit-search-placeholder`);
  if (existing) {
    configureExplicitPlaceholder(existing, title, detail);
    return existing;
  }

  const placeholder = createExplicitPlaceholder(
    title,
    detail,
    "qg-x-explicit-search-placeholder"
  );
  const anchor = main.querySelector('[aria-label^="Timeline:"], section');
  if (anchor?.parentNode) {
    anchor.parentNode.insertBefore(placeholder, anchor);
  } else {
    main.appendChild(placeholder);
  }
  return placeholder;
}

function markExplicitContent(post, mediaSurfaces, hiddenSurfaces, hiddenPosts, placeholders) {
  const style = explicitHideStyle();
  if (style === "media") {
    for (const surface of dedupeSurfaces(mediaSurfaces)) {
      markSurface(surface, "qg-x-explicit-media-surface");
      hiddenSurfaces.add(surface);
    }
    return;
  }

  post.classList.add(HIDDEN_CLASS, "qg-x-explicit-post");
  hiddenPosts.add(post);
  if (style === "placeholder") {
    placeholders.add(ensureExplicitPlaceholder(post));
  }
}

function markExplicitSearchMedia(hiddenSurfaces, placeholders) {
  const surfaces = collectSearchMediaSurfaces();

  for (const surface of surfaces) {
    markSurface(surface, "qg-x-explicit-search-media");
    hiddenSurfaces.add(surface);
  }

  placeholders.add(ensureSearchPlaceholder(
    "QuietGate blocked explicit media results",
    "This X media search matched your explicit-content tuning."
  ));
  recordAdultDecision(adultDecision("x-search-media", "hide", "explicit-search-query", 95, searchQueryText()));
  return surfaces.length;
}

function markExplicitSearchResults(hiddenPosts, placeholders) {
  if (isSearchMediaRoute()) {
    return 0;
  }

  const candidates = collectSearchResultContainers()
    .filter((container) => !container.classList.contains("qg-x-explicit-search-media"))
    .filter(hasExplicitSearchResultCue);

  if (hasExplicitSearchQueryCue() || candidates.length > 0) {
    placeholders.add(ensureSearchPlaceholder());
    recordAdultDecision(adultDecision("x-search", "hide", "explicit-search-results", 94, searchQueryText()));
  }

  for (const container of candidates) {
    container.classList.add(HIDDEN_CLASS, "qg-x-explicit-search-result");
    hiddenPosts.add(container);
  }

  return candidates.length;
}

function markExplicitProfile(posts, hiddenSurfaces, hiddenPosts, placeholders) {
  const style = explicitHideStyle();
  markExplicitContextSidebars(hiddenSurfaces, "explicit-profile");
  for (const surface of collectProfileHeaderSurfaces()) {
    markSurface(surface, "qg-x-explicit-profile-header");
    hiddenSurfaces.add(surface);
  }
  for (const surface of collectProfileTimelineSurfaces()) {
    markSurface(surface, "qg-x-explicit-profile-shell");
    hiddenSurfaces.add(surface);
  }

  for (const post of posts) {
    const mediaSurfaces = collectAllMediaSurfaces(post);
    const fallbackMediaSurfaces = mediaSurfaces.length > 0
      ? mediaSurfaces
      : [...post.querySelectorAll(RAW_PROFILE_MEDIA_SELECTOR)];

    if (style === "media") {
      for (const surface of dedupeSurfaces(fallbackMediaSurfaces)) {
        markSurface(surface, "qg-x-explicit-media-surface");
        hiddenSurfaces.add(surface);
      }
    }

    post.classList.add(HIDDEN_CLASS, "qg-x-explicit-profile");
    hiddenPosts.add(post);
    if (style === "placeholder") {
      placeholders.add(ensureExplicitPlaceholder(post));
    }
  }
}

function clearManagedSurfaces() {
  for (const node of document.querySelectorAll(MANAGED_MEDIA_CLASSES.map((className) => `.${className}`).join(","))) {
    node.classList.remove(...MANAGED_MEDIA_CLASSES);
  }
  document.documentElement.dataset.quietgateXHiddenMediaCount = "0";
  document.documentElement.dataset.quietgateXExplicitPostCount = "0";
  document.documentElement.dataset.quietgateXProfileFallbackPostCount = "0";
  document.documentElement.dataset.quietgateXSearchMediaCount = "0";
  document.documentElement.dataset.quietgateXSearchResultCount = "0";
  document.documentElement.dataset.quietgateXLastDecision = "";
}

function cleanupExplicitPlaceholders(activePlaceholders = new Set()) {
  for (const placeholder of document.querySelectorAll(`.${PLACEHOLDER_CLASS}`)) {
    if (!activePlaceholders.has(placeholder)) {
      placeholder.remove();
    }
  }
}

function markMediaSurfaces(features) {
  clearManagedSurfaces();

  if (
    !features.xSensitiveMedia &&
    !features.xExplicitContent &&
    !features.xExplicitSearch &&
    !features.xVideos &&
    !features.xPhotos &&
    !features.xMediaCards
  ) {
    cleanupExplicitPlaceholders();
    return;
  }

  const hiddenSurfaces = new Set();
  const hiddenPosts = new Set();
  const placeholders = new Set();
  const explicitCueEnabled = features.xExplicitContent || features.xSensitiveMedia;
  let searchMediaHiddenCount = 0;
  let searchResultHiddenCount = 0;
  const posts = postContainers();
  recordAdultDecision(null);
  if ((explicitCueEnabled || features.xExplicitSearch) && hasExplicitSearchMediaCue()) {
    searchMediaHiddenCount += markExplicitSearchMedia(hiddenSurfaces, placeholders);
  }
  if (features.xExplicitSearch && isSearchRoute()) {
    searchResultHiddenCount = markExplicitSearchResults(hiddenPosts, placeholders);
  }
  if ((explicitCueEnabled || features.xExplicitSearch) && isSearchRoute() && hasExplicitSearchQueryCue()) {
    markExplicitContextSidebars(hiddenSurfaces, "explicit-search");
  }
  if (isSearchMediaRoute()) {
    const searchMediaGroups = [];
    const main = document.querySelector("main") || document.body;
    if (features.xPhotos) {
      searchMediaGroups.push({
        reasonClass: "qg-x-photo-media-surface",
        surfaces: collectPhotoSurfaces(main)
      });
    }
    if (features.xVideos) {
      searchMediaGroups.push({
        reasonClass: "qg-x-video-media-surface",
        surfaces: collectVideoSurfaces(main)
      });
    }
    if (features.xMediaCards) {
      searchMediaGroups.push({
        reasonClass: "qg-x-card-media-surface",
        surfaces: collectCardSurfaces(main)
      });
    }
    for (const group of searchMediaGroups) {
      for (const surface of dedupeSurfaces(group.surfaces)) {
        markSurface(surface, group.reasonClass);
        hiddenSurfaces.add(surface);
        searchMediaHiddenCount += 1;
      }
    }
  }
  document.documentElement.dataset.quietgateXSearchMediaCount = String(searchMediaHiddenCount);
  document.documentElement.dataset.quietgateXSearchResultCount = String(searchResultHiddenCount);
  const profileFallbackPosts = explicitCueEnabled ? new Set(visibleMediaDenseProfilePosts(posts)) : new Set();
  document.documentElement.dataset.quietgateXProfileFallbackPostCount = String(profileFallbackPosts.size);
  if (profileFallbackPosts.size > 0) {
    markExplicitProfile(profileFallbackPosts, hiddenSurfaces, hiddenPosts, placeholders);
  }

  for (const post of posts) {
    const groups = [];
    const allMediaSurfaces = collectAllMediaSurfaces(post);

    if (!profileFallbackPosts.has(post) && explicitCueEnabled && hasExplicitContentCue(post, allMediaSurfaces)) {
      markExplicitContent(post, allMediaSurfaces, hiddenSurfaces, hiddenPosts, placeholders);
    }

    if (features.xSensitiveMedia && (hasSensitiveWarning(post) || hasSensitiveMetadataSignal(post))) {
      groups.push({
        reasonClass: "qg-x-sensitive-media-surface",
        surfaces: allMediaSurfaces.length > 0 ? allMediaSurfaces : collectSensitiveFallbackSurfaces(post)
      });
    }

    if (features.xVideos) {
      groups.push({
        reasonClass: "qg-x-video-media-surface",
        surfaces: collectVideoSurfaces(post)
      });
    }

    if (features.xPhotos) {
      groups.push({
        reasonClass: "qg-x-photo-media-surface",
        surfaces: collectPhotoSurfaces(post)
      });
    }

    if (features.xMediaCards) {
      groups.push({
        reasonClass: "qg-x-card-media-surface",
        surfaces: collectCardSurfaces(post)
      });
    }

    for (const group of groups) {
      for (const surface of dedupeSurfaces(group.surfaces)) {
        markSurface(surface, group.reasonClass);
        hiddenSurfaces.add(surface);
      }
    }
  }

  cleanupExplicitPlaceholders(placeholders);
  document.documentElement.dataset.quietgateXHiddenMediaCount = String(
    hiddenSurfaces.size + hiddenPosts.size
  );
  document.documentElement.dataset.quietgateXExplicitPostCount = String(
    hiddenPosts.size + placeholders.size
  );
}

function applySettings() {
  const features = effectiveFeatures(currentSettings);

  for (const [feature, className] of Object.entries(FEATURE_CLASSES)) {
    document.documentElement.classList.toggle(className, Boolean(features[feature]));
  }

  markMediaSurfaces(features);
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
    await quietGateBrowser.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
  } catch (error) {
    // Storage fallback still works when the native bridge has not been installed.
  } finally {
    syncInFlight = false;
  }
}

async function loadSettings() {
  const stored = await quietGateBrowser.storage.local.get(DEFAULT_SETTINGS);
  currentSettings = mergedSettings(stored);
  applySettings();
}

function handleStorageChange(changes, areaName) {
  if (areaName !== "local") {
    return;
  }

  if (changes.mode || changes.features || changes.options || changes.blockedDomains) {
    loadSettings();
  }
}

quietGateBrowser.storage.onChanged.addListener(handleStorageChange);

const observer = new MutationObserver(scheduleApplySettings);
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

window.addEventListener("popstate", scheduleApplySettings);
window.addEventListener("pageshow", scheduleApplySettings);
window.addEventListener("message", handlePageDetectorMessage);

function refreshController() {
  injectPageDetectorScript();
  loadSettings();
  usageController?.refresh?.();
  syncNativeSettings();
  scheduleApplySettings();
}

usageController = window.__tortoiseSiteUsage?.initSiteUsageTracker({ siteID: "x" }) || null;

window.__quietgateXTunerController = {
  version: TUNER_VERSION,
  refresh: refreshController,
  dispose() {
    observer.disconnect();
    window.removeEventListener("popstate", scheduleApplySettings);
    window.removeEventListener("pageshow", scheduleApplySettings);
    window.removeEventListener("message", handlePageDetectorMessage);
    quietGateBrowser.storage.onChanged.removeListener?.(handleStorageChange);
    usageController?.dispose?.();
    usageController = null;
    clearManagedSurfaces();
  }
};

refreshController();
})();
