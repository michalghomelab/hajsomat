import { api } from "./api.js";

// App-wide auto-refresh interval (minutes), stored server-side so it's shared
// across browsers and also drives how often the server fetches prices. There's
// no "off" — auto-refresh can't be disabled.
export const INTERVALS = [
  { label: "5 min", minutes: 5 },
  { label: "30 min", minutes: 30 },
  { label: "1 h", minutes: 60 },
];

let minutes = $state(60);
// Bumped after the server has the new value, so dependents (e.g. the countdown)
// can refetch derived data without racing the PATCH.
let version = $state(0);

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
  get version() {
    return version;
  },
  async set(v) {
    minutes = v;
    try {
      await api.setSettings(v);
    } finally {
      version += 1;
    }
  },
};
