import { api } from "./api.js";

const POLL_MS = 15_000;
const MAX_ATTEMPTS = 8; // give up after ~2 min if the refresh never lands

// Reloads an open view in step with the scheduler's price refresh: waits for the
// next scheduled refresh, then polls (reloading) until last_updated advances past
// that tick — so data appears once it's actually fresh, not stale/partial. Then
// re-arms for the next tick. `reload` must fetch data and return the view's newest
// last_updated (ISO string). Returns a stop() fn.
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
    let next;
    try {
      next = (await api.schedule()).next_refresh_at;
    } catch {
      next = null;
    }
    if (!next) {
      timer = setTimeout(arm, 5 * 60_000); // off / unreachable — recheck later
      return;
    }
    const tickMs = new Date(next).getTime();
    timer = setTimeout(() => poll(tickMs, 1), Math.max(0, tickMs - Date.now()));
  }

  arm();
  return () => {
    stopped = true;
    if (timer) clearTimeout(timer);
  };
}
