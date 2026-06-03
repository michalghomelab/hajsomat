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
  import ChevronRight from "@lucide/svelte/icons/chevron-right";
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
      <div class="space-y-4">
        <label class="block">
          <span class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45">Nazwa</span>
          <input class="input input-bordered w-full rounded-xl" placeholder="IKE, IKZE, maklerski..." bind:value={newName} />
        </label>
        <button class="btn btn-primary w-full sm:w-auto" onclick={create}>Dodaj portfel</button>
      </div>
    </Modal>
  {/if}
  {#if loading}
    <div class="space-y-2.5">
      {#each Array(3) as _}
        <div class="rounded-xl border border-base-300/60 bg-base-100/90 px-4 py-3 shadow-sm">
          <div class="flex items-center gap-3">
            <div class="skeleton h-10 w-10 shrink-0 rounded-lg"></div>
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="skeleton h-4 w-32"></div>
              <div class="skeleton h-3 w-16"></div>
            </div>
            <div class="shrink-0 space-y-1.5">
              <div class="skeleton h-4 w-32"></div>
              <div class="skeleton h-5 w-28 rounded-full"></div>
            </div>
          </div>
        </div>
      {/each}
    </div>
    <div class="mt-8 space-y-6">
      <div class="skeleton h-6 w-64"></div>
      <div class="rounded-2xl border border-base-300/60 bg-base-100/90 p-4 shadow-sm sm:p-5">
        <div class="space-y-4">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
            <div class="space-y-2">
              <div class="skeleton h-3 w-16"></div>
              <div class="skeleton h-9 w-48"></div>
            </div>
            <div class="space-y-1 sm:text-right">
              <div class="skeleton h-3 w-28"></div>
              <div class="skeleton h-3 w-40"></div>
            </div>
          </div>
          <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
            {#each Array(3) as _}
              <div class="rounded-xl bg-base-200/70 px-3 py-2.5">
                <div class="skeleton h-3 w-20"></div>
                <div class="mt-2 skeleton h-4 w-28"></div>
              </div>
            {/each}
          </div>
        </div>
      </div>
      <div class="space-y-2">
        <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center">
          <div class="skeleton h-3 w-16 sm:mr-auto"></div>
          <div class="flex justify-end gap-1 rounded-xl border border-base-300/70 bg-base-200/70 p-1">
            <div class="skeleton h-9 w-16 rounded-lg sm:h-8"></div>
            <div class="skeleton h-9 w-20 rounded-lg sm:h-8"></div>
            <div class="skeleton h-9 w-20 rounded-lg sm:h-8"></div>
          </div>
        </div>
        <div class="flex flex-col gap-1.5 sm:flex-row sm:items-center">
          <div class="skeleton h-3 w-24 sm:mr-auto"></div>
          <div class="flex justify-end gap-1 rounded-xl border border-base-300/70 bg-base-200/70 p-1">
            <div class="skeleton h-9 w-16 rounded-lg sm:h-8"></div>
            <div class="skeleton h-9 w-16 rounded-lg sm:h-8"></div>
            <div class="skeleton h-9 w-16 rounded-lg sm:h-8"></div>
          </div>
        </div>
        <div class="skeleton h-80 w-full rounded-2xl"></div>
      </div>
    </div>
  {:else}
    <ul class="space-y-2.5">
      {#each portfolios as p (p.id)}
        <li>
          <button type="button" class="group w-full cursor-pointer rounded-xl border border-base-300/60 bg-base-100/90 px-4 py-3 text-left shadow-sm transition-all hover:-translate-y-0.5 hover:border-primary/25 hover:shadow-md"
                  onclick={() => onSelect(p.id)}>
            <div class="flex w-full items-center gap-3">
              <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <Wallet size={19} />
              </span>
              <span class="min-w-0 flex-1">
                <span class="block truncate font-semibold text-base-content">{p.name}</span>
                <span class="mt-0.5 block text-xs text-base-content/50">Portfel</span>
              </span>
              <span class="flex shrink-0 flex-col items-end gap-1">
                <span class="whitespace-nowrap text-base font-semibold text-base-content">
                  <RollingNumber value={p.market_value_pln} text={money(p.market_value_pln)} />
                </span>
                <span class="inline-flex max-w-full items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium {Number(p.pnl_pln) >= 0 ? 'bg-success/12 text-success' : 'bg-error/12 text-error'}">
                  <RollingNumber value={p.pnl_pln} text={money(p.pnl_pln)} />
                  <span class="opacity-70">·</span>
                  <RollingNumber value={p.pnl_pln} text={percent(p.pnl_pln, p.cost_pln)} />
                  {#if p.incomplete}<span class="text-warning" title="Suma niepełna — brak części wycen">*</span>{/if}
                </span>
              </span>
              <ChevronRight class="hidden shrink-0 text-base-content/30 transition-transform group-hover:translate-x-0.5 sm:block" size={18} />
            </div>
          </button>
        </li>
      {/each}
    </ul>

    <div class="mt-8 space-y-6">
      <h2 class="hidden sm:block text-lg font-semibold text-base-content">Łącznie — wszystkie portfele</h2>
      {#if portfolios.length}
        <div class="rounded-2xl border border-base-300/60 bg-base-100/90 p-4 shadow-sm sm:p-5">
          <div class="space-y-4">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <span class="text-xs font-medium uppercase tracking-wide text-base-content/45">Razem</span>
                <div class="mt-1 text-3xl font-semibold leading-none text-base-content sm:text-4xl">
                  <RollingNumber value={totals.value} text={money(totals.value)} />
                </div>
              </div>
              <div class="text-xs text-base-content/55 sm:text-right">
                <span class="block">Ceny zaktualizowane</span>
                <span class="block font-medium text-base-content/70">{dateTime(lastUpdated)}</span>
              </div>
            </div>
            <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
              <div class="rounded-xl bg-base-200/70 px-3 py-2.5">
                <div class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45">P/L</div>
                <div class="mt-1 text-sm font-semibold {pnlClass(totals.pnl)}">
                  <RollingNumber value={totals.pnl} text={money(totals.pnl)} />
                </div>
              </div>
              <div class="rounded-xl bg-base-200/70 px-3 py-2.5">
                <div class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45">Stopa zwrotu</div>
                <div class="mt-1 text-sm font-semibold {pnlClass(totals.pnl)}">
                  <RollingNumber value={totals.pnl} text={percent(totals.pnl, totals.cost)} />
                </div>
              </div>
              {#if rangeSummary}
                <div class="rounded-xl bg-base-200/70 px-3 py-2.5">
                  <div class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45">Zakres: {rangeSummary.label}</div>
                  <div class="mt-1 text-sm font-semibold {pnlClass(rangeSummary.pnl)}" title={rangeSummary.from ? `${rangeSummary.from} – ${rangeSummary.to}` : undefined}>
                    <RollingNumber value={rangeSummary.pnl} text={money(rangeSummary.pnl)} />
                  </div>
                </div>
              {/if}
            </div>
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
