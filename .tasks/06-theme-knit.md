# Task: Add the Knit theme — a globe knitted in the round

## Goal

A new theme, Knit (raw value `knit`, last in the theme tray), renders the globe as chunky knitting worked in the round like a hat.

- **Stitches.** Rows run along the parallels. Stitch counts fall toward the poles in eight decrease lines, as on a hat's crown.
- **Colour.** Knit V stitches in oatmeal on land and indigo at sea, with Fair Isle motif rows by latitude band. A couched rust thread follows the real coastline.
- **Night.** The palette turns indigo-dyed, and cities become glowing French knots.
- **Backdrop.** Rust felt, with a fuzzy halo of fibres around the globe's silhouette.

The interactions are soft:

- **Press.** Squishes deeply, and the stitches stretch around the finger, with a press-following haptic.
- **City tap.** Pops a wooden button at the city, and the stitches pucker toward it.
- **Hold then drag.** Sews a red running stitch that stays until the theme changes or the app is backgrounded.
- **Fling.** Plays soft rolling thumps.
- **Theme switch.** Fluffs the fuzz up.
- **Sounds.** Muffled felt, wooden needles (backward scrubs unravel), a stitch-marker clink at midnight, and scissors on back-to-now.

## Prerequisite

`.tasks/01-feedback-cues.md` and `.tasks/02-mark-map.md` have both landed. The following exist:

- `CueContext.direction`, the design-based `SoundTimbre` init with trailing `contextual:` and `train:`, `SoundTrain`, and `EffectTuning.Press.followHaptic`;
- `MarkSettings`, `MarkBrush.stitches(dash:gap:)`, `MeshLook(…, marks:)`, `markTap(...)` in `GlobeShared.h`, and the mark map bound at mesh fragment `texture(6)`.

If any of these is missing, stop: this spec builds on them.

## Files

- tokei/Globe/Looks/KnitLook.swift (create)
- tokei/Globe/Shaders/Knit.metal (create)
- tokei/Globe/Looks/KnitSound.swift (create)
- tokei/Globe/Looks/KnitInterface.swift (create)
- tokei/Interface/KnitSwatch.swift (create)
- tokei/Globe/SceneStyle.swift (modify)
- tokei/Globe/Looks/InterfaceLook.swift (modify)
- tokei/Globe/ChipMetrics.swift (modify)
- tokei/Globe/Looks/SwatchLook.swift (modify)
- tokei/Interface/ThemeSwatch.swift (modify)
- tokei/Feedback/FeedbackCue.swift (modify)
- tokei/Globe/Looks/MagmaLook.swift, tokei/Globe/Shaders/Magma.metal, tokei/Globe/Looks/MagmaSound.swift, tokei/Globe/Looks/MagmaInterface.swift, tokei/Interface/MagmaSwatch.swift (read: the newest complete theme to mirror)
- tokei/Globe/Shaders/Sakura.metal (read: `sakuraCell`, the latitude-band lattice)
- tokei/Globe/Shaders/GlobeShared.h, tokei/Globe/MarkMap.swift (read)

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
  - `MeshLook(fragment:background:shape:parameters:marks:)` binds the parameter struct at fragment and background `buffer(1)`.
  - `.puffy` is the soft-mound shape that Toy, Sakura and Weather use.
- **Parameter struct.**
  - Only `SIMD4<Float>` colour fields and `Float` fields, mirrored in order in the `.metal` struct.
  - The `Float` count must be a multiple of 4; pad with `reserved` fields.
  - Colours are written as sRGB hex through `.linear(0xRRGGBB)`.
- **Interface colours.** Interface files use `Color(hex:)` and `InterfaceLook.legibleInk(on:dark:light:)`. Swatch colours copy palette values.

### Mesh fragment contract

