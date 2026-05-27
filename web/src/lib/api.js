const json = (r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); };

export const api = {
  portfolios: () => fetch("/api/portfolios").then(json),
  portfolio: (id) => fetch(`/api/portfolios/${id}`).then(json),
  snapshots: (id) => fetch(`/api/portfolios/${id}/snapshots`).then(json),
  createPortfolio: (name) =>
    fetch("/api/portfolios", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) }).then(json),
  searchInstruments: (q) => fetch(`/api/instruments/search?q=${encodeURIComponent(q)}`).then(json),
  addTransaction: (portfolioId, payload) =>
    fetch(`/api/portfolios/${portfolioId}/transactions`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) }).then(json),
  refresh: () => fetch("/api/refresh", { method: "POST" }).then(json),
};
