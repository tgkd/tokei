# Copilot Instructions for tokei

## Project Overview
- SwiftUI iOS app (`tokei/`) paired with multiple WidgetKit extensions (`tokeiWidget/`).
- Main view `ContentView.swift` drives world clock management; widgets render summarized time zone data via `TokeiWidgetEntryView.swift`.
- Shared logic for time zones lives in `TimeZoneModels.swift`; both app and widgets depend on these computed helpers.

## State & Persistence
- Time zones persist through an app-group user defaults suite (`UserDefaults.shared` using `group.tokei.widget`). Always write through `UserDefaults.shared` so data flows to widgets.
- Saved time zones are JSON-encoded `TimeZoneInfo` arrays under `saved_timezones`; the global offset lives under `time_offset_minutes`. Reuse existing `saveTimeZones()` / `loadTimeZones()` helpers to stay consistent.
- Every state mutation that should surface in widgets must call `WidgetCenter.shared.reloadTimelines(ofKind: ...)`; see `ContentView.updateWidget()` and the App Intents for examples.

## Time Zone Modeling
- `TimeZoneInfo` owns all presentation formatting (time strings, relative descriptions, dynamic colors/scales). Extend these computed props rather than duplicating date logic elsewhere.
- The drag-and-drop list relies on `TimeZoneInfo` conforming to `Transferable`; preserve Codable/Identifiable requirements when modifying the struct.
- Default seeds come from `TimeZoneInfo.defaultTimeZones`; new defaults should stay small and globally diverse to fit widget layouts.

## UI Patterns
- `ContentView` uses a floating footer with animated toggle state (`showSlider`, `showSliderContent`) controlling a 15-minute-step slider. Keep animation timings aligned if adjusting the interaction.
- The add-time-zone sheet filters `TimeZoneInfo.allAvailableTimeZones`; maintain the lowercase `searchableText` convention for responsive searches.
- Widget layouts have dedicated view structs grouped in `TokeiWidgetEntryView.swift`. When adjusting typography or counts, update small/medium/large variants together to avoid layout drift.

## Widgets & App Intents
- Three widget families (`TokeiWidget`, `TokeiCompactWidget`, `TokeiMinimalWidget`) share the same `Provider`. Any timeline change should keep entries lightweight—currently 60 minute-by-minute entries.
- App Intents in `TokeiAppIntents.swift` mutate user defaults and trigger timeline reloads. Reuse these intents for widget buttons or Siri shortcuts rather than wiring new persistence paths.
- `tokeiWidgetControl.swift` and `tokeiWidgetLiveActivity.swift` are scaffolds; if reactivating, align their identifiers with existing App Group data.

## Build & Run
- Primary scheme: `tokei`; widget extension scheme: `tokeiWidgetExtension`. To build via CLI, run `xcodebuild -scheme tokei -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Widgets require running on iOS 17+ simulators with the same app-group entitlements enabled. After changing entitlements (`tokei.entitlements`, `tokeiWidgetExtension.entitlements`), clean the build folder to refresh provisioning.

## Testing & Debugging
- No automated tests yet; rely on Xcode previews (SwiftUI preview blocks) plus simulator runs. When debugging widget timelines, use `WidgetCenter.shared.reloadAllTimelines()` in the debugger or trigger `RefreshTimeZonesIntent`.
- Time calculations depend on the device clock; if validating day transitions, adjust `time_offset_minutes` through the UI or via `AdjustTimeIntent` to simulate offsets.
