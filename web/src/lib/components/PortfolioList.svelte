<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass, percent, dateTime } from "../format.js";
  import ChartPanel from "./ChartPanel.svelte";
  import Countdown from "./Countdown.svelte";
  import RefreshIntervalSelect from "./RefreshIntervalSelect.svelte";
  import RollingNumber from "./RollingNumber.svelte";
  import Modal from "./Modal.svelte";
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
  let { onSelect } = $props();
  let portfolios = $state([]);
  let snapshots = $state([]);
  let newName = $state("");
  let showCreate = $state(false);
  let loading = $state(true);
  let refreshing = $state(false);
  let snapshotting = $state(false);

  let totals = $derived.by(() => {
    const sum = (k) => portfolios.reduce((a, p) => a + Number(p[k] || 0), 0);
    return { value: sum("market_value_pln"), cost: sum("cost_pln"), pnl: sum("pnl_pln") };
  });
  let lastUpdated = $derived(portfolios.map((p) => p.last_updated).filter(Boolean).sort().at(-1) ?? null);

  async function load(silent = false) {
    if (!silent) loading = true;
    portfolios = (await api.portfolios()).sort((a, b) => a.name.localeCompare(b.name, "pl"));
    const next = await api.allSnapshots();
    if (!sameSnapshots(next, snapshots)) snapshots = next; // skip chart churn when unchanged
    if (!silent) loading = false;
  }
  async function create() {
    if (!newName.trim()) return;
    await api.createPortfolio(newName.trim());
    newName = ""; showCreate = false; await load();
  }
  async function refreshPrices() {
    refreshing = true;
    try { await api.refresh(); await load(true); } // silent — update values in place, no skeleton
    finally { refreshing = false; }
  }
  async function generateSnapshot() {
    snapshotting = true;
    try { await api.generateSnapshot(); await load(true); } // silent — refresh the chart with the new point
    finally { snapshotting = false; }
  }
  onMount(() => {
    load();
    return onPriceRefresh(() => load(true)); // push from the server when prices refresh
  });
</script>

<div class="p-6 max-w-4xl mx-auto">
  <h1 class="text-2xl font-bold mb-4 text-base-content">Moje portfele</h1>
  <div class="flex gap-2 mb-6 items-center">
    <button class="btn btn-primary" onclick={() => (showCreate = true)}>+ Nowy portfel</button>
    <div class="dropdown">
      <div tabindex="0" role="button" class="btn btn-outline">Akcje ▾</div>
      <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-56 p-2 mt-1">
        <li>
          <button onclick={refreshPrices} disabled={refreshing || !market.open}
                  title={market.open ? "" : "Poza sesją (pn–pt 9:00–22:00) — ceny się nie zmieniają"}>
            {refreshing ? "Odświeżanie…" : "Odśwież ceny"}
          </button>
        </li>
        <li>
          <button onclick={generateSnapshot} disabled={snapshotting}>
            {snapshotting ? "Generowanie…" : "Wygeneruj snapshot"}
          </button>
        </li>
      </ul>
    </div>
    <div class="ml-auto flex items-center gap-3">
      <RefreshIntervalSelect />
      <Countdown field="next_refresh_at" label="odświeżenie cen" title="Następne automatyczne odświeżenie cen" />
    </div>
  </div>
  {#if showCreate}
    <Modal title="Nowy portfel" onClose={() => (showCreate = false)}>
      <div class="space-y-3">
        <input class="input input-bordered w-full" placeholder="Nazwa portfela" bind:value={newName} />
        <button class="btn btn-primary" onclick={create}>Dodaj</button>
      </div>
    </Modal>
  {/if}
  {#if loading}
    <div class="space-y-2">
      <div class="skeleton h-16 w-full"></div>
      <div class="skeleton h-16 w-full"></div>
      <div class="skeleton h-16 w-full"></div>
    </div>
    <div class="mt-8 space-y-6">
      <div class="skeleton h-16 w-full"></div>
      <div class="skeleton h-80 w-full"></div>
      <div class="skeleton h-80 w-full"></div>
    </div>
  {:else}
    <ul class="space-y-2">
      {#each portfolios as p (p.id)}
        <li class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer" onclick={() => onSelect(p.id)}>
          <div class="card-body flex-row justify-between items-center py-4">
            <span class="font-medium text-base-content">{p.name}</span>
            <span class={pnlClass(p.pnl_pln)}>
              <RollingNumber value={p.market_value_pln} text={money(p.market_value_pln)} />
              (<RollingNumber value={p.pnl_pln} text={money(p.pnl_pln)} /> ·
              <RollingNumber value={p.pnl_pln} text={percent(p.pnl_pln, p.cost_pln)} />){#if p.incomplete}<span class="text-warning" title="Suma niepełna — brak części wycen"> *</span>{/if}
            </span>
          </div>
        </li>
      {/each}
    </ul>

    <div class="mt-8 space-y-6">
      <h2 class="text-lg font-semibold text-base-content">Łącznie — wszystkie portfele</h2>
      {#if portfolios.length}
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body py-4 gap-1">
            <div class="flex justify-between items-center">
              <span class="font-medium text-base-content">Razem</span>
              <span>
                <RollingNumber value={totals.value} text={money(totals.value)} />
                (<span class={pnlClass(totals.pnl)}><RollingNumber value={totals.pnl} text={money(totals.pnl)} /> ·
                <RollingNumber value={totals.pnl} text={percent(totals.pnl, totals.cost)} /></span>)
              </span>
            </div>
            <p class="text-xs text-base-content/60">Ceny zaktualizowane: {dateTime(lastUpdated)}</p>
          </div>
        </div>
      {/if}
      <ChartPanel {snapshots} />
    </div>
  {/if}
</div>
