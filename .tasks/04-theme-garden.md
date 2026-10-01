# Task: Add the Garden theme — a karesansui dry garden you rake

## Goal

A new theme, Garden (raw value `garden`, last in the theme tray), renders the globe as a Japanese dry landscape garden:

- **Sea.** Raked white gravel. Concentric rings follow every coastline, then turn into straight lines along the parallels in open water.
- **Land.** Velvety moss mounds with granite outcrops on high relief, edged by dark pebbles.
- **Night.** The gravel goes silver-blue under moonlight.
- **Backdrop.** An earthen wall, warm tan with soft stains.

The interactions:

- **Hold then drag.** Rakes five parallel grooves along the finger. Grooves cut through older ones and stay until the theme changes or the app is backgrounded.
- **City tap.** Stamps a small raked clearing with rings around the city, which also stays.
- **Press.** Bends the rings around the finger.
- **Theme switch.** Reveals the rings outward from every coast.
- **Sounds.** Gravel, bamboo and water. A gravel crunch on gravel or a muffled pat on moss, raking scrapes, a bamboo tick per hour, a shishi-odoshi knock at midnight, hyoshigi clappers on back-to-now, and a suikinkutsu drip when the theme is selected.

## Prerequisite

`.tasks/01-feedback-cues.md` and `.tasks/02-mark-map.md` have both landed. The following exist:

- `CueContext`, including `surface`, and the design-based `SoundTimbre` init with trailing `contextual:`;
- `MarkMap`, `MarkSettings`, `MarkBrush.grooves(tines:)` and `MarkStamp.rings(radius:spacing:)`;
- `MeshLook(…, marks:)`;
- `MarkTap` and `markTap(...)` in `GlobeShared.h`;
- the mark map bound at mesh fragment `texture(6)`.

If any of these is missing, stop: this spec builds on them.

## Files

- tokei/Globe/Looks/GardenLook.swift (create)
- tokei/Globe/Shaders/Garden.metal (create)
- tokei/Globe/Looks/GardenSound.swift (create)
- tokei/Globe/Looks/GardenInterface.swift (create)
- tokei/Interface/GardenSwatch.swift (create)
- tokei/Globe/SceneStyle.swift (modify)
- tokei/Globe/Looks/InterfaceLook.swift (modify)
- tokei/Globe/ChipMetrics.swift (modify)
- tokei/Globe/Looks/SwatchLook.swift (modify)
- tokei/Interface/ThemeSwatch.swift (modify)
- tokei/Feedback/FeedbackCue.swift (modify)
- tokei/Globe/Looks/MagmaLook.swift, tokei/Globe/Shaders/Magma.metal, tokei/Globe/Looks/MagmaSound.swift, tokei/Globe/Looks/MagmaInterface.swift, tokei/Interface/MagmaSwatch.swift (read: the newest complete theme to mirror)
- tokei/Globe/Looks/SakuraInterface.swift (read: a light-scheme interface)
- tokei/Globe/Shaders/Sakura.metal (read: `sakuraCell`, a jittered latitude-band lattice)
- tokei/Globe/Shaders/GlobeShared.h, tokei/Globe/MarkMap.swift (read)

## Context

### Theme anatomy

- **Registration.** A theme is one `SceneStyle` case plus the files it owns. Register it in:
  - `SceneStyle.look` (`tokei/Globe/SceneStyle.swift`);
  - `SceneStyle.interface` (`tokei/Globe/Looks/InterfaceLook.swift`);
  - `ChipMetrics.fonts(for:)`, together with a `private static let <name>Fonts` (`tokei/Globe/ChipMetrics.swift`);
  - `SwatchLook.Finish`, plus the `drawFinish` and `drawRim` switches in `tokei/Interface/ThemeSwatch.swift`.

  The tray lists `SceneStyle.allCases`. Raw values are persisted under `scene_style`, so a new case goes last and no existing case is renamed.
- **Pipelines.** `GlobeRenderer.init` builds a pipeline for every `MeshLook.fragment` and `background` name across all styles. A misspelt or missing Metal function makes the whole renderer return nil, and the globe disappears in every theme.
- **`SceneLook`** fields: `name`, `backdrop` (linear `SIMD3<Float>`), `accent` (`Color`), `effects` (`EffectTuning`), `sound` (`SoundTimbre?`), `mesh` (`MeshLook?`), `petalDrift`, `popEcho`.
  - `MeshLook(fragment:background:shape:parameters:marks:)` carries the parameter struct as raw bytes, bound at fragment and background `buffer(1)`.
  - `.puffy` is the existing soft-mound shape that Toy, Sakura and Weather use.
