<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass, percent, dateTime } from "../format.js";
  import ChartPanel from "./ChartPanel.svelte";
  import { RELATIVE, availableYears, filterSnapshots, loadRange } from "../chartRange.js";
  import Countdown from "./Countdown.svelte";
  import RefreshIntervalSelect from "./RefreshIntervalSelect.svelte";
  import RollingNumber from "./RollingNumber.svelte";
  import Modal from "./Modal.svelte";
  import MobileNav from "./MobileNav.svelte";
  import PullToRefresh from "./PullToRefresh.svelte";
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
  import Settings from "@lucide/svelte/icons/settings";
  import Wallet from "@lucide/svelte/icons/wallet";
  import RefreshCw from "@lucide/svelte/icons/refresh-cw";
  import Camera from "@lucide/svelte/icons/camera";
  import Clock from "@lucide/svelte/icons/clock";
  let { onSelect } = $props();
  let portfolios = $state([]);
  let snapshots = $state([]);
  let newName = $state("");
  let showCreate = $state(false);
  let loading = $state(true);
  let refreshing = $state(false);
  let snapshotting = $state(false);
  let summaryRange = $state(loadRange());

  let totals = $derived.by(() => {
    const sum = (k) => portfolios.reduce((a, p) => a + Number(p[k] || 0), 0);
    return { value: sum("market_value_pln"), cost: sum("cost_pln"), pnl: sum("pnl_pln") };
  });
  let lastUpdated = $derived(portfolios.map((p) => p.last_updated).filter(Boolean).sort().at(-1) ?? null);
  let snapshotYears = $derived(availableYears(snapshots));
  let effectiveSummaryRange = $derived(
    summaryRange.startsWith("year:") && !snapshotYears.includes(summaryRange.slice(5)) ? "all" : summaryRange
  );
  let rangeSummary = $derived.by(() => {
    const points = filterSnapshots(snapshots, effectiveSummaryRange);
    if (!points.length && effectiveSummaryRange !== "all") return null;
    if (effectiveSummaryRange === "all") {
      return { label: rangeLabel(effectiveSummaryRange), pnl: totals.pnl, from: null, to: null };
    }

    const first = points[0];
    const last = points.at(-1);
    const pnl = Number(last.pnl_pln) - Number(first.pnl_pln);
    return { label: rangeLabel(effectiveSummaryRange), pnl, from: first.date, to: last.date };
  });

  function rangeLabel(id) {
    if (id === "all") return "całość";
    if (id.startsWith("year:")) return id.slice(5);
    return RELATIVE.find((r) => r.id === id)?.label ?? id;
  }

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
  async function pullRefresh() {
    if (refreshing) return;
    if (market.open) await refreshPrices();
    else await load(true);
  }
  onMount(() => {
    load();
    return onPriceRefresh(() => load(true)); // push from the server when prices refresh
  });
</script>

