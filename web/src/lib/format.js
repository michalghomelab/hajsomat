export function money(value, currency = "PLN") {
  if (value === null || value === undefined || value === "") return "—";
  const n = Number(value);
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("pl-PL", { style: "currency", currency }).format(n);
}

export function percent(pnl, cost) {
  const c = Number(cost);
  if (!c) return "";
  const p = (Number(pnl) / c) * 100;
  const sign = p > 0 ? "+" : "";
  return `${sign}${p.toFixed(2)}%`;
}

export function pnlClass(value) {
  const n = Number(value);
  if (n > 0) return "text-success";
  if (n < 0) return "text-error";
  return "text-base-content/60";
}
