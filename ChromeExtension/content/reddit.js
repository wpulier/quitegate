const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;
const TUNER_VERSION = "2026.06.11.01";

const DEFAULT_SETTINGS = {
  mode: "open",
  features: {
    redditPopularAll: false,
    redditRecommendations: false,
    redditNSFW: false,
    redditMedia: false,
    redditSidebars: false
  },
  options: {
    explicitHideStyle: "post"
  },
  blockedDomains: [],
  blockedCategories: []
};

const FEATURE_CLASSES = {
  redditPopularAll: "qg-reddit-popular-all",
  redditRecommendations: "qg-reddit-recommendations",
  redditNSFW: "qg-reddit-nsfw",
  redditMedia: "qg-reddit-media",
  redditSidebars: "qg-reddit-sidebars"
};

const PLACEHOLDER_CLASS = "qg-reddit-nsfw-placeholder";
const CONTEXT_SHELL_CLASS = "qg-reddit-adult-context-shell";
const ADULT_CATEGORY_ID = "adultContent";
const MANAGED_CLASSES = [
  "qg-reddit-recommendation-item",
  "qg-reddit-media-item",
  "qg-reddit-nsfw-item",
  "qg-reddit-nsfw-media-item",
  "qg-reddit-adult-context-hidden",
  "qg-reddit-adult-context-sidebar",
  "qg-reddit-adult-context-comment",
  "qg-reddit-adult-context-media"
];
const VALID_EXPLICIT_HIDE_STYLES = new Set(["post", "media", "placeholder"]);

