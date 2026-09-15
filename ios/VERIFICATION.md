# iOS app verification

## All-map source and shoreline review — 2026-09-14

Reviewed all 12 catalog entries. Four packs are playable; the other eight remain reference data. The complete inventory and source limits are in [MAP_REVIEW.md](../data/MAP_REVIEW.md).

State geometry now excludes mapped lakes from Natural Earth's 10m physical layer. World/continent geometry uses the 50m layer. The focused NYC pack is clipped to each area's own official borough shoreline. All map/question IDs and the 47-area NYC grouping remain stable. Source credits describe the derived geometry.

- All 623 unique area features pass validation. All 309 state/country features match the original administrative source minus the matching lake mask. All 267 official borough/NTA features match their source geometry exactly. All 47 focused NYC areas preserve source membership and inland divisions after shore clipping.
- Nine geographic source checksums pass. Offline recompilation reproduces all 22 generated map/source/repair files byte for byte. The learning validator passes for 66 states and flags, 60 cities, 70 landmarks, and 196 positions.
- The Atlas Debug scheme built and passed **23 unit tests** on iPhone 17 Pro Simulator, iOS 26.5. New regressions verify water hit testing for US and German lakes, DUMBO, and Newtown Creek, plus a selectable interior for every one of the 118 playable areas at two viewport sizes with zoom/pan. Existing Great Lakes, Illinois, antimeridian, inset, distance, and native layer checks also pass.
- **Six selected UI tests passed**: polygon taps/callouts/gestures, native pan alignment, Germany study selection, NYC neighborhood selection, NYC groups/name mode, and landmark pin/distance. Unchanged timer and full-session UI tests were not rerun in this review; their earlier evidence remains below.
- A separate iPhone 17 Simulator run confirmed the US overview and insets, Germany state selection, and the reduced NYC map with DUMBO selection and zoom.

Result bundle: the task's `work/map-audit/build/MapAudit/Logs/Test/Test-Atlas-2026.09.14_20-54-42--0400.xcresult`. Raw logs: `/private/tmp/atlas-map-audit-tests.log`, `/private/tmp/atlas-map-audit-validate.log`, `/private/tmp/atlas-map-audit-learning.log`, and `/private/tmp/atlas-map-audit-review.log`.

This update was verified in Simulator. The physical iPhone still has the earlier Release installation described below; this review does not establish device behavior for the new geometry. The world and continent layouts remain unexposed pending camera, antimeridian, and curriculum work.

## Native map performance and Great Lakes — 2026-09-14

The app remains native SwiftUI, UIKit, Core Graphics, and Core Animation. There is no web view, JavaScript UI, or external runtime. Map shapes now use retained `CAShapeLayer` paths. Gestures change native layer transforms; only labels, callouts, and pins need drawing. Unchanged SwiftUI updates no longer request map redraws. Question changes reset the viewport without destroying the map view. Bounds checks narrow polygon hit tests. Bundled map decoding runs outside the main actor, and UIKit caches flag images. Timer display updates occur when the displayed second changes; expiry still checks elapsed time every 200 ms.

### Measurements

Measured with Xcode 26.6, iOS 26.5, iPhone 17 Pro Simulator, Debug configuration, a 360 × 380 canvas, and 30 map updates at 2× zoom:

| Map | Previous CPU drawing work per update | Updated CPU work per update |
| --- | ---: | ---: |
| United States | 37.35 ms | 0.77 ms |
| Germany | 13.46 ms | 0.80 ms |
| NYC boroughs | 200.01 ms | 0.40 ms |
| NYC neighborhoods | 15.03 ms | 0.42 ms |

These measurements cover app-side work. Previously, the benchmark drew all polygons into a bitmap. It now changes the native layer transform, draws annotations, and flushes the Core Animation transaction. Rendering in the system compositor/GPU is excluded, so these are not end-to-end frame times or measured physical-phone speedups. Initial layout construction remains about 48 ms for US states and 81 ms for boroughs in this Debug run; that work is now retained across questions rather than repeated for each one.

### US geometry and validation

