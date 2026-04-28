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

// No-op: cross-context storage events not needed in Tauri (no service worker)
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
