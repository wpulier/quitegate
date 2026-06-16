#!/usr/bin/env bash
set -euo pipefail

PUBLIC=0
DMG_PATH=""

usage() {
  cat <<'USAGE'
usage: script/verify_installer_dmg.sh [--public] path/to/QuietGate.dmg

Verifies that a QuietGate DMG is installable:
  - DMG exists and can be mounted read-only
  - QuietGate.app is present
  - Applications shortcut is present
  - Start Here.txt is present and useful
  - bundled native host and browser extension are present
  - app signature verifies
  - native host is universal

With --public, also requires:
  - not a *-local.dmg file
  - stapled notarization ticket validates
  - Gatekeeper accepts the DMG
USAGE
}

log() {
  printf '[QuietGate installer verify] %s\n' "$*"
}

fail() {
  printf '[QuietGate installer verify] ERROR: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --public)
      PUBLIC=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      fail "Unknown option: $1"
      ;;
    *)
      if [[ -n "$DMG_PATH" ]]; then
        fail "Only one DMG path may be provided."
      fi
      DMG_PATH="$1"
      ;;
  esac
  shift
done

[[ -n "$DMG_PATH" ]] || fail "Missing DMG path."
[[ -f "$DMG_PATH" ]] || fail "DMG does not exist: $DMG_PATH"

if ((PUBLIC == 1)); then
  [[ "$DMG_PATH" != *"-local.dmg" ]] || fail "Public verification refuses local preview DMGs."

  log "Checking stapled notarization ticket"
  xcrun stapler validate "$DMG_PATH" >/dev/null

  log "Checking Gatekeeper acceptance"
  spctl -a -vv --type open "$DMG_PATH" >/dev/null
fi

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quietgate-dmg.XXXXXX")"
attached=0
cleanup() {
  if ((attached == 1)); then
    hdiutil detach "$MOUNT_DIR" -quiet || true
  fi
  rmdir "$MOUNT_DIR" 2>/dev/null || true
}
trap cleanup EXIT

log "Mounting DMG read-only"
if ! hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR"; then
  fail "Could not mount DMG read-only: $DMG_PATH"
fi
attached=1

APP_PATH="$MOUNT_DIR/QuietGate.app"
START_HERE="$MOUNT_DIR/Start Here.txt"
APPLICATIONS_LINK="$MOUNT_DIR/Applications"
NATIVE_HOST="$APP_PATH/Contents/Resources/quietgate-native-host"
CHROME_EXTENSION="$APP_PATH/Contents/Resources/ChromeExtension/manifest.json"
FIREFOX_EXTENSION="$APP_PATH/Contents/Resources/FirefoxExtension/manifest.json"
CHROME_BLOCK_PAGE="$APP_PATH/Contents/Resources/ChromeExtension/blocked/blocked.html"
FIREFOX_BLOCK_PAGE="$APP_PATH/Contents/Resources/FirefoxExtension/blocked/blocked.html"
CHROME_YOUTUBE_TUNER="$APP_PATH/Contents/Resources/ChromeExtension/content/youtube.js"
FIREFOX_YOUTUBE_TUNER="$APP_PATH/Contents/Resources/FirefoxExtension/content/youtube.js"
CHROME_YOUTUBE_STYLE="$APP_PATH/Contents/Resources/ChromeExtension/content/youtube.css"
FIREFOX_YOUTUBE_STYLE="$APP_PATH/Contents/Resources/FirefoxExtension/content/youtube.css"
CHROME_X_PAGE="$APP_PATH/Contents/Resources/ChromeExtension/content/x-page.js"
FIREFOX_X_PAGE="$APP_PATH/Contents/Resources/FirefoxExtension/content/x-page.js"
CHROME_X_TUNER="$APP_PATH/Contents/Resources/ChromeExtension/content/x.js"
FIREFOX_X_TUNER="$APP_PATH/Contents/Resources/FirefoxExtension/content/x.js"
CHROME_PLATFORM_CONTROLS="$APP_PATH/Contents/Resources/ChromeExtension/content/platform-controls.js"
FIREFOX_PLATFORM_CONTROLS="$APP_PATH/Contents/Resources/FirefoxExtension/content/platform-controls.js"
CHROME_WEB_CLASSIFIER="$APP_PATH/Contents/Resources/ChromeExtension/content/web-classifier.js"
FIREFOX_WEB_CLASSIFIER="$APP_PATH/Contents/Resources/FirefoxExtension/content/web-classifier.js"
CHROME_ADULT_DOMAINS="$APP_PATH/Contents/Resources/ChromeExtension/rules/adult-domains.json"
FIREFOX_ADULT_DOMAINS="$APP_PATH/Contents/Resources/FirefoxExtension/rules/adult-domains.json"
CHROME_ADULT_STATIC="$APP_PATH/Contents/Resources/ChromeExtension/rules/adult-static-1.json"
CHROME_REDDIT_TUNER="$APP_PATH/Contents/Resources/ChromeExtension/content/reddit.js"
FIREFOX_REDDIT_TUNER="$APP_PATH/Contents/Resources/FirefoxExtension/content/reddit.js"