- **Parameter struct.**
  - Only `SIMD4<Float>` colour fields and `Float` fields, mirrored in the same order in the `.metal` struct.
  - The number of `Float` fields must be a multiple of 4 (pad with `reserved` fields defaulting to 0). Otherwise the Swift and Metal sizes differ.
  - Colours are written as sRGB hex through `.linear(0xRRGGBB)`.
- **Interface colours.** Interface files use `Color(hex:)` and `InterfaceLook.legibleInk(on:dark:light:)`. Swatch colours copy palette values.

### Mesh fragment contract

- **Slots.**
  - `buffer(0)`: `GlobeUniforms`. `principal.z` is the reveal fade.
  - `buffer(1)`: the parameter struct.
  - `buffer(2)`: `EffectUniforms`.
  - `texture(1)`: city lights.
  - `texture(2)`: coast signed distance in degrees, positive on land.
  - `texture(3)`: relief. xyz is the normal (normalise after sampling) and w the relief level.
  - `texture(6)`: marks (r is coverage, g is the premultiplied phase). Read it with `markTap`.
  - `sampler(0)`: the surface sampler.
- **Preamble.** Copy it from `magmaFragment`: `pixel`, `direction` (with `effectUnshape`), `view`, `sun`, `nG`, `coordinates = surfaceCoordinates(nG)`, `muG`, `pixelAngle`, `gradient2d gradient`, the relief, coast and lights samples, `coastCoverage`.
- **Sampling rules.**
  - Sample with the explicit gradients computed before any branch. Calls to `dfdx`, `dfdy` and `fwidth` must not sit inside divergent branches.
  - Samples taken with an explicit gradient or level are safe inside branches.
- **Day and night.**
  - Gates use `nG` only: `daylight = smoothstep(-tw, tw, muG)`, `nightGate = 1 - smoothstep(-0.14, 0.04, muG)`.
  - Moonlight comes from the antisolar direction `−sun`, an art term like the realistic theme's moonlight.
- **Ending.** End with `color = mix(look.backdrop.xyz, color, uniforms.principal.z); return finishColor(color, pixel);`. Do not add gamma.
- **No idle animation.** Nothing animates on its own clock. Motion comes only from `EffectUniforms`, the camera, the sun and the mark map, which changes only under a finger.
- **`EffectUniforms` lanes.**
  - `dent`: xyz is the press centre (it follows a hold-then-drag); w is `dentDepth × pressAmount`.
  - `bump`: xyz is the pop centre.
  - `radii`: x dent radius, y bump radius, z pop glow, w inflate (rises from 0 to 1 on theme switch; 1 at rest).
  - `ripple`: xyz origin; w age, which is negative when there is none.
  - `wave`: w is the ripple speed.
  - `state`: x ripple decay, z dent shade.

  Use `effectsActive(effects)` before reading any lane. Helpers: `effectWeight`, `effectOffset`.
- **Background fragment.** Signature `(FullscreenVertex in [[stage_in]], constant GlobeUniforms &uniforms [[buffer(0)]], constant <Look> &look [[buffer(1)]])`. Use `globeRay`, `globeDisk` and `backdropPoint` (world-anchored cells, so the pattern shifts with the camera: parallax for free).
- **Offline harness.** `.claude/duck/scene-style/harness` (gitignored, present in this working copy) compiles everything under `tokei/Globe` on macOS, except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and some views. New files under `tokei/Globe` must not import UIKit.

### Marks, sound and haptics

- **What `marks:` already does.** With `marks:` set on the `MeshLook`, `SceneModel` handles everything:
  - a hold-then-drag sweeps the drag brush into the map;
  - a city pop stamps `marks.pop`;
  - style changes and backgrounding reset the map;
  - frames redraw on each mark change, also under Reduce Motion.

  The theme only declares the settings and shades the map.
- **Mark values.** For `.grooves(tines: n)` the phase runs across the stroke from −n/2 to n/2, so `cos(2π·phase)` gives `n` grooves parallel to the path. For `.rings` the phase is the angular distance from the centre divided by `spacing`.
- **Cues.**
  - The press cue arrives with `CueContext(surface: .land / .sea)` from the coast under the finger.
  - `.carve` fires every `drag.grainSpacing` points of drag travel, with volume rising with speed.
  - The other kinds:
    - `.tick` and `.dayTick` on tape hour crossings;
    - `.release` on a deliberate press;
    - `.pop` on city selection;
    - `.snap` on the glide back to now;
    - `.inflate` on selecting the theme.
