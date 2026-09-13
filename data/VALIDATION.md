# Data validation record

Validated on 2026-09-13 with Python 3.14, pyshp 3.1.6, and Shapely 2.1.2.

- All six source snapshots match their SHA-256 lock.
- All eleven catalog entries resolve to version-2 manifests and local geometry assets.
- All question IDs are unique and reference matching named features. The US and German ID sets match all 50 states and all 16 federal states. DC is background. The borough pack contains codes 1–5.
- All 576 active area features have nonempty, valid Polygon or MultiPolygon geometry. All rings are closed, all coordinates are finite longitude/latitude pairs, and all positions are within geographic bounds. This checks individual geometry validity, not complete coverage or the absence of overlaps between different features.
- All 769 US city and town Points are valid. Los Angeles, New York, Anchorage, and Honolulu each have one named record in the expected region. This is not a current population ranking.
- Two successive compiler runs reproduced all 19 generated JSON/GeoJSON files and the checksum lock byte-for-byte. The candidate output also matches the research task's normalization as JSON.

| Active geometry | Features | Longitude range | Latitude range |
| --- | ---: | --- | --- |
| US states | 51 | -179.143503 to 179.780935 | 18.906117 to 71.412502 |
| German states | 16 | 5.852490 to 15.022059 | 47.271121 to 55.065334 |
| NYC boroughs | 5 | -74.255591 to -73.700009 | 40.496134 to 40.915533 |
| NYC NTAs | 262 | -74.255591 to -73.700009 | 40.496134 to 40.915533 |
| World | 242 | -180 to 180 | -89.998926 to 83.599609 |

The US longitude range crosses the antimeridian. Do not use the simple min/max range to frame the full US map.

## Candidate issues

The 266-area Pediacities candidate is outside the active catalog. Country Club and Marine Park fail topology validity checks. Chinatown, Nolita, Tribeca, and Financial District each have a separate valid Polygon in Manhattan. The exact candidate license is unverified. See [candidate notes](candidates/README.md).

## Not yet tested

No iOS app or renderer exists. Projection round trips, inset transforms, screen tap selection, callouts, zoom, pan, city-distance scoring, simulator behavior, and physical-device behavior remain implementation work. Data validation does not prove those features work.
