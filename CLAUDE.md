# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Tokei is a SwiftUI iOS world clock app featuring an interactive 3D Earth globe (SceneKit) with city markers and a WidgetKit extension offering multiple widget styles. Users add/remove time zones, view them on the globe, and use a time-offset slider to preview different times.

## Build Commands

This is an Xcode-only project. Build, run, and test through Xcode (Cmd+B / Cmd+R / Cmd+U). There is no CLI build system or package manager (no SPM, CocoaPods, etc.).

## Architecture

### Main App (`tokei/`)

- **tokeiApp.swift** - App entry point. Handles `tokei://` deep links and triggers widget reloads.
- **ContentView.swift** - Root view: hosts the 3D globe full-screen with a bottom info card. Tapping the card opens `TimeZoneListView` as a sheet. Loads saved time zones from shared `UserDefaults`.
- **EarthGlobeView.swift** - SceneKit-based 3D globe wrapped via `UIViewRepresentable` (`OrbitingSceneView`). Features:
  - Physically-based earth rendering with day/night textures (`EarthDay`, `EarthNight` in assets)
  - Sun position calculated from real UTC time and Earth's axial tilt
  - Earth Y-axis rotation synced to current UTC time (plus optional offset)
  - City markers placed at lat/lon coordinates with billboard text cards (tap to reveal)
  - Camera orbiting via pan/pinch gestures with inertia, double-tap to reset to local timezone
- **TimeZoneModels.swift** - `TimeZoneInfo` (Codable, Transferable) is the core data model. `SearchableTimeZone` is used for the add-timezone search UI. Contains all time formatting, offset calculation, and day-difference logic.
- **TimeZoneCoordinates.swift** - Static lat/lon lookup for all IANA timezone identifiers, plus legacy aliases.
- **TimeZoneListView.swift** - List of saved time zones with drag-to-reorder, swipe-to-delete, add sheet, and a floating time-offset slider (adjusts `time_offset_minutes` in UserDefaults).

### Widget Extension (`tokeiWidget/`)

Three widget styles registered in `tokeiWidgetBundle.swift`:
- **TokeiWidget** - Standard world clock (small/medium/large)
- **TokeiCompactWidget** - Compact horizontal layout (small/medium)
- **TokeiMinimalWidget** - Single/dual timezone focus (small/medium)

Widget views are in `TokeiWidgetEntryView.swift`. The provider (`TokeiWidgetProvider.swift`) generates 60 minute-by-minute timeline entries. Widget buttons use AppIntents (`TokeiAppIntents.swift`) for time adjustment (+/-30 min, reset, refresh).

### Shared State

App and widget share data via **App Group** `group.tokei.widget`:
- `UserDefaults.shared` (suite: `group.tokei.widget`) - defined in both `ContentView.swift` and `TokeiWidgetProvider.swift`
- Key `saved_timezones`: JSON-encoded `[TimeZoneInfo]`
- Key `time_offset_minutes`: `Int` for time travel offset

### URL Scheme

`tokei://main`, `tokei://timezones`, `tokei://manage` - handled in `tokeiApp.swift` (currently stub implementations).