<PullToRefresh onRefresh={pullRefresh} disabled={loading || showCreate}>
<div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto">
  <h1 class="hidden sm:block text-2xl font-bold mb-4 text-base-content">Moje portfele</h1>
  <div class="hidden sm:flex flex-wrap gap-2 mb-2 items-center">
    <button class="btn btn-primary gap-1" onclick={() => (showCreate = true)}>
      <Wallet size={18} /> Nowy portfel
    </button>
    <div class="dropdown">
      <div tabindex="0" role="button" class="btn btn-outline btn-square" aria-label="Akcje" title="Akcje">
        <Settings size={20} />
      </div>
      <ul class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-56 p-2 mt-1">
        <li>
          <button class="disabled:opacity-50" onclick={refreshPrices} disabled={refreshing || !market.open}
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
  </div>
  <div class="flex flex-wrap items-center justify-end gap-x-3 gap-y-1 mb-6">
    <span class="hidden sm:inline-flex"><RefreshIntervalSelect /></span>
    <Countdown field="next_refresh_at" label="odświeżenie cen" title="Następne automatyczne odświeżenie cen" />
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
      {#each Array(3) as _}
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body gap-2 py-4">
            <div class="flex flex-col items-start gap-2 sm:flex-row sm:justify-between sm:items-center">
              <div class="skeleton h-5 w-32"></div>
              <div class="space-y-1 sm:text-right">
                <div class="skeleton h-5 w-36"></div>
                <div class="skeleton h-4 w-44"></div>
              </div>
            </div>
          </div>
        </div>
      {/each}
    </div>
    <div class="mt-8 space-y-6">
      <div class="skeleton h-6 w-64"></div>
      <div class="card bg-base-100 shadow-sm">
        <div class="card-body gap-2 py-4">
          <div class="flex flex-col items-start gap-2 sm:flex-row sm:justify-between sm:items-center">
            <div class="skeleton h-5 w-24"></div>
            <div class="space-y-1 sm:text-right">
              <div class="skeleton h-5 w-40"></div>
              <div class="skeleton h-4 w-44"></div>
            </div>
          </div>
          <div class="skeleton h-3 w-48"></div>
        </div>
      </div>
      <div class="space-y-2">
        <div class="flex justify-end gap-1">
          <div class="skeleton h-6 w-12"></div>
          <div class="skeleton h-6 w-12"></div>
          <div class="skeleton h-6 w-16"></div>
          <div class="skeleton h-6 w-16"></div>
        </div>
        <div class="flex justify-end gap-1">
          <div class="skeleton h-6 w-12"></div>
          <div class="skeleton h-6 w-12"></div>
          <div class="skeleton h-6 w-12"></div>
        </div>
        <div class="skeleton h-80 w-full"></div>
      </div>
    </div>
  {:else}
    <ul class="space-y-2">
      {#each portfolios as p (p.id)}
        <li>
          <button type="button" class="card w-full cursor-pointer bg-base-100 shadow-sm hover:shadow-md transition-shadow text-left"
                  onclick={() => onSelect(p.id)}>
          <div class="card-body items-start gap-1 sm:flex-row sm:justify-between sm:items-center py-4 w-full">
            <span class="font-medium text-base-content">{p.name}</span>
            <span class="text-right {pnlClass(p.pnl_pln)}">
              <span class="whitespace-nowrap"><RollingNumber value={p.market_value_pln} text={money(p.market_value_pln)} /></span>
              <span class="whitespace-nowrap">(<RollingNumber value={p.pnl_pln} text={money(p.pnl_pln)} /> · <RollingNumber value={p.pnl_pln} text={percent(p.pnl_pln, p.cost_pln)} />){#if p.incomplete}<span class="text-warning" title="Suma niepełna — brak części wycen"> *</span>{/if}</span>
            </span>
          </div>
          </button>
        </li>
      {/each}
    </ul>

    <div class="mt-8 space-y-6">
      <h2 class="hidden sm:block text-lg font-semibold text-base-content">Łącznie — wszystkie portfele</h2>
      {#if portfolios.length}
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body py-4 gap-1">
            <div class="flex flex-col items-start gap-1 sm:flex-row sm:justify-between sm:items-center">
              <span class="font-medium text-base-content">Razem</span>
              <span class="text-right">
                <span class="whitespace-nowrap"><RollingNumber value={totals.value} text={money(totals.value)} /></span>
                <span class="whitespace-nowrap {pnlClass(totals.pnl)}">(<RollingNumber value={totals.pnl} text={money(totals.pnl)} /> · <RollingNumber value={totals.pnl} text={percent(totals.pnl, totals.cost)} />)</span>
              </span>
            </div>
            <p class="text-xs text-base-content/60">Ceny zaktualizowane: {dateTime(lastUpdated)}</p>
            {#if rangeSummary}
              <p class="text-xs text-base-content/70">
                Zysk/strata ({rangeSummary.label}):
                <span class="font-medium {pnlClass(rangeSummary.pnl)}" title={rangeSummary.from ? `${rangeSummary.from} – ${rangeSummary.to}` : undefined}>
                  <RollingNumber value={rangeSummary.pnl} text={money(rangeSummary.pnl)} />
                </span>
              </p>
            {/if}
          </div>
        </div>
      {/if}
      <ChartPanel {snapshots} onRangeChange={(next) => (summaryRange = next)} />
    </div>
  {/if}
</div>
</PullToRefresh>

<MobileNav items={[
  { label: "Nowy", icon: Wallet, onclick: () => (showCreate = true) },
  {
    label: refreshing ? "Trwa..." : "Ceny",
    icon: RefreshCw,
    onclick: refreshPrices,
    disabled: refreshing || !market.open,
    title: market.open ? "Odśwież ceny" : "Poza sesją"
  },
  {
    label: "Auto",
    icon: Clock,
    submenu: INTERVALS.map((interval) => ({
      label: interval.label,
      meta: refreshEvery.minutes === interval.minutes ? "wybrane" : "",
      active: refreshEvery.minutes === interval.minutes,
      keepOpen: true,
      onclick: () => refreshEvery.set(interval.minutes)
    }))
  },
  { label: snapshotting ? "Trwa..." : "Snapshot", icon: Camera, onclick: generateSnapshot, disabled: snapshotting }
]} />
