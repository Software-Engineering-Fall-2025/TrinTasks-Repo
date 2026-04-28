use std::sync::{Arc, Mutex};
use serde::{Deserialize, Serialize};
use tauri::AppHandle;
use tauri_plugin_notification::NotificationExt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Reminder {
    pub id: String,
    pub fire_at: u64,
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
