# Task: Add the Mosaic theme — ceramic tiles that turn over in waves

## Goal

A new theme, Mosaic (raw value `mosaic`, last in the theme tray), renders the globe in Mediterranean ceramic mosaic:

- irregular glazed shards on the undulating `.puffy` shape (Gaudí's trencadís);
- cobalt, turquoise and white glass in the sea, with two rows of white tiles laid along every coast;
- ochre, orange, olive and lemon glaze on land, with a few gold tiles that catch city lights at night;
- grout lines between tiles;
- a terracotta wall backdrop with scattered white shards;
- city chips styled as azulejo street-sign tiles, which flip edge-on when selected.

Interactions turn tiles over:

- **City tap.** A wave of tiles flips outward from the city, with a click cascade synchronised to it and a matching haptic rattle.
- **Press.** Tilts the tiles under the finger into a funnel.
- **Hold then drag.** Flips tiles to their terracotta backs. They flip back one by one, each at its own moment.
- **Fling.** Rattles every tile into a sparkle.
- **Theme switch.** Assembles the mosaic in a wave.
- **Sounds.** Ceramic clicks, a plate clonk at midnight, and castanets on back-to-now.

## Prerequisite

`.tasks/01-feedback-cues.md` has landed, so `SoundSequence` (with haptic-only entries) and `SceneLook.popEcho` exist, and `FeedbackPlayer` plays a pop's echo. If they are missing, stop: this spec builds on them. The mark map is not needed.

## Files

- tokei/Globe/Looks/MosaicLook.swift (create)
- tokei/Globe/Shaders/Mosaic.metal (create)
- tokei/Globe/Looks/MosaicSound.swift (create)
- tokei/Globe/Looks/MosaicInterface.swift (create)
- tokei/Interface/MosaicSwatch.swift (create)
- tokei/Globe/SceneStyle.swift (modify)
- tokei/Globe/Looks/InterfaceLook.swift (modify)
- tokei/Globe/Looks/ChipLook.swift (modify)
- tokei/Globe/MarkerChip.swift (modify)
- tokei/Globe/ChipMetrics.swift (modify)
- tokei/Globe/Looks/SwatchLook.swift (modify)
- tokei/Interface/ThemeSwatch.swift (modify)
- tokei/Feedback/FeedbackCue.swift (modify)
- tokei/Globe/Looks/MagmaLook.swift, tokei/Globe/Shaders/Magma.metal (read: `magmaCell`, `magmaPoint`, `magmaSite`, `magmaWrap`, `magmaCos`, and the ripple block), tokei/Globe/Looks/MagmaSound.swift, tokei/Globe/Looks/MagmaInterface.swift, tokei/Interface/MagmaSwatch.swift (read: the newest complete theme to mirror)
- tokei/Globe/Shaders/GlobeShared.h (read)

## Context

### Theme anatomy

- **Registration.** A theme is one `SceneStyle` case plus the files it owns. Register it in:
  - `SceneStyle.look` (`tokei/Globe/SceneStyle.swift`);
  - `SceneStyle.interface` (`tokei/Globe/Looks/InterfaceLook.swift`);
  - `ChipMetrics.fonts(for:)`, together with a `private static let <name>Fonts` (`tokei/Globe/ChipMetrics.swift`);
  - `SwatchLook.Finish`, plus the `drawFinish` and `drawRim` switches in `tokei/Interface/ThemeSwatch.swift`.

  The tray lists `SceneStyle.allCases`. Raw values are persisted under `scene_style`, so a new case goes last and no existing case is renamed.
- **Pipelines.** `GlobeRenderer.init` builds a pipeline for every `MeshLook.fragment` and `background` name across all styles. A missing or misspelt Metal function makes the whole renderer return nil.
- **`SceneLook`** fields: `name`, `backdrop` (linear `SIMD3<Float>`), `accent`, `effects`, `sound`, `mesh`, `petalDrift`, `popEcho`.
  - `MeshLook(fragment:background:shape:parameters:snow:)` binds the parameter struct at fragment and background `buffer(1)`.
  - `snow: SnowSettings(recovery:footprints:)` enables the existing disturbance map. With `footprints: false`, a hold-then-drag carves a trail that refills over `recovery` seconds, but press and pop leave no footprint.
- **Parameter struct.**
  - Only `SIMD4<Float>` colour fields and `Float` fields, mirrored in order in the `.metal` struct.
  - The `Float` count must be a multiple of 4; pad with `reserved` fields.
  - Colours are written as sRGB hex through `.linear(0xRRGGBB)`.
- **Interface colours.** Interface files use `Color(hex:)` and `InterfaceLook.legibleInk(on:dark:light:)`. Swatch colours copy palette values.
- **Chips.** `MarkerOverlay` positions each chip and disables animation on positions (`.transaction { $0.animation = nil }`). A chip must never move. Rotation and scale effects anchored at the centre are fine.
  - `ChipLook` (`tokei/Globe/Looks/ChipLook.swift`) is a struct of chip styling with defaulted `var`s.
  - `MarkerChip` renders a chip, with `isSelected` true for the selected city.

### Mesh fragment contract

- **Slots.**
  - `buffer(0)`: `GlobeUniforms`. `principal.z` is the reveal fade.
  - `buffer(1)`: the parameter struct.
  - `buffer(2)`: `EffectUniforms`.
  - `texture(1)`: city lights.
  - `texture(2)`: coast signed distance in degrees, positive on land.
  - `texture(3)`: relief. xyz is the normal (normalise after sampling) and w the relief level.
  - `texture(4)`: the snow disturbance map. A texel holds a time; `saturate((clock − value) / recovery)` is its refill level from 0 to 1, where 1 is undisturbed.
  - `sampler(0)`: the surface sampler.
- **Preamble.** Copy it from `magmaFragment`, including the snow block that reads `effects.state.w` as `clock`.
- **Sampling rules.**
  - Sample with the explicit gradients computed before any branch. Calls to `dfdx`, `dfdy` and `fwidth` must not sit inside divergent branches.
  - Samples taken with an explicit level, such as `level(0.0)` at a tile centre, are safe inside branches.
- **Day and night.**
  - Gates use `nG` only: `daylight = smoothstep(-tw, tw, muG)`, `nightGate = 1 - smoothstep(-0.14, 0.04, muG)`.
  - The city-light texture is used only on the night side.
- **Ending.** End with `color = mix(look.backdrop.xyz, color, uniforms.principal.z); return finishColor(color, pixel);`. Do not add gamma.
- **No idle animation.** Nothing animates on its own clock. Every motion here is a pure function of `EffectUniforms`, the camera and the sun.
- **`EffectUniforms` lanes.**
  - `dent`: xyz is the press centre; w is `dentDepth × pressAmount`.
  - `bump`: xyz is the pop centre.
  - `radii`: x dent radius, y bump radius, w inflate (rises from 0 to 1 on theme switch; 1 at rest).
  - `ripple`: xyz origin; w age, which is negative when there is none.
  - `wave`: w is the ripple speed in radians per second.
  - `state`: x ripple decay, z dent shade, w snow clock (0 when there is no snow).
  - `shapeX/Y/Z`: the squash and stretch matrix (identity at rest). A fling stretches it.

  Use `effectsActive(effects)` before reading any lane. Helpers: `effectWeight`, `effectOffset`.
- **Background fragment.** Signature `(FullscreenVertex in [[stage_in]], constant GlobeUniforms &uniforms [[buffer(0)]], constant <Look> &look [[buffer(1)]])`. Use `globeRay`, `globeDisk` and `backdropPoint` (world-anchored scatter, which gives parallax).
- **Offline harness.** `.claude/duck/scene-style/harness` (gitignored, present in this working copy) compiles everything under `tokei/Globe` on macOS, except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and some views. New files under `tokei/Globe` must not import UIKit.

### Sound and haptics

- **When cues fire.**
  - `.pop`: on city selection.
  - `.press`: at touch-down on the globe.
  - `.release`: after a deliberate press.
  - `.carve`: every `drag.grainSpacing` points of drag travel.
  - `.tick` and `.dayTick`: on tape hour crossings.
  - `.snap`: on the glide back to now.
  - `.inflate`: on selecting the theme.
- **Layers.** `Tone`, `Wash` (band-passed noise, optional `sweep`), `Grains` and `Ring`, as in `MagmaSound`.
  - `Grains(rise:fall:density:…)` has an envelope: sin² up over `rise`, then exponential decay over `fall`.
  - A `Design` has a loudness `level` and a high-pass `floor`.
- **Pop echo and pop haptic.** `SceneLook.popEcho` is played with every pop; its entries may carry only a `HapticTick`. `FeedbackCue.popHaptic` maps a style to its pop impact.
- **Reference facts.**
  - Modes of a thin free square plate are at 1 : 1.455 : 1.802 : 2.584 of the fundamental.
  - Opus vermiculatum lays rows of tesserae along the outline of a figure, forming a halo; open ground is laid in plain rows (opus tessellatum).

## Plan

1. **SceneStyle.swift.** Add `case mosaic` as the last case, and `case .mosaic: .mosaic` in `look`.
2. **MosaicLook.swift.**
   - **`struct MosaicLook`.** Fields, in this order, with these `standard` values:
     - Colours:
       - backdrop and grout: `backdrop` `0xA84A2F`, `backdropShade` `0x7E3420`, `shard` `0xF2EEE6`, `grout` `0xD8D1C3`, `groutNight` `0x2A2622`
       - sea: `cobalt` `0x1F4FA8`, `turquoise` `0x2FA5B5`, `seaWhite` `0xEEF3F4`
       - land: `ochre` `0xD99A2B`, `orange` `0xE0662E`, `olive` `0x7C8A2E`, `lemon` `0xE9CF4A`, `gold` `0xD8A93B`
       - other: `terracottaBack` `0xB5603A`, `nightGlaze` `0x141A2A`, `cityLight` `0xFFC27A`, `twilight` `0xF0A070`
     - Floats:
       - tiles: `tileSize` 2.7 (degrees), `tileTilt` 0.1, `glazeGloss` 300, `glazeSpec` 0.5, `groutWidth` 0.06 (fraction of a tile), `coastRow` 0.9 (degrees)
       - gold: `goldChance` 0.04, `goldGloss` 900
       - flips and press: `flipTime` 0.25 (seconds), `flipJitter` 0.08 (seconds), `funnel` 0.35, `pressDepth` 0.012 (always equal to `EffectTuning.mosaic.press.dentDepth`), `recovery` 4, `flipThreshold` 0.25, `flipSpread` 0.5, `rattle` 0.6, `inflateSpan` 1.1
       - light: `terminatorWidth` 0.02, `cityGlow` 0.8
       - backdrop: `shardCells` 30, `shardChance` 0.15, `shardSize` 5 (pixels at 1206 px width), `vignette` 0.25

       That is 24 floats.
   - **`SceneLook.mosaic`.**
     - `name` "Mosaic"; `backdrop: MosaicLook.standard.backdrop.xyz`.
     - `accent: Color(red: 0.12, green: 0.31, blue: 0.66)`; `effects: .mosaic`; `sound: .mosaic`.
     - `mesh: MeshLook(fragment: "mosaicFragment", background: "mosaicBackground", shape: .puffy, parameters: MosaicLook.standard, snow: SnowSettings(recovery: Double(MosaicLook.standard.recovery), footprints: false))`.
     - `popEcho: MosaicSound.cascadeHaptics`.
   - **`EffectTuning.mosaic`.**
     - `press`: `dentDepth` 0.012, `dentRadius` 0.12, `dentShade` 2, `frost` 0, `cracks` 0, `squash` 0.004, `pressSpring: Spring(duration: 0.16, bounce: 0)`, `releaseSpring: Spring(duration: 0.28, bounce: 0.15)`.
     - `pop`: `height` 0.006, `radius` 0.04, `glow` 0, `spring: Spring(duration: 0.4, bounce: 0.2)`.
     - `ripple`: `tilt` 0, `landShare` 1, `flash` 0, `displacement` 0, `wavelength` 0.06, `speed` 0.5, `decay` 2.0, `duration` 2.4.
     - `fling`: `stretchPerSpeed` 0.004, `maximumStretch` 0.02, `spring: Spring(duration: 0.45, bounce: 0.25)`.
     - `flightArc` 0.5; `inflate: Spring(duration: 1.4, bounce: 0.1)`.
     - `drag: .init(follow: Spring(duration: 0.16, bounce: 0.2), trailWidth: 1.2, trailHold: 0.5, grainSpacing: 10, grainSharpness: 0.7)`.
3. **Mosaic.metal.**
   - Add `struct MosaicLook`, mirroring the Swift struct.
   - Copy `magmaCell` and its helpers into this file as `mosaicCell` (and `mosaicPoint`, `mosaicSite`, `mosaicWrap`, `mosaicCos`), with `rows = 180 / tileSize`.
     - It returns the cell edge distance, the in-plane offset `away` from the cell's site, and a stable id. Rebuild the site's direction from its latitude and longitude, using longitude = atan2(x, z).
     - Do not edit Magma.metal: its output must not change.
   - **`mosaicFragment`.** The buffers and textures are those of `magmaFragment`, including `snowTexture [[texture(4)]]`.
     1. **Hoisted.** The preamble, the relief normal `nM` (mixed by inflate as Magma does), and the tile cell at `nG`. Also `tilePixels = (tileSize in radians) / pixelAngle`; `detail = smoothstep(3, 6, tilePixels)` fades grout and per-tile tilt so small tiles don't shimmer.
     2. **Regions, per pixel**, from the coast distance `d`:
        - land when `d > 0`;
        - two coast rows on the sea side, `0 > d > −coastRow` and `−coastRow > d > −2·coastRow`;
        - open sea beyond.

        Tiles crossing a boundary are cut along it, as real mosaics cut tiles to an outline. Grout runs where the lattice edge is under `groutWidth` of a tile, and along the coastline and row boundaries. Antialias it with `fwidth`, computed in the hoisted block.
     3. **Tile colour**, from a hash of the cell id and the region.
        - Land picks ochre, orange, olive or lemon; `goldChance` makes it gold.
        - Open sea picks cobalt, turquoise, cobalt or `seaWhite`.
        - Coast rows are `seaWhite`, the second row slightly bluer.
        - Tone jitter ±8 %.
     4. **Tile normal.** `nM` tilted by up to `tileTilt` in a random direction in the tile's tangent frame, scaled by `detail`.
     5. **Effects, per tile**, using the tile centre `c` and only when effects are active. All of this is shading only.
        - **Flip wave.**
          - When `ripple.w ≥ 0`: `arrival = acos(dot(c, ripple.xyz)) / wave.w + flipJitter·hash`.
          - `s = saturate((ripple.w − arrival) / flipTime)`; the flip angle is `2π · smoothstep(0, 1, s)`.
        - **Drag flips.**
          - When the snow clock `state.w > 0`: the level `L` at the tile centre is `saturate((clock − snowTexture.sample(sampler, uv(c), level(0.0)).r) / recovery)`, and the tile's threshold is `θ = flipThreshold + flipSpread·hash`.
          - The flip angle is `π · (1 − smoothstep(θ − 0.04, θ + 0.04, L))`, so tiles flip back one by one as the trail refills.
        - **Inflate assembly.**
          - With `front = inflateSpan · π · radii.w` and `ac = acos(dot(c, normalize(cameraPosition.xyz)))`, the flip angle is `π · (1 − smoothstep(ac, ac + 0.3, front))`. Tiles turn face-up as the front sweeps out from the view centre.
        - **Combining.** Sum the three angles into `φ`. Each tile has a hashed flip axis, east or north.
          - The tile's visible half-width along the axis is `abs(cos φ)`. Pixels whose `away` along the axis lies beyond it show the dark grout bed.
          - The face is glaze while `cos φ ≥ 0`, else the matte `terracottaBack`.
          - The normal rotates by `φ` about the axis, so each tile glints once.
        - **Funnel.** Tilt the tile normal toward `dent.xyz` by `funnel · effectWeight(c, dent.xyz, radii.x) · saturate(dent.w / pressDepth)`.
        - **Rattle.** `stretch = abs(shapeX.x − 1) + abs(shapeY.y − 1) + abs(shapeZ.z − 1)`. Jitter each tile's normal by `rattle · stretch · (hash − 0.5)`.
     6. **Shading.**
        - Glaze: Lambert plus a specular term `pow(saturate(dot(reflect(−view, n), sun)), glazeGloss) · glazeSpec · daylight`. Gold uses `goldGloss` and a gold-tinted specular.
        - The back side and the grout are matte; the grout is recessed (×0.85).
        - Night: mix glaze toward `nightGlaze` and grout toward `groutNight` by `1 − daylight`, with a warm `twilight` band.
        - City lights: sample lights at the tile centre with `level(0.0)`. Land tiles emit `cityLight · lights · cityGlow · 0.25 · nightGate`, gold tiles at ×4, so cities read as clusters of warm tiles.
     7. **Dent, then finish.** Darken the dent as Magma does, mix with the backdrop by `principal.z`, then `finishColor`.
   - **`mosaicBackground`.**
     - `backdrop`, darkened toward `backdropShade` by `vignette` across the screen.
     - Shards from `backdropPoint(direction, shardCells, 5.0, focal)` with `random.x < shardChance`: a small irregular quad (four jittered corners, a random rotation, about `shardSize · viewport.x / 1206` pixels) in `shard`, with a one-pixel darker edge.
     - Mix with `principal.z`, then `finishColor`.
4. **MosaicSound.swift.**
   - **Timbre.** `extension SoundTimbre { static let mosaic = SoundTimbre(id: "mosaic", variants: [.press: 10, .pop: 8, .release: 8]) { kind, random in MosaicSound.design(for: kind, random: &random) } }`.
   - **Tile click helper.** A `Ring` at f·[1, 1.455, 1.802, 2.584] with decays [0.02, 0.012, 0.009, 0.006] s (each ×0.85…1.15) and gains [1, 0.5, 0.35, 0.2], plus a 0.3 ms `Wash` at 7 kHz (gain 0.3).
   - **Designs.**
     - `.pop`, the cascade.
       - A tile click at 3.2 kHz at 0.
       - `Grains` at 0.03 s: rise 0.45, fall 0.5, density 260, band 2000…5000, cycles 3…6, resonance 4, grit 1.5, gain 0.8. Its envelope follows the number of tiles the front crosses: the front's circumference grows as sin(v·t) while the ripple decays as e^(−decay·t), peaking at atan(v / decay) / v ≈ 0.49 s for this tuning.
       - A 400 Hz `Wash` (attack 0.003, decay 0.03, gain 0.25) under it.
       - Level −20.
     - `.press`, a clack. 2–3 tile clicks at 1.8–3 kHz within 15 ms, plus a 220 Hz mortar thump `Wash` (20 ms). Level −21.
     - `.release`, "tikitikitik". 5–8 tile clicks at accelerating offsets within 120 ms, with falling gain. Level −25.
     - `.carve`. One tile click at 2–3.5 kHz plus a small knock. Level −26.
     - `.tick`. A tile click at 3.5–4.5 kHz with decays ×0.5. Level −31.
     - `.dayTick`, a plate clonk. Plate partials from about 700 Hz with decays 0.06–0.15 s, plus a knock. Level −22.
     - `.snap`, castanets. 2–3 clicks 20–30 ms apart, each a `Ring` at 2.2 and 3.4 kHz (8 ms) over a 1.2 kHz `Wash` (5 ms). Level −20.
     - `.inflate`, assembling.
       - `Grains`: rise 0.5, fall 0.15, density 400, band 2000…5000, cycles 3…6, resonance 4, gain 0.7.
       - Three tuned tiles at 0.55, 0.62 and 0.70 s, at 2100, 2650 and 3150 Hz, with decays ×4.
       - Level −20.
   - **`static let cascadeHaptics: SoundSequence`.** Eight haptic-only entries (`design` nil), computed once from the same envelope.
     - With `v = EffectTuning.mosaic.ripple.speed` and `decay = EffectTuning.mosaic.ripple.decay`, sample `D(t) = sin(min(v·t, π)) · e^(−decay·t)` on 240 steps over the ripple duration.
     - Place tick `k` where the cumulative integral crosses `(k + 0.5) / 8`.
     - Intensity `0.3 + 0.4 · D(t_k) / max D`, sharpness 0.75.
5. **MosaicInterface.swift.** `InterfaceLook.mosaic`:
   - `colorScheme: .dark`; `ink` `0xFBF6EE`; `secondaryInk` `0xF0D9C8`.
   - `typography`: `design` `.serif`, `titleWeight` `.semibold`, `captionCase` `.uppercase`, `captionTracking` 1.4.
   - `panel: .raised(fill: Color(hex: 0x8E3D26), base: Color(hex: 0x5E2716), depth: 3, edge: .white.opacity(0.25))`; `panelCorner` 18.
   - `control: .raised(fill: Color(hex: 0x9C4429), base: Color(hex: 0x5E2716), depth: 2, edge: .white.opacity(0.2))`.
   - `accentSurface: .raised(fill: accent, base: Color(hex: 0x14336E), depth: 2, edge: .white.opacity(0.4))`; `onAccent: .white`.
   - `sheet: Color(hex: 0x7A3320)`.
   - `chip`, as an azulejo sign:
     - `name` serif 13 bold with `uppercasedName: true`; `time` serif 13 semibold with monospaced digits; `detail` serif 11 regular;
     - `corner` 4;
     - `surface: .solid(fill: Color(hex: 0xF7F4EE).opacity(0.97), edge: accent)`;
     - `nameColor` `0x1F4FA8`, `timeColor` `0x3C5A8C`, `detailColor` `0x6B7FA6`;
     - `selectedSurface: .solid(fill: accent, edge: .white)`, `selectedInk: .white`, `shiftedTimeColor` `0xE0662E`;
     - `flipsOnSelect: true`.
   - `bead`: cobalt.
   - `tape`: `tick: ink`, `label: secondaryInk`, `labelDesign: .serif`, `hourWidth` 2, `quarterWidth` 1.2, `squareCaps: true`, `needle: .capsule`.
   - `swatch: SwatchLook(ocean: Color(hex: 0x1F4FA8), land: Color(hex: 0xD99A2B), night: Color(hex: 0x141A2A).opacity(0.5), rim: Color(hex: 0xF2EEE6), finish: .tiles)`.
6. **ChipLook.swift and MarkerChip.swift.**
   - Add `var flipsOnSelect = false` to `ChipLook`.
   - In `MarkerChip`, when `chip.flipsOnSelect` is true, add `.keyframeAnimator(initialValue: 0.0, trigger: isSelected)`. It applies `rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0))` with keyframes: a cubic to 90° over 0.12 s, then back to 0 over 0.16 s.
   - The chip turns edge-on and back in place while its content swaps. Its position never changes. When the flag is false, nothing changes.
7. **Registration.**
   - `InterfaceLook.swift`: `case .mosaic: .mosaic`.
   - `ChipMetrics.swift`: `mosaicFonts` and its switch case.
   - `SwatchLook.swift`: `Finish.tiles`.
   - `ThemeSwatch.swift`: `.tiles` in `drawFinish` → `MosaicSwatch.finish(…)`, and in `drawRim` → `MosaicSwatch.rim(…)`.
   - `FeedbackCue.swift`: `case .mosaic: .impact(flexibility: .rigid, intensity: 0.6)` in `popHaptic`.
8. **MosaicSwatch.swift.** `enum MosaicSwatch` with:
   - `finish`: a fixed set of about 30 small jittered quads across the sphere, alternating `look.ocean` lightened and white at 0.35 opacity, with thin grout strokes;
   - `rim`: a 1-unit ring in `look.rim`.

## Constraints

- Do not change any other theme's files, output, sounds or haptics. `Magma.metal` is read, not edited.
- Do not rename existing `SceneStyle` raw values.
- Shading only. Flips, the funnel, the rattle and the assembly never move geometry; only the existing dent, bump and stretch formulas do. Chips therefore stay on their cities.
- The chip flip is a rotation in place; positions are never animated.
- With Reduce Motion, effect records are not created, so no flips run. That is the intended behaviour.
- Write no comments anywhere: no `//`, `/* */` or `///`, in Swift or Metal. Names carry the meaning.
- Brace every control-flow body, keeping the codebase's one-line `guard … else { return }` form.
- Use 4-space indentation. Metal helpers are `static` inside `Mosaic.metal`.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=mosaic .claude/duck/scene-style/harness/render.sh fx-rest fx-pop-london fx-ripple-late fx-press-held fx-inflate-early`

## Manual review

1. **Harness renders.** Run `STYLE=mosaic .claude/duck/scene-style/harness/render.sh` with no scene names, then open its `sheet.png`. Check that:
   - tiles read clearly at the default zoom and the white coast rows hug the coasts;
   - the grout doesn't shimmer when zoomed out;
   - a ring of flipping tiles shows in `fx-pop-london` and `fx-ripple-late`;
   - `fx-inflate-early` shows a partly assembled mosaic.
2. **Simulator.**
   - Select Mosaic: tiles assemble in a wave with a rising cascade.
   - Tap a city: a flip wave spreads with a click cascade that swells and thins, and the azulejo chip flips edge-on.
   - Press: tiles funnel. Hold then drag: a clean path of terracotta backs, which flip back tile by tile over about 4 s.
   - Fling: a sparkle rattle.
   - Tape: tile ticks, a plate clonk at midnight, castanets on back-to-now.
3. **Device only.** The haptic rattle on a city tap follows the cascade.

## Out of scope

- Moving tiles geometrically.
- Petals or particles.
- Changes to the snow map, `SceneModel` or other themes.
- Persisting anything new.

## Open questions

none
