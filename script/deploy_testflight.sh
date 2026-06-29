#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/QuietGate.xcodeproj"
SCHEME="Tortoise"
TEAM_ID="${TORTOISE_TEAM_ID:-V558WV68AM}"
BUILD_ROOT="$ROOT_DIR/build/TestFlight"
ARCHIVE_PATH="$BUILD_ROOT/Tortoise.xcarchive"
EXPORT_PATH="$BUILD_ROOT/export"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
TORTOISE_API_BASE_URL="${TORTOISE_API_BASE_URL:-https://www.yourtortoise.com}"
CLERK_PUBLISHABLE_KEY="${CLERK_PUBLISHABLE_KEY:-${NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY:-}}"

ASC_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-${ASC_KEY_ID:-}}"
ASC_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-${ASC_ISSUER_ID:-}}"
ASC_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-${ASC_KEY_PATH:-}}"

log() {
  printf '[Tortoise TestFlight] %s\n' "$*"
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
  CLERK_PUBLISHABLE_KEY="$(
    awk -F= '/^NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=/{print substr($0, index($0, "=") + 1); exit}' "$ROOT_DIR/my-clerk-app/.env.local" |
      sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
  )"
fi

[[ -n "$CLERK_PUBLISHABLE_KEY" ]] || fail "CLERK_PUBLISHABLE_KEY or NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY is required for the iOS archive."

build_settings=(
  "CLERK_PUBLISHABLE_KEY=$CLERK_PUBLISHABLE_KEY"
  "DEVELOPMENT_TEAM=$TEAM_ID"
  "TORTOISE_API_BASE_URL=$TORTOISE_API_BASE_URL"
)

mkdir -p "$BUILD_ROOT"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

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
  <key>testFlightInternalTestingOnly</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

log "Archiving $SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  ${auth_args[@]+"${auth_args[@]}"} \
  "${build_settings[@]}" \
  archive

log "Uploading archive to App Store Connect"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  ${auth_args[@]+"${auth_args[@]}"}

log "Upload requested. Processing status will appear in App Store Connect/TestFlight."
