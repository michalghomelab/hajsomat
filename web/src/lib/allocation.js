// Portfolio allocation helpers: how big a slice each item is, and display order.

const toNumber = (v) => (v === null || v === undefined || v === "" ? null : Number(v));

// Map of item → share of the total (0..1). Items without a value get null, and
// so does everything when the total is zero (no NaN/Infinity).
export function shares(items, valueOf) {
  const values = items.map((item) => toNumber(valueOf(item)));
  const total = values.reduce((sum, v) => (v === null || Number.isNaN(v) ? sum : sum + v), 0);
  const out = new Map();
  items.forEach((item, i) => {
    const v = values[i];
    out.set(item, total > 0 && v !== null && !Number.isNaN(v) ? v / total : null);
  });
  return out;
}

// Largest first; items without a value keep their relative order at the end.
export function byValueDesc(items, valueOf) {
  const key = (item) => {
    const v = toNumber(valueOf(item));
    return v === null || Number.isNaN(v) ? -Infinity : v;
  };
  return [...items].sort((a, b) => key(b) - key(a));
}

export function displayName(pos) {
  return pos?.name ? pos.name : pos?.symbol ?? "";
}
