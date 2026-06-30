let quietGateSyncInFlight = false;

async function syncQuietGateSettings() {
  if (quietGateSyncInFlight) {
    return;
  }

  quietGateSyncInFlight = true;
  try {
    await chrome.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
  } catch (error) {
    // DNR keeps enforcing the last applied rules if the native host is unavailable.
  } finally {
    quietGateSyncInFlight = false;
  }
}

syncQuietGateSettings();
