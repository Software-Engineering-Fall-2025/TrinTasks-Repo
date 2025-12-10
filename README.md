# TrinTasks

TrinTasks is a simple iCal-based assignment viewer designed to help students keep track of upcoming tasks at a glance.  
Paste in an iCal URL (such as from your school’s LMS or calendar), and TrinTasks will parse the events into a clean weekly view with per-day assignment lists, reminders, and customizable themes.

---

## Features

- **iCal parsing**
  - Supports `webcal://` and `https://` iCal links (e.g. `calendar.ics`).
  - Stores the provided iCal URL so you don’t need to paste it every time.

- **Weekly calendar view**
  - “This Week” header with previous/next week navigation.
  - Compact week-day strip showing days in the current week.
  - Click a day to see assignments/events for that specific date.

- **Daily assignment list**
  - “Today’s Assignments” (or selected day) panel.
  - Filter options:
    - **All**
    - **Uncompleted**
    - **Completed**

- **Settings panel**
  - **Calendar Source**
    - Set or update the iCal link.
    - Refresh the calendar data.
    - Clear all stored data if needed.
  - **Notifications**
    - Toggle assignment reminders on/off.
    - Choose reminder lead time: `1, 2, 4, 6, 12, 24, 48` hours.
  - **Theme**
    - Pick a color theme for header, buttons, and cards:
      - Fern, Ocean, Sunset, Slate, Orchid, Midnight.
  - **Subject Colors**
    - View subject tags and click a swatch to change each subject’s color.

- **UI niceties**
  - Loading spinner while parsing.
  - Error message area for invalid links or parsing issues.
  - Refresh toast to show when the calendar has been updated.

---

## Getting Started

> These steps assume you’re running this as a browser extension or a small web app. Adjust as needed for your actual environment.

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-username/TrinTasks-Repo.git
   cd TrinTasks-Repo