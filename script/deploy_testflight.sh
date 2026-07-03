#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/QuietGate.xcodeproj"
SCHEME="Tortoise"
TEAM_ID="${TORTOISE_TEAM_ID:-SY7TABCD5M}"
BUILD_ROOT="$ROOT_DIR/build/TestFlight"
ARCHIVE_PATH="$BUILD_ROOT/Tortoise.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
TORTOISE_API_BASE_URL="${TORTOISE_API_BASE_URL:-https://www.yourtortoise.com}"
CLERK_PUBLISHABLE_KEY="${CLERK_PUBLISHABLE_KEY:-${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY:-}}"
CLERK_KEY_SOURCE="environment"
TORTOISE_ALLOW_TEST_CLERK="${TORTOISE_ALLOW_TEST_CLERK:-0}"
TORTOISE_TESTFLIGHT_INTERNAL_ONLY="${TORTOISE_TESTFLIGHT_INTERNAL_ONLY:-0}"
TORTOISE_ARCHIVE_ONLY="${TORTOISE_ARCHIVE_ONLY:-0}"

ASC_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
ASC_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-${ASC_ISSUER_ID:-}}"
ASC_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"

log() {
  printf '[Tortoise TestFlight] %s\n' "$*"
}

warn() {
  printf '[Tortoise TestFlight] WARNING: %s\n' "$*" >&2
}

fail() {
  printf '[Tortoise TestFlight] ERROR: %s\n' "$*" >&2
  exit 1
}

auth_args=()
if [[ -n "$ASC_KEY_ID" || -n "$ASC_ISSUER_ID" || -n "$ASC_KEY_PATH" ]]; then
  [[ -n "$ASC_KEY_ID" ]] || fail "APP_STORE_CONNECT_API_KEY_ID or ASC_KEY_ID is required when using API key upload."
  [[ -n "$ASC_ISSUER_ID" ]] || fail "APP_STORE_CONNECT_API_ISSUER_ID or ASC_ISSUER_ID is required when using API key upload."
  [[ -n "$ASC_KEY_PATH" ]] || fail "APP_STORE_CONNECT_API_KEY_PATH or ASC_KEY_PATH is required when using API key upload."
  [[ -f "$ASC_KEY_PATH" ]] || fail "App Store Connect API key file was not found: $ASC_KEY_PATH"
  auth_args=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

if [[ -z "$CLERK_PUBLISHABLE_KEY" && -f "$ROOT_DIR/my-clerk-app/.env.local" ]]; then
  CLERK_KEY_SOURCE="my-clerk-app/.env.local"
  CLERK_PUBLISHABLE_KEY="$(
    awk -F= '/^NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=/{print substr($0, index($0, "=") + 1); exit}' "$ROOT_DIR/my-clerk-app/.env.local" |
      sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
  )"
fi

[[ -n "$CLERK_PUBLISHABLE_KEY" ]] || fail "CLERK_PUBLISHABLE_KEY or NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY is required for the iOS archive."
[[ "$TORTOISE_ALLOW_TEST_CLERK" =~ ^(0|1)$ ]] || fail "TORTOISE_ALLOW_TEST_CLERK must be 0 or 1."
[[ "$TORTOISE_TESTFLIGHT_INTERNAL_ONLY" =~ ^(0|1)$ ]] || fail "TORTOISE_TESTFLIGHT_INTERNAL_ONLY must be 0 or 1."
[[ "$TORTOISE_ARCHIVE_ONLY" =~ ^(0|1)$ ]] || fail "TORTOISE_ARCHIVE_ONLY must be 0 or 1."

