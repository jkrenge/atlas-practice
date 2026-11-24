# Install Atlas Practice on an iPhone

The app uses native SwiftUI, UIKit, Core Graphics, and Core Animation. It requires iOS 18 or later.

## Prerequisites

Connect and unlock your iPhone. Trust the Mac if prompted, enable Developer Mode, and sign in to Xcode with an Apple developer account. Use your own development team and your own bundle ID: the values in `ios/project.yml` and `Atlas.xcodeproj` belong to the original developer, so override them in the build command below. Certificates and account credentials stay in Xcode and Keychain.

Run these commands from the repository root. Find the device identifiers first:

```sh
xcrun devicectl list devices
xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas -showdestinations
```

Use your iPhone's UDID from Xcode for `PHONE_UDID`. Use the corresponding identifier from `devicectl` for `DEVICE_ID`.

## Build and install

```sh
TEAM_ID='replace-with-your-team-id'
BUNDLE_ID='replace-with-your-bundle-id'
PHONE_UDID='replace-with-phone-udid'
DEVICE_ID='replace-with-devicectl-identifier'

xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas \
  -configuration Release -destination "id=$PHONE_UDID" \
  -derivedDataPath build/DeviceRelease -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_STYLE=Automatic \
  ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO build

codesign --verify --deep --strict \
  build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app

xcrun devicectl device install app --device "$DEVICE_ID" \
  build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app

xcrun devicectl device info apps --device "$DEVICE_ID" \
  --bundle-id "$BUNDLE_ID"

xcrun devicectl device process launch --device "$DEVICE_ID" \
  --terminate-existing "$BUNDLE_ID"
```

Run each step only after the previous step succeeds. Release builds use optimization. Disable coverage with both settings shown above because the scheme enables test coverage. `--ui-testing` (fixed question order for UI tests) only affects Debug builds; don't pass it to a build you play.

Installation updates the existing app without an uninstall. Do not delete the app to update it; that can remove local progress. If launch reports `Locked`, installation can still have succeeded. Unlock your iPhone and open **Atlas Practice**, or repeat the launch command. Verify installation separately from launch and interaction.

Build products stay under ignored `build/`. Do not commit provisioning profiles, certificates, credentials, DerivedData, or test-result bundles. This procedure installs a development-signed app directly; it does not publish to TestFlight or the App Store.

## Verification and known limits

See [VERIFICATION.md](VERIFICATION.md) for dated test and installation results and [MAP_REVIEW.md](../data/MAP_REVIEW.md) for map-source limits.
