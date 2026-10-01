# Task: Persistent mark map for brush strokes and stamps that last until the theme changes

## Goal

A mesh theme can declare `marks:` in its `MeshLook`. For such a theme:

- a hold-then-drag paints a brush stroke into an RG16F map, either parallel grooves or a dashed running stitch;
- a city pop can stamp concentric rings into the same map;
- the map is bound at mesh fragment `texture(6)`.

Marks stay until the theme changes or the app leaves the foreground. They cost nothing while idle, they redraw under Reduce Motion, and existing themes are unaffected.

## Files

- tokei/Globe/MarkMap.swift (create)
- tokei/Globe/Looks/SceneLook.swift (modify)
- tokei/Globe/Shaders/GlobeShared.h (modify)
- tokei/Globe/GlobeRenderer.swift (modify)
- tokei/Globe/GlobeFrame.swift (modify)
- tokei/Globe/GlobeScene.swift (modify)
- tokei/Globe/SceneModel.swift (modify)
- tokei/Globe/SnowCover.swift (read: texel iteration, dirty-rect upload, `tangent`)
- tokei/Globe/SnowTrail.swift, tokei/Globe/SurfaceStroke.swift (read)

## Context

- **SnowCover, the map to mirror.**
  - An R16F 2048×1024 equirect texture with a CPU mirror of `[Float16]`.
  - Column = longitude `atan2(x, z)`; row 0 is latitude +90°. Shaders sample it at `surfaceCoordinates(n).uv` = (lon/2π + 0.5, 0.5 − lat/π).
  - `paint(around:reach:…)` walks the rows within reach and the wrapped columns, skipping texels outside `cos(reach)`. Precomputed row and column sines and cosines give each texel's direction.
  - `markDirty` plus `flush` upload only the touched rows and columns with `texture.replace`.
  - `carve(from:to:…)` splits a segment into pieces no longer than half the trail radius.
- **Drag flow in SceneModel.**
  - `GlobeTouch` decides hold-then-drag. Then `beginSurfaceDrag(at:footprint:location:)` and `dragSurface(to:location:)` run, the point being nil when the finger is off the globe, and finally `endSurfaceDrag()`.
  - `footprint` is the angle in radians that spans 16 pt at the current zoom (`16 / globeRadius`).
  - Grain sound and haptics fire from `SurfaceStroke.advance` every `drag.grainSpacing` points. Leave that untouched.
- **Drag permission.** `allowsSurfaceDrag` is `mesh.snow != nil || !reduceMotion`. Under Reduce Motion there is no press record, so no dent follows the finger and no effect record changes while drawing.
- **When frames draw.** `GlobeLayerView` draws only when the `GlobeFrame` value changes (it is `Equatable`). GlobeScene builds the frame inside a `TimelineView` that is paused when `effects.cadence == .still`, but SwiftUI still re-evaluates it when observed state it reads changes. The offline harness builds `GlobeFrame` with its memberwise initialiser and no new fields, so new fields need defaults.
- **Textures in `GlobeRenderer`.**
  - `snowCover` is created in `init`.
  - `encodeMesh`, used by both the normal and the pixel-art paths, binds fragment textures 0 day, 1 lights, 2 coast, 3 relief, 4 snow and 5 weather. Absent ones get `placeholder`, an rgba8 1×1 black texture whose `.r` is 0.
  - Mesh `sampler(0)` is linear and mipmapped, repeat in u, clamp in v.
- **Reset points.** `SceneModel.resetDisturbance()` runs on every style change. `isForeground`'s `didSet` runs when the app goes to the background.
- **Offline harness.** `.claude/duck/scene-style/harness` (gitignored, present in this working copy) compiles everything under `tokei/Globe` except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and a few other views. `MarkMap.swift` will be compiled there, on macOS, so it imports only Foundation, Metal and simd.

## Plan

