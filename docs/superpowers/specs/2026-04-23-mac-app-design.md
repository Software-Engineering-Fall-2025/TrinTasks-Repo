# TrinTasks Mac App — Design Spec
**Date:** 2026-04-23
**Branch:** app

---

## Overview

Convert TrinTasks from a Chrome extension into a native macOS menu bar app. The app surfaces Trinity School iCal assignments in a floating panel anchored to the menu bar, with a full-window calendar view, background refresh, and per-assignment notifications. Visual style matches the existing neo-brutalism design exactly.

**Tech stack:** Swift + SwiftUI, `swift-ical` for iCal parsing, Swift Package Manager, direct `.dmg` distribution.

---

## Architecture

Four layers:

### 1. App Shell
- `NSStatusItem` owns the menu bar icon
- Clicking the icon toggles a floating `NSPanel` (no separate dropdown — the panel IS the UI)
- `AppDelegate` owns both the status item and the panel
- `LSUIElement = YES` in Info.plist — app is invisible in the Dock, never fully quits

### 2. Data Layer
- `ICalService` — fetches iCal URL via async `URLSession`, parses via `swift-ical` into `[CalendarEvent]`
- `StorageService` — persists settings and per-event metadata (completion, pin state, reminder offset) to `UserDefaults`, keyed by event `UID`
- `StorageService.merge()` — reconciles fresh iCal events with existing local metadata, preserving completion/pin state across refreshes

### 3. Background Services
- `RefreshService` — `NSBackgroundActivityScheduler` fires on a user-configurable interval (default 30 min), calls `ICalService`, then `StorageService.merge()`
- `NotificationService` — after each refresh, diffs upcoming assignments against scheduled `UNUserNotificationCenter` notifications; cancels stale ones and schedules new ones based on per-assignment reminder offsets

### 4. UI Layer
- All views in SwiftUI
- `ThemeManager: ObservableObject` injected via `.environmentObject()` — all views react instantly on theme change
- `BrutalStyle` enum defines design tokens used in a shared `ViewModifier`:
  - `borderWidth: 2pt`
  - `shadowOffset: (3, 3)`
  - `cornerRadius: 4pt`
  - Font: Inter (bundled, matches extension's primary font-family)

---

## Views

| View | Responsibility |
|---|---|
| `ContentView` | Root layout — top bar + week grid + sidebar |
| `WeekView` | 7-column day grid, week navigation |
| `DayView` | Single day column with stacked assignment cards |
| `AssignmentCard` | Card with subject color, title, due date, checkbox, long-press action menu |
| `SidebarView` | Collapsible right panel for pinned/major assignments |
| `SettingsView` | Theme picker, refresh interval, iCal URL, subject color overrides |

**Top bar:** iCal URL input, refresh button, today button, week nav arrows, week-view toggle.

**AssignmentCard action menu** (long-press): pin, set reminder, mark complete — mirrors the current extension's right-click context menu.

---

## Data Flow

```
NSBackgroundActivityScheduler
  → RefreshService.refresh()
    → ICalService.fetch(url:) → [CalendarEvent]
    → StorageService.merge([CalendarEvent])
      → @Published assignments updated
        → SwiftUI views re-render

User interaction (pin / complete / reminder)
  → StorageService.update(uid:metadata:)
    → NotificationService.sync()
```

The iCal feed is the source of truth. `UserDefaults` stores only overlay metadata (completion, pin, reminder offset) and app settings.

---

## Themes

Seven themes ported from the extension, including dynamic "Serenity" (time-based color shifting). Each theme is a `Theme` struct with named color tokens. `ThemeManager` publishes the active theme.

---

## Project Structure

```
TrinTasksApp/
├── App/
│   ├── TrinTasksApp.swift        # @main entry point
│   ├── AppDelegate.swift         # NSStatusItem + NSPanel ownership
│   └── MenuBarController.swift   # Icon, toggle logic
├── Views/
│   ├── ContentView.swift
│   ├── WeekView.swift
│   ├── DayView.swift
│   ├── AssignmentCard.swift
│   ├── SidebarView.swift
│   └── SettingsView.swift
├── Models/
│   ├── Assignment.swift
│   ├── CalendarEvent.swift
│   └── AppSettings.swift
├── Services/
│   ├── ICalService.swift
│   ├── RefreshService.swift
│   ├── NotificationService.swift
│   └── StorageService.swift
├── Themes/
│   ├── ThemeManager.swift
│   ├── Theme.swift
│   └── Themes/                   # 7 theme definitions
├── Style/
│   └── BrutalStyle.swift         # Design tokens + ViewModifier
└── Resources/
    ├── Assets.xcassets
    ├── Inter.ttf
    └── Info.plist
```

---

## Build & Distribution

- **Minimum macOS:** 13.0 (Ventura)
- **Dependency:** Swift iCal parsing library via Swift Package Manager (evaluate `swift-ical`, `IcalParser`, or similar at implementation time — choose the most actively maintained option that handles RRULE and VTIMEZONE)
- **Entitlements:** `com.apple.security.network.client`, `com.apple.security.notifications`
- **Signing:** Developer ID (for direct distribution, Gatekeeper compatibility)
- **Packaging:** `.dmg` via `create-dmg` CLI
- **Auto-launch:** `LaunchAgent` plist dropped in `~/Library/LaunchAgents/` so the menu bar icon appears on login

---

## Out of Scope

- App Store submission
- iCloud sync
- iOS / iPadOS version
- System calendar (EventKit) integration — iCal URL fetch is the only data source
