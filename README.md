# Atlas Practice for iOS

A native SwiftUI geography learning app with 50 US states, 16 German states, five NYC boroughs, and 47 NYC practice areas. Learn state capitals, flags, nicknames and campaign slogans; locate capitals, the 50 largest US cities and 10 largest German cities; estimate city populations; and place 50 US and 20 German landmarks on the map.

Choose untimed practice or a 30/60-second countdown per question. Pause and resume, review missed answers once, and keep separate local scores by map, mode, and timer setting. Location questions use movable pins and geographic distance: within 50 km for US maps or 20 km for Germany counts as correct. Browse every fact and its source before playing.

The app runs offline. State flags are bundled PNGs from Wikimedia Commons with file-specific credits. NYC neighborhood boundaries are approximate and include parks and islands; source equivalence remains a documented limit in [source notes](data/SOURCES.md).

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

Build products and test results stay under ignored `build/`. To run on a physical iPhone, select a signing team in Xcode and a connected device. The signed Release build of commit `47de3a3`, including the map corrections, was installed on an iPhone Air on 2026-09-14. Installation was verified; automatic launch was blocked by the phone lock screen. See [device installation](ios/DEVICE_INSTALL.md) for repeatable commands and [verification](ios/VERIFICATION.md) for the tested scope.

See [implementation status](PROJECT_PLAN.md), [verification evidence](ios/VERIFICATION.md), and the retained [implementation brief](IMPLEMENTATION_HANDOFF.md).

## Prepared data

All playable geometry uses GeoJSON with WGS 84 longitude and latitude coordinates. Map manifests use schema version 2.

| Map | Geometry features | Question areas |
| --- | ---: | ---: |
| United States | 51 | 50 states; DC is background |
| Germany | 16 | 16 federal states |
| NYC boroughs | 5 | 5 boroughs |
| NYC neighborhoods | 47 | 37 Manhattan areas plus 10 outside Manhattan |
| NYC statistical neighborhoods | 262 | 197 residential 2020 NTAs |
| World | 242 | 204 provisionally eligible source records |
| Africa | Shared world geometry | 53 |
| Asia | Shared world geometry | 48 |
| Europe | Shared world geometry | 48 |
| North America | Shared world geometry | 26 |
| South America | Shared world geometry | 12 |
| Oceania | Shared world geometry | 14 |

State and country geometry excludes mapped lakes from Natural Earth physical layers at the same scale as its boundaries: 1:10 million for states and 1:50 million for countries. These are generalized learning maps, not survey-grade maps.

The country lists follow Natural Earth's classifications. The count of 204 is not a claim about the number of sovereign countries. The six continent lists contain 201 questions in total: the source places Seychelles, Mauritius, and Maldives in `Seven seas (open ocean)`, so they appear only in the World list. Continent membership and disputed areas need curriculum review. There is no Antarctica country quiz.

The app selector includes the US, Germany, NYC boroughs, and the focused NYC neighborhood pack. The separate official NTA dataset remains a statistical reference. Chinatown, Nolita, Tribeca, and Financial District have separate geometry in the neighborhood game. Manhattan keeps all 37 source areas. Bed-Stuy, DUMBO, Williamsburg, Greenpoint, and Long Island City stay separate. West Brooklyn, South & East Brooklyn, and Queens (other areas) combine the remaining Brooklyn and Queens neighborhoods. The Bronx and Staten Island each use one official borough polygon. These broad groups are practice areas. The unmodified mirror remains in `data/candidates`; repairs occur before grouping. Each practice area is then clipped to its own official borough shoreline. This preserves membership and inland divisions but does not fill source gaps. See [group membership](data/nyc-learning-groups.json). The focused map has a new ID, so earlier scores from the 266-area map stay separate.

`content/learning.json` contains 66 state facts, 60 ranked cities, and 70 curated sights. US city populations use Census Vintage 2025, July 1, 2025; German cities use Destatis, December 31, 2024. These are city/municipal populations, not metro areas. US consolidated-government balances and Washington, DC follow the Census ranking. Landmarks form a curated learning list, not a measured popularity ranking. Each point has a source link, and park reference points are labeled.

The older `data/us-cities.geojson` remains a cartographic reference with 769 Natural Earth city/town points. Its population fields do not feed the new city games.

## Files

