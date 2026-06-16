#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTIFICATE_PATH="${1:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-${QUIETGATE_APPLE_TEAM_ID:-V558WV68AM}}"

usage() {
  cat <<'USAGE'
usage: script/configure_github_release_secrets.sh path/to/DeveloperIDApplication.p12

Writes the GitHub Actions secrets required by .github/workflows/release-macos.yml.

Required environment:
  DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD   Password for the exported .p12
  APPLE_ID                                        Apple ID email for notarization
  APPLE_APP_SPECIFIC_PASSWORD                     App-specific Apple ID password

Optional environment:
  APPLE_TEAM_ID                                   Apple Developer team ID
  QUIETGATE_APPLE_TEAM_ID                         Fallback Apple Developer team ID
  MACOS_SIGNING_KEYCHAIN_PASSWORD                 Temporary CI keychain password

Requires:
  - gh CLI installed and authenticated
  - git origin remote configured
USAGE
}

log() {
  printf '[QuietGate GitHub secrets] %s\n' "$*"
}

fail() {
  printf '[QuietGate GitHub secrets] ERROR: %s\n' "$*" >&2
  exit 1
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    fail "Missing required environment variable: $name"
  fi
}

set_secret() {
  local name="$1"
  local value="$2"
  gh secret set "$name" --body "$value" >/dev/null
  log "Set $name"
}

if [[ "$CERTIFICATE_PATH" == "--help" || "$CERTIFICATE_PATH" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "$CERTIFICATE_PATH" ]]; then
  usage
  exit 2
fi

cd "$ROOT_DIR"

[[ -f "$CERTIFICATE_PATH" ]] || fail "Certificate file not found: $CERTIFICATE_PATH"
command -v gh >/dev/null 2>&1 || fail "GitHub CLI is not installed."
git remote get-url origin >/dev/null 2>&1 || fail "No git origin remote is configured."
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated. Run: gh auth login"

require_env DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
require_env APPLE_ID
require_env APPLE_APP_SPECIFIC_PASSWORD

if [[ -z "${MACOS_SIGNING_KEYCHAIN_PASSWORD:-}" ]]; then
  MACOS_SIGNING_KEYCHAIN_PASSWORD="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  log "Generated MACOS_SIGNING_KEYCHAIN_PASSWORD for the temporary CI keychain."
fi

if command -v openssl >/dev/null 2>&1; then
  if ! openssl pkcs12 \
    -in "$CERTIFICATE_PATH" \
    -nokeys \
    -passin "pass:$DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD" \
    -info \
    -noout >/dev/null 2>&1; then
    fail "The .p12 file could not be opened with DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD."
  fi
fi

certificate_base64="$(base64 < "$CERTIFICATE_PATH" | tr -d '\n')"

log "Writing release secrets for $(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
set_secret DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64 "$certificate_base64"
set_secret DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD "$DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD"
set_secret MACOS_SIGNING_KEYCHAIN_PASSWORD "$MACOS_SIGNING_KEYCHAIN_PASSWORD"
set_secret APPLE_ID "$APPLE_ID"
set_secret APPLE_APP_SPECIFIC_PASSWORD "$APPLE_APP_SPECIFIC_PASSWORD"
set_secret APPLE_TEAM_ID "$APPLE_TEAM_ID"

log "Done. Push a version tag or run the Release macOS workflow to publish QuietGate."
