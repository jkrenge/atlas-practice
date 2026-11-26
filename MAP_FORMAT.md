# Map format, version 2

Area selection uses a map manifest and geographic geometry. It does not depend on SVG element IDs. Version 1 fields such as `svgAsset` and `shapeIds` are obsolete.

## Catalog

`maps/catalog.json` contains `schemaVersion: 2` and a `maps` array. Each entry has an `id`, `name`, `manifest`, and `areaCount`. Resolve `manifest` relative to the catalog folder. `areaCount` is the number of question areas, not the number of geometry features.

## Map manifest

Resolve asset paths relative to the folder that contains `map.json`. A path can refer to shared geometry in another map folder.

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Integer `2`. Reject unsupported versions. |
| `id` | Unique map ID, such as `us-states`. |
| `name` | Display name. |
| `areaType` | Display term: `state`, `borough`, `neighborhood`, `country`, or `area`. Do not branch game logic on this field. |
| `coordinateSystem` | `OGC:CRS84`: WGS 84 coordinates in **longitude, latitude** order, in degrees. |
| `geometryAsset` | Relative path to a GeoJSON FeatureCollection. |
| `sourceId` | Dataset key documented in `data/SOURCES.md`. |
| `areas` | Explicit question list. Only these IDs can be answers in this map. |
| `areas[].id` | Unique question ID that matches a GeoJSON feature's top-level `id`. |
| `areas[].name` | Prompt name. Matches the feature's `properties.name`. |
| `referenceSvgAsset` | Optional visual reference, currently present only for the US. |
| `referenceSvgGeoreferenced` | `false` for the current SVG. It cannot map pixels to geographic coordinates. |

For example, the US manifest points to `areas-lowres.geojson`, and Colorado has ID `US-CO`. A continent manifest points to `../world-countries/areas-lowres.geojson` and lists only its question areas. Full source-derived `areas.geojson` files remain in the repository for validation and are excluded from the iOS bundle.

The simplified assets use matched shared borders and retain all feature IDs and metadata. Small rings receive tighter simplification limits. Original NYC edge inconsistencies are normalized before simplification; existing gaps remain water, and overlapping source faces belong to the first source feature. Changes to each feature's area are limited to 1%, and known lake and river points must remain water. Higher zoom levels show less coastline detail. Geographic point coordinates are not simplified.

## Geometry and identity

Area geometry is `Polygon` or `MultiPolygon`. Preserve all parts, islands, and interior rings. Ring boundaries are closed. The first ring of a polygon is its exterior; later rings are holes. Use an even-odd fill rule or the equivalent containment logic. Do not treat rectangular bounds as the selected shape.

Each feature has a unique string `id`, a nonempty `properties.name`, and `properties.quizEligible`. Other properties retain source context:

| Dataset | ID rule | Additional properties |
| --- | --- | --- |
| US and Germany | Source ISO 3166-2, such as `US-CO` or `DE-BY` | `nameEnglish` |
| NYC boroughs | `NYC-BORO-` plus `borocode` | `boroughCode` |
| NYC focused practice areas | Original source URI for retained neighborhoods; `NYC-PRACTICE-` plus group name for merged areas; `NYC-PRACTICE-SEAPORT` for the hand-drawn Seaport; official borough ID for the Bronx and Staten Island | `borough`, `shorelineSourceId`, `shorelineAreaID`; outside Manhattan and for Seaport: `sourceId`, `sourceAreaIDs`; Seaport: `outlineSource` |
| NYC NTAs | `NYC-` plus `nta2020` | `borough`, `ntaType` |
| World countries | `NE-` plus Natural Earth `NE_ID` | `continent`, `sourceType`, `adminCode` |

State manifests use `natural-earth-admin1-land`; world and continent manifests use `natural-earth-countries-land`. These IDs identify the original administrative boundaries minus the matching-scale physical lake mask. NYC focused areas use historical neighborhood divisions, plus a hand-drawn Seaport outline (`data/nyc-carve-outs.json`), clipped to official borough land. See [source recipes](data/SOURCES.md).

IDs are stable within the pinned source snapshots. Check source ID changes when data is updated. Never identify an area by its display name or array position.

The manifest's `areas` list controls eligibility for the active map. A shared world feature can have `quizEligible: true` and still be outside a continent's question list. Features outside that list are background. The renderer can crop the view, but it must retain complete answer geometry. Full overseas geometry is preserved. Do not assume each country lies in one compact bounding box.

US states, German states, the world, NYC boroughs, and the focused NYC areas are exposed in the app. The NTA and continent packs are stored references. Continent manifests share complete world geometry; their camera bounds must be reviewed before exposure.

The data contains antimeridian geometry, including Alaska's Aleutian Islands. A naive longitude minimum and maximum can span most of the world. Handle wrapping, polygon splitting, and clipping explicitly in the renderer.

## City points

`data/us-cities.geojson` is a separate FeatureCollection of `Point` features in the same longitude, latitude order. Its feature IDs use `NE-` plus `NE_ID`. Properties are `name`, `stateName`, `sourceId`, `sourcePopulationMax`, and `sourceScaleRank`. The last two are source metadata, not current population facts or a final difficulty ranking.

Use the Point geometry as the city's position. Do not substitute the source's separate `LATITUDE` or `LONGITUDE` fields: they can differ from the actual geometry. These legacy points are reference data. Current city, capital, and landmark questions instead use the sourced points in `content/learning.json`. Its `challenge` object holds the timed-challenge places of the maps without such facts, keyed by map ID (`world-countries`, and `nyc` for both New York City maps); each entry has an `id`, a `name`, and a `coordinate` with `longitude` and `latitude`.

## Required rendering and tap pipeline

The native renderer implements this pipeline for the five playable packs:

```text
longitude/latitude -> projection -> optional inset transform -> viewport/zoom/pan -> screen
screen tap -> inverse viewport -> inverse inset -> inverse projection -> longitude/latitude
```

Use a defined projection with explicit parameters and an inverse. A projected map can distort distance; screen pixels and projected map units are not a geographic distance measure. The implemented projections and inset parameters are documented in [README.md](README.md). No projection parameters or view configuration are stored in this version of the manifests.

The US map uses separate lower-48, Alaska, and Hawaii view regions. Each region needs its own forward transform, inverse transform, clipping boundary, and screen hit region. Select the correct region before inverting a tap. Empty inset space must not map to an unrelated location. Preserve the original geographic coordinates when a region is moved or scaled.

All maps must support pinch zoom and pan. Drawing, shape selection, leader lines, and callout anchors must use the same current transforms. Callout boxes for small states, including Delaware and Rhode Island, must visibly link to their actual shapes. A callout and its shape select the same area ID. A callout tap has no unique geographic coordinate and must not be used as a city-distance guess.

For city mode, convert a map tap to longitude and latitude, then calculate a geodesic distance in meters to the city's Point. Test the result against known coordinate pairs. Zoom, pan, screen size, and inset scale must not change the result. Current location questions use haversine distance and fixed thresholds of 50 km for US maps and 20 km for Germany. Water is a valid location guess inside a geographic map region. The timed challenge scores the same distance against a range per map; [README.md](README.md) gives the formula.