const RECOMMENDATION_TEXT =
  /\b(promoted|recommended|suggested|popular on reddit|because you've shown interest|because you visited|similar to|communities near you)\b/i;
const NATIVE_NSFW_TEXT =
  /\b(nsfw|18\+|mature\s+content|adult\s+content|over\s*18|not\s+safe\s+for\s+work)\b/i;
const EXPLICIT_CUE_TEXT =
  /(?:🔞|\b(?:nsfw|18\+|xxx|porn(?:hub|star|ography)?|only\s*fans|onlyfans|fansly|redgifs|nudes?|leaked\s+(?:nudes?|onlyfans|content)|sex(?:tape|ual\s+content)?|cam\s?(?:girl|show|model)|uncensored|explicit\s+(?:content|media|pics?|photos?|videos?)|spicy\s+(?:link|content)|blowjob|handjob|pussy|cock|dick|tits?|boobs?|anal|hardcore|erotic|masturbat(?:e|ing|ion)|striptease|orgasm|cumshot|squirting|deep\s*throat|throat\s*(?:fuck|pie|bulge|bulging)|face\s*fuck|nutt(?:ed|ing)|sluts?|gooning|creampie|milf)\b)/i;
const EXPLICIT_QUERY_TEXT =
  /(?:🔞|\b(?:nsfw|18\+|xxx|porn(?:hub|star|ography)?|only\s*fans|onlyfans|fansly|redgifs|nudes?|hentai|gone\s*wild|cam\s?(?:girl|show|model)|blowjob|handjob|pussy|cock|dick|tits?|boobs?|anal|hardcore|erotic|fetish|bdsm|cumshot|squirting|deep\s*throat|throat\s*(?:fuck|pie|bulge|bulging)|face\s*fuck|nutt(?:ed|ing)|sluts?|creampie|milf)\b)/i;
const ADULT_SUBREDDIT_TEXT =
  /(?:^|[^a-z0-9])(?:nsfw|gonewild|porn|hentai|onlyfans|fansly|nudes?|milf|boobs?|tits?|ass|sex|xxx|rule34|redgifs|deep\s*throat|deepthroat|throat(?:fuck|pie|bulge|bulging)?|face\s*fuck|facefuck|blowjob|handjob|pussy|cock|dick|anal|hardcore|erotic|fetish|bdsm|cumshot|squirting|creampie|sluts?|goon|gooning)(?:[^a-z0-9]|$)/i;
const BENIGN_CONTEXT_TEXT =
  /\b(?:adult\s+education|adult\s+learning|sex\s+education|sexual\s+health|medical|healthcare|research|news|policy|politics|trafficking|support|recovery|wikipedia|dictionary)\b/i;
const ADULT_DOMAIN_HINTS = new Set([
  "redgifs.com",
  "onlyfans.com",
  "fansly.com",
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

let currentSettings = DEFAULT_SETTINGS;
let adultDomainSet = null;
let adultDomainPayloadPromise = null;
let syncInFlight = false;
let applyQueued = false;

document.documentElement.dataset.quietgateRedditTuner = "loaded";
document.documentElement.dataset.quietgateRedditTunerVersion = TUNER_VERSION;
document.documentElement.dataset.quietgateRedditHiddenCount = "0";
document.documentElement.dataset.quietgateRedditNSFWCount = "0";
document.documentElement.dataset.quietgateRedditAdultDomainCount = "0";
document.documentElement.dataset.quietgateRedditAdultContext = "none";
document.documentElement.dataset.quietgateRedditLastDecision = "";

function normalizeDomain(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/^\*\./, "")
    .replace(/\.$/, "");
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
      : DEFAULT_SETTINGS.blockedDomains,
    blockedCategories: Array.isArray(value.blockedCategories)
      ? [...new Set(value.blockedCategories.map((category) => String(category || "").trim()).filter(Boolean))].sort()
      : DEFAULT_SETTINGS.blockedCategories
  };
}

function domainMatchFromSet(hostname, domains) {
  const normalizedHostname = normalizeDomain(hostname);
  if (!normalizedHostname || !domains?.size) {
    return null;
  }

  const parts = normalizedHostname.split(".");
  for (let index = 0; index <= Math.max(parts.length - 2, 0); index += 1) {
    const candidate = parts.slice(index).join(".");
    if (domains.has(candidate)) {
      return candidate;
    }
  }
  return null;
}

function adultCategoryEnabled(settings = currentSettings) {
  if (settings.blockedCategories?.includes(ADULT_CATEGORY_ID)) {
    return true;
  }

  return (settings.blockedDomains || []).some((domain) => (
    ADULT_DOMAIN_HINTS.has(normalizeDomain(domain))
  ));
}

function shouldLoadAdultDomains(settings = currentSettings) {
  return adultCategoryEnabled(settings) || Boolean(settings.features?.redditNSFW);
}

async function loadAdultDomainSet() {
  if (adultDomainSet) {
    return adultDomainSet;
  }
  if (!adultDomainPayloadPromise) {
    adultDomainPayloadPromise = fetch(quietGateBrowser.runtime.getURL("rules/adult-domains.json"))
      .then((response) => response.ok ? response.json() : Promise.reject(new Error(`HTTP ${response.status}`)))
      .then((payload) => {
        adultDomainSet = new Set([
          ...ADULT_DOMAIN_HINTS,
          ...((Array.isArray(payload?.domains) ? payload.domains : []).map(normalizeDomain).filter(Boolean))
        ]);
        document.documentElement.dataset.quietgateRedditAdultDomainCount = String(adultDomainSet.size);
        scheduleApplySettings();
        return adultDomainSet;
      })
      .catch(() => {
        adultDomainSet = new Set(ADULT_DOMAIN_HINTS);
        document.documentElement.dataset.quietgateRedditAdultDomainCount = String(adultDomainSet.size);
        return adultDomainSet;
      });
  }
  return adultDomainPayloadPromise;
}

function ensureAdultDomainSetLoaded() {
  if (shouldLoadAdultDomains() && !adultDomainSet) {
    loadAdultDomainSet();
  }
}

function modeFeatures(mode) {
  if (mode === "strict") {
    return {
      redditPopularAll: true,
      redditRecommendations: true,
      redditNSFW: true,
      redditMedia: true,
      redditSidebars: true
    };
  }

  if (mode === "focus") {
    return {
      redditPopularAll: true,
      redditRecommendations: true,
      redditNSFW: false,
      redditMedia: false,
      redditSidebars: false
    };
  }

  return { ...DEFAULT_SETTINGS.features };
}

function effectiveFeatures(settings) {
  const features = {
    ...modeFeatures(settings.mode),
    ...settings.features
  };
  if (adultCategoryEnabled(settings)) {
    features.redditNSFW = true;
  }
  return features;
}

function explicitHideStyle() {
  const value = currentSettings.options?.explicitHideStyle || DEFAULT_SETTINGS.options.explicitHideStyle;
  return VALID_EXPLICIT_HIDE_STYLES.has(value) ? value : DEFAULT_SETTINGS.options.explicitHideStyle;
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
    const customDomainSet = new Set((currentSettings.blockedDomains || []).map(normalizeDomain).filter(Boolean));
    return domainMatchFromSet(hostname, customDomainSet) ||
      domainMatchFromSet(hostname, adultDomainSet) ||
      domainMatchFromSet(hostname, ADULT_DOMAIN_HINTS);
  } catch (_error) {
    return null;
  }
}

