#!/usr/bin/env bash
# Captures raw App Store screenshots from the --screenshots fixture on a fresh
# iPhone 17 Pro Max simulator (6.9", 1320x2868) with a 9:41 status bar.
# Usage: scripts/capture-screenshots.sh [output-dir] [appearance...]
# Writes <output-dir>/<appearance>/<screen>.png; defaults to build/screenshots/raw and light dark.
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:-build/screenshots/raw}
shift || true
appearances=("$@")
[[ ${#appearances[@]} -gt 0 ]] || appearances=(light dark)
device_type=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max
derived=build/screenshots/DerivedData

runtime=${TENDR_SIM_RUNTIME:-$(xcrun simctl list runtimes --json | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS" and r["isAvailable"]]
runtimes.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(runtimes[-1]["identifier"] if runtimes else "")
')}
[[ -n "$runtime" ]] || { echo "No iOS simulator runtime is installed" >&2; exit 1; }
echo "Using $runtime"

udid=$(xcrun simctl create "Tendr Screenshots" "$device_type" "$runtime")
trap 'xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true; xcrun simctl delete "$udid" >/dev/null 2>&1 || true' EXIT
scripts/boot-simulator.sh "$udid" 300

xcodebuild build-for-testing -project Still.xcodeproj -scheme Still \
  -destination "id=$udid" -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO -quiet

rm -rf "$out" build/screenshots/*.xcresult
for appearance in "${appearances[@]}"; do
  xcrun simctl ui "$udid" appearance "$appearance"
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName "" \
    --batteryState discharging --batteryLevel 100
  mkdir -p "$out/$appearance"
  TEST_RUNNER_SCREENSHOT_DIR="$PWD/$out/$appearance" xcodebuild test-without-building \
    -project Still.xcodeproj -scheme Still -destination "id=$udid" -derivedDataPath "$derived" \
    -only-testing:StillUITests/ScreenshotTests \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 600 \
    -resultBundlePath "build/screenshots/ScreenshotTests-$appearance.xcresult" -quiet
done

python3 - "$out" <<'PY'
import struct, sys, pathlib
for png in sorted(pathlib.Path(sys.argv[1]).rglob("*.png")):
    width, height = struct.unpack(">II", png.read_bytes()[16:24])
    print(f"{png}: {width}x{height}")
    if (width, height) != (1320, 2868):
        sys.exit(f"{png} is {width}x{height}, expected 1320x2868")
PY
