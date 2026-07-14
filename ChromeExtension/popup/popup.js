const accountConnectRequested = new URLSearchParams(globalThis.location?.search || "").get("connect") === "1";
let accountConnectOpened = false;

if (accountConnectRequested) {
  document.body.classList.add("connect-page");
}

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

const QUIETGATE_WEB_ORIGIN = "https://www.yourtortoise.com";

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
  "instagramProfileSuggestions",
  "instagramMessages",
  "instagramNotifications",
  "instagramStories",
  "redditPopularAll",
  "redditRecommendations",
  "redditNSFW",
  "redditMedia",
  "redditSidebars"
];

const siteFeatureIds = {
  youtube: featureIds.filter((id) => id.startsWith("youtube")),
  x: featureIds.filter((id) => id.startsWith("x")),
  instagram: featureIds.filter((id) => id.startsWith("instagram")),
  reddit: featureIds.filter((id) => id.startsWith("reddit"))
};

function setControlsDisabled(disabled) {
  const dailyLimit = document.querySelector("#youtubeDailyLimitMinutes");
  if (dailyLimit) {
    dailyLimit.disabled = disabled;
  }
  for (const id of featureIds) {
    const control = document.querySelector(`#${id}`);
    if (control) {
      control.disabled = disabled;
    }
  }
}

function modeLabel(mode) {
  if (mode === "strict") {
    return "Strict";
  }
  if (mode === "focus") {
    return "Focus";
  }
  return "Open";
}

function updateTuneCounts(features) {
  for (const [siteID, ids] of Object.entries(siteFeatureIds)) {
    const active = ids.filter((id) => Boolean(features[id])).length;
    const tileCount = document.querySelector(`#${siteID}Count`);
    const panelCount = document.querySelector(`#${siteID}PanelCount`);
    if (tileCount) {
      tileCount.textContent = `${active}/${ids.length} hidden`;
    }
    if (panelCount) {
      panelCount.textContent = `${active} of ${ids.length} hidden`;
    }
  }
}

function setupTuneNavigation() {
  const buttons = [...document.querySelectorAll("[data-tune-site]")];
  const panels = [...document.querySelectorAll("[data-tune-panel]")];
  const emptyState = document.querySelector("#emptyTuneState");

  const selectSite = (siteID) => {
    const nextSite = buttons.find((button) => button.getAttribute("aria-expanded") === "true")?.dataset.tuneSite === siteID
      ? null
      : siteID;

    for (const button of buttons) {
      button.setAttribute("aria-expanded", String(button.dataset.tuneSite === nextSite));
    }
    for (const panel of panels) {
      panel.hidden = panel.dataset.tunePanel !== nextSite;
    }
    emptyState.hidden = Boolean(nextSite);
  };

  for (const button of buttons) {
    button.addEventListener("click", () => selectSite(button.dataset.tuneSite));
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
    let settled = false;
    const resolveOnce = (value) => {
      if (settled) {
        return;
      }
      settled = true;
      resolve(value);
    };
    try {
      if (runtime === globalThis.browser?.runtime && runtime !== globalThis.chrome?.runtime) {
        runtime
          .sendMessage(message)
          .then(resolveOnce)
          .catch((error) => resolveOnce({ ok: false, error: error?.message || String(error) }));
        return;
      }
      const result = runtime.sendMessage(message, (response) => {
        const error = runtime.lastError;
        if (error) {
          resolveOnce({ ok: false, error: error.message || String(error) });
          return;
        }
        resolveOnce(response);
      });
      if (result && typeof result.then === "function") {
        result
          .then(resolveOnce)
          .catch((error) => resolveOnce({ ok: false, error: error?.message || String(error) }));
      }
    } catch (error) {
      resolveOnce({ ok: false, error: error?.message || String(error) });
    }
  });
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

function formatDate(value) {
  if (!value) {
    return "never";
  }
  try {
    return new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit",
      month: "short",
      day: "numeric"
    }).format(new Date(value));
  } catch (_error) {
    return value;
  }
}

function setButtonBusy(button, busy, label = null) {
  if (!button) {
    return;
  }
  if (!button.dataset.defaultLabel) {
    button.dataset.defaultLabel = button.textContent;
  }
  button.disabled = busy;
  button.textContent = busy && label ? label : button.dataset.defaultLabel;
}

