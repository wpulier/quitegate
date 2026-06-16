#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOSTS_PATH="${QG_HOSTS_PATH:-/etc/hosts}"
PROFILE="${QG_CHROME_PROFILE:-}"
EXTENSION_DIR="${QG_CHROME_EXTENSION_DIR:-$ROOT_DIR/ChromeExtension}"

MARKER_BEGIN="# QuietGate blocklist begin"
MARKER_END="# QuietGate blocklist end"

fail() {
  echo "green_now: $*" >&2
  exit 1
}

apple_script_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

swift_adult_domains() {
  awk '
    /static let domains = \[/ { in_list=1; next }
    in_list && /\]/ { exit }
    in_list {
      gsub(/[", ]/, "")
      if (length($0) > 0) print $0
    }
  ' "$ROOT_DIR/QuietGate/Models/AdultContentPreset.swift"
}

saved_custom_domains() {
  /usr/bin/python3 - <<'PY'
import plistlib
import subprocess
import sys

try:
    data = subprocess.check_output(
        ["/usr/bin/defaults", "export", "com.willpulier.QuietGate", "-"],
        stderr=subprocess.DEVNULL,
    )
    prefs = plistlib.loads(data)
except Exception:
    sys.exit(0)

rules = prefs.get("quietgate.blockedSites")
if isinstance(rules, list):
    for rule in rules:
        if not isinstance(rule, dict):
            continue
        domain = str(rule.get("domain", "")).strip()
        if domain and bool(rule.get("isEnabled", True)):
            print(domain)
    sys.exit(0)

legacy = prefs.get("quietgate.customDomains", [])
if isinstance(legacy, list):
    for domain in legacy:
        value = str(domain).strip()
        if value:
            print(value)
PY
}

adult_category_enabled() {
  /usr/bin/python3 - <<'PY'
import plistlib
import subprocess
import sys

try:
    data = subprocess.check_output(
        ["/usr/bin/defaults", "export", "com.willpulier.QuietGate", "-"],
        stderr=subprocess.DEVNULL,
    )
    prefs = plistlib.loads(data)
except Exception:
    print("false")
    sys.exit(0)

rules = prefs.get("quietgate.blockCategories")
if isinstance(rules, list):
    for rule in rules:
        if isinstance(rule, dict) and rule.get("id") == "adultContent":
            print("true" if bool(rule.get("isEnabled", False)) else "false")
            sys.exit(0)

mode = str(prefs.get("quietgate.accessMode", "open"))
print("true" if mode in {"focus", "strict"} else "false")
PY
}

write_hosts_payload() {
  local payload_path="$1"
  {
    if [[ "$(adult_category_enabled)" == "true" ]]; then
      swift_adult_domains
    fi
    saved_custom_domains
  } |
    awk 'NF { print tolower($0) }' |
    sort -u |
    while IFS= read -r domain; do
      printf '%s\n' "$domain"
      case "$domain" in
        www.*) ;;
        *) printf 'www.%s\n' "$domain" ;;
      esac
      case "$domain" in
        m.*) ;;
        *) printf 'm.%s\n' "$domain" ;;
      esac
    done |
    sort -u |
    awk '{ print "0.0.0.0 " $0 "\n::1 " $0 }' > "$payload_path"

  [[ -s "$payload_path" ]] || fail "no fallback block domains were found"
}

write_hosts_installer() {
  local script_path="$1"
  cat > "$script_path" <<'INSTALLER'
#!/usr/bin/env bash
set -euo pipefail

HOSTS="$1"
PAYLOAD="$2"
MARKER_BEGIN="# QuietGate blocklist begin"
MARKER_END="# QuietGate blocklist end"
TMP="$(mktemp)"
BACKUP="${HOSTS}.quietgate.$(date +%Y%m%d%H%M%S).bak"

cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT

if [[ -f "$HOSTS" ]]; then
  cp "$HOSTS" "$BACKUP"
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$HOSTS" > "$TMP"
else
  : > "$TMP"
fi

printf '\n%s\n' "$MARKER_BEGIN" >> "$TMP"
cat "$PAYLOAD" >> "$TMP"
printf '%s\n' "$MARKER_END" >> "$TMP"

install -m 644 "$TMP" "$HOSTS"
dscacheutil -flushcache >/dev/null 2>&1 || true
killall -HUP mDNSResponder >/dev/null 2>&1 || true
INSTALLER
  chmod 700 "$script_path"
}

