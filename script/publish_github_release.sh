#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_PATH="${1:-}"

usage() {
  cat <<'USAGE'
usage: script/publish_github_release.sh dist/Tortoise-VERSION-BUILD-notarize.dmg

Publishes a notarized Tortoise DMG to GitHub Releases and prints the download URL.
Requires:
  - git origin remote configured
  - gh CLI installed and authenticated
  - Sparkle's sign_update tool and the Tortoise signing key in Keychain
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

find_sparkle_sign_update() {
  local candidate

  if [[ -n "${SPARKLE_SIGN_UPDATE:-}" && -x "${SPARKLE_SIGN_UPDATE}" ]]; then
    printf '%s\n' "$SPARKLE_SIGN_UPDATE"
    return 0
  fi

  for candidate in \
    "$ROOT_DIR/build/PublicRelease/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" \
    "$ROOT_DIR/build/SparkleSetup/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
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
sign_update="$(find_sparkle_sign_update)" \
  || fail "Sparkle sign_update was not found. Resolve the Sparkle package first or set SPARKLE_SIGN_UPDATE."

"$ROOT_DIR/script/verify_installer_dmg.sh" --public "$DMG_PATH" >/dev/null

filename="$(basename "$DMG_PATH")"
if [[ "$filename" =~ ^(Tortoise|QuietGate)-([^-]+)-([^-]+)-notarize\.dmg$ ]]; then
  app_name="${BASH_REMATCH[1]}"
  version="${BASH_REMATCH[2]}"
  build="${BASH_REMATCH[3]}"
else
  fail "DMG filename must look like Tortoise-VERSION-BUILD-notarize.dmg"
fi

tag="v${version}-${build}"
feed_tag="macos-appcast"
sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
notes_file="$(mktemp)"
asset_dir="$(mktemp -d)"
trap 'rm -f "$notes_file"; rm -rf "$asset_dir"' EXIT
stable_dmg="$asset_dir/Tortoise.dmg"
stable_sha="$asset_dir/Tortoise.dmg.sha256"
legacy_dmg="$asset_dir/QuietGate.dmg"
legacy_sha="$asset_dir/QuietGate.dmg.sha256"
versioned_sha="$asset_dir/$filename.sha256"
appcast="$asset_dir/appcast.xml"
repo="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
target_commit="$(git rev-parse HEAD)"
asset_url="https://github.com/$repo/releases/download/$tag/$filename"
sparkle_asset_url="https://github.com/$repo/releases/download/$tag/Tortoise.dmg"
stable_url="https://github.com/$repo/releases/latest/download/Tortoise.dmg"
legacy_url="https://github.com/$repo/releases/latest/download/QuietGate.dmg"

cp "$DMG_PATH" "$stable_dmg"
cp "$DMG_PATH" "$legacy_dmg"
printf '%s  %s\n' "$sha256" "$filename" > "$versioned_sha"
printf '%s  Tortoise.dmg\n' "$sha256" > "$stable_sha"
printf '%s  QuietGate.dmg\n' "$sha256" > "$legacy_sha"

signature_attributes="$(
  "$sign_update" --account com.yourtortoise.Tortoise "$stable_dmg"
)" || fail "Sparkle could not sign the update. Confirm the Tortoise Ed25519 key is available in Keychain."
ed_signature="$(printf '%s\n' "$signature_attributes" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
file_length="$(printf '%s\n' "$signature_attributes" | sed -n 's/.*length="\([0-9]*\)".*/\1/p')"
[[ -n "$ed_signature" && -n "$file_length" ]] \
  || fail "Sparkle returned an unexpected signature: $signature_attributes"

pub_date="$(LC_ALL=C date -R)"
cat > "$appcast" <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Tortoise Updates</title>
    <link>https://www.yourtortoise.com</link>
    <description>Signed updates for Tortoise on macOS.</description>
    <language>en</language>
    <item>
      <title>Tortoise ${version} (${build})</title>
      <pubDate>${pub_date}</pubDate>
      <sparkle:version>${build}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="${sparkle_asset_url}"
        length="${file_length}"
        type="application/octet-stream"
        sparkle:edSignature="${ed_signature}" />
    </item>
  </channel>
</rss>
APPCAST

cat > "$notes_file" <<NOTES
Tortoise ${version} build ${build}

Install:
- Existing users on build 20 or newer update inside Tortoise; it installs and relaunches automatically.
- For a first install, download the DMG, drag Tortoise to Applications, and open it.

SHA-256:
${sha256}

Stable latest download:
${stable_url}

Legacy latest download:
${legacy_url}

Versioned download:
${asset_url}
NOTES

if gh release view "$tag" >/dev/null 2>&1; then
  fail "Release already exists: $tag"
fi

log "Creating GitHub Release $tag"
gh release create "$tag" "$DMG_PATH" "$versioned_sha" "$stable_dmg" "$stable_sha" "$legacy_dmg" "$legacy_sha" "$appcast" \
  --target "$target_commit" \
  --title "Tortoise ${version} (${build})" \
  --notes-file "$notes_file"

release_url="$(gh release view "$tag" --json url --jq '.url')"

if gh release view "$feed_tag" >/dev/null 2>&1; then
  log "Updating stable Sparkle feed"
  gh release upload "$feed_tag" "$appcast" --clobber
else
  log "Creating stable Sparkle feed"
  gh release create "$feed_tag" "$appcast" \
    --title "Tortoise macOS update feed" \
    --notes "Machine-readable signed update feed for the Tortoise macOS app." \
    --prerelease
fi

log "Release page: $release_url"
log "Direct download: $asset_url"
log "Stable latest download: $stable_url"
log "Legacy latest download: $legacy_url"
