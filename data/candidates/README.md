# NYC finer-neighborhood candidate

`nyc-neighborhoods.geojson` contains 266 named areas normalized from the pinned Pediacities / Ontodia mirror. It is **outside `maps/catalog.json`**. The exact upstream license remains unverified; confirm it before distribution. Source URLs and normalization rules are in [SOURCES.md](../SOURCES.md).

Chinatown, Nolita, Tribeca, and Financial District each have a separate Polygon in Manhattan. All four pass the geometry validity check. `FiDi` is a proposed display alias for Financial District; no alias field has been added.

The dataset includes named parks and islands. Its boundaries are approximate and historical, and the boundary vintage is unknown. It is not a residential-only neighborhood curriculum.

Shapely 2.1.2 reports two invalid geometries:

| Source ID suffix | Issue |
| --- | --- |
| `Country_Club` | Self-intersection near longitude -73.812524347705, latitude 40.8450348665851 |
| `Marine_Park` | Self-intersection near longitude -73.924441, latitude 40.605794 |

Full IDs begin with `http://nyc.pediacities.com/Resource/Neighborhood/`. The validator checks that these are the only known invalid features. Their presence is reported separately from the valid active map packs. No repair has been applied. Review polygon overlaps, gaps, names, and these two geometries before promoting the data to a map pack.