- **Layers.** `Tone`, `Wash` (band-passed noise, optional `sweep`), `Grains` and `Ring` (modal partials with an optional `beat`), as used in `MagmaSound`. A `Design` has a loudness `level` and a high-pass `floor`.
- **Pop haptic.** `FeedbackCue.popHaptic` maps a style to its pop haptic.
- **Reference facts.**
  - In karesansui, rings around rocks (mizu-mon) are ripples around islands, and straight parallels (sazanami-mon) are open sea.
  - The shishi-odoshi strike shows peaks near 260, 550 and 790 Hz and dies out in about 100 ms.
  - Hyoshigi are paired hardwood blocks clapped twice ("kachi-kachi") by fire-watch patrols.
  - Suikinkutsu jars ring with modes near 850, 1375, 1650, 1900, 2250 and 2863 Hz, with a reverberation of 1–2 s, excited by the bubble of a falling drop.

## Plan

1. **SceneStyle.swift.** Add `case garden` as the last case, and `case .garden: .garden` in `look`.
2. **GardenLook.swift.**
   - **`struct GardenLook`.** Fields, in this order, with these `standard` values:
     - Colours:
       - `backdrop` `0xCDB993`, `stain` `0xA88F62`
       - `gravel` `0xE4E1DA`, `gravelShade` `0xB9B4A8`, `mica` `0xFFFFFF`
       - `moss` `0x3F5A2C`, `mossLight` `0x5E7436`, `mossSheen` `0xA7B86A`, `nightMoss` `0x0E140C`
       - `granite` `0x807E77`, `lichen` `0xB5B08A`, `pebble` `0x4A4740`
       - `moon` `0x8FA3C8`, `twilight` `0xE8A66B`, `cityLight` `0xFFB866`
     - Floats:
       - rake: `rakeSpacing` 1.3 (degrees), `ringBand` 7.8 (degrees), `grooveTilt` 0.45, `grooveShade` 0.18
       - grain: `grainFine` 0.06 (degrees), `grainCoarse` 0.25 (degrees), `grainContrast` 0.06
       - mica: `micaCell` 0.15 (degrees), `micaChance` 0.04, `micaSharpness` 400
       - edging and rock: `pebbleBand` 0.35 (degrees), `pebbleCell` 0.12 (degrees), `rockLevel` 0.4
       - moss and light: `mossSheenPower` 4, `mossSheenStrength` 0.25, `moonStrength` 0.22, `terminatorWidth` 0.02
       - press and pop: `pressBend` 0.6 (degrees), `pressDepth` 0.02 (always equal to `EffectTuning.garden.press.dentDepth`), `rippleGlint` 1.5
       - backdrop: `stainCells` 6, `stainStrength` 0.18, `grainBackdrop` 0.03
       - `reserved` 0

       That is 24 floats.
   - **`SceneLook.garden`.**
     - `name` "Garden"; `backdrop: GardenLook.standard.backdrop.xyz`.
     - `accent: Color(red: 0.31, green: 0.42, blue: 0.18)`; `effects: .garden`; `sound: .garden`.
     - `mesh: MeshLook(fragment: "gardenFragment", background: "gardenBackground", shape: .puffy, parameters: GardenLook.standard, marks: MarkSettings(drag: .grooves(tines: 5), pop: .rings(radius: 0.05, spacing: 0.0125), width: 1.4))`.
   - **`EffectTuning.garden`.**
     - `press`: `dentDepth` 0.02, `dentRadius` 0.11, `dentShade` 3, `frost` 0, `cracks` 0, `squash` 0.006, `pressSpring: Spring(duration: 0.2, bounce: 0)`, `releaseSpring: Spring(duration: 0.35, bounce: 0)`.
     - `pop`: `height` 0.008, `radius` 0.04, `glow` 0, `spring: Spring(duration: 0.5, bounce: 0.1)`.
     - `ripple`: `tilt` 0, `landShare` 1, `flash` 1, `displacement` 0, `wavelength` 0.04, `speed` 0.45, `decay` 1.2, `duration` 1.6.
     - `fling`: `stretchPerSpeed` 0.002, `maximumStretch` 0.008, `spring: Spring(duration: 0.4, bounce: 0.05)`.
     - `flightArc` 0.4; `inflate: Spring(duration: 1.6, bounce: 0.05)`.
     - `drag: .init(follow: Spring(duration: 0.18, bounce: 0), grainSpacing: 8, grainSharpness: 0.55)`.
