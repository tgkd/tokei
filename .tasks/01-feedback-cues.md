# Task: Contextual cues, cancelable sound sequences with paired haptics, and fling click trains

## Goal

The feedback layer gains the hooks that four upcoming themes use. Every existing theme must sound and feel exactly as it does today. The hooks:

1. A cue can carry context: a pitch, a scrub direction, a tension level, or the surface under the finger. A timbre can render variants for that context lazily.
2. A timed sequence of sound designs plays as one mixed buffer, with an optional Core Haptics pattern built from the same schedule, and can be cancelled.
3. A fling schedules a click train from the inertia curve, for timbres that define one.
4. A press cue is cut when the press is released before a theme-defined time.
5. A theme can opt into a press-following haptic curve, and can attach a fixed sequence to every city pop.

## Files

- tokei/Feedback/FeedbackCue.swift (modify)
- tokei/Feedback/SoundSynth.swift (modify)
- tokei/Feedback/SoundBoard.swift (modify)
- tokei/Feedback/SoundOutput.swift (modify)
- tokei/Feedback/WobbleHaptics.swift (modify)
- tokei/Feedback/FeedbackPlayer.swift (modify)
- tokei/Globe/EffectTuning.swift (modify)
- tokei/Globe/Looks/SceneLook.swift (modify)
- tokei/Globe/SceneModel.swift (modify)
- tokei/Globe/GlobeScene.swift (modify)
- tokei/Clock/TimeTape.swift (modify)
- tokei/Feedback/SoundLayers.swift (read: layer types, `SoundSynth.Random`)
- tokei/Globe/Looks/MagmaSound.swift (read: a design-based timbre)
- tokei/Globe/CameraMotion.swift (read: inertia formula)
- tokei/Globe/TerrainGrid.swift, tokei/Globe/ToySurface.swift (read: CPU coast sampling)
- Shared/ZoneClock.swift (read: `offsetMinutes(of:from:at:)`)

## Context

- **The cue path today.**
  1. `SceneModel.emit(_:)` builds `FeedbackCue(kind:style:)` and stores it in `cue`. `RootView` turns `cue.haptic` into `.sensoryFeedback`.
  2. It calls `FeedbackPlayer.play(_:style:soundEnabled:volume:)`, which calls `SoundBoard.play(_:timbre:volume:)`.
  3. `SoundBoard` picks a random pre-rendered variant, never the same one twice in a row. `SoundOutput.play(_:voice:volume:)` schedules it with `.interrupts` on the least-busy of 8 `AVAudioPlayerNode` voices, on its own serial queue.
- **Libraries.** `SoundSynth.samples(timbre:rate:)` renders every `FeedbackCue.Kind` not in `timbre.silent`, with `timbre.variants(of:)` variants each. Each variant is seeded by `timbre.seed(kind:variant:)`, where `kind` is the index in `FeedbackCue.Kind.allCases`. Rendering happens once per timbre in `SoundBoard.prepare`, on a detached task.
- **Designs.**
  - A design-based timbre returns a `SoundSynth.Design` (layers, a loudness `level` in dB, a high-pass `floor`).
  - `SoundSynth.render` normalises each design to its level, measured through a 400 Hz high-pass, and soft-limits peaks with the private `limited` to `ceiling` (0.7).
  - Shape-based timbres such as `.soft` and `.metal` only reshape the base voices from `SoundSynth.voice(for:)`.
- **Waiting and idling.** `SoundBoard.waiting` holds one request while a timbre renders, and plays it if the render finishes within `waitLimit` (0.3 s). `busyUntil` per voice plus `schedulePause()` pause the engine 10 s after the last sound ends.
- **Haptics.** `WobbleHaptics` uses Core Haptics (`playsHapticsOnly`). `play(following:)` plays a continuous intensity curve sampled from a `Spring`; the release cue uses it. `tick(intensity:sharpness:)` plays one transient for drag grains. Discrete cue haptics come from `FeedbackCue.haptic` via SwiftUI.
- **Fling.**
  - GlobeScene's rotation drag `.onEnded` calls `scene.coast(yawVelocity:pitchVelocity:)`, then `scene.fling(axis:speed:)`.
  - `CameraMotion.inertia` moves the camera by `velocity · τ · (1 − e^(−t/τ))`, with `τ = CameraMotion.inertiaTime` (0.45 s). It ends when the speed falls to 0.01 rad/s.
  - `SceneModel.interruptCamera()` runs when a rotation drag, a pinch or a surface drag starts. `fly(to:)` replaces any motion.
- **Press.**
  - GlobeScene calls `scene.press(at:footprint:)` at touch-down on the globe (never on a chip) and `scene.releasePress(moved:)` at touch-up.
  - A hold-then-drag ends with `endSurfaceDrag()` instead.
  - Under Reduce Motion, `press(at:)` emits the cue but creates no `effects.press` record, and `releasePress` returns early at its `guard`.