- **Slots.**
  - `buffer(0)`: `GlobeUniforms`. `principal.z` is the reveal fade.
  - `buffer(1)`: the parameter struct.
  - `buffer(2)`: `EffectUniforms`.
  - `texture(1)`: city lights.
  - `texture(2)`: coast signed distance in degrees, positive on land.
  - `texture(3)`: relief, xyz normal (normalise after sampling).
  - `texture(6)`: marks (r is coverage, g is the premultiplied phase). Read it with `markTap`. For `.stitches` the phase runs across the thread, −1…1.
  - `sampler(0)`: the surface sampler.
- **Preamble.** Copy it from `magmaFragment`: `pixel`, `direction` (with `effectUnshape`), `view`, `sun`, `nG`, `coordinates`, `muG`, `pixelAngle`, `gradient2d gradient`, the relief, coast and lights samples, `coastCoverage`.
- **Sampling rules.**
  - Sample with the explicit gradients computed before any branch. Calls to `dfdx`, `dfdy` and `fwidth` must not sit inside divergent branches.
  - Samples taken with an explicit level at a cell centre are safe inside branches.
- **Day and night.**
  - Gates use `nG` only: `daylight = smoothstep(-tw, tw, muG)`, `nightGate = 1 - smoothstep(-0.14, 0.04, muG)`.
  - French knots glow only through `nightGate`.
- **Ending.** End with `color = mix(look.backdrop.xyz, color, uniforms.principal.z); return finishColor(color, pixel);`. Do not add gamma.
- **No idle animation.** Nothing animates on its own clock.
- **`EffectUniforms` lanes.**
  - `dent`: xyz is the press centre (it follows a hold-then-drag); w is `dentDepth × pressAmount`.
  - `bump`: xyz is the pop centre; w the pop height times its spring.
  - `radii`: x dent radius, y bump radius, w inflate (rises from 0 to 1 on theme switch; 1 at rest).
  - `state`: z dent shade.

  Use `effectsActive(effects)` before reading any lane. Helpers: `effectWeight`, `effectOffset`.
- **Background fragment.**
  - Signature `(FullscreenVertex in [[stage_in]], constant GlobeUniforms &uniforms [[buffer(0)]], constant <Look> &look [[buffer(1)]])`.
  - Use `globeRay(pixel, focal, uniforms)`, which is the view ray, and `globeDisk(uniforms)`: the globe's screen circle, centre in xy and radius in z.
  - The background is drawn before the globe, so anything inside the disk is covered.
- **Offline harness.** `.claude/duck/scene-style/harness` (gitignored, present in this working copy) compiles everything under `tokei/Globe` on macOS, except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and some views. New files under `tokei/Globe` must not import UIKit.

### Marks, sound and haptics

- **What `marks:` already does.** With `marks:` set, `SceneModel` handles everything: it sweeps the drag brush along a hold-then-drag, resets on style change and backgrounding, and redraws per mark change, also under Reduce Motion. The theme only declares the settings and shades the map.
  - `MarkSettings.width` is the thread's half-width as a fraction of the 16 pt touch footprint.
  - `dash` and `gap` are multiples of that half-width.
- **Cues.**
  - `.press` at touch-down on the globe; `.release` after a deliberate press.
  - `.pop` on city selection.
  - `.carve` every `drag.grainSpacing` points of drag travel.
  - `.tick` and `.dayTick` on tape hour crossings. Contextual `.tick` designs receive `CueContext.direction`, +1 forward and −1 backward.
  - `.snap` on the glide back to now; `.inflate` on selecting the theme.
- **Press haptic.** `EffectTuning.Press.followHaptic = true` plays a continuous haptic curve that follows the press spring.
- **Fling train.** A `SoundTrain` schedules clicks along a fling's inertia, one per `spacing` radians of camera travel.
- **Layers.** `Tone`, `Wash` (band-passed noise, optional `sweep`), `Grains` and `Ring`, as in `MagmaSound`. A `Design` has a loudness `level` and a high-pass `floor`.
- **Phone speakers.** Loudness is measured through a 400 Hz high-pass that stands in for a phone speaker. Soft low thumps all but vanish on one, so every soft cue includes a quiet presence layer at 1–4 kHz.
- **Pop haptic.** `FeedbackCue.popHaptic` maps a style to its pop impact.
- **Charlie sheen** (Estevez & Kulla 2017): `D = (2 + 1/r) · sin(θh)^(1/r) / (2π)`, with `sin²θh = 1 − (n·h)²`. Use it with the visibility term `1 / (4 · (NoL + NoV − NoL·NoV))`.

