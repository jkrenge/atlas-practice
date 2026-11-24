# iOS app verification

A dated log of verification runs, newest first. Evidence paths under `build/` are local and not in the repository.

## Settings, support links, and release preparation — 2026-11-23

The home screen ends with a Settings button (shown once the maps load). Settings holds the round settings that used to sit on each map page (questions 10/25/All, timer Off/30 s/60 s), a note that progress stays on the device, Reset progress (with a confirmation; it also clears the last map played), Help and support and Privacy policy links to the website (`AtlasLinks`), Map sources and credits, and the version and build. Each map page's Start here card now says what a round is ("10 questions · 30 s each"). New York City is a half-width card with the boroughs map, reading "2 maps". The credits gained the Natural Earth world-map line, the ODC-By notice for NYC neighborhoods, and the Destatis source note. `ios/Atlas/PrivacyInfo.xcprivacy` declares no tracking and no collected data, plus UserDefaults (CA92.1) and system boot time (35F9.1); it is in the built app.

Tests: a new unit test covers resetting progress; the session-length UI test now sets the length in Settings; the credits test reaches Sources through Settings and audits the Settings screen. Three UI-test waits used `XCTWaiter.wait(for: [], timeout:)`, which returns at once; a `pause` helper now really waits, so the accessibility audit settles for 1.2 s, the auto-advance-cancel test really waits 3.5 s, and screenshots catch the rank stamp. The three-second auto-advance test now starts its clock before the tap (XCUITest returns from a tap only once the app is idle) and expects at least 2.9 s. The contrast re-measure locates a label's own text pixels when a wide List header puts the map behind a short taped label; `testRenderedContrastMeasure` checks it still fails pale text.

`scripts/screenshots.sh` captures eight frames on iPhone 17 Pro (1206 x 2622), iPhone 17 Pro Max (1320 x 2868) and iPad Pro 13" (2064 x 2752) with a 9:41 status bar, into `build/screenshots/`, and web copies into `website/assets/screens/`. The website (`website/`, Pages workflow `.github/workflows/pages.yml`) was built, reviewed for accuracy and accessibility, and checked in a browser at 390 and 1280 px under a project sub-path; owner placeholders are listed in `website/README.md`.

On the final code the full suite passed: 62 of 63 tests, with the screenshot test skipped (it runs only from `scripts/screenshots.sh`). All 24 screenshots are the exact App Store sizes without alpha, and the results frame shows the rank stamp.

## New York City page — 2026-11-23

The home screen now lists United States and Germany as squares, then one full-width New York City card that shows both NYC maps side by side and their combined first-try accuracy. It opens a new `CityScreen` (large title "New York City", a short taped intro, and Boroughs and Neighborhoods squares), which pushes the existing map setup. The city page's backdrop camera is wider than each NYC map's, so opening one zooms in. The boroughs map is now titled "NYC boroughs" (it was "New York City"). `MapGrid` replaces the home grid so both screens share one column rule; `PracticeRecord` gained `+`, which `ProgressStore.summary` now also uses. Card titles stay on one line and shrink slightly when needed, because "Neighborhoods" otherwise broke mid-word at xLarge text in a half-width card.

UI tests reach NYC maps through `map-nyc` (helpers `openMap` and `backHome`). The NYC practice test now checks and audits the city page, including its intro, and captures the home card and the city page. The full suite passed on the first build (60 of 60: 30 unit tests and 30 UI tests). After the review fixes, the six affected UI tests passed again (NYC practice, largest text, Blue Study library, home navigation performance, NYC gameplay performance, borough session). NYC gameplay and home navigation benchmarks now include the city page push, so their numbers are not comparable with earlier runs. A three-angle review found one older issue that this change did not fix: going back to a scrolled screen resets the backdrop parallax until the next scroll, so the map can jump slightly then.

## NYC neighborhoods: Downtown Brooklyn, Crown Heights, Prospect Park, and Seaport — 2026-11-23

Downtown Brooklyn (from West Brooklyn), Crown Heights and Prospect Park (from South & East Brooklyn) are now separate practice areas, using their Pediacities geometry clipped to the Brooklyn shoreline. Seaport is new: no bundled source has it, so `data/nyc-carve-outs.json` holds a hand-drawn outline (Pearl Street west, John Street south), and `scripts/compile_maps.py` cuts it out of the Financial District, whose own edges supply the Brooklyn Bridge and the shore and piers. The street lines are placed from the Wikipedia coordinates of the Titanic Memorial (Fulton and Pearl) and the Schermerhorn Row block, so they are approximate, within roughly a block. The focused pack has 53 areas: 38 in Manhattan and 15 across the other boroughs.

Only `maps/nyc-neighborhoods-focused/*`, the catalog count, and the simplification report changed; the other packs recompiled byte for byte. `scripts/validate_data.py` now checks the carve-out (Seaport equals the source inside the outline, the Financial District the rest, and together they cover the source exactly) and the three new single-source Brooklyn areas, and passes. The validator's feature total is now computed (629); the old hard-coded 623 had not counted the earlier Park Slope split. Renders of the full and low-res geometry show all four areas in place; Seaport is about the size of Little Italy. New geometry probes cover all four areas and the Financial District.

A signed Release build with these four areas passed strict code-signature verification and was installed in place on the test iPhone on 2026-11-23, confirmed in the device app list, and launched. The new areas were not checked by hand on the device.

## NYC neighborhoods: Park Slope and Prospect Heights — 2026-11-22

Park Slope and Prospect Heights are now separate practice areas, carved out of West Brooklyn in `data/nyc-learning-groups.json`. The focused NYC pack has 49 areas: 37 in Manhattan and 12 across the other boroughs. West Brooklyn keeps its 16 other members. Both new areas use their Pediacities source geometry unchanged, clipped to the official Brooklyn shoreline like every other area.

`scripts/compile_maps.py` regenerated only `maps/nyc-neighborhoods-focused/*`, the catalog area count, and the simplification report; every other pack recompiled byte for byte. `scripts/validate_data.py` (expecting 49 areas and the two names as separate single-source areas) passed. A render of the new geometry showed both areas in place; the small gap at Grand Army Plaza comes from the source and was already inside West Brooklyn. Scores already saved for the NYC neighborhood pack stay; they now count against a pack with two more areas.

## School-atlas concept and app icon — 2026-11-22

A new visual concept: one world map in school-atlas style (`AtlasBackdrop.swift`) lies under every screen and glides to a new region per screen; information sits on paper cards and label tape, with a yellow exhibit frame, title tape and a rank stamp as accents (`AtlasCollage.swift`); controls stay one pill and circle shape in paper-veiled Liquid Glass. The backdrop is drawn on device from the bundled Natural Earth countries with water-lining, vector forest and highland tints, invented contour lines, a 10° graticule, ocean lettering and red voyage routes. The palette and components were defined with contrast computed against real map pixels.

