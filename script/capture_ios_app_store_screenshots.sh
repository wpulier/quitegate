#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/QuietGate.xcodeproj"
SCHEME="Tortoise"
BUNDLE_ID="com.yourtortoise.Tortoise"
DERIVED_DATA="$ROOT_DIR/build/AppStoreScreenshots/DerivedData"
IPHONE_SIMULATOR_NAME="${TORTOISE_SCREENSHOT_IPHONE:-iPhone 17 Pro Max}"
IPAD_SIMULATOR_NAME="${TORTOISE_SCREENSHOT_IPAD:-iPad Pro 13-inch (M5)}"
CLERK_PUBLISHABLE_KEY="${CLERK_PUBLISHABLE_KEY:-pk_test_ZHVtbXkudG9ydG9pc2UuY2xlcmsuYWNjb3VudHMuZGV2JA}"
TORTOISE_API_BASE_URL="${TORTOISE_API_BASE_URL:-https://www.yourtortoise.com}"

log() {
  printf '[Tortoise screenshots] %s\n' "$*"
}

fail() {
  printf '[Tortoise screenshots] ERROR: %s\n' "$*" >&2
  exit 1
}

simulator_id_for_name() {
  local name="$1"
  xcrun simctl list devices available |
    grep -F -m 1 "$name" |
    sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

boot_simulator() {
  local simulator_id="$1"
  xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_id" -b >/dev/null
}

build_for_simulator() {
  local simulator_id="$1"
  log "Building $SCHEME for simulator $simulator_id"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$simulator_id" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet \
    "CLERK_PUBLISHABLE_KEY=$CLERK_PUBLISHABLE_KEY" \
    "TORTOISE_API_BASE_URL=$TORTOISE_API_BASE_URL" \
    build

  local app_path="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Tortoise.app"
  [[ -d "$app_path" ]] || fail "Built app not found at $app_path"
  xcrun simctl install "$simulator_id" "$app_path"
}

prepare_status_bar() {
  local simulator_id="$1"
  xcrun simctl status_bar "$simulator_id" override \
    --time "9:41" \
    --wifiBars 3 \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100 >/dev/null 2>&1 || true
}

launch_and_capture() {
  local simulator_id="$1"
  local output_path="$2"
  shift 2

  xcrun simctl terminate "$simulator_id" "$BUNDLE_ID" >/dev/null 2>&1 || true
  SIMCTL_CHILD_CLERK_PUBLISHABLE_KEY="$CLERK_PUBLISHABLE_KEY" \
    SIMCTL_CHILD_TORTOISE_API_BASE_URL="$TORTOISE_API_BASE_URL" \
    xcrun simctl launch "$simulator_id" "$BUNDLE_ID" "$@" >/dev/null
  sleep 2
  xcrun simctl io "$simulator_id" screenshot "$output_path" >/dev/null
  log "Captured $output_path"
}

capture_device_set() {
  local device_label="$1"
  local simulator_name="$2"
  local output_dir="$3"
  local simulator_id

  simulator_id="$(simulator_id_for_name "$simulator_name")"
  [[ -n "$simulator_id" ]] || fail "Simulator not found: $simulator_name"

  log "Preparing $device_label screenshots on $simulator_name ($simulator_id)"
  mkdir -p "$output_dir"
  boot_simulator "$simulator_id"
  build_for_simulator "$simulator_id"
  prepare_status_bar "$simulator_id"

  launch_and_capture "$simulator_id" "$output_dir/01-account-hub.png"
  launch_and_capture "$simulator_id" "$output_dir/02-ios-setup.png" --tortoise-screenshot --tortoise-screenshot-section blocking
  launch_and_capture "$simulator_id" "$output_dir/03-tuning.png" --tortoise-screenshot --tortoise-screenshot-section tuning
  launch_and_capture "$simulator_id" "$output_dir/04-usage.png" --tortoise-screenshot --tortoise-screenshot-section usage
  launch_and_capture "$simulator_id" "$output_dir/05-devices.png" --tortoise-screenshot --tortoise-screenshot-section devices
}

capture_device_set "iPhone 6.9-inch" "$IPHONE_SIMULATOR_NAME" "$ROOT_DIR/docs/app-store/screenshots/iphone-6-9"
capture_device_set "iPad 13-inch" "$IPAD_SIMULATOR_NAME" "$ROOT_DIR/docs/app-store/screenshots/ipad-13"

log "Done. Upload the PNGs under docs/app-store/screenshots to App Store Connect."