## Plan

1. **SceneStyle.swift.** Add `case knit` as the last case, and `case .knit: .knit` in `look`.
2. **KnitLook.swift.**
   - **`struct KnitLook`.** Fields, in this order, with these `standard` values:
     - Colours:
       - felt: `backdrop` `0x8E4632`, `feltShade` `0x6E3424`, `fiber` `0xE9DFC9`
       - yarn: `indigo` `0x34507A`, `indigoDeep` `0x223652`, `oatmeal` `0xE8DCC4`, `cream` `0xF4EEE2`
       - motifs: `rust` `0xB5523B`, `mustard` `0xD7A12F`, `forest` `0x3F6B4A`
       - thread and night: `floss` `0xC43A2F`, `nightTint` `0x2B3352`, `knot` `0xE2B13C`
       - light and wood: `sheen` `0xFFF4E0`, `twilight` `0xE8A070`, `wood` `0x8A5A3B`
     - Floats:
       - lattice: `rowHeight` 2.6 (degrees), `stitchWidth` 2.6 (degrees), `sectors` 8
       - stitch: `legWidth` 0.32, `legTilt` 0.55, `plyFrequency` 9, `plyContrast` 0.08
       - cloth: `fuzzScale` 0.4 (degrees), `fuzzStrength` 0.15, `sheenRoughness` 0.35, `sheenStrength` 0.35
       - colourwork: `motifBand` 7 (rows), `coastThread` 0.14 (degrees)
       - knots: `knotCell` 0.9 (degrees), `knotRadius` 0.3, `knotGlow` 0.4
       - press: `stretch` 1.6, `pressDepth` 0.11 (always equal to `EffectTuning.knit.press.dentDepth`)
       - button: `pucker` 0.6, `buttonRadius` 0.035 (radians), `buttonHeight` 0.025 (always equal to `EffectTuning.knit.pop.height`)
       - halo: `haloReach` 0.06, `haloDensity` 0.5, `haloStrength` 0.35
       - light: `terminatorWidth` 0.03, `wrap` 0.35
       - `reserved1` 0, `reserved2` 0

       That is 28 floats.
   - **`SceneLook.knit`.**
     - `name` "Knit"; `backdrop: KnitLook.standard.backdrop.xyz`.
     - `accent: Color(red: 0.89, green: 0.69, blue: 0.24)`; `effects: .knit`; `sound: .knit`.
     - `mesh: MeshLook(fragment: "knitFragment", background: "knitBackground", shape: .puffy, parameters: KnitLook.standard, marks: MarkSettings(drag: .stitches(dash: 4, gap: 2.6), pop: nil, width: 0.1))`.
   - **`EffectTuning.knit`.**
     - `press`: `dentDepth` 0.11, `dentRadius` 0.2, `dentShade` 4, `frost` 0, `cracks` 0, `squash` 0.03, `pressSpring: Spring(duration: 0.3, bounce: 0)`, `releaseSpring: Spring(duration: 0.55, bounce: 0.1)`, `followHaptic: true`.
     - `pop`: `height` 0.025, `radius` 0.05, `glow` 0, `spring: Spring(duration: 0.55, bounce: 0.35)`.
     - `ripple`: `tilt` 0, `landShare` 0, `flash` 0, `displacement` 0, `wavelength` 0.08, `speed` 1, `decay` 3, `duration` 0.
     - `fling`: `stretchPerSpeed` 0.012, `maximumStretch` 0.06, `spring: Spring(duration: 0.7, bounce: 0.2)`.
     - `flightArc` 0.55; `inflate: Spring(duration: 1.0, bounce: 0.3)`.
     - `drag: .init(follow: Spring(duration: 0.24, bounce: 0.1), grainSpacing: 10, grainSharpness: 0.4)`.
