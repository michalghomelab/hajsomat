// Shared, reactive "auto-refresh every N" setting for the views, persisted in
// the browser. 0 = off.
const KEY = "hajsomat:refreshInterval";

export const INTERVALS = [
  { label: "Wył.", ms: 0 },
  { label: "30 s", ms: 30_000 },
  { label: "1 min", ms: 60_000 },
  { label: "5 min", ms: 300_000 },
  { label: "15 min", ms: 900_000 },
];

function initial() {
  try {
    const v = localStorage.getItem(KEY);
    return v === null ? 300_000 : Number(v);
  } catch {
    return 300_000;
  }
}

let ms = $state(initial());

export const refreshEvery = {
  get value() {
    return ms;
  },
  set(v) {
    ms = v;
    try {
      localStorage.setItem(KEY, String(v));
    } catch {
      // ignore — selection just won't persist
    }
  },
};
