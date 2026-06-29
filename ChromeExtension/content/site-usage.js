(() => {
const VERSION = "2026.06.29.1200";
const existing = window.__tortoiseSiteUsage;
if (existing?.version === VERSION) {
  return;
}

const quietGateBrowser = typeof browser !== "undefined" ? browser : chrome;
const SITES = [
  { id: "all", title: "All", shortTitle: "All", activityLabel: null },
  { id: "youtube", title: "YouTube", shortTitle: "YouTube", activityLabel: "videos" },
  { id: "x", title: "X", shortTitle: "X", activityLabel: null },
  { id: "instagram", title: "Instagram", shortTitle: "Instagram", activityLabel: null },
  { id: "reddit", title: "Reddit", shortTitle: "Reddit", activityLabel: null }
];
const SITE_MAP = new Map(SITES.map((site) => [site.id, site]));
const SUPPORTED_SITE_IDS = SITES.filter((site) => site.id !== "all").map((site) => site.id);
let activeController = null;

function siteDefinition(siteID) {
  return SITE_MAP.get(siteID) || SITE_MAP.get("all");
}

function localDateKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function todayElapsedSeconds(now = new Date()) {
  const startOfToday = new Date(now);
  startOfToday.setHours(0, 0, 0, 0);
  return Math.max(Math.floor((now.getTime() - startOfToday.getTime()) / 1000), 0);
}

function formatDuration(seconds) {
  const total = Math.max(Math.floor(Number(seconds) || 0), 0);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (hours > 0) {
    return `${hours}h ${String(minutes).padStart(2, "0")}m`;
  }
  return `${minutes}m`;
}

function activityText(siteID, count, compact = false) {
  const total = Math.max(Math.floor(Number(count) || 0), 0);
  const label = siteDefinition(siteID).activityLabel;
  if (!label) {
    return "";
  }
  if (compact && label === "videos") {
    return `${total} vid${total === 1 ? "" : "s"}`;
  }
  return `${total} ${total === 1 ? label.replace(/s$/, "") : label}`;
}

function emptyUsage(siteID, previous = {}) {
  return {
    siteID,
    title: siteDefinition(siteID).title,
    date: localDateKey(),
    totalSeconds: 0,
    lifetimeSeconds: Math.max(Number(previous.lifetimeSeconds) || 0, 0),
    activityCount: 0,
    lifetimeActivityCount: Math.max(Number(previous.lifetimeActivityCount ?? previous.lifetimeVideoCount) || 0, 0),
    activityLabel: siteDefinition(siteID).activityLabel,
    lastUpdatedAt: null
  };
}

function normalizeUsage(siteID, value) {
  const today = localDateKey();
  if (!value || typeof value !== "object" || value.date !== today) {
    return emptyUsage(siteID, value || {});
  }
  return {
    siteID,
    title: siteDefinition(siteID).title,
    date: today,
    totalSeconds: Math.max(Number(value.totalSeconds) || 0, 0),
    lifetimeSeconds: Math.max(Number(value.lifetimeSeconds) || 0, 0),
    activityCount: Math.max(Number(value.activityCount ?? value.videoCount) || 0, 0),
    lifetimeActivityCount: Math.max(Number(value.lifetimeActivityCount ?? value.lifetimeVideoCount) || 0, 0),
    activityLabel: typeof value.activityLabel === "string" ? value.activityLabel : siteDefinition(siteID).activityLabel,
    lastUpdatedAt: typeof value.lastUpdatedAt === "string" ? value.lastUpdatedAt : null
  };
}

function browserDisplayName(browserID) {
  switch (browserID) {
    case "chrome":
      return "Chrome";
    case "edge":
      return "Edge";
    case "brave":
      return "Brave";
    case "arc":
      return "Arc";
    case "firefox":
      return "Firefox";
    default:
      return "Web";
  }
}

function normalizeProfile(profile) {
  if (!profile || typeof profile !== "object") {
    return null;
  }
  const id = typeof profile.id === "string" ? profile.id.trim() : "";
  const name = typeof profile.name === "string" ? profile.name.trim() : "";
  const label = typeof profile.label === "string" ? profile.label.trim() : "";
  if (!id && !name && !label) {
    return null;
  }
  return {
    id: id || "default",
    name: name || null,
    label: label || name || id || "Default"
  };
}

function localEntry(state, siteID, usage) {
  if (!state.browserID || !usage) {
    return null;
  }
  const profileID = state.browserProfile?.id || "default";
  const browserName = browserDisplayName(state.browserID);
  const profileLabel = state.browserProfile?.label || state.browserProfile?.name || profileID;
  return {
    id: `${siteID}:${state.browserID}:${profileID}`,
    siteID,
    siteTitle: siteDefinition(siteID).title,
    sourceType: "browser",
    sourceID: `${state.browserID}:${profileID}`,
    browserID: state.browserID,
    browserName,
    profileID,
    profileName: state.browserProfile?.name || null,
    label: [browserName, profileLabel].filter(Boolean).join(" - "),
    deviceName: browserName,
    date: usage.date,
    totalSeconds: Math.floor(usage.totalSeconds),
    lifetimeSeconds: Math.floor(usage.lifetimeSeconds),
    activityCount: Math.floor(usage.activityCount),
    lifetimeActivityCount: Math.floor(usage.lifetimeActivityCount),
    activityLabel: usage.activityLabel,
    lastUpdatedAt: usage.lastUpdatedAt
  };
}

function normalizeEntry(value, siteID) {
  if (!value || typeof value !== "object") {
    return null;
  }
  const usage = value.siteUsage && typeof value.siteUsage === "object" ? value.siteUsage : value;
  const entrySiteID = String(value.siteID || usage.siteID || siteID || "").toLowerCase();
  const definition = siteDefinition(entrySiteID);
  return {
    id: typeof value.id === "string" && value.id.trim()
      ? value.id.trim()
      : [entrySiteID, value.browserID, value.profileID].filter(Boolean).join(":"),
    siteID: entrySiteID,
    siteTitle: definition.title,
    sourceType: typeof value.sourceType === "string" ? value.sourceType : "browser",
    sourceID: typeof value.sourceID === "string" ? value.sourceID : null,
    browserID: typeof value.browserID === "string" ? value.browserID.trim() : "",
    browserName: typeof value.browserName === "string" ? value.browserName.trim() : "",
    profileID: typeof value.profileID === "string" ? value.profileID.trim() : "",
    profileName: typeof value.profileName === "string" ? value.profileName.trim() : "",
    label: typeof value.label === "string" ? value.label.trim() : "",
    deviceName: typeof value.deviceName === "string" ? value.deviceName.trim() : "",
    date: typeof usage.date === "string" ? usage.date : "",
    totalSeconds: Math.max(Math.floor(Number(usage.totalSeconds ?? value.totalSeconds) || 0), 0),
    lifetimeSeconds: Math.max(Math.floor(Number(usage.lifetimeSeconds ?? value.lifetimeSeconds) || 0), 0),
    activityCount: Math.max(Math.floor(Number(usage.activityCount ?? usage.videoCount ?? value.activityCount ?? value.videoCount) || 0), 0),
    lifetimeActivityCount: Math.max(Math.floor(Number(usage.lifetimeActivityCount ?? usage.lifetimeVideoCount ?? value.lifetimeActivityCount ?? value.lifetimeVideoCount) || 0), 0),
    activityLabel: typeof usage.activityLabel === "string" ? usage.activityLabel : definition.activityLabel,
    limitReached: Boolean(usage.limitReached || value.limitReached),
    lastUpdatedAt: typeof usage.lastUpdatedAt === "string"
      ? usage.lastUpdatedAt
      : (typeof value.lastUpdatedAt === "string" ? value.lastUpdatedAt : null)
  };
}

function siteFromSummary(summary, siteID) {
  if (!summary || typeof summary !== "object") {
    return null;
  }
  const today = localDateKey();
  if (Array.isArray(summary.sites)) {
    const site = summary.sites.find((candidate) => candidate?.siteID === siteID);
    if (!site || site.date !== today) {
      return null;
    }
    const entries = Array.isArray(site.entries)
      ? site.entries.map((entry) => normalizeEntry(entry, siteID)).filter((entry) => entry && entry.date === today)
      : [];
    return {
      siteID,
      title: siteDefinition(siteID).title,
      date: today,
      totalSeconds: Math.max(Math.floor(Number(site.totalSeconds) || 0), 0),
      lifetimeSeconds: Math.max(Math.floor(Number(site.lifetimeSeconds) || 0), 0),
      activityCount: Math.max(Math.floor(Number(site.activityCount ?? site.videoCount) || 0), 0),
      lifetimeActivityCount: Math.max(Math.floor(Number(site.lifetimeActivityCount ?? site.lifetimeVideoCount) || 0), 0),
      activityLabel: typeof site.activityLabel === "string" ? site.activityLabel : siteDefinition(siteID).activityLabel,
      entries
    };
  }
  return null;
}

function youtubeFromLegacySummary(summary) {
  if (!summary || typeof summary !== "object" || summary.date !== localDateKey()) {
    return null;
  }
  const entries = Array.isArray(summary.entries)
    ? summary.entries.map((entry) => normalizeEntry(entry, "youtube")).filter((entry) => entry && entry.date === summary.date)
    : [];
  return {
    siteID: "youtube",
    title: "YouTube",
    date: summary.date,
    totalSeconds: Math.max(Math.floor(Number(summary.totalSeconds) || 0), 0),
    lifetimeSeconds: Math.max(Math.floor(Number(summary.lifetimeSeconds) || 0), 0),
    activityCount: Math.max(Math.floor(Number(summary.videoCount) || 0), 0),
    lifetimeActivityCount: Math.max(Math.floor(Number(summary.lifetimeVideoCount) || 0), 0),
    activityLabel: "videos",
    entries
  };
}

function mergeLocalSite(state, site) {
  const siteID = site.siteID;
  const local = normalizeUsage(siteID, state.siteUsageBySite[siteID] || (siteID === state.siteID ? state.usage : null));
  const localSource = localEntry(state, siteID, local);
  if (!localSource || localSource.date !== site.date) {
    return site;
  }
  const existing = site.entries.find((entry) => entry.id === localSource.id);
  const entries = [
    localSource,
    ...site.entries.filter((entry) => entry.id !== localSource.id)
  ].sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
  return {
    ...site,
    totalSeconds: Math.max(site.totalSeconds - (existing?.totalSeconds || 0) + localSource.totalSeconds, 0),
    lifetimeSeconds: Math.max(site.lifetimeSeconds - (existing?.lifetimeSeconds || 0) + localSource.lifetimeSeconds, 0),
    activityCount: Math.max(site.activityCount - (existing?.activityCount || 0) + localSource.activityCount, 0),
    lifetimeActivityCount: Math.max(site.lifetimeActivityCount - (existing?.lifetimeActivityCount || 0) + localSource.lifetimeActivityCount, 0),
    entries
  };
}

function siteSnapshot(state, siteID) {
  const today = localDateKey();
  const fromNative = siteFromSummary(state.siteUsageSummary, siteID)
    || (siteID === "youtube" ? youtubeFromLegacySummary(state.youtubeUsageSummary) : null);
  if (fromNative) {
    return mergeLocalSite(state, fromNative);
  }
  const usage = normalizeUsage(siteID, state.siteUsageBySite[siteID] || (siteID === state.siteID ? state.usage : null));
  const entry = localEntry(state, siteID, usage);
  return {
    siteID,
    title: siteDefinition(siteID).title,
    date: today,
    totalSeconds: Math.floor(usage.totalSeconds),
    lifetimeSeconds: Math.floor(usage.lifetimeSeconds),
    activityCount: Math.floor(usage.activityCount),
    lifetimeActivityCount: Math.floor(usage.lifetimeActivityCount),
    activityLabel: usage.activityLabel,
    entries: entry ? [entry] : []
  };
}

function allSnapshot(state) {
  const sites = SUPPORTED_SITE_IDS.map((siteID) => siteSnapshot(state, siteID));
  return {
    siteID: "all",
    title: "All",
    date: localDateKey(),
    totalSeconds: sites.reduce((sum, site) => sum + site.totalSeconds, 0),
    lifetimeSeconds: sites.reduce((sum, site) => sum + site.lifetimeSeconds, 0),
    activityCount: sites.reduce((sum, site) => sum + site.activityCount, 0),
    lifetimeActivityCount: sites.reduce((sum, site) => sum + site.lifetimeActivityCount, 0),
    activityLabel: null,
    entries: sites.flatMap((site) => site.entries),
    sites
  };
}

function selectedSnapshot(state) {
  return state.selectedSiteID === "all" ? allSnapshot(state) : siteSnapshot(state, state.selectedSiteID);
}

function extractedEmail(value) {
  const text = typeof value === "string" ? value : "";
  const match = text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
  return match ? match[0].toLowerCase() : null;
}

function strippedProfileName(value, email = null) {
  let name = typeof value === "string" ? value.trim() : "";
  if (!name) {
    return "";
  }
  name = name.replace(/^(Chrome|Firefox|Edge|Brave|Arc|Web)\s*-\s*/i, "").trim();
  if (email) {
    name = name.replace(new RegExp(email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i"), "");
  }
  return name.replace(/\([^)]*\)/g, "").replace(/[,-]\s*$/g, "").replace(/\s{2,}/g, " ").trim();
}

function usageEntryLooksLikeIOS(entry) {
  const text = [
    entry?.sourceType,
    entry?.browserID,
    entry?.browserName,
    entry?.profileID,
    entry?.profileName,
    entry?.label,
    entry?.deviceName,
    entry?.id
  ].filter(Boolean).join(" ").toLowerCase();
  return /\bios\b|iphone|ipad/.test(text);
}

function summedUsage(entries) {
  return entries.reduce((usage, entry) => ({
    totalSeconds: usage.totalSeconds + Math.max(Math.floor(Number(entry.totalSeconds) || 0), 0),
    lifetimeSeconds: usage.lifetimeSeconds + Math.max(Math.floor(Number(entry.lifetimeSeconds) || 0), 0),
    activityCount: usage.activityCount + Math.max(Math.floor(Number(entry.activityCount) || 0), 0)
  }), { totalSeconds: 0, lifetimeSeconds: 0, activityCount: 0 });
}

function browserProfileSummary(entries) {
  const browsers = new Set();
  const profiles = new Set();
  for (const entry of entries) {
    const browserName = entry.browserName || browserDisplayName(entry.browserID);
    browsers.add(browserName);
    if (entry.profileID) {
      profiles.add(`${browserName}:${entry.profileID}`);
    }
  }
  const browserText = Array.from(browsers).join(", ") || "Web browser";
  return profiles.size > 1 ? `${browserText} - ${profiles.size} profiles` : browserText;
}

function deviceRows(snapshot) {
  const iosEntries = snapshot.entries.filter(usageEntryLooksLikeIOS);
  const browserEntries = snapshot.entries.filter((entry) => !usageEntryLooksLikeIOS(entry));
  return [
    {
      id: "web",
      title: "Web browser",
      meta: browserEntries.length ? browserProfileSummary(browserEntries) : "No browser data yet",
      connected: browserEntries.length > 0,
      iconLabel: "WEB",
      ...summedUsage(browserEntries)
    },
    {
      id: "ios",
      title: "iOS",
      meta: iosEntries.length ? "Connected" : "Not connected",
      connected: iosEntries.length > 0,
      iconLabel: "iOS",
      ...summedUsage(iosEntries)
    }
  ];
}

function accountGroups(entries) {
  const groups = new Map();
  for (const entry of entries.filter((candidate) => !usageEntryLooksLikeIOS(candidate))) {
    const key = extractedEmail(entry.label) ||
      extractedEmail(entry.profileName) ||
      [entry.browserID, entry.profileID || entry.label].filter(Boolean).join(":") ||
      "web";
    const email = extractedEmail(entry.label) || extractedEmail(entry.profileName);
    const title = strippedProfileName(entry.profileName, email) ||
      strippedProfileName(entry.label, email) ||
      email ||
      "Web browser";
    const existingGroup = groups.get(key);
    if (!existingGroup) {
      groups.set(key, {
        id: key,
        title,
        email,
        totalSeconds: entry.totalSeconds,
        lifetimeSeconds: entry.lifetimeSeconds,
        activityCount: entry.activityCount,
        entries: [entry]
      });
      continue;
    }
    existingGroup.totalSeconds += entry.totalSeconds;
    existingGroup.lifetimeSeconds += entry.lifetimeSeconds;
    existingGroup.activityCount += entry.activityCount;
    existingGroup.entries.push(entry);
  }
  return Array.from(groups.values())
    .map((group) => ({ ...group, meta: browserProfileSummary(group.entries) }))
    .sort((lhs, rhs) => rhs.totalSeconds - lhs.totalSeconds);
}

function initials(group) {
  const source = group.title || group.email || "T";
  const parts = source.replace(/@.*/, "").split(/[\s._-]+/).filter(Boolean);
  return parts.slice(0, 2).map((part) => part[0]).join("").toUpperCase() || "T";
}

function installStyles() {
  if (document.getElementById("tortoise-site-usage-style")) {
    return;
  }
  const style = document.createElement("style");
  style.id = "tortoise-site-usage-style";
  style.textContent = `
    #tortoise-site-usage {
      position: fixed !important;
      right: 16px !important;
      bottom: 16px !important;
      z-index: 2147483646 !important;
      display: grid !important;
      gap: 9px !important;
      width: max-content !important;
      max-width: min(430px, calc(100vw - 32px)) !important;
      padding: 9px !important;
      border: 1px solid rgba(255, 255, 255, 0.2) !important;
      border-radius: 22px !important;
      background: linear-gradient(180deg, rgba(31, 34, 39, 0.97), rgba(12, 14, 18, 0.96)) !important;
      -webkit-backdrop-filter: blur(18px) saturate(1.15) !important;
      backdrop-filter: blur(18px) saturate(1.15) !important;
      color: #fff !important;
      box-shadow: 0 20px 52px rgba(0, 0, 0, 0.34), inset 0 1px 0 rgba(255, 255, 255, 0.08) !important;
      font: 600 12px/1.35 -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif !important;
      letter-spacing: 0 !important;
      pointer-events: auto !important;
      cursor: default !important;
      outline: none !important;
    }
    #tortoise-site-usage .tg-summary { padding: 0 5px !important; white-space: nowrap !important; font-size: 12px !important; font-weight: 800 !important; }
    #tortoise-site-usage .tg-detail {
      display: none !important;
      min-width: min(365px, calc(100vw - 50px)) !important;
      max-height: min(640px, calc(100vh - 116px)) !important;
      overflow-y: auto !important;
      gap: 10px !important;
    }
    #tortoise-site-usage:hover .tg-detail,
    #tortoise-site-usage:focus-within .tg-detail,
    #tortoise-site-usage.tg-expanded .tg-detail { display: grid !important; }
    #tortoise-site-usage .tg-tabs { display: flex !important; gap: 5px !important; overflow-x: auto !important; padding: 1px !important; }
    #tortoise-site-usage .tg-tab {
      border: 0 !important;
      border-radius: 999px !important;
      padding: 6px 9px !important;
      background: rgba(255,255,255,0.08) !important;
      color: rgba(255,255,255,0.62) !important;
      font: 800 11px/1 -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif !important;
      white-space: nowrap !important;
    }
    #tortoise-site-usage .tg-tab[aria-selected="true"] { background: rgba(255,255,255,0.18) !important; color: #fff !important; }
    #tortoise-site-usage .tg-hero {
      display: grid !important;
      grid-template-columns: minmax(0, 1fr) auto !important;
      align-items: start !important;
      gap: 12px !important;
      padding: 14px !important;
      border-radius: 16px !important;
      background: rgba(255,255,255,0.08) !important;
      box-shadow: inset 0 1px 0 rgba(255,255,255,0.08) !important;
    }
    #tortoise-site-usage .tg-copy { display: grid !important; gap: 2px !important; min-width: 0 !important; }
    #tortoise-site-usage .tg-kicker { color: rgba(255,255,255,0.58) !important; font-size: 10px !important; font-weight: 800 !important; text-transform: uppercase !important; }
    #tortoise-site-usage .tg-total { color: #fff !important; font-size: 30px !important; font-weight: 850 !important; line-height: 1.05 !important; }
    #tortoise-site-usage .tg-muted { color: rgba(255,255,255,0.58) !important; font-size: 11px !important; font-weight: 650 !important; }
    #tortoise-site-usage .tg-pill {
      display: inline-flex !important;
      align-items: center !important;
      gap: 6px !important;
      width: fit-content !important;
      border-radius: 999px !important;
      padding: 6px 9px !important;
      background: rgba(255,255,255,0.12) !important;
      color: rgba(255,255,255,0.82) !important;
      font-size: 11px !important;
      font-weight: 800 !important;
      white-space: nowrap !important;
    }
    #tortoise-site-usage .tg-section { padding: 0 5px !important; color: rgba(255,255,255,0.48) !important; font-size: 10px !important; font-weight: 850 !important; text-transform: uppercase !important; }
    #tortoise-site-usage .tg-list { display: grid !important; gap: 7px !important; }
    #tortoise-site-usage .tg-row {
      display: grid !important;
      grid-template-columns: 34px minmax(0, 1fr) auto !important;
      gap: 9px !important;
      align-items: center !important;
      min-height: 44px !important;
      padding: 6px 7px !important;
      border-radius: 13px !important;
      background: rgba(255,255,255,0.055) !important;
    }
    #tortoise-site-usage .tg-avatar { display: grid !important; place-items: center !important; width: 34px !important; height: 34px !important; border-radius: 50% !important; background: rgba(255,255,255,0.14) !important; color: rgba(255,255,255,0.92) !important; font-size: 11px !important; font-weight: 850 !important; }
    #tortoise-site-usage .tg-ios { border-radius: 10px !important; }
    #tortoise-site-usage .tg-row-copy { display: grid !important; gap: 1px !important; min-width: 0 !important; }
    #tortoise-site-usage .tg-title, #tortoise-site-usage .tg-subtitle { min-width: 0 !important; overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important; }
    #tortoise-site-usage .tg-title { color: rgba(255,255,255,0.9) !important; font-size: 12px !important; font-weight: 700 !important; }
    #tortoise-site-usage .tg-subtitle { color: rgba(255,255,255,0.52) !important; font-size: 11px !important; font-weight: 550 !important; }
    #tortoise-site-usage .tg-value { color: rgba(255,255,255,0.76) !important; font-size: 11px !important; font-weight: 800 !important; white-space: nowrap !important; }
    #tortoise-site-usage .tg-muted-row { opacity: 0.52 !important; }
  `;
  document.documentElement.appendChild(style);
}

function ensureOverlay(state) {
  if (!document.body) {
    return null;
  }
  installStyles();
  let overlay = document.getElementById("tortoise-site-usage");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "tortoise-site-usage";
    overlay.setAttribute("role", "button");
    overlay.setAttribute("aria-live", "polite");
    overlay.setAttribute("aria-expanded", "false");
    overlay.tabIndex = 0;
    overlay.addEventListener("click", (event) => {
      if (event.target.closest(".tg-tab")) {
        return;
      }
      const expanded = !overlay.classList.contains("tg-expanded");
      overlay.classList.toggle("tg-expanded", expanded);
      overlay.setAttribute("aria-expanded", expanded ? "true" : "false");
    });
    overlay.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        overlay.classList.remove("tg-expanded");
        overlay.setAttribute("aria-expanded", "false");
      }
    });
    overlay.appendChild(document.createElement("div")).className = "tg-summary";
    overlay.appendChild(document.createElement("div")).className = "tg-detail";
    document.body.appendChild(overlay);
  }
  return overlay;
}

