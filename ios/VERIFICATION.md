# First milestone verification

Verified on 2026-09-13 with Xcode 26.6 (17F113), Swift 6 language mode, and iOS Simulator 26.5 (23F77). The app deployment target is iOS 18.0.

## Build and data

- Atlas Debug build for the generic iOS Simulator destination succeeds.
- The committed Xcode project includes the application, Swift Testing unit target, XCTest UI target, bundled maps, and app icon.
- All 11 catalog entries decode with their shared geometry references and expected question counts. Only the three approved maps appear in the app selector.
- `scripts/validate_data.py` passes: 11 active data packs, 576 valid area features, 769 city points, and matching source hashes. The detailed NYC candidate remains excluded.
- `scripts/compile_maps.py` reproduces committed geometry and metadata without a Git diff.

## Automated checks

All 16 tests passed with no failures: 9 unit tests and 7 Simulator UI tests in the Atlas scheme. Use `scripts/ios.sh test SIMULATOR_UDID` to repeat them. The UI test device is iPhone 17 Pro on iOS 26.5. Tests use a deterministic question order only when the Debug app is launched with `--ui-testing`; normal sessions sample randomly.

Unit checks cover catalog resolution, geographic projection round trips to within 1e-8 degrees, antimeridian wrapping, Colorado/Alaska/Hawaii/Rhode Island/Delaware/Germany/NYC hits, zoom/pan and portrait/landscape fitting, all 50 US state shapes, callout targets, DC background, polygon holes, water, ambiguous borders, anchored zoom, spaced review, finite sessions, and separate persisted map/mode results.

UI checks cover actual polygon taps, neutral callouts, pinch and pan without answer submission, zoom/reset, correct/wrong/revealed answers, a complete five-borough session and results, German study selection, landscape controls, the largest accessibility text category, and the non-spatial area list. The accessibility audit checks touch-target size, element descriptions, and contrast on the Find screen.

The audit found and led to fixes for a small Show answer target and low secondary-text contrast. Direct UI inspection also led to full-width study-row targets and distinct accessibility labels on preview zoom controls.

## Runtime inspection

The app was separately installed and launched on an iPhone 17 Simulator. Visual inspection covered map selection, the US overview and insets, a Find Washington question, a real polygon tap, and the resulting correct-answer outline and text.

Native controls expose labels and hints. Answer feedback posts a VoiceOver announcement. The custom map is exposed as an image; Find mode provides an area-list alternative. This alternative supports non-spatial selection and is not equivalent to learning from a map. Automated accessibility checks do not establish a complete VoiceOver user experience; spoken output and a full VoiceOver session still require manual review. Map labels are part of the drawing and grow with zoom; surrounding app text follows Dynamic Type. The app adds no custom motion effects.

## Limits

- `xcrun devicectl list devices` found no physical devices. Physical-device behavior and signing are unverified.
- iOS 18 is the deployment target, but runtime checks used iOS 26.5. Older supported OS versions and iPad need device-specific review.
- This is a local first milestone. No TestFlight, App Store, or public release was performed.
- World/continent curricula, detailed NYC neighborhoods, capitals, city-distance scoring, and optional games remain backlog in PROJECT_PLAN.md.

The final result bundle is `build/DerivedData/Logs/Test/Test-Atlas-2026.09.13_23-50-51--0400.xcresult`. Raw Xcode logs and result bundles remain under ignored build/task paths. The standard test command prints the current `.xcresult` location at completion.
