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
  options: {
    explicitHideStyle: "post",
    youtubeDailyLimitMinutes: 30
  },
  blockedDomains: [],
  blockedCategories: [],
  settingsVersion: null,
  blockedRuleCount: 0,
  source: null,
  nativeSyncError: null,
  nativeSyncAt: null,
  browserID: null,
  browserProfile: null
};

const featureIds = [
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
  "youtubeDailyLimit",
  "xSensitiveMedia",
  "xExplicitContent",
  "xExplicitSearch",
  "xVideos",
  "xPhotos",
  "xMediaCards",
  "xExploreTrends",
  "instagramReels",
  "instagramExplore",
  "instagramSuggested",
  "instagramStories",
  "redditPopularAll",
  "redditRecommendations",
  "redditNSFW",
  "redditMedia",
  "redditSidebars"
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
  };
}

function setControlsDisabled(disabled) {
  document.querySelector("#mode").disabled = disabled;
  document.querySelector("#explicitHideStyle").disabled = disabled;
  document.querySelector("#youtubeDailyLimitMinutes").disabled = disabled;
  for (const id of featureIds) {
    document.querySelector(`#${id}`).disabled = disabled;
  }
}

function browserName(browserID) {
  const names = {
    chrome: "Chrome",
    edge: "Edge",
    brave: "Brave",
    arc: "Arc",
    firefox: "Firefox"
  };
  return names[browserID] || "browser";
}

function runtimeAPI() {
  return globalThis.chrome?.runtime || globalThis.browser?.runtime || null;
}

function tabsAPI() {
  return globalThis.chrome?.tabs || globalThis.browser?.tabs || null;
}

function sendRuntimeMessage(message) {
  const runtime = runtimeAPI();
  return new Promise((resolve) => {
    if (!runtime) {
      resolve({ ok: false, error: "Browser runtime is unavailable." });
      return;
    }
    try {
      const result = runtime.sendMessage(message, resolve);
      if (result && typeof result.then === "function") {
        result.then(resolve).catch((error) => resolve({ ok: false, error: error?.message || String(error) }));
      }
    } catch (error) {
      resolve({ ok: false, error: error?.message || String(error) });
    }
  });
}

function queryActiveTab() {
  const tabs = tabsAPI();
  return new Promise((resolve) => {
    if (!tabs) {
      resolve(null);
      return;
    }
    try {
      const result = tabs.query({ active: true, currentWindow: true }, (values) => {
        resolve(values?.[0] || null);
      });
      if (result && typeof result.then === "function") {
        result.then((values) => resolve(values?.[0] || null)).catch(() => resolve(null));
      }
    } catch (_error) {
      resolve(null);
    }
  });
}

function normalizePageDomain(url) {
  try {
    const parsed = new URL(url);
    if (!/^https?:$/.test(parsed.protocol)) {
      return null;
    }
    return parsed.hostname.toLowerCase().replace(/^www\./, "");
  } catch (_error) {
    return null;
  }
}

async function refreshCurrentSiteTool() {
  const button = document.querySelector("#reportAdultSite");
  const status = document.querySelector("#currentSiteStatus");
  const tab = await queryActiveTab();
  const domain = normalizePageDomain(tab?.url || "");
  if (!domain) {
    button.disabled = true;
    status.textContent = "No website tab selected.";
    return;
  }
  button.disabled = false;
  button.dataset.url = tab.url;
  button.dataset.domain = domain;
  status.textContent = domain;
}

