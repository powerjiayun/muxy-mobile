#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../Muxy"

BUNDLE_ID="com.muxy.app"

if [ "${1:-}" = "stop" ]; then
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null && echo "Muxy stopped" || echo "Muxy not running"
  exit 0
fi

if [ "${1:-}" = "restart" ]; then
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null && echo "Muxy stopped" || echo "Muxy not running"
  shift
fi

SIM_NAME="${1:-iPhone 16e}"
SIM_ID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == '$SIM_NAME' and d['isAvailable']:
            print(d['udid']); sys.exit(0)
print(''); sys.exit(1)
" 2>/dev/null) || { echo "Simulator '$SIM_NAME' not found"; exit 1; }

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open -a Simulator

echo "Building Muxy..."
xcodebuild -project Muxy.xcodeproj \
  -scheme Muxy \
  -sdk iphonesimulator \
  -destination "id=$SIM_ID" \
  -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO \
  build -quiet

xcrun simctl install "$SIM_ID" .build/xcode/Build/Products/Debug-iphonesimulator/Muxy.app
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
echo ""
echo "Muxy running on $SIM_NAME"
echo "Connect using: 127.0.0.1:4865 (simulator) or $LOCAL_IP:4865 (real device)"
