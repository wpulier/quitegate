# Platform Controls Integration Plan

QuietGate should treat built-in platform controls as an additive safety layer, not as a replacement for its own browser tuners. Apple, Google, X, and Reddit all expose useful content controls, but each has different scope and reliability. QuietGate's role is to audit those controls, guide the user to apply them, and keep deterministic local blocking active for gaps such as unlabeled X or Reddit media.

## Layered Model

1. **OS controls**
   - Apple Screen Time can limit adult websites and maintain custom allowed/restricted website lists, primarily for Safari and system-managed web access.
   - Apple Sensitive Content Warning uses private on-device analysis, but on Mac it applies to supported Apple surfaces such as Messages, Contact Posters, and shared photo albums. It does not automatically scan arbitrary Chrome or X pages.
   - Apple's SensitiveContentAnalysis framework is a future entitlement-gated engineering track for apps that receive media directly.

2. **Browser and search controls**
   - Google SafeSearch can be locked with account/device/network controls, including mapping Google search domains to `forcesafesearch.google.com`.
   - Chrome policies can force Google SafeSearch and YouTube Restricted Mode where local or managed policy is available.
   - DNS-family filters such as Cloudflare Family DNS and CleanBrowsing Adult/Family can block adult domains before browser scripts run.
   - These controls help search/discovery, but do not replace site-specific DOM blocking.

3. **Platform account controls**
   - X can hide sensitive media and hide sensitive search results when its own metadata marks content correctly.
   - Reddit can hide mature content and blur mature media when Reddit exposes NSFW/18+ labels.
   - These controls are account-scoped and label-dependent, so QuietGate still needs its own tuners for unlabeled or dynamically inserted content.

4. **QuietGate tuners**
   - QuietGate remains the enforcement layer for supported sites and browser profiles.
   - Tuners must continue to handle stale extension versions, dynamic SPA routes, account/profile pages, and unlabeled explicit cues.

## Guided Apply Rules

- QuietGate never silently changes Apple, Google, X, Reddit, or browser account settings.
- QuietGate may open the exact settings page, show the current audit state, and explain the recommended setting.
- Any account or system setting change must be done by the user or behind an explicit visible confirmation flow.
- After a guided action, QuietGate should perform a readback check and show whether the setting is enabled, unknown, or still needs action.

## V1 Statuses

- Apple Screen Time web restrictions: manual guided check with System Settings link.
- Apple Sensitive Content Warning: manual guided check with Privacy & Security link.
- Google SafeSearch lock: local hosts/DNS readback check.
- Cloudflare Family DNS and CleanBrowsing: guided setup entries for DNS-level adult filtering.
- Chrome SafeSearch and YouTube Restricted Mode policies: local policy readback check.
- X sensitive-media and sensitive-search settings: browser settings-page audit from the logged-in web session.
- Reddit mature-content and blur settings: browser settings-page audit from the logged-in web session.
- QuietGate browser tuners: separate status from app version and platform settings.

## Acceptance Checklist

- The app distinguishes app freshness, browser helper freshness, platform-control status, and live page tuner status.
- A platform setting marked "On" has a concrete readback source or is clearly labeled as manual.
- X and Reddit account setting audits work from deterministic browser fixtures and do not mutate the page.
- QuietGate tuners remain active even when platform settings are enabled.
- Stale browser helper versions remain visible as browser freshness problems, not app update problems.