1. **MarkMap.swift.**
   - Add `enum MarkBrush: Equatable { case grooves(tines: Int); case stitches(dash: Double, gap: Double) }`. `dash` and `gap` are multiples of the stroke half-width.
   - Add `enum MarkStamp: Equatable { case rings(radius: Double, spacing: Double) }`, in radians.
   - Add `struct MarkSettings: Equatable { var drag: MarkBrush; var pop: MarkStamp?; var width: Double }`, where `width` is the stroke half-width divided by the touch footprint.
   - Add `struct MarkStroke { let halfWidth: Double; var last: SIMD3<Double>?; var distance = 0.0 }`.
   - Add `@MainActor final class MarkMap`:
     - `static let width = 2048`, `static let height = 1024`;
     - a `.rg16Float` texture, usage `.shaderRead`, storage `.shared`;
     - CPU arrays `coverage: [Float16]` and `phase: [Float16]`, the phase stored premultiplied by coverage;
     - `private(set) var revision = 0`;
     - `init?(device:)`.
   - **`func sweep(to point: SIMD3<Double>, stroke: inout MarkStroke, brush: MarkBrush)`.**
     - With no `stroke.last`, set it and return.
     - Otherwise split the arc from `last` to `point` into pieces no longer than half of `halfWidth`.
     - For each piece, with `side = normalize(cross(start, end))`, visit the texels within reach. Keep only those whose projection onto the chord falls inside it (0 ≤ along ≤ 1).
     - Signed `across = dot(texel − start, side) / halfWidth`; skip it when `abs(across) ≥ 1`.
     - Coverage `a = 1 − smoothstep(0.8, 1, abs(across))`.
     - `.grooves(tines)`: `phase = across · Double(tines) / 2`.
     - `.stitches(dash, gap)`: with `s = stroke.distance + along · pieceArc`, `period = (dash + gap) · halfWidth` and `u = s mod period`, multiply `a` by `smoothstep(0, 0.25·halfWidth, u) · (1 − smoothstep(dash·halfWidth − 0.25·halfWidth, dash·halfWidth, u))`. `phase = across`.
     - Composite over the old values: `r' = a + (1 − a)·r`, `g' = a·phase + (1 − a)·g`.
     - Add each piece's arc to `stroke.distance`, set `stroke.last = point`, upload the dirty rectangle and increment `revision`.
   - **`func stamp(_ stamp: MarkStamp, at center: SIMD3<Double>)`.** For `.rings(radius, spacing)`, for each texel with angular distance `r < radius`: `a = 1 − smoothstep(radius − 0.15·spacing, radius, r)` and `phase = r / spacing`. Composite over, upload, and increment `revision`.
   - **`func reset()`.** Zero the touched rows, upload them, and increment `revision`.
   - Mirror SnowCover's row and column iteration, longitude wrap, dirty-rect bookkeeping and `texture.replace` upload. Do not share code with or modify `SnowCover`.
2. **SceneLook.swift.** `MeshLook` gains `let marks: MarkSettings?` and an init parameter `marks: MarkSettings? = nil` placed after `snow`.
3. **GlobeShared.h.** Add `struct MarkTap { float coverage; float phase; };` and `static inline MarkTap markTap(texture2d<float> markTexture, sampler markSampler, float2 uv, gradient2d gradient)`. It returns `coverage = sample.r` and `phase = sample.g / max(sample.r, 1e-4)`, with phase 0 where coverage is 0.
4. **GlobeRenderer.swift.** Add `let markMap: MarkMap?`, created in `init` next to `snowCover`. In `encodeMesh`, bind `markMap?.texture ?? placeholder` at fragment texture index 6 alongside the other terrain textures. No existing fragment declares `texture(6)`, so their output does not change.
5. **GlobeFrame.swift.** Add `var marks = 0` after `petals`.
6. **SceneModel.swift.**
   - Add `private(set) var marksRevision = 0`, which is observed, and `@ObservationIgnored private var markStroke: MarkStroke?`.
   - `allowsSurfaceDrag` is also true when `mesh.marks != nil`. Marks are drawing, like snow, so Reduce Motion keeps them.
   - **`beginSurfaceDrag`:** when `style.mesh?.marks` is set, `markStroke = MarkStroke(halfWidth: footprint * marks.width)` before the existing call into `dragSurface`.
   - **`dragSurface`:** when marks are set and `point` is non-nil, call `renderer?.markMap?.sweep(to: point, stroke: &markStroke, brush: marks.drag)` (unwrap `markStroke` safely), then `marksRevision = markMap.revision`. When `point` is nil, set `markStroke?.last = nil`, so a stroke that leaves the globe restarts cleanly.
   - **`endSurfaceDrag`:** `markStroke = nil`.
   - **`pop(at:)`:** when `style.mesh?.marks?.pop` is set, stamp at the point before the Reduce Motion guard, then update `marksRevision`.
   - **`resetDisturbance()`, and `isForeground` becoming false:** call `renderer?.markMap?.reset()`, set `markStroke = nil`, and update `marksRevision`.
7. **GlobeScene.swift.** Pass `marks: scene.marksRevision` into the `GlobeFrame` it builds, so a stroke redraws even when no effect record changes.

## Constraints

- Existing themes must render, sound and feel exactly as before. No existing look file changes. `SnowCover` is untouched.
- New parameters and fields are defaulted, so existing call sites and the offline harness compile unchanged.
- `MarkMap` must not import UIKit or SwiftUI.
- Write no comments anywhere: no `//`, `/* */` or `///`, in Swift or Metal. Names carry the meaning.
- Brace every control-flow body, keeping the codebase's one-line `guard … else { return }` form. Use 4-space indentation and `private` helpers, and avoid force unwraps.
- Helpers in `GlobeShared.h` are `static inline`, like their neighbours.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=ice .claude/duck/scene-style/harness/render.sh fx-rest fx-snow`

## Manual review

- **Simulator, Ice.** Hold then drag still carves the snow, which refills.
- **Simulator, Toy.** Hold then drag still pulls the dent.
- **Theme switching.** It works as before.
- **Nothing new is visible yet.** No theme declares `marks` until `.tasks/04-theme-garden.md` and `.tasks/06-theme-knit.md`.

## Out of scope

- Any theme that uses marks.
- Saving marks across launches.
- Changes to `SnowCover` or the Ice carve.
- Mipmaps for the mark texture.

## Open questions

none