The US pack now uses Natural Earth's official Admin 1 variant without large lakes, version 5.1.1. The archive is pinned with a SHA-256 hash. Original state names, order, IDs, and saved score keys remain stable. The source retains the Illinois shoreline and both Michigan peninsulas; the Great Lakes are water rather than state fill. No manual lake shape or screen-coordinate correction is used.

Both data validators pass: 12 packs, 623 valid area features, 66 state facts and flags, 60 ranked cities, 70 sights, and all 196 learning coordinates. A second offline compilation reproduced all 22 generated map files byte for byte.

All **37 distinct automated tests passed**: 21 unit checks and 16 Simulator UI checks. The complete 21-unit/15-UI suite passed first. An additional real pan-and-tap regression then passed after moving its test tap away from the border tolerance. Coverage includes all five Great Lakes as water, near-shore Illinois land, both Michigan peninsulas, retained native paths, transform alignment, resize, question viewport reset, gesture input, labels, pins, all modes, timer expiry, and accessibility controls.

The full result bundle is in the task's `work/performance/build/PerformanceUpdated/Logs/Test/Test-Atlas-2026.09.14_18-58-45--0400.xcresult`. The extra pan test is `Test-Atlas-2026.09.14_19-08-14--0400.xcresult` in the same directory. The before-change benchmark is under `build/PerformanceBaseline/Logs/Test/Test-Atlas-2026.09.14_18-54-05--0400.xcresult` in that task directory.

A separate iPhone 17 Simulator inspection confirmed visible lake shorelines, Illinois selection, state labels, flag details, and enlarged native map shapes. Automated pan input also confirmed that the moved Washington polygon and answer hit testing stay aligned.

### Phone installation

A signed **Release** build was installed successfully on the connected iPhone Air using the existing paid developer team. The compiler used `-O` and whole-module optimization. `ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO` removed test instrumentation; these settings must be included when repeating this development build because the scheme enables test coverage. Build output: `build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app`.

Automatic launch was blocked by the iPhone lock screen. Unlock the phone and open Atlas Practice. Installation is verified; physical-phone interaction performance is not yet measured. No remote push, TestFlight upload, or App Store release was performed.

## NYC map reduction — 2026-09-14

The active NYC neighborhood map now has **47 areas: all 37 original Manhattan areas plus ten areas outside Manhattan**. The five named Brooklyn/Queens neighborhoods retain their polygons. The other Brooklyn and Queens areas use explicit source unions. The Bronx and Staten Island each use one official borough boundary. The new map ID keeps scores separate from the earlier 266-area map.

- Generic iOS Simulator Debug build passed with Xcode 26.6 (17F113), Swift 6, and deployment target iOS 18.0.
- Both Python validators passed: twelve packs and 623 valid area features, plus the unchanged state, flag, city, and sight database. Checks confirm exact Manhattan boundaries, separate named neighborhoods, unique group membership, complete Brooklyn/Queens source-member coverage, and exact official Bronx/Staten Island polygons. All 22 generated map/source/repair files reproduce byte-for-byte offline. The original candidate, repair report, and source locks are unchanged.
- **18 unit tests and three selected UI tests passed** on iPhone 17 Pro, iOS 26.5. Map-hit and coordinate round-trip checks now include both borough-sized answers, all three merged practice groups, DUMBO, and Long Island City at two viewport sizes and with zoom/pan.
- UI checks passed for Chinatown search; Bed-Stuy, Long Island City, and Staten Island selection; the 47-area description; a correct answer in Name the area; and a complete five-borough quiz. Other UI tests were not repeated for this data change; their earlier results are below.
- A separate iPhone 17 Simulator launch showed the 47-area home entry, reduced boundaries, study labels, and West Brooklyn selection. A direct tap inside Staten Island selected the whole island and displayed the expected answer feedback. The app was left on the NYC neighborhood mode selector.

Result bundle: `build/DerivedData/Logs/Test/Test-Atlas-2026.09.14_16-35-25--0400.xcresult`. Build and test logs are in the task's `work/nyc-focused/` directory. The update is saved locally; no remote publication is part of this check.

