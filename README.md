# QuietGate

QuietGate is a Mac app for customizing how your computer behaves.

It helps people block distracting sites, lock in focus sessions, schedule stricter
computer rules, and tune browser experiences like YouTube and X. The product goal
is simple: install QuietGate, connect a browser when needed, choose your
rules, and see only controls that can honestly work.

The default MVP does not ask normal users to create a third-party blocking
account, paste developer keys, or understand network setup. QuietGate saves
rules locally and sends them to connected browsers.

## Modes

- Open: QuietGate blocking rules are off.
- Focus: adult website blocking is on; YouTube Home and Shorts are hidden,
  YouTube usage is tracked, sensitive X media, X video/GIF players, Instagram
  Reels/Explore/suggested posts, and Reddit Popular/All plus recommendations
  are hidden.
- Strict: blocking is on; YouTube Home, Shorts, comments, recommendations,
  distracting search modules, end screens, live chat, autoplay, playlists, tweet
  photos, X media cards, X Explore/Trend surfaces, Instagram stories, and Reddit
  media/sidebars are hidden; YouTube also enforces the configured daily time
  limit.

Home and the menu bar include timed sessions for common Focus and Strict blocks.
A timed session applies the selected mode immediately and returns to Open when
the timer expires while QuietGate is running. Locked Strict sessions add
precommitment: QuietGate will not end the session, switch modes, weaken browser
tuning, remove blocked domains, or quit from its own menu until the timer
expires.

Home also includes Focus Windows: daily time ranges that automatically apply
Focus or Strict while QuietGate is running. A manual mode change suppresses the
current window until it ends, and timed sessions take precedence over scheduled
windows.

## App Blocking

The Apps page is the first local Mac blocker slice. It scans installed Mac apps,
lets the user choose apps by name, and closes selected apps as soon as they
launch while QuietGate is running. This is intentionally labeled as local app
closing, not full launch prevention. Screen Time shields or stronger Mac
blocking can replace or extend this connector later.

## Product Contract

QuietGate does not treat saved preferences as proof that a browser is enforcing
them.

- Home controls are available without a third-party provider account.
- Website blocks and site tuning apply in browsers only after that browser is
  connected and has acknowledged the latest settings.
- The UI must say what is true: rules may be saved in QuietGate, active in
  connected browsers, or waiting for a browser connection.
- No default onboarding surface should ask a layperson for provider accounts,
  profile IDs, developer keys, native messaging, DNR, or extension internals.
- Advanced connectors must stay out of public product surfaces and must
  not make the main product look incomplete when browser-first blocking is the
  active path.

## Blocking Architecture

QuietGate separates the product surface from the implementation provider:

- `BrowserConnectorSnapshot`: the plain status for one browser connection. Chrome,
  Edge, Brave, Arc, and Firefox are the first working browser connectors.
  QuietGate also detects whether Safari is installed, but labels it as planned
  until that browser connection actually ships.
- `BlockingProviderSnapshot`: the status for a blocking route. Browser connections
  are the default provider for websites. The local Mac app blocker can close
  selected apps when they open while QuietGate is running; stronger launch
  prevention remains planned work. Advanced connectors are not normal
  onboarding surfaces or runtime dependencies.
- `LocalMacBlockingProvider`: the owned Mac blocker route. Today it represents
  selected app closing; later it can grow into Screen Time shields or a stronger
  native Mac blocker without changing normal onboarding into a third-party setup.
- `MacLoginItemService`: the first-party Mac startup connector. Users can let
  QuietGate start when they sign in so app blocking is ready after a restart.
- `ReadinessCheck`: default setup checks are browser-generic (`browserConnection`
  and `browserSettings`) so the product can support Chrome, Edge, Brave, Arc,
  and Firefox without falling back to provider-specific onboarding.
- Old connector experiments are isolated from normal browser-first product code.

This keeps the MVP path consumer-simple while preserving a place for stronger
Mac-level blocking later.

## Run The App

```sh
script/build_and_run.sh
```

The app opens to Setup. A normal user should only need to connect one supported
browser for website blocking and site tuning, then use Home for modes,
websites, timers, and schedules.

## Set Up QuietGate

1. Open QuietGate.
2. Go to Setup.
3. Click Connect on Chrome, Edge, Brave, Arc, or Firefox.
4. Allow QuietGate in that browser.
5. Return to QuietGate. QuietGate checks the connection automatically.

Setup should show connected or not connected. It should not require manual
"check setup" buttons for normal use.

## Home Blocking

Home owns the daily blocking state:

- Access Mode
- Adult website blocking
- Individual websites
- Timed Sessions
- Focus Windows

Adding, removing, or toggling a site updates QuietGate's rules and syncs them to
connected browsers. In the browser-first MVP, Home stays locked until at least
one supported browser is connected because browser extensions are the working
enforcement path today. Once a browser connection is installed, Home stays
usable even if that browser is closed or still catching up to the latest rules.

## Browser Connection

Browser connection applies website blocks in Chrome, Edge, Brave, Arc, or Firefox
and powers site tuning in connected browsers. QuietGate writes the desired
rules, the extension applies browser-level rules, and the browser reports back
after it receives them. QuietGate treats a browser as connected when it can
receive settings; it treats the browser as current only after the latest
acknowledgement.

Production setup should use published browser-store extensions. Local unpacked
loading is development-only because Chromium browsers require the user, browser
store, or enterprise policy to install extensions.

For source-checkout development, the extension folder is:

```text
ChromeExtension
```

## Verify

```sh
script/build_native_host.sh
script/install_chrome_sync.sh
xcodegen generate --spec project.yml --project .
xcodebuild -project QuietGate.xcodeproj -scheme QuietGate -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData test
script/verify_tuner.sh
```

## Build Installer

For local installer testing:

```sh
script/package_public_release.sh --local
```

For public download, use Developer ID signing and Apple notarization:

```sh
script/release_public.sh
```

Check release readiness first:

```sh
script/release_status.sh
```

See `docs/public-installer.md` for certificate, notarization, and download-link
setup.

`script/release_public.sh` is the one-command public path. It preflights the
machine, builds the notarized DMG, verifies the installer, publishes the GitHub
Release, and prints the stable `QuietGate.dmg` download URL.

For GitHub Actions releases, use `script/configure_github_release_secrets.sh`
to write the exact signing and notarization secrets expected by the workflow.

For the hosted path, configure the GitHub Actions secrets documented there and
push a version tag. The release workflow builds, notarizes, validates, and
uploads the public DMG to GitHub Releases. Public download buttons should point
at the stable latest asset:

```text
https://github.com/OWNER/REPO/releases/latest/download/QuietGate.dmg
```
