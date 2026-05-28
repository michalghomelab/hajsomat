import { api } from "./api.js";

// App-wide auto-refresh interval (minutes; 0 = off), stored server-side so it's
// shared across browsers and also drives how often the server fetches prices.
export const INTERVALS = [
  { label: "Wył.", minutes: 0 },
  { label: "5 min", minutes: 5 },
  { label: "30 min", minutes: 30 },
  { label: "1 h", minutes: 60 },
];

let minutes = $state(60);

async function reload() {
  try {
    minutes = (await api.settings()).refresh_interval_minutes;
  } catch {
    // keep default until reachable
  }
}
reload();

export const refreshEvery = {
  get minutes() {
    return minutes;
  },
  get ms() {
    return minutes * 60_000;
  },
  async set(v) {
    minutes = v;
    try {
      await api.setSettings(v);
    } catch {
      // ignore — server unreachable
    }
  },
};
