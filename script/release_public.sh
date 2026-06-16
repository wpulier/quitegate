#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="QuietGate"
RUN_TESTS=1
NOTARY_PROFILE="${QUIETGATE_NOTARY_PROFILE:-quietgate-notary}"

usage() {
  cat <<'USAGE'
usage: script/release_public.sh [--skip-tests]

Builds, notarizes, verifies, and publishes the public QuietGate DMG.

Requires:
  - Developer ID Application certificate installed
  - notarytool credentials saved in QUIETGATE_NOTARY_PROFILE, default quietgate-notary
  - git origin remote configured
  - gh CLI installed and authenticated

The published GitHub Release includes:
  - versioned DMG: QuietGate-VERSION-BUILD-notarize.dmg
  - stable DMG: QuietGate.dmg
USAGE
}

log() {
  printf '[QuietGate public release] %s\n' "$*"
}

fail() {
  printf '[QuietGate public release] ERROR: %s\n' "$*" >&2
  exit 1
}

latest_notarized_dmg() {
  find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME-*-notarize.dmg" -print 2>/dev/null |
    while IFS= read -r path; do
      printf '%s\t%s\n' "$(stat -f '%m' "$path")" "$path"
    done |
    sort -rn |
    awk 'NR == 1 {print $2}'
}

while (($# > 0)); do
  case "$1" in
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

cd "$ROOT_DIR"

log "Checking public release prerequisites"
QUIETGATE_NOTARY_PROFILE="$NOTARY_PROFILE" "$ROOT_DIR/script/release_status.sh"

package_args=(--notarize)
if [[ "$RUN_TESTS" == "0" ]]; then
  package_args+=(--skip-tests)
fi

log "Building and notarizing public installer"
QUIETGATE_NOTARY_PROFILE="$NOTARY_PROFILE" "$ROOT_DIR/script/package_public_release.sh" "${package_args[@]}"

dmg_path="$(latest_notarized_dmg)"
if [[ -z "$dmg_path" || ! -f "$dmg_path" ]]; then
  fail "No notarized DMG was produced."
fi

log "Verifying notarized installer"
"$ROOT_DIR/script/verify_installer_dmg.sh" --public "$dmg_path"

log "Publishing GitHub Release"
"$ROOT_DIR/script/publish_github_release.sh" "$dmg_path"

repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
log "Public download URL: https://github.com/$repo/releases/latest/download/QuietGate.dmg"
