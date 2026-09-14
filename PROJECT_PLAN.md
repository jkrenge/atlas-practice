# iOS implementation status

## Implemented: first playable milestone

- SwiftUI app, iOS 18 deployment target, shared Atlas scheme, committed Xcode project, and repeatable build/test/run script.
- Generic schema-version-2 catalog loader. All 11 prepared packs decode; only US states, German states, and official NYC boroughs appear in the selector.
- Geographic Polygon/MultiPolygon renderer with holes, Albers lower-48 projection, separate Alaska/Hawaii insets, antimeridian wrapping, and inverse coordinate transforms.
- Polygon taps, pinch zoom, pan, zoom buttons, and reset. Gestures do not submit answers. Ambiguous border taps, water, holes, and background geometry do not score.
- Linked 44-point neutral markers for Rhode Island, Connecticut, New Jersey, and Delaware, plus Hamburg, Bremen, and Berlin. Study and feedback can reveal labels.
- Find the area and Name the area, labeled study, short untimed sessions, explicit feedback, Show answer, one spaced review per miss, and results.
- Local progress by map and mode. First attempts and review attempts have separate counts.
- Native accessible controls and text feedback alongside color. The area-list alternative supports non-spatial selection; it is not a substitute for spatial learning.

Build, geometry, scoring, Simulator interaction, and accessibility checks are recorded in [ios/VERIFICATION.md](ios/VERIFICATION.md). A physical iPhone remains untested. No distribution or App Store work is included.

## Next core milestones

1. **Capital pairs:** reviewed US/German state-to-capital relationships, stable IDs, aliases, source metadata, and separate progress in each direction. Do not infer capitals from population or shape centroids.
2. **Place the city:** choose a point, adjust a pin, then Check. Invert taps to geographic coordinates before measuring distance. Use reviewed representative city centers; callout boxes cannot submit a city guess.
3. **Largest US cities:** archive and validate the Census Vintage 2025 `SUB-IP-EST2025-ANNRNK` workbook before selecting ranks 1–50. The source has been identified, but its rows have not been validated. Natural Earth population fields are not this ranking.
4. **Continent curricula:** review names, dependencies, disputed/transcontinental areas, islands, overseas geometry, and camera framing. The current 204 World questions are source records, not a sovereign-country count. Seychelles, Mauritius, and Maldives require an explicit continent decision.
5. **Detailed NYC:** resolve the Pediacities candidate license, two topology errors, and coverage before adding everyday neighborhoods. Keep statistical NTAs clearly distinct. Use the official five-borough polygons independently; do not dissolve NTAs to derive boroughs.

## Optional backlog

Outline recognition, land-border neighbors, city/state and neighborhood/borough relationships, and north/south comparisons need a separate product decision and reviewed content.

Additional research ideas retained in the [implementation brief](IMPLEMENTATION_HANDOFF.md):

| Idea | Required work |
| --- | --- |
| Build the map | Place region shapes while preserving geographic proportions. |
| Plan a journey | Validate connected routes against a reviewed adjacency graph. |
| Find the landmark | Add reviewed landmark points or geometry and area links. |
| Follow the river | Add named river geometry and geographic relationships. |
| Find the mistake | Identify and correct swapped map labels. |

These proposals are not implemented. Accounts, leaderboards, payments, social features, and reward systems are outside this delivery.
