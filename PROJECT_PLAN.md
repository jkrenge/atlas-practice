# Project status and plan

## Implemented

- Native SwiftUI app, iOS 18 target, generated Xcode project, and repeatable build/test/run script.
- Four playable map packs: 50 US states, 16 German states, five official NYC boroughs, and 53 NYC practice areas (37 Manhattan source areas with preserved names and inland divisions, a hand-drawn Seaport, and 15 across the other boroughs). The home screen shows them as three cards: United States, Germany, and New York City, which opens a city page with the boroughs and neighborhoods maps. All twelve prepared map packs decode.
- Geographic polygon rendering, holes, reversible projections, Alaska/Hawaii insets, 32× zoom, pan, and linked small-state markers. Point questions use geographic coordinates and accept coastline/water positions inside an inset.
- Nine US/German modes: Find the area, Name the area, State capitals, State flags, Nicknames & slogans, Locate capitals, Locate cities, City populations, and Locate landmarks. NYC maps use the two area modes.
- Offline database: 66 state capitals/names/flags, 50 US and 10 German city populations, and 50 US plus 20 German landmark coordinates. Browse facts includes images, population dates, coordinate definitions, and source links.
- Untimed, 30-second, or 60-second questions; manual pause/resume of timed questions; automatic pause while inactive and during feedback; timeout feedback and one review per miss.
- Adjustable map pins and distance feedback. A location within 50 km on US maps or 20 km in Germany is correct. Coordinate entry offers an accessible alternative to a map tap.
- Each round asks 10 or 25 places, or all of them (Settings → Questions; default 10). One spaced review per miss, explicit feedback, separate first/review scores, and a first-try rank on the results screen. Local progress is stored by map, mode, and timer setting; the app shows the combined score.
- Settings: round length, timer, reset progress, help and privacy links, map sources and credits, version. The privacy manifest declares no tracking and no collected data. The public website is in `website/`.
- State and country maps exclude mapped lakes at the matching source scale. NYC practice areas are clipped to official borough shorelines. Map IDs are stable; Park Slope, Prospect Heights, Downtown Brooklyn, Crown Heights, Prospect Park and Seaport left their former groups in 2026-11. See [map review](data/MAP_REVIEW.md).
- Original NYC geometry retained. Two self-intersections repaired only in the active pack. Approximate boundaries and the source-download equivalence limit are documented in the app and data notes.

See [verification](ios/VERIFICATION.md) and [data sources](data/SOURCES.md).

## Remaining scope

- World and continent curricula need review of disputed areas, dependencies, names, and map framing before they appear in the app.
- Release builds have been installed and launched on an iPhone (latest 2026-11-23). Automated device UI checks last ran on 2026-10-10, on the earlier interface. Not yet checked: the current interface by hand on a device, iPad hardware, iOS 18 at runtime, and a full spoken VoiceOver session.
- NYC polygon validity is verified individually; this does not prove gap-free, non-overlapping coverage or definitive neighborhood boundaries. The catalog declares ODC-By, but the licensed resource download could not be compared with the pinned mirror.
- No account system or leaderboard. TestFlight build 1.0 (1), with the earlier interface, was uploaded on 2026-10-05. The App Store release is pending.

## Backlog

Optional ideas, not part of the current delivery. Most need reviewed data or relationships before they can ship; Build the map, Find the mistake and Outline recognition reuse the existing shapes and names.

| Idea | Interaction | Data or implementation needed |
| --- | --- | --- |
| Build the map | Place region outlines into a blank map. Start with three neighboring regions and destination hints, then remove hints. | Drag placement and geographic alignment; reuse region shapes. Preserve shape proportions. |
| Plan a journey | Tap a connected route from California to Colorado. Accept any valid route first; shortest route is a later challenge. | Reviewed adjacency graph and route validation. |
| Landmarks in NYC | Select the NYC area a sight is in, such as Times Square. (Locate landmarks already exists for the US and German maps.) | Reviewed links from sights to NYC practice areas. |
| Follow the river | Identify a highlighted river that separates two areas. | River geometry, names, and reviewed relationships. |
| Find the mistake | Identify and correct two swapped map labels. | Existing region shapes and names plus label-placement and answer controls. |
| Outline recognition | A Name the area variant: show one region's outline, north up, then reveal it in context. | Keep aspect ratio and disconnected parts. Not for isolated neighborhood outlines. |
| Neighbors and relations | Find a land-border neighbor, name a neighborhood's borough or a city's state, or pick which city is farther north. | Reviewed relationships or unambiguous comparisons. |

Build the map is the most distinct next game; Find the mistake is the smallest addition. Accounts, leaderboards, payments, social features, and a reward economy are out of scope.
