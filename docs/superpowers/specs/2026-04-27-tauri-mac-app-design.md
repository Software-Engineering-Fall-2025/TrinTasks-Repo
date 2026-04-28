# TrinTasks Tauri Mac App — Design Spec

**Date:** 2026-04-27  
**Status:** Approved

---

## Overview

Replace the in-progress Swift macOS app with a Tauri 2 application that wraps the existing Chrome extension frontend (vanilla JS/HTML/CSS) with a minimal Rust backend. The app lives in the Mac menu bar, opens a floating window on click, and ships as a `.dmg` for distribution outside the App Store.

---

## Architecture

Two layers:

**Rust backend (`src-tauri/`)** — system-level concerns only:
- Tray icon with toggle and quit context menu
- Window lifecycle (show/hide on tray click, hide on focus loss)
- Background timer: emits `refresh-ical` event to frontend every 30 minutes
- Reminder scheduler: holds scheduled reminders in memory, checks every minute, fires system notifications via `tauri-plugin-notification`

**Web frontend (`ui/`)** — existing Chrome extension files with minimal changes:
- All UI, parsing, theming, drag-drop, weather effects: zero changes
- Storage layer updated to use `tauri-plugin-store`
- Background service worker replaced by a small Tauri event listener file
- One new file: `tauri-listeners.js`

No build tool (Webpack/Vite) is needed. Tauri serves static HTML/JS/CSS directly.

---

## Menu Bar & Window Behavior

- Tray icon: `icon-128.png` resized to 22×22, sits in top-right menu bar
- Left-click tray icon: toggles floating window (show/hide)
- Window: frameless, 800×600, positioned just below the tray icon
- Clicking outside the window hides it (does not close — state preserved)
- No Dock icon (`LSUIElement = true` in app plist)
- Right-click tray: context menu with **Show/Hide** and **Quit TrinTasks**
- First launch with no saved iCal URL: setup screen shown; subsequent launches go straight to main view

---

## Chrome API Replacements

### Storage
- `chrome.storage.local` → `tauri-plugin-store`
- Persistent JSON file on disk
- JS API is nearly identical (async get/set); ~15 call sites updated in `storage-manager.js`

### Background Refresh
- `chrome.alarms` (30-min refresh) → Rust interval timer
- Rust emits `"refresh-ical"` Tauri event every 30 minutes
- Frontend listens in `tauri-listeners.js` and calls existing `ICalParser.fetchAndParse()`

### Reminder Notifications
- `chrome.notifications` + `chrome.alarms` → Rust reminder scheduler + `tauri-plugin-notification`
- JS calls `invoke("schedule_reminder", { id, fireAt, title, body })` when saving a reminder
- JS calls `invoke("cancel_reminder", { id })` when cancelling
- Rust holds reminders in a `Mutex<Vec<Reminder>>`, checks every minute, fires notification when `fireAt` is reached
- On app launch, JS reads all stored reminders from the store and re-registers them with Rust via invoke

---

## File Changes

| File | Action | Notes |
|------|--------|-------|
| `popup.html` | Rename → `ui/index.html` | Add Tauri JS bridge script tag |
| `popup.js` | Move → `ui/popup.js` | No changes |
| `styles.css` | Move → `ui/styles.css` | No changes |
| `src/*.js` (all modules except storage-manager) | Move → `ui/src/` | No changes |
| `src/storage-manager.js` | Move + edit | Replace `chrome.storage` calls with `tauri-plugin-store` (~15 sites) |
| `background.js` | Delete | Replaced by Rust timers + `tauri-listeners.js` |
| `manifest.json` | Delete | Chrome-specific |
| `ui/tauri-listeners.js` | Create | Listens for `refresh-ical` event, wires to `ICalParser` |
| `src-tauri/` | Create | Entire Rust backend (see below) |
| `TrinTasksApp/` (Swift) | Delete | Fully replaced |

---

## Rust Backend Files

```
src-tauri/
  src/
    main.rs           — app setup, tray, window, plugin registration
    commands.rs       — schedule_reminder, cancel_reminder Tauri commands
    scheduler.rs      — in-memory reminder list, per-minute check loop
  tauri.conf.json     — app metadata, window config, bundle ID
  Cargo.toml          — dependencies
  icons/              — app icons (generated from icon-128.png)
```

Rust dependencies:
- `tauri` 2.x
- `tauri-plugin-store`
- `tauri-plugin-notification`

Rust backend is ~150 lines total.

---

## Project Structure (final)

```
TrinTasks-Repo/
  src-tauri/
  ui/
    index.html
    popup.js
    styles.css
    src/
      (all existing JS modules)
    tauri-listeners.js
  package.json        — devDependency: @tauri-apps/cli
```

---

## Build & Distribution

- Build command: `cargo tauri build`
- Output: `.app` bundle + `.dmg` installer (~10–15MB)
- Distribution: GitHub Releases as `.dmg`
- No Apple Developer account required
- Users on first launch: right-click app → Open → Open Anyway (Gatekeeper bypass, one-time)

---

## Out of Scope

- App Store submission
- Apple notarization
- Windows/Linux builds
- Auto-updater
