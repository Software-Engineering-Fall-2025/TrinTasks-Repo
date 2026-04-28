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
