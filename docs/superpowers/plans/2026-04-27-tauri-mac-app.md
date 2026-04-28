# TrinTasks Tauri Mac App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Swift macOS app with a Tauri 2 menu bar app that wraps the existing Chrome extension JS/HTML/CSS frontend, delivering a distributable `.dmg` with full feature parity.

**Architecture:** A minimal Rust backend (Tauri 2) owns the menu bar tray, window lifecycle, a 30-minute iCal refresh timer (emits Tauri event to frontend), and an in-memory reminder scheduler that fires system notifications. The existing vanilla JS frontend moves to `ui/` with three files changed: `storage-manager.js` (replace `chrome.*` APIs), `ui-controller.js` (6 direct `chrome.storage` calls + `chrome.runtime.sendMessage`), and `ical-parser.js` (CORS-bypassing HTTP fetch). Two new JS files are added: `tauri-listeners.js` and an updated `popup.js`. `background.js` is deleted.

**Tech Stack:** Rust 1.75+, Tauri 2.x, tauri-plugin-store 2.x, tauri-plugin-notification 2.x, tauri-plugin-http 2.x, tokio 1.x, Vite 6.x, vanilla JS/HTML/CSS

---

## File Map

**Create (Rust):**
- `src-tauri/src/main.rs` — tray, window, refresh timer, plugin/state setup
- `src-tauri/src/commands.rs` — `schedule_reminder`, `cancel_reminder` Tauri commands
- `src-tauri/src/scheduler.rs` — `SchedulerState`, `Reminder`, `start_scheduler`
- `src-tauri/build.rs` — Tauri build script
- `src-tauri/Cargo.toml` — Rust dependencies
- `src-tauri/tauri.conf.json` — window config, bundle, CSP
- `src-tauri/capabilities/default.json` — plugin permissions

**Create (JS/config):**
- `vite.config.js` — Vite build config
- `package.json` — npm scripts and deps
- `ui/tauri-listeners.js` — listens for `refresh-ical` Rust event

**Move (no content changes):**
- `popup.html` → `ui/index.html` (title tweak only)
- `styles.css` → `ui/styles.css`
- `src/constants.js` → `ui/src/constants.js`
- `src/utils.js` → `ui/src/utils.js`
- `src/theme-manager.js` → `ui/src/theme-manager.js`
- `src/event-renderer.js` → `ui/src/event-renderer.js`
- `src/week-view.js` → `ui/src/week-view.js`
- `src/sidebar.js` → `ui/src/sidebar.js`

**Modify:**
- `popup.js` → `ui/popup.js` — add Tauri listener setup and reminder re-registration
- `src/storage-manager.js` → `ui/src/storage-manager.js` — replace all `chrome.*` calls
- `src/ui-controller.js` → `ui/src/ui-controller.js` — 6 direct `chrome.storage` calls + `chrome.runtime.sendMessage`
- `src/ical-parser.js` → `ui/src/ical-parser.js` — import `fetch` from `@tauri-apps/plugin-http`

**Delete:**
- `background.js`
- `manifest.json`
- `TrinTasksApp/` (entire Swift directory — approved by user)

---

## Task 1: Verify Prerequisites

**Files:** none

- [ ] **Step 1: Check Rust is installed**

```bash
rustc --version
cargo --version
```
Expected: `rustc 1.75.0` or newer. If missing: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

- [ ] **Step 2: Check Xcode CLI tools**

```bash
xcode-select --version
```
Expected: `xcode-select version 2397` or similar. If missing: `xcode-select --install`

- [ ] **Step 3: Install Tauri CLI as npm devDependency (do this after package.json exists in Task 2)**

Skip for now — handled in Task 2.

- [ ] **Step 4: Commit checkpoint**

```bash
git add -A
git commit -m "chore: begin Tauri migration (no changes yet)"
```

---

