# Expanded app verification

Verified on 2026-09-14 with Xcode 26.6 (17F113), Swift 6 language mode, and iOS Simulator 26.5 (23F77). Deployment target: iOS 18.0.

## Build and data

- Generic iOS Simulator Debug build succeeds from the saved repository's committed project structure. Maps, the learning JSON, and all 66 PNG flags are bundled; no app package dependency or server is required.
- Both Python validators pass: twelve packs, 842 individually valid area features, 769 retained city/town points, 66 complete state facts, 60 ranked city populations, 70 landmarks, and 196 capital/city/landmark positions.
- Source and asset checksum locks pass. Two successive offline compiler runs reproduced 21 generated map/fact/repair files byte-for-byte.
- The NYC local pack includes 266 named areas and separately preserves the original candidate. The two active geometry repairs are documented. Source-download equivalence remains a stated limit.

## Automated tests

All **32 distinct tests passed**: 18 Swift Testing unit tests and 14 XCTest Simulator UI tests. The full UI suite ran on iPhone 17 Pro. After adding the coordinates to location feedback, the saved repository build passed all 18 unit tests and both affected location UI tests again. The final timer-only check passed after disabling polling for untimed and completed sessions. Its repository result bundle is `build/DerivedData/Logs/Test/Test-Atlas-2026.09.14_01-05-32--0400.xcresult`.

Unit checks cover all map packs, projections and antimeridian wrapping, geometry hits and inverse transforms, inset placement for every learning point at two viewport sizes, water acceptance for point questions, inset-gap rejection, all flag image decodes, complete state/city/landmark counts, dated population ordering, unique answer labels, haversine distance, timer pause/resume/expiry, duplicate-answer protection, spaced review, finite sessions, and separate progress for map/mode/timer settings.

UI checks cover all nine game modes; real polygon and pin taps; pinch, pan, zoom, and reset; correct/wrong/revealed answers; a full borough session; coordinate entry; city population dates; flag images; nickname and capital answers; German reference data; NYC neighborhood search; countdown expiry and answer locking; landscape; the largest accessibility text category; and the area-list alternative. The accessibility audit checks touch-target size, descriptions, and contrast on the Find screen.

The full 14-test UI bundle is in the task's `work/expansion/DerivedData/Logs/Test/Test-Atlas-2026.09.14_00-53-11--0400.xcresult`. The final repository unit/location bundle is `build/DerivedData/Logs/Test/Test-Atlas-2026.09.14_01-01-45--0400.xcresult`. Raw logs and result bundles remain under ignored build/task directories. Run `scripts/ios.sh test SIMULATOR_UDID` to repeat the complete scheme.

## Runtime inspection

The repository build was installed and launched separately on iPhone 17 Simulator. Native UI readback and screenshots confirmed the expanded mode selector, authentic Colorado and California flags, a correct flag answer, and a Florida landmark answer pin. Manual pause disabled answer controls; resume restored the countdown. Advancing reset it to 30 seconds. After leaving the app on the Simulator Home screen for over a minute, it returned with 22 seconds left rather than expiring. A separate landmark question displayed timeout feedback and inserted one review.

The current Minnesota and Utah flag assets were visually checked. No generated substitute flag artwork is used.

## Limits

- Physical-device behavior and signing remain unverified. No TestFlight, App Store, or public release was performed.
- Runtime verification used iOS 26.5. Older supported OS versions and iPad need device-specific review.
- Native controls have accessibility labels, and answers post announcements. A complete spoken VoiceOver session has not been verified. The custom map has area-list and coordinate-entry alternatives; those do not reproduce visual spatial learning.
- NYC boundaries are approximate and include parks and islands. Individual topology checks do not prove complete gap/overlap coverage. The datHere catalog declares ODC-By, but the licensed resource download could not be compared with the pinned mirror.
- City populations are dated city/municipal figures, not live counts or metropolitan populations. Landmarks are a curated set, not a popularity ranking. Large parks use an identified reference point.
