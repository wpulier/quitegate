# Connect + Tune — Unified UX Design

**Date:** 2026-07-03
**Status:** Approved design, ready for implementation planning
**Scope:** The Mac app (`QuietGate/`) and the iOS app (`Tortoise/`). Web (`my-clerk-app/`) and the browser/Safari extensions are supporting surfaces, changed only where they serve these two apps.

## 1. Goal

Two verbs, almost no words, usable by everyone from a non-technical parent to a developer:

- **Add devices / profiles** — a "Devices" hub.
- **Tune your digital life** — a "Tune" surface.

The same on Mac and iPhone, both riding **one cloud account as the single source of truth**. Everything shown must be **real and honest** — no placeholder/demo content mixed with working controls, and "connected" means actually enforcing.

## 2. Principles

1. **One account, one truth.** The Supabase `TortoisePolicy` (via `/api/policy`) is authoritative. Local state is a cache, never a competing source.
2. **Say only what's true.** A thing is "On" only when it is reachable and actually enforcing. Saved ≠ active. (Preserves the README Product Contract.)
3. **Minimal words.** Icon + name + one-word state. Detail appears only when asked for.
4. **Same model everywhere.** Mac and iOS render the *same* data model and the *same* concepts; only the native chrome differs.
5. **Nothing fake ships.** If a control can't enforce on a surface, it is hidden there or clearly labeled — never a dead toggle.

## 3. Information architecture

The app is **two places**, identical on Mac and iPhone:

| Place | Verb | Contents |
|---|---|---|
| **Devices** | Add devices / profiles | Account, connected things (each one honest state), one **Add** button. |
| **Tune** | Tune your digital life | One mode (Open / Focus / Strict) + areas (sites, adult sites, apps, websites, sessions), each with detail-on-demand. |

Name is **Tortoise** everywhere (finish the QuietGate → Tortoise rename in identifiers and user-facing strings).

## 4. The canonical model (the shared spine)

This is the heart of the cleanup. Today the same ideas are modeled 5–7 times and drift. Collapse to one definition each, placed in the **shared Swift files that already compile into both targets** (`Tortoise/TortoiseModels.swift` and siblings, per `project.yml`).

### 4.1 One connection status

Replace the 7+ status enums (`ConnectionState`, `BrowserConnectorState`, `ChromeHelperState`, `MacAccountSessionState`, `MacPolicySyncState`, `IOSEnforcementConnectionState`, `IOSSafariExtensionState`) and the 4 different freshness clocks with a single model:

```
enum ConnectionStatus {
  case on                    // reachable within the freshness window AND enforcing latest policy
  case attention(Reason)     // one concrete step left (e.g. signIn, enableExtension, grantScreenTime)
  case off                   // paused by the user
}
```

- **One freshness constant** (single source, e.g. `heartbeatFreshWindow`) used by every surface. A device past the window is `attention(.stale)`, not silently "On."
- Each connected entity (device or browser profile) resolves to exactly one `ConnectionStatus`. The hub renders the dot + at most one word from it.

### 4.2 One site/feature catalog

Replace `DesignTuningSite` (Mac UI), `MobileTuningSite` (iOS UI), the near-dead `BrowserTuningSite`, and the ad hoc `SafariExtensionPolicy` maps with **one catalog** in shared code, keyed to `BrowserTuningFeature`. Reconcile the 39-vs-41 gap: `TortoisePolicy.browserFeatureKeys` must contain **every** feature (add `instagramProfileSuggestions`, `instagramMessages`, `instagramNotifications`), so no feature can fall through the local-only fallback branch.

Each catalog entry declares:
- site, title, `brandAssetName` (real brand icon), the granular features it owns
- **per-surface enforceability**: which features each surface (Chrome/Firefox extension, iOS Safari web extension, iOS Screen Time) can actually apply.

### 4.3 Modes derive from the catalog

