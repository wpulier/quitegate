const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;

const DEFAULT_SETTINGS = {
  mode: "open",
  features: {
    instagramReels: false,
    instagramExplore: false,
    instagramSuggested: false,
    instagramStories: false
  },
  blockedDomains: []
};

const FEATURE_CLASSES = {
  instagramReels: "qg-instagram-reels",
  instagramExplore: "qg-instagram-explore",
  instagramSuggested: "qg-instagram-suggested",
  instagramStories: "qg-instagram-stories"
};

const MANAGED_CLASSES = [
  "qg-instagram-suggested-item",
  "qg-instagram-stories-item"
];

const SUGGESTED_TEXT = /\b(suggested for you|suggested posts|suggested account|because you follow|recommendations?|recommended for you)\b/i;
const STORIES_TEXT = /\bstories\b/i;

let currentSettings = DEFAULT_SETTINGS;
let syncInFlight = false;
let applyQueued = false;

document.documentElement.dataset.quietgateInstagramTuner = "loaded";
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
      instagramStories: true
    };
  }

  if (mode === "focus") {
    return {
      instagramReels: true,
      instagramExplore: true,
      instagramSuggested: true,
      instagramStories: false
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

function clearManagedItems() {
  for (const node of document.querySelectorAll(MANAGED_CLASSES.map((className) => `.${className}`).join(","))) {
    node.classList.remove(...MANAGED_CLASSES);
  }
  document.documentElement.dataset.quietgateInstagramHiddenCount = "0";
}

function nearestHideableContainer(node) {
  return node.closest?.("article, section, main > div, [role='dialog']") || node;
}

function markInstagramItems(features) {
  clearManagedItems();

  const hiddenItems = new Set();
  if (features.instagramSuggested) {
    const candidates = document.querySelectorAll("article, section, main > div, [role='dialog'] div");
    for (const candidate of candidates) {
      const text = accessibleText(candidate);
      if (text.length > 2400 || !SUGGESTED_TEXT.test(text)) {
        continue;
      }
      const item = nearestHideableContainer(candidate);
      item.classList.add("qg-instagram-suggested-item");
      hiddenItems.add(item);
    }
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

quietGateBrowser.storage.onChanged.addListener((changes, areaName) => {
  if (areaName !== "local") {
    return;
  }

  if (changes.mode || changes.features) {
    loadSettings();
  }
});

const observer = new MutationObserver(scheduleApplySettings);
observer.observe(document.documentElement, {
  childList: true,
  subtree: true
});

window.addEventListener("popstate", scheduleApplySettings);
window.addEventListener("pageshow", scheduleApplySettings);

loadSettings();
syncNativeSettings();
