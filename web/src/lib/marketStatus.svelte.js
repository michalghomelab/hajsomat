import { api } from "./api.js";

// Shared, reactive market-session flag. Polls the backend (which derives it from
// the same cron rufus uses) so the UI flips live as the session opens/closes,
// without a page reload.
let open = $state(true);

async function poll() {
  try {
    open = (await api.schedule()).market_open;
  } catch {
    // keep the previous value on a transient error
  }
}

poll();
setInterval(poll, 60_000);

export const market = {
  get open() {
    return open;
  },
};
