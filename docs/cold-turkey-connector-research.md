# Cold Turkey Connector Research

Research date: 2026-05-27

This is based on public Cold Turkey documentation and current QuietGate source.
It is not reverse engineering.

## Public Cold Turkey Pattern

Cold Turkey presents itself as a desktop website and app blocker for Windows and
macOS. The public setup path is:

1. Install the desktop app.
2. Install browser extensions for detected browsers.
3. Start and optionally lock a block.

Sources:

- Product setup and positioning: https://getcoldturkey.com/
- Features: https://getcoldturkey.com/features/
- User guide: https://getcoldturkey.com/support/user-guide/
- System requirements and supported browsers:
  https://getcoldturkey.com/support/system-requirements/
- Chrome extension setup:
  https://getcoldturkey.com/support/extensions/chrome/?reason=incognito
- Firefox extension setup:
  https://getcoldturkey.com/support/extensions/firefox/
- Safari permission setup:
  https://getcoldturkey.com/support/extensions/mac/safari/full-disk-access/

Key product lessons:

- Browser coverage is treated as a first-class connector surface.
- Setup is explicit per browser, profile, and permission.
- Failure states are concrete: extension missing, private browsing permission
  missing, site access missing, Safari permission missing.
- Locks defend against bypass paths: disabling extensions, uninstalling, changing
  time, Activity Monitor, browser internal pages, and installer reruns.
- Statistics are local and used to help users decide what to block.

## QuietGate Current Stack

QuietGate currently has:

- macOS SwiftUI app, Swift 5, macOS 14 target:
  `project.yml`
- Chrome MV3 helper with DNR, native messaging, and YouTube content scripts:
  `ChromeExtension/manifest.json`
- Native messaging host for Chrome:
  `NativeHost/QuietGateNativeHost.swift`
- Chrome profile/status detection:
  `QuietGate/Services/BrowserExtensionBridge.swift`
- Apps page with installed-app scanning, local launch detection, and app closing:
  `QuietGate/Stores/AppBlockingStore.swift`
- Legacy NextDNS API and Apple DNS profile support:
  `QuietGate/Stores/ProtectionStore.swift` and
  `QuietGate/Services/MacConfigurationProfileService.swift`

Current gap:

QuietGate has working browser helpers for Chrome, Edge, Brave, Arc, and Firefox
plus legacy provider plumbing. It does not yet have the full connector breadth Cold Turkey
uses for Safari, stronger app blocking, browser-profile setup, bypass
defense, or usage visibility. The new MVP direction is to remove DNS-account
onboarding from the normal user path and make browser helpers the first-class
connector surface.

## Connector Roadmap

### 1. Browser Connector Framework

Create a generic `BrowserConnector` model instead of hard-coding Chrome.
QuietGate now has the first model slice in code:
`BrowserConnectorSnapshot` and `BlockingProviderSnapshot`.
Setup now presents Chrome, Edge, Brave, Arc, and Firefox as working browser
connectors and detects whether Safari is installed. Safari stays clearly labeled
as planned until QuietGate can actually enforce rules there.

Each connector should expose:

- Browser name and installed app detection.
- User profile detection.
- Extension install URL.
- Native messaging manifest path.
- Current extension state.
- Private/incognito permission state when detectable.
- Site access permission state when detectable.
- Last applied settings version.
- Last check time.
- One clear next action.

Priority order:

1. Chrome - working
2. Edge - working
3. Brave - working
4. Arc - working
5. Firefox - working local helper
6. Safari
7. Vivaldi and Opera

Chromium browsers can reuse most Chrome MV3/DNR logic, but each browser needs
its own extension-store install path, extension ID, user-data directory, and
native messaging host manifest location. Firefox can reuse WebExtension concepts
but uses `allowed_extensions` instead of Chrome `allowed_origins`. Safari needs
an Xcode Safari Web Extension or content blocker and App Store distribution.

Supporting docs:

- Chrome native messaging:
  https://developer.chrome.com/docs/apps/nativeMessaging
- Chrome DNR:
  https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest
- Firefox native messaging:
  https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging
- Safari extensions:
  https://developer.apple.com/safari/extensions/

### 2. Real Screen Time Connector

Replace the current guide-only page with a real Apple Screen Time connector when
entitlements are available.

Target capabilities:

- Ask for Screen Time authorization.
- Read local device activity where Apple permits it.
- Let users choose apps/categories through Apple-native pickers where available.
- Sync the same chosen app/category concepts with the iOS partner app.

Supporting docs:

- Apple Screen Time frameworks:
  https://developer.apple.com/documentation/ScreenTimeAPIDocumentation

### 3. App Blocking Connector

Cold Turkey's app-blocking coverage is a major gap for QuietGate.

Pragmatic stages:

1. Scan installed apps, let users choose apps by name, and close selected apps when they open while QuietGate runs.
2. Add Screen Time-based app shields where Apple APIs permit it.
3. Add an advanced Mac helper for stronger launch prevention only if the product
   needs hard app blocking beyond Screen Time.

This should be a separate connector because it needs separate user trust,
permissions, and failure states.

### 4. Bypass Defense Connector

For locked sessions, add explicit bypass coverage:

- Browser extension settings URLs.
- Browser guest/private modes where unsupported.
- System time settings.
- Activity Monitor.
- Installer/uninstaller reruns.
- Known alternate browsers not yet connected.

This should not appear as scary technical language. In product terms:
"Keep this session locked even if I try to undo it."

### 5. Activity Connector

Cold Turkey uses local statistics to help users decide what to block. QuietGate
should add a local-only activity connector:

- Active app tracking.
- Browser domain time from connected browser extensions.
- Local export/delete controls.
- No cloud upload by default.

This creates a strong UX loop: "Here is where your time went. Tap once to block
or schedule it."

## Performance Improvements

### Browser helper

Current Chrome helper uses `sendNativeMessage`, which starts a native host
process for each message. Chrome documents that behavior. Move toward:

- Background-owned sync on settings-version changes.
- Content scripts reading extension storage, not polling the native host.
- Event-based sync on tab activation/navigation.
- Persistent native connections where the browser permits it.
- DNR updates only when the domain ruleset hash changes.

### DNR scale

Current extension caps QuietGate dynamic rules at 4500. Chrome documents a
larger safe dynamic rule limit in modern Chrome. Add runtime quota detection and
prefer static rulesets for large built-in category packs, dynamic rules for user
custom domains.

### Browser sync delay UX

Browser helper changes can have a visible sync delay, especially when tabs were
already open. Product copy should say:

"Blocking is saved. Connected browser tabs may take about a minute to catch up."

Do not turn that delay into a fake setup failure. A browser with the extension
and native host installed is connected; a stale or not-yet-current heartbeat is
a catch-up state, not a reason to relock Home.

Do not expose this as a manual check button. The app should check automatically
on launch, after connector setup, before risky mutations, and after mutations.

## Setup UX Rule

The connector page should never look like a developer dashboard.

Use three plain states:

- Ready
- Needs one step
- Optional

Use plain tasks:

- "Connect browser"
- "Connect Chrome"
- "Connect Edge"
- "Connect Brave"
- "Connect Arc"
- "Connect Firefox"
- "Connect Safari"
- "Choose apps to block"
- "Allow stronger app blocking"

Hide terms like DNS, API key, DNR, native messaging, profile ID, and manifest
from public onboarding entirely.

## Recommended MVP Sequence

1. Keep Chrome, Edge, Brave, Arc, and Firefox as the default browser-blocking
   connectors and keep NextDNS out of public onboarding.
2. Add Safari with the clearest possible Apple permission flow.
3. Replace local app closing with Screen Time shields or a stronger helper when
   the product needs launch prevention.
4. Add local activity stats.
5. Add bypass defense only after setup is genuinely usable.

Keep NextDNS as code-only legacy plumbing. Default startup clears stale DNS setup
state, ignores saved DNS credentials, and cannot reactivate the old connector
from environment variables or saved defaults. Debug/test code may still construct
the legacy runtime directly for migration work, but the grandma-safe MVP must not
require it or show it in normal product setup.
