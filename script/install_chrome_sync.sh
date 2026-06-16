#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_NAME="com.willpulier.quietgate"
CHROMIUM_EXTENSION_ID="fedpnejbgmllajjlfkahlnjbgfmjjmmf"
FIREFOX_EXTENSION_ID="quietgate@willpulier.com"

APP_SUPPORT_DIR="$HOME/Library/Application Support/QuietGate"
HOST_DIR="$APP_SUPPORT_DIR/NativeHost"
CHROME_HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
EDGE_HOSTS_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
BRAVE_HOSTS_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
ARC_HOSTS_DIR="$HOME/Library/Application Support/Arc/User Data/NativeMessagingHosts"
FIREFOX_HOSTS_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"

"$ROOT_DIR/script/build_native_host.sh"

install -d "$HOST_DIR" "$CHROME_HOSTS_DIR" "$EDGE_HOSTS_DIR" "$BRAVE_HOSTS_DIR" "$ARC_HOSTS_DIR" "$FIREFOX_HOSTS_DIR"
install -m 755 "$ROOT_DIR/NativeHost/build/quietgate-native-host" "$HOST_DIR/quietgate-native-host"

TMP_CHROMIUM_MANIFEST="$(mktemp)"
TMP_FIREFOX_MANIFEST="$(mktemp)"
trap 'rm -f "$TMP_CHROMIUM_MANIFEST" "$TMP_FIREFOX_MANIFEST"' EXIT

cat > "$TMP_CHROMIUM_MANIFEST" <<JSON
{
  "allowed_origins": [
    "chrome-extension://$CHROMIUM_EXTENSION_ID/"
  ],
  "description": "QuietGate browser settings bridge",
  "name": "$HOST_NAME",
  "path": "$HOST_DIR/quietgate-native-host",
  "type": "stdio"
}
JSON

cat > "$TMP_FIREFOX_MANIFEST" <<JSON
{
  "allowed_extensions": [
    "$FIREFOX_EXTENSION_ID"
  ],
  "description": "QuietGate Firefox settings bridge",
  "name": "$HOST_NAME",
  "path": "$HOST_DIR/quietgate-native-host",
  "type": "stdio"
}
JSON

for HOSTS_DIR in "$CHROME_HOSTS_DIR" "$EDGE_HOSTS_DIR" "$BRAVE_HOSTS_DIR" "$ARC_HOSTS_DIR"; do
  install -m 644 "$TMP_CHROMIUM_MANIFEST" "$HOSTS_DIR/$HOST_NAME.json"
done
install -m 644 "$TMP_FIREFOX_MANIFEST" "$FIREFOX_HOSTS_DIR/$HOST_NAME.json"

echo "Installed QuietGate browser automatic updates host:"
echo "$HOST_DIR/quietgate-native-host"
echo "$CHROME_HOSTS_DIR/$HOST_NAME.json"
echo "$EDGE_HOSTS_DIR/$HOST_NAME.json"
echo "$BRAVE_HOSTS_DIR/$HOST_NAME.json"
echo "$ARC_HOSTS_DIR/$HOST_NAME.json"
echo "$FIREFOX_HOSTS_DIR/$HOST_NAME.json"
