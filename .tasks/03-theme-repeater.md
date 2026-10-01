# Task: Add the Repeater theme — an enamel watch dial that strikes a city's time

## Goal

A new theme, Repeater (raw value `repeater`, last in the theme tray), renders the globe as a watch dial:

- translucent blue enamel over wave guilloché on the sea;
- silvered hobnail on land, with a gold wire along the coast;
- on the night side, lume that is brightest just after local sunset and fades through the night;
- an opaline silver backdrop with a sunray sheen that turns with the camera.

Pressing shows a loupe that magnifies the dial under the finger. Every interaction sounds like a watch:

- crown clicks with a detent;
- ratchet ticks that change with scrub direction and with distance from now;
- a gong pitched by the tapped city's offset from home;
- a freewheel click train on a fling;
- on a long-press of a city chip, a full minute repeater of that city's displayed local time (hours, quarters, minutes), with a haptic per strike and a pulse on that chip.

## Prerequisite

`.tasks/01-feedback-cues.md` has landed, so the following exist:

- `CueContext` (in `FeedbackCue.swift`);
- `SoundSequence` and `SoundTrain` (in `SoundSynth.swift`);
- the design-based `SoundTimbre` init with trailing `contextual:` and `train:` parameters;
- `EffectTuning.Press.cutoff`;
- `SceneLook.popEcho`;
- `SceneModel.playSequence(_:)` and `cancelSequence()`.

If any of these is missing, stop: this spec builds on them.

## Files

- tokei/Globe/Looks/RepeaterLook.swift (create)
- tokei/Globe/Shaders/Repeater.metal (create)
- tokei/Globe/Looks/RepeaterSound.swift (create)
- tokei/Globe/Looks/RepeaterInterface.swift (create)
- tokei/Interface/RepeaterSwatch.swift (create)
- tokei/Globe/SceneStyle.swift (modify)
- tokei/Globe/Looks/SceneLook.swift (modify)
- tokei/Globe/Looks/InterfaceLook.swift (modify)
- tokei/Globe/ChipMetrics.swift (modify)
- tokei/Globe/Looks/SwatchLook.swift (modify)
- tokei/Interface/ThemeSwatch.swift (modify)
- tokei/Feedback/FeedbackCue.swift (modify)
- tokei/Globe/SceneModel.swift (modify)
- tokei/Globe/GlobeScene.swift (modify)
- tokei/Globe/MarkerOverlay.swift (modify)
- tokei/Globe/MarkerChip.swift (modify)
- tokei/Globe/Looks/MagmaLook.swift, tokei/Globe/Shaders/Magma.metal, tokei/Globe/Looks/MagmaSound.swift, tokei/Globe/Looks/MagmaInterface.swift, tokei/Interface/MagmaSwatch.swift (read: the newest complete theme to mirror)
- tokei/Globe/Looks/SakuraInterface.swift (read: a light-scheme interface)
- tokei/Globe/Shaders/Sakura.metal (read: `sakuraCell`, the latitude-band lattice)
- tokei/Globe/Shaders/GlobeShared.h (read: shared structs and helpers)

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
  - `MeshLook(fragment:background:shape:parameters:)` carries the parameter struct as raw bytes, bound at fragment and background `buffer(1)`.
  - `shape: .stepped` is the existing terraced real-relief shape. Its relief level is in `texture(3).w`, and Magma and Ice use it.
- **Parameter struct.**
  - Only `SIMD4<Float>` colour fields and `Float` fields, mirrored in the same order in the `.metal` struct.
  - The number of `Float` fields must be a multiple of 4 (pad with `reserved` fields defaulting to 0). Otherwise the Swift and Metal sizes differ; `MagmaLook` ends with `reserved` for this reason.
  - Colours are written as sRGB hex through `.linear(0xRRGGBB)`, which uploads them linear.
