# Geography learning for iOS

Project preparation for a personal geography learning app. The first mode shows a prompt such as **Tap Colorado**, displays the full US map, and lets the player select a state.

This repository contains map geometry, source snapshots, a shared data format, and an implementation plan. The iOS app, renderer, tap detection, projection transforms, and distance scoring are not implemented. No simulator or device tests have run.

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

## First implementation

Build one SwiftUI area-selection flow for all maps. Keep data loading, map display and tap detection, and question state separate. Pinch zoom, pan, and linked callout boxes for small states are required. Alaska and Hawaii need explicit inset transforms with an inverse. The later city mode must convert the tap back to longitude and latitude before computing geographic distance.

See the [project plan](PROJECT_PLAN.md) for the sequence and checks. Data source terms remain separate from the project code; see [source notes](data/SOURCES.md).