function rowValue(siteID, seconds, activityCount, connected = true) {
  if (!connected) {
    return "No data";
  }
  const activity = siteID === "all" ? "" : activityText(siteID, activityCount, true);
  return [formatDuration(seconds), activity].filter(Boolean).join(" - ");
}

function summaryText(snapshot) {
  const activity = snapshot.siteID === "all" ? "" : activityText(snapshot.siteID, snapshot.activityCount);
  return [`Today ${formatDuration(snapshot.totalSeconds)}`, activity].filter(Boolean).join(" - ");
}

function render(state) {
  const overlay = ensureOverlay(state);
  if (!overlay) {
    return;
  }
  const snapshot = selectedSnapshot(state);
  overlay.querySelector(".tg-summary").textContent = summaryText(siteSnapshot(state, state.siteID));
  overlay.setAttribute("aria-label", summaryText(snapshot));

  const detail = overlay.querySelector(".tg-detail");
  detail.replaceChildren();

  const tabs = document.createElement("div");
  tabs.className = "tg-tabs";
  tabs.setAttribute("role", "tablist");
  for (const site of SITES) {
    const tab = document.createElement("button");
    tab.type = "button";
    tab.className = "tg-tab";
    tab.setAttribute("role", "tab");
    tab.setAttribute("aria-selected", state.selectedSiteID === site.id ? "true" : "false");
    tab.textContent = site.shortTitle;
    tab.addEventListener("click", (event) => {
      event.stopPropagation();
      state.selectedSiteID = site.id;
      render(state);
    });
    tabs.appendChild(tab);
  }
  detail.appendChild(tabs);

  const hero = document.createElement("div");
  hero.className = "tg-hero";
  const copy = document.createElement("div");
  copy.className = "tg-copy";
  const kicker = document.createElement("div");
  kicker.className = "tg-kicker";
  kicker.textContent = "Tortoise";
  const total = document.createElement("div");
  total.className = "tg-total";
  total.textContent = formatDuration(snapshot.totalSeconds);
  const windowText = document.createElement("div");
  windowText.className = "tg-muted";
  windowText.textContent = `Today so far - ${formatDuration(todayElapsedSeconds())} since 12:00 AM`;
  const meta = document.createElement("div");
  meta.className = "tg-muted";
  const activity = snapshot.siteID === "all" ? "" : activityText(snapshot.siteID, snapshot.activityCount);
  meta.textContent = activity || (snapshot.siteID === "all" ? "Across supported apps" : `${snapshot.title} active time`);
  copy.append(kicker, total, windowText, meta);

  const rail = document.createElement("div");
  rail.style.display = "grid";
  rail.style.justifyItems = "end";
  rail.style.gap = "8px";
  const source = document.createElement("div");
  source.className = "tg-pill";
  source.textContent = snapshot.title;
  const count = document.createElement("div");
  count.className = "tg-pill";
  const accounts = accountGroups(snapshot.entries);
  count.textContent = `${accounts.length} ${accounts.length === 1 ? "account" : "accounts"}`;
  rail.append(source, count);
  hero.append(copy, rail);
  detail.appendChild(hero);

  const devicesTitle = document.createElement("div");
  devicesTitle.className = "tg-section";
  devicesTitle.textContent = "Devices";
  detail.appendChild(devicesTitle);

  const devices = document.createElement("div");
  devices.className = "tg-list";
  for (const device of deviceRows(snapshot)) {
    const row = document.createElement("div");
    row.className = `tg-row${device.connected ? "" : " tg-muted-row"}`;
    const avatar = document.createElement("span");
    avatar.className = `tg-avatar${device.id === "ios" ? " tg-ios" : ""}`;
    avatar.textContent = device.iconLabel;
    const copyNode = document.createElement("span");
    copyNode.className = "tg-row-copy";
    const title = document.createElement("span");
    title.className = "tg-title";
    title.textContent = device.title;
    const subtitle = document.createElement("span");
    subtitle.className = "tg-subtitle";
    subtitle.textContent = device.meta;
    copyNode.append(title, subtitle);
    const value = document.createElement("span");
    value.className = "tg-value";
    value.textContent = rowValue(snapshot.siteID, device.totalSeconds, device.activityCount, device.connected);
    row.append(avatar, copyNode, value);
    devices.appendChild(row);
  }
  detail.appendChild(devices);

  const accountsTitle = document.createElement("div");
  accountsTitle.className = "tg-section";
  accountsTitle.textContent = "Accounts";
  detail.appendChild(accountsTitle);

  const list = document.createElement("div");
  list.className = "tg-list";
  const groups = accounts.length ? accounts : [{
    title: "Web browser",
    email: null,
    meta: "No account data yet",
    totalSeconds: 0,
    activityCount: 0
  }];
  for (const group of groups.slice(0, 8)) {
    const row = document.createElement("div");
    row.className = `tg-row${accounts.length ? "" : " tg-muted-row"}`;
    const avatar = document.createElement("span");
    avatar.className = "tg-avatar";
    avatar.textContent = initials(group);
    const copyNode = document.createElement("span");
    copyNode.className = "tg-row-copy";
    const title = document.createElement("span");
    title.className = "tg-title";
    title.textContent = group.title;
    const subtitle = document.createElement("span");
    subtitle.className = "tg-subtitle";
    subtitle.textContent = [group.email, group.meta].filter(Boolean).join(" - ");
    copyNode.append(title, subtitle);
    const value = document.createElement("span");
    value.className = "tg-value";
    value.textContent = accounts.length ? rowValue(snapshot.siteID, group.totalSeconds, group.activityCount, true) : "No data";
    row.append(avatar, copyNode, value);
    list.appendChild(row);
  }
  detail.appendChild(list);
}