The app icon is generated by `scripts/app_icon.swift` (black New York "Atlas" on yellow tape over the eastern Atlantic); the previous icon is kept locally as `build/redesign/AppIcon-previous.png`.

The accessibility audit now waits for the backdrop to settle and re-measures any flagged text from its own rendered pixels (failing below 4.5:1), because the auditor read the map behind opaque paper: "ways to play" measured 7.2:1 rendered but was flagged.

A signed Release build passed strict code-signature verification and was installed in place on the test iPhone on 2026-11-22, confirmed in the device app list, and launched. Physical interaction, on-device contrast of the glass controls, performance, and iPad were not checked.

## Playful voice, Liquid Glass, and one button shape — 2026-11-22

This pass answered feedback on the redesign: it felt boring, Liquid Glass had been removed, and "Practice again" (a pill) and "Done" (a rounded rectangle) did not match.

- One button shape: every text button and answer choice is a 54 pt pill with 27 pt corners (`AtlasStyle.buttonShape`); icon buttons and map callouts are 44 pt circles; cards use one 24 pt radius. Primary, secondary, and quiet variants share the shape and font. Explore map and Browse facts stack when they would otherwise wrap.
- Liquid Glass returns through one helper, `atlasGlass`, on controls only: the floating question pill over the map (iPhone portrait), close and pause circles, map zoom circles, primary buttons (tinted by result), and home badges. It falls back to solid surfaces on iOS 18 and with Reduce Transparency. Information text stays on solid surfaces, which is what passed earlier contrast audits.
- Voice: deterministic headline pools for correct, wrong, near and far pin misses, reveals, timeouts, comebacks, and streaks of 3, 5, and 10; results ranks from Wanderer to Cartographer; travel-themed small copy. VoiceOver reads the plain outcome first, and UI tests assert on it.
- Motion: one symbol bounce or wiggle per answer and one shake on a wrong choice, all off with Reduce Motion.

A design panel produced the spec; a review then confirmed 12 issues, all fixed (wrapping pills, map jokes in non-map modes, truncated "Show answer" at large text, quiet pill states, VoiceOver order for the floating prompt, miter spikes on highlighted coasts).

Verified on an iPhone 17e Simulator, iOS 26.5: all 28 unit tests and 27 UI tests passed in `build/redesign/Glass2.xcresult`, including new equal-height checks for Another round/Done and Lock it in/Show answer, and contrast audits on the results and timeout screens. Not verified: physical device (earlier glass contrast failures appeared only on device), iPad, iOS 18 fallback at runtime, Reduce Transparency and Reduce Motion at runtime, and performance benchmarks for this pass.

## UX and visual redesign — 2026-11-22

Redesigned every screen: native large-title navigation; a home card that starts or resumes the last mode and states its question count and timer; first-try accuracy on map cards; a map screen with a featured Find the area card, segmented question/timer controls, and grouped mode rows tinted by kind; practice in a full-screen cover with a progress bar, timer pill, and a result-tinted bottom panel; fact choices that stay visible with correct/chosen states; a paused overlay; leave confirmation after an answer; and results with an animated first-try ring and Practice again. Map controls are a floating group; wrong picks and guesses use coral, with a dashed guess-to-answer line. Scores shown in the app now combine timer settings; storage is unchanged.

A review confirmed about 30 issues, which were fixed. They included layouts that broke at accessibility text sizes, white-on-coral contrast at 4.33:1 (now at least 4.5:1), VoiceOver focus not moving to a new question, the zoom column covering numbered markers in landscape, the hint chip blocking inset taps, and fact questions keeping the previous scroll position.

Verified on an iPhone 17e Simulator, iOS 26.5, Xcode 27.2:

- All 26 unit tests and 27 functional UI tests passed in `build/redesign/Final.xcresult`. A new unit test covers combined scores. UI tests were updated for segmented controls, the map-name navigation title, locked (not hidden) answers after a timeout, the leave confirmation popover, the Done button, the combined capital fact, and Practice again.
- The accessibility audit now checks the setup screen at four scroll positions. It skips contrast results only for elements partly under the navigation bar or past the screen edge, where the audit samples blurred or black pixels; each such element is audited fully visible at another position.
- Screens reviewed by hand: home, setup, find, name, flag, pin drop with distance, timeout, results, explore, facts, and landscape.

Performance, same Simulator, two iterations each, app CPU time per scripted workload:

| Workload | Previous commit | Redesign |
| --- | ---: | ---: |
| Home scrolling/navigation | 4.47 s | 5.90 s |
| NYC gameplay | 3.84 s | 5.01 s |
| US gameplay | 5.60 s | 6.14 s |

The redesign uses more CPU in these workloads. Removing blurred card and marker shadows reduced it slightly; blocking map-frame animation had no effect; moving VoiceOver focus costs about 4% under XCUITest. No single hotspot was found. The NYC workload now scrolls the setup screen once more before starting, so the workloads are not identical. Hitch metrics are not reported in the Simulator, so frame smoothness was not measured. The NYC benchmark now scrolls the map card into view before measuring, because lower cards are created lazily below the resume card.

Not verified: physical device, iPad, Reduce Motion and Reduce Transparency at runtime, VoiceOver by ear, and Dynamic Type beyond the automated largest-size tests. Nothing was installed on a device or uploaded.

## Blue Study app icon — 2026-11-16

Replaced the app icon with an ultramarine globe and white location marker. Verified the asset is 1024 × 1024 with no alpha channel. The signed Release build and strict code-signature verification passed. Installed the update on the test iPhone, confirmed the bundle in the device app list, and launched it successfully. Build log: `build/blue-study-icon-device.log`. Gameplay tests were not rerun for this asset-only change; the physical Home Screen appearance was not inspected.

## Blue Study controls and layout review — 2026-11-16

Reviewed the library, setup, all quiz modes, correct/incorrect/timeout feedback, results, study selection, reference lists and details, source disclosure, credits, coordinate entry, area selection, and empty search states. Kept native SwiftUI, existing geometry, scoring, and progress storage.

Changes: white map cards with explicit Explore actions; bordered practice rows, settings, answers, secondary buttons, and source links; stronger type hierarchy; distinct map and feedback surfaces; one question heading; fact questions and answer choices in the same scrolling card; an empty area-search state; grey selection feedback text matching the map. Larger text uses stacked layouts.

Validation on iPhone 17 Pro / iOS 26.5 with Xcode 27.2:

