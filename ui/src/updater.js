import { check } from '@tauri-apps/plugin-updater';
import { relaunch } from '@tauri-apps/plugin-process';

export async function checkForUpdates() {
  try {
    const update = await check();
    if (!update?.available) return;
    showUpdateBanner(update);
  } catch {
    // Update check failures are silent — don't disrupt the app
  }
}

function showUpdateBanner(update) {
  const banner = document.getElementById('updateBanner');
  const versionEl = document.getElementById('updateBannerVersion');
  if (!banner) return;

  if (versionEl) versionEl.textContent = update.version;
  banner.classList.remove('hidden');

  document.getElementById('updateBannerInstall')?.addEventListener('click', async () => {
    banner.classList.add('hidden');
    try {
      await update.downloadAndInstall();
      await relaunch();
    } catch {
      banner.classList.remove('hidden');
    }
  }, { once: true });

  document.getElementById('updateBannerLater')?.addEventListener('click', () => {
    banner.classList.add('hidden');
  }, { once: true });
}
