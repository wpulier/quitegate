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

function profileStatusText(response) {
  const profile = normalizeProfileMetadata(response?.profile);
  if (profile?.label) {
    return `Connected in ${profile.label}`;
  }
  return `Connected in this ${browserName(response?.browserID)} profile`;
}

async function connectQuietGate({ openAccountSetup = true } = {}) {
  const status = document.querySelector("#connectStatus");
  const profileDetail = document.querySelector("#profileDetail");
  const detail = document.querySelector("#connectDetail");
  const button = document.querySelector("#syncNow");

  status.textContent = "Checking this Chrome profile...";
  status.dataset.state = "manual";
  profileDetail.textContent = "Checking this browser profile...";
  profileDetail.dataset.state = "manual";
  detail.textContent = "QuietGate is checking the extension and your account connection.";
  button.disabled = true;
  button.textContent = "Checking...";

  let nativeResponse = null;
  try {
    nativeResponse = await chrome.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
    if (nativeResponse?.ok) {
      profileDetail.textContent = profileStatusText(nativeResponse);
      profileDetail.dataset.state = "managed";
    } else {
      profileDetail.textContent = nativeResponse?.error || "The Mac app connection needs attention.";
      profileDetail.dataset.state = "manual";
    }
  } catch (error) {
    profileDetail.textContent = error?.message || "The Chrome extension could not reach the Mac app.";
    profileDetail.dataset.state = "manual";
  }

  let accountResponse;
  try {
    accountResponse = await chrome.runtime.sendMessage({ type: "quietgate.extensionStatus" });
  } catch (error) {
    status.textContent = "Chrome extension needs attention";
    status.dataset.state = "manual";
    detail.textContent = error?.message || "QuietGate could not check this extension account.";
    button.disabled = false;
    button.textContent = "Try again";
    return;
  }

  if (accountResponse?.signedIn) {
    const count = Number(accountResponse.blockedRuleCount ?? nativeResponse?.blockedRuleCount) || 0;
    status.textContent = "Chrome extension connected";
    status.dataset.state = "managed";
    detail.textContent = count === 1
      ? "Your account is connected and 1 browser block rule is active."
      : `Your account is connected and ${count} browser block rules are active.`;
    button.disabled = false;
    button.textContent = "Check again";
    return;
  }

  status.textContent = "Account sign-in required";
  status.dataset.state = "manual";
  detail.textContent = "Sign in or create an account to add this Chrome profile to QuietGate.";
  button.disabled = false;
  button.textContent = "Sign in or create account";

  if (!openAccountSetup) {
    return;
  }

  button.disabled = true;
  button.textContent = "Opening account setup...";
  const connectResponse = await chrome.runtime.sendMessage({ type: "quietgate.startExtensionConnect" });
  if (!connectResponse?.ok) {
    detail.textContent = connectResponse?.error || "QuietGate could not open account setup.";
    button.disabled = false;
    button.textContent = "Try again";
    return;
  }

  status.textContent = "Finish in the tab that opened";
  detail.textContent = "After you sign in or create your account, this page will confirm the connection.";
  button.disabled = false;
  button.textContent = "Open account setup again";
}

document.querySelector("#syncNow").addEventListener("click", () => {
  connectQuietGate({ openAccountSetup: true });
});

chrome.storage.onChanged.addListener((changes, areaName) => {
  if (
    areaName === "local" &&
    (changes.extensionDeviceToken || changes.extensionDevice || changes.extensionLastSyncAt)
  ) {
    connectQuietGate({ openAccountSetup: false });
  }
});

connectQuietGate({ openAccountSetup: true });