- Simulator and signed Release builds passed; strict code-signature verification passed.
- All 25 unit tests passed. All 27 functional UI tests passed across the main run and focused reruns, including accessibility audit, largest text, landscape, all quiz modes, map gestures, results, and reference details.
- The first new search-cancel test used the wrong system selector. Inspected its accessibility hierarchy and corrected the test to close active search before cancelling the sheet. The rerun passed.
- Inspected 35 distinct screen/state screenshots, then reviewed fresh fact-question screenshots after grouping their answers with the prompt.
- `git diff --check` passed. Existing XCTest setup actor-isolation warnings remain; no new app build warnings were reported.

Evidence (ignored local artifacts): `build/BlueStudy-polish.xcresult`, `build/BlueStudy-polish-final.xcresult`, `build/blue-study-polish/`, and `build/blue-study-polish-device.log`. The main bundle retains the initial test-selector failure; the final bundle has five passing affected checks.

Installed the signed Release as an update on the test iPhone without uninstalling. Physical touch interaction, iPad, older iOS versions, and release frame-rate benchmarks were not checked in this review. The app remains light-only.

## Blue Study device installation — 2026-11-16

Built the current working tree in Release for the test iPhone with the configured developer team. Strict code-signature verification passed. Installed as an update without uninstalling, verified the app in the device app list, and successfully launched Atlas Practice. Physical interaction and frame-rate checks remain unverified. Build log: `build/blue-study-device-build.log`.

## Blue Study UI — 2026-11-15

Applied the selected Blue Study concept to the existing SwiftUI app: ultramarine outlines, grey canvas, light headings, monospaced labels, a two-column library, and flat controls. Accessibility text sizes use a single library column. Existing map geometry, gameplay, progress storage, and the light-only appearance are retained.

Verified on iPhone 17 Pro, iOS 26.5 Simulator:

- Build and launch passed.
- Six initial UI tests passed: library/practice navigation, all four maps at the largest text size, large-text answer controls, landscape controls, polygon taps/zoom/pan, and coordinate entry.
- The accessibility audit first found a small Show answer hit region. Added an explicit content shape after the button frame. The accessibility audit and library/practice navigation both passed on rerun.
- Reviewed library, practice setup, and answer-feedback screenshots. No changes to source geography or quiz scoring.
- `git diff --check` passed.

Evidence: `build/BlueStudy.xcresult`, `build/BlueStudy-controls.xcresult`, and `build/blue-study/`. These are ignored local build artifacts. No physical-device verification, dark theme, or release frame-rate measurement was performed for this change.

## Liquid Glass physical-device check — 2026-10-10

The current app was built, installed, and tested on a physical iPhone Air running iOS 27.0.1 with Xcode 27.0. Five functional UI checks passed: glass card navigation and answer actions, library scrolling, polygon/callout/zoom behavior, landscape controls, and the largest accessibility text size. The navigation and answer test passed again after the setup controls changed.

The first accessibility audit passed the library but failed contrast on the setup screen’s Explore map action. System text color alone and native glass button styling did not resolve that result. The Explore map/Browse facts row now has system text color and a solid surface. Both library and setup audits pass. The practice audit still fails contrast on the native Show answer glass button. Its failure screenshot shows black text on a pale surface, but the cause is unconfirmed. The test was not weakened or filtered, and full device accessibility approval remains incomplete.

Debug functional results and failed audit attempts are retained in `build/glass-device-2026-10-10/`: `Functional.xcresult`, `Accessibility.xcresult`, `NativeControls.xcresult`, and `SolidNavigation.xcresult`. The last bundle contains screenshots of the current library, setup, and answer feedback. These checks did not complete a practice session or delete the installed app.

All three optimized Release performance workloads passed in `Performance.xcresult`. Each workload has two measured iterations with coverage disabled. Library scrolling/navigation, NYC map interaction, and US map interaction each recorded zero frame hitches. Mean app CPU time per complete workload was 5.488 s, 3.988 s, and 6.239 s, respectively. These are workload CPU totals, not response times. No before/after performance improvement is established by this run. Battery use, sustained thermal behavior, and real-device iPad behavior were not measured.

The Release app passed strict code-signature verification. The current signed build was installed in place and launched normally after the tests. Installation and launch receipts are `install.json` and `launch.json` in the same evidence folder. No TestFlight upload was performed.

## Liquid Glass design — 2026-10-10

The library and practice setup use solid information cards with native Liquid Glass navigation controls on iOS 26 and later. Map prompts, zoom controls, and practice actions use glass. Rounded system type and larger previews connect the library, study, facts, and results screens. The deployment target remains iOS 18. Older supported systems use materials and standard bordered buttons. Custom glass surfaces become solid when Reduce Transparency is enabled. The map renderer, geometry, scoring, timers, and stored progress format did not change.

The app built with Xcode 27.0 and ran on iPhone 17 Pro Simulator, iOS 26.5. All 25 unit test functions and 11 of the 12 selected UI checks passed in `build/glass-design/Functional.xcresult`. The initial contrast audit failed on the Offline badge. After correcting that badge, the audit found a contrast failure in the practice action row. Native glass buttons with system text colors above a solid panel resolved it. The expanded audit also checks answer feedback and the white Continue label; it passed in `AccessibilitySurface.xcresult`. The glass navigation, map tap/zoom, and largest-text checks passed again in `AccessibilityNative.xcresult`. The earlier failed contrast runs remain as evidence.

On iPad Pro 13-inch (M5) Simulator, iOS 26.5, navigation, landscape, and largest-text checks passed in `iPad.xcresult`. The contrast audit found additional failures with glass behind card captions and material behind the question count. An unchanged HEAD build passed the same audit in `iPadBaseline.xcresult`. The final design separates solid information surfaces from glass controls and uses stronger captions. The full audit of home, setup, practice, and feedback then passed in `iPadOpaqueHeader.xcresult`.

The final iPhone build passed the glass navigation/action test, the largest-text test, and the full accessibility audit in `iPhoneFinal.xcresult`. That result includes screenshots of the library, setup, and feedback screens. Across the runs, all 25 unit test functions, 12 selected iPhone UI checks, and four iPad UI checks passed.

Screenshots and result bundles are under `build/glass-design/`. Test compilation reported existing actor-isolation warnings in the UI test setup method. No physical-device performance measurements, iOS 27 runtime checks, or iOS 18 runtime checks were made. The Reduce Transparency branch was inspected in code but not exercised through the system setting. This work did not upload a TestFlight build.

## Physical-device performance comparison — 2026-10-08

The retained-path renderer uses less CPU but produced more frame hitches in physical-device recordings. It and the trial that deferred border-width updates during pinches were rejected. The app source now uses the native `UIScrollView` and cached `CATiledLayer` renderer again. This keeps the prior UI changes, three-second automatic advance, reduced geometry, map projections, and selection behavior. The 50% performance target remains unmet.

