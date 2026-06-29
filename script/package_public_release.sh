#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuietGate"
SCHEME="QuietGate"
BUNDLE_ID="com.willpulier.QuietGate"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/QuietGate.xcodeproj"
BUILD_ROOT="$ROOT_DIR/build/PublicRelease"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
DMG_ROOT="$BUILD_ROOT/dmg-root"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
NATIVE_HOST="$APP_BUNDLE/Contents/Resources/quietgate-native-host"
CHROME_EXTENSION="$APP_BUNDLE/Contents/Resources/ChromeExtension/manifest.json"
FIREFOX_EXTENSION="$APP_BUNDLE/Contents/Resources/FirefoxExtension/manifest.json"
CHROME_BLOCK_PAGE="$APP_BUNDLE/Contents/Resources/ChromeExtension/blocked/blocked.html"
FIREFOX_BLOCK_PAGE="$APP_BUNDLE/Contents/Resources/FirefoxExtension/blocked/blocked.html"
CHROME_YOUTUBE_TUNER="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/youtube.js"
FIREFOX_YOUTUBE_TUNER="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/youtube.js"
CHROME_YOUTUBE_STYLE="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/youtube.css"
FIREFOX_YOUTUBE_STYLE="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/youtube.css"
CHROME_X_PAGE="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/x-page.js"
FIREFOX_X_PAGE="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/x-page.js"
CHROME_X_TUNER="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/x.js"
FIREFOX_X_TUNER="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/x.js"
CHROME_INSTAGRAM_TUNER="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/instagram.js"
FIREFOX_INSTAGRAM_TUNER="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/instagram.js"
CHROME_PLATFORM_CONTROLS="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/platform-controls.js"
FIREFOX_PLATFORM_CONTROLS="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/platform-controls.js"
CHROME_WEB_CLASSIFIER="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/web-classifier.js"
FIREFOX_WEB_CLASSIFIER="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/web-classifier.js"
CHROME_ADULT_DOMAINS="$APP_BUNDLE/Contents/Resources/ChromeExtension/rules/adult-domains.json"
FIREFOX_ADULT_DOMAINS="$APP_BUNDLE/Contents/Resources/FirefoxExtension/rules/adult-domains.json"
CHROME_ADULT_STATIC="$APP_BUNDLE/Contents/Resources/ChromeExtension/rules/adult-static-1.json"
CHROME_REDDIT_TUNER="$APP_BUNDLE/Contents/Resources/ChromeExtension/content/reddit.js"
FIREFOX_REDDIT_TUNER="$APP_BUNDLE/Contents/Resources/FirefoxExtension/content/reddit.js"
FORBIDDEN_PUBLIC_ONBOARDING_REGEX='nextdns|Profile ID|API key|private access code|public setup code|legacy provider|blocking account|provider key|provider setup|provider connection'

MODE="local"
RUN_TESTS=1
APP_SIGN_IDENTITY="${QUIETGATE_APP_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${QUIETGATE_NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${QUIETGATE_APPLE_TEAM_ID:-V558WV68AM}}"
APPLE_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

usage() {
  cat <<'USAGE'
usage: script/package_public_release.sh [--local|--signed|--notarize] [--skip-tests]

Modes:
  --local      Build an ad-hoc signed DMG for local install testing. Default.
  --signed     Require a Developer ID Application identity and sign the app/DMG.
  --notarize   Sign, submit to Apple notarization, staple, and validate Gatekeeper.

Environment:
  QUIETGATE_APP_SIGN_IDENTITY       Developer ID Application identity. Auto-detected if omitted.
  QUIETGATE_NOTARY_PROFILE          notarytool keychain profile, preferred for --notarize.
  APPLE_ID                          Apple ID for notarytool when no profile is supplied.
  APPLE_APP_SPECIFIC_PASSWORD       App-specific password for notarytool.
  QUIETGATE_APPLE_TEAM_ID           Apple team ID. Defaults to V558WV68AM.
USAGE
}

while (($# > 0)); do
  case "$1" in
    --local)
      MODE="local"
      ;;
    --signed)
      MODE="signed"
      ;;
    --notarize)
      MODE="notarize"
      ;;
    --skip-tests)
      RUN_TESTS=0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

log() {
  printf '[QuietGate release] %s\n' "$*"
}

fail() {
  printf '[QuietGate release] ERROR: %s\n' "$*" >&2
  exit 1
}

verify_public_onboarding_strings() {
  log "Checking public app for removed onboarding strings"
  local binary="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  local hits
  hits="$(mktemp)"

  if /usr/bin/strings "$binary" | /usr/bin/grep -E -i "$FORBIDDEN_PUBLIC_ONBOARDING_REGEX" >"$hits"; then
    /usr/bin/head -20 "$hits" >&2
    rm -f "$hits"
    fail "Public app still contains removed onboarding strings."
  fi

  if /usr/bin/grep -R -I -E -i "$FORBIDDEN_PUBLIC_ONBOARDING_REGEX" "$APP_BUNDLE" >"$hits"; then
    /usr/bin/head -20 "$hits" >&2
    rm -f "$hits"
    fail "Public app bundle still contains removed onboarding strings."
  fi

  rm -f "$hits"
}