3. **Garden.metal.**
   - Add `struct GardenLook`, mirroring the Swift struct.
   - **Static helpers.**
     - A jittered lattice copied from `sakuraCell` as `gardenCell`. Do not edit Sakura.
     - A cheap 3D value noise.
     - A surface-gradient bump, given a height `h` computed outside branches:
       - `dpdx = dfdx(in.spherePosition)`, `dpdy = dfdy(in.spherePosition)`;
       - `r1 = cross(dpdy, nG)`, `r2 = cross(nG, dpdx)`, `det = dot(dpdx, r1)`;
       - `n′ = normalize(abs(det)·nG − sign(det)·(r1·dfdx(h) + r2·dfdy(h)))`.
   - **`gardenFragment`.** The buffers and textures are those of `magmaFragment`, plus `texture2d<float> markTexture [[texture(6)]]`, with no snow texture.
     1. **Hoisted block, before any branch.**
        - `MarkTap mark = markTap(markTexture, surfaceSampler, coordinates.uv, gradient)`.
        - `dSea = −coast` (degrees into the sea).
        - Press bend: when effects are active, subtract `pressBend · effectWeight(nG, effects.dent.xyz, effects.radii.x) · saturate(effects.dent.w / pressDepth)` from `dSea`, so the rings bulge around the finger.
        - Static phase: `dSea / rakeSpacing` where `dSea < ringBand`, otherwise `latitudeDegrees / rakeSpacing`. Use a select, not a branch.
        - Reveal:
          - rings show where `dSea < ringBand · saturate(inflate · 1.15)`, with a soft edge one `rakeSpacing` wide;
          - straight lines fade in over `inflate` 0.85…1;
          - `inflate` is `effects.radii.w` when effects are active, else 1.
        - `gStatic = (0.5 − 0.5·cos(2π·phase)) · water · reveal`; `gMark = 0.5 − 0.5·cos(2π·mark.phase)`.
        - Fade each pattern toward 0.5 when `fwidth` of its phase exceeds 0.3–0.5.
        - `g = mix(gStatic, gMark, mark.coverage)`.
        - `h = grooveTilt · (rakeSpacing in radians) / π · g`, then the bump normal `nB`.
     2. **Gravel.**
        - Where `gravelMask = max(water, mark.coverage)`, albedo `gravel · (1 + grainContrast · (noise(fine) + 0.5·noise(coarse)))`, times `(1 − grooveShade · g)`.
        - Lambert on `nB`, so low sun near the terminator rakes the grooves hardest.
        - Mica: in `gardenCell` cells of `micaCell` with `random.x < micaChance`, a sparkle `pow(saturate(dot(reflect(−view, cellNormal), sun)), micaSharpness) · daylight`. `cellNormal` is `nB` tilted randomly per cell.
     3. **Moss**, where land is not covered by marks.
        - `mix(moss, mossLight, noise)`, wrap diffuse 0.2.
        - A sheen rim `mossSheen · pow(1 − viewCosine, mossSheenPower) · mossSheenStrength`.
        - On relief `w > rockLevel`: granite, with lichen specks where a hash is above 0.8, shaded by the relief normal.
        - On the land side of the coast, `0 < coast < pebbleBand`: dark rounded pebbles in `gardenCell` cells of `pebbleCell`, shaded by tilting the normal toward each cell's offset. Antialias the band edge with `coastCoverage`.
     4. **Night.** Moonlit colour `albedo · moon · (0.15 + moonStrength · saturate(dot(n, −sun)))`, using `nB` on gravel. Mix day to night by `daylight`, and mix moss toward `nightMoss`. Add a warm `twilight` band at the terminator, and `cityLight · smoothstep(0.2, 0.7, lights) · nightGate · 0.8`.
     5. **Ripple glint.** When the ripple is live, compute the front `pulse` as in `magmaFragment`'s ripple block. Add `rippleGlint · pulse · g` of white light to gravel, scaled by `max(daylight, 0.4)`.
     6. **Dent.** Darken the dent as Magma does (`effects.state.z · effects.dent.w · weight`).
     7. **Finish.** Mix with the backdrop by `principal.z`, then `finishColor`.
   - **`gardenBackground`.**
     - The `backdrop` wall.
     - Large soft stains from `backdropPoint(direction, stainCells, 3.0, focal)`: a blob whose radius is about `0.6 / stainCells · focal`, mixed toward `stain` by `stainStrength`.
     - Faint horizontal trowel bands, `sin(pixel.y · 0.02 + noise)`, plus a per-pixel grain of `grainBackdrop`.
     - Mix with `principal.z`, then `finishColor`.