- **Pops.** GlobeScene's `.onChange(of: store.selection)` calls `scene.pop(at:)` with the selected zone's `location.unitVector`. GlobeScene's `date` property is the displayed time (now plus the shift). `store.homeZone` is the reference zone. `ZoneClock.offsetMinutes(of:from:at:)` returns a zone's offset from another in minutes. A cloud tap in the Weather theme also calls `pop(at:)`.
- **Tape ticks.** `TimeTape`'s `.onChange(of: hourIndex) { old, new in … }` emits `.dayTick` at the home zone's local midnight and `.tick` otherwise. `shift` there is in minutes, within ±72 h.
- **Coast on the CPU.** `renderer?.toyMesh?.shapes[shape]?.surface.coast.sample(direction)` returns the coast signed distance in degrees, positive on land. Shapes may not be loaded yet, so treat nil as unknown.
- **Build settings.** Swift 5 language mode, iOS 26 deployment target. An `@Sendable` closure that captures a non-Sendable value is a warning, and the build must stay warning-free. Build designs inside `@Sendable` closures on the render task, as `SoundTimbre.design` does, and capture only plain values.
- **Offline render harness.** It lives in `.claude/duck/scene-style/harness` (gitignored, present in this working copy) and is compiled on macOS. It compiles `SoundSynth.swift`, `SoundLayers.swift`, `FeedbackCue.swift` and everything under `tokei/Globe` except `GlobeScene`, `SceneModel`, `MarkerOverlay`, `MarkerChip`, `ChipMetrics` and a few other views. Any type that those compiled files reference must therefore live in them, or under `tokei/Globe`, and must not import UIKit.

## Plan

1. **FeedbackCue.swift.**
   - Add `struct CueContext: Hashable, Sendable` with:
     - `enum Surface: Hashable, Sendable { case land, sea }`
     - `var pitch: Int?` (semitones from the home tonic, −12…11)
     - `var direction = 0` (+1 forward, −1 backward)
     - `var tension = 0` (0…3)
     - `var surface: Surface?`
     - `static let none = CueContext()`
     - `var seed: UInt64`, computed deterministically by packing the fields into bytes: `(pitch ?? 99) + 128`, `direction + 2`, `tension`, and a surface code. Never use `hashValue`, which changes on every launch.
   - Add `var context: CueContext = .none` to `FeedbackCue`, so `FeedbackCue(kind:style:)` still compiles.
2. **SoundSynth.swift.**
   - Add `struct SoundSequence: Sendable` with:
     - nested `struct HapticTick: Sendable { var intensity: Float; var sharpness: Float }`
     - nested `struct Entry: Sendable { var at: Double; var gain = 1.0; var design: (@Sendable (inout SoundSynth.Random) -> SoundSynth.Design)?; var haptic: HapticTick? }`
     - `var entries: [Entry]` and `var seed: UInt64 = 0`
   - Add `struct SoundTrain: Sendable` with `var spacing: Double` (radians of camera travel per click), `var limit: Int`, `var haptics: Int` (how many leading clicks also tick haptically), `var sharpness: Float`, and `var design: @Sendable (Double, inout SoundSynth.Random) -> SoundSynth.Design`. The `Double` is the instantaneous speed fraction, 0…1.
   - `SoundTimbre` gains two stored properties:
     - `contextual: (@Sendable (FeedbackCue.Kind, CueContext, inout SoundSynth.Random) -> SoundSynth.Design?)?`
     - `train: SoundTrain?`

     The shape-based init sets both to nil. The design-based init gains `contextual: … = nil, train: SoundTrain? = nil` as its last two parameters, after `design`, so every existing trailing-closure call site still binds its closure to `design`.
   - Add `static func contextualSamples(timbre: SoundTimbre, kind: FeedbackCue.Kind, context: CueContext, rate: Double) -> [[Float]]`.
     - It renders `timbre.variants(of: kind)` variants through `timbre.contextual` with `render`.
     - The seed is `timbre.seed(kind: index, variant: variant) ^ context.seed`, where `index` is the kind's position in `allCases`.
     - It returns `[]` when the closure returns nil.
   - Add `static func mix(_ sequence: SoundSequence, rate: Double) -> [Float]`.
     - It renders each entry's design with `render`, seeded `sequence.seed ^ UInt64(index)`, and adds it at `Int(at * rate)` scaled by `gain`.
     - It passes every sample through the soft limiter and fades the last 4 ms, as `render` does.
     - Remove `private` from `limited` so `mix` can reuse it.
