# Data validation record

Validated on 2026-11-23 with Python 3.14, pyshp 3.1.6, Shapely 2.1.2, and openpyxl 3.1.5.

- Twelve catalog entries resolve to schema-version-2 manifests and local geometry assets.
- All 629 unique catalog area geometries are valid Polygon/MultiPolygon features, with closed rings and finite longitude/latitude coordinates. This checks individual geometry validity, not complete coverage or the absence of overlaps between different features.
- US and German state sets match all 50 and 16 ISO identifiers. DC remains background for state questions and is available for city and landmark coordinates. NYC borough codes remain 1–5.
- The active NYC neighborhood pack has 53 areas. All 37 Manhattan feature IDs, names, and inland divisions match the original candidate, except the Financial District, which equals its source minus the hand-drawn Seaport outline. Seaport equals the Financial District inside that outline, and the two together still cover the source exactly. The fifteen other areas have unique IDs and source membership. Each Brooklyn and Queens source area belongs to exactly one practice area. Each area equals its source geometry, or the union of its repaired members, intersected with its own official borough land polygon. The ten named Brooklyn/Queens neighborhoods remain separate. All 53 areas have shoreline provenance and no geometry outside their official borough land. The Bronx and Staten Island exactly match the official borough geometry. The original 266-area candidate and repair report remain unchanged.
- All 309 state and country features equal their original pinned boundaries minus the physical lake dataset at the matching scale. Representative Great Lakes, Great Salt Lake, Okeechobee, German lakes, Baikal, and Victoria points remain water. Illinois still meets Lake Michigan, and both Michigan peninsulas remain selectable land.
- The 769 legacy Natural Earth city/town Points still validate. Their population fields do not drive the new ranked-city games.
- The new database has 66 state capitals, one labeled nickname or slogan per state, and 66 PNG flag assets. Every image decodes in the iOS unit tests. PNG headers, dimensions, source URLs, and hashes also pass the Python validator.
- The 50 US city populations rebuild from the Census 2025 workbook. The 10 German cities rebuild from the sorted Destatis 2024 column. Each country uses one stated date; ranks are complete and populations decrease in rank order.
- All 70 landmark identities are unique, split 50 US and 20 Germany. The three requested US sights have coordinate sanity checks. These are curated sights, not a measured popularity ranking.
- All 196 capital/city/landmark points are within their expected state's geometry or a 0.15-degree shoreline/border tolerance. Each has a source link. All locations round-trip through their rendered US/German map region in iOS tests.
- All nine geographic source locks and the learning-source/asset lock pass. Compilation runs without network access; the latest byte-for-byte check is in [the map review](MAP_REVIEW.md).

The datHere NYC catalog declares ODC-By. Its resource and datastore downloads returned HTTP 403, so exact equivalence with the pinned mirror is not confirmed. See [sources](SOURCES.md).

The full map-by-map result and remaining limits are in [the map review](MAP_REVIEW.md). All 124 playable areas (50 + 16 + 5 + 53) have a selectable interior at two viewport sizes, before and after zoom/pan. Native checks also verify that the corrected water points reject area answers while still accepting location guesses.

App interaction and timer checks are recorded in [iOS verification](../ios/VERIFICATION.md). Source validation alone does not prove runtime behavior or physical-device support.