3. **Knit.metal.**
   - Add `struct KnitLook`, mirroring the Swift struct.
   - **Static helpers.**
     - A cheap 3D value noise.
     - The surface-gradient bump, given a height `h` computed outside branches:
       - `dpdx = dfdx(in.spherePosition)`, `dpdy = dfdy(in.spherePosition)`;
       - `r1 = cross(dpdy, nG)`, `r2 = cross(nG, dpdx)`, `det = dot(dpdx, r1)`;
       - `n′ = normalize(abs(det)·nG − sign(det)·(r1·dfdx(h) + r2·dfdy(h)))`.
     - Three Fair Isle motif bitmaps as `constant ushort` row arrays: a 7×7 snowflake, a 5×5 small cross ("peerie") and a 7×7 diamond. A bit is `(rows[y] >> x) & 1`.
   - **`knitFragment`.** The buffers and textures are those of `magmaFragment`, plus `markTexture [[texture(6)]]`, with no snow texture.
     1. **Hoisted pattern warp.**
        - When effects are active:
          - `wP = effectWeight(nG, dent.xyz, radii.x) · saturate(dent.w / pressDepth)`;
          - `pK = normalize(mix(dent.xyz, nG, 1 / (1 + stretch·wP)))`, so the stitches near the finger stretch;
          - `wB = effectWeight(nG, bump.xyz, radii.y · 1.5) · saturate(bump.w / buttonHeight)`;
          - `pK = normalize(mix(bump.xyz, pK, 1 + pucker·wB))`, so the stitches pull toward the button.
        - Otherwise `pK = nG`.
     2. **Hoisted stitch lattice on `pK`.**
        - Latitude and longitude in degrees, with longitude = atan2(x, z).
        - `row = floor((lat + 90) / rowHeight)`; `rowLat` is the row's centre latitude; `sector = floor((lon + 180) / (360 / sectors))`.
        - Stitches per sector: `n = max(1, floor((360 / sectors) · cos(rowLat) / stitchWidth + 0.5))`. Counts change only where the rounding flips, and the change falls on the sector borders, which become the decrease lines.
        - `column = floor(fraction of the sector × n)`. Local `u` (−0.5…0.5 across) and `v` (0…1 up the row).
        - Each stitch has two legs centred at `u = ∓0.22`, tilted `±legTilt`, each an ellipse of half-width `legWidth` with a rounded height `sqrt(1 − ρ²)`. The stitch height `h` is the larger of the two; between legs is a dark gap.
        - Ply stripes along each leg: `0.5 + 0.5·sin(2π·plyFrequency·along + 4·across)`, giving ±`plyContrast` albedo.
        - The bump normal comes from `h · (rowHeight in radians) · 0.25`.
        - `detail = smoothstep(3, 6, (rowHeight in radians) / pixelAngle)` fades the bump and stripes when stitches get small.
     3. **Colourwork, per stitch.** Sample the coast at the stitch centre with `level(0.0)`.
        - Sea: `indigo`, with every 12th row lightened by 25 % toward `oatmeal` (a wave row).
        - Land: `oatmeal`. In alternate bands of `motifBand` rows, a motif drawn by its bitmap at `(column mod width, row in band)`:
          - polar (`abs(rowLat) > 60`): snowflake in `forest`;
          - temperate (23…60): peerie in `rust`;
          - tropic (< 23): diamond in `mustard`.
     4. **Coastline.** A couched thread on top along the true coast: `abs(coast) < coastThread / 2`, antialiased with `fwidth`. It is `rust`, with twist stripes from `sin(dot(pK, (900, 900, 900)))` (±10 %) and a brighter centre.
     5. **Finger stitches.** `MarkTap mark` at `coordinates.uv`. Where `mark.coverage > 0`, draw `floss` over everything, with roundness `0.75 + 0.25·sqrt(1 − phase²)`.
     6. **Button.** When effects are active and `bump.w > 0`:
        - angle `ab` to `bump.xyz`; radius `rb = buttonRadius · saturate(bump.w / buttonHeight)`;
        - inside `rb`, a `wood` disc with grain stripes and a lighter rim from 0.8 to 1.0 `rb`;
        - four dark holes of radius 0.09 `rb` at (±0.28, ±0.28) `rb` in the local east/north frame;
        - two `floss` thread lines, 0.05 `rb` wide, across the diagonals;
        - antialiased by `pixelAngle`.
     7. **Lighting.**
        - Wrap diffuse `saturate((dot(n, sun) + wrap) / (1 + wrap))`.
        - Charlie sheen with `r = sheenRoughness`, in `sheen`, times `sheenStrength · daylight`.
        - Fuzz: `noise(pK / fuzzScale)` times `pow(1 − viewCosine, 2) · fuzzStrength`, lightening, times `fluff`. `fluff` is `saturate(radii.w)` when effects are active, else 1, so the fuzz grows as the theme inflates.
     8. **Night.**
        - Multiply the albedo toward `nightTint` by `1 − daylight`.
        - French knots: a regular `sakuraCell`-style lattice (copied into this file, spread 0) at `knotCell` degrees on `pK`. In a cell whose centre lights sample (`level(0.0)`) exceeds 0.25, a knot of radius `knotRadius` of the cell: a dome with spiral stripes `sin(6·angle + 20·r)`, in `knot`, emitting `knot · knotGlow · nightGate`.
        - A warm `twilight` band at the terminator.
     9. **Dent, then finish.** Darken the dent as Magma does, mix with the backdrop by `principal.z`, then `finishColor`.
   - **`knitBackground`.**
     - The felt: `backdrop` mixed toward `feltShade` by two octaves of screen-space value noise.
     - Short light fibre strokes from `backdropPoint(direction, 140, 9.0, focal)`, where `random.x < 0.3`: 3–6 px lines at a random angle in `fiber` at 0.25.
     - Fuzz halo, for pixels with `1 < reach < 1 + haloReach` (`reach` = distance to the disk centre ÷ disk radius):
       - the closest-approach direction of the view ray is `pc = normalize(o + d·(−dot(o, d)))`, where `o = cameraPosition.xyz` and `d = normalize(globeRay(...))`;
       - `fuzz = step(1 − haloDensity, noise(pc · 800) · noise(pc · 2000) · 2)`;
       - add `fiber · haloStrength · fuzz · (1 − (reach − 1) / haloReach)`.

       `pc` is anchored to the globe, so the halo turns with it.
     - Mix with `principal.z`, then `finishColor`.
