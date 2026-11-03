export function money(value, currency = "PLN") {
  if (value === null || value === undefined || value === "") return "—";
  const n = Number(value);
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("pl-PL", { style: "currency", currency }).format(n);
}

const blank = (v) => v === null || v === undefined || v === "";
const pct2 = new Intl.NumberFormat("pl-PL", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const pct1 = new Intl.NumberFormat("pl-PL", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const qty = new Intl.NumberFormat("pl-PL", { maximumFractionDigits: 6 });

export function percent(pnl, cost) {
  const c = Number(cost);
  if (!c || blank(pnl)) return "";
  const p = (Number(pnl) / c) * 100;
  const sign = p > 0 ? "+" : p < 0 ? "-" : "";
  return `${sign}${pct2.format(Math.abs(p))}%`;
}

// Share count, e.g. "9,7636" — up to 6 decimals, no trailing zeros.
export function quantity(value) {
  if (blank(value) || Number.isNaN(Number(value))) return "—";
  return qty.format(Number(value));
}

// A 0..1 share of a whole as "47,8%".
export function sharePercent(share) {
  if (share === null || share === undefined || Number.isNaN(share)) return "—";
  return `${pct1.format(share * 100)}%`;
}

// Time until the next refresh, e.g. "za 42 min", "za 1 h 5 min", "za 2 dni".
export function nextIn(ms) {
  if (ms === null || ms === undefined) return "";
  if (ms < 60_000) return "za chwilę";
  const minutes = Math.floor(ms / 60_000);
  const hours = Math.floor(minutes / 60);
  if (hours >= 24) {
    const days = Math.floor(hours / 24);
    return days === 1 ? "za 1 dzień" : `za ${days} dni`;
  }
  const rest = minutes % 60;
  if (!hours) return `za ${minutes} min`;
  return rest ? `za ${hours} h ${rest} min` : `za ${hours} h`;
}

// "zaktualizowano 09:10" for today, "zaktualizowano 6.06, 06:51" otherwise.
export function updatedLabel(value, now = new Date()) {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  const pad = (n) => String(n).padStart(2, "0");
  const time = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  const today = d.toDateString() === now.toDateString();
  return today ? `zaktualizowano ${time}` : `zaktualizowano ${d.getDate()}.${pad(d.getMonth() + 1)}, ${time}`;
}

export function dateTime(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString("pl-PL", { dateStyle: "short", timeStyle: "short" });
}

export function pnlClass(value) {
  const n = Number(value);
  if (n > 0) return "text-success";
  if (n < 0) return "text-error";
  return "text-base-content/60";
}