async function persist(state, reason) {
  state.usage = normalizeUsage(state.siteID, state.usage);
  state.usage.lastUpdatedAt = new Date().toISOString();
  try {
    const stored = await quietGateBrowser.storage.local.get({ siteUsageBySite: {} });
    const siteUsageBySite = {
      ...(stored.siteUsageBySite && typeof stored.siteUsageBySite === "object" ? stored.siteUsageBySite : {}),
      [state.siteID]: state.usage
    };
    state.siteUsageBySite = siteUsageBySite;
    await quietGateBrowser.storage.local.set({ siteUsageBySite });
  } catch (_error) {
    // Best-effort local usage persistence.
  }
  try {
    await quietGateBrowser.runtime.sendMessage({
      type: "quietgate.siteUsageChanged",
      siteID: state.siteID,
      reason
    });
  } catch (_error) {
    // The local overlay still works if the service worker is asleep.
  }
}

function shouldTrack() {
  return document.visibilityState === "visible" && (!document.hasFocus || document.hasFocus());
}

function scheduleTick(state) {
  if (state.timer !== null) {
    return;
  }
  state.lastTick = performance.now();
  state.timer = window.setTimeout(() => tick(state), 1000);
}

function tick(state) {
  state.timer = null;
  const now = performance.now();
  const elapsedSeconds = state.lastTick === null ? 0 : Math.min(Math.max((now - state.lastTick) / 1000, 0), 10);
  state.lastTick = now;
  if (shouldTrack() && elapsedSeconds > 0) {
    state.usage.totalSeconds += elapsedSeconds;
    state.usage.lifetimeSeconds += elapsedSeconds;
    render(state);
    if (now - state.lastReportAt >= 10000) {
      state.lastReportAt = now;
      persist(state, "tick");
    }
  }
  state.timer = window.setTimeout(() => tick(state), 1000);
}

