#!/bin/zsh
# DexCast Action Handler Script
set +e

ROOT="/Users/andrew/DexCast"
PROFILES="$ROOT/profiles"
ACTIVE="$PROFILES/active-profile"
LOG="$HOME/Library/Logs/dexcast.log"

ADB="$(command -v adb 2>/dev/null || echo /opt/homebrew/bin/adb)"
SCRCPY="$(command -v scrcpy 2>/dev/null || echo /opt/homebrew/bin/scrcpy)"
BREW="$(command -v brew 2>/dev/null || echo /opt/homebrew/bin/brew)"
SUNSHINE="$(command -v sunshine 2>/dev/null || echo /opt/homebrew/bin/sunshine)"

mkdir -p "$PROFILES" "$(dirname "$LOG")"
touch "$LOG"

log(){
  echo "[$(date '+%F %T')] $*" >> "$LOG"
}

load_profile(){
  PROFILE="$(cat "$ACTIVE" 2>/dev/null || echo default)"
  CFG="$PROFILES/$PROFILE.env"
  if [ -f "$CFG" ]; then
    source "$CFG" 2>/dev/null || true
  else
    FIRE_IP=""
    ANDROID_IP=""
    DISPLAY_MODE="Choose in Sunshine"
  fi
}

terminal_run(){
  local title="$1"
  local cmd="$2"
  osascript <<OSA
tell application "Terminal"
  activate
  do script "echo '=== $title ==='; echo; $cmd; echo; echo '=== Done. You may close this window. ==='"
end tell
OSA
}

case "${1:-}" in
  check-status)
    load_profile
    
    # 1. Ping Check
    if [ -n "$FIRE_IP" ]; then
      if ping -c 1 -t 1 "$FIRE_IP" >/dev/null 2>&1; then
        echo "FIRE_REACHABLE:ok"
      else
        echo "FIRE_REACHABLE:fail"
      fi
    else
      echo "FIRE_REACHABLE:unconfigured"
    fi
    
    # 2. ADB State Check
    if [ -n "$FIRE_IP" ]; then
      "$ADB" connect "$FIRE_IP:5555" >/dev/null 2>&1
      DEV_STATE="$("$ADB" devices | grep "$FIRE_IP:5555" | awk '{print $2}')"
      if [ "$DEV_STATE" = "device" ]; then
        echo "ADB_AUTHORIZED:ok"
      elif [ "$DEV_STATE" = "unauthorized" ]; then
        echo "ADB_AUTHORIZED:unauthorized"
      else
        echo "ADB_AUTHORIZED:disconnected"
      fi
    else
      echo "ADB_AUTHORIZED:unconfigured"
    fi
    
    # 3. Moonlight Check
    if [ -n "$FIRE_IP" ] && [ "$DEV_STATE" = "device" ]; then
      PKG="$("$ADB" shell pm list packages 2>/dev/null | grep -iE 'limelight|moonlight' | head -n 1 | sed 's/package://;s/\r//')"
      if [ -n "$PKG" ]; then
        echo "MOONLIGHT_PRESENT:ok"
      else
        echo "MOONLIGHT_PRESENT:missing"
      fi
    else
      echo "MOONLIGHT_PRESENT:unknown"
    fi
    
    # 4. Sunshine Check
    if [ -n "$SUNSHINE" ] && [ -f "$SUNSHINE" ]; then
      if pgrep -x sunshine >/dev/null; then
        echo "SUNSHINE_RUNNING:ok"
      else
        echo "SUNSHINE_RUNNING:installed_stopped"
      fi
    else
      echo "SUNSHINE_RUNNING:missing"
    fi
    
    # 5. Profile info
    echo "PROFILE_NAME:${PROFILE:-default}"
    echo "FIRE_IP:${FIRE_IP:-Not set}"
    echo "ANDROID_IP:${ANDROID_IP:-Not set}"
    echo "DISPLAY_MODE:${DISPLAY_MODE:-Choose in Sunshine}"
    ;;

  setup)
    PROFILE="$(osascript -e 'text returned of (display dialog "Enter profile name:" default answer "default" buttons {"Cancel","Save"} default button "Save" with title "DexCast Setup")')" || exit 0
    FIRE_IP="$(osascript -e 'text returned of (display dialog "Enter Fire Stick IP address:" default answer "10.0.0.115" buttons {"Cancel","Save"} default button "Save" with title "DexCast Setup")')" || exit 0
    ANDROID_IP="$(osascript -e 'text returned of (display dialog "Enter Android Wi-Fi ADB IP (optional, press Skip to omit):" default answer "" buttons {"Skip","Save"} default button "Save" with title "DexCast Setup")')" || ANDROID_IP=""
    DISPLAY_MODE="$(osascript -e 'choose from list {"MacBook display","External display","Both displays","Choose in Sunshine"} with title "DexCast Setup" with prompt "Which screen do you want to cast?" default items {"Choose in Sunshine"}')" || DISPLAY_MODE="Choose in Sunshine"
    
    echo "$PROFILE" > "$ACTIVE"
    cat > "$PROFILES/$PROFILE.env" <<CFG
