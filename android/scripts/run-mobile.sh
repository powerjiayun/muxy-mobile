#!/usr/bin/env bash
# Build, install, and launch the Android Muxy client on the muxy_pixel emulator.
# Usage:
#   scripts/run-mobile.sh              # build + install + launch
#   scripts/run-mobile.sh stop         # force-stop the app on the emulator
#   scripts/run-mobile.sh restart      # stop, then build + install + launch
#   scripts/run-mobile.sh logs         # tail logcat for the app
set -euo pipefail

SDK="${ANDROID_HOME:-/Volumes/SSD1/Storage/android-sdk}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
AVD_NAME="${MUXY_AVD:-muxy_pixel}"
PKG="com.muxy.app"
ACTIVITY="$PKG/.MainActivity"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="$ROOT_DIR/app/build/outputs/apk/debug/app-debug.apk"

cmd="${1:-run}"

stop_app() {
  if "$ADB" get-state >/dev/null 2>&1; then
    "$ADB" shell am force-stop "$PKG" 2>/dev/null && echo "Muxy stopped" || echo "Muxy not running"
  else
    echo "No device attached"
  fi
}

case "$cmd" in
  stop)
    stop_app
    exit 0
    ;;
  restart)
    stop_app
    ;;
  logs)
    exec "$ADB" logcat -v color -s "MuxyClient:* AndroidRuntime:E System.err:W $PKG:*"
    ;;
  run|"")
    ;;
  *)
    echo "Unknown command: $cmd"
    echo "Usage: $0 [run|stop|restart|logs]"
    exit 1
    ;;
esac

# 1. Ensure a booted emulator is available.
EMU_LOG=/tmp/muxy-emulator.log

is_booted() {
  # Returns 0 if at least one device reports boot_completed=1.
  local serial
  serial="$("$ADB" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}')"
  [ -n "$serial" ] || return 1
  [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]
}

wait_for_boot() {
  local timeout="${1:-180}"
  local waited=0
  echo -n "  waiting for boot"
  while [ "$waited" -lt "$timeout" ]; do
    if is_booted; then
      echo " ready"
      return 0
    fi
    echo -n "."
    sleep 2
    waited=$((waited + 2))
  done
  echo " timeout"
  return 1
}

kill_emulators() {
  echo "Killing existing emulators and resetting adb..."
  # Ask each connected emulator to shut down cleanly.
  "$ADB" devices 2>/dev/null | awk 'NR>1 && $1 ~ /^emulator-/ {print $1}' | while read -r serial; do
    [ -n "$serial" ] && "$ADB" -s "$serial" emu kill >/dev/null 2>&1 || true
  done
  # Force-kill any lingering qemu/emulator processes.
  pkill -f "qemu-system" 2>/dev/null || true
  pkill -f "$SDK/emulator/" 2>/dev/null || true
  "$ADB" kill-server >/dev/null 2>&1 || true
  sleep 1
  "$ADB" start-server >/dev/null 2>&1 || true
}

boot_emulator() {
  # Verify the AVD actually exists before launching, so we fail fast with a
  # clear message instead of waiting on an emulator that already exited.
  if ! ANDROID_HOME="$SDK" "$EMULATOR" -list-avds 2>/dev/null | grep -qx "$AVD_NAME"; then
    echo "AVD '$AVD_NAME' not found. Available AVDs:"
    ANDROID_HOME="$SDK" "$EMULATOR" -list-avds 2>/dev/null | sed 's/^/  /'
    echo "Set MUXY_AVD or ANDROID_AVD_HOME to point at the right location."
    return 1
  fi

  echo "Starting emulator '$AVD_NAME'..."
  # Do NOT override ANDROID_AVD_HOME — a blank value hides AVDs stored in
  # non-default locations (e.g. /Volumes/SSD2/Storage/android-avd).
  ANDROID_HOME="$SDK" \
    "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-save >"$EMU_LOG" 2>&1 &
  local emu_pid=$!
  echo "  emulator pid=$emu_pid  log=$EMU_LOG"

  # Give the emulator a moment to either start or exit immediately on error.
  sleep 2
  if ! kill -0 "$emu_pid" 2>/dev/null; then
    echo "Emulator process exited immediately. Last 20 log lines:"
    tail -n 20 "$EMU_LOG" 2>/dev/null || true
    return 1
  fi

  if ! wait_for_boot 180; then
    echo "Emulator failed to boot within timeout. Last 20 log lines:"
    tail -n 20 "$EMU_LOG" 2>/dev/null || true
    return 1
  fi
}

"$ADB" start-server >/dev/null 2>&1 || true

if is_booted; then
  echo "Emulator already booted; reusing it."
else
  # Either no device, or a half-booted/offline emulator. Reset and start fresh.
  kill_emulators
  if ! boot_emulator; then
    # One retry after another full reset, in case the first attempt got stuck.
    kill_emulators
    boot_emulator || { echo "Giving up on emulator boot."; exit 1; }
  fi
fi

# 2. Build debug APK.
echo "Building debug APK..."
GRADLE_USER_HOME="$HOME/.gradle" \
JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home}" \
  "$ROOT_DIR/gradlew" -q -p "$ROOT_DIR" \
    -Pandroid.builder.sdkDownload=false \
    assembleDebug

if [ ! -f "$APK" ]; then
  echo "APK not found at $APK"
  exit 1
fi

# 3. Install + launch.
echo "Installing $APK"
"$ADB" install -r "$APK" >/dev/null
echo "Launching $ACTIVITY"
"$ADB" shell am start -n "$ACTIVITY" >/dev/null

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
echo
echo "Muxy running on emulator '$AVD_NAME'"
echo "Connect using: 10.0.2.2:4865 (emulator <-> Mac host) or $LOCAL_IP:4865 (real device)"
echo "Tail logs:   scripts/run-mobile.sh logs"
