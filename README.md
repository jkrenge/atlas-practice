# Atlas Practice for iOS

A native SwiftUI geography learning app. Practice **Find the area** and **Name the area** with all 50 US states, 16 German states, and five official NYC boroughs. Explore a labeled study map, get feedback, and revisit missed answers in short untimed sessions. Progress is stored on the device, separately for each map and mode.

The app uses geographic polygons for display and selection, supports pinch zoom and pan, and includes linked markers for small states. Alaska and Hawaii have reversible inset transforms. Other prepared datasets remain outside the app selector until their curricula are reviewed.

## Build and run

Open `ios/Atlas.xcodeproj`, select the **Atlas** scheme and an iOS Simulator, then run. The deployment target is iOS 18.0. Development was verified with Xcode 26.6, Swift 6 language mode, and the iOS 26.5 Simulator runtime. No third-party app packages or server are required.

The generated project is committed, so XcodeGen is only needed when changing `ios/project.yml` or adding source files. To regenerate it, use XcodeGen 2.46 or compatible and `scripts/ios.sh generate`.

```sh
scripts/ios.sh build
xcrun simctl list devices available
# Replace SIMULATOR_UDID with an available device identifier.
scripts/ios.sh test SIMULATOR_UDID
scripts/ios.sh run SIMULATOR_UDID
```

Build products and test results stay under ignored `build/`. To run on a physical iPhone, select a signing team in Xcode and a connected device. Physical-device testing and signing are not yet verified.

See [implementation status](PROJECT_PLAN.md), [verification evidence](ios/VERIFICATION.md), and the retained [implementation brief](IMPLEMENTATION_HANDOFF.md).

## Prepared data

All playable geometry uses GeoJSON with WGS 84 longitude and latitude coordinates. Map manifests use schema version 2.

| Map | Geometry features | Question areas |
| --- | ---: | ---: |
| United States | 51 | 50 states; DC is background |
| Germany | 16 | 16 federal states |
| NYC boroughs | 5 | 5 boroughs |
| NYC statistical neighborhoods | 262 | 197 residential 2020 NTAs |
| World | 242 | 204 provisionally eligible source records |
| Africa | Shared world geometry | 53 |
| Asia | Shared world geometry | 48 |
| Europe | Shared world geometry | 48 |
| North America | Shared world geometry | 26 |
| South America | Shared world geometry | 12 |
| Oceania | Shared world geometry | 14 |

The country lists follow Natural Earth's classifications. The count of 204 is not a claim about the number of sovereign countries. The six continent lists contain 201 questions in total: the source places Seychelles, Mauritius, and Maldives in `Seven seas (open ocean)`, so they appear only in the World list. Continent membership and disputed areas need curriculum review. There is no Antarctica country quiz.

NYC NTAs are statistical areas that approximate neighborhoods. They do not provide the requested finer neighborhood level for every name, such as Chinatown, Nolita, Tribeca, and Financial District (FiDi). The official five-borough pack is ready. Finer Pediacities geometry is retained in `data/candidates/nyc-neighborhoods.geojson`, with separate polygons for all four requested names. It stays outside the active catalog because its exact license is unverified and two other features have invalid topology. See [candidate notes](data/candidates/README.md).

`data/us-cities.geojson` contains 769 US city and town points for a later city mode, including Los Angeles. These are cartographic points, with source population estimates and scale ranks. They are not a current list of the largest cities. The geometry coordinates are canonical; separate coordinate attributes in the original source can differ.

## Files

- `maps/catalog.json`: Index of the eleven prepared map packs.
- `maps/*/map.json`: Question IDs, names, and relative geometry references.
- `maps/*/areas.geojson`: Polygon and MultiPolygon geometry, including background areas.
- `data/us-cities.geojson`: City Point features for future distance questions.
- `data/sources/`: Original source snapshots, committed for reproducible builds.
- `data/source-checksums.json`: SHA-256 lock for the six snapshots.
- `data/SOURCES.md`: Source URLs, versions, terms, and selection rules.
- `assets/us-states.svg` and `maps/us-states/map.svg`: Original and adapted visual references.
- [MAP_FORMAT.md](MAP_FORMAT.md): Data contract and required coordinate handling.
- [PROJECT_PLAN.md](PROJECT_PLAN.md): Implementation steps and acceptance checks.

The SVG is decorative reference material. It has no verified registration to geographic coordinates. Use the GeoJSON for rendering and tap detection. Do not use SVG pixels to locate cities or measure distance.

## Rebuild and validate

Use Python 3.10 or later. The initial build was verified with Python 3.14.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-data.txt
.venv/bin/python scripts/compile_maps.py
.venv/bin/python scripts/validate_data.py
git diff --exit-code -- maps data/us-cities.geojson data/candidates/nyc-neighborhoods.geojson data/source-checksums.json
```

Compilation reads the committed snapshots and checks their hashes before writing output. It does not download data or replace the checksum lock. The validation checks references, expected area sets, geometry structure and topology, coordinate bounds, and representative city points. The final command checks that compilation reproduced the committed output exactly.

Source snapshots total about 27 MB. Keeping them in Git makes the initial data build independent of upstream updates, API row order, and download availability. The virtual environment is excluded.

## App structure

- `ios/Atlas/MapData.swift`: schema-version-2 manifests and Polygon/MultiPolygon decoding, including shared geometry paths.
- `ios/Atlas/MapGeometry.swift`: projection, inset fitting, viewport transforms, and polygon hit testing.
- `ios/Atlas/MapView.swift`: native map drawing and touch gestures, with SwiftUI zoom controls.
- `ios/Atlas/PracticeSession.swift`: question queue, spaced review, scoring, and local progress.
- `ios/Atlas/AtlasApp.swift`: map selector, practice screens, study, results, and credits.
- `ios/AtlasTests` and `ios/AtlasUITests`: geometry/session checks and Simulator interaction tests.

The lower 48 use Albers equal-area with standard parallels 29.5°/45.5°, central longitude −96°, and origin latitude 37.5°. Alaska and Hawaii use separate equirectangular view regions centered at −154°/64° and −157°/20°. Longitude wrapping around Alaska preserves the Aleutian Islands across ±180°. Germany and NYC use an equirectangular projection centered on their geometry. Each region has an explicit inverse; uniform fitting preserves aspect ratio. These first three map layouts are tested. The world and continent views need separate camera and antimeridian review before exposure.

Callout boxes are fixed 44-point touch targets. Their leader lines follow the projected shape as the map moves. Before feedback, the markers display neutral numbers. Water, holes, and DC do not submit state answers. A tap within 3 screen points of another eligible area is treated as ambiguous and asks the player to zoom in.

Each session samples up to six unique places. A first miss or Show answer inserts one review after two other queued questions when possible. A review is attempted once, so a session always ends. First-attempt results and review results remain separate. The area list supports non-spatial selection in Find mode; it does not provide equivalent spatial learning for a person who cannot see the map.

Source terms remain separate from project code; see [source notes](data/SOURCES.md).