Unprofiled Release workloads ran on an iPhone Air, iOS 27.0.1, with coverage disabled. Each CPU mean contains two measured iterations. Release questions remain random; these are scripted workloads, not complete measurements of user interaction.

| Workload | Tiled CPU | Retained-path CPU | CPU reduction |
| --- | ---: | ---: | ---: |
| Home scrolling/navigation | 4.804 s | 4.645 s | 3.3% |
| NYC gameplay | 3.482 s | 3.048 s | 12.5% |
| US gameplay | 5.658 s | 3.414 s | 39.7% |

XCTest reported zero hitches in all of these workloads. That result does not establish smooth frame delivery: separate Time Profiler plus Hitches captures of the US workload found the following app hitches.

| Renderer | Capture duration | Hitches | Total hitch time | Hitch time per second |
| --- | ---: | ---: | ---: | ---: |
| Tiled | 16.68 s | 13 | 308 ms | 18.5 ms/s |
| Retained paths | 17.20 s | 98 | 1,667 ms | 96.9 ms/s |
| Retained paths with deferred pinch strokes | 16.59 s | 84 | 1,313 ms | 79.1 ms/s |

Each trace is one partial capture that ends when the test relaunches the app. Profiling affects timing, and frame counts differ, so these traces do not establish a precise percentage improvement in smoothness. They do show enough regression to reject the retained-path candidates. The deferred-stroke candidate also measured 3.515 s CPU in a separate unprofiled US run. Original retained-path samples included annotation drawing in 185 of 1,833 backtrace samples and Core Animation commits in 634; repeated SwiftUI updates alone do not explain the full cost. NYC and home frame traces were not recorded.

The first device build needed a command-line signing-team override for test targets. One automation initialization timed out and passed on retry. A notification interrupted the initial home test; its result was excluded, and the home test passed after Do Not Disturb was enabled. All three baseline workloads and both separate profiling test runs passed. The candidate pinch workload and its profiling run also passed.

The restored tiled source passed all 25 unit test functions (31 cases including parameterized maps) and four physical-device UI checks: home scroll movement, native pan/tap alignment, polygon/callout/zoom behavior, and correct-answer automatic advance. `FinalFunctional.xcresult` reports no failures or skipped tests. A normal signed Release build passed strict signature verification; its 18 geometry/manifest files match the workspace. It was installed in place and launched on the iPhone without deleting app data. Receipts are `final-install.json`, `final-launch.json`, and `final-bundle-check.json`. `git diff --check` passed. No test screenshots were attached to the final test result; the assertions supply the functional evidence.

Evidence is in `build/device-performance-2026-10-08/`: `comparison.json`, `profile-comparison.json`, exported metrics, `CurrentRetry.xcresult` (NYC/US passes; interrupted home excluded), `CurrentHome.xcresult`, `Baseline.xcresult`, `Profile.xcresult`, `BaselineProfile.xcresult`, `PinchMetrics.xcresult`, `PinchProfile.xcresult`, and three `*-TimeProfiler-Hitches.trace` recordings. Rejected renderer source snapshots remain in this ignored evidence folder. This testing did not upload a TestFlight build.

## Performance optimization — 2026-10-06

The 50% performance target remains unmet. The current renderer keeps native `UIScrollView` interaction and replaces `CATiledLayer` drawing with retained `CAShapeLayer` paths. Pan, zoom, and answer changes retain the base layers; canvas resizing replaces them. Borders keep their screen width. Full map geometry, projections, water holes, insets, hit tests, and separate answer overlays remain in use.

The unchanged gameplay workloads ran in baseline and candidate Release builds on iPhone 17 Pro Simulator, iOS 26.5, with coverage disabled and no profiler attached. Each mean contains two measured iterations:

| Map | Tiled baseline CPU | Retained-path CPU | Reduction |
| --- | ---: | ---: | ---: |
| NYC boroughs | 5.358 s | 5.054 s | 5.7% |
| United States | 6.654 s | 5.099 s | 23.4% |

A second candidate grouped base geometry into two layers. It measured 4.943 s for NYC and 5.379 s for the US map, and was rejected because the individual retained layers performed better overall. Release question order remains random. These simulator CPU results do not prove a 50% improvement or physical-device smoothness.

A separate Time Profiler recording of the retained-path candidate captured 936 samples with backtraces before the test relaunched the app. Annotation drawing appeared in 41 samples. Core Animation commits and XCTest accessibility snapshot work account for a substantial part of the remaining samples. Two earlier attach attempts lost the app process during relaunch; a third could not resolve the process name. Only the fourth recording supplies trace evidence. The physical iPhone was unavailable.

A temporary diagnostic Release build omitted base geometry, answer overlays, and annotation drawing. The unchanged NYC workload still measured 5.062 s CPU (iterations 5.092 s and 5.031 s), versus 5.054 s for the retained renderer. Removing map drawing did not materially reduce this workload's remaining CPU time. This rules out further map drawing changes alone as a route to the 50% target in this benchmark; it does not prove physical-device rendering performance. A phone profile of the reported slow interaction is required before choosing another rendering change. The iPhone was checked again and remained unavailable. Source restoration after diagnostic compilation was verified byte for byte, and the verified retained-path Release app was reinstalled and launched in the simulator. Diagnostic logs, metrics, and `Floor.xcresult` are under `build/performance-50/floor/`; the diagnostic is not part of the app source or TestFlight build.

The final candidate passed all 25 unit test functions and four focused UI checks: polygon/callout/zoom behavior, pan alignment, location pins, and three-second automatic advance. The answer screenshot was inspected. An initial new assertion incorrectly required object identity for a path that Core Animation copies; it now checks geometry equality and passed on repeat. Evidence is in `build/performance-50/`: `Baseline.xcresult`, `Candidate.xcresult`, `Batched.xcresult`, `RetainedFunctional.xcresult` (four UI passes; initial unit assertion failure), `RetainedUnit.xcresult`, exported metrics, `retained-comparison.json`, `Candidate-TimeProfiler-4.trace`, `profile.xml`, and `retained-screenshots/`. This renderer change has not been uploaded to TestFlight.

## TestFlight upload — 2026-10-05

