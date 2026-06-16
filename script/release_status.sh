#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuietGate"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_APP="$ROOT_DIR/build/PublicRelease/DerivedData/Build/Products/Release/$APP_NAME.app"
NOTARY_PROFILE="${QUIETGATE_NOTARY_PROFILE:-quietgate-notary}"
INFO_PLIST="$ROOT_DIR/QuietGate/Resources/Info.plist"

ok_count=0
warn_count=0
fail_count=0

ok() {
  ok_count=$((ok_count + 1))
  printf '[ok] %s\n' "$*"
}

warn() {
  warn_count=$((warn_count + 1))
  printf '[warn] %s\n' "$*"
}

fail() {
  fail_count=$((fail_count + 1))
  printf '[fail] %s\n' "$*"
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

latest_dist_file() {
  local pattern="$1"
  find "$DIST_DIR" -maxdepth 1 -type f -name "$pattern" -print 2>/dev/null |
    while IFS= read -r path; do
      printf '%s\t%s\n' "$(stat -f '%m' "$path")" "$path"
    done |
    sort -rn |
    awk 'NR == 1 {print $2}'
}

developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' |
    head -n 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null || true
}

require_https_plist_url() {
  local key="$1"
  local label="$2"
  local value
  value="$(plist_value "$key")"
  if [[ "$value" == https://* ]]; then
    ok "$label configured: $value"
  else
    fail "$label is not configured in QuietGate/Resources/Info.plist ($key)"
  fi
}

printf 'QuietGate public release status\n'
printf 'Repo: %s\n\n' "$ROOT_DIR"

LOCAL_DMG="$(latest_dist_file "$APP_NAME-*-local.dmg")"
NOTARIZED_DMG="$(latest_dist_file "$APP_NAME-*-notarize.dmg")"

for tool in xcodebuild xcrun hdiutil codesign security shasum; do
  if have_command "$tool"; then
    ok "$tool is available"
  else
    fail "$tool is missing"
  fi
done

if [[ -d "$RELEASE_APP" ]]; then
  ok "Release app exists: $RELEASE_APP"
  if codesign --verify --deep --strict "$RELEASE_APP" >/dev/null 2>&1; then
    ok "Release app signature verifies"
  else
    fail "Release app signature does not verify"
  fi
else
  warn "Release app is not built yet. Run: script/package_public_release.sh --local --skip-tests"
fi

require_https_plist_url "QuietGateChromiumExtensionStoreURL" "Published Chromium helper URL"
require_https_plist_url "QuietGateFirefoxExtensionStoreURL" "Published Firefox helper URL"

if [[ -n "$LOCAL_DMG" && -f "$LOCAL_DMG" ]]; then
  ok "Local preview DMG exists: $LOCAL_DMG"
  warn "Local preview DMG is ad-hoc signed and is not public-ready"
else
  warn "No local preview DMG found. Run: script/package_public_release.sh --local"
fi

identity="$(developer_id_identity || true)"
if [[ -n "$identity" ]]; then
  ok "Developer ID Application identity installed: $identity"
else
  fail "No Developer ID Application identity installed"
fi

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  ok "Notary profile works: $NOTARY_PROFILE"
else
  fail "Notary profile is missing or unusable: $NOTARY_PROFILE"
fi

if [[ -n "$NOTARIZED_DMG" && -f "$NOTARIZED_DMG" ]]; then
  ok "Notarized DMG candidate exists: $NOTARIZED_DMG"
  if xcrun stapler validate "$NOTARIZED_DMG" >/dev/null 2>&1; then
    ok "Stapled notarization ticket validates"
  else
    fail "Stapled notarization ticket is missing or invalid"
  fi
  if spctl -a -vv --type open "$NOTARIZED_DMG" >/dev/null 2>&1; then
    ok "Gatekeeper accepts notarized DMG"
  else
    fail "Gatekeeper does not accept notarized DMG"
  fi
else
  warn "No notarized DMG found. Run: QUIETGATE_NOTARY_PROFILE=$NOTARY_PROFILE script/package_public_release.sh --notarize"
fi

if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
  ok "Git origin remote is configured"
else
  fail "No git origin remote configured for a GitHub Release download link"
fi

if have_command gh; then
  if gh auth status >/dev/null 2>&1; then
    ok "GitHub CLI is authenticated"
  else
    warn "GitHub CLI is installed but not authenticated"
  fi
else
  warn "GitHub CLI is not installed; publishing a GitHub Release will need gh"
fi

printf '\nSummary: %s ok, %s warnings, %s failures\n' "$ok_count" "$warn_count" "$fail_count"

if ((fail_count > 0)); then
  cat <<'NEXT'

Next public-release gates:
1. Install a Developer ID Application certificate for the Apple developer team.
2. Save notary credentials:
   xcrun notarytool store-credentials quietgate-notary --apple-id APPLE_ID --team-id TEAM_ID --password APP_SPECIFIC_PASSWORD
3. Publish the browser helpers and add their store URLs to QuietGate/Resources/Info.plist:
   QuietGateChromiumExtensionStoreURL
   QuietGateFirefoxExtensionStoreURL
4. Configure a git origin remote for the public repo.
5. Build, notarize, verify, and publish:
   script/release_public.sh
6. For hosted GitHub Actions releases, configure workflow secrets:
   script/configure_github_release_secrets.sh path/to/DeveloperIDApplication.p12

The public website/download button should use the stable GitHub asset:
   https://github.com/OWNER/REPO/releases/latest/download/QuietGate.dmg
NEXT
  exit 1
fi

cat <<'READY'

Public release prerequisites are ready.
Build, notarize, verify, and publish:
  script/release_public.sh

Use this stable URL for the public website/download button:
  https://github.com/OWNER/REPO/releases/latest/download/QuietGate.dmg
READY
