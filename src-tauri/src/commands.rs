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