async function loadState(state) {
  const stored = await quietGateBrowser.storage.local.get({
    siteUsageBySite: {},
    siteUsageSummary: null,
    youtubeUsageSummary: null,
    browserID: null,
    browserProfile: null
  });
  state.siteUsageBySite = stored.siteUsageBySite && typeof stored.siteUsageBySite === "object" ? stored.siteUsageBySite : {};
  state.siteUsageSummary = stored.siteUsageSummary || null;
  state.youtubeUsageSummary = stored.youtubeUsageSummary || null;
  state.browserID = typeof stored.browserID === "string" ? stored.browserID.trim().toLowerCase() : null;
  state.browserProfile = normalizeProfile(stored.browserProfile);
  state.usage = normalizeUsage(state.siteID, state.siteUsageBySite[state.siteID]);
  render(state);
  scheduleTick(state);
}

function handleStorageChange(state, changes, areaName) {
  if (areaName !== "local") {
    return;
  }
  if (changes.siteUsageBySite) {
    state.siteUsageBySite = changes.siteUsageBySite.newValue && typeof changes.siteUsageBySite.newValue === "object"
      ? changes.siteUsageBySite.newValue
      : {};
    state.usage = normalizeUsage(state.siteID, state.siteUsageBySite[state.siteID]);
  }
  if (changes.siteUsageSummary) {
    state.siteUsageSummary = changes.siteUsageSummary.newValue || null;
  }
  if (changes.youtubeUsageSummary) {
    state.youtubeUsageSummary = changes.youtubeUsageSummary.newValue || null;
  }
  if (changes.browserID) {
    state.browserID = typeof changes.browserID.newValue === "string" ? changes.browserID.newValue.trim().toLowerCase() : null;
  }
  if (changes.browserProfile) {
    state.browserProfile = normalizeProfile(changes.browserProfile.newValue);
  }
  render(state);
}

