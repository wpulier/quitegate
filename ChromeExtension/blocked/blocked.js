chrome.runtime.sendMessage({ type: "quietgate.syncNativeSettings" }).catch(() => {
  // Existing DNR rules keep this page blocked even if QuietGate is closed.
});

document.getElementById("backButton")?.addEventListener("click", () => {
  if (history.length > 1) {
    history.back();
    return;
  }

  window.close();
});
