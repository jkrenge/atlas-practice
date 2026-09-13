# Decorative US state map

[Wikimedia source page](https://commons.wikimedia.org/wiki/File:Blank_US_Map_(states_only).svg). Author: Heitordp, with subsequent Wikimedia edits. License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).

Downloaded on 2026-09-13. The source page's current file revision is dated 2020-12-22. `assets/us-states.svg` retains the original bytes. Separate state paths use lowercase two-letter CSS classes. The prepared `maps/us-states/map.svg` adds a `0 0 959 593` viewBox and `us-xx` path IDs for the 50 states.

The SVG has a decorative layout with Alaska and Hawaii insets. It is not registered to the GeoJSON, and no forward or inverse geographic transform has been verified. Retain it as a visual reference only. Render the app's geographic maps from GeoJSON. SVG pixels must not be used for city placement or geographic distance.
