# Geographic data sources

The original geographic snapshots were downloaded on **2026-09-13**. The lake-clipped US snapshot, new facts, and assets were retrieved on **2026-09-14**. Original bytes are retained under `data/sources/`; SHA-256 hashes are in `data/source-checksums.json`. Compilation verifies those hashes before writing output. Source data is not covered by an assumed project-wide license.

## Natural Earth

Natural Earth makes its map data public domain. See the [official terms](https://www.naturalearthdata.com/about/terms-of-use/). Credit: Made with Natural Earth. The archive `VERSION.txt` files confirm the versions below, and their `.prj` files declare WGS 84 geographic coordinates. `pyshp` reads the geometry without reprojection, simplification, or vertex rounding.

| Source ID | Snapshot and direct download | Version | Output and selection |
| --- | --- | --- | --- |
| `natural-earth-admin1` | [ne_10m_admin_1_states_provinces.zip](https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_1_states_provinces.zip) | 5.1.1, 1:10 million | Keep `adm0_a3` DEU geometry for 16 German states. Retain USA names, IDs, and order; US geometry now comes from the lake-clipped variant below. |
| `natural-earth-admin1-lakes` | [ne_10m_admin_1_states_provinces_lakes.zip](https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_1_states_provinces_lakes.zip) | 5.1.1, 1:10 million | Keep `adm0_a3` USA. 51 lake-clipped state features, with US-DC excluded from questions. The official variant excludes large lakes, preserving the Illinois shore of Lake Michigan and both Michigan peninsulas. |
| `natural-earth-countries` | [ne_50m_admin_0_countries.zip](https://naturalearth.s3.amazonaws.com/50m_cultural/ne_50m_admin_0_countries.zip) | 5.1.1, 1:50 million | Keep all 242 features. Only `TYPE` values `Sovereign country` and `Country` are provisionally eligible: 204 records. |
| `natural-earth-places` | [ne_10m_populated_places.zip](https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_populated_places.zip) | 5.1.2, 1:10 million | Keep `ADM0_A3` USA: 769 city and town Points. Preserve `POP_MAX` and `SCALERANK` as source metadata. |

Official documentation: [states and provinces](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/), [countries](https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/), and [populated places](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/).

German display names come from `name`; `name_en` remains available as `nameEnglish`. Country names use `NAME_EN` with `NAME` as fallback. Country and city IDs use `NE_ID` with the `NE-` prefix.

Country questions and continent assignments are source classifications, not a final curriculum or a sovereign-country count. Natural Earth generally uses de facto boundaries. The six continent manifests filter `CONTINENT` and share the full world geometry, including overseas parts. Transcontinental countries can be assigned to one continent. Seychelles, Mauritius, and Maldives use the source label `Seven seas (open ocean)` and appear only in World. Antarctica is background. Review this policy before shipping a country curriculum.

Populated places are selected for cartographic and regional significance. Population values are estimates and are not a current city-proper ranking. Use Point geometry as the canonical city position. Los Angeles is approximately `[-118.231986, 34.049219]`; source `LATITUDE` and `LONGITUDE` attribute values differ and are not imported.

## NYC Department of City Planning

The [NYC Open Data terms](https://opendata.cityofnewyork.us/overview/#termsofuse) refer to [NYC.gov terms](https://www.nyc.gov/main/terms-of-use), its privacy policy, and applicable agency terms. The metadata has no separate license ID. Record this as NYC Open Data terms, not CC0 or a verified Creative Commons license. Credit: NYC Department of City Planning (DCP). The City provides the data without accuracy or fitness warranties.

### `nyc-nta2020`

- [Dataset 9nt8-h7nd](https://data.cityofnewyork.us/City-Government/2020-Neighborhood-Tabulation-Areas-NTAs-/9nt8-h7nd).
- [GeoJSON download](https://data.cityofnewyork.us/resource/9nt8-h7nd.geojson?$limit=5000), saved as `nyc-nta.geojson`.
- Live [metadata](https://data.cityofnewyork.us/api/views/9nt8-h7nd.json) reports version **26b**, rows updated **2026-05-28**. Relevant fields are retained in `nyc-source-metadata.json`.
- Preserve all 262 features. Use `NYC-` plus `nta2020` as ID, and `ntaname` as name. The provisional question list uses the 197 residential `ntatype == "0"` records. Non-residential types remain background; the snapshot contains types 5, 6, 7, 8, and 9 for special areas, parks, cemeteries, and airports.

NTAs are statistical areas, not definitive neighborhood boundaries. Some cross borough boundaries; do not dissolve them to make borough polygons. The [DCP metadata PDF](https://s-media.nyc.gov/agencies/dcp/assets/files/pdf/data-tools/bytes/nynta2020_metadata.pdf) is a moving URL and currently reports a newer release, so it does not establish this snapshot's version.

### `nyc-boroughs`

- [Dataset gthc-hcne](https://data.cityofnewyork.us/City-Government/Borough-Boundaries/gthc-hcne/data).
- [GeoJSON download](https://data.cityofnewyork.us/resource/gthc-hcne.geojson?$limit=5000), saved as `nyc-boroughs.geojson`.
- Live [metadata](https://data.cityofnewyork.us/api/views/gthc-hcne.json) reports version **26b**; relevant fields are retained in `nyc-borough-source-metadata.json`.
- Five shoreline borough MultiPolygons, with water areas excluded. Keep all five as questions. Use `NYC-BORO-` plus `borocode` as ID, and `boroname` as name. No NTA dissolve is used.

Both NYC geometry sources use longitude and latitude. Preserve their coordinates and polygon parts without reprojection.

## Pediacities / Ontodia neighborhoods

The prototype uses this source in the `nyc-neighborhoods-focused` pack. The unmodified normalized mirror remains under `data/candidates`. Two self-intersections are repaired during compilation with Shapely 2.1.2 `make_valid`, before the learning groups are formed. The repair report records affected IDs and before/after areas.

- [Pinned ix4 mirror download](https://gist.githubusercontent.com/ix4/ff7603f48283cf06fc4fb3dfb6a0635c/raw/5cdd9db840eb9235d116c5f632599dca1b925d11/nyc.geojson), saved as `nyc-pediacities-neighborhoods.geojson`.
- [Mirror page](https://gist.github.com/ix4/ff7603f48283cf06fc4fb3dfb6a0635c), revision `5cdd9db840eb9235d116c5f632599dca1b925d11`. The boundary vintage is unknown; mirror activity is not a boundary update date.
- The [datHere catalog API](https://data.dathere.com/api/3/action/package_show?id=nyc-neighborhoods), saved as `nyc-catalog.json`, credits Ontodia and declares **Open Data Commons Attribution License (ODC-By)**. The catalog resource download and datastore endpoint returned HTTP 403, so its exact equivalence to the pinned mirror was not confirmed. This is a prototype source limitation, not a claim that matching licensed bytes were verified. Attribution and this limit are also visible in the app.

The raw snapshot has 310 records. Compilation skips seven null geometries and groups polygon parts by the existing `properties.@id`, yielding 266 named areas. IDs are the original source URIs. The original normalized copy changes no vertices. The compiler uses `make_valid` on Country Club and Marine Park only. Country Club is then replaced by the official Bronx boundary; Marine Park is merged into South & East Brooklyn. Boundaries are approximate and historical; named parks and islands are included. Credit: Neighborhood boundaries from Pediacities / Ontodia; normalized from the ix4 GeoJSON mirror.

## `nyc-learning-areas`: focused NYC practice map

`nyc-neighborhoods-focused` has 47 questions. All 37 Manhattan areas retain their source IDs, names, and geometry. Outside Manhattan, [nyc-learning-groups.json](nyc-learning-groups.json) defines ten areas and their source members:

- **Bed-Stuy, DUMBO, Williamsburg, Greenpoint:** retained Brooklyn polygons. Bedford-Stuyvesant uses the shorter display name Bed-Stuy; its source ID stays unchanged.
- **West Brooklyn:** Brooklyn Heights, Downtown Brooklyn, Boerum Hill, Cobble Hill, Carroll Gardens, Red Hook, Columbia St, Vinegar Hill, Fort Greene, Clinton Hill, Navy Yard, Prospect Heights, Park Slope, Gowanus, South Slope, Sunset Park, Bay Ridge, and Fort Hamilton.
- **South & East Brooklyn:** the remaining 32 Brooklyn source areas.
- **Long Island City:** retained Queens polygon.
- **Queens (other areas):** the remaining 61 Queens source areas.
- **The Bronx and Staten Island:** one official NYC DCP borough boundary each, from `nyc-boroughs`. No neighborhood or NTA dissolve is used for either borough.

West Brooklyn, South & East Brooklyn, and Queens (other areas) are learning groups, not official neighborhoods. Shapely `unary_union` merges their repaired source polygons without inventing a new dividing line. Each Brooklyn and Queens source area belongs to exactly one group. Source gaps and overlaps can remain; validation establishes member coverage, not a complete city partition. The combined pack credits both Pediacities/Ontodia and NYC DCP. Each non-Manhattan feature records `sourceId` and `sourceAreaIDs`.

The focused pack replaces the 266-area pack in the catalog and selector. Its new map ID keeps earlier practice scores separate. The original candidate and source snapshots stay available for reproducibility.

## Decorative US SVG

See [assets/SOURCE.md](../assets/SOURCE.md). This CC0 reference is separate from the geographic datasets. Neither its declared projection name nor its state IDs provides a verified screen-to-geography transform.

## State facts, flags, cities, and landmarks

- **State capitals and US nicknames:** pinned Wikidata EntityData JSON snapshots. IDs are checked against each state's `P300` ISO code. Current non-deprecated `P36` capital claims are used, with preferred rank taking priority and ended claims excluded. Berlin and Hamburg are their own capitals. Coordinates use `P625`. US nicknames use one English `P1449` name. The app does not call all nicknames official mottos. [Wikidata structured data is CC0](https://www.wikidata.org/wiki/Wikidata:Licensing).
- **German names and slogans:** one sourced phrase per state, with a separate kind: nickname, state brand, tourism slogan, or campaign. `data/learning/german-slogans.json` records the precise source URL. Campaigns are learning facts, not claims of legal motto status or a guarantee that every historic campaign remains in use.
- **Flags:** `P41` identifies each Commons file. Commons image metadata, artist attribution, license, description URL, original URL, and thumbnail URL are retained in `data/learning/flag-metadata.json`. Each downloaded PNG is hash-locked. The app displays file-specific credits and links; it does not assign a blanket license to all flag artwork. Current Minnesota and Utah designs were visually checked. Flag images are not generated substitutes.
- **US city population:** [Census Vintage 2025 ranking workbook](https://www2.census.gov/programs-surveys/popest/tables/2020-2025/cities/totals/SUB-IP-EST2025-ANNRNK.xlsx), saved as `census-us-cities-2025.xlsx`. Use ranks 1–50 and the July 1, 2025 column. Preserve the geographic-area definition, including consolidated-government balances. This set includes Washington, DC. Population estimates may be revised in later vintages.
- **German city population:** [Destatis city visualization](https://service.destatis.de/DE/barchart_race/BarChartRace500k_Berlin_1955-2024.html) and its [published CSV](https://service.destatis.de/DE/barchart_race/data/staedte1b15de1955b2024.csv), saved as `destatis-cities-2024.csv`. Sort the 2024 column descending and select 10. Date: December 31, 2024; municipal boundaries and 2022-census-based figures. These are not local population-register counts. The current Destatis city-size page also reports December 31, 2024.
- **City and landmark coordinates:** pinned Wikidata API/EntityData snapshots. Curated records identify exact Wikidata entities and expected country/state. Place identity and coordinate/state proximity are validated. Do not infer locations from display pixels. Broad parks use the source reference coordinate, not a claimed entrance. The 50 US and 20 German landmarks are curated for learning and geographic variety, not an objective top-visitor ranking.

`compile_learning.py` rebuilds all facts from these local snapshots and curation files. `learning-checksums.json` locks every input and flag image. Compilation performs no network requests. Per-record source links remain in `content/learning.json`; the app exposes them in Browse facts.
