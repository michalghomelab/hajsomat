const json = async (r) => {
  if (!r.ok) {
    let msg = `HTTP ${r.status}`;
    try { const b = await r.json(); if (b && b.error) msg = b.error; } catch { /* non-JSON body */ }
    throw new Error(msg);
  }
  return r.json();
};

export const api = {
  portfolios: () => fetch("/api/portfolios").then(json),
  portfolio: (id) => fetch(`/api/portfolios/${id}`).then(json),
  snapshots: (id) => fetch(`/api/portfolios/${id}/snapshots`).then(json),
  allSnapshots: () => fetch("/api/snapshots").then(json),
  schedule: () => fetch("/api/schedule").then(json),
  settings: () => fetch("/api/settings").then(json),
  setSettings: (refresh_interval_minutes) =>
    fetch("/api/settings", { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ refresh_interval_minutes }) }).then(json),
  createPortfolio: (name) =>
    fetch("/api/portfolios", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  renamePortfolio: (id, name) =>
    fetch(`/api/portfolios/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  searchInstruments: (q) => fetch(`/api/instruments?q=${encodeURIComponent(q)}`).then(json),
  addTransaction: (portfolioId, payload) =>
    fetch(`/api/portfolios/${portfolioId}/transactions`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }).then(json),
  deleteTransaction: (id) =>
    fetch(`/api/transactions/${id}`, { method: "DELETE" }).then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); }),
  refresh: () => fetch("/api/refresh", { method: "POST" }).then(json),
  backfill: () => fetch("/api/backfill", { method: "POST" }).then(json),
};
