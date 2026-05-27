export function money(value, currency = "PLN") {
  if (value === null || value === undefined || value === "") return "—";
  const n = Number(value);
  if (Number.isNaN(n)) return "—";
  return new Intl.NumberFormat("pl-PL", { style: "currency", currency }).format(n);
}

export function pnlClass(value) {
  const n = Number(value);
  if (n > 0) return "text-green-600";
  if (n < 0) return "text-red-600";
  return "text-gray-500";
}
