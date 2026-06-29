#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/ChromeExtension"
DIST_DIR="$ROOT_DIR/dist/chrome-store"
ZIP_PATH="$ROOT_DIR/dist/quietgate-chrome-store.zip"
VERIFY_ONLY=0

if [[ "${1:-}" == "--verify" ]]; then
  VERIFY_ONLY=1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$SOURCE_DIR"/. "$DIST_DIR"/

node "$ROOT_DIR/script/generate_chrome_store_assets.mjs" "$ROOT_DIR"
node "$ROOT_DIR/script/rewrite_chrome_store_manifest.mjs" "$DIST_DIR/manifest.json"

node --check "$DIST_DIR/background.js"
node --check "$DIST_DIR/popup/popup.js"
node --check "$DIST_DIR/content/x-page.js"
node --check "$DIST_DIR/content/x.js"
node --check "$DIST_DIR/content/reddit.js"
node --check "$DIST_DIR/content/youtube.js"
node --check "$DIST_DIR/content/instagram.js"
node --check "$DIST_DIR/content/web-classifier.js"

node "$ROOT_DIR/script/verify_chrome_store_extension.mjs" "$DIST_DIR"

if [[ "$VERIFY_ONLY" == "0" ]]; then
  rm -f "$ZIP_PATH"
  (cd "$DIST_DIR" && zip -qr "$ZIP_PATH" .)
  echo "Created $ZIP_PATH"
else
  echo "Verified $DIST_DIR"
fi
