# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Style Rules

- **Maximum file length**: Keep all code files under 400 lines. If a file grows beyond this, refactor it into smaller, focused modules.

## Build Commands

```bash
# Build the project
xcodebuild -project Promptlet.xcodeproj -scheme Promptlet build

# Build and run
xcodebuild -project Promptlet.xcodeproj -scheme Promptlet run

# Build for release
xcodebuild -project Promptlet.xcodeproj -configuration Release build

# Clean build
xcodebuild -project Promptlet.xcodeproj -scheme Promptlet clean
```

## Architecture Overview

Promptlet is a macOS menu bar application built with SwiftUI for managing and inserting text prompts via a command palette interface.

### Core Architectural Flow

```
AppDelegate (NSApplicationDelegate)
├── Coordinates between controllers and data models
│
├── Controllers (Modular functionality)
│   ├── MenuBarController
│   │   └── Manages status item and menu
│   ├── KeyboardController
│   │   └── Handles global/local hotkeys and events
│   └── WindowController
│       └── Manages palette and settings windows
│
├── Data Models (Observable state)
│   ├── PromptStore
│   │   └── Data persistence, search, filtering
│   ├── PaletteController
│   │   └── Navigation and selection state
│   └── AppSettings
│       └── User preferences and themes
│
└── Views (SwiftUI)
    ├── SimplePaletteView
    │   └── Command palette interface
    └── SettingsView
        └── Preferences window
```

### Key Cross-File Dependencies

1. **Window Management**: AppDelegate creates and positions the palette window, which hosts SimplePaletteView via NSHostingView
2. **Text Insertion Flow**: AppDelegate saves previousApp → hides palette → restores focus → simulates Cmd+V via CGEvents
3. **Data Flow**: PromptStore publishes changes → SimplePaletteView observes → PaletteController manages selection
4. **Variable System**: Prompt.renderedContent() processes Variable instances, replacing `{{variable}}` placeholders
5. **Enhancement System**: Enhancement model determines text placement (cursor/top/bottom/wrap) during insertion

### Critical Implementation Details

- **Focus Management**: Must hide palette before restoring focus to previous app, otherwise text insertion fails
- **Keyboard Events**: Uses both global (when app inactive) and local (when app active) event monitors
- **Accessibility API**: Required for cursor position detection via AXUIElement
- **Window Type**: NSPanel with HUD style for proper floating behavior
- **Persistence**: All data stored in UserDefaults as JSON-encoded arrays

### Project Configuration

- **Bundle ID**: `justjoshing.Promptlet`
- **Deployment Target**: macOS 14.0+
- **Sandbox**: Enabled with Accessibility and Apple Events permissions
- **LSUIElement**: Set to true (menu bar app without dock icon)
- **Development Team**: Z69AA836Q7

### Required Permissions

The app requires these permissions to function:
1. Accessibility access (for cursor position and text insertion)
2. Apple Events (for sending keystrokes to other apps)

Both are configured in Info.plist with usage descriptions.