4. **KnitSound.swift.**
   - **Timbre.** `extension SoundTimbre { static let knit = SoundTimbre(id: "knit", variants: [.press: 10, .pop: 8, .release: 8], design: { KnitSound.design(for: $0, random: &$1) }, contextual: { KnitSound.contextual($0, $1, random: &$2) }, train: KnitSound.train) }`.
   - **Contextual.** `.tick` with `direction == -1` returns the unravel design; anything else returns nil, so forward ticks use the regular library.
   - **Designs.**
     - `.press`, a felt thump. A `Wash` at 140–220 Hz (attack 0.006, decay 0.06, resonance 0.8, gain 0.7), plus a fibre crackle `Grains` (band 1500…4000, density 300, rise 0.005, fall 0.04, cycles 1…2, resonance 0.8, grit 2, gain 0.12). Level −24, floor 70.
     - `.release`, an exhale. A `Wash` at 900 Hz with `sweep` 0.55 (attack 0.03, decay 0.09, resonance 0.5, gain 0.4), plus a faint crackle. Level −28.
     - `.pop`, a button "pok".
       - A `Ring` at 1500–2200 Hz and ×2.4, decaying in 20 and 10 ms, plus a 300 Hz knock `Wash` (10 ms).
       - At 0.04 s, a thread "thwip": a `Wash` at 800 Hz with `sweep` 3.5 (attack 0.015, decay 0.025, resonance 0.7, gain 0.3).
       - Level −21.
     - `.carve`, one stitch.
       - A needle tick: a 0.3 ms 6 kHz `Wash` plus a `Ring` at 5200 Hz (6 ms, gain 0.15).
       - At 0.01 s, a thread pull: a `Wash` at 800 Hz with `sweep` 3.75 (attack 0.01, decay 0.03, resonance 0.6, gain 0.35).
       - Level −27.
     - `.tick`, a bamboo needle. A `Ring` at f and 2.7·f decaying in 12 and 6 ms, with f picked from {1600, 1900} Hz so ticks alternate between two needles, plus a 0.4 ms 5 kHz `Wash`. Level −30.
     - Unravel, contextual only. A `Grains` (band 600…2500, density 900, rise 0.005, fall 0.06, cycles 1…3, resonance 1, grit 1.2, gain 0.8), plus a `Wash` at 1800 Hz with `sweep` 0.5 (attack 0.005, decay 0.05, gain 0.2). Level −30.
     - `.dayTick`, a stitch marker clink. A `Ring` at 3100 and 7400 Hz (60 and 30 ms, gains 1 and 0.4) plus a click. Level −27.
     - `.snap`, scissors. A `Grains` (band 3000…8000, cycles 2…4, resonance 4, density 2000, rise 0.002, fall 0.02, gain 0.6), then at 0.03 s a click: a `Ring` at 4200 Hz (8 ms). Level −23.
     - `.inflate`, a pillow "fwump". A 120 Hz `Wash` (attack 0.02, decay 0.12, gain 0.8), plus a rustle `Wash` at 1000 Hz (attack 0.03, decay 0.1, resonance 0.5, gain 0.15), plus three needle clicks at 0.25, 0.37 and 0.49 s. Level −21.
   - **`static let train`.** `SoundTrain(spacing: 0.35, limit: 12, haptics: 0, sharpness: 0.1, design: …)`. The design is a soft thump (a `Wash` at 110–160 Hz, attack 0.004, decay 0.03, gain 0.8) plus a faint crackle, at level −28.
