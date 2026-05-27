import { api } from "./api.js";

const POLL_MS = 15_000;
const MAX_ATTEMPTS = 8; // give up after ~2 min if the refresh never lands

// Reloads an open view after each scheduled price refresh. Reloading exactly at
// the tick would pull stale/partial data, so we poll: `reload` must fetch fresh
// data and return the view's newest `last_updated` (ISO string); we keep going
// until that advances past the refresh tick, then re-arm for the next one.
export function onScheduledRefresh(reload) {
  let timer = null;
  let stopped = false;

  async function poll(tickMs, attempt) {
    if (stopped) return;
    const lastUpdated = await reload();
    const fresh = lastUpdated && new Date(lastUpdated).getTime() >= tickMs;
    if (fresh || attempt >= MAX_ATTEMPTS) {
      arm();
    } else {
      timer = setTimeout(() => poll(tickMs, attempt + 1), POLL_MS);
    }
  }

  async function arm() {
    if (stopped) return;
    try {
      const tickMs = new Date((await api.schedule()).next_refresh_at).getTime();
      timer = setTimeout(() => poll(tickMs, 1), Math.max(0, tickMs - Date.now()));
    } catch {
      timer = setTimeout(arm, 5 * 60_000); // transient error — retry in 5 min
    }
  }

  arm();
  return () => {
    stopped = true;
    if (timer) clearTimeout(timer);
  };
}
