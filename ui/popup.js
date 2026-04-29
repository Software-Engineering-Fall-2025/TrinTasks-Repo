import { UIController } from './src/ui-controller.js';
import { setupTauriListeners } from './tauri-listeners.js';
import { getAssignmentReminders } from './src/storage-manager.js';
import { invoke } from '@tauri-apps/api/core';
import { captureAppLaunch } from './src/telemetry.js';
import { checkForUpdates } from './src/updater.js';

// Re-focus the WebView whenever the OS window gains focus.
// On macOS transparent windows WKWebView loses first-responder status,
// which silences keydown events. Focusing any element restores it.
window.addEventListener('focus', () => {
  document.getElementById('keyboardTrap')?.focus();
});

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

    // Telemetry and update check run in background — never block the UI
    captureAppLaunch();
    checkForUpdates();
  } catch (error) {
    console.error('Failed to initialize TrinTasks:', error);
  }
});
