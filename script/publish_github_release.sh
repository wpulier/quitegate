#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_PATH="${1:-}"

usage() {
  cat <<'USAGE'
usage: script/publish_github_release.sh dist/QuietGate-VERSION-BUILD-notarize.dmg

Publishes a notarized QuietGate DMG to GitHub Releases and prints the download URL.
Requires:
  - git origin remote configured
  - gh CLI installed and authenticated
  - a notarized/stapled DMG, not a local preview DMG
USAGE
}

fail() {
  printf '[QuietGate publish] ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[QuietGate publish] %s\n' "$*"
}

if [[ -z "$DMG_PATH" || "${DMG_PATH:-}" == "--help" || "${DMG_PATH:-}" == "-h" ]]; then
  usage
  exit 2
fi

cd "$ROOT_DIR"

[[ -f "$DMG_PATH" ]] || fail "DMG not found: $DMG_PATH"
[[ "$DMG_PATH" != *"-local.dmg" ]] || fail "Refusing to publish a local preview DMG. Build with --notarize first."
command -v gh >/dev/null 2>&1 || fail "GitHub CLI is not installed."
git remote get-url origin >/dev/null 2>&1 || fail "No git origin remote is configured."
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run: gh auth login"

if ! xcrun stapler validate "$DMG_PATH" >/dev/null 2>&1; then
  fail "DMG does not have a valid stapled notarization ticket: $DMG_PATH"
fi

if ! spctl -a -vv --type open "$DMG_PATH" >/dev/null 2>&1; then
  fail "Gatekeeper does not accept this DMG: $DMG_PATH"
fi

filename="$(basename "$DMG_PATH")"
if [[ "$filename" =~ ^QuietGate-([^-]+)-([^-]+)-notarize\.dmg$ ]]; then
  version="${BASH_REMATCH[1]}"
  build="${BASH_REMATCH[2]}"
else
  fail "DMG filename must look like QuietGate-VERSION-BUILD-notarize.dmg"
fi

tag="v${version}-${build}"
sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
notes_file="$(mktemp)"
asset_dir="$(mktemp -d)"
trap 'rm -f "$notes_file"; rm -rf "$asset_dir"' EXIT
stable_dmg="$asset_dir/QuietGate.dmg"
stable_sha="$asset_dir/QuietGate.dmg.sha256"
versioned_sha="$asset_dir/$filename.sha256"
repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
asset_url="https://github.com/$repo/releases/download/$tag/$filename"
stable_url="https://github.com/$repo/releases/latest/download/QuietGate.dmg"

cp "$DMG_PATH" "$stable_dmg"
printf '%s  %s\n' "$sha256" "$filename" > "$versioned_sha"
printf '%s  QuietGate.dmg\n' "$sha256" > "$stable_sha"

cat > "$notes_file" <<NOTES
QuietGate ${version} build ${build}

Install:
1. Download the DMG.
2. Open it.
3. Drag QuietGate to Applications.
4. Open QuietGate and follow Setup.

SHA-256:
${sha256}

Stable latest download:
${stable_url}

Versioned download:
${asset_url}
NOTES

if gh release view "$tag" >/dev/null 2>&1; then
  fail "Release already exists: $tag"
fi

log "Creating GitHub Release $tag"
gh release create "$tag" "$DMG_PATH" "$versioned_sha" "$stable_dmg" "$stable_sha" \
  --title "QuietGate ${version} (${build})" \
  --notes-file "$notes_file"

release_url="$(gh release view "$tag" --json url --jq '.url')"

log "Release page: $release_url"
log "Direct download: $asset_url"
log "Stable latest download: $stable_url"