- `maps/catalog.json`: Index of the twelve prepared map packs.
- `maps/*/map.json`: Question IDs, names, and relative geometry references.
- `maps/*/areas.geojson`: Full source-derived geometry retained for validation.
- `maps/*/areas-lowres.geojson`: Simplified geometry used by the app for rendering and selection.
- `data/us-cities.geojson`: Retained Natural Earth city Point features.
- `data/sources/`: Original source snapshots, committed for reproducible builds.
- `data/source-checksums.json`: SHA-256 lock for the nine geographic snapshots.
- `content/learning.json` and `content/flags/`: offline game facts and authentic flag images.
- `data/learning/`: reviewed identities, selections, slogan sources, and flag metadata.
- `data/learning-checksums.json`: locks the new source snapshots, curation, and flag assets.
- `data/SOURCES.md`: Source URLs, versions, terms, and selection rules.
- [data/MAP_REVIEW.md](data/MAP_REVIEW.md): Review of all 12 packs, shoreline corrections, and limits.
- `assets/us-states.svg` and `maps/us-states/map.svg`: Original and adapted visual references.
- [MAP_FORMAT.md](MAP_FORMAT.md): Data contract and required coordinate handling.
- [PROJECT_PLAN.md](PROJECT_PLAN.md): Implementation steps and acceptance checks.

The SVG is decorative reference material. It has no verified registration to geographic coordinates. Use the GeoJSON for rendering and tap detection. Do not use SVG pixels to locate cities or measure distance.

## Rebuild and validate

Use Python 3.10 or later. The initial build was verified with Python 3.14.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-data.txt
npm ci --prefix scripts/geometry
.venv/bin/python scripts/compile_maps.py
.venv/bin/python scripts/validate_data.py
.venv/bin/python scripts/compile_learning.py
.venv/bin/python scripts/validate_learning.py
git diff --exit-code -- maps content data/us-cities.geojson data/candidates/nyc-neighborhoods.geojson data/nyc-neighborhood-repairs.json
```

Compilation reads the committed snapshots and checks their hashes before writing output. It does not download data or replace the checksum lock. The validation checks references, expected area sets, geometry structure and topology, coordinate bounds, and representative city points. The final command checks that compilation reproduced the committed output exactly.

Map compilation also runs `scripts/simplify_maps.py`. It uses shared-edge Douglas–Peucker simplification, with tighter limits for small rings and known water points. Each feature's changed area is limited to 1%. Original geometry remains available for source checks; iOS bundles only the simplified assets. `data/geometry-simplification.json` records point counts and file sizes. Both rendering and answer selection use the same reduced geometry.

Keeping source snapshots in Git makes the initial data build independent of upstream updates, API row order, and download availability. The virtual environment is excluded.

## App structure

- `ios/Atlas/MapData.swift`: schema-version-2 manifests and Polygon/MultiPolygon decoding, including shared geometry paths.
- `ios/Atlas/MapGeometry.swift`: projection, inset fitting, viewport transforms, and polygon hit testing.
- `ios/Atlas/MapView.swift`: native map drawing and touch gestures, with SwiftUI zoom controls.
- `ios/Atlas/PracticeSession.swift`: question queue, spaced review, scoring, and local progress.
- `ios/Atlas/AtlasApp.swift`: map selector, practice screens, study, results, and credits.
- `ios/AtlasTests` and `ios/AtlasUITests`: geometry/session checks and Simulator interaction tests.

The lower 48 use Albers equal-area with standard parallels 29.5°/45.5°, central longitude −96°, and origin latitude 37.5°. Alaska and Hawaii use separate equirectangular view regions centered at −154°/64° and −157°/20°. Longitude wrapping around Alaska preserves the Aleutian Islands across ±180°. Germany and NYC use an equirectangular projection centered on their geometry. Each region has an explicit inverse; uniform fitting preserves aspect ratio. The four exposed map layouts are tested. The world and continent views need separate camera and antimeridian review before exposure.

Callout boxes are fixed 44-point touch targets. Their leader lines follow the projected shape as the map moves. Before feedback, the markers display neutral numbers. Water, holes, and DC do not submit state answers. A tap within 3 screen points of another eligible area is treated as ambiguous and asks the player to zoom in.

Point questions accept water and coastlines inside a geographic map region. Gaps between US insets cannot submit a point. Distance uses the haversine formula on canonical longitude/latitude, not screen pixels. Map zoom supports up to 32×.

Each session samples up to six unique places. A first miss or Show answer inserts one review after two other queued questions when possible. A review is attempted once, so a session always ends. First-attempt results and review results remain separate. The area list supports non-spatial selection in Find mode; it does not provide equivalent spatial learning for a person who cannot see the map.

Countdowns pause while the app is inactive and during answer feedback. A timeout records one miss and one review. The coordinate-entry sheet provides an accessible alternative to pin placement.

Source terms remain separate from project code; see [source notes](data/SOURCES.md).