verify_public_installer_text() {
  log "Checking public installer text for removed onboarding strings"
  local hits
  hits="$(mktemp)"

  if /usr/bin/grep -R -I -E -i "$FORBIDDEN_PUBLIC_ONBOARDING_REGEX" "$DMG_ROOT" >"$hits"; then
    /usr/bin/head -20 "$hits" >&2
    rm -f "$hits"
    fail "Public installer still contains removed onboarding strings."
  fi

  rm -f "$hits"
}

detect_developer_id_application() {
  security find-identity -v -p codesigning |
    sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' |
    head -n 1
}

require_public_signing() {
  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    APP_SIGN_IDENTITY="$(detect_developer_id_application)"
  fi

  if [[ -z "$APP_SIGN_IDENTITY" ]]; then
    fail "No Developer ID Application certificate is installed. Install it, or run --local for a preview DMG."
  fi
}

if [[ "$MODE" == "signed" || "$MODE" == "notarize" ]]; then
  require_public_signing
fi

if [[ "$MODE" == "notarize" && -z "$NOTARY_PROFILE" ]]; then
  if [[ -z "$APPLE_ID" || -z "$APPLE_PASSWORD" || -z "$APPLE_TEAM_ID" ]]; then
    fail "Notarization needs QUIETGATE_NOTARY_PROFILE or APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and QUIETGATE_APPLE_TEAM_ID."
  fi
fi

mkdir -p "$BUILD_ROOT" "$DIST_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  log "Regenerating Xcode project from project.yml"
  xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR" >/dev/null
fi

log "Building universal native host"
"$ROOT_DIR/script/build_native_host.sh"

if [[ "$RUN_TESTS" == "1" ]]; then
  log "Running tests"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    test
fi

log "Building Release app"
BUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration Release
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED_DATA"
  clean build
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
)

if [[ "$MODE" == "local" ]]; then
  BUILD_ARGS+=(CODE_SIGN_IDENTITY="-")
else
  BUILD_ARGS+=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" OTHER_CODE_SIGN_FLAGS="--timestamp")
fi

xcodebuild "${BUILD_ARGS[@]}"

[[ -d "$APP_BUNDLE" ]] || fail "Release app was not produced at $APP_BUNDLE"
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
[[ -f "$CHROME_INSTAGRAM_TUNER" ]] || fail "Bundled Chrome Instagram tuner is missing."
[[ -f "$FIREFOX_INSTAGRAM_TUNER" ]] || fail "Bundled Firefox Instagram tuner is missing."
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
grep -q '"content/instagram.js"' "$CHROME_EXTENSION" || fail "Bundled Chrome manifest does not include the Instagram tuner."
grep -q '"content/instagram.js"' "$FIREFOX_EXTENSION" || fail "Bundled Firefox manifest does not include the Instagram tuner."
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
grep -q 'quietgateInstagramTunerVersion' "$CHROME_INSTAGRAM_TUNER" || fail "Bundled Chrome Instagram tuner is missing version reporting."
grep -q 'quietgateInstagramTunerVersion' "$FIREFOX_INSTAGRAM_TUNER" || fail "Bundled Firefox Instagram tuner is missing version reporting."
grep -q 'redditNSFW' "$CHROME_REDDIT_TUNER" || fail "Bundled Chrome Reddit tuner is missing NSFW handling."

if ! file "$NATIVE_HOST" | grep -q "x86_64"; then
  fail "Native host is not universal; x86_64 slice is missing."
fi
if ! file "$NATIVE_HOST" | grep -q "arm64"; then
  fail "Native host is not universal; arm64 slice is missing."
fi

if [[ "$MODE" == "local" ]]; then
  log "Applying local ad-hoc signatures"
  codesign --force --options runtime --sign - "$NATIVE_HOST"
  codesign --force --options runtime --sign - "$APP_BUNDLE"
else
  log "Applying Developer ID signatures"
  codesign --force --timestamp --options runtime --sign "$APP_SIGN_IDENTITY" "$NATIVE_HOST"
  codesign --force --timestamp --options runtime --sign "$APP_SIGN_IDENTITY" "$APP_BUNDLE"
fi

log "Validating app bundle signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
verify_public_onboarding_strings

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
DMG_SUFFIX="$MODE"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-$BUILD_NUMBER-$DMG_SUFFIX.dmg"

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

cat > "$DMG_ROOT/Start Here.txt" <<TXT
QuietGate

1. Drag QuietGate into Applications.
2. Open QuietGate.
3. Connect one supported browser when QuietGate asks.
4. Home unlocks after QuietGate confirms the browser connection.

Browser Helper powers website blocking and YouTube cleanup in Chrome, Edge, Brave, Arc, and Firefox.
TXT

verify_public_installer_text

rm -f "$DMG_PATH"
log "Creating DMG at $DMG_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

if [[ "$MODE" == "signed" || "$MODE" == "notarize" ]]; then
  log "Signing DMG"
  codesign --force --timestamp --sign "$APP_SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ "$MODE" == "notarize" ]]; then
  log "Submitting DMG for notarization"
  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" \
      --wait
  fi

  log "Stapling notarization ticket"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl -a -vv --type open "$DMG_PATH"
  log "Verifying public installer contents"
  "$ROOT_DIR/script/verify_installer_dmg.sh" --public "$DMG_PATH"
else
  log "Verifying installer contents"
  "$ROOT_DIR/script/verify_installer_dmg.sh" "$DMG_PATH"
  log "Created a $MODE DMG. This is not a public-ready notarized installer."
fi

log "Done: $DMG_PATH"