case "$CLERK_PUBLISHABLE_KEY" in
  pk_live_*)
    log "Using production Clerk publishable key from $CLERK_KEY_SOURCE."
    ;;
  pk_test_*)
    if [[ "$TORTOISE_ALLOW_TEST_CLERK" != "1" ]]; then
      fail "Refusing to archive TestFlight with a Clerk test publishable key from $CLERK_KEY_SOURCE. Switch Clerk to Production and export CLERK_PUBLISHABLE_KEY=pk_live_... before uploading. For a throwaway dev archive only, set TORTOISE_ALLOW_TEST_CLERK=1."
    fi
    warn "Using a Clerk test publishable key because TORTOISE_ALLOW_TEST_CLERK=1. Do not submit this build to Apple review."
    ;;
  *)
    fail "CLERK_PUBLISHABLE_KEY must look like a Clerk publishable key starting with pk_live_."
    ;;
esac

case "$TORTOISE_API_BASE_URL" in
  https://*)
    ;;
  *)
    fail "TORTOISE_API_BASE_URL must be an https URL for TestFlight/App Store builds."
    ;;
esac

build_settings=(
  "CLERK_PUBLISHABLE_KEY=$CLERK_PUBLISHABLE_KEY"
  "DEVELOPMENT_TEAM=$TEAM_ID"
  "TORTOISE_API_BASE_URL=$TORTOISE_API_BASE_URL"
)

mkdir -p "$BUILD_ROOT"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

internal_testing_plist=""
if [[ "$TORTOISE_TESTFLIGHT_INTERNAL_ONLY" == "1" ]]; then
  warn "Export will be marked internal-only because TORTOISE_TESTFLIGHT_INTERNAL_ONLY=1."
  internal_testing_plist=$'  <key>testFlightInternalTestingOnly</key>\n  <true/>'
else
  log "Export will be eligible for external TestFlight/App Review when App Store Connect metadata is complete."
fi

log "Signing team: $TEAM_ID"
if ! security find-identity -v -p codesigning | grep -Eq "(Apple Development|Apple Distribution|iPhone Distribution): .*\\($TEAM_ID\\)"; then
  warn "No local Apple signing identity was found for team $TEAM_ID. Automatic signing may still work with App Store Connect API credentials, but local archive can fail."
fi

explain_archive_failure() {
  local archive_log="$1"

  if grep -Eq "automatically signed for development, but a conflicting code signing identity Apple Distribution" "$archive_log"; then
    fail "The archive is using automatic signing, so Xcode needs the build targets signed with Apple Development during archive; the app-store-connect export step re-signs with Apple Distribution for TestFlight. Remove any Release CODE_SIGN_IDENTITY=Apple Distribution override, then rerun."
  fi

  if grep -Eq "requires signing with a development certificate" "$archive_log"; then
    fail "One or more Tortoise targets still cannot be development-signed for archive. In Apple Developer for team $TEAM_ID, verify Family Controls Development and Distribution are enabled for com.yourtortoise.Tortoise plus DeviceActivityMonitor, ShieldAction, and ShieldConfiguration; verify App Group group.com.yourtortoise.Tortoise is enabled for all app/extension IDs; then rerun with -allowProvisioningUpdates or App Store Connect API credentials."
  fi

  fail "xcodebuild archive failed. See $archive_log for the full signing/build output."
}

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>manageAppVersionAndBuildNumber</key>
  <true/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
$internal_testing_plist
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

archive_log="$BUILD_ROOT/archive.log"

log "Archiving $SCHEME"
set +e
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -quiet \
  ${auth_args[@]+"${auth_args[@]}"} \
  "${build_settings[@]}" \
  archive 2>&1 | tee "$archive_log"
archive_status=${PIPESTATUS[0]}
set -e

if [[ "$archive_status" -ne 0 ]]; then
  explain_archive_failure "$archive_log"
fi

if [[ "$TORTOISE_ARCHIVE_ONLY" == "1" ]]; then
  log "Archive-only mode requested. Archive is at $ARCHIVE_PATH; skipping App Store Connect upload."
  exit 0
fi

log "Uploading archive to App Store Connect"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  -quiet \
  ${auth_args[@]+"${auth_args[@]}"}

log "Upload requested. Processing status will appear in App Store Connect/TestFlight."
