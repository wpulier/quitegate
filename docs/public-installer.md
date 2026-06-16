# Public Installer

QuietGate ships as a notarized Mac DMG.

The release script builds the app, verifies the bundle contents, creates a DMG
with an Applications shortcut, and can submit the DMG to Apple notarization.

## Local Installer Preview

Use this for internal install testing on this Mac:

```sh
script/package_public_release.sh --local
```

The output is written to `dist/`. A local DMG is ad-hoc signed and is not ready
for public download.

## Public Notarized Installer

Public release requires:

- A Developer ID Application certificate in Keychain Access.
- Apple notary credentials saved in a notarytool keychain profile.
- Published browser helper listing URLs in `QuietGate/Resources/Info.plist`:
  `QuietGateChromiumExtensionStoreURL` and `QuietGateFirefoxExtensionStoreURL`.
- A public download host. The recommended MVP path is GitHub Releases.

Check this Mac before trying to publish:

```sh
script/release_status.sh
```

Recommended one-time setup:

```sh
xcrun notarytool store-credentials quietgate-notary \
  --apple-id "APPLE_ID_EMAIL" \
  --team-id "V558WV68AM" \
  --password "APP_SPECIFIC_PASSWORD"
```

After the required credentials are in place, run the full public release:

```sh
script/release_public.sh
```

That command checks prerequisites, builds the notarized DMG, verifies the
installer, publishes the GitHub Release, and prints the stable download URL.

To build only the public installer without publishing:

```sh
QUIETGATE_NOTARY_PROFILE=quietgate-notary \
script/package_public_release.sh --notarize
```

The script fails before upload if the app is missing the native host, missing the
bundled Chromium or Firefox extension, or if the native host is not universal.
`script/release_status.sh` also fails until the browser helpers have published
store URLs. Local unpacked helpers are acceptable for internal testing, but they
are not a consumer-grade public setup path.

## Publish A Download Link

If you built the notarized DMG separately, publish it to GitHub Releases:

```sh
script/publish_github_release.sh dist/QuietGate-1.0-1-notarize.dmg
```

The publish script refuses local preview DMGs, checks for a stapled notarization
ticket, checks Gatekeeper acceptance, creates a versioned GitHub Release, uploads
both the versioned DMG and a stable `QuietGate.dmg` asset, then prints the
release page plus direct download URLs.

If GitHub Releases is not the final hosting choice, upload the notarized DMG to
another HTTPS host and publish that URL. Do not upload `*-local.dmg` for public
users.

## Hosted Release Pipeline

The repo includes `.github/workflows/release-macos.yml`. After the GitHub repo is
configured, pushing a tag like `v1.0.1` builds the macOS app on GitHub Actions,
imports the Developer ID certificate from secrets, notarizes the DMG with Apple,
validates Gatekeeper, uploads the DMG as a workflow artifact, and publishes a
GitHub Release download URL.

Required GitHub Actions secrets:

- `DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`: base64-encoded `.p12`
  containing the Developer ID Application certificate and private key.
- `DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `MACOS_SIGNING_KEYCHAIN_PASSWORD`: temporary CI keychain password.
- `APPLE_ID`: Apple ID email used for notarization.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific Apple ID password.
- `APPLE_TEAM_ID`: Apple developer team ID.

Set those secrets with the helper:

```sh
export DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD="P12_PASSWORD"
export APPLE_ID="APPLE_ID_EMAIL"
export APPLE_APP_SPECIFIC_PASSWORD="APP_SPECIFIC_PASSWORD"
export APPLE_TEAM_ID="V558WV68AM"

script/configure_github_release_secrets.sh path/to/DeveloperIDApplication.p12
```

The helper validates the `.p12` password when `openssl` is available, writes the
exact GitHub secret names the workflow expects, and does not print secret values.

Once secrets are configured:

```sh
git tag v1.0.1
git push origin v1.0.1
```

The release page will expose a versioned asset URL like:

```text
https://github.com/OWNER/REPO/releases/download/v1.0.1/QuietGate-1.0-1-notarize.dmg
```

It also uploads a stable asset for the latest release:

```text
https://github.com/OWNER/REPO/releases/latest/download/QuietGate.dmg
```

Use the stable URL for the public website/download button.

## Current Public Release Blockers

This machine currently has Apple Development and iPhone Distribution signing
identities only. A public Mac download needs:

- Developer ID Application certificate installed in Keychain Access.
- Working `quietgate-notary` notarytool keychain profile.
- Published Chromium and Firefox helper URLs added to
  `QuietGate/Resources/Info.plist`.
- Git origin remote configured if using GitHub Releases for the download link.
- GitHub Actions release secrets configured with
  `script/configure_github_release_secrets.sh` if using the hosted workflow.

Until those are in place, `dist/QuietGate-1.0-1-local.dmg` is only an internal
preview installer, not a public installer.