4. **GardenSound.swift.**
   - **Timbre.** `extension SoundTimbre { static let garden = SoundTimbre(id: "garden", variants: [.press: 10, .pop: 8, .release: 8], design: { GardenSound.design(for: $0, random: &$1) }, contextual: { GardenSound.contextual($0, $1, random: &$2) }) }`.
   - **Contextual.** `.press` with `.land` returns the moss pat; with `.sea` it returns the gravel crunch; anything else returns nil.
   - **Designs.**
     - `.press`, gravel crunch. `Grains`: rise 0.008, fall 0.04, density 400…700, band 1200…5000, cycles 1…3, resonance 1.4, grit 2.5, gain 1. Plus `Wash` 250 Hz (attack 0.002, decay 0.02, resonance 0.9, gain 0.4). Level −22, floor 100.
     - Moss pat, contextual only. `Wash` 160–240 Hz (attack 0.006, decay 0.05, gain 0.6), plus `Grains` 2–5 kHz at density 150 and gain 0.15, so the phone speaker still plays it. Level −26.
     - `.release`: 2–4 pebble ticks, each a `Ring` at 2.2–4 kHz decaying in 8–15 ms, at random times 0.02–0.12 s. Level −30.
     - `.pop`, pebble drop.
       - `Wash` 150 Hz (attack 0.002, decay 0.025, gain 0.7).
       - `Grains` at 0.01 s: rise 0.005, fall 0.05, density 300, band 1500…5000, gain 0.6.
       - A soft swirl at 0.05 s: `Wash` 2 kHz with `sweep` 2, attack 0.08, decay 0.12, gain 0.12.
       - Level −21.
     - `.carve`, the rake. 3–5 tine streams, each a `Grains` offset 4–8 ms from the last: rise 0.003, fall 0.015, density 900, band 1500…6000, cycles 1…3, resonance 1.2, grit 2, gain 0.6. Plus a dry `Wash` at 3 kHz (attack 0.004, decay 0.03, gain 0.12). Level −26.
     - `.tick`, a bamboo tok. A `Ring` at f = 1100–1500 Hz and 2.6·f, decaying in 12–25 and 6 ms, plus a 0.5 ms 4 kHz `Wash`. Level −30.
     - `.dayTick`, the shishi-odoshi.
       - A `Ring` at 260, 550 and 790 Hz (±2 %), decays 0.09, 0.06 and 0.04 s, gains 1, 0.6 and 0.4.
       - A stone knock: a 1 ms `Wash` at 2.5 kHz, plus a `Ring` at 1800 and 3900 Hz (15 and 8 ms).
       - A water trickle at 0.12 s: `Grains` with rise 0.02, fall 0.08, density 300, band 2000…6000, cycles 3…6, resonance 3, gain 0.25.
       - Level −20.
     - `.snap`, hyoshigi. Two strikes 0.12 s apart, each a `Ring` at 2.0–2.6 kHz and 5.0–5.6 kHz (30–60 and 15 ms) plus a 0.6 ms 6 kHz `Wash`. Level −19.
     - `.inflate`, the suikinkutsu.
       - A drip: a `Tone` gliding 1600 → 2600 Hz (glide 0.006, attack 0.001, decay 0.012, duration 0.03).
       - At 0.01 s, a `Ring` at 850, 1375, 1650, 1900, 2250 and 2863 Hz (each ×0.98…1.02), decaying in 1.8 s for the lowest down to 1.0 s for the highest, gains 1, 0.7, 0.6, 0.5, 0.35, 0.25, with a 0.5–1.2 Hz beat on the first two.
       - Echo drips at +0.45 s and +0.8 s with the same ring at gains 0.4 and 0.2.
       - Level −22, floor 400.
