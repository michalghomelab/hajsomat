// Chart time-range selection, persisted in the browser so it survives reloads.
const KEY = "hajsomat:chartRange";

export const RELATIVE = [
  { id: "1m", label: "1M", months: 1 },
  { id: "3m", label: "3M", months: 3 },
  { id: "6m", label: "6M", months: 6 },
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
  const rel = RELATIVE.find((r) => r.id === range);
  if (!rel) return all;
  const from = new Date();
  from.setMonth(from.getMonth() - rel.months);
  const cutoff = from.toISOString().slice(0, 10);
  return all.filter((s) => s.date >= cutoff);
}
