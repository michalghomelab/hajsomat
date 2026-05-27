<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass, percent, dateTime } from "../format.js";
  import ChartPanel from "./ChartPanel.svelte";
  import Modal from "./Modal.svelte";
  let { onSelect } = $props();
  let portfolios = $state([]);
  let snapshots = $state([]);
  let newName = $state("");
  let showCreate = $state(false);
  let loading = $state(true);
  let refreshing = $state(false);

  let totals = $derived.by(() => {
    const sum = (k) => portfolios.reduce((a, p) => a + Number(p[k] || 0), 0);
    return { value: sum("market_value_pln"), cost: sum("cost_pln"), pnl: sum("pnl_pln") };
  });
  let lastUpdated = $derived(portfolios.map((p) => p.last_updated).filter(Boolean).sort().at(-1) ?? null);

  async function load() {
    loading = true;
    portfolios = await api.portfolios();
    snapshots = await api.allSnapshots();
    loading = false;
  }
  async function create() {
    if (!newName.trim()) return;
    await api.createPortfolio(newName.trim());
    newName = ""; showCreate = false; await load();
  }
  async function refreshPrices() {
    refreshing = true;
    try { await api.refresh(); await load(); }
    finally { refreshing = false; }
  }
  onMount(load);
</script>

<div class="p-6 max-w-3xl mx-auto">
  <h1 class="text-2xl font-bold mb-4 text-base-content">Moje portfele</h1>
  <div class="flex gap-2 mb-6">
    <button class="btn btn-primary" onclick={() => (showCreate = true)}>+ Nowy portfel</button>
    <button class="btn btn-outline" onclick={refreshPrices} disabled={refreshing}>
      {refreshing ? "Odświeżanie…" : "Odśwież ceny"}
    </button>
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
      {#each portfolios as p}
        <li class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer" onclick={() => onSelect(p.id)}>
          <div class="card-body flex-row justify-between items-center py-4">
            <span class="font-medium text-base-content">{p.name}</span>
            <span class={pnlClass(p.pnl_pln)}>
              {money(p.market_value_pln)} ({money(p.pnl_pln)} · {percent(p.pnl_pln, p.cost_pln)}){#if p.incomplete}<span class="text-warning" title="Suma niepełna — brak części wycen"> *</span>{/if}
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
                {money(totals.value)} (<span class={pnlClass(totals.pnl)}>{money(totals.pnl)} · {percent(totals.pnl, totals.cost)}</span>)
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
