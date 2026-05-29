// Chart time-range selection, persisted in the browser so it survives reloads.
const KEY = "hajsomat:chartRange";

export const RELATIVE = [
  { id: "1m", label: "1M", months: 1 },
  { id: "3m", label: "3M", months: 3 },
  { id: "6m", label: "6M", months: 6 },
  { id: "ytd", label: "YTD" }, // od początku roku — handled specially in filterSnapshots
];

export function availableYears(snapshots) {
  const years = new Set((snapshots ?? []).map((s) => String(s.date).slice(0, 4)));
  return [...years].sort();
}

export function loadRange() {
  try {
    return localStorage.getItem(KEY) || "all";
  } catch {
    return "all";
  }
}

export function saveRange(id) {
  try {
    localStorage.setItem(KEY, id);
  } catch {
    // ignore (e.g. storage disabled in private mode) — selection just won't persist
  }
}

export function filterSnapshots(snapshots, range) {
  const all = snapshots ?? [];
  if (!all.length || range === "all") return all;
  if (range.startsWith("year:")) {
    const year = range.slice(5);
    return all.filter((s) => String(s.date).slice(0, 4) === year);
  }
  if (range === "ytd") {
    const cutoff = `${new Date().getFullYear()}-01-01`;
    return all.filter((s) => s.date >= cutoff);
  }
  const rel = RELATIVE.find((r) => r.id === range);
  if (!rel) return all;
  const from = new Date();
  from.setMonth(from.getMonth() - rel.months);
  const cutoff = from.toISOString().slice(0, 10);
  return all.filter((s) => s.date >= cutoff);
}

// --- Resolution (downsampling to period-end points) ---
const RES_KEY = "hajsomat:chartResolution";

export const RESOLUTIONS = [
  { id: "day", label: "Dzień" },
  { id: "week", label: "Tydzień" },
  { id: "month", label: "Miesiąc" },
  { id: "quarter", label: "Kwartał" },
  { id: "year", label: "Rok" },
];

export function loadResolution() {
  try {
    return localStorage.getItem(RES_KEY) || "day";
  } catch {
    return "day";
  }
}

export function saveResolution(id) {
  try {
    localStorage.setItem(RES_KEY, id);
  } catch {
    // ignore — selection just won't persist
  }
}

// --- Legend visibility (which series are toggled off), persisted across reloads ---
const HIDDEN_KEY = "hajsomat:chartHidden";

export function loadHiddenSeries() {
  try {
    return JSON.parse(localStorage.getItem(HIDDEN_KEY)) || [];
  } catch {
    return [];
  }
}

export function saveHiddenSeries(names) {
  try {
    localStorage.setItem(HIDDEN_KEY, JSON.stringify(names));
  } catch {
    // ignore — selection just won't persist
  }
}

// Bucket key for a "YYYY-MM-DD" date at the given resolution. Keys are sortable
// and monotonic, so grouping preserves chronological order.
function bucketKey(dateStr, res) {
  const [y, m, d] = dateStr.split("-").map(Number);
  if (res === "year") return `${y}`;
  if (res === "quarter") return `${y}-Q${Math.floor((m - 1) / 3) + 1}`;
  if (res === "month") return `${y}-${String(m).padStart(2, "0")}`;
  if (res === "week") {
    const dt = new Date(Date.UTC(y, m - 1, d));
    dt.setUTCDate(dt.getUTCDate() - ((dt.getUTCDay() + 6) % 7)); // back to Monday
    return dt.toISOString().slice(0, 10);
  }
  return dateStr; // day
}

// Keep the last snapshot of each period (period-end value), in date order.
export function resample(snapshots, resolution) {
  const all = snapshots ?? [];
  if (!all.length || resolution === "day") return all;
  const sorted = [...all].sort((a, b) => (a.date < b.date ? -1 : 1));
  const lastByBucket = new Map();
  for (const s of sorted) lastByBucket.set(bucketKey(s.date, resolution), s);
  return [...lastByBucket.values()];
}
