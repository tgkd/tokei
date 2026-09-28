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
- `tokei/Globe/` draws the globe with Metal (`Globe.metal`), no RealityKit. Each scene style (`SceneStyle`) has its own pipeline and the style rides in `GlobeFrame`, so switching redraws like any other frame change. The realistic style is one full-screen fragment shader that ray-traces an analytic sphere. The mesh styles (Toy, Ice) are artistic, deliberately non-geographic globes: a displaced cube-sphere mesh drawn with MSAA and depth. Land shapes (`ToyShape`: puffy, and glacier with seeded mountain ranges around iconic peaks from `MountainRange`, shape only and never recoloured), the ocean mask and per-shape normal/height maps are generated on the CPU from the water mask at load (`ToyTerrain`), not bundled. Each mesh style picks a palette, a material (`ToyMaterial`, including an optional interactive snow cover), a shape, a sound timbre and a UI accent in `SceneStyle`.
- `tokei/Clock/` holds the stores, the time tape and scrubber panel, the city list and the city picker.
- `tokei/Feedback/` holds sound and haptics: cues, the code-generated sound set, the audio engine and the Core Haptics wobble.
- `tokeiWidget/` holds the timeline provider, the intents and the widget views.

## Rules that are easy to break

- One displayed time: `now + shift`. The sun, marker chips, list rows and widget entries all derive from that single date. Never call `Date()` inside formatting helpers or views.
- The globe is Earth-fixed: the camera orbits a still Earth and the sun direction moves with time. The latitude/longitude ↔ vector convention is duplicated in the shader (`atan2`/`asin`) and in `GeoPoint.unitVector`; change both or neither.
- `GlobeFrame` is the immutable per-frame snapshot used both for shader uniforms and for projecting SwiftUI marker chips. Chips must stay unanimated in position, or they drift off their cities.
- `GlobeLayerView` draws on demand in `layoutSubviews` and presents with the Core Animation transaction, so a SwiftUI update and its Metal frame land together. Continuous motion (inertia, fly-to, shift glide) is a pure function of time inside `TimelineView(.animation)`; `.task(id:)` settles it. Nothing renders while idle except the minute tick.
- The realistic atmosphere is single scattering with a precomputed transmittance LUT that includes the planet shadow. Twilight warmth, moonlight and the reduced haze over the night side are deliberate art terms, not physics. The shader encodes sRGB itself into a non-sRGB drawable after tone mapping; do not add a second gamma.
- Surface texture sampling uses explicit gradients taken before any coverage branch, because derivatives are undefined in divergent control flow. New taps and `fwidth` terms reuse or join that hoisted block.
- The toy style's day/night gates read the radial direction of the surface point only; the displaced shape and its normals feed material shading, never the terminator or city-light gating.
- The toy vertex shader reproduces `GlobeFrame.project` exactly, and in the toy style `MarkerLayout` lifts each city onto the drawn triangles through `ToySurface`. A change to the camera projection or the mesh has to reach both sides, or chips drift off their cities.
- Interaction effects (press dent and squash, city pop and ripple, fling stretch, toy inflate, fly-to arc) are time-parameterised records in `SceneEffects`, evaluated once per frame into `GlobeFrame.effects`, like camera motion. Each style has its own `EffectTuning`, so styles are tuned independently. The shaders and `EffectSnapshot.place` (which positions chips) apply the same displacement formulas: change both or neither.
- Snow footprints live in `SnowCover`: a CPU-written R16F map of when each spot was last disturbed, relative to the cover's epoch. Refill is a pure function of the snow clock in `EffectUniforms.state.w`, and the map is cleared when the `SceneEffects.snow` record settles, so no per-frame decay pass exists.
- The realistic fragment is compiled twice through a function constant. The effect-free variant is the untouched ray tracer and draws every idle frame; the renderer switches to the effects variant only while an effect is live.
- Sounds belong to mesh styles only (Toy soft, Ice glass timbre) and are generated in code, played through an `.ambient` audio engine that runs only while such a style is active, sound is on and the app is in the foreground. Discrete haptics go through `SceneModel.cue` into `.sensoryFeedback`; the release wobble uses Core Haptics. Neither can be judged in the simulator.
- Mesh-style colours are authored in `ToyPalette` as sRGB and uploaded linear; each palette's backdrop is also the SwiftUI and layer background and the mesh pass's clear colour, so that file is the one place to change them. App UI takes its accent from the `sceneAccent` environment value, set from the style; widgets keep `Color.sunlight`.
- Globe textures are bundle resources in `tokei/Resources` (NASA Blue Marble / Black Marble plus a water mask) uploaded with mipmaps; the widget has its own small map images in its asset catalog.
- The stored JSON shape of `Zone` must stay decodable; suite name and keys live in `ZoneStorage`. The shift is a persisted relative offset shared with widgets.
- Every mutation of App Group data calls `WidgetCenter.shared.reloadAllTimelines()`. Scrubbing persists only when the glide settles, not per drag sample. App-only preferences such as the scene style live in standard defaults and do not reload widgets.
- Widget kind identifiers (in `TokeiWidgets.swift`) are placed on users' home screens: never rename or remove them. Intent type names are referenced by the system too.
- Widget timelines are minute-aligned and self-contained. The night mask is computed on the CPU per entry (`NightMask`); the extension does no GPU work.
- `tokei://zone/<uuid>` opens the app focused on that city (used by widget rows).
