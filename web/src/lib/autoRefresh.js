import { api } from "./api.js";

// Reload an open view shortly AFTER each scheduled price refresh fires, so the
// scheduler has time to fetch from Yahoo and write — reloading exactly at the
// tick would pull stale/partial data.
const SETTLE_MS = 60_000;

export function onScheduledRefresh(onRefreshed) {
  let timer = null;
  let stopped = false;

  async function schedule() {
    if (stopped) return;
    let waitMs;
    try {
      const { next_refresh_at } = await api.schedule();
      waitMs = new Date(next_refresh_at).getTime() - Date.now() + SETTLE_MS;
    } catch {
      waitMs = 5 * 60_000; // transient error — retry in 5 min
    }
    timer = setTimeout(async () => {
      await onRefreshed();
      schedule(); // re-arm for the next scheduled refresh
    }, Math.max(SETTLE_MS, waitMs));
  }

  schedule();
  return () => {
    stopped = true;
    if (timer) clearTimeout(timer);
  };
}