[[ -d "$APP_PATH" ]] || fail "QuietGate.app is missing from the DMG."
[[ -e "$APPLICATIONS_LINK" ]] || fail "Applications shortcut is missing from the DMG."
[[ -f "$START_HERE" ]] || fail "Start Here.txt is missing from the DMG."
[[ -x "$NATIVE_HOST" ]] || fail "Bundled native host is missing or not executable."
[[ -f "$CHROME_EXTENSION" ]] || fail "Bundled browser extension manifest is missing."
[[ -f "$FIREFOX_EXTENSION" ]] || fail "Bundled Firefox extension manifest is missing."
[[ -f "$CHROME_BLOCK_PAGE" ]] || fail "Bundled Chrome Helper block page is missing."
[[ -f "$FIREFOX_BLOCK_PAGE" ]] || fail "Bundled Firefox Helper block page is missing."
[[ -f "$CHROME_YOUTUBE_TUNER" ]] || fail "Bundled Chrome YouTube tuner is missing."
[[ -f "$FIREFOX_YOUTUBE_TUNER" ]] || fail "Bundled Firefox YouTube tuner is missing."
[[ -f "$CHROME_YOUTUBE_STYLE" ]] || fail "Bundled Chrome YouTube style is missing."
[[ -f "$FIREFOX_YOUTUBE_STYLE" ]] || fail "Bundled Firefox YouTube style is missing."
[[ -f "$CHROME_X_PAGE" ]] || fail "Bundled Chrome X page detector is missing."
[[ -f "$FIREFOX_X_PAGE" ]] || fail "Bundled Firefox X page detector is missing."
[[ -f "$CHROME_X_TUNER" ]] || fail "Bundled Chrome X tuner is missing."
[[ -f "$FIREFOX_X_TUNER" ]] || fail "Bundled Firefox X tuner is missing."
[[ -f "$CHROME_PLATFORM_CONTROLS" ]] || fail "Bundled Chrome platform controls audit is missing."
[[ -f "$FIREFOX_PLATFORM_CONTROLS" ]] || fail "Bundled Firefox platform controls audit is missing."
[[ -f "$CHROME_WEB_CLASSIFIER" ]] || fail "Bundled Chrome all-web adult classifier is missing."
[[ -f "$FIREFOX_WEB_CLASSIFIER" ]] || fail "Bundled Firefox all-web adult classifier is missing."
[[ -f "$CHROME_ADULT_DOMAINS" ]] || fail "Bundled Chrome adult domain snapshot is missing."
[[ -f "$FIREFOX_ADULT_DOMAINS" ]] || fail "Bundled Firefox adult domain snapshot is missing."
[[ -f "$CHROME_ADULT_STATIC" ]] || fail "Bundled Chrome static adult DNR rules are missing."
[[ -f "$CHROME_REDDIT_TUNER" ]] || fail "Bundled Chrome Reddit tuner is missing."
[[ -f "$FIREFOX_REDDIT_TUNER" ]] || fail "Bundled Firefox Reddit tuner is missing."
grep -q '"content/x-page.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include the X page detector."
grep -q '"content/x-page.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not expose the X page detector."
grep -q '"content/platform-controls.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include platform controls audit."
grep -q '"content/platform-controls.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not include platform controls audit."
grep -q '"content/web-classifier.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include the all-web classifier."
grep -q '"content/web-classifier.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not include the all-web classifier."
grep -q '"rules/adult-static-1.json"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include static adult rules."
grep -q '"rules/adult-domains.json"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not expose the adult domain snapshot."
grep -q '"rules/adult-domains.json"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not expose the adult domain snapshot."
grep -q '"content/reddit.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include the Reddit tuner."
grep -q '"content/reddit.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not include the Reddit tuner."
grep -q '"content/youtube.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include the YouTube tuner."
grep -q '"content/youtube.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not include the YouTube tuner."
grep -q 'youtubeVideoSidebar' "$CHROME_YOUTUBE_TUNER" || fail "Bundled Chrome YouTube tuner is missing expanded sidebar handling."
grep -q 'youtubeEndScreenCards' "$CHROME_YOUTUBE_TUNER" || fail "Bundled Chrome YouTube tuner is missing end-screen card handling."
grep -q 'youtubeSubscriptions' "$CHROME_YOUTUBE_TUNER" || fail "Bundled Chrome YouTube tuner is missing subscriptions handling."
grep -q 'youtubeUsageTracking' "$CHROME_YOUTUBE_TUNER" || fail "Bundled Chrome YouTube tuner is missing usage tracking."
grep -q 'youtubeDailyLimit' "$CHROME_YOUTUBE_TUNER" || fail "Bundled Chrome YouTube tuner is missing daily limit handling."
grep -q 'qg-youtube-video-sidebar' "$CHROME_YOUTUBE_STYLE" || fail "Bundled Chrome YouTube style is missing expanded sidebar selectors."
grep -q 'qg-youtube-end-screen-cards' "$CHROME_YOUTUBE_STYLE" || fail "Bundled Chrome YouTube style is missing end-screen card selectors."
grep -q 'qg-youtube-subscriptions' "$CHROME_YOUTUBE_STYLE" || fail "Bundled Chrome YouTube style is missing subscriptions selectors."
grep -q 'quietgate-youtube-usage' "$CHROME_YOUTUBE_STYLE" || fail "Bundled Chrome YouTube style is missing usage overlay selectors."
grep -q 'quietgate-youtube-limit' "$CHROME_YOUTUBE_STYLE" || fail "Bundled Chrome YouTube style is missing limit overlay selectors."
grep -q 'xExplicitContent' "$CHROME_X_TUNER" || fail "Bundled Chrome X tuner is missing explicit-cue handling."
grep -q 'xExplicitSearch' "$CHROME_X_TUNER" || fail "Bundled Chrome X tuner is missing explicit search handling."
grep -q 'redditNSFW' "$CHROME_REDDIT_TUNER" || fail "Bundled Chrome Reddit tuner is missing NSFW handling."

if ! grep -q "Drag QuietGate into Applications" "$START_HERE"; then
  fail "Start Here.txt does not include the install instruction."
fi

log "Checking app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null

log "Checking native host architecture"
native_host_info="$(file "$NATIVE_HOST")"
if [[ "$native_host_info" != *"x86_64"* ]]; then
  fail "Native host is missing the x86_64 slice."
fi
if [[ "$native_host_info" != *"arm64"* ]]; then
  fail "Native host is missing the arm64 slice."
fi

if ((PUBLIC == 1)); then
  log "Checking mounted app Gatekeeper acceptance"
  spctl -a -vv --type execute "$APP_PATH" >/dev/null
fi

log "Installer DMG passed verification: $DMG_PATH"