FIRE_IP="$FIRE_IP"
ANDROID_IP="$ANDROID_IP"
DISPLAY_MODE="$DISPLAY_MODE"
CFG
    log "Profile '$PROFILE' updated: FIRE_IP='$FIRE_IP', ANDROID_IP='$ANDROID_IP', DISPLAY_MODE='$DISPLAY_MODE'"
    ;;

  install)
    log "Starting installation of tools..."
    terminal_run "DexCast Dependencies Installer" "
echo 'Tapping lizardbyte/homebrew...';
'$BREW' tap lizardbyte/homebrew;
echo 'Trusting lizardbyte/homebrew...';
'$BREW' trust lizardbyte/homebrew || true;
echo 'Installing tools: adb, scrcpy, localsend, kdeconnect, sunshine...';
'$BREW' install android-platform-tools scrcpy localsend kdeconnect lizardbyte/homebrew/sunshine;
echo 'Setting up Sunshine background service...';
'$BREW' services start lizardbyte/homebrew/sunshine || true;
"
    ;;

  authorize-fire)
    load_profile
    if [ -z "$FIRE_IP" ]; then
      osascript -e 'display dialog "Please configure your profile first." buttons {"OK"} with title "DexCast"'
      exit 1
    fi
    log "Authorizing Fire Stick at $FIRE_IP"
    terminal_run "Fire Stick ADB Authorization" "