- **Interface colours.** Interface files use `Color(hex:)` and `InterfaceLook.legibleInk(on:dark:light:)`, both defined in `InterfaceLook.swift`. Swatch colours copy palette values.

### Mesh fragment contract

- **Slots.**
  - `buffer(0)`: `GlobeUniforms`. `principal.z` is the reveal fade.
  - `buffer(1)`: the parameter struct.
  - `buffer(2)`: `EffectUniforms`.
  - `texture(1)`: city lights.
  - `texture(2)`: coast signed distance in degrees, positive on land.
  - `texture(3)`: relief. xyz is the normal (normalise after sampling) and w the relief level.
  - `sampler(0)`: the surface sampler.
- **Preamble.** Copy it from `magmaFragment`: `pixel`, `direction` (with `effectUnshape`), `view`, `sun`, `nG = normalize(in.spherePosition)`, `coordinates = surfaceCoordinates(nG)`, `muG`, `pixelAngle`, `gradient2d gradient`, the relief, coast and lights samples, `coastCoverage`.
- **Sampling rules.**
  - Sample with the explicit gradients computed before any branch. Calls to `dfdx`, `dfdy` and `fwidth` must not sit inside divergent branches.
  - Samples taken with an explicit gradient or level are safe inside branches.
- **Day and night.**
  - Gates use the radial direction `nG` only: `daylight = smoothstep(-tw, tw, muG)`, `nightGate = 1 - smoothstep(-0.14, 0.04, muG)`, as in Magma.
  - Lume, glints and every other effect stay gated by these.
- **Ending.** End with `color = mix(look.backdrop.xyz, color, uniforms.principal.z); return finishColor(color, pixel);`. `finishColor` does tonemapping and sRGB encoding; do not add gamma.
- **No idle animation.** Nothing may animate on its own clock. Motion comes only from `EffectUniforms`, the camera and the sun.
- **`EffectUniforms` lanes.**
  - `dent`: xyz is the press centre (it follows the finger during a hold-then-drag); w is `dentDepth × pressAmount`.
  - `bump`: xyz is the pop centre; w the pop height.
  - `radii`: x dent radius, y bump radius, z pop glow, w inflate (1 at rest).
  - `ripple`: xyz origin; w age, which is negative when there is none.
  - `wave`: x tilt, y displacement, z wavelength, w speed.
  - `state`: x ripple decay, y active flag (read it through `effectsActive`), z dent shade, w snow clock.
  - `detail`: z ripple land share, w ripple flash.

  Helpers: `effectWeight(direction, center, radius)`, `effectOffset`, `rippleSlope`.
