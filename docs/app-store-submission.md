# Tortoise iOS App Store Submission

Last updated: 2026-07-03

## Current Status

Ready:

- iOS simulator build and launch succeeds for the `Tortoise` scheme.
- iPhone 6.9-inch screenshots are generated at `1320x2868`.
- iPad 13-inch screenshots are generated at `2064x2752`.
- TestFlight upload script now refuses Clerk test keys by default.
- TestFlight export no longer forces internal-only builds unless `TORTOISE_TESTFLIGHT_INTERNAL_ONLY=1` is set.
- Main iOS app, DeviceActivity monitor, shield configuration, shield action, and Safari extension targets exist.
- App Group storage is configured in entitlements as `group.com.yourtortoise.Tortoise`.

Still blocked before external TestFlight/App Review:

- Confirm Apple approved the Family Controls distribution entitlement for the account/team.
- Enable required capabilities on all App IDs in Apple Developer Identifiers.
- Fix production iOS signing/provisioning so archive uses App Store distribution profiles.
- Set production Clerk keys in Vercel and use a production `pk_live_...` publishable key for the iOS archive.
- Fill App Store Connect app metadata, privacy, beta review notes, and review credentials.

Apple references:

- Family Controls entitlement: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- TestFlight overview: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- Screenshots: https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/
- App privacy in App Store Connect: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/

## Screenshot Assets

Upload these PNGs to App Store Connect.

iPhone 6.9-inch:

- `docs/app-store/screenshots/iphone-6-9/01-account-hub.png`
- `docs/app-store/screenshots/iphone-6-9/02-ios-setup.png`
- `docs/app-store/screenshots/iphone-6-9/03-tuning.png`
- `docs/app-store/screenshots/iphone-6-9/04-usage.png`
- `docs/app-store/screenshots/iphone-6-9/05-devices.png`

iPad 13-inch:

- `docs/app-store/screenshots/ipad-13/01-account-hub.png`
- `docs/app-store/screenshots/ipad-13/02-ios-setup.png`
- `docs/app-store/screenshots/ipad-13/03-tuning.png`
- `docs/app-store/screenshots/ipad-13/04-usage.png`
- `docs/app-store/screenshots/ipad-13/05-devices.png`

Regenerate screenshots after UI changes:

```bash
script/capture_ios_app_store_screenshots.sh
```

## Production Clerk Setup

In Clerk, switch to the `quietgate` Production instance.

Set these in Vercel Production:

```bash
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
CLERK_SECRET_KEY=sk_live_...
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
CLERK_JWT_AUDIENCE=tortoise-api
CLERK_AUTHORIZED_PARTIES=https://www.yourtortoise.com,https://yourtortoise.com
```

For local TestFlight upload, do not store the secret key in the repo. Export only the production publishable key before running the upload:

```bash
export CLERK_PUBLISHABLE_KEY=pk_live_...
export TORTOISE_API_BASE_URL=https://www.yourtortoise.com
script/deploy_testflight.sh
```

The upload script will fail if it sees a `pk_test_...` key unless `TORTOISE_ALLOW_TEST_CLERK=1` is explicitly set. Do not use that override for Apple review.

## Apple Developer Capabilities

Verify these App IDs in Apple Developer `Certificates, Identifiers & Profiles`.

- `com.yourtortoise.Tortoise`
  - App Groups: `group.com.yourtortoise.Tortoise`
  - Associated Domains: `webcredentials:clerk.yourtortoise.com`
  - Family Controls
- `com.yourtortoise.Tortoise.DeviceActivityMonitor`
  - App Groups: `group.com.yourtortoise.Tortoise`
  - Family Controls
- `com.yourtortoise.Tortoise.ShieldConfiguration`
  - App Groups: `group.com.yourtortoise.Tortoise`
  - Family Controls
- `com.yourtortoise.Tortoise.ShieldAction`
  - App Groups: `group.com.yourtortoise.Tortoise`
  - Family Controls
- `com.yourtortoise.Tortoise.SafariExtension`
  - App Groups: `group.com.yourtortoise.Tortoise`

If Family Controls is not visible on those App IDs, the entitlement is not ready for distribution yet.

## Signing And Upload

Current local blocker:

- Local signing identities include `iPhone Distribution: WILLIAM PULIER (SY7TABCD5M)`.
- Local signing identities do not include an Apple Development certificate for `SY7TABCD5M`.
- The current Xcode project automatic signing path resolves the iOS archive to `iPhone Developer`, which fails for the extension entitlements.

Unblock options:

- Preferred: in Xcode, sign in to the Apple Developer account for team `SY7TABCD5M`, then create/download Apple Development and Apple Distribution certificates and let automatic signing create profiles for all five iOS bundle IDs.
- Alternative: manually create App Store provisioning profiles for all five bundle IDs, then wire manual signing for the `Tortoise` scheme and embedded extensions.
- Alternative: use Xcode Cloud/App Store Connect managed signing if it already has the Family Controls entitlement and profiles for these App IDs.

Archive-only preflight command:

```bash
export CLERK_PUBLISHABLE_KEY=pk_live_...
export TORTOISE_API_BASE_URL=https://www.yourtortoise.com
TORTOISE_ARCHIVE_ONLY=1 script/deploy_testflight.sh
```

