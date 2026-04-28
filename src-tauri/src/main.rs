#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod scheduler;

use commands::{cancel_reminder, schedule_reminder};
use scheduler::SchedulerState;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{TrayIconBuilder, TrayIconEvent},
    Emitter, Manager,
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
                                if let Ok(Some(rect)) = tray.rect() {
                                    let (x, bottom_y) = match (rect.position, rect.size) {
                                        (tauri::Position::Physical(pos), tauri::Size::Physical(size)) => {
                                            (pos.x, pos.y + size.height as i32)
                                        }
                                        _ => (0, 50),
                                    };
                                    let _ = window.set_position(tauri::Position::Physical(
                                        tauri::PhysicalPosition::new(x, bottom_y),
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
