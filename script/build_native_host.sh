#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/NativeHost/QuietGateNativeHost.swift"
OUTPUT_DIR="$ROOT_DIR/NativeHost/build"
OUTPUT="$OUTPUT_DIR/quietgate-native-host"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"
ARM64_OUTPUT="$OUTPUT_DIR/quietgate-native-host-arm64"
X86_64_OUTPUT="$OUTPUT_DIR/quietgate-native-host-x86_64"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -sdk "$SDKROOT" \
  -target "arm64-apple-macos$DEPLOYMENT_TARGET" \
  "$SOURCE" \
  -o "$ARM64_OUTPUT"

swiftc \
  -sdk "$SDKROOT" \
  -target "x86_64-apple-macos$DEPLOYMENT_TARGET" \
  "$SOURCE" \
  -o "$X86_64_OUTPUT"

lipo -create "$ARM64_OUTPUT" "$X86_64_OUTPUT" -output "$OUTPUT"
rm -f "$ARM64_OUTPUT" "$X86_64_OUTPUT"
chmod 755 "$OUTPUT"