Observed blocker on 2026-07-03:

```text
"TortoiseShieldAction" has entitlements that require signing with a development certificate.
"TortoiseShieldConfiguration" has entitlements that require signing with a development certificate.
"TortoiseDeviceActivityMonitor" has entitlements that require signing with a development certificate.
"TortoiseSafariExtension" has entitlements that require signing with a development certificate.
```

Upload command after signing and production Clerk are ready:

```bash
export CLERK_PUBLISHABLE_KEY=pk_live_...
export TORTOISE_API_BASE_URL=https://www.yourtortoise.com
export APP_STORE_CONNECT_API_KEY_ID=...
export APP_STORE_CONNECT_API_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_....p8
script/deploy_testflight.sh
```

For an internal-only smoke build, set `TORTOISE_TESTFLIGHT_INTERNAL_ONLY=1`. Leave it unset for external TestFlight/Beta App Review.

## App Store Connect Metadata

Suggested fields:

- App name: `Tortoise`
- Subtitle: `Tune your digital life`
- Category: Productivity
- Content rights: Tortoise owns or has rights to included content.
- Support URL: `https://www.yourtortoise.com/support`
- Privacy Policy URL: `https://www.yourtortoise.com/privacy`
- Marketing URL: `https://www.yourtortoise.com`

Short description draft:

```text
Tortoise helps you tune distracting sites and apps across iPhone, Mac, and browser profiles from one account.
```

Full description draft:

```text
Tortoise gives you one account for quieter digital habits across your devices.

On iPhone, Tortoise uses Screen Time permissions to help block selected apps and web domains, set YouTube limits, and keep setup status clear. In Safari, the Tortoise extension tunes distracting pages such as YouTube, X, Instagram, and Reddit by hiding noisy surfaces you choose to quiet.

Use Tortoise with the Mac app and browser helpers to keep your policy, usage summaries, and connected device status in sync.
```

Keywords draft:

```text
screen time,focus,blocker,youtube,distraction,productivity,parental controls,safari
```

## Beta App Review Notes

Use this in TestFlight beta review notes and App Review notes.

```text
Tortoise is a digital usage control app. It uses Apple's Screen Time APIs (FamilyControls, DeviceActivity, ManagedSettings) for app/site shields and daily thresholds, and an iOS Safari Web Extension for Safari page tuning.

Reviewer test account:
Email: <add reviewer email>
Password: <add reviewer password>

Suggested review flow:
1. Launch Tortoise and sign in with the reviewer account.
2. Open Blocking.
3. Choose My iPhone.
4. Tap Allow Screen Time and approve the Screen Time permission prompt.
5. Tap Select targets and choose YouTube app and youtube.com if available.
6. Enable Tortoise Safari from Settings > Apps > Safari > Extensions > Tortoise Safari > Allow Extension.
7. Return to Tortoise, tap Recheck, then turn on Focus or Strict.
8. Open YouTube in Safari to verify Safari tuning and heartbeat.

Privacy note: Screen Time opaque tokens stay local on device and are not uploaded. Tortoise uploads account/device status, setup health, policy settings, supported-site usage summaries, and threshold events so a user's devices can stay in sync.

If Family Sharing child authorization is unavailable on the review device, use the My iPhone self-control path.
```

## App Privacy Checklist

Answer App Privacy based on current behavior:

- Contact Info: email address for account sign-in, linked to the user, not used for tracking.
- Identifiers: Clerk user ID and Tortoise device IDs, linked to the user, not used for tracking.
- Usage Data: supported-site/app usage summaries and product interaction data, linked to the user, not used for tracking.
- Diagnostics: device health, sync health, setup status, and error/status reports, linked to the user where needed, not used for tracking.
- Sensitive Info: do not claim collection of Screen Time tokens. They remain local and private.
- Browsing History: if App Store Connect treats supported-site usage by domain as browsing history, disclose it. Tortoise stores supported-site usage summaries for sync and dashboard display, not advertising.

Do not claim third-party advertising tracking.

## Export Compliance

`Tortoise/Resources/Info.plist` sets `ITSAppUsesNonExemptEncryption` to `false`.

Expected App Store Connect answer: the app uses standard HTTPS/TLS only and does not include proprietary or non-exempt encryption. Reconfirm before final submission if any new crypto/auth library changes are added.

## Final Submission Checklist

- Production Clerk instance is configured.
- `https://www.yourtortoise.com` production env vars are set and deployed.
- Family Controls entitlement is approved for distribution.
- App IDs have Family Controls/App Group/Associated Domain capabilities as listed above.
- App Store distribution profiles exist for the app and all embedded extensions.
- `script/deploy_testflight.sh` uploads a new build without `TORTOISE_ALLOW_TEST_CLERK=1`.
- App Store Connect build processing completes.
- Beta app info is filled.
- Screenshots are uploaded for iPhone 6.9-inch and iPad 13-inch.
- App Privacy is filled.
- Export compliance is filled.
- Reviewer account is created and verified.
- Review notes are pasted.
- External TestFlight group/public link is enabled after Beta App Review approves the first build.