echo 'Look at the TV. If prompted, select \"Always allow from this computer\" and then click Allow.';
echo;
'$ADB' kill-server;
'$ADB' start-server;
'$ADB' connect '$FIRE_IP:5555';
'$ADB' devices;
"
    ;;

  sunshine)
    log "Launching Sunshine stream server..."
    if ! pgrep -x sunshine >/dev/null; then
      # Try starting service or run binary directly
      "$BREW" services start lizardbyte/homebrew/sunshine >> "$LOG" 2>&1 || "$SUNSHINE" >> "$LOG" 2>&1 &
      log "Sunshine service started"
    else
      log "Sunshine is already running"
    fi
    ;;

  moonlight)
    load_profile
    if [ -z "$FIRE_IP" ]; then
      log "Moonlight launch failed: Fire Stick IP is not configured."
      osascript -e 'display dialog "Fire Stick IP is not configured. Please run Setup." buttons {"OK"} with title "DexCast"'
      exit 1
    fi
    log "Waking up Fire Stick at $FIRE_IP and launching Moonlight..."
    
    # Try connecting and wait for device to be online (up to 5 retries)
    local retries=5
    local DEV_STATE=""
    while [ $retries -gt 0 ]; do
      CONN_OUT="$("$ADB" connect "$FIRE_IP:5555" 2>&1)"
      log "ADB connect retry $((6 - retries)): $CONN_OUT"
      DEV_STATE="$("$ADB" devices | grep "$FIRE_IP:5555" | awk '{print $2}')"
      if [ "$DEV_STATE" = "device" ] || [ "$DEV_STATE" = "unauthorized" ]; then
        break
      fi
      log "Device is in state '$DEV_STATE', retrying in 1s..."
      sleep 1
      retries=$((retries - 1))
    done
    
    if [ "$DEV_STATE" = "unauthorized" ]; then
      log "ADB connection unauthorized. Displaying dialog."
      osascript -e 'display dialog "Fire Stick ADB connection is unauthorized.\n\nLook at the TV screen and choose \"Always allow from this computer\", then \"Allow\".\nThen try again." buttons {"OK"} with title "DexCast"'
      exit 1
    elif [ "$DEV_STATE" = "offline" ]; then
      log "Fire Stick is offline."
      osascript -e 'display dialog "Fire Stick ADB connection is offline.\n\nTry toggling ADB Debugging OFF and then ON in Fire Stick Settings → My Fire TV → Developer Options.\nThen try again." buttons {"OK"} with title "DexCast"'
      exit 1
    elif [ -z "$DEV_STATE" ]; then
      log "Fire Stick not connected. Testing ping."
      if ! ping -c 1 -t 1 "$FIRE_IP" >/dev/null 2>&1; then
        osascript -e "display dialog \"I can't reach the Fire Stick at $FIRE_IP. Recheck Fire Stick Settings → Network.\" buttons {\"OK\"} with title \"DexCast\""
        exit 1
      fi
      osascript -e 'display dialog "Fire Stick is reachable but ADB did not answer. Ensure ADB Debugging is enabled on the Fire Stick." buttons {"OK"} with title "DexCast"'
      exit 1
    fi
    
    # Wake up stick
    "$ADB" shell input keyevent KEYCODE_WAKEUP >> "$LOG" 2>&1
    "$ADB" shell input keyevent KEYCODE_HOME >> "$LOG" 2>&1
    
    # Find Moonlight package
    PKG="$("$ADB" shell pm list packages 2>>"$LOG" | grep -iE 'limelight|moonlight' | head -n 1 | sed 's/package://;s/\r//')"
    if [ -n "$PKG" ]; then
      log "Found Moonlight package: $PKG. Launching..."
      "$ADB" shell monkey -p "$PKG" 1 >> "$LOG" 2>&1
    else
      log "Moonlight is not installed on the Fire Stick."
      osascript -e 'display dialog "Moonlight was not found on the Fire Stick.\n\nOn the Fire Stick, search for \"Moonlight Game Streaming\" and install it first." buttons {"OK"} with title "DexCast"'
      exit 1
    fi
    ;;

  mac-fire)
    log "Sit With Dexter: MacBook -> Fire Stick triggered"
    "$0" sunshine
    "$0" moonlight
    ;;

  android-usb-fire)
    log "Sit With Dexter: Android USB Mirror triggered"
    "$0" sunshine
    "$0" moonlight
    log "Spawning scrcpy via USB..."
    "$SCRCPY" --stay-awake --turn-screen-off >> "$LOG" 2>&1 &
    SCRCPY_PID=$!
    echo $SCRCPY_PID > "$PROFILES/scrcpy.pid"
    log "scrcpy spawned with PID $SCRCPY_PID"
    ;;

  android-wifi-fire)
    load_profile
    if [ -z "$ANDROID_IP" ]; then
      osascript -e 'display dialog "Android IP is not configured in this profile." buttons {"OK"} with title "DexCast"'
      exit 1
    fi
    log "Sit With Dexter: Android Wi-Fi Mirror triggered to $ANDROID_IP"
    "$0" sunshine
    "$0" moonlight
    log "Connecting ADB to Android at $ANDROID_IP..."
    "$ADB" connect "$ANDROID_IP:5555" >> "$LOG" 2>&1
    log "Spawning scrcpy via TCP/IP..."
    "$SCRCPY" --tcpip="$ANDROID_IP:5555" --stay-awake >> "$LOG" 2>&1 &
    SCRCPY_PID=$!
    echo $SCRCPY_PID > "$PROFILES/scrcpy.pid"
    log "scrcpy spawned with PID $SCRCPY_PID"
    ;;

  stop-mirrors)
    log "Stopping mirroring sessions..."
    PID="$(cat "$PROFILES/scrcpy.pid" 2>/dev/null)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      log "Killed managed scrcpy PID $PID"
    else
      log "No active managed scrcpy PID found, running fallback pkill"
      pkill -f scrcpy 2>/dev/null || true
    fi
    rm -f "$PROFILES/scrcpy.pid"
    ;;

  doctor)
    load_profile
    {
      echo "=============================================="
      echo "=== DexCast DOCTOR REPORT $(date) ==="
      echo "=============================================="
      echo "Active Profile: ${PROFILE:-default}"
      echo "Fire Stick IP: ${FIRE_IP:-Not set}"
      echo "Android IP: ${ANDROID_IP:-Not set}"
      echo "Display Mode: ${DISPLAY_MODE:-Not set}"
      echo "----------------------------------------------"
      echo "Brew Path: $BREW"
      [ -f "$BREW" ] && "$BREW" --version | head -n 1 || echo "Brew not found"
      echo "ADB Path: $ADB"
      [ -f "$ADB" ] && "$ADB" version | head -n 2 || echo "ADB not found"
      echo "scrcpy Path: $SCRCPY"
      [ -f "$SCRCPY" ] && "$SCRCPY" --version | head -n 1 || echo "scrcpy not found"
      echo "Sunshine Path: $SUNSHINE"
      [ -f "$SUNSHINE" ] && echo "Sunshine binary exists" || echo "Sunshine binary not found"
      echo "----------------------------------------------"
      echo "Running processes:"
      pgrep -fl Sunshine || echo "Sunshine process is NOT running"
      pgrep -fl scrcpy || echo "scrcpy process is NOT running"
      echo "----------------------------------------------"
      echo "Network Reachability:"
      if [ -n "$FIRE_IP" ]; then
        ping -c 3 -W 1000 "$FIRE_IP" 2>&1
        echo "ADB Device State:"
        "$ADB" connect "$FIRE_IP:5555" 2>&1
        "$ADB" devices | grep "$FIRE_IP:5555"
        echo "Moonlight Package Check:"
        "$ADB" shell pm list packages | grep -iE 'limelight|moonlight' 2>&1
      else
        echo "Fire Stick IP is not configured."
      fi
      echo "=============================================="
    } >> "$LOG" 2>&1
    open "$LOG"
    ;;

  log)
    open "$LOG"
    ;;

  webui)
    open "https://localhost:47990"
    ;;

  displays)
    open "x-apple.systempreferences:com.apple.preference.displays"
    ;;

  reset-adb)
    log "Resetting ADB server..."
    "$ADB" kill-server >> "$LOG" 2>&1
    "$ADB" start-server >> "$LOG" 2>&1
    log "ADB server reset complete"
    ;;

  uninstall)
    log "Uninstalling DexCast app artifacts..."
    pkill -f scrcpy 2>/dev/null
    rm -rf "$ROOT/profiles" "$ROOT/assets" "$ROOT/src" "$ROOT/bin" "$ROOT/scripts" "$ROOT/README.md"
    rm -rf "$HOME/Desktop/DexCast.app" "$ROOT/DexCast.app"
    log "DexCast uninstalled successfully."
    ;;
esac
