var quietGateInstagramTunerVersion = "2026.06.29.1200";
var existingQuietGateInstagramController = window.__quietgateInstagramTunerController;
if (existingQuietGateInstagramController?.version === quietGateInstagramTunerVersion) {
  existingQuietGateInstagramController.refresh?.();
} else {
existingQuietGateInstagramController?.dispose?.();

const TUNER_VERSION = "2026.06.29.1200";
const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;

const DEFAULT_SETTINGS = {
  mode: "open",
  features: {
    instagramReels: false,
    instagramExplore: false,
    instagramSuggested: false,
    instagramProfileSuggestions: false,
    instagramMessages: false,
    instagramNotifications: false,
    instagramStories: false
  },
  blockedDomains: []
};

const FEATURE_CLASSES = {
  instagramReels: "qg-instagram-reels",
  instagramExplore: "qg-instagram-explore",
  instagramSuggested: "qg-instagram-suggested",
  instagramProfileSuggestions: "qg-instagram-profile-suggestions",
  instagramMessages: "qg-instagram-messages",
  instagramNotifications: "qg-instagram-notifications",
  instagramStories: "qg-instagram-stories"
};

const MANAGED_CLASSES = [
  "qg-instagram-reels-item",
  "qg-instagram-explore-item",
  "qg-instagram-suggested-item",
  "qg-instagram-profile-suggestions-item",
  "qg-instagram-messages-item",
  "qg-instagram-notifications-item",
  "qg-instagram-stories-item"
];

const SUGGESTED_TEXT = /\b(suggested for you|suggested posts|because you follow|because you watched|similar to|recommendations?|recommended for you)\b/i;
const SUGGESTED_POST_SECTION_TEXT = /\b(suggested posts|recommendations?|recommended for you)\b/i;
const PROFILE_SUGGESTION_TEXT = /\b(suggested for you|suggested account|followed by|people you may know|discover people)\b/i;
const PROFILE_SECTION_TEXT = /\b(suggested for you|suggested account|people you may know|discover people)\b/i;
const PROMOTED_TEXT = /^(ad|sponsored|promoted)$/i;
const STORIES_TEXT = /\bstories\b/i;
const REELS_SELECTOR = "a[href^='/reel/'], a[href^='/reels/'], [aria-label='Reels'], [aria-label*='Reels']";
const EXPLORE_SELECTOR = "a[href='/explore/'], a[href^='/explore/'], [aria-label='Explore'], [aria-label*='Explore']";
const MESSAGES_SELECTOR = "a[href^='/direct/'], [aria-label*='Direct'], [aria-label*='Messenger'], [aria-label*='Messages']";
const NOTIFICATIONS_SELECTOR = "[aria-label*='Notifications'], [aria-label*='Activity']";

let currentSettings = DEFAULT_SETTINGS;
let syncInFlight = false;
let applyQueued = false;
let usageController = null;

document.documentElement.dataset.quietgateInstagramTuner = "loaded";
document.documentElement.dataset.quietgateInstagramTunerVersion = TUNER_VERSION;
document.documentElement.dataset.quietgateInstagramHiddenCount = "0";

function mergedSettings(value) {
  return {
    mode: value.mode || DEFAULT_SETTINGS.mode,
    features: {
      ...DEFAULT_SETTINGS.features,
      ...(value.features || {})
    }
  };
}

function modeFeatures(mode) {
  if (mode === "strict") {
    return {
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramProfileSuggestions: true,
      instagramMessages: true,
      instagramNotifications: true,
      instagramStories: true
    };
  }

  if (mode === "focus") {
    return {
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramProfileSuggestions: true,
      instagramMessages: true,
      instagramNotifications: true,
      instagramStories: true
    };
  }

  return { ...DEFAULT_SETTINGS.features };
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

  const parts = [node.innerText || node.textContent || ""];
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

function clearManagedItems() {
  for (const node of document.querySelectorAll(MANAGED_CLASSES.map((className) => `.${className}`).join(","))) {
    node.classList.remove(...MANAGED_CLASSES);
  }
  document.documentElement.dataset.quietgateInstagramHiddenCount = "0";
}

function nearestHideableContainer(node) {
  return node.closest?.("article, section, main > div, [role='dialog']") || node;
}

function normalizedText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function directText(node) {
  if (!node) {
    return "";
  }

  return normalizedText(
    [...node.childNodes]
      .filter((child) => child.nodeType === Node.TEXT_NODE)
      .map((child) => child.textContent || "")
      .join(" ")
  );
}

function visibleText(node) {
  if (!node || node.nodeType !== Node.ELEMENT_NODE) {
    return "";
  }
  const tagName = node.tagName?.toLowerCase();
  if (tagName === "script" || tagName === "style") {
    return "";
  }
  const style = window.getComputedStyle?.(node);
  if (style && (style.display === "none" || style.visibility === "hidden")) {
    return "";
  }
  return normalizedText(node.textContent || "");
}

function nodeHasExactLabel(node, pattern) {
  if (!node) {
    return false;
  }
  const candidates = [
    directText(node),
    node.getAttribute?.("aria-label") || "",
    node.getAttribute?.("title") || "",
    node.getAttribute?.("alt") || ""
  ].map(normalizedText).filter(Boolean);
  return candidates.some((value) => pattern.test(value));
}

function hasLabel(node, pattern) {
  if (pattern.test(directText(node))) {
    return true;
  }
  return [...node.querySelectorAll?.("h1,h2,h3,span,div,[aria-label],[title]") || []]
    .some((child) => nodeHasExactLabel(child, pattern));
}

function hasSuggestedPostLabel(node) {
  return hasLabel(node, SUGGESTED_POST_SECTION_TEXT);
}

function hasProfileSuggestionLabel(node) {
  return hasLabel(node, PROFILE_SECTION_TEXT);
}

function hasPromotedLabel(node) {
  if (nodeHasExactLabel(node, PROMOTED_TEXT)) {
    return true;
  }
  return [...node.querySelectorAll?.("span,div,a,[aria-label],[title]") || []]
    .some((child) => nodeHasExactLabel(child, PROMOTED_TEXT));
}

function hasFollowAction(node) {
  return [...node.querySelectorAll?.("a,button,[role='button']") || []]
    .some((child) => /\bfollow\b/i.test(accessibleText(child)));
}

function instagramPostContainers() {
  return [...new Set([...document.querySelectorAll("article, [role='article']")])]
    .filter((node) => node !== document.body && node !== document.documentElement);
}

function candidateModuleFromLabel(labelNode, labelPattern, requiresFollowAction) {
  const semanticContainer = labelNode.closest?.("aside, section, [role='complementary'], [role='dialog']");
  if (semanticContainer && semanticContainer !== document.body && semanticContainer !== document.documentElement) {
    const text = accessibleText(semanticContainer);
    if (text.length <= 2600 && (!requiresFollowAction || hasFollowAction(semanticContainer))) {
      return semanticContainer;
    }
  }

  let best = null;
  let current = labelNode.parentElement;
  while (current && current !== document.body && current !== document.documentElement) {
    if (current.tagName?.toLowerCase() === "main" || current.getAttribute("role") === "main") {
      break;
    }
    const text = accessibleText(current);
    if (
      text.length > 80 &&
      text.length <= 2600 &&
      hasLabel(current, labelPattern) &&
      (!requiresFollowAction || hasFollowAction(current))
    ) {
      best = current;
    }
    current = current.parentElement;
  }
  return best;
}

function nearestNavItem(node) {
  const item = node.closest?.("a, button, [role='button'], [role='link'], nav li, nav div") || node;
  if (!item || item === document.body || item === document.documentElement) {
    return null;
  }
  return item;
}

function markSelectorItems(selector, className, hiddenItems) {
  for (const node of document.querySelectorAll(selector)) {
    const item = nearestNavItem(node);
    if (!item) {
      continue;
    }
    item.classList.add(className);
    hiddenItems.add(item);
  }
}

function markSuggestedItems(hiddenItems) {
  for (const post of instagramPostContainers()) {
    const text = accessibleText(post);
    if (text.length > 3200) {
      continue;
    }
    if (SUGGESTED_TEXT.test(text) || hasPromotedLabel(post)) {
      post.classList.add("qg-instagram-suggested-item");
      hiddenItems.add(post);
    }
  }

  const moduleCandidates = document.querySelectorAll("aside, section, [role='complementary'], [role='dialog'], main > div");
  for (const candidate of moduleCandidates) {
    if (candidate.closest?.("article, [role='article']")) {
      continue;
    }
    const text = accessibleText(candidate);
    if (text.length > 2600 || !SUGGESTED_TEXT.test(text)) {
      continue;
    }
    if (hasProfileSuggestionLabel(candidate) && !hasSuggestedPostLabel(candidate)) {
      continue;
    }
    if (!hasSuggestedPostLabel(candidate) && !hasPromotedLabel(candidate)) {
      continue;
    }
    const item = nearestHideableContainer(candidate);
    item.classList.add("qg-instagram-suggested-item");
    hiddenItems.add(item);
  }

  const labelCandidates = document.querySelectorAll("h1,h2,h3,span,div,[aria-label],[title]");
  for (const label of labelCandidates) {
    const labelText = visibleText(label);
    if (labelText.length > 80 || !SUGGESTED_POST_SECTION_TEXT.test(labelText)) {
      continue;
    }
    const item = candidateModuleFromLabel(label, SUGGESTED_POST_SECTION_TEXT, false);
    if (!item) {
      continue;
    }
    item.classList.add("qg-instagram-suggested-item");
    hiddenItems.add(item);
  }
}

function markProfileSuggestionItems(hiddenItems) {
  const moduleCandidates = document.querySelectorAll("aside, section, [role='complementary'], [role='dialog'], main > div");
  for (const candidate of moduleCandidates) {
    if (candidate.closest?.("article, [role='article']")) {
      continue;
    }
    const text = accessibleText(candidate);
    if (text.length > 2600 || !PROFILE_SUGGESTION_TEXT.test(text)) {
      continue;
    }
    if (!hasProfileSuggestionLabel(candidate) && !hasFollowAction(candidate)) {
      continue;
    }
    const item = nearestHideableContainer(candidate);
    item.classList.add("qg-instagram-profile-suggestions-item");
    hiddenItems.add(item);
  }

  const labelCandidates = document.querySelectorAll("h1,h2,h3,span,div,[aria-label],[title]");
  for (const label of labelCandidates) {
    const labelText = visibleText(label);
    if (labelText.length > 80 || !PROFILE_SECTION_TEXT.test(labelText)) {
      continue;
    }
    const item = candidateModuleFromLabel(label, PROFILE_SECTION_TEXT, true);
    if (!item) {
      continue;
    }
    item.classList.add("qg-instagram-profile-suggestions-item");
    hiddenItems.add(item);
  }
}

function markInstagramItems(features) {
  clearManagedItems();

  const hiddenItems = new Set();
  if (features.instagramReels) {
    markSelectorItems(REELS_SELECTOR, "qg-instagram-reels-item", hiddenItems);
  }

  if (features.instagramExplore) {
    markSelectorItems(EXPLORE_SELECTOR, "qg-instagram-explore-item", hiddenItems);
  }

  if (features.instagramSuggested) {
    markSuggestedItems(hiddenItems);
  }

  if (features.instagramProfileSuggestions) {
    markProfileSuggestionItems(hiddenItems);
  }

  if (features.instagramMessages) {
    markSelectorItems(MESSAGES_SELECTOR, "qg-instagram-messages-item", hiddenItems);
  }

  if (features.instagramNotifications) {
    markSelectorItems(NOTIFICATIONS_SELECTOR, "qg-instagram-notifications-item", hiddenItems);
  }

  if (features.instagramStories) {
    const candidates = document.querySelectorAll("[aria-label*='Stories'], [aria-label*='stories'], section, main > div");
    for (const candidate of candidates) {
      const text = accessibleText(candidate);
      if (text.length > 1600 || !STORIES_TEXT.test(text)) {
        continue;
      }
      const hasStoryLikeLink = candidate.querySelector?.("canvas, img, a[href^='/stories/'], [role='button']");
      if (!hasStoryLikeLink) {
        continue;
      }
      const item = nearestHideableContainer(candidate);
      item.classList.add("qg-instagram-stories-item");
      hiddenItems.add(item);
    }
  }

  document.documentElement.dataset.quietgateInstagramHiddenCount = String(hiddenItems.size);
}

function redirectBlockedRoutes(features) {
  if (features.instagramReels && /^\/reels?(\/|$)/.test(location.pathname)) {
    location.replace("https://www.instagram.com/");
    return;
  }

  if (features.instagramExplore && /^\/explore(\/|$)/.test(location.pathname)) {
    location.replace("https://www.instagram.com/");
    return;
  }

  if (features.instagramMessages && /^\/direct(\/|$)/.test(location.pathname)) {
    location.replace("https://www.instagram.com/");
    return;
  }

  if (features.instagramNotifications && /^\/notifications?(\/|$)/.test(location.pathname)) {
    location.replace("https://www.instagram.com/");
  }
}

function applySettings() {
  const features = effectiveFeatures(currentSettings);

  for (const [feature, className] of Object.entries(FEATURE_CLASSES)) {
    document.documentElement.classList.toggle(className, Boolean(features[feature]));
  }

  redirectBlockedRoutes(features);
  markInstagramItems(features);
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

  if (changes.mode || changes.features) {
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

usageController = window.__tortoiseSiteUsage?.initSiteUsageTracker({ siteID: "instagram" }) || null;

window.__quietgateInstagramTunerController = {
  version: TUNER_VERSION,
  refresh: () => {
    loadSettings();
    usageController?.refresh?.();
    syncNativeSettings();
    scheduleApplySettings();
  },
  dispose() {
    observer.disconnect();
    window.removeEventListener("popstate", scheduleApplySettings);
    window.removeEventListener("pageshow", scheduleApplySettings);
    quietGateBrowser.storage.onChanged.removeListener?.(handleStorageChange);
    usageController?.dispose?.();
    usageController = null;
    clearManagedItems();
  }
};

loadSettings();
syncNativeSettings();
}
