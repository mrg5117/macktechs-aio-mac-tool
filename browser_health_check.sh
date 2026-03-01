#!/usr/bin/env zsh
#
# Macktechs Browser Health Check
# Runs on macOS 11+ (Intel and Apple Silicon).
# Use from Terminal or wrap in Automator/Platypus.
#
set -u

# ---------------------------------------------------------------------------
# 1. Version Gate (Compatibility Check)
# ---------------------------------------------------------------------------
MIN_VER="11.0"
MACOS_VER=$(sw_vers -productVersion 2>/dev/null || echo "0")

# Compare version strings using sort -V (version sort).
version_lt() {
  local a="$1" b="$2"
  [[ -z "$a" || -z "$b" ]] && return 1
  [[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" == "$a" ]] && [[ "$a" != "$b" ]]
}

if version_lt "$MACOS_VER" "$MIN_VER"; then
  osascript -e "display alert \"Macktechs Browser Health Check\" message \"Your macOS version ($MACOS_VER) is not supported. This tool requires macOS 11.0 or later.\" as critical"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Report File Setup
# ---------------------------------------------------------------------------
REPORT="$HOME/Desktop/browser_health_report_$(date +%Y%m%d_%H%M%S).txt"
ARCH=$(uname -m)

log() {
  echo "===============================" | tee -a "$REPORT"
  echo "$1" | tee -a "$REPORT"
  echo "===============================" | tee -a "$REPORT"
}

{
  echo "Macktechs Browser Health Check Report"
  echo "Generated: $(date)"
  echo "Architecture: $ARCH"
  echo "macOS Version: $MACOS_VER"
  echo ""
} | tee "$REPORT"

# ---------------------------------------------------------------------------
# 3. Suspicious Pattern Engine
# ---------------------------------------------------------------------------
SUSPICIOUS_MATCHES=()

check_suspicious() {
  local label="$1"
  local data="$2"
  if echo "$data" | egrep -qi "mackeeper|mackeepr|advancedmaccleaner|searchmarquis|search baron|searchbaron|chilltab|weknow|anysearch|mybrowserhelper"; then
    SUSPICIOUS_MATCHES+=("$label")
  fi
}

# ---------------------------------------------------------------------------
# 4. System-Level Checks (Browser-Agnostic)
# ---------------------------------------------------------------------------

# 4.1 /etc/hosts
log "System: /etc/hosts"
if [[ -r /etc/hosts ]]; then
  cat /etc/hosts >> "$REPORT"
  check_suspicious "hosts file" "$(cat /etc/hosts)"
else
  echo "(Cannot read /etc/hosts)" >> "$REPORT"
fi
echo "" >> "$REPORT"

# 4.2 DNS for Wi-Fi
log "System: DNS Servers for Wi-Fi"
if networksetup -getdnsservers "Wi-Fi" &>/dev/null; then
  networksetup -getdnsservers "Wi-Fi" >> "$REPORT"
else
  echo "Wi-Fi service not found or no DNS info available." >> "$REPORT"
fi
echo "" >> "$REPORT"

# 4.3 Proxy Settings for Wi-Fi
log "System: Proxy Settings for Wi-Fi"
WEB_PROXY=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null)
SECURE_PROXY=$(networksetup -getsecurewebproxy "Wi-Fi" 2>/dev/null)
echo "$WEB_PROXY" >> "$REPORT"
echo "$SECURE_PROXY" >> "$REPORT"
check_suspicious "Wi-Fi proxy settings" "${WEB_PROXY} ${SECURE_PROXY}"
echo "" >> "$REPORT"

# 4.4 LaunchAgents & LaunchDaemons
log "System: LaunchAgents & LaunchDaemons"
USER_LAUNCH_AGENTS=""
if [[ -d "$HOME/Library/LaunchAgents" ]]; then
  USER_LAUNCH_AGENTS=$(ls -la "$HOME/Library/LaunchAgents" 2>/dev/null)
  echo "--- User LaunchAgents ($HOME/Library/LaunchAgents) ---" >> "$REPORT"
  echo "$USER_LAUNCH_AGENTS" >> "$REPORT"
else
  echo "User LaunchAgents dir not found." >> "$REPORT"
fi
check_suspicious "User LaunchAgents" "$USER_LAUNCH_AGENTS"

SYS_LAUNCH_AGENTS=""
if [[ -d /Library/LaunchAgents ]]; then
  SYS_LAUNCH_AGENTS=$(ls -la /Library/LaunchAgents 2>/dev/null)
  echo "--- System LaunchAgents ---" >> "$REPORT"
  echo "$SYS_LAUNCH_AGENTS" >> "$REPORT"
else
  echo "System LaunchAgents dir not found." >> "$REPORT"
fi
check_suspicious "System LaunchAgents" "$SYS_LAUNCH_AGENTS"

SYS_LAUNCH_DAEMONS=""
if [[ -d /Library/LaunchDaemons ]]; then
  SYS_LAUNCH_DAEMONS=$(ls -la /Library/LaunchDaemons 2>/dev/null)
  echo "--- System LaunchDaemons ---" >> "$REPORT"
  echo "$SYS_LAUNCH_DAEMONS" >> "$REPORT"
else
  echo "System LaunchDaemons dir not found." >> "$REPORT"
fi
check_suspicious "System LaunchDaemons" "$SYS_LAUNCH_DAEMONS"
echo "" >> "$REPORT"

# 4.5 Login Items
log "System: Login Items"
LOGIN_ITEMS=""
if LOGIN_ITEMS=$(osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null); then
  echo "$LOGIN_ITEMS" >> "$REPORT"
  check_suspicious "Login Items" "$LOGIN_ITEMS"
else
  echo "Could not read login items (AppleScript may need permissions)." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ---------------------------------------------------------------------------
# 5. Chrome Checks
# ---------------------------------------------------------------------------
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
CHROME_EXT_DIR="$CHROME_DIR/Default/Extensions"

log "Chrome Health"
if [[ ! -d "$CHROME_DIR" ]]; then
  echo "Chrome not installed for this user." >> "$REPORT"
else
  # 5.1 Profiles
  echo "--- Profiles ---" >> "$REPORT"
  for p in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
    [[ -d "$p" ]] && echo "$p" >> "$REPORT"
  done

  # 5.2 Extensions with human-readable names
  if [[ -d "$CHROME_EXT_DIR" ]]; then
    echo "--- Extensions ---" >> "$REPORT"
    EXT_LIST=""
    for ext_dir in "$CHROME_EXT_DIR"/*/; do
      [[ ! -d "$ext_dir" ]] && continue
      ext_id=$(basename "$ext_dir")
      name="(no manifest)"
      for manifest in "$ext_dir"*/*/manifest.json "$ext_dir"*/manifest.json; do
        if [[ -f "$manifest" ]]; then
          name=$(python3 -c "import json; print(json.load(open('$manifest')).get('name','(no name)'))" 2>/dev/null || echo "(parse error)")
          break
        fi
      done
      echo "ID: $ext_id | Name: $name" >> "$REPORT"
      EXT_LIST="$EXT_LIST ID: $ext_id | Name: $name"
    done
    check_suspicious "Chrome Extensions" "$EXT_LIST"
  fi

  # 5.3 Managed Preferences
  if [[ -f /Library/Managed\ Preferences/com.google.Chrome.plist ]]; then
    echo "--- Chrome Managed Preferences ---" >> "$REPORT"
    CHROME_MANAGED=$(defaults read "/Library/Managed Preferences/com.google.Chrome" 2>/dev/null)
    echo "$CHROME_MANAGED" >> "$REPORT"
    check_suspicious "Chrome Managed Preferences" "$CHROME_MANAGED"
  fi
fi
echo "" >> "$REPORT"

# ---------------------------------------------------------------------------
# 6. Firefox Checks
# ---------------------------------------------------------------------------
FF_DIR="$HOME/Library/Application Support/Firefox"
FF_PROFILES_DIR="$FF_DIR/Profiles"

log "Firefox Health"
if [[ ! -d "$FF_PROFILES_DIR" ]]; then
  echo "Firefox may not be installed (Profiles dir not found)." >> "$REPORT"
else
  for profile_dir in "$FF_PROFILES_DIR"/*/; do
    [[ ! -d "$profile_dir" ]] && continue
    name=$(basename "$profile_dir")
    echo "--- Profile: $name ---" >> "$REPORT"

    if [[ -d "$profile_dir/extensions" ]]; then
      echo "Extensions (.xpi):" >> "$REPORT"
      ls "$profile_dir/extensions" 2>/dev/null >> "$REPORT"
    fi
    if [[ -f "$profile_dir/extensions.json" ]]; then
      echo "extensions.json (excerpt):" >> "$REPORT"
      cat "$profile_dir/extensions.json" 2>/dev/null >> "$REPORT"
    fi
    FF_EXT_DATA=$(ls "$profile_dir/extensions" 2>/dev/null; cat "$profile_dir/extensions.json" 2>/dev/null)
    check_suspicious "Firefox profile $name extensions" "$FF_EXT_DATA"
  done

  # Global policies
  FF_POLICIES="/Library/Application Support/Mozilla/ManagedStorage/firefox/policies.json"
  if [[ -f "$FF_POLICIES" ]]; then
    echo "--- Firefox global policies ---" >> "$REPORT"
    POL_CONTENT=$(cat "$FF_POLICIES" 2>/dev/null)
    echo "$POL_CONTENT" >> "$REPORT"
    check_suspicious "Firefox global policies" "$POL_CONTENT"
  fi
fi
echo "" >> "$REPORT"

# ---------------------------------------------------------------------------
# 7. Safari Checks
# ---------------------------------------------------------------------------
SAFARI_DIR="$HOME/Library/Safari"
SAFARI_EXT_DIR="$SAFARI_DIR/Extensions"

log "Safari Health"
if [[ ! -d "$SAFARI_DIR" ]]; then
  echo "Safari user data dir not found." >> "$REPORT"
else
  # 7.1 Extensions folder
  if [[ -d "$SAFARI_EXT_DIR" ]]; then
    echo "--- Safari Extensions folder ---" >> "$REPORT"
    SAFARI_EXT_LIST=$(ls -la "$SAFARI_EXT_DIR" 2>/dev/null)
    echo "$SAFARI_EXT_LIST" >> "$REPORT"
    check_suspicious "Safari Extensions folder" "$SAFARI_EXT_LIST"
  fi

  # 7.2 Managed Preferences
  if [[ -f /Library/Managed\ Preferences/com.apple.Safari.plist ]]; then
    echo "--- Safari Managed Preferences ---" >> "$REPORT"
    SAFARI_MANAGED=$(defaults read "/Library/Managed Preferences/com.apple.Safari" 2>/dev/null)
    echo "$SAFARI_MANAGED" >> "$REPORT"
    check_suspicious "Safari Managed Preferences" "$SAFARI_MANAGED"
  fi

  # 7.3 Search & Homepage
  echo "--- Safari key preferences ---" >> "$REPORT"
  SEARCH_PROV=$(defaults read com.apple.Safari SearchProviderIdentifier 2>/dev/null) || SEARCH_PROV="(not set)"
  HOMEPAGE=$(defaults read com.apple.Safari HomePage 2>/dev/null) || HOMEPAGE="(not set)"
  echo "Default search provider: $SEARCH_PROV" >> "$REPORT"
  echo "Home page: $HOMEPAGE" >> "$REPORT"
  check_suspicious "Safari search/homepage" "Search: $SEARCH_PROV Home: $HOMEPAGE"

  # 7.4 Safari App Extensions (optional)
  echo "--- Safari-related system extensions ---" >> "$REPORT"
  systemextensionsctl list 2>/dev/null | grep -i safari >> "$REPORT" || true
fi
echo "" >> "$REPORT"

# ---------------------------------------------------------------------------
# 8. Browser-Related Processes
# ---------------------------------------------------------------------------
log "Browser-related Processes"
PS_OUT=$(ps aux | egrep 'Chrome|chrome|Firefox|firefox|Safari' | egrep -v 'egrep' 2>/dev/null)
echo "$PS_OUT" >> "$REPORT"
check_suspicious "Browser processes" "$PS_OUT"
echo "" >> "$REPORT"

# ---------------------------------------------------------------------------
# 9. Suspicious Summary & Footer
# ---------------------------------------------------------------------------
log "Summary: Suspicious Flags"
if [[ ${#SUSPICIOUS_MATCHES[@]} -eq 0 ]]; then
  echo "No known bad patterns matched. Manual review still recommended." >> "$REPORT"
else
  echo "Potential issues detected in:" >> "$REPORT"
  for m in "${SUSPICIOUS_MATCHES[@]}"; do
    echo "  - $m" >> "$REPORT"
  done
fi
echo "" >> "$REPORT"

echo "----------------------------------------" >> "$REPORT"
echo "Macktechs Browser Health Check" >> "$REPORT"
echo "https://fix.macktechs.com" >> "$REPORT"
echo "If you're not sure how to read this report," >> "$REPORT"
echo "please email this file to support@macktechs.com" >> "$REPORT"

# ---------------------------------------------------------------------------
# 10. Finished Alert (for Automator/Platypus)
# ---------------------------------------------------------------------------
REPORT_BASENAME=$(basename "$REPORT")
osascript -e "display alert \"Macktechs Browser Health Check\" message \"Scan completed. A report has been saved on your Desktop as: $REPORT_BASENAME\""
