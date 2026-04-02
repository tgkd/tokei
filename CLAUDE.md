# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Tokei is a SwiftUI iOS world clock app featuring an interactive 3D Earth globe (RealityKit) with city markers and a WidgetKit extension offering multiple widget styles. Users add/remove time zones, view them on the globe, and use a time-offset slider to preview different times. Requires iOS 17+.

## Build Commands

Xcode-only project. No SPM, CocoaPods, or other package managers.

- **Build/Run/Test in Xcode:** Cmd+B / Cmd+R / Cmd+U
- **CLI build:** `xcodebuild -scheme tokei -destination 'platform=iOS Simulator,name=iPhone 16' build`
- **Widget scheme:** `tokeiWidgetExtension` (requires same app-group entitlements)
- **No automated tests.** Use SwiftUI previews and simulator runs. Debug widget timelines via `WidgetCenter.shared.reloadAllTimelines()` or `RefreshTimeZonesIntent`.
- After changing entitlements (`tokei.entitlements`, `tokeiWidgetExtension.entitlements`), clean the build folder to refresh provisioning.

## Architecture

### Main App (`tokei/`)

- **tokeiApp.swift** — App entry point. Handles `tokei://` deep links and triggers widget reloads.
- **ContentView.swift** — Root view: full-screen 3D globe with floating glass-effect buttons (location reset, clock list) and a time-offset slider at the bottom. Opens `TimeZoneListView` as a sheet. Defines `UserDefaults.shared` (suite: `group.tokei.widget`).
- **EarthGlobeView.swift** — RealityKit-based 3D globe (`RealityView` + `GlobeController`). Uses a custom Metal shader (`EarthDayNight.metal`) via `CustomMaterial` for day/night rendering with PBR fallback. Sun position derived from UTC time + Earth's axial tilt. Earth Y-axis rotation synced to current time (plus offset). City markers at lat/lon with billboard text cards (tap to reveal). Camera orbiting via pan/pinch gestures with inertia.
- **EarthDayNight.metal** — Metal surface shader blending day texture (base_color) and night texture (emissive_color) based on sun direction passed via `custom_parameter`.
- **TimeZoneModels.swift** — `TimeZoneInfo` (Codable, Transferable, Identifiable) is the core data model. `SearchableTimeZone` for search UI. All time formatting, offset calculation, and day-difference logic lives here—extend these computed props rather than duplicating date logic.
- **TimeZoneCoordinates.swift** — Static lat/lon lookup for all IANA timezone identifiers plus legacy aliases.
- **TimeZoneListView.swift** — List of saved time zones with drag-to-reorder, swipe-to-delete, and add-timezone sheet.

### Widget Extension (`tokeiWidget/`)

Three widget styles registered in `tokeiWidgetBundle.swift`, all sharing the same `Provider`:
- **TokeiWidget** — Standard world clock (small/medium/large)
- **TokeiCompactWidget** — Compact horizontal layout (small/medium)
- **TokeiMinimalWidget** — Single/dual timezone focus (small/medium)

Widget views in `TokeiWidgetEntryView.swift`. Provider (`TokeiWidgetProvider.swift`) generates 60 minute-by-minute timeline entries. Widget buttons use AppIntents (`TokeiAppIntents.swift`) for time adjustment. When adjusting widget layouts, update small/medium/large variants together to avoid layout drift.

### Shared State

App and widget share data via **App Group** `group.tokei.widget`:
- `UserDefaults.shared` (suite: `group.tokei.widget`) — defined in `ContentView.swift`, also used in `TokeiWidgetProvider.swift`
- Key `saved_timezones`: JSON-encoded `[TimeZoneInfo]`
- Key `time_offset_minutes`: `Int` for time travel offset

**Important:** Every state mutation that should surface in widgets must call `WidgetCenter.shared.reloadTimelines(ofKind: ...)`. Reuse existing AppIntents in `TokeiAppIntents.swift` for widget buttons or Siri shortcuts rather than creating new persistence paths.