5. **KnitInterface.swift.** `InterfaceLook.knit`:
   - `colorScheme: .dark`; `ink` `0xFBF3E6`; `secondaryInk` `0xE8CDB8`.
   - `typography`: `design` and `digitDesign` `.rounded`; `displayWeight` and `titleWeight` `.semibold`; `bodyWeight` `.medium`; `captionCase` `.uppercase`; `captionTracking` 1.0.
   - `panel: .raised(fill: Color(hex: 0x6F3324), base: Color(hex: 0x4A2016), depth: 3, edge: accent.opacity(0.3))`; `panelCorner` 24.
   - `control: .raised(fill: Color(hex: 0x7D3A28), base: Color(hex: 0x4A2016), depth: 2, edge: accent.opacity(0.25))`.
   - `accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.4), depth: 2, edge: Color(hex: 0xF4EEE2).opacity(0.5))`; `onAccent: legibleInk(on: accent, dark: Color(hex: 0x3A1A10))`.
   - `sheet: Color(hex: 0x5E2B1E)`.
   - `chip`, a sewn-on woven label:
     - `name` rounded 13 bold, `time` rounded 13 semibold with monospaced digits, `detail` rounded 11 medium; `corner` 5;
     - `surface: .solid(fill: Color(hex: 0xF3EBDD).opacity(0.97), edge: Color(hex: 0xB5523B))`;
     - `nameColor` `0x5A2A1E`, `timeColor` and `detailColor` `0x8A5A48`;
     - `selectedSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.4), depth: 2, edge: Color(hex: 0xB5523B))`, `selectedInk` `0x3A1A10`, `shiftedTimeColor` `0xB5523B`.
   - `bead`: mustard.
   - `tape`: `tick: ink`, `label: secondaryInk`, `labelDesign: .rounded`, `hourWidth` 1.6, `quarterWidth` 1, `needle: .pin`, `needleOutline: Color(hex: 0x4A2016)`.
   - `swatch: SwatchLook(ocean: Color(hex: 0x34507A), land: Color(hex: 0xE8DCC4), night: Color(hex: 0x2B3352).opacity(0.5), rim: Color(hex: 0xD7A12F), finish: .yarn)`.