function updateAccountStatus(status, settings = {}) {
  const signedOutAccount = document.querySelector("#signedOutAccount");
  const signedInAccount = document.querySelector("#signedInAccount");
  const managedControls = document.querySelector("#managedControls");
  const accountStatus = document.querySelector("#accountStatus");
  const accountDetail = document.querySelector("#accountDetail");
  const signedInAccountDetail = document.querySelector("#signedInAccountDetail");
  const accountMenuLabel = document.querySelector("#accountMenuLabel");
  const accountMenu = document.querySelector("#accountMenu");
  const connectButton = document.querySelector("#connectQuietGate");
  const syncButton = document.querySelector("#syncQuietGate");
  const dashboardButton = document.querySelector("#openDashboard");
  const disconnectButton = document.querySelector("#disconnectQuietGate");
  const requestAllSitesButton = document.querySelector("#requestAllSites");
  const protectionDetails = document.querySelector("#protectionDetails");
  const protectionSummary = document.querySelector("#protectionSummary");
  const localProtectionDetail = document.querySelector("#localProtectionDetail");
  const permissionStatus = document.querySelector("#permissionStatus");
  const incognitoStatus = document.querySelector("#incognitoStatus");
  const localAdultBlocking = document.querySelector("#localAdultBlocking");
  const signedIn = Boolean(status?.signedIn);
  const permissions = status?.permissions || {};
  const deviceName = status?.device?.name || "QuietGate for Chrome";
  const policyVersion = status?.policySettingsVersion || settings.policySettingsVersion || null;

  document.body.dataset.accountState = signedIn ? "signed-in" : "signed-out";
  signedOutAccount.hidden = signedIn;
  signedInAccount.hidden = !signedIn;
  managedControls.hidden = !signedIn;
  protectionDetails.hidden = !signedIn;
  accountMenu.hidden = !signedIn;
  accountMenuLabel.textContent = signedIn ? "Connected" : "Connect";
  if (!signedIn) {
    accountMenu.open = false;
  }

  accountStatus.textContent = deviceName;
  accountStatus.dataset.state = "managed";
  signedInAccountDetail.textContent = `Policy ${policyVersion || "pending"} · synced ${formatDate(status?.lastSyncAt || settings.extensionLastSyncAt)}`;
  if (!signedIn && !accountDetail.textContent.trim()) {
    accountDetail.textContent = "Secure sign-in opens on yourtortoise.com.";
  }

  connectButton.hidden = signedIn;
  syncButton.hidden = !signedIn;
  dashboardButton.hidden = !signedIn;
  disconnectButton.hidden = !signedIn;
  requestAllSitesButton.hidden = Boolean(permissions.optionalAllSites);
  localAdultBlocking.closest("label").hidden = signedIn;
  localAdultBlocking.checked = Boolean(status?.localAdultBlockingEnabled);
  protectionSummary.textContent = "Browser protection";
  localProtectionDetail.textContent = "QuietGate uses browser permissions to apply the protection policy synced from your account.";
  protectionDetails.open = signedIn && !permissions.optionalAllSites;

  permissionStatus.textContent = permissions.optionalAllSites
    ? "Full web classifier permission is enabled."
    : "Full web classifier permission is off; packaged adult-domain blocking still works.";
  incognitoStatus.textContent = permissions.incognitoAllowed
    ? "Incognito access is enabled."
    : "Incognito is off. Enable Allow in Incognito on chrome://extensions for private windows.";
}

function updateSyncStatus(settings) {
  const status = document.querySelector("#syncStatus");
  const ruleStatus = document.querySelector("#ruleStatus");
  if (document.body.dataset.accountState !== "signed-in") {
    status.textContent = "Sign in to finish setup";
    status.dataset.state = "manual";
    ruleStatus.textContent = "";
    ruleStatus.hidden = true;
    setControlsDisabled(true);
    return;
  }

  if (settings.source === "smoke" && !settings.nativeSyncError && !settings.extensionSyncError) {
    const count = settings.blockedRuleCount || 0;
    status.textContent = "Synced with Tortoise";
    ruleStatus.textContent = count === 1
      ? "Connected. 1 browser rule active."
      : `Connected. ${count} browser rules active.`;
    ruleStatus.hidden = false;
    status.dataset.state = "managed";
    ruleStatus.dataset.state = "managed";
    setControlsDisabled(true);
    return;
  }

  if (settings.source === "remote" && !settings.extensionSyncError) {
    const count = settings.blockedRuleCount || 0;
    status.textContent = "Synced with Tortoise";
    ruleStatus.textContent = count === 1
      ? "1 browser rule active."
      : `${count} browser rules active.`;
    ruleStatus.hidden = false;
    status.dataset.state = "managed";
    ruleStatus.dataset.state = "managed";
    setControlsDisabled(true);
    return;
  }

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
  if (settings.extensionSyncError || settings.nativeSyncError) {
    status.textContent = settings.extensionSyncError || "Open QuietGate to connect helper";
    status.dataset.state = "manual";
  } else if (settings.source === "local") {
    status.textContent = "Local signed-out mode";
    status.dataset.state = "manual";
  } else {
    status.textContent = "Waiting for QuietGate";
    status.dataset.state = "manual";
  }
  setControlsDisabled(true);
}

