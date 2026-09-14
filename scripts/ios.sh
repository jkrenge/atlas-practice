#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"
action="${1:-build}"
project="ios/Atlas.xcodeproj"
scheme="Atlas"
derived="build/DerivedData"
case "$action" in
  generate)
    xcodegen generate --spec ios/project.yml
    ;;
  build)
    xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" \
      CODE_SIGNING_ALLOWED=NO build
    ;;
  test|run)
    simulator_id="${2:-}"
    if [[ -z "$simulator_id" ]]; then
      echo "Usage: scripts/ios.sh $action SIMULATOR_UDID" >&2
      echo "Find a device with: xcrun simctl list devices available" >&2
      exit 2
    fi
    if [[ "$action" == test ]]; then
      xcodebuild -project "$project" -scheme "$scheme" \
        -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath "$derived" \
        -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
    else
      "$0" build
      # bootstatus -b boots a shut-down device and waits until it is ready.
      xcrun simctl bootstatus "$simulator_id" -b
      xcrun simctl install "$simulator_id" "$derived/Build/Products/Debug-iphonesimulator/Atlas.app"
      xcrun simctl launch "$simulator_id" com.jkrenge.geography
    fi
    ;;
  *)
    echo "Usage: scripts/ios.sh {generate|build|test|run} [SIMULATOR_UDID]" >&2
    exit 2
    ;;
esac
