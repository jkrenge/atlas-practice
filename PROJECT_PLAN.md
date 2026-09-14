# iOS implementation status

## Implemented

- Native SwiftUI app, iOS 18 target, generated Xcode project, and repeatable build/test/run script.
- Four playable maps: 50 US states, 16 German states, five official NYC boroughs, and 47 NYC practice areas (37 unchanged Manhattan areas and 10 across the other boroughs). All twelve prepared map packs decode.
- Geographic polygon rendering, holes, reversible projections, Alaska/Hawaii insets, 32× zoom, pan, and linked small-state markers. Point questions use geographic coordinates and accept coastline/water positions inside an inset.
- Nine US/German modes: Find the area, Name the area, State capitals, State flags, Nicknames & slogans, Locate capitals, Locate cities, City populations, and Locate landmarks. NYC maps use the two area modes.
- Offline database: 66 state capitals/names/flags, 50 US and 10 German city populations, and 50 US plus 20 German landmark coordinates. Browse facts includes images, population dates, coordinate definitions, and source links.
- Untimed, 30-second, or 60-second questions; manual pause/resume; automatic pause while inactive and during feedback; timeout feedback and one review per miss.
- Adjustable map pins and distance feedback. A location within 50 km on US maps or 20 km in Germany is correct. Coordinate entry offers an accessible alternative to a map tap.
- Six-question sessions, one spaced review per miss, explicit feedback, and separate first/review scores. Local progress is separated by map, mode, and timer setting.
- Original NYC geometry retained. Two self-intersections repaired only in the active pack. Approximate boundaries and the source-download equivalence limit are documented in the app and data notes.

See [verification](ios/VERIFICATION.md) and [data sources](data/SOURCES.md).

## Remaining scope

- World and continent curricula need review of disputed areas, dependencies, names, and map framing before they appear in the app.
- Physical iPhone, older supported iOS versions, iPad, and a complete spoken VoiceOver session still need device-specific checks.
- NYC polygon validity is verified individually; this does not prove gap-free, non-overlapping coverage or definitive neighborhood boundaries. The catalog declares ODC-By, but the licensed resource download could not be compared with the pinned mirror.
- No account system, leaderboard, TestFlight, App Store, or public distribution is included.

Other optional ideas remain in the historical [implementation brief](IMPLEMENTATION_HANDOFF.md). They are not part of the current delivery.
