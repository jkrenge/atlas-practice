# Install Atlas Practice on an iPhone

The app uses native SwiftUI, UIKit, Core Graphics, and Core Animation. It requires iOS 18 or later. The last verified device build used Xcode 26.6 and an iPhone Air.

## Prerequisites

Connect and unlock the phone. Trust the Mac if prompted, enable Developer Mode, and sign in to Xcode with an account that can use the configured developer team. The Atlas target uses team `8433V6NWHP` in both `project.yml` and `Atlas.xcodeproj`. This ID is not a credential; certificates and account credentials remain in Xcode and Keychain. Another developer can select their own team or override `DEVELOPMENT_TEAM` in the build command.

Run these commands from the repository root. Find the device identifiers first:

```sh
xcrun devicectl list devices
xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas -showdestinations
```

Use the phone UDID from Xcode for `PHONE_UDID`. Use the corresponding identifier from `devicectl` for `DEVICE_ID`.

## Build and install

```sh
PHONE_UDID='replace-with-phone-udid'
DEVICE_ID='replace-with-devicectl-identifier'

xcodebuild -project ios/Atlas.xcodeproj -scheme Atlas \
  -configuration Release -destination "id=$PHONE_UDID" \
  -derivedDataPath build/DeviceRelease -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=8433V6NWHP CODE_SIGN_STYLE=Automatic \
  ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO build

codesign --verify --deep --strict \
  build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app

xcrun devicectl device install app --device "$DEVICE_ID" \
  build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app

xcrun devicectl device info apps --device "$DEVICE_ID" \
  --bundle-id com.jkrenge.geography

xcrun devicectl device process launch --device "$DEVICE_ID" \
  --terminate-existing com.jkrenge.geography
```

Run each step only after the previous step succeeds. Release builds use optimization. Disable coverage with both settings shown above because the scheme enables test coverage. Do not pass `--ui-testing` when launching on the user's phone: that argument is for automated tests.

Installation updates the existing app without an uninstall. Do not delete the app to update it; that can remove local progress. If launch reports `Locked`, installation can still have succeeded. Unlock the phone and open **Atlas Practice**, or repeat the launch command. Verify installation separately from launch and interaction.

Build products stay under ignored `build/`. Do not commit provisioning profiles, certificates, credentials, DerivedData, or test-result bundles. This procedure installs a development-signed app directly; it does not publish to TestFlight or the App Store.

## Verification and known limits

See [VERIFICATION.md](VERIFICATION.md) for the latest test and installation results and [MAP_REVIEW.md](../data/MAP_REVIEW.md) for map-source limits. The installed map update passed 23 unit tests and six selected Simulator UI tests before the Release build. Physical interaction, older supported OS versions, and iPad still need separate checks.