- **Background fragment.** Signature `(FullscreenVertex in [[stage_in]], constant GlobeUniforms &uniforms [[buffer(0)]], constant <Look> &look [[buffer(1)]])`. Use `globeRay`, `globeDisk(uniforms)` (the globe's screen circle: centre in xy, radius in z) and `backdropPoint`. Mix with the backdrop by `principal.z` and finish with `finishColor`.
- **Offline harness.** `.claude/duck/scene-style/harness` (gitignored, present in this working copy) compiles everything under `tokei/Globe` on macOS, except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and some views. The new files under `tokei/Globe` must therefore not import UIKit; SwiftUI `Color` is fine.

### Sound and haptics

- **Timbres.** A design-based timbre maps each `FeedbackCue.Kind` (`tick`, `dayTick`, `press`, `release`, `pop`, `snap`, `inflate`, `carve`) to a `SoundSynth.Design`: layers, a loudness `level` and a high-pass `floor`, with seeded random variants. See `MagmaSound`. Kinds in `silent` never render or play.
- **Layers in `SoundLayers.swift`.**
  - `Tone`: an enveloped sine `Voice` with glide.
  - `Wash`: band-passed noise with attack, decay and an optional `sweep` ratio.
  - `Grains`: sparse resonant noise bursts.
  - `Ring`: modal partials, each with a frequency, a decay, a gain and an optional `beat`.
- **When cues fire.**
  - `.tick` and `.dayTick` fire on tape hour crossings.
  - `.press` fires at touch-down on the globe.
  - `.release` fires on a deliberate press (held at least 0.2 s, moved less than 10 pt).
  - `.pop` fires on city selection.
  - `.snap` fires when the tape glides back to now.
  - `.inflate` fires on switching to the theme.
  - `.carve` fires as drag grains.
- **Context.** `contextual` designs receive `CueContext`:
  - `pitch` is in semitones from the home zone, −12…11, for pops;
  - `direction` is ±1 and `tension` is 0…3, for ticks.
- **Trains.** `train` sequences clicks along the fling's inertia.
- **Haptics.**
  - `FeedbackCue.popHaptic` maps a style to its pop impact.
  - Entries of a `SoundSequence` carrying a `HapticTick` become Core Haptics transients.
  - Haptics play even with the Silent switch on, where `.ambient` audio is muted. So the repeater can be felt in silent mode, subject to the system haptics setting.
- **Chip taps.** `MarkerOverlay` wraps each chip in a `Button` whose action calls `onSelect` (`store.toggleSelection`, so a second tap deselects). A selection change pops the city in GlobeScene. GlobeScene's `date` is the displayed time (now plus the shift).
- **Reference facts.**
  - A real minute repeater strikes hours on the low gong, each quarter as a high-then-low "ding-dong", and the minutes since the last quarter on the high gong. 12:59 takes 18–20 s on a real watch; this theme compresses it to about 10 s.
  - Repeater gongs are steel wires whose audible partials lie between 1 and 20 kHz, inharmonic and dense.
  - A 28,800 vph escapement beats every 125 ms. Each tick is about three fused impacts within 15–18 ms, and tic differs from tac.
  - Phosphorescent lume fades as a power law with an exponent near 1.

## Plan

1. **SceneStyle.swift.** Add `case repeater` after `pixel`, and `case .repeater: .repeater` in `look`.
2. **SceneLook.swift.** Add `var strikes: (@Sendable (Int, Int) -> SoundSequence)?` after `popEcho`, defaulted to nil. Given a local hour (0–23) and minute, it returns the strike sequence.
3. **RepeaterLook.swift.**
   - **`struct RepeaterLook`.** Fields, in this order, with these `standard` values:
     - Colours:
       - `backdrop` `0xE7E4DE`, `backdropShade` `0xCFCAC0`, `sunray` `0xFFFFFF`
       - `enamelDeep` `0x0F2C6E`, `enamelShallow` `0x2D5DB5`
       - `silver` `0xE4E2DC`, `silverShade` `0x8F8D88`
       - `gold` `0xCFA850`, `goldShade` `0x6E5320`
       - `nightEnamel` `0x0A1326`, `nightSilver` `0x262A33`
       - `lume` `0xB8F0A0`, `twilight` `0xE7B58A`
     - Floats:
       - waves: `waveSpacing` 0.6 (degrees), `waveWobble` 0.25 (degrees), `waveDepth` 0.55
       - flanks: `flankTilt` 0.35, `flankSharpness` 80, `flankStrength` 0.6
       - hobnail: `hobnailCell` 1.1 (degrees), `hobnailTilt` 0.22, `highland` 0.35
       - surface: `wireWidth` 0.09 (degrees), `clearcoat` 0.04, `clearcoatGloss` 1200
       - lume: `lumeStrength` 1.6, `lumeHalfTime` 0.5 (hours), `lumeExponent` 1.0, `terminatorWidth` 0.025
       - loupe: `loupeRadius` 0.12 (radians), `loupeMagnification` 2.0, `loupeDepth` 0.004 (always equal to `EffectTuning.repeater.press.dentDepth`)
       - backdrop: `sunrayLines` 220, `sunraySheen` 0.35, `chapterRing` 1.13, `rimLight` 0.25
       - `reserved` 0

       That is 24 floats.
   - **`SceneLook.repeater`.**
     - `name` "Repeater"; `backdrop: RepeaterLook.standard.backdrop.xyz`.
     - `accent: Color(red: 0.69, green: 0.54, blue: 0.24)` (deep gold); `effects: .repeater`; `sound: .repeater`.
     - `mesh: MeshLook(fragment: "repeaterFragment", background: "repeaterBackground", shape: .stepped, parameters: RepeaterLook.standard)`.
     - `strikes: { hour, minute in RepeaterSound.repeater(hour: hour, minute: minute) }`.
   - **`EffectTuning.repeater`.**
     - `press`: `dentDepth` 0.004, `dentRadius` 0.12, `dentShade` 0, `frost` 0, `cracks` 0, `squash` 0.004, `pressSpring: Spring(duration: 0.18, bounce: 0)`, `releaseSpring: Spring(duration: 0.3, bounce: 0.1)`, `cutoff: RepeaterSound.detentTime`.
     - `pop`: `height` 0.006, `radius` 0.045, `glow` 1.4, `spring: Spring(duration: 0.6, bounce: 0.2)`.
     - `ripple`: `tilt` 0, `landShare` 1, `flash` 1, `displacement` 0, `wavelength` 0.05, `speed` 0.7, `decay` 1.6, `duration` 1.6.
     - `fling`: `stretchPerSpeed` 0.002, `maximumStretch` 0.01, `spring: Spring(duration: 0.4, bounce: 0.1)`.
     - `flightArc` 0.45; `inflate: Spring(duration: 0.8, bounce: 0.12)`.
     - `drag: .init(follow: Spring(duration: 0.14, bounce: 0), grainSpacing: 14, grainSharpness: 0.8)`.
4. **Repeater.metal.**
   - Add `struct RepeaterLook`, mirroring the Swift struct.
   - **Static helpers.**
     - A regular lattice cell: copy `sakuraCell` from `Sakura.metal` as `repeaterCell` with spread 0, so cells sit on a regular grid. Do not edit Sakura.
     - A cheap 3D value noise.
     - A surface-gradient bump function, given the height `h` (computed outside branches):
       - `dpdx = dfdx(in.spherePosition)`, `dpdy = dfdy(in.spherePosition)`;
       - `r1 = cross(dpdy, nG)`, `r2 = cross(nG, dpdx)`, `det = dot(dpdx, r1)`;
       - `n′ = normalize(abs(det)·nG − sign(det)·(r1·dfdx(h) + r2·dfdy(h)))`.
   - **`repeaterFragment`.** The buffer, texture and sampler slots are those of `magmaFragment`, minus the snow texture.
     1. **Loupe** (before any branch). `amount = effectsActive(effects) ? saturate(effects.dent.w / look.loupeDepth) : 0`. Let `a` be the angle between `nG` and `effects.dent.xyz`, `R = look.loupeRadius · amount`, `inside = 1 − smoothstep(0.85R, R, a)` and `m = 1 + (look.loupeMagnification − 1)·inside`. The pattern direction is `pD = normalize(mix(effects.dent.xyz, nG, 1 / m))` when `amount > 0`, else `nG`.
        - All pattern work below (coast, relief and lights samples, lattice, waves) uses `surfaceCoordinates(pD)` and its gradients, so it magnifies naturally.
        - Lighting gates use `nG`.
        - Lens rim: add `0.35 · exp(−((a − R) / (0.08R))²) · amount` of white, and darken by up to 15 % just outside `R`.
     2. **Sea.**
        - `dSea = −coast(pD)`; `phase = (dSea + look.waveWobble · noise(pD·12)) / look.waveSpacing`.
        - Lines fade below a pixel or two: `lineFade = 1 − smoothstep(0.25, 0.5, fwidth(phase))`.
        - Groove `g = mix(0.5, 0.5 − 0.5·cos(2π·phase), lineFade)`; enamel = `mix(enamelShallow, enamelDeep, saturate(0.35 + waveDepth·g))`.
        - Flank normal from the bump function with `h = look.flankTilt · (waveSpacing in radians) / π · g`.
        - Flank glint: `pow(saturate(dot(reflect(−view, flankNormal), sun)), flankSharpness) · flankStrength · daylight`.
        - Clearcoat: Schlick Fresnel with `clearcoat` as F0, a sun glint `pow(…, clearcoatGloss)` on `nG`, and a silver environment tint scaled by Fresnel.
        - City pop: when `ripple.w ≥ 0`, multiply the flank glint by `1 + 3·pulse`. `pulse` is the front band computed as in `magmaFragment`'s ripple block.
     3. **Land.**
        - Hobnail on the `repeaterCell` lattice at `hobnailCell` degrees, with local `(u, v)` in −0.5…0.5. The facet tilts `hobnailTilt` toward ±east when `abs(u) > abs(v)`, else ±north. Apply it to the relief normal, mixed by `effects.radii.w` when effects are active, as Magma does.
        - Darken thin ridge lines along the diagonals and the cell borders.
        - Where relief `w > highland`, use barleycorn instead: diagonal grooves `sin(2π·4·(u + v))` tilting along east + north.
        - Fade the facet pattern toward the plain normal when a cell spans fewer than 3–5 pixels (`hobnailCell` in radians ÷ `pixelAngle`).
        - Silver albedo, wrap diffuse 0.3, facet specular `pow(…, 60) · 0.5`.
     4. **Coast wire.** `wire = 1 − smoothstep(wireWidth/2 − w, wireWidth/2 + w, abs(coast))` with `w = max(fwidth(coast), 1e-4)`. Gold, rounded by tilting the normal across it, with `goldShade` at the edges.
     5. **Day and night.**
        - Mix enamel toward `nightEnamel` and silver toward `nightSilver` by `1 − daylight`.
        - Add a warm `twilight` band just inside the terminator, like Magma's `warmth`.
     6. **Lume** (on `nG`, the real point).
        - `φ = asin(clamp(nG.y, −0.9999, 0.9999))`, which keeps `tan` finite at the poles; `δ = asin(sun.y)`; `H = wrap(atan2(nG.x, nG.z) − atan2(sun.x, sun.z))` (positive in the afternoon), `H0 = acos(clamp(−tan φ · tan δ, −1, 1))`.
        - Hours since sunset `t = fract((H − H0) / 2π) · 24`.
        - `L = lumeStrength / pow(1 + t / lumeHalfTime, lumeExponent)`.
        - When effects are active, multiply `L` by `1 + 4·saturate(1 − effects.radii.w)`: the "charged" flash while the theme inflates.
        - Emission `lume · L · nightGate · (wire + 0.85 · smoothstep(0.15, 0.6, lights(pD)))`.
     7. **Pop glint.** Add `gold · effects.radii.z · effectWeight(nG, effects.bump.xyz, effects.radii.y · 0.7)`.
     8. **Rim, then finish.** A silver rim light `pow(1 − viewCosine, 3) · rimLight`; then the backdrop mix and `finishColor`.
   - **`repeaterBackground`.**
     - Base `mix(backdrop, backdropShade, …)`, a soft vignette.
     - Sunray brushing around `globeDisk`: angle `θ` around the disk centre, line jitter from `hash12(floor(θ / 2π · sunrayLines))` (±3 %), and a sheen `pow(abs(cos(θ − yaw)), 24) · sunraySheen`, where `yaw = atan2(cameraPosition.x, cameraPosition.z)`. The bright sector turns only when the camera moves.
     - A thin `goldShade` chapter ring at `chapterRing ×` the disk radius, with 60 ticks just outside it, every fifth longer.
     - Mix with `principal.z`, then `finishColor`.
5. **RepeaterSound.swift.**
   - **Timbre.**
     - `extension SoundTimbre { static let repeater = SoundTimbre(id: "repeater", variants: [.press: 8, .pop: 8, .release: 8], silent: [.carve], design: { RepeaterSound.design(for: $0, random: &$1) }, contextual: { RepeaterSound.contextual($0, $1, random: &$2) }, train: RepeaterSound.train) }`.
     - `enum RepeaterSound` holds `static let detentTime = 0.14`, `hourGong = 1100.0`, `minuteGong = 1560.0`.
   - **Gong strike** `strike(at:pitch:random:) -> [any SoundLayer]`:
     - a `Ring` with partial ratios 1, 1.96, 3.24, 4.84, 6.76 (the high modes of a bar), decays 1.4, 0.9, 0.55, 0.32, 0.18 s (each ×0.9…1.1), gains 1, 0.6, 0.4, 0.25, 0.15;
     - a beat of 0.6–1.0 Hz on the first two partials;
     - a hammer `Wash` (5.5 kHz, attack 0.0001, decay 0.0008, gain 0.35) and a case knock `Wash` (420 Hz, decay 0.004, gain 0.12).
     - Strike designs use level −22.
   - **`static func repeater(hour: Int, minute: Int) -> SoundSequence`.**
     - Hour count: `hour % 12`, where 0 becomes 12.
     - Quarters `q = minute / 15`; minutes `m = minute % 15`.
     - Hours: low gong (`hourGong`) every 0.34 s, with haptic (0.7, 0.3).
     - After a 0.5 s gap, `q` pairs every 0.46 s: high (`minuteGong`) at 0 with haptic (0.5, 0.8), then low at +0.17 with haptic (0.6, 0.35).
     - After a 0.5 s gap, `m` high strikes every 0.24 s, with haptic (0.45, 0.85).
     - Skip a block and its gap when its count is 0.
     - `seed = UInt64(hour * 60 + minute)`.
   - **Contextual.**
     - `.pop` with a pitch: a single gong. Snap the pitch to the major pentatonic degrees {0, 2, 4, 7, 9} (plus 12·k); the frequency is `hourGong · 2^(s/12)`.
     - `.tick` with a direction: a ratchet click.
       - Forward: `Wash` near 4.2 kHz (decay 1.2 ms), plus a `Ring` at 4.4 and 7.1 kHz (6 and 3 ms), plus a body `Wash` at 900 Hz (3 ms).
       - Every tension step raises the click frequencies by 3 %.
       - Backward: the same click at ×0.7 frequency, 3 dB quieter.
     - Return nil for anything else.
   - **Designs.**
     - `.tick`: the forward click.
     - `.dayTick`: a date jump, "tk-CLACK": a 1 ms 2 kHz click, then at +25 ms a `Ring` at 1100 and 2900 Hz (25 and 12 ms) over a 180 Hz knock.
     - `.press`: a crown push. A click (3.5 kHz `Wash`, 1 ms, plus a 3.8 kHz `Ring`, 6 ms) at 0, and a deeper detent click at `detentTime` (2.2 kHz `Wash`; `Ring` at 2.6 and 5.1 kHz, 10 and 5 ms; 600 Hz body).
     - `.release`: a click-back (4.8 kHz `Wash`, 0.8 ms) plus a click-spring `Ring` at 5.2 kHz (25 ms).
     - `.pop`: a single gong at `hourGong`.
     - `.snap`: a flyback. A click, then a `Wash` from 1.5 kHz with `sweep` 2.7 (attack 0.02, decay 0.012), then a click at +70 ms.
     - `.inflate`: winding, then two escapement beats.
       - 8 ratchet clicks at intervals 60, 52, 45, 39, 34, 30, 27 ms.
       - Then a tic at +90 ms after the last click: sub-clicks at 0, 5 and 12 ms (`Wash` 3–7 kHz, 0.4–0.8 ms, gains 0.5, 0.35, 0.6).
       - Then a tac 125 ms later, with spacing ×0.85 and gain ×0.8.
   - **`static let train`.** `SoundTrain(spacing: 0.105, limit: 48, haptics: 6, sharpness: 0.8, design: …)`. The design is the forward ratchet click, its `Wash` centre at `3600 + 1200·fraction` Hz.
6. **RepeaterInterface.swift.** `InterfaceLook.repeater`, mirroring the structure of `MagmaInterface`:
   - `colorScheme: .light`; `ink` `0x1C2433`; `secondaryInk` `0x5D6676`.
   - `typography`: `design` and `digitDesign` `.serif`; `displayWeight` `.regular`, `titleWeight` `.semibold`; `captionCase` `.uppercase`; `captionTracking` 1.6.
   - `panel: .metal(fill: Color(hex: 0xECE9E3), highlight: .white, shade: Color(hex: 0xBDB7AC), brushed: true)`; `panelCorner` 26.
   - `control: .solid(fill: Color(hex: 0xF6F4F0), edge: gold.opacity(0.5))`.
   - `accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.45), depth: 2, edge: gold.opacity(0.6))`; `onAccent: legibleInk(on: accent)`.
   - `sheet: Color(hex: 0xF1EEE8)`.
   - `chip`:
     - `name` serif 13 semibold; `time` serif 13 regular with monospaced digits; `detail` serif 11 regular; `corner` 6.
     - `surface: .solid(fill: Color(hex: 0xFBFAF7).opacity(0.95), edge: gold.opacity(0.6))`.
     - `selectedSurface: .raised(fill: Color(hex: 0x1F3F8F), base: Color(hex: 0x12285E), depth: 2, edge: gold)`.
     - `selectedInk: .white`; `shiftedTimeColor: Color(hex: 0x1F3F8F)`.
   - `bead`: a blued steel body `0x1F3F8F` with highlight `0x8FA9E8`.
   - `tape`:
     - `tick: ink`, `label: secondaryInk`, `labelDesign: .serif`;
     - `hourWidth` 1.2, `quarterWidth` 0.8, `squareCaps: true`;
     - `needle: .hairline`.
   - `swatch: SwatchLook(ocean: Color(hex: 0x1E4296), land: Color(hex: 0xE6E4DF), night: Color(hex: 0x0B1220).opacity(0.5), rim: Color(hex: 0xCFA850), finish: .enamel)`.
7. **Registration.**
   - `InterfaceLook.swift`: add `case .repeater: .repeater` to `SceneStyle.interface`.
   - `ChipMetrics.swift`: `repeaterFonts` and its switch case.
   - `SwatchLook.swift`: `Finish.enamel`.
   - `ThemeSwatch.swift`: `.enamel` in `drawFinish` → `RepeaterSwatch.finish(…)`, and in `drawRim` → `RepeaterSwatch.rim(…)`.
   - `FeedbackCue.swift`: `case .repeater: .impact(flexibility: .rigid, intensity: 0.55)` in `popHaptic`.
8. **RepeaterSwatch.swift.** `enum RepeaterSwatch` with:
   - `finish`: six slightly wobbly concentric rings around (62, 58) in the 100-unit swatch space, stroked white at 0.18 opacity, 0.6 units wide;
   - `rim`: a 1.4-unit ring in `look.rim` with a 0.5-unit `0x6E5320` hairline inside it.
9. **SceneModel.swift.**
   - Add `struct Striking: Equatable { let zone: UUID; let start: Date; let times: [Double] }` and an observed `private(set) var striking: Striking?`.
   - Add `func strike(zone: UUID, hour: Int, minute: Int)`:
     - guard on `style.look.strikes`;
     - build the sequence and `playSequence` it;
     - set `striking` with the entries' `at` times;
     - start a cancellable main-actor task that clears `striking` 0.6 s after the last time, unless it changed.
   - `cancelSequence()` also clears `striking` and cancels that task.
10. **MarkerOverlay.swift.** Add `var onStrike: ((UUID) -> Void)? = nil` and `var striking: SceneModel.Striking? = nil`.
    - When `onStrike` is set, attach to the chip button `.simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in … })`. It records `(id, Date())` in `@State` and calls `onStrike(id)`.
    - The button action ignores a tap on that same chip within 2 s of a recorded strike, clearing the record. A long-press therefore strikes without also toggling selection.
    - Add `.accessibilityAction(named: Text("Strike the time")) { onStrike(id) }`.
    - Pass `striking` through to the chip of the matching zone.
11. **MarkerChip.swift.** Add `var strike: SceneModel.Striking? = nil`.
    - When set, wrap the existing body in `TimelineView(.animation)` and apply `scaleEffect(1 + 0.07 · Σ k(t − tᵢ))`, where `t` is seconds since `strike.start` and `k(x) = x ≥ 0 ? exp(−x / 0.09) : 0`.
    - The effect is anchored at the centre, so the chip's position never moves. Without a strike, the body is unchanged.
12. **GlobeScene.swift.**
    - Pass `onStrike` to `MarkerOverlay` only when `scene.style.look.strikes != nil`, plus `striking: scene.striking`.
    - The handler finds the zone, takes `Calendar.current.dateComponents(in: zone.timeZone, from: date)` (the displayed time) and calls `scene.strike(zone:hour:minute:)`.

## Constraints

- Do not change any other theme's files, output, sounds or haptics.
- Do not rename existing `SceneStyle` raw values.
- New fields and parameters are defaulted, so existing call sites and the offline harness compile.
- Shading only. The loupe, guilloché, glints and lume never move geometry; only the existing dent, bump and stretch formulas do. Chips therefore stay on their cities.
- Write no comments anywhere: no `//`, `/* */` or `///`, in Swift or Metal. Names carry the meaning.
- Brace every control-flow body, keeping the codebase's one-line `guard … else { return }` form.
- Use 4-space indentation. Metal helpers are `static` inside `Repeater.metal`.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=repeater .claude/duck/scene-style/harness/render.sh fx-rest fx-pop-london fx-press-held`

## Manual review

1. **Harness renders.** Run `STYLE=repeater .claude/duck/scene-style/harness/render.sh` with no scene names, then open its `sheet.png`. Check that:
   - the terminator is legible and the night side readable;
   - lume is brighter just past the evening terminator than before dawn;
   - coasts are clean at the closest zoom;
   - the loupe shows in `fx-press-held`.
2. **Simulator.**
   - Switch to Repeater in the theme tray: winding clicks, then tic-tac. The continents settle and the night-side lume flashes.
   - Rotate: the guilloché shimmers and the backdrop sheen turns. Idle: nothing moves.
3. **Press.**
   - Hold: the loupe grows, follows a hold-then-drag and shrinks on release.
   - Holding past 0.14 s plays the detent; a quick tap plays only the click.
4. **City chips.**
   - Tap: a gong whose pitch depends on the offset from home. Same-zone cities play the tonic.
   - Long-press: the full repeater for the time the chip shows, also after scrubbing the tape. The chip pulses per strike, and a touch anywhere on the globe stops it.
5. **Tape.**
   - Scrub: ratchet ticks, softer backward and brighter far from now.
   - Midnight plays the date jump; "back to now" plays the flyback.
6. **Fling.** A freewheel buzz that thins out; a touch stops it.
7. **Device only.** Strike haptics are felt with the Silent switch on, and the click and detent haptics feel crisp.

## Out of scope

- A world-time bezel.
- Changes to other themes.
- New `FeedbackCue.Kind` cases.
- Scheduling tape ticks from the glide.
- Persisting anything new.

## Open questions

none
