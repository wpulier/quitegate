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

async function connectQuietGate() {
  const status = document.querySelector("#connectStatus");
  const profileDetail = document.querySelector("#profileDetail");
  const detail = document.querySelector("#connectDetail");

  status.textContent = "Connecting Browser Helper...";
  status.dataset.state = "manual";
  profileDetail.textContent = "Checking this browser profile...";
  profileDetail.dataset.state = "manual";
  detail.textContent = "QuietGate is sending this browser the latest site tuning and browser rules.";

  try {
    const response = await browser.runtime.sendMessage({ type: "quietgate.syncNativeSettings" });
    if (response?.ok) {
      const count = response.blockedRuleCount || 0;
      status.textContent = "Browser Helper connected";
      status.dataset.state = "managed";
      profileDetail.textContent = profileStatusText(response);
      profileDetail.dataset.state = "managed";
      detail.textContent =
        count === 1
          ? "This browser confirmed 1 browser block rule."
          : `This browser confirmed ${count} browser block rules.`;
      return;
    }

    status.textContent = "Browser Helper needs attention";
    status.dataset.state = "manual";
    profileDetail.textContent = "This browser profile is not connected yet.";
    profileDetail.dataset.state = "manual";
    detail.textContent = response?.error || "This browser could not reach QuietGate.";
  } catch (error) {
    status.textContent = "Browser Helper needs attention";
    status.dataset.state = "manual";
    profileDetail.textContent = "This browser profile is not connected yet.";
    profileDetail.dataset.state = "manual";
    detail.textContent = error?.message || "This browser could not reach QuietGate.";
  }
}

document.querySelector("#syncNow").addEventListener("click", connectQuietGate);
connectQuietGate();