hosts_fallback_installed() {
  [[ -f "$HOSTS_PATH" ]] &&
    grep -qxF "$MARKER_BEGIN" "$HOSTS_PATH" &&
    grep -qxF "$MARKER_END" "$HOSTS_PATH"
}

install_hosts_fallback() {
  if [[ "${QG_FORCE_HOSTS:-0}" != "1" ]] && hosts_fallback_installed; then
    echo "QuietGate local hosts fallback is already installed in $HOSTS_PATH"
    return
  fi

  local payload_path
  local script_path
  payload_path="$(mktemp)"
  script_path="$(mktemp)"

  write_hosts_payload "$payload_path"
  write_hosts_installer "$script_path"

  if [[ "$HOSTS_PATH" != "/etc/hosts" ]]; then
    "$script_path" "$HOSTS_PATH" "$payload_path"
    echo "Installed QuietGate local hosts fallback in $HOSTS_PATH"
    rm -f "$payload_path" "$script_path"
    return
  fi

  if [[ "${QG_SKIP_ADMIN:-0}" == "1" ]]; then
    rm -f "$payload_path" "$script_path"
    fail "/etc/hosts requires admin approval; rerun without QG_SKIP_ADMIN or use the app Install Fallback button"
  fi

  local quoted_script quoted_hosts quoted_payload command
  quoted_script="$(printf '%q' "$script_path")"
  quoted_hosts="$(printf '%q' "$HOSTS_PATH")"
  quoted_payload="$(printf '%q' "$payload_path")"
  command="/bin/bash $quoted_script $quoted_hosts $quoted_payload"
  /usr/bin/osascript -e "do shell script $(apple_script_string "$command") with administrator privileges"
  echo "Installed QuietGate local hosts fallback in /etc/hosts"
  rm -f "$payload_path" "$script_path"
}

selected_chrome_profile() {
  if [[ -n "$PROFILE" ]]; then
    printf '%s\n' "$PROFILE"
    return
  fi

  /usr/bin/python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / "Library" / "Application Support" / "Google" / "Chrome" / "Local State"
try:
    value = json.loads(path.read_text()).get("profile", {}).get("last_used") or "Default"
except Exception:
    value = "Default"
print(value)
PY
}

wait_for_chrome_to_quit() {
  for _ in {1..40}; do
    if ! /usr/bin/pgrep -x "Google Chrome" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

start_chrome_tuner_session() {
  [[ -d "$EXTENSION_DIR" ]] || fail "Browser extension folder not found: $EXTENSION_DIR"

  "$ROOT_DIR/script/install_chrome_sync.sh"

  if [[ "${QG_SKIP_CHROME:-0}" == "1" ]]; then
    echo "Skipped Chrome restart because QG_SKIP_CHROME=1"
    return
  fi

  local profile
  profile="$(selected_chrome_profile)"

  if /usr/bin/pgrep -x "Google Chrome" >/dev/null 2>&1; then
    if [[ "${QG_ALLOW_CHROME_RESTART:-0}" != "1" ]]; then
      echo "Chrome is already running; QuietGate will not close it automatically."
      echo "Quit Chrome yourself and rerun, or set QG_ALLOW_CHROME_RESTART=1 if you explicitly want this script to restart Chrome."
      return
    fi
    /usr/bin/osascript -e 'tell application id "com.google.Chrome" to quit' >/dev/null 2>&1 || true
    wait_for_chrome_to_quit || fail "Chrome did not quit; close Chrome and rerun this script"
  fi

  /usr/bin/open -na "Google Chrome" --args \
    "--profile-directory=$profile" \
    "--load-extension=$EXTENSION_DIR" \
    "https://www.youtube.com/"

  echo "Started Chrome with QuietGate tuner in profile $profile"
}

main() {
  install_hosts_fallback
  start_chrome_tuner_session
  sleep "${QG_GREEN_NOW_VERIFY_DELAY:-1}"
  "$ROOT_DIR/script/check_real_setup.js"
}

main "$@"
