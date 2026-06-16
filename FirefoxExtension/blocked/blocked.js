const site = new URLSearchParams(window.location.search).get("site");
const siteLine = document.getElementById("siteLine");

browser.runtime.sendMessage({ type: "quietgate.syncNativeSettings" }).catch(() => {
  // Existing webRequest rules keep this page blocked even if QuietGate is closed.
});

if (site && siteLine) {
  siteLine.textContent = site;
  siteLine.hidden = false;
}

document.getElementById("backButton")?.addEventListener("click", () => {
  if (history.length > 1) {
    history.back();
    return;
  }

  window.close();
});