3. **SoundOutput.swift.** Add `func stop(voice slot: Int)`, which stops that player node on the serial queue. `play` already restarts a node that is not playing.
4. **SoundBoard.swift.**
   - Add `struct SoundTicket: Hashable { let voice: Int; let serial: Int }`. The board keeps a serial counter, a `voiceSerial: [Int]` per voice, and a set of serials cancelled while still rendering.
   - `play(_ kind:timbre:volume:context: CueContext = .none)` becomes `@discardableResult` and returns `SoundTicket?`.
     - When `context != .none` and `timbre.contextual` is non-nil, it uses a cache keyed by timbre, kind and context.
     - On a cache miss, first call `timbre.contextual` once with a scratch `SoundSynth.Random`; building a `Design` is cheap and renders nothing. If that returns nil, cache an empty entry and play from the regular library right away, so the call still returns a ticket. Only when it returns a design, render with `contextualSamples` on a detached task, store the result, and play it only if it finishes within `waitLimit` of the request.
     - An empty contextual result falls back to the regular library.
     - Every other call behaves exactly as today. Whenever a buffer is scheduled on a voice, record `voiceSerial[slot]` and return the ticket.
   - Add `@discardableResult func play(sequence: SoundSequence, timbre: SoundTimbre, volume: Float = 1) -> SoundTicket?`.
     - It requires `wantsRunning` and reserves a serial at once.
     - It renders `SoundSynth.mix` on a detached task, then, unless the serial was cancelled meanwhile, plays the buffer on the least-busy voice exactly like a cue (updating `busyUntil` and `schedulePause()`).
     - It returns the reserved ticket.
   - Add `func cancel(_ ticket: SoundTicket)`.
     - If `voiceSerial[ticket.voice] == ticket.serial`, call `output.stop(voice:)` and set `busyUntil[ticket.voice]` to now.
     - Otherwise, if it is still rendering, add it to the cancelled set.
5. **WobbleHaptics.swift.**
   - Add `func play(_ ticks: [(time: Double, tick: SoundSequence.HapticTick)]) -> (any CHHapticPatternPlayer)?`. It builds one pattern of transient events at those relative times and starts it immediately, as `tick` does.
   - Add `func stop(_ player: (any CHHapticPatternPlayer)?)`, which stops at `CHHapticTimeImmediate`.
6. **FeedbackPlayer.swift.**
   - Add `struct FeedbackTicket { var sound: SoundTicket?; var haptics: (any CHHapticPatternPlayer)? }`.
   - `play(_ cue:style:soundEnabled:volume:)` becomes `@discardableResult`, returns the `SoundTicket?` from `SoundBoard`, and passes `cue.context`. When `cue.kind == .press` and `style.effects.press.followHaptic` is true, it also calls `wobble.play(following: style.effects.press.pressSpring)`.
   - Add `func play(_ sequence: SoundSequence, style: SceneStyle, soundEnabled: Bool) -> FeedbackTicket`.
     - Haptics always play, as the release wobble does: the entries that carry `haptic`, at their `at`.
     - Sound plays through `play(sequence:timbre:)` only when the style has a timbre, sound is enabled, and at least one entry has a design. A haptic-only sequence never touches the audio engine.
   - Add `func train(_ train: SoundTrain, speed: Double, style: SceneStyle, soundEnabled: Bool) -> FeedbackTicket`. It builds a `SoundSequence` and plays it like the method above.
     - With `τ = CameraMotion.inertiaTime`, click `k` for `k` in 1…min(`train.limit`, ⌊τ·speed / spacing⌋) sits at `t_k = −τ · ln(1 − k·spacing / (τ·speed))`.
     - Its speed fraction is `f_k = min(speed · e^(−t_k/τ) / 10, 1)`.
     - The entry's design is `train.design(f_k, &random)`, its gain is `0.35 + 0.65·f_k`, and the first `train.haptics` entries carry a haptic tick of intensity `0.2 + 0.5·f_k` at `train.sharpness`.
   - Add `func cancel(_ ticket: FeedbackTicket?)`, which cancels the sound ticket and stops the haptic player.
