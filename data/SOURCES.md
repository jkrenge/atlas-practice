# Geographic data sources

All snapshots were downloaded on **2026-09-13**. Original bytes are retained under `data/sources/`; SHA-256 hashes are in `data/source-checksums.json`. Compilation verifies those hashes before writing output. Source data is not covered by an assumed project-wide license.

## Natural Earth

Natural Earth makes its map data public domain. See the [official terms](https://www.naturalearthdata.com/about/terms-of-use/). Credit: Made with Natural Earth. The archive `VERSION.txt` files confirm the versions below, and their `.prj` files declare WGS 84 geographic coordinates. `pyshp` reads the geometry without reprojection, simplification, or vertex rounding.

| Source ID | Snapshot and direct download | Version | Output and selection |
| --- | --- | --- | --- |
| `natural-earth-admin1` | [ne_10m_admin_1_states_provinces.zip](https://naturalearth.s3.amazonaws.com/10m_cultural/ne_10m_admin_1_states_provinces.zip) | 5.1.1, 1:10 million | Keep `adm0_a3` USA or DEU; use `iso_3166_2` as ID. 51 US features, with US-DC excluded from questions; 16 German states. |
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

## Candidate: Pediacities / Ontodia neighborhoods

This data is retained for prototype evaluation outside the active map catalog. Its exact upstream license is unverified. Two normalized geometries are invalid. See [candidate notes](candidates/README.md) before using it.

- [Pinned ix4 mirror download](https://gist.githubusercontent.com/ix4/ff7603f48283cf06fc4fb3dfb6a0635c/raw/5cdd9db840eb9235d116c5f632599dca1b925d11/nyc.geojson), saved as `nyc-pediacities-neighborhoods.geojson`.
- [Mirror page](https://gist.github.com/ix4/ff7603f48283cf06fc4fb3dfb6a0635c), revision `5cdd9db840eb9235d116c5f632599dca1b925d11`. The boundary vintage is unknown; mirror activity is not a boundary update date.
- [Catalog](https://data.dathere.com/dataset/nyc-neighborhoods) credits Pediacities/Ontodia. [Niche's attribution](https://www.niche.com/about/urban-neighborhood-data-disclaimers-and-sources/) refers to ODC Attribution, but this is downstream evidence and does not verify the license for these exact bytes.

The raw snapshot has 310 records. Compilation skips seven null geometries and groups polygon parts by the existing `properties.@id`, yielding 266 named areas. IDs are the original source URIs. No vertices are changed, and no topology repair is applied. Boundaries are approximate and historical; named parks and islands are included. Provisional credit: Neighborhood boundaries from Pediacities / Ontodia; normalized from the ix4 GeoJSON mirror.

## Decorative US SVG

See [assets/SOURCE.md](../assets/SOURCE.md). This CC0 reference is separate from the geographic datasets. Neither its declared projection name nor its state IDs provides a verified screen-to-geography transform.
