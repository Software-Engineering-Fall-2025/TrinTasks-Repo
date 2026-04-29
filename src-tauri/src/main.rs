#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod scheduler;

use commands::{cancel_reminder, quit_app, schedule_reminder};
use scheduler::SchedulerState;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use tauri::{
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager,
};

#[cfg(target_os = "macos")]
use tauri_nspanel::{
    tauri_panel, CollectionBehavior, ManagerExt, PanelLevel, StyleMask, WebviewWindowExt,
};

// Define our custom NSPanel subclass. The override `can_become_key_window: true`
// is essential: a stock NSPanel returns false from canBecomeKeyWindow, which
// would prevent keyboard input from reaching the webview.
#[cfg(target_os = "macos")]
tauri_panel! {
    panel!(TrinTasksPanel {
        config: {
            can_become_key_window: true,
            is_floating_panel: true
        }
    })
}

fn main() {
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_http::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init());

    #[cfg(target_os = "macos")]
    let builder = builder.plugin(tauri_nspanel::init());

    builder
        .setup(|app| {
            // Hide from Dock — menu bar only
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Convert main window → NSPanel so it can overlay foreign full-screen
            // Spaces. A regular NSWindow physically cannot — only an NSPanel with
            // the NonactivatingPanel style mask + CanJoinAllSpaces |
            // FullScreenAuxiliary collection behavior. The tauri-nspanel plugin
            // performs the runtime class-swap and exposes setters for these.
            #[cfg(target_os = "macos")]
            if let Some(window) = app.get_webview_window("main") {
                let panel = window.to_panel::<TrinTasksPanel>().unwrap();
                // Floating window level (4) — drawn above app windows. Use
                // PopUpMenu (101) if we ever need to overlay system menus too.
                panel.set_level(PanelLevel::Floating.value());
                // NonactivatingPanel: showing the panel does NOT activate the
                // owning app, so macOS keeps the user in their current Space.
                panel.set_style_mask(StyleMask::empty().nonactivating_panel().into());
                // CanJoinAllSpaces + FullScreenAuxiliary lets the panel appear
                // on every Space including a foreign app's full-screen Space.
                panel.set_collection_behavior(
                    CollectionBehavior::new()
                        .can_join_all_spaces()
                        .full_screen_auxiliary()
                        .into(),
                );
                // Stay visible when our app "deactivates" — the tray-driven
                // hide-on-blur logic below handles dismissal.
                panel.set_hides_on_deactivate(false);
            }

            // Guard: prevents Focused(false) from hiding the window during the
            // 500 ms show transition (avoids race with macOS focus handoff).
            let is_showing = Arc::new(AtomicBool::new(false));
            let is_showing_for_focus = is_showing.clone();

            // Build tray icon (click only — no context menu)
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("TrinTasks")
                .on_tray_icon_event(move |tray, event| {
                    if let TrayIconEvent::Click { button, button_state, .. } = event {
                        if button != MouseButton::Left || button_state != MouseButtonState::Up {
                            return;
                        }
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                #[cfg(target_os = "macos")]
                                {
                                    if let Ok(panel) = app.get_webview_panel("main") {
                                        panel.hide();
                                    } else {
                                        let _ = window.hide();
                                    }
                                }
                                #[cfg(not(target_os = "macos"))]
                                let _ = window.hide();
                            } else {
                                if let Ok(Some(rect)) = tray.rect() {
                                    let (tray_x, bottom_y) = match (rect.position, rect.size) {
                                        (tauri::Position::Physical(pos), tauri::Size::Physical(size)) => {
                                            (pos.x, pos.y + size.height as i32)
                                        }
                                        _ => (0, 50),
                                    };
                                    let scale = window.scale_factor().unwrap_or(1.0);
                                    let win_physical_w = (800.0 * scale) as i32;
                                    let x = if let Ok(Some(monitor)) = window.primary_monitor() {
                                        let sw = monitor.size().width as i32;
                                        tray_x.min(sw - win_physical_w).max(0)
                                    } else {
                                        tray_x
                                    };
                                    let _ = window.set_position(tauri::Position::Physical(
                                        tauri::PhysicalPosition::new(x, bottom_y),
                                    ));
                                }

                                // Block focus-loss hide for 500 ms while we transition
                                is_showing.store(true, Ordering::SeqCst);
                                let flag = is_showing.clone();
                                tauri::async_runtime::spawn(async move {
                                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                                    flag.store(false, Ordering::SeqCst);
                                });

                                // Show via the panel (orderFrontRegardless under the hood);
                                // because the panel is nonactivating, this does not switch
                                // Spaces and the panel appears on the current Space.
                                #[cfg(target_os = "macos")]
                                {
                                    if let Ok(panel) = app.get_webview_panel("main") {
                                        panel.show();
                                    } else {
                                        let _ = window.show();
                                    }
                                }
                                #[cfg(not(target_os = "macos"))]
                                {
                                    let _ = window.show();
                                    let _ = window.set_focus();
                                }
                            }
                        }
                    }
                })
                .build(app)?;

            // Hide window when it loses focus — guarded against the show transition
            let focus_handle = app.handle().clone();
            if let Some(window) = app.get_webview_window("main") {
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        if is_showing_for_focus.load(Ordering::SeqCst) {
                            return;
                        }
                        #[cfg(target_os = "macos")]
                        {
                            if let Ok(panel) = focus_handle.get_webview_panel("main") {
                                panel.hide();
                                return;
                            }
                        }
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
        .invoke_handler(tauri::generate_handler![schedule_reminder, cancel_reminder, quit_app])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