Open / Focus / Strict presets are computed from the single catalog, so "Focus" means the **same set of features on Mac and iOS** (kills today's four divergent "focus" definitions). Per-feature overrides layer on top and sync through the policy.

## 5. Devices — "Add devices / profiles"

### 5.1 The hub
Account (avatar + name) → a list, one row per connected thing: brand/device icon · name · one `ConnectionStatus` dot (green On / amber Attention+word / grey Off) → one **Add** button. Browser **profiles nest under their browser** (e.g. "Chrome · 2 profiles") — no top-level double-counting.

### 5.2 Add flow (account-based, zero codes)
`Add` → pick **Phone / Computer / Browser** → show a QR + link → **sign in on the new one with the same account → it appears in the hub as On.** No pairing codes, no "check setup" button.

- **Browser** (the fiddly one) collapses to effectively one move: open `tortoise.com/add` in that browser (scan or tap) → one click **"Add to [browser]"** installs the extension and links it to the already-signed-in web session in the same click. Then it flips to On, carrying current tuning.
- **Phone / Computer:** install the app, sign in, appears.

### 5.3 Consequences
- Delete the dead iOS "Connect another device" button (`Tortoise/ContentView.swift:888`) and replace with this Add flow.
- The Mac "Add iPhone (iOS)" / "Expand to another device" buttons (`TuningView.swift`, `ControlView.swift`) route into this real Add flow, not the browser connector.
- **Pick ONE browser-connect transport.** Keep the account/web token exchange (`/api/extension/exchange`), retire the parallel native-messaging "tuner session" as the connect path (native messaging may remain an internal detail but is not a second notion of "connected").

## 6. Tune — "Tune your digital life"

### 6.1 Top level
One mode selector **Open / Focus / Strict**, then areas as simple switches / drill-ins:
- Sites: **YouTube, X, Instagram, Reddit, TikTok** (each: quick on/off + tap for granular)
- **Adult sites** (on/off)
- **Apps** (drill in — real installed apps, no hardcoded Slack/Discord/Steam list)
- **Websites** (drill in — real blocked list, no fake espn/cnn defaults)
- **Start a session** (timed / locked Focus or Strict — real on **both** platforms)

### 6.2 Detail on demand
Tap a site → its granular feature toggles (e.g. YouTube: Shorts, Home feed, Recommendations, Comments, Autoplay, Daily limit). Every toggle writes to the cloud policy and reads back from it.

### 6.3 Honesty in tuning
- A toggle is only shown/active on a surface that can enforce it (from §4.2 enforceability). iOS must **honor per-feature toggles** for Safari (today it applies only the mode preset) — or, where a feature genuinely can't be enforced on a surface, it is not shown as an active control there.
- Wire the currently-unwired "augment" knobs on **Mac**: explicit-hide style and YouTube daily limit (`setExplicitHideStyle`, `setYouTubeDailyLimitMinutes` exist with no UI). Daily-limit label reflects the real value (fix the hardcoded "45m" vs real default).
- **TikTok gets a real tuner** (new `tiktok` content script across Chrome/Firefox/Safari targets + policy features), replacing the current local-`@State` stub in both apps.

## 7. Cross-device behavior

- All edits go to the one `TortoisePolicy` document with optimistic concurrency (`expectedSettingsVersion`); on conflict, refresh and re-apply (existing pattern in `MacAccountStore.updatePolicy`).
- Each surface maps the shared policy to its own enforcement: browser extensions (content scripts), iOS Safari web extension (app group), iOS Screen Time / DeviceActivity (native apps + daily limit).
- Delete the local-only Mac write branch so a Mac edit always reaches the account and every other device.

## 8. Cleanup / deletions (part of this work)

- **`QuietGate/LegacyProviderConnector/`** (~1,660 lines, force-disabled) — delete, plus the ~40 `ProtectionStore` branches guarding it and the now-unused `KeychainStore`.
- **Vestigial `ConnectionState`** (`QuietGate/Models/ConnectionState.swift`) — delete, superseded by `ConnectionStatus`.
- **All fake/demo content** — hardcoded distracting-apps list, dead Gambling/News concept rows, fake blocked-site defaults, fake iOS "concept blocking", fake iOS session timers.
- **Duplicate device classification** — one shared implementation, remove the Mac/iOS copies.
- **Two API clients** — converge `MacTortoiseAPIClient` and `TortoiseAPIClient` on one shared client where practical.
- **Finish the rename** to Tortoise (bundle IDs may stay for continuity; user-facing strings and new identifiers standardize on Tortoise).

## 9. Build strategy

**Approach A — unify in place.** Keep the existing polished SwiftUI components and cloud API. Introduce the single `ConnectionStatus` + single catalog in shared files; collapse each app to **Devices + Tune**; rewire everything to the cloud policy; delete dead/fake code. Mac and iOS keep thin native views that render one shared data model (≈90% of the anti-drift benefit of a shared UI layer, a fraction of the cost).

### 9.1 Implementation phasing

This design is one coherent spec but too large for a single plan. Suggested decomposition (each its own plan):

1. **Canonical spine** — `ConnectionStatus`, single site/feature catalog, reconcile `browserFeatureKeys`, make cloud policy the only writer (delete the local-only Mac branch). Foundation; nothing user-facing yet.
2. **Devices** — hub + Add flow on both apps; delete the dead "Connect another device" button; converge on one browser-connect transport.
3. **Tune** — mode + areas + detail-on-demand on both apps; per-feature enforcement honesty; wire Mac augment knobs.
4. **TikTok tuner** — new content scripts + policy features across the three extension targets.
5. **Cleanup + rename** — delete `LegacyProviderConnector`/`KeychainStore`/vestigial `ConnectionState`/fake demo content; finish Tortoise rename.

## 10. Visual direction

Refined, monochrome, premium — thin line icons + **real brand marks**, light font weights, one calm accent, generous whitespace, minimal text. (Validated via mockups: `devices-hub-v2`, `hub-v3`, `tune-v1`.)

## 11. Success criteria

- On a fresh account, a non-technical user can connect a phone, a Mac, and a browser without typing a code, and see each turn **On**.
- The same account shows the **same devices, same tuning, same mode** on Mac and iPhone within one refresh.
- Every control on screen is real: toggling it changes enforcement on at least one connected surface, or it isn't shown there.
- "On" is never displayed for a device that isn't actually enforcing the latest policy.
- No `LegacyProviderConnector`, no fake demo data, one browser-connect path, one name.

## 12. Risks / open questions

- **iOS per-feature Safari enforcement**: confirm the Safari web extension can apply arbitrary per-feature toggles (not just mode presets); if some features are infeasible, they're marked non-enforceable in the catalog and hidden on iOS.
- **TikTok tuner** adds real scope (new content scripts + testing across three extension targets).
- **Browser one-click connect** depends on the extension detecting the signed-in web session at install; validate the store-install → account-link handoff.
- **Rename** touches many strings/identifiers; sequence to avoid breaking native-messaging host IDs already deployed.