async function load() {
  const statusBeforeSync = await sendRuntimeMessage({ type: "quietgate.extensionStatus" });
  updateAccountStatus(statusBeforeSync || {});
  await sendRuntimeMessage({ type: "quietgate.syncQuietGateSettings" });
  const status = await sendRuntimeMessage({ type: "quietgate.extensionStatus" });

  const settings = await chrome.storage.local.get(DEFAULT_SETTINGS);
  const features = {
    ...DEFAULT_SETTINGS.features,
    ...(settings.features || {})
  };
  const options = {
    ...DEFAULT_SETTINGS.options,
    ...(settings.options || {})
  };

  document.querySelector("#youtubeDailyLimitMinutes").value = options.youtubeDailyLimitMinutes;
  document.querySelector("#modeStatus").textContent = modeLabel(settings.mode || DEFAULT_SETTINGS.mode);

  for (const id of featureIds) {
    document.querySelector(`#${id}`).checked = Boolean(features[id]);
  }
  updateTuneCounts(features);
  updateAccountStatus(status || statusBeforeSync || {}, settings);
  updateSyncStatus(settings);

  const accountStatus = status || statusBeforeSync || {};
  if (accountConnectRequested && !accountStatus.signedIn && !accountConnectOpened) {
    accountConnectOpened = true;
    const response = await sendRuntimeMessage({ type: "quietgate.startExtensionConnect" });
    document.querySelector("#accountDetail").textContent = response?.ok
      ? "Finish signing in or creating your account in the tab that opened."
      : response?.error || "Could not open QuietGate sign-in.";
  }
}

document.querySelector("#connectQuietGate").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  setButtonBusy(button, true, "Opening...");
  const response = await sendRuntimeMessage({ type: "quietgate.startExtensionConnect" });
  if (!response?.ok) {
    document.querySelector("#accountDetail").textContent = response?.error || "Could not open QuietGate sign-in.";
    setButtonBusy(button, false);
    return;
  }
  document.querySelector("#accountDetail").textContent = "Sign in with the same Tortoise account you use in the app.";
  setButtonBusy(button, false);
});

document.querySelector("#syncQuietGate").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  setButtonBusy(button, true, "Syncing...");
  await sendRuntimeMessage({ type: "quietgate.syncRemotePolicy", forceApply: true });
  setButtonBusy(button, false);
  await load();
});

document.querySelector("#footerSyncQuietGate").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  setButtonBusy(button, true, "Syncing...");
  await sendRuntimeMessage({ type: "quietgate.syncRemotePolicy", forceApply: true });
  setButtonBusy(button, false);
  await load();
});

document.querySelector("#openDashboard").addEventListener("click", () => {
  const tabs = tabsAPI();
  if (tabs?.create) {
    tabs.create({ url: QUIETGATE_WEB_ORIGIN });
  }
});

document.querySelector("#requestAllSites").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  setButtonBusy(button, true, "Requesting...");
  const response = await sendRuntimeMessage({ type: "quietgate.requestAllSitesPermission" });
  document.querySelector("#permissionStatus").textContent = response?.ok
    ? "Full web protection is enabled."
    : response?.error || "Permission was not enabled.";
  setButtonBusy(button, false);
  await load();
});

document.querySelector("#disconnectQuietGate").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  setButtonBusy(button, true, "Disconnecting...");
  await sendRuntimeMessage({ type: "quietgate.revokeExtensionDevice" });
  setButtonBusy(button, false);
  await load();
});

document.querySelector("#localAdultBlocking").addEventListener("change", async (event) => {
  await sendRuntimeMessage({
    type: "quietgate.setLocalAdultBlocking",
    enabled: event.target.checked
  });
  await load();
});

setupTuneNavigation();
load();