## Earlier app expansion — 2026-09-14

Verified on 2026-09-14 with Xcode 26.6 (17F113), Swift 6 language mode, and iOS Simulator 26.5 (23F77). Deployment target: iOS 18.0.

### Build and data

- Generic iOS Simulator Debug build succeeds from the saved repository's committed project structure. Maps, the learning JSON, and all 66 PNG flags are bundled; no app package dependency or server is required.
- Both Python validators pass: twelve packs, 842 individually valid area features, 769 retained city/town points, 66 complete state facts, 60 ranked city populations, 70 landmarks, and 196 capital/city/landmark positions.
- Source and asset checksum locks pass. Two successive offline compiler runs reproduced 21 generated map/fact/repair files byte-for-byte.
- The NYC local pack includes 266 named areas and separately preserves the original candidate. The two active geometry repairs are documented. Source-download equivalence remains a stated limit.

### Automated tests

All **32 distinct tests passed**: 18 Swift Testing unit tests and 14 XCTest Simulator UI tests. The full UI suite ran on iPhone 17 Pro. After adding the coordinates to location feedback, the saved repository build passed all 18 unit tests and both affected location UI tests again. The final timer-only check passed after disabling polling for untimed and completed sessions. Its repository result bundle is `build/DerivedData/Logs/Test/Test-Atlas-2026.09.14_01-05-32--0400.xcresult`.

Unit checks cover all map packs, projections and antimeridian wrapping, geometry hits and inverse transforms, inset placement for every learning point at two viewport sizes, water acceptance for point questions, inset-gap rejection, all flag image decodes, complete state/city/landmark counts, dated population ordering, unique answer labels, haversine distance, timer pause/resume/expiry, duplicate-answer protection, spaced review, finite sessions, and separate progress for map/mode/timer settings.

UI checks cover all nine game modes; real polygon and pin taps; pinch, pan, zoom, and reset; correct/wrong/revealed answers; a full borough session; coordinate entry; city population dates; flag images; nickname and capital answers; German reference data; NYC neighborhood search; countdown expiry and answer locking; landscape; the largest accessibility text category; and the area-list alternative. The accessibility audit checks touch-target size, descriptions, and contrast on the Find screen.

The full 14-test UI bundle is in the task's `work/expansion/DerivedData/Logs/Test/Test-Atlas-2026.09.14_00-53-11--0400.xcresult`. The final repository unit/location bundle is `build/DerivedData/Logs/Test/Test-Atlas-2026.09.14_01-01-45--0400.xcresult`. Raw logs and result bundles remain under ignored build/task directories. Run `scripts/ios.sh test SIMULATOR_UDID` to repeat the complete scheme.

### Runtime inspection

The repository build was installed and launched separately on iPhone 17 Simulator. Native UI readback and screenshots confirmed the expanded mode selector, authentic Colorado and California flags, a correct flag answer, and a Florida landmark answer pin. Manual pause disabled answer controls; resume restored the countdown. Advancing reset it to 30 seconds. After leaving the app on the Simulator Home screen for over a minute, it returned with 22 seconds left rather than expiring. A separate landmark question displayed timeout feedback and inserted one review.

The current Minnesota and Utah flag assets were visually checked. No generated substitute flag artwork is used.

### Limits

- Physical-device behavior and signing remain unverified. No TestFlight, App Store, or public release was performed.
- Runtime verification used iOS 26.5. Older supported OS versions and iPad need device-specific review.
- Native controls have accessibility labels, and answers post announcements. A complete spoken VoiceOver session has not been verified. The custom map has area-list and coordinate-entry alternatives; those do not reproduce visual spatial learning.
- NYC boundaries are approximate and include parks and islands. Individual topology checks do not prove complete gap/overlap coverage. The datHere catalog declares ODC-By, but the licensed resource download could not be compared with the pinned mirror.
- City populations are dated city/municipal figures, not live counts or metropolitan populations. Landmarks are a curated set, not a popularity ranking. Large parks use an identified reference point.
