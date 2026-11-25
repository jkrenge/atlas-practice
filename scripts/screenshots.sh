#!/bin/bash
# Captures App Store and website screenshots on fresh simulators with a clean 9:41 status bar.
#
#   scripts/screenshots.sh
#
# Output: build/screenshots/<device>/NN-name.png at full size (App Store: iPhone 6.3" is required,
# 6.9" optional, and iPad 13" because the app runs on iPad),
# and website/assets/screens/NN-name.jpg (from iPhone 17 Pro Max, 1400 px tall).
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/screenshots
derived=build/screenshot-derived # Not build/Screenshots: macOS paths ignore case.
rm -rf "$out"
mkdir -p "$out" website/assets/screens

xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived" CODE_SIGNING_ALLOWED=NO build-for-testing -quiet

for device in iPhone-17-Pro iPhone-17-Pro-Max iPad-Pro-13-inch-M5-12GB; do
  id=$(xcrun simctl create "Atlas Screenshots" "com.apple.CoreSimulator.SimDeviceType.$device")
  xcrun simctl bootstatus "$id" -b >/dev/null
  # iPadOS 26 defaults to Windowed Apps, whose resize grabber would show in the frames; iPhone ignores it.
  xcrun simctl spawn "$id" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool false
  xcrun simctl status_bar "$id" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  result="$derived/$device.xcresult"
  rm -rf "$result"
  status=0
  # TEST_RUNNER_ passes ATLAS_SCREENSHOTS to the UI test; without it the test skips.
  TEST_RUNNER_ATLAS_SCREENSHOTS=1 xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas \
    -destination "platform=iOS Simulator,id=$id" -derivedDataPath "$derived" -resultBundlePath "$result" \
    CODE_SIGNING_ALLOWED=NO test-without-building -only-testing:AtlasUITests/AtlasUITests/testStoreScreenshots \
    -quiet || status=$?
  xcrun simctl shutdown "$id" || true
  xcrun simctl delete "$id"
  [ "$status" -eq 0 ] || { echo "Screenshot run failed on $device" >&2; exit "$status"; }

  folder="$out/$device"
  xcrun xcresulttool export attachments --path "$result" --output-path "$folder/raw" >/dev/null
  # Attachments come out as UUID files; name them after the capture ("01-home.png").
  python3 - "$folder" <<'EOF'
import json, pathlib, shutil, sys
folder = pathlib.Path(sys.argv[1])
for test in json.loads((folder / 'raw/manifest.json').read_text()):
    for item in test.get('attachments', []):
        name = item['suggestedHumanReadableName'].split('_0_')[0]
        if not name[:2].isdigit():
            continue  # Helper captures such as "Quiz-…", not store frames.
        shutil.copy(folder / 'raw' / item['exportedFileName'], folder / f'{name}.png')
shutil.rmtree(folder / 'raw')
EOF
done

for shot in "$out"/iPhone-17-Pro-Max/*.png; do
  sips -Z 1400 -s format jpeg -s formatOptions 80 "$shot" --out "website/assets/screens/$(basename "${shot%.png}").jpg" >/dev/null
done
ls "$out"/*