6. **Registration.**
   - `InterfaceLook.swift`: `case .knit: .knit`.
   - `ChipMetrics.swift`: `knitFonts` and its switch case.
   - `SwatchLook.swift`: `Finish.yarn`.
   - `ThemeSwatch.swift`: `.yarn` in `drawFinish` → `KnitSwatch.finish(…)`, and in `drawRim` → `KnitSwatch.rim(…)`.
   - `FeedbackCue.swift`: `case .knit: .impact(flexibility: .soft, intensity: 0.6)` in `popHaptic`.
7. **KnitSwatch.swift.** `enum KnitSwatch` with:
   - `finish`: seven elliptical arcs at different rotations across the sphere, like the wraps of a ball of yarn, stroked `0xF4EEE2` at 0.45 opacity, 0.8 units wide;
   - `rim`: a ring in `look.rim`, drawn once blurred (1 unit) and once sharp at 0.8 units.

## Constraints

- Do not change any other theme's files, output, sounds or haptics. `Sakura.metal` is read, not edited.
- Do not rename existing `SceneStyle` raw values.
- Shading only. The stretch, pucker, button and stitches never move geometry; only the existing dent, bump and stretch formulas do. Chips therefore stay on their cities.
- The mark map is written only by `SceneModel` code that already exists after `.tasks/02-mark-map.md`. This theme does not touch `SceneModel`, `MarkMap` or `GlobeRenderer`.
- Write no comments anywhere: no `//`, `/* */` or `///`, in Swift or Metal. Names carry the meaning.
- Brace every control-flow body, keeping the codebase's one-line `guard … else { return }` form.
- Use 4-space indentation. Metal helpers are `static` inside `Knit.metal`.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=knit .claude/duck/scene-style/harness/render.sh fx-rest fx-pop-land fx-press-held fx-inflate-early`

## Manual review

1. **Harness renders.** Run `STYLE=knit .claude/duck/scene-style/harness/render.sh` with no scene names, then open its `sheet.png`. Check that:
   - stitches read as knit Vs at the default zoom and don't shimmer when zoomed out;
   - the decrease lines converge toward the poles;
   - Fair Isle rows sit on land only, and the coastline thread is smooth;
   - the night shows French knots at cities;
   - `fx-press-held` shows stretched stitches, `fx-pop-land` shows a button, and the fuzz halo surrounds the globe.
2. **Simulator.**
   - Select Knit: a fwump and three needle clicks, with the fuzz growing.
   - Press: a deep, slow squish and a muffled thump. Hold then drag: red running stitches, each with a tick-and-thwip. They stay until the theme changes, also with Reduce Motion on.
   - Tap a city: a button pops with a "pok", and the stitches pucker.
   - Fling: soft rolling thumps that stop on touch.
   - Tape: needle ticks forward, an unravel backward, a clink at midnight, a snip on back-to-now.
3. **Device only.** The press haptic follows the squish, and the soft sounds stay audible on the phone speaker.

## Out of scope

- Thread colours that change per stroke.
- Stitched chip borders that draw themselves.
- A pompom.
- Changes to `SceneModel`, `MarkMap`, `GlobeRenderer` or any other theme.
- Persisting marks across launches.

## Open questions

none