function accessibleText(node) {
  if (!node) {
    return "";
  }

  const parts = [node.textContent || ""];
  for (const child of node.querySelectorAll?.("[aria-label], [title], img[alt]") || []) {
    for (const attribute of ["aria-label", "title", "alt"]) {
      const value = child.getAttribute(attribute);
      if (value) {
        parts.push(value);
      }
    }
  }
  for (const attribute of ["aria-label", "title", "alt"]) {
    const value = node.getAttribute?.(attribute);
    if (value) {
      parts.push(value);
    }
  }

  return parts.join(" ").replace(/\s+/g, " ").trim();
}

function adultDecision(surface, action, reason, confidence, source) {
  return { surface, action, reason, confidence, source };
}

function recordAdultDecision(decision) {
  document.documentElement.dataset.quietgateRedditLastDecision = decision
    ? `${decision.surface}:${decision.action}:${decision.reason}:${decision.source}:${decision.confidence}`
    : "";
}

function resetAdultContextDataset() {
  document.documentElement.dataset.quietgateRedditAdultContext = "none";
  document.documentElement.dataset.quietgateRedditAdultReason = "";
}

function clearManagedItems() {
  for (const node of document.querySelectorAll(MANAGED_CLASSES.map((className) => `.${className}`).join(","))) {
    node.classList.remove(...MANAGED_CLASSES);
  }
  cleanupAdultContextShell();
  resetAdultContextDataset();
  document.documentElement.dataset.quietgateRedditHiddenCount = "0";
  document.documentElement.dataset.quietgateRedditNSFWCount = "0";
}

function cleanupNSFWPlaceholders(activePlaceholders = new Set()) {
  for (const placeholder of document.querySelectorAll(`.${PLACEHOLDER_CLASS}`)) {
    if (!activePlaceholders.has(placeholder)) {
      placeholder.remove();
    }
  }
}

function postContainers() {
  const selectors = [
    "shreddit-post",
    "article",
    "[role='article']",
    "[data-testid='post-container']",
    "[data-testid='search-post-unit']",
    "[data-testid='post-search-result']",
    "[data-testid='subreddit-search-result']",
    "[data-testid='user-search-result']",
    "[data-testid='community-card']",
    "[data-testid='community-container']",
    "[data-post-id]",
    "faceplate-tracker[noun='post']",
    "faceplate-tracker[noun='subreddit']",
    "faceplate-tracker[noun='user']",
    "search-telemetry-tracker",
    ".thing"
  ].join(",");
  return [...new Set([...document.querySelectorAll(selectors)])]
    .filter((node) => node !== document.body && node !== document.documentElement);
}

function markRecommendations(features, hiddenItems) {
  if (!features.redditRecommendations) {
    return;
  }

  for (const post of postContainers()) {
    const text = accessibleText(post);
    if (text.length > 3200 || !RECOMMENDATION_TEXT.test(text)) {
      continue;
    }
    post.classList.add("qg-reddit-recommendation-item");
    hiddenItems.add(post);
  }

  for (const module of document.querySelectorAll("aside, section, shreddit-feed, .promotedlink")) {
    const text = accessibleText(module);
    if (text.length > 2600 || !RECOMMENDATION_TEXT.test(text)) {
      continue;
    }
    module.classList.add("qg-reddit-recommendation-item");
    hiddenItems.add(module);
  }
}

function isAvatarImage(node) {
  const source = node.getAttribute?.("src") || "";
  const alt = node.getAttribute?.("alt") || "";
  return /avatar|profile|community icon|subreddit icon/i.test(`${source} ${alt}`);
}

function mediaSurfaceFor(node) {
  if (node.tagName === "IMG" && isAvatarImage(node)) {
    return null;
  }
  if (node.tagName === "A") {
    return node.querySelector?.("figure, [slot='post-media-container'], [data-testid='post-media-container'], img, video") || node;
  }
  return node.closest?.("[slot='post-media-container'], [data-testid='post-media-container'], figure, gallery-carousel, shreddit-player, a") || node;
}

