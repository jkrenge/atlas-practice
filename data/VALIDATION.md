# Data validation record

Validated on 2026-09-14 with Python 3.14, pyshp 3.1.6, Shapely 2.1.2, and openpyxl 3.1.5.

- Twelve catalog entries resolve to schema-version-2 manifests and local geometry assets.
- All 623 active area geometries are valid Polygon/MultiPolygon features, with closed rings and finite longitude/latitude coordinates. This checks individual geometry validity, not complete coverage or the absence of overlaps between different features.
- US and German state sets match all 50 and 16 ISO identifiers. DC remains background for state questions and is available for city and landmark coordinates. NYC borough codes remain 1–5.
- The active NYC neighborhood pack has 47 areas. All 37 Manhattan feature IDs, names, and coordinates match the original candidate exactly. The ten other areas have unique IDs and source membership. Each Brooklyn and Queens source area belongs to exactly one practice area; each merged geometry equals the union of its repaired members. The five retained neighborhoods keep their geometry. The Bronx and Staten Island exactly match the official borough geometry. The original 266-area candidate and repair report remain unchanged.
- The 769 legacy Natural Earth city/town Points still validate. Their population fields do not drive the new ranked-city games.
- The new database has 66 state capitals, one labeled nickname or slogan per state, and 66 PNG flag assets. Every image decodes in the iOS unit tests. PNG headers, dimensions, source URLs, and hashes also pass the Python validator.
- The 50 US city populations rebuild from the Census 2025 workbook. The 10 German cities rebuild from the sorted Destatis 2024 column. Each country uses one stated date; ranks are complete and populations decrease in rank order.
- All 70 landmark identities are unique, split 50 US and 20 Germany. The three requested US sights have coordinate sanity checks. These are curated sights, not a measured popularity ranking.
- All 196 capital/city/landmark points are within their expected state's geometry or a 0.15-degree shoreline/border tolerance. Each has a source link. All locations round-trip through their rendered US/German map region in iOS tests.
- Original source locks and the new learning-source/asset lock pass. Successive map and learning compiler runs reproduce the generated output byte-for-byte without network access.

The datHere NYC catalog declares ODC-By. Its resource and datastore downloads returned HTTP 403, so exact equivalence with the pinned mirror is not confirmed. See [sources](SOURCES.md).

App interaction and timer checks are recorded in [iOS verification](../ios/VERIFICATION.md). Source validation alone does not prove runtime behavior or physical-device support.
