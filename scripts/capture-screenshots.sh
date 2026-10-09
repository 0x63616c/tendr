#!/usr/bin/env bash
# Captures raw App Store screenshots on a fresh iPhone 17 Pro Max simulator (6.9", 1320x2868)
# with a 9:41 / full battery / full signal status bar. Usage: scripts/capture-screenshots.sh [output-dir]
set -euo pipefail

cd "$(dirname "$0")/.."
out="$(mkdir -p "${1:-build/screenshots/raw}" && cd "${1:-build/screenshots/raw}" && pwd)"
rm -f "$out"/*.png
device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
runtime="$(xcrun simctl list runtimes available -j | jq -r '[.runtimes[] | select(.platform == "iOS")] | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')"
if [[ -z "$runtime" ]]; then
  echo "::error::No iOS simulator runtime is installed" >&2
  exit 1
fi

udid="$(xcrun simctl create "Tendr Screenshots $$" "$device_type" "$runtime")"
trap 'xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true; xcrun simctl delete "$udid" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" \
  --batteryState charged --batteryLevel 100

TEST_RUNNER_SCREENSHOTS_DIR="$out" xcodebuild test \
  -project Still.xcodeproj -scheme Still \
  -destination "platform=iOS Simulator,id=$udid" \
  -only-testing:StillUITests/AppStoreScreenshots \
  -resultBundlePath "build/screenshots/AppStoreScreenshots-$$.xcresult" \
  CODE_SIGNING_ALLOWED=NO

count=0
for png in "$out"/*.png; do
  size="$(sips -g pixelWidth -g pixelHeight "$png" | awk '/pixel(Width|Height)/ { printf "%s ", $2 }')"
  if [[ "$size" != "1320 2868 " ]]; then
    echo "::error::$png is ${size}not 1320x2868" >&2
    exit 1
  fi
  count=$((count + 1))
done
if [[ "$count" -lt 5 ]]; then
  echo "::error::Expected at least 5 screenshots, found $count" >&2
  exit 1
fi
echo "Captured $count screenshots in $out"
