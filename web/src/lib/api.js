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
  createPortfolio: (name) =>
    fetch("/api/portfolios", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  renamePortfolio: (id, name) =>
    fetch(`/api/portfolios/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  searchInstruments: (q) => fetch(`/api/instruments/search?q=${encodeURIComponent(q)}`).then(json),
  addTransaction: (portfolioId, payload) =>
    fetch(`/api/portfolios/${portfolioId}/transactions`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }).then(json),
  refresh: () => fetch("/api/refresh", { method: "POST" }).then(json),
};
