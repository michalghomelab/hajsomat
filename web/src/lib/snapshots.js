// Daily snapshots only grow (new day) or have their last (today's) entry
// updated, so comparing length + the last entry is enough to tell if anything
// changed — lets us skip re-rendering charts on intraday price refreshes.
export function sameSnapshots(a, b) {
  if (a === b) return true;
  if (!a || !b || a.length !== b.length) return false;
  const x = a[a.length - 1] ?? {};
  const y = b[b.length - 1] ?? {};
  return (
    x.date === y.date &&
    x.total_value_pln === y.total_value_pln &&
    x.total_cost_pln === y.total_cost_pln &&
    x.pnl_pln === y.pnl_pln
  );
}