async function reportCurrentSite() {
  const button = document.querySelector("#reportAdultSite");
  const status = document.querySelector("#currentSiteStatus");
  const url = button.dataset.url || "";
  const domain = button.dataset.domain || normalizePageDomain(url);
  if (!domain) {
    return;
  }
  button.disabled = true;
  button.textContent = "Saving...";
  const response = await sendRuntimeMessage({
    type: "quietgate.reportMissedAdultSite",
    payload: { url, domain, title: "" }
  });
  if (response?.ok) {
    status.textContent = `${response.domain || domain} is blocked.`;
    button.textContent = "Blocked";
    return;
  }
  status.textContent = response?.error || "Open QuietGate to add this site.";
  button.textContent = "Block current site";
  button.disabled = false;
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

function profileStatusText(settings) {
  const profile = normalizeProfileMetadata(settings.browserProfile);
  if (profile?.label) {
    return `Connected in ${profile.label}`;
  }
  return `Connected in this ${browserName(settings.browserID)} profile`;
}

function updateSyncStatus(settings) {
  const status = document.querySelector("#syncStatus");
  const ruleStatus = document.querySelector("#ruleStatus");
  if (settings.source === "native" && !settings.nativeSyncError) {
    const count = settings.blockedRuleCount || 0;
    status.textContent = profileStatusText(settings);
    ruleStatus.textContent = count === 1
      ? "Connected. 1 browser rule active."
      : `Connected. ${count} browser rules active.`;
    ruleStatus.hidden = false;
    status.dataset.state = "managed";
    ruleStatus.dataset.state = "managed";
    setControlsDisabled(true);
    return;
  }

  ruleStatus.textContent = "";
  ruleStatus.hidden = true;
  if (settings.nativeSyncError) {
    status.textContent = "Open QuietGate to connect helper";
    status.dataset.state = "manual";
  } else {
    status.textContent = "Waiting for QuietGate";
    status.dataset.state = "manual";
  }
  setControlsDisabled(true);
}

async function load() {
  try {
    const response = await chrome.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
    if (response?.ok && response.settings) {
      const update = {
        source: "native",
        nativeSyncError: null,
        nativeSyncAt: new Date().toISOString()
      };
      if (response.browserID) {
        update.browserID = response.browserID;
      }
      const profile = normalizeProfileMetadata(response.profile);
      if (profile) {
        update.browserProfile = profile;
      }
      await chrome.storage.local.set(update);
    }
  } catch (error) {
    // Manual popup controls still work before the native bridge is installed.
  }

  const settings = await chrome.storage.local.get(DEFAULT_SETTINGS);
  const features = {
    ...DEFAULT_SETTINGS.features,
    ...(settings.features || {})
  };
  const options = {
    ...DEFAULT_SETTINGS.options,
    ...(settings.options || {})
  };

  document.querySelector("#mode").value = settings.mode || DEFAULT_SETTINGS.mode;
  document.querySelector("#explicitHideStyle").value = options.explicitHideStyle;
  document.querySelector("#youtubeDailyLimitMinutes").value = options.youtubeDailyLimitMinutes;

  for (const id of featureIds) {
    document.querySelector(`#${id}`).checked = Boolean(features[id]);
  }
  updateSyncStatus(settings);
  await refreshCurrentSiteTool();
}

async function saveFeature(id, checked) {
  const settings = await chrome.storage.local.get(DEFAULT_SETTINGS);
  await chrome.storage.local.set({
    ...settings,
    source: "popup",
    features: {
      ...DEFAULT_SETTINGS.features,
      ...(settings.features || {}),
      [id]: checked
    }
  });
}

async function saveExplicitHideStyle(value) {
  const settings = await chrome.storage.local.get(DEFAULT_SETTINGS);
  await chrome.storage.local.set({
    ...settings,
    source: "popup",
    options: {
      ...DEFAULT_SETTINGS.options,
      ...(settings.options || {}),
      explicitHideStyle: value
    }
  });
}

async function saveYouTubeDailyLimitMinutes(value) {
  const settings = await chrome.storage.local.get(DEFAULT_SETTINGS);
  const minutes = Math.min(Math.max(Number(value) || DEFAULT_SETTINGS.options.youtubeDailyLimitMinutes, 5), 480);
  await chrome.storage.local.set({
    ...settings,
    source: "popup",
    options: {
      ...DEFAULT_SETTINGS.options,
      ...(settings.options || {}),
      youtubeDailyLimitMinutes: minutes
    }
  });
}

document.querySelector("#mode").addEventListener("change", async (event) => {
  const mode = event.target.value;
  const features = modeFeatures(mode);

  await chrome.storage.local.set({
    mode,
    features,
    source: "popup"
  });

  for (const id of featureIds) {
    document.querySelector(`#${id}`).checked = Boolean(features[id]);
  }
});

for (const id of featureIds) {
  document.querySelector(`#${id}`).addEventListener("change", (event) => {
    saveFeature(id, event.target.checked);
  });
}

document.querySelector("#explicitHideStyle").addEventListener("change", (event) => {
  saveExplicitHideStyle(event.target.value);
});

document.querySelector("#youtubeDailyLimitMinutes").addEventListener("change", (event) => {
  saveYouTubeDailyLimitMinutes(event.target.value);
});

document.querySelector("#reportAdultSite").addEventListener("click", () => {
  reportCurrentSite();
});

load();