## Task 2: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `vite.config.js`
- Create: `src-tauri/Cargo.toml`
- Create: `src-tauri/build.rs`
- Create: `src-tauri/tauri.conf.json`
- Create: `src-tauri/capabilities/default.json`

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "trintasks",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "tauri": "tauri"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^2",
    "vite": "^6"
  },
  "dependencies": {
    "@tauri-apps/api": "^2",
    "@tauri-apps/plugin-http": "^2",
    "@tauri-apps/plugin-notification": "^2",
    "@tauri-apps/plugin-store": "^2"
  }
}
```

- [ ] **Step 2: Install npm dependencies**

```bash
npm install
```
Expected: `node_modules/` created with `@tauri-apps/*` and `vite` packages.

- [ ] **Step 3: Create `vite.config.js`**

```js
import { defineConfig } from 'vite'

export default defineConfig({
  root: './ui',
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
})
```

- [ ] **Step 4: Create `src-tauri/` directory structure**

```bash
mkdir -p src-tauri/src src-tauri/capabilities src-tauri/icons
```

- [ ] **Step 5: Create `src-tauri/build.rs`**

```rust
fn main() {
    tauri_build::build()
}
```

- [ ] **Step 6: Create `src-tauri/Cargo.toml`**

```toml
[package]
name = "trintasks"
version = "1.0.0"
edition = "2021"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = ["tray-icon", "image-png"] }
tauri-plugin-store = "2"
tauri-plugin-notification = "2"
tauri-plugin-http = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }

[features]
default = ["custom-protocol"]
custom-protocol = ["tauri/custom-protocol"]
```

- [ ] **Step 7: Create `src-tauri/tauri.conf.json`**

```json
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "TrinTasks",
  "version": "1.0.0",
  "identifier": "com.trintasks.app",
  "build": {
    "beforeDevCommand": "npm run dev",
    "devUrl": "http://localhost:1420",
    "beforeBuildCommand": "npm run build",
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "TrinTasks",
        "width": 800,
        "height": 600,
        "decorations": false,
        "visible": false,
        "resizable": false
      }
    ],
    "security": {
      "csp": "default-src 'self'; connect-src https: http:; style-src 'self' 'unsafe-inline'"
    },
    "macOSPrivateApi": true
  },
  "bundle": {
    "active": true,
    "targets": ["dmg"],
    "icon": [
      "icons/32x32.png",
      "icons/128x128.png",
      "icons/128x128@2x.png",
      "icons/icon.icns",
      "icons/icon.ico"
    ],
    "macOS": {
      "minimumSystemVersion": "10.15"
    }
  }
}
```

- [ ] **Step 8: Create `src-tauri/capabilities/default.json`**

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default capability for TrinTasks",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "store:default",
    "notification:default",
    "http:default"
  ]
}
```

- [ ] **Step 9: Create placeholder `src-tauri/src/main.rs`** (will be replaced in Task 5)

```rust
fn main() {}
```

- [ ] **Step 10: Verify Cargo can resolve dependencies**

```bash
cd src-tauri && cargo fetch && cd ..
```
Expected: Downloads crates without errors.

- [ ] **Step 11: Commit**

```bash
git add package.json package-lock.json vite.config.js src-tauri/
git commit -m "chore: add Tauri 2 project scaffold"
```

---

## Task 3: Rust Scheduler (TDD)

**Files:**
- Create: `src-tauri/src/scheduler.rs`

- [ ] **Step 1: Write `src-tauri/src/scheduler.rs` with tests**

```rust
use std::sync::{Arc, Mutex};
use serde::{Deserialize, Serialize};
use tauri::AppHandle;
use tauri_plugin_notification::NotificationExt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Reminder {
    pub id: String,
    pub fire_at: u64, // Unix timestamp in milliseconds
    pub title: String,
    pub body: String,
}

#[derive(Default)]
pub struct SchedulerState {
    pub reminders: Arc<Mutex<Vec<Reminder>>>,
}

pub fn start_scheduler(app: AppHandle, reminders: Arc<Mutex<Vec<Reminder>>>) {
    tauri::async_runtime::spawn(async move {
        loop {
            tokio::time::sleep(std::time::Duration::from_secs(60)).await;
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64;

            let fired: Vec<String> = {
                let locked = reminders.lock().unwrap();
                locked
                    .iter()
                    .filter(|r| r.fire_at <= now)
                    .map(|r| {
                        let _ = app.notification().builder().title(&r.title).body(&r.body).show();
                        r.id.clone()
                    })
                    .collect()
            };

            if !fired.is_empty() {
                reminders.lock().unwrap().retain(|r| !fired.contains(&r.id));
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_reminder(id: &str, fire_at: u64) -> Reminder {
        Reminder {
            id: id.to_string(),
            fire_at,
            title: "Test".to_string(),
            body: "Body".to_string(),
        }
    }

    #[test]
    fn test_add_reminder() {
        let mut reminders: Vec<Reminder> = Vec::new();
        reminders.push(make_reminder("a", 9_999_999_999_999));
        assert_eq!(reminders.len(), 1);
    }

    #[test]
    fn test_cancel_reminder() {
        let mut reminders = vec![make_reminder("a", 9_999_999_999_999)];
        reminders.retain(|r| r.id != "a");
        assert_eq!(reminders.len(), 0);
    }

    #[test]
    fn test_replace_duplicate_id() {
        let mut reminders = vec![make_reminder("a", 1000)];
        let updated = make_reminder("a", 2000);
        reminders.retain(|r| r.id != updated.id);
        reminders.push(updated);
        assert_eq!(reminders.len(), 1);
        assert_eq!(reminders[0].fire_at, 2000);
    }

    #[test]
    fn test_only_past_reminders_fire() {
        let now = 5000u64;
        let reminders = vec![make_reminder("past", 1000), make_reminder("future", 9999)];
        let to_fire: Vec<&Reminder> = reminders.iter().filter(|r| r.fire_at <= now).collect();
        assert_eq!(to_fire.len(), 1);
        assert_eq!(to_fire[0].id, "past");
    }

    #[test]
    fn test_retain_removes_fired() {
        let mut reminders = vec![make_reminder("a", 1000), make_reminder("b", 9999)];
        let fired = vec!["a".to_string()];
        reminders.retain(|r| !fired.contains(&r.id));
        assert_eq!(reminders.len(), 1);
        assert_eq!(reminders[0].id, "b");
    }
}
```

- [ ] **Step 2: Update `src-tauri/src/main.rs` to declare the module (so tests compile)**

```rust
mod scheduler;
fn main() {}
```

- [ ] **Step 3: Run tests to verify they pass**

```bash
cd src-tauri && cargo test scheduler && cd ..
```
Expected output contains `test scheduler::tests::test_add_reminder ... ok` and 4 more passing tests.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/scheduler.rs src-tauri/src/main.rs
git commit -m "feat: add Rust reminder scheduler with unit tests"
```

---

## Task 4: Rust Commands

**Files:**
- Create: `src-tauri/src/commands.rs`

- [ ] **Step 1: Write `src-tauri/src/commands.rs`**

```rust
use crate::scheduler::{Reminder, SchedulerState};
use tauri::State;

#[tauri::command]
pub fn schedule_reminder(
    id: String,
    fire_at: u64,
    title: String,
    body: String,
    state: State<'_, SchedulerState>,
) {
    let mut reminders = state.reminders.lock().unwrap();
    reminders.retain(|r| r.id != id);
    reminders.push(Reminder { id, fire_at, title, body });
}

#[tauri::command]
pub fn cancel_reminder(id: String, state: State<'_, SchedulerState>) {
    state.reminders.lock().unwrap().retain(|r| r.id != id);
}
```

- [ ] **Step 2: Add `mod commands;` to `src-tauri/src/main.rs`**

```rust
mod commands;
mod scheduler;
fn main() {}
```

- [ ] **Step 3: Verify compilation**

```bash
cd src-tauri && cargo build 2>&1 | grep -E "^error" && cd ..
```
Expected: no output (no errors). If errors appear, fix them before continuing.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/commands.rs src-tauri/src/main.rs
git commit -m "feat: add schedule_reminder and cancel_reminder Tauri commands"
```

---

## Task 5: Rust Main — Tray, Window & Timers

**Files:**
- Modify: `src-tauri/src/main.rs`

- [ ] **Step 1: Replace `src-tauri/src/main.rs` with full implementation**

```rust
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod scheduler;

use commands::{cancel_reminder, schedule_reminder};
use scheduler::SchedulerState;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{TrayIconBuilder, TrayIconEvent},
    Manager,
};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_http::init())
        .setup(|app| {
            // Hide from Dock — menu bar only
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Build tray context menu
            let show_item =
                MenuItem::with_id(app, "show", "Show/Hide", true, None::<&str>)?;
            let quit_item =
                MenuItem::with_id(app, "quit", "Quit TrinTasks", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_item, &quit_item])?;

            // Build tray icon
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .tooltip("TrinTasks")
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click { .. } = event {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                let _ = window.hide();
                            } else {
                                if let Some(rect) = tray.rect() {
                                    let _ = window.set_position(tauri::Position::Physical(
                                        tauri::PhysicalPosition::new(
                                            rect.position.x as i32,
                                            (rect.position.y + rect.size.height) as i32,
                                        ),
                                    ));
                                }
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                })
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                let _ = window.hide();
                            } else {
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;

            // Hide window when it loses focus
            let focus_handle = app.handle().clone();
            if let Some(window) = app.get_webview_window("main") {
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        if let Some(win) = focus_handle.get_webview_window("main") {
                            let _ = win.hide();
                        }
                    }
                });
            }

            // Background iCal refresh every 30 minutes
            let refresh_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                loop {
                    tokio::time::sleep(std::time::Duration::from_secs(1800)).await;
                    let _ = refresh_handle.emit("refresh-ical", ());
                }
            });

            // Start reminder scheduler
            let scheduler_state = app.state::<SchedulerState>();
            scheduler::start_scheduler(
                app.handle().clone(),
                scheduler_state.inner().reminders.clone(),
            );

            Ok(())
        })
        .manage(SchedulerState::default())
        .invoke_handler(tauri::generate_handler![schedule_reminder, cancel_reminder])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 2: Verify it compiles (icons don't exist yet — expect icon-related error only)**

```bash
cd src-tauri && cargo build 2>&1 | grep "^error" && cd ..
```
Expected: errors only about missing icon files (e.g., `icons/32x32.png`). If there are Rust compile errors unrelated to icons, fix them now.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/main.rs
git commit -m "feat: add Tauri tray, window, refresh timer, and reminder scheduler wiring"
```

---

## Task 6: Move Frontend Files to `ui/`

**Files:** Move/rename as described below.

- [ ] **Step 1: Create `ui/src/` directory**

```bash
mkdir -p ui/src
```

- [ ] **Step 2: Copy files that need no content changes**

```bash
cp popup.html ui/index.html
cp styles.css ui/styles.css
cp src/constants.js ui/src/constants.js
cp src/utils.js ui/src/utils.js
cp src/theme-manager.js ui/src/theme-manager.js
cp src/event-renderer.js ui/src/event-renderer.js
cp src/week-view.js ui/src/week-view.js
cp src/sidebar.js ui/src/sidebar.js
```

- [ ] **Step 3: Update title in `ui/index.html`**

Find line: `<title>iCal Parser</title>`
Replace with: `<title>TrinTasks</title>`

- [ ] **Step 4: Copy files that will be edited in subsequent tasks (do not edit yet)**

```bash
cp popup.js ui/popup.js
cp src/storage-manager.js ui/src/storage-manager.js
cp src/ical-parser.js ui/src/ical-parser.js
cp src/ui-controller.js ui/src/ui-controller.js
```

- [ ] **Step 5: Verify `ui/` structure**

```bash
find ui/ -type f | sort
```
Expected:
```
ui/index.html
ui/popup.js
ui/src/constants.js
ui/src/event-renderer.js
ui/src/ical-parser.js
ui/src/sidebar.js
ui/src/storage-manager.js
ui/src/theme-manager.js
ui/src/ui-controller.js
ui/src/utils.js
ui/src/week-view.js
ui/styles.css
```

- [ ] **Step 6: Commit**

```bash
git add ui/
git commit -m "feat: copy frontend files into ui/ directory"
```

---

## Task 7: Migrate `ui/src/storage-manager.js`

**Files:**
- Modify: `ui/src/storage-manager.js`

Replace the entire file. Every `chrome.storage.local.*` call becomes a `tauri-plugin-store` call. Every `chrome.alarms.*` call becomes a Tauri `invoke()` call.

- [ ] **Step 1: Replace `ui/src/storage-manager.js` with the full Tauri version**

```js
import { Store } from '@tauri-apps/plugin-store';
import { invoke } from '@tauri-apps/api/core';
import { ICalParser } from './ical-parser.js';
import { getEventId } from './utils.js';

let _store = null;

export async function getStore() {
  if (!_store) {
    _store = await Store.load('trintasks.json');
  }
  return _store;
}

export async function saveToStorage(url, events) {
  try {
    const store = await getStore();
    const completedAssignments = await store.get('completedAssignments') || {};
    events = events.map(event => {
      const eventId = getEventId(event);
      if (completedAssignments[eventId]) {
        event.isCompleted = true;
        event.completedDate = completedAssignments[eventId].completedDate;
      }
      return event;
    });
    await store.set('icalUrl', url);
    await store.set('events', events);
    await store.set('lastUpdated', new Date().toISOString());
    await store.save();
    console.log('Data saved to storage');
  } catch (error) {
    console.error('Failed to save to storage:', error);
  }
}

export async function loadSavedData() {
  try {
    const store = await getStore();
    const icalUrl = await store.get('icalUrl');
    const events = await store.get('events');
    if (icalUrl && events) {
      const completedAssignments = await store.get('completedAssignments') || {};
      const inProgressAssignments = await store.get('inProgressAssignments') || {};
      const cachedEvents = mergeCompletionStatus(events, completedAssignments, inProgressAssignments);
      return {
        url: icalUrl,
        events: cachedEvents,
        pinnedAssignments: await store.get('pinnedAssignments') || {},
        lastRefreshSummary: await store.get('lastRefreshSummary')
      };
    }
  } catch (error) {
    console.error('Failed to load from storage:', error);
  }
  return null;
}

export function mergeCompletionStatus(events, completedAssignments, inProgressAssignments) {
  const completed = completedAssignments || {};
  const inProgress = inProgressAssignments || {};
  return (events || []).map(event => {
    const merged = { ...event };
    const eventId = getEventId(merged);
    if (completed[eventId]) {
      merged.isCompleted = true;
      merged.completedDate = completed[eventId].completedDate;
      merged.isInProgress = false;
    } else if (inProgress[eventId]) {
      merged.isInProgress = true;
      merged.inProgressDate = inProgress[eventId].inProgressDate;
      merged.isCompleted = false;
      merged.completedDate = null;
    } else {
      merged.isCompleted = false;
      merged.completedDate = null;
      merged.isInProgress = false;
      merged.inProgressDate = null;
    }
    return merged;
  });
}

export async function togglePinAssignment(event, currentPinned) {
  const eventId = getEventId(event);
  const store = await getStore();
  const pinnedAssignments = await store.get('pinnedAssignments') || {};
  let isPinned;
  if (pinnedAssignments[eventId]) {
    delete pinnedAssignments[eventId];
    isPinned = false;
  } else {
    pinnedAssignments[eventId] = {
      title: event.title,
      dueRaw: event.dueRaw,
      startRaw: event.startRaw,
      dueTime: event.dueTime,
      startTime: event.startTime,
      pinnedDate: new Date().toISOString()
    };
    isPinned = true;
  }
  await store.set('pinnedAssignments', pinnedAssignments);
  await store.save();
  return { pinnedAssignments, isPinned };
}

export async function toggleAssignmentComplete(event) {
  const eventId = getEventId(event);
  const store = await getStore();
  const completedAssignments = await store.get('completedAssignments') || {};
  const inProgressAssignments = await store.get('inProgressAssignments') || {};
  let isCompleted;
  let completedDate = null;
  if (event.isCompleted) {
    delete completedAssignments[eventId];
    isCompleted = false;
  } else {
    delete inProgressAssignments[eventId];
    completedDate = new Date().toISOString();
    completedAssignments[eventId] = { completedDate, title: event.title };
    isCompleted = true;
  }
  await store.set('completedAssignments', completedAssignments);
  await store.set('inProgressAssignments', inProgressAssignments);
  await store.save();
  return { isCompleted, completedDate, isInProgress: false };
}

export async function toggleAssignmentInProgress(event) {
  const eventId = getEventId(event);
  const store = await getStore();
  const inProgressAssignments = await store.get('inProgressAssignments') || {};
  const completedAssignments = await store.get('completedAssignments') || {};
  let isInProgress;
  let inProgressDate = null;
  if (event.isInProgress) {
    delete inProgressAssignments[eventId];
    isInProgress = false;
  } else {
    delete completedAssignments[eventId];
    inProgressDate = new Date().toISOString();
    inProgressAssignments[eventId] = { inProgressDate, title: event.title };
    isInProgress = true;
  }
  await store.set('inProgressAssignments', inProgressAssignments);
  await store.set('completedAssignments', completedAssignments);
  await store.save();
  return { isInProgress, inProgressDate, isCompleted: false };
}

// No-op: cross-context storage events are not needed in Tauri (no service worker)
export function listenForStorageChanges(_callback) {}

const EVENT_COMPARE_FIELDS = ['title', 'dueRaw', 'startRaw', 'endRaw', 'description', 'location', 'dueTime', 'startTime'];

function hasEventChanged(prev, curr) {
  for (const field of EVENT_COMPARE_FIELDS) {
    if (prev[field] !== curr[field]) return true;
  }
  return false;
}

export async function refreshLocally(url) {
  const store = await getStore();
  const previousEvents = await store.get('events') || [];
  const completedAssignments = await store.get('completedAssignments') || {};
  const newEvents = await ICalParser.fetchAndParse(url);
  const prevMap = new Map();
  previousEvents.forEach(ev => prevMap.set(getEventId(ev), ev));
  const nextEvents = [];
  const nextIds = new Set();
  let added = 0, updated = 0;
  for (const ev of newEvents) {
    const id = getEventId(ev);
    nextIds.add(id);
    const prev = prevMap.get(id);
    if (!prev) added++;
    else if (hasEventChanged(prev, ev)) updated++;
    if (completedAssignments[id]) {
      ev.isCompleted = true;
      ev.completedDate = completedAssignments[id].completedDate;
    }
    nextEvents.push(ev);
  }
  let removed = 0;
  for (const ev of previousEvents) {
    const id = getEventId(ev);
    if (!nextIds.has(id)) {
      removed++;
      delete completedAssignments[id];
    }
  }
  const summary = { added, updated, removed, timestamp: Date.now() };
  await store.set('events', nextEvents);
  await store.set('completedAssignments', completedAssignments);
  await store.set('lastUpdated', new Date().toISOString());
  await store.set('lastRefreshSummary', summary);
  await store.save();
  return { added, updated, removed };
}

export async function clearAllReminderAlarms() {
  try {
    const store = await getStore();
    const assignmentReminders = await store.get('assignmentReminders') || {};
    for (const eventId of Object.keys(assignmentReminders)) {
      await invoke('cancel_reminder', { id: `assignment_reminder_${eventId}` });
    }
    await store.set('reminders', {});
    await store.set('reminderHistory', {});
    await store.set('assignmentReminders', {});
    await store.save();
  } catch (err) {
    console.error('Failed to clear reminder alarms:', err);
  }
}

export async function clearAllData() {
  const store = await getStore();
  await store.clear();
  await store.save();
}

export async function loadSettings() {
  const store = await getStore();
  const reminderSettings = await store.get('reminderSettings');
  return {
    autoRefresh: await store.get('autoRefresh') || false,
    enableReminders: (await store.get('enableReminders')) === true,
    reminderHours: (reminderSettings && reminderSettings.hours) || await store.get('reminderHours') || 24,
    theme: await store.get('theme') || 'slate',
    uiStyle: await store.get('uiStyle') || 'neobrutalism',
    showMajorAssignmentsBar: (await store.get('showMajorAssignmentsBar')) === true,
    subjectTags: await store.get('subjectTags') || {},
    weatherUnlocked: (await store.get('weatherUnlocked')) === true,
    weather: await store.get('weather') || 'clear'
  };
}

export async function saveSettings(settings) {
  const store = await getStore();
  await store.set('autoRefresh', settings.autoRefresh);
  await store.set('enableReminders', settings.enableReminders);
  await store.set('reminderHours', settings.reminderHours);
  await store.set('theme', settings.theme);
  await store.set('uiStyle', settings.uiStyle);
  await store.set('reminderSettings', { enabled: settings.enableReminders, hours: settings.reminderHours });
  await store.set('showMajorAssignmentsBar', settings.showMajorAssignmentsBar);
  await store.save();
}

export async function unlockWeather() {
  const store = await getStore();
  await store.set('weatherUnlocked', true);
  await store.save();
}

export async function saveWeather(weather) {
  const store = await getStore();
  await store.set('weather', weather);
  await store.save();
}

export async function saveSubjectTags(subjectTags) {
  const store = await getStore();
  await store.set('subjectTags', subjectTags);
  await store.save();
}

export async function saveEventOrder(dateKey, eventIds) {
  const store = await getStore();
  const eventOrder = await store.get('eventOrder') || {};
  eventOrder[dateKey] = eventIds;
  await store.set('eventOrder', eventOrder);
  await store.save();
}

export async function loadEventOrder(dateKey) {
  const store = await getStore();
  const eventOrder = await store.get('eventOrder') || {};
  return eventOrder[dateKey] || null;
}

export async function setAssignmentReminder(event, hours) {
  const eventId = getEventId(event);
  const reminderTime = Date.now() + (hours * 60 * 60 * 1000);
  const store = await getStore();
  const assignmentReminders = await store.get('assignmentReminders') || {};
  assignmentReminders[eventId] = { reminderTime, hours, title: event.title, dueRaw: event.dueRaw, createdAt: Date.now() };
  await store.set('assignmentReminders', assignmentReminders);
  await store.save();
  await invoke('schedule_reminder', {
    id: `assignment_reminder_${eventId}`,
    fireAt: reminderTime,
    title: `Reminder: ${event.title}`,
    body: event.dueRaw ? `Due: ${event.dueRaw}` : 'Assignment due soon'
  });
  return { success: true, reminderTime };
}

export async function clearAssignmentReminder(event) {
  const eventId = getEventId(event);
  const store = await getStore();
  const assignmentReminders = await store.get('assignmentReminders') || {};
  delete assignmentReminders[eventId];
  await store.set('assignmentReminders', assignmentReminders);
  await store.save();
  await invoke('cancel_reminder', { id: `assignment_reminder_${eventId}` });
  return { success: true };
}

export async function getAssignmentReminders() {
  const store = await getStore();
  return await store.get('assignmentReminders') || {};
}

export async function getAssignmentReminderStatus(event) {
  const eventId = getEventId(event);
  const store = await getStore();
  const assignmentReminders = await store.get('assignmentReminders') || {};
  if (assignmentReminders[eventId]) {
    return {
      hasReminder: true,
      reminderTime: assignmentReminders[eventId].reminderTime,
      hours: assignmentReminders[eventId].hours
    };
  }
  return { hasReminder: false, reminderTime: null, hours: null };
}
```

- [ ] **Step 2: Confirm no `chrome.` references remain**

```bash
grep -n "chrome\." ui/src/storage-manager.js
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add ui/src/storage-manager.js
git commit -m "feat: migrate storage-manager.js to tauri-plugin-store and Tauri commands"
```

---

## Task 8: Update `ui/src/ui-controller.js`

**Files:**
- Modify: `ui/src/ui-controller.js`

There are 8 targeted changes. Make them one at a time.

- [ ] **Step 1: Add `getStore` to the import from `./storage-manager.js`**

Find (line 9–28):
```js
import {
  saveToStorage,
  loadSavedData,
  mergeCompletionStatus,
  togglePinAssignment,
  toggleAssignmentComplete,
  toggleAssignmentInProgress,
  listenForStorageChanges,
  refreshLocally,
  clearAllReminderAlarms,
  clearAllData,
  loadSettings,
  saveSettings,
  saveSubjectTags,
  unlockWeather,
  saveWeather,
  setAssignmentReminder,
  clearAssignmentReminder,
  getAssignmentReminderStatus
} from './storage-manager.js';
```

Replace with (add `getStore` and `saveEventOrder` and `loadEventOrder`):
```js
import {
  saveToStorage,
  loadSavedData,
  mergeCompletionStatus,
  togglePinAssignment,
  toggleAssignmentComplete,
  toggleAssignmentInProgress,
  listenForStorageChanges,
  refreshLocally,
  clearAllReminderAlarms,
  clearAllData,
  loadSettings,
  saveSettings,
  saveSubjectTags,
  unlockWeather,
  saveWeather,
  setAssignmentReminder,
  clearAssignmentReminder,
  getAssignmentReminderStatus,
  getStore
} from './storage-manager.js';
```

- [ ] **Step 2: Replace `handleSaveCustomAssignment` storage call (around line 704)**

Find:
```js
    await chrome.storage.local.set({
      events: this.events,
      subjectTags: this.subjectTags
    });
```

Replace with:
```js
    const store = await getStore();
    await store.set('events', this.events);
    await store.set('subjectTags', this.subjectTags);
    await store.save();
```

- [ ] **Step 3: Replace `handleUnpin` storage call (around line 878)**

Find:
```js
    await chrome.storage.local.set({ pinnedAssignments: this.pinnedAssignments });
```

Replace with:
```js
    const store = await getStore();
    await store.set('pinnedAssignments', this.pinnedAssignments);
    await store.save();
```

- [ ] **Step 4: Replace `updateEventsFromStorage` body (around line 1000–1014)**

Find:
```js
  async updateEventsFromStorage() {
    try {
      const data = await chrome.storage.local.get(['events', 'completedAssignments', 'inProgressAssignments', 'icalUrl', 'pinnedAssignments']);
      if (data.icalUrl) {
        this.icalLinkInput.value = data.icalUrl;
        this.settingsIcalLink.value = data.icalUrl;
      }
      this.pinnedAssignments = data.pinnedAssignments || {};
      const merged = mergeCompletionStatus(data.events || [], data.completedAssignments, data.inProgressAssignments);
      if (merged.length > 0) {
        this.displayEvents(merged);
      }
    } catch (error) {
      console.error('Failed to update events from storage:', error);
    }
  }
```

Replace with:
```js
  async updateEventsFromStorage() {
    try {
      const store = await getStore();
      const icalUrl = await store.get('icalUrl');
      const events = await store.get('events');
      const completedAssignments = await store.get('completedAssignments');
      const inProgressAssignments = await store.get('inProgressAssignments');
      const pinnedAssignments = await store.get('pinnedAssignments');
      if (icalUrl) {
        this.icalLinkInput.value = icalUrl;
        this.settingsIcalLink.value = icalUrl;
      }
      this.pinnedAssignments = pinnedAssignments || {};
      const merged = mergeCompletionStatus(events || [], completedAssignments, inProgressAssignments);
      if (merged.length > 0) {
        this.displayEvents(merged);
      }
    } catch (error) {
      console.error('Failed to update events from storage:', error);
    }
  }
```

- [ ] **Step 5: Replace `requestBackgroundRefresh` body (around line 1017–1051)**

Find:
```js
  async requestBackgroundRefresh() {
    const currentUrl = this.icalLinkInput.value.trim() || this.settingsIcalLink.value.trim();
    if (!currentUrl) {
      this.showError('Please add an iCal link first');
      return;
    }
    await chrome.storage.local.set({ icalUrl: currentUrl });

    const response = await new Promise(resolve => {
      try {
        chrome.runtime.sendMessage({ action: 'refreshCalendarNow', icalUrl: currentUrl }, (resp) => {
          if (chrome.runtime.lastError) {
            resolve({ success: false, error: chrome.runtime.lastError.message });
          } else {
            resolve(resp);
          }
        });
      } catch (err) {
        resolve({ success: false, error: err?.message || 'Unable to contact background' });
      }
    });

    if (!response || !response.success) {
      console.warn('Background refresh failed or no response', response && response.error);
      try {
        await refreshLocally(currentUrl);
        await this.updateEventsFromStorage();
      } catch (err) {
        this.showError(response && response.error ? response.error : 'Could not refresh calendar. Please try again.');
        return;
      }
    } else {
      await this.updateEventsFromStorage();
    }
  }
```

Replace with:
```js
  async requestBackgroundRefresh() {
    const currentUrl = this.icalLinkInput.value.trim() || this.settingsIcalLink.value.trim();
    if (!currentUrl) {
      this.showError('Please add an iCal link first');
      return;
    }
    const store = await getStore();
    await store.set('icalUrl', currentUrl);
    await store.save();
    try {
      await refreshLocally(currentUrl);
      await this.updateEventsFromStorage();
    } catch (err) {
      this.showError('Could not refresh calendar. Please try again.');
    }
  }
```

- [ ] **Step 6: Replace `loadSubjectTags` storage call (around line 1267–1269)**

Find:
```js
    const data = await chrome.storage.local.get(['subjectTags']);
    this.subjectTags = data.subjectTags || {};
```

Replace with:
```js
    const store = await getStore();
    this.subjectTags = await store.get('subjectTags') || {};
```

- [ ] **Step 7: Replace `showTutorial` storage call (around line 1641–1643)**

Find:
```js
    const data = await chrome.storage.local.get(['tutorialCompleted']);
    if (data.tutorialCompleted) return;
```

Replace with:
```js
    const store = await getStore();
    if (await store.get('tutorialCompleted')) return;
```

- [ ] **Step 8: Replace `closeTutorial` storage call (around line 1656)**

Find:
```js
    chrome.storage.local.set({ tutorialCompleted: true });
```

Replace with:
```js
    getStore().then(store => { store.set('tutorialCompleted', true); store.save(); });
```

- [ ] **Step 9: Confirm no `chrome.` references remain in ui-controller.js**

```bash
grep -n "chrome\." ui/src/ui-controller.js
```
Expected: no output.

- [ ] **Step 10: Commit**

```bash
git add ui/src/ui-controller.js
git commit -m "feat: replace chrome.storage and chrome.runtime calls in ui-controller.js"
```

---

## Task 9: Update `ui/src/ical-parser.js` (CORS Fix)

**Files:**
- Modify: `ui/src/ical-parser.js`

The Chrome extension bypassed CORS via extension host permissions. In Tauri, we must use `tauri-plugin-http`'s `fetch()` which goes through Rust's HTTP client and has no CORS restrictions.

- [ ] **Step 1: Add the plugin-http import at the top of `ui/src/ical-parser.js`**

Find the very first line of the file (likely a comment or `export class ICalParser`).

Add as the **first non-comment line**:
```js
import { fetch } from '@tauri-apps/plugin-http';
```

The rest of the file is unchanged. The existing `fetch(fetchUrl)` call at line ~401 will now resolve to the plugin's fetch automatically since it's in scope.

- [ ] **Step 2: Confirm the import is present and fetch call is unchanged**

```bash
head -5 ui/src/ical-parser.js
grep -n "fetch(" ui/src/ical-parser.js
```
Expected: import line visible at top; `fetch(fetchUrl)` unchanged at its original line.

- [ ] **Step 3: Commit**

```bash
git add ui/src/ical-parser.js
git commit -m "feat: use tauri-plugin-http fetch in ical-parser to bypass CORS"
```

---

## Task 10: Create `ui/tauri-listeners.js` and Update `ui/popup.js`

**Files:**
- Create: `ui/tauri-listeners.js`
- Modify: `ui/popup.js`

- [ ] **Step 1: Create `ui/tauri-listeners.js`**

```js
import { listen } from '@tauri-apps/api/event';
import { ICalParser } from './src/ical-parser.js';
import { loadSavedData, saveToStorage } from './src/storage-manager.js';

export async function setupTauriListeners(onRefreshComplete) {
  await listen('refresh-ical', async () => {
    try {
      const saved = await loadSavedData();
      if (!saved?.url) return;
      const events = await ICalParser.fetchAndParse(saved.url);
      await saveToStorage(saved.url, events);
      if (onRefreshComplete) onRefreshComplete();
    } catch (err) {
      console.error('Auto-refresh failed:', err);
    }
  });
}
```

- [ ] **Step 2: Replace `ui/popup.js` with Tauri-aware entry point**

```js
import { UIController } from './src/ui-controller.js';
import { setupTauriListeners } from './tauri-listeners.js';
import { getAssignmentReminders } from './src/storage-manager.js';
import { invoke } from '@tauri-apps/api/core';

document.addEventListener('DOMContentLoaded', async () => {
  try {
    const controller = new UIController();
    requestAnimationFrame(() => {
      document.body.classList.add('popup-ready');
    });

    // Re-register stored reminders with the Rust scheduler on every launch
    const reminders = await getAssignmentReminders();
    const now = Date.now();
    for (const [eventId, reminder] of Object.entries(reminders)) {
      if (reminder.reminderTime > now) {
        await invoke('schedule_reminder', {
          id: `assignment_reminder_${eventId}`,
          fireAt: reminder.reminderTime,
          title: `Reminder: ${reminder.title}`,
          body: reminder.dueRaw ? `Due: ${reminder.dueRaw}` : 'Assignment due soon'
        });
      }
    }

    // Listen for 30-minute background refresh events emitted by Rust
    await setupTauriListeners(() => controller.updateEventsFromStorage());
  } catch (error) {
    console.error('Failed to initialize TrinTasks:', error);
  }
});
```

- [ ] **Step 3: Verify no `chrome.` references anywhere in `ui/`**

```bash
grep -rn "chrome\." ui/
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add ui/tauri-listeners.js ui/popup.js
git commit -m "feat: add tauri-listeners.js and update popup.js entry point"
```

---

## Task 11: Generate App Icons

**Files:**
- Create: `src-tauri/icons/` (multiple PNG + ICNS + ICO files)

Tauri CLI generates all required icon sizes from one source image.

- [ ] **Step 1: Verify the source icon exists**

```bash
ls icon-128.png
```
Expected: `icon-128.png` listed.

- [ ] **Step 2: Generate all icon sizes**

```bash
npm run tauri icon icon-128.png
```
Expected: creates `src-tauri/icons/32x32.png`, `128x128.png`, `128x128@2x.png`, `icon.icns`, `icon.ico`, and others.

- [ ] **Step 3: Verify icons were created**

```bash
ls src-tauri/icons/
```
Expected: at minimum `32x32.png`, `128x128.png`, `128x128@2x.png`, `icon.icns`, `icon.ico`.

- [ ] **Step 4: Commit**

```bash
git add src-tauri/icons/
git commit -m "feat: add generated app icons from icon-128.png"
```

---

## Task 12: Dev Test, Delete Old Files & Build DMG

**Files:**
- Delete: `background.js`, `manifest.json`, `TrinTasksApp/`

- [ ] **Step 1: Run dev build to catch any remaining issues**

```bash
npm run tauri dev
```
Expected: Vite dev server starts on port 1420, Rust compiles, TrinTasks app appears in menu bar. Click the tray icon — the 800×600 window should open. If compilation errors appear, fix them before proceeding.

Common issues to fix if they appear:
- Icon path errors: ensure `src-tauri/icons/` files exist
- JS import errors: check relative paths in `ui/src/*.js` files
- Rust type errors: check `scheduler.rs` and `commands.rs` compile

- [ ] **Step 2: Manually test core features while dev server is running**

- [ ] Click tray icon — window opens below tray
- [ ] Click outside window — window hides
- [ ] Right-click tray — context menu shows Show/Hide + Quit
- [ ] Paste an iCal URL, click parse — assignments load
- [ ] Toggle an assignment complete — persists after hiding/reopening window
- [ ] Open settings, change theme — persists
- [ ] Set a reminder on an assignment — no JS errors in console
- [ ] Press Cmd+Q in context menu — app quits

- [ ] **Step 3: Stop the dev server (Ctrl+C)**

- [ ] **Step 4: Delete old Chrome extension files**

```bash
rm background.js
rm manifest.json
```

- [ ] **Step 5: Delete the Swift directory (user approved this action)**

```bash
rm -rf TrinTasksApp/
```

- [ ] **Step 6: Also delete the original source files (now in ui/)**

```bash
rm popup.html popup.js styles.css
rm -rf src/
```

- [ ] **Step 7: Build the release DMG**

```bash
npm run tauri build
```
Expected: outputs `src-tauri/target/release/bundle/dmg/TrinTasks_1.0.0_aarch64.dmg` (or `x86_64` on Intel Mac). Build takes 2–5 minutes on first run.

- [ ] **Step 8: Test the DMG**

```bash
open src-tauri/target/release/bundle/dmg/TrinTasks_*.dmg
```
Drag TrinTasks to Applications. Open it — macOS shows a security warning. Right-click → Open → Open Anyway. Verify the app works identically to the dev build.

- [ ] **Step 9: Final commit**

```bash
git add -A
git commit -m "feat: complete Tauri mac app — delete Chrome extension files, verified DMG build"
```

---

## Self-Review Checklist

After writing this plan, checking against the spec:

- [x] Menu bar tray with toggle and quit — Task 5
- [x] Frameless 800×600 window, hidden at start — Task 2 (tauri.conf.json)
- [x] No Dock icon — Task 5 (`ActivationPolicy::Accessory`)
- [x] Window hides on focus loss — Task 5
- [x] Window positioned below tray icon — Task 5
- [x] `chrome.storage` → tauri-plugin-store — Task 7
- [x] Background refresh timer → Rust interval → `refresh-ical` event — Task 5 + Task 10
- [x] Reminder scheduler in Rust — Tasks 3, 4, 5
- [x] Reminder re-registration on launch — Task 10 (popup.js)
- [x] `listenForStorageChanges` → no-op — Task 7
- [x] CORS fetch fix for iCal — Task 9
- [x] `ui-controller.js` direct chrome.storage calls — Task 8 (6 targeted edits)
- [x] Delete Swift, background.js, manifest.json — Task 12
- [x] DMG output — Task 12
- [x] No Apple account required — confirmed in spec; Gatekeeper bypass in dev test
