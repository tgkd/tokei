# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Environment

This is a SwiftUI iOS application project built with Xcode. The project follows standard iOS app development patterns.

## Build Commands

- **Build**: Use Xcode's Command+B or Product > Build
- **Run**: Use Xcode's Command+R or Product > Run  
- **Test**: Use Xcode's Command+U or Product > Test (if tests are added)
- **Clean**: Use Xcode's Shift+Command+K or Product > Clean Build Folder

## Project Structure

- `tokei/` - Main application source code directory
  - `tokeiApp.swift` - Main app entry point with @main attribute
  - `ContentView.swift` - Primary view containing the app's UI
  - `Assets.xcassets/` - App icons, colors, and other visual assets
- `tokei.xcodeproj/` - Xcode project configuration and build settings

## Architecture

This is a minimal SwiftUI application with:
- Single-view architecture using ContentView as the main interface
- Standard iOS app lifecycle managed by tokeiApp struct
- SwiftUI declarative UI framework for view rendering
- Assets managed through Xcode's asset catalog system

## Key Development Notes

- Uses SwiftUI framework for UI development
- App follows standard iOS app structure with App and View protocols
- Asset management handled through Xcode's asset catalog (Assets.xcassets)
- Project uses modern Xcode project format with PBXFileSystemSynchronizedRootGroup