function collectMediaSurfaces(post) {
  const surfaces = new Set();
  const mediaNodes = post.querySelectorAll([
    "video",
    "iframe",
    "shreddit-player",
    "gallery-carousel",
    "[slot='post-media-container']",
    "[data-testid='post-media-container']",
    "a[href*='v.redd.it']",
    "a[href*='i.redd.it']",
    "a[href*='redgifs.com']",
    "a[href*='preview.redd.it']",
    "a[href*='external-preview.redd.it']",
    "img[src*='i.redd.it']",
    "img[src*='preview.redd.it']",
    "img[src*='external-preview.redd.it']",
    "img[srcset*='preview.redd.it']",
    "img[srcset*='external-preview.redd.it']"
  ].join(","));

  for (const node of mediaNodes) {
    const surface = mediaSurfaceFor(node);
    if (surface) {
      surfaces.add(surface);
    }
  }

  return [...surfaces].filter((surface) => (
    ![...surfaces].some((other) => other !== surface && other.contains(surface))
  ));
}

function markMedia(features, hiddenItems) {
  if (!features.redditMedia) {
    return;
  }

  for (const post of postContainers()) {
    for (const surface of collectMediaSurfaces(post)) {
      surface.classList.add("qg-reddit-media-item");
      hiddenItems.add(surface);
    }
  }
}

function hasNativeNSFWAttribute(post) {
  const booleanAttributes = [
    "over-18",
    "over18",
    "over_18",
    "nsfw",
    "data-nsfw",
    "data-over18",
    "data-over-18",
    "data-over_18",
    "post-over-18",
    "post-over18",
    "post-over_18",
    "is-nsfw",
    "data-mature"
  ];
  for (const attribute of booleanAttributes) {
    if (!post.hasAttribute?.(attribute)) {
      continue;
    }
    const value = String(post.getAttribute(attribute) || "true").toLowerCase();
    if (value === "" || value === "true" || value === "1") {
      return true;
    }
  }

  for (const attribute of post.attributes || []) {
    const combined = `${attribute.name} ${attribute.value || ""}`;
    if (/\b(?:nsfw|over[-_]?18|mature|adult[-_]?content)\b/i.test(combined)) {
      if (!/\b(?:false|0|off)\b/i.test(String(attribute.value || ""))) {
        return true;
      }
    }
  }

  return /\bover18\b|\bnsfw\b/i.test(post.className || "");
}

