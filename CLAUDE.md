# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Tokei is a SwiftUI world clock. Saved time zones are markers on a photo-real 3D globe with a live day/night terminator, city lights and an atmosphere; a time tape shifts the displayed moment. A WidgetKit extension shows the same cities, the same shift and a day/night map. The deployment target in the project file is recent enough that Liquid Glass and other current SwiftUI APIs are used without availability checks.

## Build

- Xcode project only, no package managers. Scheme `tokei` builds the app and embeds `tokeiWidgetExtension`.
- CLI: `xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'platform=iOS Simulator,name=<device>' build`.
- No test target. Verify in the simulator; widgets are added from the home-screen widget gallery.

## Layout

- `Shared/` is a file-system-synchronized folder attached to both targets: the `Zone` model, App Group persistence (`ZoneStorage`), time formatting (`ZoneClock`), sun ephemeris (`SolarPosition`), label collision placement (`LabelPlacer`) and the palette. Anything the widget needs lives here.
- `tokei/Globe/` renders the globe as one full-screen Metal fragment shader (`Globe.metal`) that ray-traces an analytic sphere. There are no meshes and no RealityKit.
- `tokei/Clock/` holds the stores, the time tape and scrubber panel, the city list and the city picker.
- `tokeiWidget/` holds the timeline provider, the intents and the widget views.

## Rules that are easy to break

- One displayed time: `now + shift`. The sun, marker chips, list rows and widget entries all derive from that single date. Never call `Date()` inside formatting helpers or views.
- The globe is Earth-fixed: the camera orbits a still Earth and the sun direction moves with time. The latitude/longitude ↔ vector convention is duplicated in the shader (`atan2`/`asin`) and in `GeoPoint.unitVector`; change both or neither.
- `GlobeFrame` is the immutable per-frame snapshot used both for shader uniforms and for projecting SwiftUI marker chips. Chips must stay unanimated in position, or they drift off their cities.
- `GlobeLayerView` draws on demand in `layoutSubviews` and presents with the Core Animation transaction, so a SwiftUI update and its Metal frame land together. Continuous motion (inertia, fly-to, shift glide) is a pure function of time inside `TimelineView(.animation)`; `.task(id:)` settles it. Nothing renders while idle except the minute tick.
- The atmosphere is single scattering with a precomputed transmittance LUT that includes the planet shadow. Twilight warmth, moonlight and the reduced haze over the night side are deliberate art terms, not physics. The shader encodes sRGB itself into a non-sRGB drawable after tone mapping; do not add a second gamma.
- Globe textures are bundle resources in `tokei/Resources` (NASA Blue Marble / Black Marble plus a water mask) uploaded with mipmaps; the widget has its own small map images in its asset catalog.
- The stored JSON shape of `Zone` must stay decodable; suite name and keys live in `ZoneStorage`. The shift is a persisted relative offset shared with widgets.
- Every persisted mutation calls `WidgetCenter.shared.reloadAllTimelines()`. Scrubbing persists only when the glide settles, not per drag sample.
- Widget kind identifiers (in `TokeiWidgets.swift`) are placed on users' home screens: never rename or remove them. Intent type names are referenced by the system too.
- Widget timelines are minute-aligned and self-contained. The night mask is computed on the CPU per entry (`NightMask`); the extension does no GPU work.
- `tokei://zone/<uuid>` opens the app focused on that city (used by widget rows).
