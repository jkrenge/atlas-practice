# iOS implementation plan

The repository prepares data for implementation. No Xcode project or app target exists yet. Use the following steps to build and verify the first version.

## 1. Create the app shell and data loader

Create a SwiftUI iOS app and choose its minimum supported iOS version. Bundle the catalog, manifests, and required GeoJSON. Decode map and feature IDs without assuming a fixed number of areas. Keep the area question session independent of country or area type.

Verify: load all eleven prepared manifests, resolve shared assets, and reject a question ID that has no geometry. Use the same session logic for US states, German federal states, and NYC areas.

## 2. Build the geographic renderer

Render Polygon and MultiPolygon features with holes. Choose and document a projection with an inverse. Add antimeridian handling and explicit Alaska and Hawaii insets. Initially show the full map with all 50 US states available.

Verify: Colorado, Alaska, Hawaii, islands, holes, and DC draw correctly. Coordinate-to-screen-to-coordinate round trips stay within a defined numeric tolerance for every view region. US islands near the antimeridian do not create lines across the map. Inset gaps cannot select an unrelated place.

## 3. Add map interaction

Add pinch zoom and pan to every map. Use the same transforms for drawing and selection. Use actual polygon containment for area taps. Add callout boxes for small states, including Delaware and Rhode Island, with leader lines to their shapes. Both the box and the shape select the same feature ID. Keep the callouts usable as zoom and pan change.

Verify: a visible shape remains selectable after zoom, pan, rotation of the device, and inset scaling. Callouts do not select adjacent states. Background, water, polygon holes, and DC cannot become state answers. Check small targets, islands, and accessibility on a simulator and a physical iPhone.

## 4. Complete the first learning loop

Show a prompt such as `Tap Colorado`. Compare the selected ID with the requested ID, show clear feedback, and continue to the next question. Use the manifest's explicit question list. Choose retry, question order, and score rules before implementing them.

Verify: correct, incorrect, and background taps behave as specified. All 50 states can appear. Switching to Germany or an NYC map changes data, not the session logic. Screen-reader controls identify selectable areas and announce feedback.

## 5. Prepare the NYC learning levels

Start with the five boroughs, then offer finer named neighborhoods. The requested names include Chinatown, Nolita, Tribeca, and Financial District (FiDi). Keep aliases separate from stable IDs.

The current NTA pack is a statistical reference level. It must not be presented as a complete fine-neighborhood curriculum. The official five-borough pack is prepared. A 266-area Pediacities candidate includes the four requested finer neighborhoods, but its exact license and two invalid geometries need resolution before it becomes an active pack. Do not create borough boundaries by dissolving NTAs: some NTAs cross borough boundaries.

Verify: the borough pack has five correct polygons and five answers. Each requested finer neighborhood has its own named polygon and reviewed source terms. Record gaps, overlapping boundaries, and naming rules before importing that dataset. Reuse the same map contract and area session.

## 6. Review continent question lists

Review disputed areas, dependencies, transcontinental countries, names, and islands. The current lists follow source fields and are provisional. Decide how to assign Seychelles, Mauritius, and Maldives, which the source classifies outside the six continents. Review overseas geometry and camera framing separately from question membership.

Verify: each intended country appears in the intended learning level, and the documented policy explains exclusions and duplicate membership. Keep Antarctica out of the country quiz.

## 7. Add city-distance mode later

Select and review a city curriculum from the 769 prepared points. If a current largest-cities list is wanted, obtain an appropriate dated population source. Show a city name, invert a map tap to longitude and latitude, then measure geographic distance to the city's Point. Decide the score curve after distance is verified.

Verify: exact-location guesses return zero within tolerance. Known coordinate pairs return the expected distance. Results remain the same after zoom, pan, inset movement, and device rotation. A small-state callout cannot submit a city guess. Check Los Angeles, New York, Anchorage, and Honolulu against the map display.

## Completion criteria for the first app version

The full US map supports all 50 state questions, correct polygon selection, zoom and pan, small-state callouts, and a complete question/feedback loop. Shared data loading also works for Germany and NYC. Projection round trips and area selection pass automated checks; the learning flow passes simulator and physical-device checks. City-distance mode and the later curricula are separate follow-up work.