5. **GardenInterface.swift.** `InterfaceLook.garden`:
   - `colorScheme: .light`; `ink` `0x2E2A22`; `secondaryInk` `0x6E6455`.
   - `typography`: `displayWeight` `.light`, `titleWeight` `.medium`, `captionCase` `.uppercase`, `captionTracking` 2.0.
   - `panel: .paper(fill: Color(hex: 0xEDE6D6), edge: Color(hex: 0xBFAE8A), shadow: .black.opacity(0.12))`; `panelCorner` 22.
   - `control: .paper(fill: Color(hex: 0xF4EFE4), edge: Color(hex: 0xBFAE8A), shadow: .black.opacity(0.08))`.
   - `accentSurface: .solid(fill: accent, edge: nil)`; `onAccent: .white`.
   - `chip`:
     - `name` 13 semibold, `time` 13 medium with monospaced digits, `detail` 11 regular, `corner` 9;
     - `surface: .solid(fill: Color(hex: 0xEDEAE3).opacity(0.95), edge: Color(hex: 0x9C9486).opacity(0.6))`;
     - `selectedSurface: .solid(fill: accent, edge: nil)`, `selectedInk: .white`.
   - `bead`: moss green.
   - `tape`: `tick: ink`, `label: secondaryInk`, `hourWidth` 1.4, `quarterWidth` 0.9, `needle: .bar`.
   - `swatch: SwatchLook(ocean: Color(hex: 0xE4E1DA), land: Color(hex: 0x3F5A2C), night: Color(hex: 0x1A2030).opacity(0.45), rim: Color(hex: 0x9C9486), finish: .raked)`.
6. **Registration.**
   - `InterfaceLook.swift`: `case .garden: .garden`.
   - `ChipMetrics.swift`: `gardenFonts` and its switch case.
   - `SwatchLook.swift`: `Finish.raked`.
   - `ThemeSwatch.swift`: `.raked` in `drawFinish` → `GardenSwatch.finish(…)`, and in `drawRim` → `GardenSwatch.rim(…)`.
   - `FeedbackCue.swift`: `case .garden: .impact(flexibility: .soft, intensity: 0.7)` in `popHaptic`.
7. **GardenSwatch.swift.** `enum GardenSwatch` with:
   - `finish`: parallel, gently curved lines every 3 units across the sphere, stroked `0xB9B4A8` at 0.35 opacity, 0.5 units wide;
   - `rim`: a 0.8-unit ring in `look.rim`.

## Constraints

- Do not change any other theme's files, output, sounds or haptics.
- Do not rename existing `SceneStyle` raw values.
- Shading only. Grooves, the press bend, glints and the reveal never move geometry, so chips stay on their cities.
- The mark map is written only by `SceneModel` code that already exists after `.tasks/02-mark-map.md`. This theme does not touch `SceneModel`, `MarkMap` or `GlobeRenderer`.
- Write no comments anywhere: no `//`, `/* */` or `///`, in Swift or Metal. Names carry the meaning.
- Brace every control-flow body, keeping the codebase's one-line `guard … else { return }` form.
- Use 4-space indentation. Metal helpers are `static` inside `Garden.metal`.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=garden .claude/duck/scene-style/harness/render.sh fx-rest fx-pop-london fx-press-held fx-inflate`

## Manual review

1. **Harness renders.** Run `STYLE=garden .claude/duck/scene-style/harness/render.sh` with no scene names, then open its `sheet.png`. Check that:
   - the rings follow coasts and meet in creases between landmasses;
   - grooves are strongest near the terminator;
   - the night side reads as moonlit gravel;
   - the rings are revealed outward in `fx-inflate`;
   - coasts and pebbles are clean at the closest zoom.
2. **Simulator.**
   - Select Garden in the tray: the rings sweep out from the coasts, with a suikinkutsu drip.
   - Hold then drag: five clean grooves follow the finger, cut across earlier strokes, and stay after release. Raking also works with Reduce Motion on.
   - Tap a city: a ringed clearing appears around it with a glint sweep, and stays. Switching themes clears every mark.
3. **Sounds.**
   - A press on the sea crunches; a press on land pats.
   - The rake scrapes with speed.
   - The tape ticks are bamboo, midnight is the shishi-odoshi knock, and back-to-now is the clappers.
4. **Device only.** Pop and rake haptics feel soft and textured.

## Out of scope

- Saving marks across launches.
- Leaves or petals.
- Lanterns (Paper owns lantern night).
- Changes to `SceneModel`, `MarkMap`, `GlobeRenderer` or any other theme.
- A dawn chorus of per-city chimes while scrubbing.

## Open questions

none