function subredditNamesForPost(post) {
  const names = new Set();
  for (const attribute of ["subreddit-prefixed-name", "subreddit-name", "subredditName", "data-subreddit"]) {
    const value = post.getAttribute?.(attribute);
    if (value) {
      names.add(value.replace(/^r\//i, ""));
    }
  }
  for (const link of post.querySelectorAll?.('a[href^="/r/"], a[href*="reddit.com/r/"]') || []) {
    const href = link.getAttribute("href") || "";
    const match = href.match(/\/r\/([^/?#\s]+)/i);
    if (match) {
      names.add(match[1]);
    }
  }
  return [...names];
}

function hasAdultSubredditCue(post) {
  return subredditNamesForPost(post).some((name) => ADULT_SUBREDDIT_TEXT.test(name));
}

function hasAdultDomainCue(post) {
  for (const link of post.querySelectorAll?.("a[href]") || []) {
    if (adultDomainForURL(link.getAttribute("href"))) {
      return true;
    }
  }
  for (const node of post.querySelectorAll?.("img, video, iframe, source, shreddit-post") || []) {
    for (const attribute of ["src", "srcset", "poster", "href", "content-href", "thumbnail", "preview"]) {
      if (adultDomainForURL(node.getAttribute?.(attribute))) {
        return true;
      }
    }
  }
  return false;
}

function isSearchRoute() {
  return /^\/search(\/|$)/i.test(location.pathname);
}

function searchQueryText() {
  const params = new URLSearchParams(location.search);
  return [
    params.get("q"),
    params.get("query"),
    params.get("term")
  ].filter(Boolean).join(" ");
}

function hasExplicitSearchQuery() {
  const query = searchQueryText();
  return query.length > 0 && EXPLICIT_QUERY_TEXT.test(query) && !BENIGN_CONTEXT_TEXT.test(query);
}

function decodedPathSegment(value) {
  try {
    return decodeURIComponent(value || "");
  } catch (_error) {
    return value || "";
  }
}

function subredditNameFromPath() {
  const match = location.pathname.match(/^\/r\/([^/?#]+)(?:\/|$)/i);
  return match ? decodedPathSegment(match[1]) : null;
}

function userNameFromPath() {
  const match = location.pathname.match(/^\/(?:user|u)\/([^/?#]+)(?:\/|$)/i);
  return match ? decodedPathSegment(match[1]) : null;
}

function isSubredditRoute() {
  return Boolean(subredditNameFromPath());
}

function isCommentRoute() {
  return /^\/r\/[^/?#]+\/comments\//i.test(location.pathname);
}

function isUserRoute() {
  return Boolean(userNameFromPath());
}

function adultSubredditFromPath() {
  const name = subredditNameFromPath();
  return name && ADULT_SUBREDDIT_TEXT.test(name) ? name : null;
}

function adultUserFromPath() {
  const name = userNameFromPath();
  return name && EXPLICIT_QUERY_TEXT.test(name.replace(/[_-]+/g, " ")) ? name : null;
}

function pageContextText() {
  const parts = [
    document.title || "",
    accessibleText(document.querySelector("h1, [role='heading'], header")),
    accessibleText(document.querySelector("aside, [data-testid='right-sidebar'], #right-sidebar, .side"))
  ];
  return parts.join(" ").replace(/\s+/g, " ").trim().slice(0, 8000);
}

function nativeAdultPageLabelDetected() {
  if (!isSubredditRoute() && !isCommentRoute() && !isUserRoute()) {
    return false;
  }
  const text = pageContextText();
  return text.length > 0 && NATIVE_NSFW_TEXT.test(text);
}

function adultContextDecision() {
  const adultSubreddit = adultSubredditFromPath();
  if (adultSubreddit) {
    return adultDecision("reddit-route", "page", "adult-subreddit", 100, `r/${adultSubreddit}`);
  }

  const adultUser = adultUserFromPath();
  if (adultUser) {
    return adultDecision("reddit-route", "page", "adult-user", 92, `u/${adultUser}`);
  }

  if (isSearchRoute() && hasExplicitSearchQuery()) {
    return adultDecision("reddit-search", "page", "explicit-search-query", 95, searchQueryText());
  }

  if (nativeAdultPageLabelDetected()) {
    const subreddit = subredditNameFromPath();
    if (subreddit) {
      return adultDecision("reddit-route", "page", "native-adult-community-label", 96, `r/${subreddit}`);
    }
    const user = userNameFromPath();
    return adultDecision("reddit-route", "page", "native-adult-profile-label", 90, user ? `u/${user}` : "page");
  }

  return null;
}

function cleanupAdultContextShell() {
  document.querySelector(`.${CONTEXT_SHELL_CLASS}`)?.remove();
  document.documentElement.classList.remove("qg-reddit-adult-context");
}

function configureAdultContextShell(shell, decision) {
  shell.setAttribute("role", "region");
  shell.setAttribute("aria-labelledby", "qg-reddit-adult-context-title");
  shell.innerHTML = `
    <div class="qg-reddit-adult-context-panel">
      <div class="qg-reddit-mark" aria-hidden="true">Q</div>
      <div class="qg-reddit-adult-context-copy">
        <p class="qg-reddit-eyebrow">QuietGate</p>
        <h1 id="qg-reddit-adult-context-title">Adult Reddit content blocked</h1>
        <p class="qg-reddit-adult-context-detail">This Reddit area matched your adult-content tuning. Reddit navigation remains available.</p>
        <p class="qg-reddit-adult-context-reason"></p>
        <div class="qg-reddit-adult-context-actions">
          <button type="button" class="qg-primary" data-qg-reddit-action="back">Go Back</button>
          <button type="button" data-qg-reddit-action="home">Reddit Home</button>
        </div>
      </div>
    </div>
  `;
  shell.querySelector(".qg-reddit-adult-context-reason").textContent =
    `Reason: ${decision.reason}${decision.source ? ` (${decision.source})` : ""}`;
  shell.querySelector('[data-qg-reddit-action="back"]')?.addEventListener("click", () => {
    if (history.length > 1) {
      history.back();
    } else {
      location.href = "https://www.reddit.com/";
    }
  });
  shell.querySelector('[data-qg-reddit-action="home"]')?.addEventListener("click", () => {
    location.href = "https://www.reddit.com/";
  });
}

function ensureAdultContextShell(decision) {
  const main = document.querySelector("main") || document.body;
  let shell = main.querySelector?.(`:scope > .${CONTEXT_SHELL_CLASS}`) ||
    document.querySelector(`.${CONTEXT_SHELL_CLASS}`);
  if (!shell) {
    shell = document.createElement("section");
    shell.className = CONTEXT_SHELL_CLASS;
    if (main.firstChild) {
      main.insertBefore(shell, main.firstChild);
    } else {
      main.appendChild(shell);
    }
  }
  configureAdultContextShell(shell, decision);
  return shell;
}

function adultContextHiddenCandidates(shell) {
  const candidates = new Set();
  const main = document.querySelector("main");
  if (main) {
    for (const child of main.children) {
      if (child !== shell) {
        candidates.add(child);
      }
    }
  }
  for (const selector of [
    "shreddit-comment",
    "[data-testid*='comment' i]",
    "[slot*='comment' i]",
    ".comment",
    "[id^='comment-']"
  ]) {
    for (const node of document.querySelectorAll(selector)) {
      if (node !== shell && !shell.contains(node)) {
        node.classList.add("qg-reddit-adult-context-comment");
        candidates.add(node);
      }
    }
  }
  return candidates;
}

function adultContextSidebarCandidates(shell) {
  const candidates = new Set();
  for (const selector of [
    "aside",
    "[data-testid='right-sidebar']",
    "#right-sidebar",
    ".side",
    "reddit-sidebar-nav",
    "[data-testid='subreddit-right-rail']",
    "[data-testid='community-right-rail']"
  ]) {
    for (const node of document.querySelectorAll(selector)) {
      if (node !== shell && !shell.contains(node)) {
        candidates.add(node);
      }
    }
  }
  return candidates;
}

function markAdultContext(features, hiddenItems) {
  if (!features.redditNSFW) {
    cleanupAdultContextShell();
    resetAdultContextDataset();
    recordAdultDecision(null);
    return null;
  }

  const decision = adultContextDecision();
  if (!decision) {
    cleanupAdultContextShell();
    resetAdultContextDataset();
    recordAdultDecision(null);
    return null;
  }

  document.documentElement.classList.add("qg-reddit-adult-context");
  document.documentElement.dataset.quietgateRedditAdultContext = decision.reason;
  document.documentElement.dataset.quietgateRedditAdultReason = decision.source || "";
  recordAdultDecision(decision);

  const shell = ensureAdultContextShell(decision);
  hiddenItems.add(shell);
  for (const node of adultContextHiddenCandidates(shell)) {
    node.classList.add("qg-reddit-adult-context-hidden");
    hiddenItems.add(node);
  }
  for (const node of adultContextSidebarCandidates(shell)) {
    node.classList.add("qg-reddit-adult-context-sidebar");
    hiddenItems.add(node);
  }
  for (const node of collectMediaSurfaces(document.body)) {
    if (shell.contains(node)) {
      continue;
    }
    node.classList.add("qg-reddit-adult-context-media");
    hiddenItems.add(node);
  }
  return decision;
}

function isCommunityOrProfileSurface(post) {
  const attributeText = [
    post.tagName || "",
    post.getAttribute?.("data-testid") || "",
    post.getAttribute?.("noun") || "",
    post.getAttribute?.("aria-label") || ""
  ].join(" ");
  if (/\b(?:community|subreddit|user|profile|people)\b/i.test(attributeText)) {
    return true;
  }
  return Boolean(post.querySelector?.('a[href^="/r/"], a[href*="reddit.com/r/"], a[href^="/user/"], a[href^="/u/"], a[href*="reddit.com/user/"]'));
}

function hasExplicitTextCue(text) {
  if (!text || text.length > 5000) {
    return false;
  }
  if (!EXPLICIT_CUE_TEXT.test(text)) {
    return false;
  }
  return !BENIGN_CONTEXT_TEXT.test(text) || EXPLICIT_QUERY_TEXT.test(text);
}

function hasNSFWPostSignal(post, mediaSurfaces) {
  if (hasNativeNSFWAttribute(post)) {
    return true;
  }

  const text = accessibleText(post);
  if (text.length <= 5000 && NATIVE_NSFW_TEXT.test(text)) {
    return true;
  }

  if (hasAdultDomainCue(post)) {
    return true;
  }

  const communityOrProfileSurface = isCommunityOrProfileSurface(post);
  const explicitQuery = isSearchRoute() && hasExplicitSearchQuery();

  if (hasAdultSubredditCue(post)) {
    return mediaSurfaces.length > 0 || communityOrProfileSurface || explicitQuery;
  }

  if (explicitQuery && (mediaSurfaces.length > 0 || communityOrProfileSurface)) {
    return true;
  }

  return hasExplicitTextCue(text) && (mediaSurfaces.length > 0 || communityOrProfileSurface);
}

function ensureNSFWPlaceholder(post) {
  const previous = post.previousElementSibling;
  if (previous?.classList?.contains(PLACEHOLDER_CLASS)) {
    return previous;
  }

  const placeholder = document.createElement("div");
  placeholder.className = PLACEHOLDER_CLASS;
  placeholder.setAttribute("role", "note");
  placeholder.textContent = "QuietGate blocked NSFW content";
  post.parentNode?.insertBefore(placeholder, post);
  return placeholder;
}

function markNSFWPost(post, mediaSurfaces, hiddenItems, nsfwItems, placeholders) {
  const style = explicitHideStyle();
  if (style === "media") {
    for (const surface of mediaSurfaces) {
      surface.classList.add("qg-reddit-nsfw-media-item");
      hiddenItems.add(surface);
      nsfwItems.add(surface);
    }
    return;
  }

  post.classList.add("qg-reddit-nsfw-item");
  hiddenItems.add(post);
  nsfwItems.add(post);
  if (style === "placeholder") {
    const placeholder = ensureNSFWPlaceholder(post);
    nsfwItems.add(placeholder);
    placeholders.add(placeholder);
  }
}

function markNSFW(features, hiddenItems) {
  if (!features.redditNSFW) {
    cleanupNSFWPlaceholders();
    return new Set();
  }

  const nsfwItems = new Set();
  const placeholders = new Set();
  for (const post of postContainers()) {
    const mediaSurfaces = collectMediaSurfaces(post);
    if (!hasNSFWPostSignal(post, mediaSurfaces)) {
      continue;
    }
    markNSFWPost(post, mediaSurfaces, hiddenItems, nsfwItems, placeholders);
  }

  cleanupNSFWPlaceholders(placeholders);
  document.documentElement.dataset.quietgateRedditNSFWCount = String(nsfwItems.size);
  return placeholders;
}

function markRedditItems(features) {
  clearManagedItems();
  const hiddenItems = new Set();
  const contextDecision = markAdultContext(features, hiddenItems);
  if (contextDecision) {
    document.documentElement.dataset.quietgateRedditNSFWCount = String(hiddenItems.size);
    document.documentElement.dataset.quietgateRedditHiddenCount = String(hiddenItems.size);
    return;
  }
  markNSFW(features, hiddenItems);
  markRecommendations(features, hiddenItems);
  markMedia(features, hiddenItems);
  document.documentElement.dataset.quietgateRedditHiddenCount = String(hiddenItems.size);
}

function redirectBlockedRoutes(features) {
  if (features.redditPopularAll && /^\/r\/(popular|all)(\/|$)/i.test(location.pathname)) {
    location.replace("https://www.reddit.com/");
  }
}

function applySettings() {
  const features = effectiveFeatures(currentSettings);
  ensureAdultDomainSetLoaded();

  for (const [feature, className] of Object.entries(FEATURE_CLASSES)) {
    document.documentElement.classList.toggle(className, Boolean(features[feature]));
  }

  redirectBlockedRoutes(features);
  markRedditItems(features);
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
  ensureAdultDomainSetLoaded();
  applySettings();
}

function handleStorageChange(changes, areaName) {
  if (areaName !== "local") {
    return;
  }

  if (changes.mode || changes.features || changes.options || changes.blockedDomains || changes.blockedCategories) {
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

window.__quietgateRedditTunerController = {
  refresh: () => {
    loadSettings();
    syncNativeSettings();
    scheduleApplySettings();
  },
  dispose() {
    observer.disconnect();
    window.removeEventListener("popstate", scheduleApplySettings);
    window.removeEventListener("pageshow", scheduleApplySettings);
    quietGateBrowser.storage.onChanged.removeListener?.(handleStorageChange);
    clearManagedItems();
  }
};

loadSettings();
syncNativeSettings();
