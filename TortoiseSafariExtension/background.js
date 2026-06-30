const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;
const NATIVE_EXTENSION_ID = "com.yourtortoise.Tortoise.SafariExtension";

async function sendNativeMessage(message) {
  if (!quietGateBrowser.runtime?.sendNativeMessage) {
    return null;
  }

  try {
    return await quietGateBrowser.runtime.sendNativeMessage(message);
  } catch (_singleArgumentError) {
    try {
      return await quietGateBrowser.runtime.sendNativeMessage(NATIVE_EXTENSION_ID, message);
    } catch (_namedApplicationError) {
      return null;
    }
  }
}

async function syncNativeSettings() {
  const response = await sendNativeMessage({ type: "quietgate.policy" });
  const updates = response?.storageUpdates;
  if (!updates || typeof updates !== "object") {
    return { ok: false };
  }

  await quietGateBrowser.storage.local.set(updates);
  return { ok: true, setup: response.setup || null };
}

async function recordSiteUsage(message = {}) {
  const stored = await quietGateBrowser.storage.local.get({ siteUsageBySite: {} });
  await sendNativeMessage({
    type: "quietgate.recordSiteUsage",
    siteID: message.siteID || null,
    reason: message.reason || null,
    siteUsageBySite: stored.siteUsageBySite || {}
  });
  return { ok: true };
}

quietGateBrowser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  const type = message?.type;
  if (type === "quietgate.syncNativeSettings") {
    syncNativeSettings().then(sendResponse);
    return true;
  }

  if (type === "quietgate.siteUsageChanged") {
    recordSiteUsage(message).then(sendResponse);
    return true;
  }

  return false;
});

quietGateBrowser.runtime.onInstalled?.addListener(() => {
  syncNativeSettings();
});

quietGateBrowser.runtime.onStartup?.addListener(() => {
  syncNativeSettings();
});

syncNativeSettings();