7. **EffectTuning.swift.** `Press` gains `var cutoff: Double? = nil` and `var followHaptic = false`, last and defaulted, so every existing `Press(...)` call compiles.
8. **SceneLook.swift.** Add `var popEcho: SoundSequence?` after `petalDrift` (defaulted to nil by the memberwise init).
9. **SceneModel.swift.**
   - `emit(_:context:)` becomes `@discardableResult func emit(_ kind: FeedbackCue.Kind, context: CueContext = .none) -> SoundTicket?`. It puts the context into the `FeedbackCue` and returns `feedback.play(...)`.
   - New `@ObservationIgnored` state: `pressStart: Date?`, `pressTicket: SoundTicket?`, `trainTicket: FeedbackTicket?`, `sequenceTicket: FeedbackTicket?`.
   - Add `func playSequence(_ sequence: SoundSequence)`: `cancelSequence()`, then `sequenceTicket = feedback.play(sequence, style:, soundEnabled:)`.
   - Add `func cancelSequence()`, which cancels `sequenceTicket` and sets it to nil.
   - Add `private func surface(at point: SIMD3<Double>) -> CueContext.Surface?`: `.land` when the current shape's coast sample is > 0, `.sea` otherwise, nil when the style has no mesh or the shape is not loaded.
   - `press(at:footprint:)`:
     - Call `cancelSequence()` first.
     - Emit `.press` with `CueContext(surface: surface(at: point))`.
     - Store `pressStart = Date()` and the returned ticket in `pressTicket`.
   - `releasePress(moved:)`: before its existing `guard`, if `style.effects.press.cutoff` is set and `pressStart` is less than the cutoff ago, cancel `pressTicket`. Then clear `pressStart`. Do the same at the top of `endSurfaceDrag()`.
   - `pop(at:)` becomes `pop(at point: SIMD3<Double>, context: CueContext = .none)`:
     - Call `cancelSequence()`, then emit `.pop` with the context.
     - If `style.look.popEcho` is set, play it with `playSequence`.
     - The rest is unchanged.
   - `beginSurfaceDrag`: call `cancelSequence()`. It already calls `interruptCamera()`.
   - `interruptCamera()`: at its top, before the guard, cancel `trainTicket` (set it to nil) and call `cancelSequence()`. Any touch on the globe stops a running sequence.
   - `fly(to:duration:arc:)`: cancel `trainTicket`.
   - `coast(yawVelocity:pitchVelocity:)`: when it assigns a new `cameraMotion` and `style.soundTimbre?.train` is set, cancel any previous train, then call `trainTicket = feedback.train(train, speed: hypot(yawVelocity, pitchVelocity), style: style, soundEnabled: soundEnabled)`.
   - `isForeground` becoming false: cancel the sequence and the train.
10. **GlobeScene.swift.** In `.onChange(of: store.selection)`, look up the selected zone and compute its offset from `store.homeZone` at `date` with `ZoneClock.offsetMinutes`. Divide by 60, round to whole hours, and fold into −12…11 (`((h % 24) + 24) % 24`, minus 24 when ≥ 12). Call `scene.pop(at: location.unitVector, context: CueContext(pitch: pitch))`.
11. **TimeTape.swift.** Emit with `CueContext(direction: new > old ? 1 : -1, tension: min(Int(abs(shift) / (18 * 60)), 3))`.

## Constraints

- No timbre in the repo defines `contextual`, `train` or `popEcho`, and no tuning sets `cutoff` or `followHaptic`. Existing themes must render, sound and feel exactly as before, so no existing look, sound or tuning file changes.
- Every new parameter is defaulted and every changed return value is `@discardableResult`, so existing call sites compile unchanged. That includes the offline harness, which constructs `GlobeFrame`, `SceneLook` and `EffectTuning` values.
- Write no comments anywhere: no `//`, `/* */` or `///`. Names carry the meaning.
- Brace every control-flow body, and keep the codebase's one-line `guard … else { return }` form.
- Match the neighbouring code:
  - 4-space indentation;
  - `private` helpers;
  - no force unwraps where the neighbouring code avoids them;
  - main-actor classes stay main-actor;
  - audio work stays on `SoundOutput`'s queue or on detached tasks, never on the main thread beyond scheduling.
- Do not add `FeedbackCue.Kind` cases. Do not change `SoundSynth.voice(for:)`, any existing timbre, or `FeedbackCue.haptic`.
- Surgical changes only. Touch nothing outside Files without a stated reason.
- The work is writing the code in Plan and running the commands in Acceptance. Nothing else: do not start the app or a dev server, do not open a browser, do not take screenshots, do not write or run tests or scripts that are not listed in Plan, do not mock or call any API. When the Acceptance commands pass, stop.

## Acceptance

- `mkdir -p build && xcodebuild -project tokei.xcodeproj -scheme tokei -destination 'generic/platform=iOS Simulator' -quiet build > build/acceptance.log 2>&1`
- `! grep -E 'warning:|error:' build/acceptance.log | grep -v 'CFBundleVersion of an app extension'`
- `STYLE=ice .claude/duck/scene-style/harness/render.sh fx-rest fx-snow`

## Manual review

- In the simulator, with sound on, in Toy, Ice and Sakura: tap a city chip, scrub the tape across midnight, press and release on the globe, and fling.
  - Every sound and timing should match the build before this change.
  - No timbre uses context yet, so pitch and direction are ignored.
- Nothing new is audible until a theme adopts the hooks (`.tasks/03-theme-repeater.md` and later).

## Out of scope

- Any theme's designs, tunings or haptics.
- New `FeedbackCue.Kind` cases.
- Sample-accurate tape ticks during glides (scheduling from `ShiftGlide`).
- Visual effects.

## Open questions

none