Version 1.0 (1) was archived, signed for App Store distribution and uploaded to App Store Connect on 2026-10-05. Both the archive and App Store distribution package passed strict signature verification. The distribution profile has no development debug entitlement or device list. All 87 bundled map/content files match the workspace. Version/build settings are now present in the project and its XcodeGen source. The app uses system-provided HTTPS and no custom encryption; the generated encryption key is Boolean false, consistent with [Apple's guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations).

Xcode confirmed that Apple accepted the package and started processing it. TestFlight readiness and tester availability were not checked. The upload receipt is `build/testflight-2026-10-05/upload-created-record.log`. The signed package is `build/testflight-2026-10-05/FinalExport/Atlas.ipa`; the archive is `Atlas-TestFlight.xcarchive` in the same evidence directory. Archive/export logs and `final-package-verification.json` record the verified package. Existing code and UI checks are documented below; no app logic changed for this release preparation.

## Native tiled map interaction — 2026-10-05

`UIScrollView` now handles pan, pinch, and deceleration. `CATiledLayer` draws the base map on background threads and caches tiles at multiple zoom levels. It draws only shapes that intersect the requested tile. The map projections, Alaska/Hawaii insets, polygon hit tests, and geographic pin coordinates remain in use. Two separate shape layers show selection and the correct answer; answer changes do not recolor every base shape. Base tiles remain attached during pan, zoom, and selection changes at the same canvas size. A canvas resize refits the map and replaces the tile layer. Stroke widths and accessibility values update only when they change, empty annotation layers skip redraws, and scrolling uses faster deceleration. No SDK dependency was added.

All 25 unit test functions passed, including four native-map cases that check tile reuse, coordinate alignment, native viewport readback, resizing, and reset. Fifteen distinct functional UI checks passed across iPhone and iPad runs. The final three focused iPhone checks passed after the last changes: automatic advance, pan alignment, and polygon/callout/zoom behavior. Functional checks use Debug's deterministic question order; two ordering-dependent checks also attempted in Release failed on random question order, then passed in Debug. A drag test now holds before release to test a known tap position without scroll momentum. The gameplay screenshot was reviewed.

The same existing gameplay workloads ran in baseline and updated Release builds on iPhone 17 Pro Simulator, iOS 26.5, with coverage disabled and no profiler attached. Each CPU mean contains two measured iterations:

| Map | Previous renderer CPU | Native tiled renderer CPU |
| --- | ---: | ---: |
| NYC boroughs | 5.173 s | 5.676 s |
| United States | 5.147 s | 6.903 s |

Total CPU increased. Native momentum also changes the workload duration, and Release questions use random order. These figures do not demonstrate a performance gain. Simulator returned CPU metrics but no hitch measurements; missing frame data is not a zero-hitch result.

A separate Release Time Profiler recording saved an 11.04-second trace with readable application symbols. Of 1,730 CPU samples with backtraces, 855 included tile drawing on five background threads and none included tile drawing on the main thread. Annotation drawing appeared in 67 samples; map layout appeared in one. The trace ended when the test relaunched the app and reported one table without a known input source. CPU samples were exported and inspected; the short capture does not establish full-session frame delivery. The SwiftUI/Hitches recording failed because Hitches does not support this Simulator platform, so it supplies no frame evidence. The physical iPhone was offline. Device smoothness and the reported lag remain unverified.

Evidence is in `build/native-map/`: `Verified.xcresult`, `Unit.xcresult`, `UI.xcresult` plus the passing `Pan.xcresult` repeat, `iPad.xcresult`, `Baseline.xcresult`, `FinalMetrics.xcresult`, `comparison.json`, `TimeProfiler-release.trace`, `time-profile.xml`, `profile-summary.json`, recording logs, and reviewed screenshots. Release builds passed, and `git diff --check` passed.

## Further map simplification — 2026-10-05

The simplifier now allows four times the prior maximum distance and caps each feature's symmetric-difference area at 1% instead of 0.5%. Small rings still receive lower distance limits, shared borders remain matched, and known lake and river points remain water. Detailed source geometry is retained. Rendering and answer selection use the same generated assets.

The six unique assets decrease from 143,647 to 109,138 points (24.0% fewer) and from 4,468,096 to 3,425,983 bytes (23.3% smaller). The four playable maps decrease from 45,258 to 32,483 points (28.2% fewer). US states decrease from 25,208 to 19,132; Germany from 5,351 to 4,070; NYC boroughs from 7,542 to 4,767; and focused NYC neighborhoods from 7,157 to 4,514. High zoom levels show coarser coastlines.

Map/source validation and all 196 learning-coordinate checks passed. All 25 unit test functions and five focused iPhone 17 Pro Simulator UI tests passed: automatic advance, German selection, native pan alignment, NYC selection, and polygon taps/callouts/zoom. Evidence is in `build/vector-reduction/`, including `before.json`, generation and validation logs, and `Verified.xcresult`. The Simulator screenshot was reviewed. These checks verify the reduced point count and interaction correctness; they do not establish improved physical-device frame delivery.

## Reduced map geometry — 2026-10-04

All 12 map manifests now use six shared simplified GeoJSON assets. The compiler uses pinned Mapshaper 0.7.72 with Douglas–Peucker simplification on shared boundaries. Small islands and holes get tighter distance limits. Invalid source coverage is normalized before simplification. Validation limits each feature's symmetric-difference area to 0.5% and checks shared topology, metadata, selectable interiors, and known water locations. Rendering and answer selection use the same reduced geometry. Detailed source files remain unchanged in the repository and are excluded from the app bundle. Coastlines have less detail at high zoom.

The six unique assets decrease from 450,408 to 143,647 points (68.1%) and from 17,457,955 to 4,468,096 bytes (74.4%). The four playable maps decrease from 218,631 to 45,258 points (79.3%). Regeneration produced identical asset hashes. Data and learning validation passed, including source checksums and 196 learning coordinates.

All 25 unit test functions and seven focused Simulator UI tests passed, including water boundaries, selection, pan, zoom, coordinate entry, and home scrolling. Three Release tests passed on an iPhone Air: home scroll movement and US/NYC gameplay workloads. Recorded hitch metrics were zero; CPU averages were NYC 3.276 seconds and US 3.753 seconds. These checks do not establish that the previously reported freeze is resolved.

Evidence is in `build/geometry-review/`: `SimulatorVerified.xcresult`, `Device.xcresult`, validation logs, and `reproducibility.json`. A clean normal Release build passed strict signature verification. Bundle verification confirmed that all 12 manifests reference reduced assets, all bundled map/content files match the verified source, and detailed geometry is excluded (`release-verification.json`). The verified normal Release app was installed in place and launched successfully. Installed-app readback confirmed Atlas Practice. Receipts are `install.json`, `app.json`, and `launch.json`; `phone-final.png` records the home screen.

## Home-screen responsiveness — 2026-10-04

The prior resize change did not resolve the reported home-screen problem. The library and pack previews used interactive map renderers with about 219,000 geometry points across four maps. Previews now use a static UIKit backing image and separate simplified paths prepared during background map loading. The full paths, playable map renderer, hit tests, water checks, and pin coordinates are unchanged. Preview geometry contains 16,804 path elements, compared with 219,519 detailed elements. A 360 × 150 preview rendered in 6–18 ms in the Release Simulator unit check.

An intermediate static preview that still drew full paths was too slow. A two-second Simulator sample stayed in Core Graphics path filling on the main thread. Its home navigation workload used 63.619 seconds of Simulator CPU and 30.598 seconds of phone CPU. Reduced previews brought the Simulator workload to 5.986 seconds. The intermediate phone gameplay workloads changed from NYC 27.018 to 3.257 seconds and US 26.017 to 3.680 seconds. These figures compare the intermediate static renderer with the reduced static renderer, not the previously installed version.

The separate comparison against the previously installed live-preview implementation did not demonstrate a home CPU improvement: 4.534 seconds previously and 4.971 seconds with reduced static previews. Both physical-device runs returned zero recorded hitch measurements. Those values do not prove that the reported freeze is resolved. The home performance workload scrolls up and down and opens all four collections; a separate physical-device test explicitly verified that a swipe moves the first map by more than 10 points in both directions, then opens that map. Both checks passed on the test iPhone, iOS 27.0.1. The US and NYC gameplay workloads also passed. The first updated home run was interrupted by a notification banner; its focused repeat passed. An initial baseline launch failed; its repeat passed.

All 25 unit test functions passed, including four preview-rendering cases and existing geography checks. Simulator home navigation, accessibility, study selection, and full-screen feedback checks passed. The Simulator screenshot was reviewed. Evidence is in `build/performance-review/`: `ReducedPreviewsSimulator.xcresult`, `ReducedPreviewAccessibility.xcresult`, `HomeBaselineDeviceRetry.xcresult`, `ReducedPreviewsDevice.xcresult` (gameplay passes; interrupted home check), `ReducedHomeDeviceRetry.xcresult`, and `HomeScrollMovementDevice.xcresult`. Corresponding metrics JSON and the readable Simulator sample are in the same directory. The broad Animation Hitches trace did not finish saving and was stopped; it is not usable evidence.

The normal signed Release build passed strict signature verification and installed in place. App readback confirmed Atlas Practice, and launch succeeded. Installation, app readback, launch, and a physical-device screenshot are recorded as `home-final-*` under the evidence directory. Saved progress was retained. The reported complete freeze remains unconfirmed by these automated checks.

## Gameplay performance — 2026-10-04

The full-screen layout exposed a resize regression: changes to the answer panel changed the map bounds, which rebuilt projected geometry, interior anchors, and all shape layers on the main thread. The geometry rebuild was confirmed in a sampled Release gameplay stack. Pan and zoom still retained paths between resizes, but panning also assigned unchanged stroke widths on each update.

Map loading now prepares geometry once on a background executor. Previews and play screens share the prepared paths. Fitting a canvas changes transforms, anchors, and bounds; it does not reconstruct the paths. UIKit keeps the same shape layers during resizing. Hit tests apply the inverse fit, and strokes retain their screen width. Panning no longer updates stroke widths. Swift's `sending` transfer keeps the prepared Core Graphics objects out of unchecked Sendable wrappers.

### Measurements

Same iPhone 17 Pro Simulator, iOS 26.5, Release optimization, coverage disabled. Each resize sample changes a 402-point-wide native map through six heights and flushes the Core Animation transaction. Values measure app-side CPU work, not GPU frame time.

| Map | Previous resize | Updated resize |
| --- | ---: | ---: |
| United States | 4.668 ms | 0.042 ms |
| Germany | 1.170 ms | 0.030 ms |
| NYC boroughs | 5.929 ms | 0.032 ms |
| NYC neighborhoods | 4.357 ms | 0.041 ms |

The identical navigation, answer, pan, pinch, reset, and Continue workloads also ran in baseline and updated Release builds. Whole-app CPU measurements were similar: NYC 5.193 → 5.096 seconds and US 5.342 → 5.327 seconds across each measured workload. These include UI automation work and do not establish perceived smoothness. Simulator returned CPU metrics but no `XCTHitchMetric` measurements; missing frame data is not a zero-hitch result.

### Verification and remaining work

All 24 unit tests and the full 20 existing UI tests passed. The retained-layer regression test now covers all four playable maps, including resize, transform alignment, stroke width, and selectable interiors. Both new performance workloads passed in Debug and Release. Three focused iPad checks passed: accessibility, full-screen feedback, and study selection. An updated Release gameplay screenshot was reviewed, and the optimized app was restored to Simulator after the baseline comparison.

Evidence is in `build/performance-review/`: `Optimized.xcresult`, `FramePerformance.xcresult`, `ReleaseOptimized.xcresult`, `ReleaseBaseline.xcresult`, `iPad.xcresult`, benchmark logs, metrics JSON, and the sampled baseline stack. The isolated baseline source under that directory uses the previous map renderer with the same test workloads. Instruments traces have a missing-input-source warning and unresolved application symbols; the native `sample` output provides the readable stack evidence.

The signed Release build passed strict code-signature verification and was installed in place on the test iPhone. The installed-app query confirmed Atlas Practice. The physical UI test runner timed out while enabling automation mode, so no gameplay frame measurements were collected. The normal Release build was installed again after the failed test run. Automatic launch was then blocked because the phone had locked. Installation receipts, app readback, and test diagnostics are in `build/performance-review/` (`install-final-now.json`, `app-readback-now.json`, and `DeviceFramesNow.xcresult`). Physical-device frame measurements remain required before claiming that the reported lag is fully resolved.

## Session length — 2026-10-04

The practice setup now has a **Places per session** picker with 10, 25, and All. The default is 10. The choice persists across launches and applies to every mode. All uses the current mode's eligible places; numeric options are capped at the available count. Existing missed-place reviews remain separate from the selected number of unique places. Progress totals keep using actual first-attempt counts.

The Debug build and all 24 unit tests passed. Four focused iPhone UI tests passed: all length choices with persistence after relaunch, accessibility, largest text, and completion of the five-borough session with a limit of 10. The length-choice and accessibility checks also passed on iPad mini. An iPad screenshot confirmed the native menu. Logs and result bundles are in `build/session-length/`.

The signed Release build passed strict signature verification and installed successfully in place on the test iPhone. The phone then became unavailable, so the installed-app readback and automatic launch could not complete. The installation receipt and connection diagnostics are in the same evidence directory.

## Full-screen gameplay — 2026-10-04

The play screen now gives the map the full available width and height between a compact question bar and a fixed bottom panel. The top bar combines Back, the question, count, timer, and progress. The map card border and repeated mode heading are removed. Answer choices, result feedback, Continue, and Check location stay at the bottom. Feedback sits beside Continue at normal text sizes and stacks above it at accessibility sizes. Long content can scroll within the panel without moving the action. Small-area callouts remain inside short landscape maps.

All **24 unit tests and 19 UI tests** have passing results across the full iPhone run and focused reruns. Coverage includes every mode, polygon selection, callouts, pan, zoom, pin placement, coordinates, timer expiry, session completion, landscape, and the largest accessibility text size. A new layout check verifies an edge-to-edge map occupying more than 60% of the initial play screen and fully visible feedback and Continue. A new geometry check verifies reachable, nonoverlapping callouts in a 180-point-high map.

The full run found a small footer touch target. Moving the 44-point frame inside each button label fixed it. Final accessibility, full-screen layout, and pin-placement checks passed on both **iPhone 17 Pro and iPad mini (A17 Pro)** with iOS 26.5. Screenshots were reviewed for play, feedback, pin entry, landscape, and large text. Temporary screenshot capture code was removed; assertions remain. Evidence is under `build/fullscreen-review/`: `iPhone.xcresult` contains the full run, and `iPhoneVerified.xcresult` and `iPadVerified.xcresult` contain the final checks.

The updated Release build was signed with the existing team and installed in place on the test iPhone. Strict signature verification passed, and all 87 bundled map and content files matched the workspace. The installed-app query and launch succeeded. A physical-device screenshot confirmed the library screen. Game interaction was verified in Simulator; it was not repeated on the physical phone. Build, installation, launch, screenshot, and checksum evidence is in `build/fullscreen-review/device/`.

## Device update — 2026-10-04

The current working tree, including the blue UI, app icon, and practice-flow improvements, was built in Release with Xcode 27.0 and installed on an iPhone Air running iOS 26.7.1. The build used the existing signing team with coverage instrumentation disabled. Strict code-signature verification passed, and 87 bundled map and content files matched the workspace.

Installation succeeded; the installed-app query then confirmed Atlas Practice. This was an in-place update without uninstalling the app. Launch was blocked because the phone was locked, so this installation does not establish physical-device UI verification.

Build, installation, app readback, launch diagnostics, and source/binary checksums are under `build/device-install-2026-10-04/`. The signed app is `build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app`.

## Practice flow iteration — 2026-10-03

The library has a shorter introduction and smaller map thumbnails so more collections fit on screen. Explore map and Browse facts now sit together above practice. Modes are grouped under Names & facts and Place a pin. Continue and Check location stay in a bottom safe-area inset, and advancing returns the scroll view to the question. Map feedback shows the correct answer before the explanation of a wrong selection. Reference search displays a native no-results message. The Home Screen icon now uses blue to match the app.

The final test build passed with Xcode 27.0 and the iOS 26.5 Simulator runtime. All **23 unit tests and 18 UI tests** have passing results across the full run and focused reruns. The full run passed 16 UI checks, including every mode, map gestures, timer expiry, session completion, landscape, and the largest accessibility text size. The first run found a library row at the bottom edge and an incorrect test query for the native search message. Smaller thumbnails resolved the library audit; the test now queries the native text elements.

The final accessibility, Continue, and search-recovery checks each passed on **iPhone 17 Pro and iPad mini (A17 Pro)**. The Continue check verifies a fully visible action and question without a helper scroll. The location and largest-text checks also verify the action frame. iPad tests use the first list item and explicitly restore search focus after clearing the field. Screenshots were reviewed for the library, pack, feedback, pin entry, large text, and empty search.

Evidence: `build/iteration-review/iPhone.xcresult` contains the full run; `iPhoneVerified.xcresult` and `iPadVerified.xcresult` contain the final three checks on each device. `FeedbackVerified.xcresult` confirms the last feedback copy change and contains its screenshot. That check passed after reinstalling the test runner because Simulator had reused an older test binary. Logs and screenshots are in the same directory. Temporary screenshot attachment calls were removed after capture; assertions remain in the UI suite. This is local Simulator verification; this iteration does not establish physical-device behavior.

The app icon was recolored with an image generation tool and saved at `ios/Atlas/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. The generated image was resized to the required opaque 1024 × 1024 PNG. The prior icon is retained locally at `build/iteration-review/AppIcon.before.png`.

## Blue palette revision — 2026-10-03

The app now uses cobalt blue for primary controls, navy text, cool backgrounds, and pale blue map surfaces. Map highlights, pins, progress, results, and answer text use the same palette. Incorrect answers retain a distinct brown color. The geometry and practice behavior are unchanged.

The Atlas Debug build passed. The library, map detail, and practice accessibility audits passed on iPhone 17 Pro and iPad mini (A17 Pro), iOS 26.5. The iPhone polygon, callout, zoom, and pan UI test also passed. Screenshots of the library, map detail, practice, and answer feedback were reviewed. Primary button text has a calculated contrast ratio of 7.22:1; secondary text on the pale blue map surface has a ratio of 5.09:1. Logs, result bundles, and screenshots are under `build/blue-review/`.

This revision used focused checks for the palette change. The full-suite results below cover the earlier design pass.

## Initial UI design update — 2026-10-03

The first design pass introduced a field-guide style with warm paper, dark green, serif headings, and previews drawn from the bundled map geometry. The map detail screen has a primary practice action and a direct study link. Answer choices, session progress, feedback, results, and fact details use the same visual style. Press feedback respects Reduce Motion; large text uses stacked layouts where needed.

- The Atlas Debug build passed with Xcode 27.0 (27A266a), the existing iOS 18 deployment target, and the iOS 26.5 Simulator runtime.
- All **23 unit tests and 16 UI tests** have passing results across the full run and focused reruns. Coverage includes all quiz modes, map pan/zoom and hit testing, timers, session completion, landscape, and the largest accessibility text size.
- The accessibility audit now covers the library, map detail, and practice screens. Hit regions, descriptions, and contrast pass on iPhone 17 Pro and iPad mini (A17 Pro). The checks found and guided fixes for the progress indicator, zoom controls, and decorative globe label.
- Simulator screenshots were reviewed for the library, map detail, practice, answer feedback, study facts, results, and large text. Preview maps omit quiz callout space so small thumbnails remain readable.

Local logs, result bundles, and screenshots are under `build/design-review/`. The full run initially failed the accessibility check; the corrected flow passes in `Navigation.xcresult` and `iPad.xcresult`. The focused geometry and session results are in `Final.xcresult`, map controls in `Accessibility.xcresult`, and the final large-text layout in `Review.xcresult`. Temporary screenshot capture code was removed; the expanded accessibility assertions remain in the UI suite.

This update was verified in Simulator. Physical-device haptics and interaction were not tested. Existing XCTest actor-isolation warnings and the App Intents metadata warning remain; no new app compiler warning was introduced.

## Device installation — 2026-09-14

A signed Release build from commit `47de3a3` was installed successfully on the connected iPhone Air after the map review. The build used Xcode 26.6, the configured paid developer team, whole-module optimization, and disabled coverage instrumentation. Before installation, all 20 bundled map files and the learning JSON matched the repository byte for byte; strict code-signature verification passed.

`devicectl device install app` reported success, and a subsequent installed-app query returned Atlas Practice. Launch was denied because the phone was locked. Installation is confirmed; this is not evidence of a completed physical-phone interaction test. The installed build includes the lake and NYC shoreline corrections. No TestFlight or App Store release was performed.

This record was consolidated on 2026-09-17 from the build and device-tool results. Temporary logs from that installation are not retained. Repeatable commands are in [DEVICE_INSTALL.md](DEVICE_INSTALL.md). The existing signing-team setting is now retained in both the generated Xcode project and its XcodeGen source.

The dated sections below retain the validation scope at each earlier stage.

## All-map source and shoreline review — 2026-09-14

Reviewed all 12 catalog entries. Four packs are playable; the other eight remain reference data. The complete inventory and source limits are in [MAP_REVIEW.md](../data/MAP_REVIEW.md).

State geometry now excludes mapped lakes from Natural Earth's 10m physical layer. World/continent geometry uses the 50m layer. The focused NYC pack is clipped to each area's own official borough shoreline. All map/question IDs and the 47-area NYC grouping remain stable. Source credits describe the derived geometry.

- All 623 unique area features pass validation. All 309 state/country features match the original administrative source minus the matching lake mask. All 267 official borough/NTA features match their source geometry exactly. All 47 focused NYC areas preserve source membership and inland divisions after shore clipping.
- Nine geographic source checksums pass. Offline recompilation reproduces all 22 generated map/source/repair files byte for byte. The learning validator passes for 66 states and flags, 60 cities, 70 landmarks, and 196 positions.
- The Atlas Debug scheme built and passed **23 unit tests** on iPhone 17 Pro Simulator, iOS 26.5. New regressions verify water hit testing for US and German lakes, DUMBO, and Newtown Creek, plus a selectable interior for every one of the 118 playable areas at two viewport sizes with zoom/pan. Existing Great Lakes, Illinois, antimeridian, inset, distance, and native layer checks also pass.
- **Six selected UI tests passed**: polygon taps/callouts/gestures, native pan alignment, Germany study selection, NYC neighborhood selection, NYC groups/name mode, and landmark pin/distance. Unchanged timer and full-session UI tests were not rerun in this review; their earlier evidence remains below.
- A separate iPhone 17 Simulator run confirmed the US overview and insets, Germany state selection, and the reduced NYC map with DUMBO selection and zoom.

Result bundles were local and are not retained.

This update was verified in Simulator and subsequently installed on the physical iPhone, as recorded above. The locked-phone launch limit means physical interaction with the new geometry is not verified. The world and continent layouts remain unexposed pending camera, antimeridian, and curriculum work.

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

Result bundles were local and are not retained.

A separate iPhone 17 Simulator inspection confirmed visible lake shorelines, Illinois selection, state labels, flag details, and enlarged native map shapes. Automated pan input also confirmed that the moved Washington polygon and answer hit testing stay aligned.

### Phone installation

A signed **Release** build was installed successfully on the connected iPhone Air using the existing paid developer team. The compiler used `-O` and whole-module optimization. `ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO` removed test instrumentation; these settings must be included when repeating this development build because the scheme enables test coverage. Build output: `build/DeviceRelease/Build/Products/Release-iphoneos/Atlas.app`.

Automatic launch was blocked by the iPhone lock screen. Installation is verified; physical-phone interaction performance is not yet measured. No remote push, TestFlight upload, or App Store release was performed.

## NYC map reduction — 2026-09-14

The active NYC neighborhood map now has **47 areas: all 37 original Manhattan areas plus ten areas outside Manhattan**. The five named Brooklyn/Queens neighborhoods retain their polygons. The other Brooklyn and Queens areas use explicit source unions. The Bronx and Staten Island each use one official borough boundary. The new map ID keeps scores separate from the earlier 266-area map.

- Generic iOS Simulator Debug build passed with Xcode 26.6 (17F113), Swift 6, and deployment target iOS 18.0.
- Both Python validators passed: twelve packs and 623 valid area features, plus the unchanged state, flag, city, and sight database. Checks confirm exact Manhattan boundaries, separate named neighborhoods, unique group membership, complete Brooklyn/Queens source-member coverage, and exact official Bronx/Staten Island polygons. All 22 generated map/source/repair files reproduce byte-for-byte offline. The original candidate, repair report, and source locks are unchanged.
- **18 unit tests and three selected UI tests passed** on iPhone 17 Pro, iOS 26.5. Map-hit and coordinate round-trip checks now include both borough-sized answers, all three merged practice groups, DUMBO, and Long Island City at two viewport sizes and with zoom/pan.
- UI checks passed for Chinatown search; Bed-Stuy, Long Island City, and Staten Island selection; the 47-area description; a correct answer in Name the area; and a complete five-borough quiz. Other UI tests were not repeated for this data change; their earlier results are below.
- A separate iPhone 17 Simulator launch showed the 47-area home entry, reduced boundaries, study labels, and West Brooklyn selection. A direct tap inside Staten Island selected the whole island and displayed the expected answer feedback.

Result bundles were local and are not retained.

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

Result bundles were local and are not retained. Run `scripts/ios.sh test SIMULATOR_UDID` to repeat the complete scheme.

### Runtime inspection

The repository build was installed and launched separately on iPhone 17 Simulator. Native UI readback and screenshots confirmed the expanded mode selector, authentic Colorado and California flags, a correct flag answer, and a Florida landmark answer pin. Manual pause disabled answer controls; resume restored the countdown. Advancing reset it to 30 seconds. After leaving the app on the Simulator Home screen for over a minute, it returned with 22 seconds left rather than expiring. A separate landmark question displayed timeout feedback and inserted one review.

The current Minnesota and Utah flag assets were visually checked. No generated substitute flag artwork is used.

### Limits

- Physical-device behavior and signing remain unverified. No TestFlight, App Store, or public release was performed.
- Runtime verification used iOS 26.5. Older supported OS versions and iPad need device-specific review.
- Native controls have accessibility labels, and answers post announcements. A complete spoken VoiceOver session has not been verified. The custom map has area-list and coordinate-entry alternatives; those do not reproduce visual spatial learning.
- NYC boundaries are approximate and include parks and islands. Individual topology checks do not prove complete gap/overlap coverage. The datHere catalog declares ODC-By, but the licensed resource download could not be compared with the pinned mirror.
- City populations are dated city/municipal figures, not live counts or metropolitan populations. Landmarks are a curated set, not a popularity ranking. Large parks use an identified reference point.
