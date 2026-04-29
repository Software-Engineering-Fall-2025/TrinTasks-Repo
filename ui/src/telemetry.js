import { fetch } from '@tauri-apps/plugin-http';
import { getStore } from './storage-manager.js';

const POSTHOG_KEY = 'phc_tpmCWofFuZf8KtzvbjRUxdbhmEE4pSGnuokdeRJtivPR';
const POSTHOG_URL = 'https://us.i.posthog.com/capture/';
const APP_VERSION = '0.1.0-beta.1';

let _optedOut = false;
let _installId = null;

function getOS() {
  const ua = navigator.userAgent;
  if (ua.includes('Mac OS X') || ua.includes('Macintosh')) return 'macOS';
  if (ua.includes('Windows')) return 'Windows';
  if (ua.includes('Linux')) return 'Linux';
  return 'Unknown';
}

async function getInstallId() {
  if (_installId) return _installId;
  const store = await getStore();
  let id = await store.get('installId');
  if (!id) {
    id = crypto.randomUUID();
    await store.set('installId', id);
    await store.save();
  }
  _installId = id;
  return id;
}

export async function loadTelemetryPreference() {
  const store = await getStore();
  _optedOut = (await store.get('telemetryOptOut')) === true;
  return _optedOut;
}

export async function setTelemetryOptOut(value) {
  _optedOut = value;
  const store = await getStore();
  await store.set('telemetryOptOut', value);
  await store.save();
}

export function isTelemetryOptedOut() {
  return _optedOut;
}

export async function captureEvent(event, properties = {}) {
  if (_optedOut) return;
  try {
    const distinctId = await getInstallId();
    await fetch(POSTHOG_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: POSTHOG_KEY,
        event,
        distinct_id: distinctId,
        properties: {
          $os: getOS(),
          app_version: APP_VERSION,
          ...properties
        }
      })
    });
  } catch {
    // Telemetry must never crash the app
  }
}

export async function captureAppLaunch() {
  await loadTelemetryPreference();
  await captureEvent('app_launch');
}
