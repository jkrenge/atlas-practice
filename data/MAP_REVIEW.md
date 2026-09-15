# Map review — 2026-09-14

Reviewed all 12 catalog entries, their six unique geometry collections, source versions, question lists, and the four native map layouts exposed in the app. The playable packs contain 118 question areas. All 623 catalog area features pass geometry validation.

## Map decisions

| Pack | Features / questions | Source and result | App status |
| --- | --- | --- | --- |
| US states | 51 / 50 | Natural Earth Admin 1 Lakes 5.1.1, plus the 10m physical lake mask 5.0.0. The existing Great Lakes correction is retained; smaller mapped lakes now also remain water. DC stays background. | Playable; source and native checks pass. |
| German states | 16 / 16 | Natural Earth Admin 1 5.1.1, minus the 10m physical lake mask 5.0.0. Corrects filled lakes such as Constance, Müritz, and Schweriner See. | Playable; source and native checks pass. |
| NYC boroughs | 5 / 5 | Official NYC DCP shoreline boundaries, version 26b. All geometry matches the original snapshot exactly. No correction needed. | Playable; source and native checks pass. |
| NYC practice areas | 47 / 47 | Historical Pediacities/Ontodia neighborhood divisions, grouped as requested, then clipped to their own official DCP borough shoreline. Corrects extensions at DUMBO and along Newtown Creek. | Playable; approximate neighborhood divisions. |
| NYC 2020 NTAs | 262 / 197 | Official DCP statistical areas, version 26b. All geometry matches the original snapshot exactly. These are not definitive neighborhood boundaries. | Stored reference. |
| World countries | 242 / 204 | Natural Earth Admin 0 5.1.1, minus the matching 50m physical lake mask 5.0.0. Removes mapped lakes, including Baikal and Victoria, from country fill. | Stored reference; camera and curriculum review required. |
| Africa countries | Shared world / 53 | Same corrected country geometry; source continent filter verified. | Stored reference. |
| Asia countries | Shared world / 48 | Same corrected country geometry; source continent filter verified. | Stored reference. |
| Europe countries | Shared world / 48 | Same corrected country geometry; source continent filter verified. | Stored reference. |
| North America countries | Shared world / 26 | Same corrected country geometry; source continent filter verified. | Stored reference. |
| South America countries | Shared world / 12 | Same corrected country geometry; source continent filter verified. | Stored reference. |
| Oceania countries | Shared world / 14 | Same corrected country geometry; source continent filter verified. | Stored reference. |

State boundaries and lake masks use 1:10 million scale; country boundaries and lake masks use 1:50 million. They are suitable for a generalized geography-learning map, not exact shore surveys. Smaller water bodies can be absent from the source. Source URLs, licenses, versions, and the exact compilation recipes are in [SOURCES.md](SOURCES.md).

The state and country variants that exclude large lakes are not sufficient by themselves. The Admin 1 variant leaves the checked German lakes filled; the country variant still fills interior lakes such as Baikal. The compiler therefore subtracts the official physical lake layer at the matching scale. Both added archives are pinned with SHA-256 hashes.

## NYC grouping and coverage

All 37 Manhattan areas keep their IDs, names, and inland divisions. Bed-Stuy, DUMBO, Williamsburg, Greenpoint, and Long Island City remain separate. The three broader Brooklyn/Queens groups keep their existing membership. The Bronx and Staten Island each remain one official borough area.

The shoreline intersection removes excess coverage; it does not fill missing land in the historical source or make its neighborhood divisions official. Before clipping, the source missed approximately 0.56% of Manhattan borough land, 1.06% of Brooklyn, and 0.23% of Queens. These are diagnostic ratios in longitude/latitude space, not surveyed area measurements. Source gaps remain visible. Within each borough, no positive-area overlaps were found between the practice areas.

Live DCP metadata was checked again on 2026-09-14. Both borough and NTA datasets still report version 26b and the row-update timestamps retained in the source metadata. The Pediacities mirror has no established boundary vintage. Exact equivalence with the catalog's licensed download remains unconfirmed because that download returned HTTP 403.

## Coordinate and source checks

- All 309 state and country features equal their original pinned administrative geometry minus the matching lake mask.
- All 267 official borough and NTA features match their saved source geometry exactly.
- All 47 practice areas match their source members after repair, grouping, and intersection with the correct borough land. Every area records its shoreline source and borough ID.
- All 12 map IDs, question IDs, names, and order are unchanged. The original neighborhood candidate, repair report, and game facts are unchanged.
- Nine geographic source hashes pass. A repeat offline compilation reproduced all 22 generated map/source/repair files byte for byte.
- All 196 capital, city, and landmark points still pass the learning validator and native projection/inverse checks. Point questions can accept water; area questions cannot select it.

The native app renders GeoJSON. Its decorative US SVG is not used for rendering, map taps, or geographic distance.

## Native verification

The Atlas scheme built and passed **23 unit tests and six selected UI tests** on iPhone 17 Pro Simulator, iOS 26.5, with Xcode 26.6. Checks cover every playable area's interior at portrait and landscape viewport sizes, zoom/pan transforms, Great Lakes and Illinois, new lake/river regressions, US insets, native gestures, neighborhood selection, and landmark pin placement. See [iOS verification](../ios/VERIFICATION.md) for the result bundle and exact scope.

A separate iPhone 17 Simulator inspection confirmed the US overview and insets, Germany's map and state selection, and the reduced NYC map with DUMBO selection and zoom. The new map update has not been installed on the physical phone as part of this review.

## Limits before enabling stored country maps

Each continent manifest filters answer eligibility but still loads the full world geometry. The current generic layout fits all those features. Continent camera bounds and global antimeridian handling need separate runtime verification before those entries can be enabled. This review validates their source data; it does not certify them as finished game modes.

The 204 World records follow provisional Natural Earth classifications, not a final sovereign-country count. The six continent lists contain 201 records; Seychelles, Mauritius, and Maldives appear only in World because their source continent is `Seven seas (open ocean)`. Disputed boundaries, dependent territories, and transcontinental assignments need an explicit curriculum decision before release.