function initSiteUsageTracker(config = {}) {
  const siteID = String(config.siteID || "").toLowerCase();
  if (!SUPPORTED_SITE_IDS.includes(siteID)) {
    return null;
  }
  activeController?.dispose?.();
  const state = {
    siteID,
    selectedSiteID: siteID,
    usage: emptyUsage(siteID),
    siteUsageBySite: {},
    siteUsageSummary: null,
    youtubeUsageSummary: null,
    browserID: null,
    browserProfile: null,
    timer: null,
    lastTick: null,
    lastReportAt: 0
  };
  const storageListener = (changes, areaName) => handleStorageChange(state, changes, areaName);
  const visibilityListener = () => {
    if (document.visibilityState === "hidden") {
      persist(state, "hidden");
    }
    render(state);
  };
  const pageHideListener = () => persist(state, "pagehide");
  quietGateBrowser.storage.onChanged.addListener(storageListener);
  window.addEventListener("visibilitychange", visibilityListener);
  window.addEventListener("pagehide", pageHideListener);
  loadState(state);
  activeController = {
    refresh: () => loadState(state),
    dispose() {
      if (state.timer !== null) {
        window.clearTimeout(state.timer);
      }
      state.timer = null;
      quietGateBrowser.storage.onChanged.removeListener?.(storageListener);
      window.removeEventListener("visibilitychange", visibilityListener);
      window.removeEventListener("pagehide", pageHideListener);
      document.getElementById("tortoise-site-usage")?.remove();
      if (activeController === this) {
        activeController = null;
      }
    }
  };
  return activeController;
}

window.__tortoiseSiteUsage = {
  version: VERSION,
  initSiteUsageTracker
};
})();
