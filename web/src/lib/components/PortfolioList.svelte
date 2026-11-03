<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, signedMoney, pnlClass, percent, sharePercent } from "../format.js";
  import { shares, byValueDesc } from "../allocation.js";
  import { themeMenuItems } from "../theme.svelte.js";
  import Hero from "./Hero.svelte";
  import ShareBar from "./ShareBar.svelte";
  import SettingsMenu from "./SettingsMenu.svelte";
  import ChartPanel from "./ChartPanel.svelte";
  import { RELATIVE, availableYears, filterSnapshots, loadRange } from "../chartRange.js";
  import RollingNumber from "./RollingNumber.svelte";
  import Modal from "./Modal.svelte";
  import MobileNav from "./MobileNav.svelte";
  import PullToRefresh from "./PullToRefresh.svelte";
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
  import Wallet from "@lucide/svelte/icons/wallet";
  import ChevronRight from "@lucide/svelte/icons/chevron-right";
  import Plus from "@lucide/svelte/icons/plus";
  import RefreshCw from "@lucide/svelte/icons/refresh-cw";
  import MoreHorizontal from "@lucide/svelte/icons/more-horizontal";
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
  let sortedPortfolios = $derived(byValueDesc(portfolios, (p) => p.market_value_pln));
  let portfolioShares = $derived(shares(portfolios, (p) => p.market_value_pln));
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
<div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto space-y-6">
  {#if loading}
    <div class="-mx-6 -mt-6 rounded-b-[1.75rem] bg-neutral px-6 pb-6 pt-[calc(env(safe-area-inset-top)+1.25rem)] sm:mx-0 sm:mt-0 sm:rounded-3xl">
      <div class="skeleton h-5 w-32 bg-white/10"></div>
      <div class="mt-4 skeleton h-10 w-56 bg-white/10"></div>
      <div class="mt-3 skeleton h-4 w-40 bg-white/10"></div>
    </div>
    <div class="overflow-hidden rounded-2xl border border-base-300 bg-base-100">
      {#each Array(2) as _}
        <div class="flex items-start justify-between gap-3 border-b border-base-300 px-4 py-3 last:border-b-0">
          <div class="space-y-2"><div class="skeleton h-4 w-24"></div><div class="skeleton h-1 w-40"></div></div>
          <div class="space-y-1.5"><div class="skeleton h-4 w-28"></div><div class="skeleton h-3 w-24"></div></div>
        </div>
      {/each}
    </div>
    <div class="skeleton h-80 w-full rounded-2xl"></div>
  {:else}
    <Hero value={totals.value} pnl={totals.pnl} cost={totals.cost} updatedAt={lastUpdated}>
      {#snippet top()}
        <h1 class="text-xl font-bold leading-tight sm:text-2xl">Moje portfele</h1>
      {/snippet}
      {#snippet extra()}
        {#if rangeSummary && effectiveSummaryRange !== "all"}
          <div class="mt-2 text-sm text-neutral-content/65" title={rangeSummary.from ? `${rangeSummary.from} – ${rangeSummary.to}` : undefined}>
            W zakresie {rangeSummary.label}:
            <span class="font-semibold {Number(rangeSummary.pnl) >= 0 ? 'text-accent' : ''}"
                  style={Number(rangeSummary.pnl) >= 0 ? undefined : "color: var(--hero-loss)"}>
              <RollingNumber value={rangeSummary.pnl} text={signedMoney(rangeSummary.pnl)} />
            </span>
          </div>
        {/if}
      {/snippet}
    </Hero>

    <div class="hidden items-center gap-2 sm:flex">
      <button class="btn btn-primary gap-2" onclick={() => (showCreate = true)}><Plus size={18} /> Nowy portfel</button>
      <SettingsMenu actions={[
        { label: refreshing ? "Odświeżanie…" : "Odśwież ceny", onclick: refreshPrices, disabled: refreshing || !market.open,
          title: market.open ? "" : "Poza sesją (pn–pt 9:00–22:00) — ceny się nie zmieniają" },
        { label: snapshotting ? "Generowanie…" : "Wygeneruj snapshot", onclick: generateSnapshot, disabled: snapshotting },
      ]} />
    </div>

    {#if portfolios.length}
      <ul class="overflow-hidden rounded-2xl border border-base-300 bg-base-100">
        {#each sortedPortfolios as p (p.id)}
          {@const share = portfolioShares.get(p) ?? null}
          <li class="border-b border-base-300 last:border-b-0">
            <button type="button" class="group w-full cursor-pointer px-4 py-3 text-left transition-colors hover:bg-base-200/60"
                    onclick={() => onSelect(p.id)}>
              <span class="flex items-start gap-3">
                <span class="min-w-0 flex-1">
                  <span class="block truncate font-semibold text-base-content">{p.name}</span>
                  <span class="mt-0.5 block text-xs text-muted">{sharePercent(share)}</span>
                </span>
                <span class="shrink-0 whitespace-nowrap text-right">
                  <span class="block font-semibold text-base-content">
                    <RollingNumber value={p.market_value_pln} text={money(p.market_value_pln)} />
                  </span>
                  <span class="mt-0.5 flex justify-end gap-2 text-xs font-medium {pnlClass(p.pnl_pln)}">
                    <RollingNumber value={p.pnl_pln} text={signedMoney(p.pnl_pln)} />
                    <RollingNumber value={p.pnl_pln} text={percent(p.pnl_pln, p.cost_pln)} />
                    {#if p.incomplete}<span class="text-warning" title="Suma niepełna — brak części wycen">*</span>{/if}
                  </span>
                </span>
                <ChevronRight class="mt-0.5 hidden shrink-0 text-muted transition-transform group-hover:translate-x-0.5 sm:block" size={18} />
              </span>
              <ShareBar {share} />
            </button>
          </li>
        {/each}
      </ul>
      <ChartPanel {snapshots} onRangeChange={(next) => (summaryRange = next)} />
    {:else}
      <p class="rounded-2xl border border-base-300 bg-base-100 px-4 py-3 text-sm text-muted">Nie masz jeszcze portfela. Dodaj pierwszy, żeby zacząć śledzić inwestycje.</p>
    {/if}
  {/if}

  {#if showCreate}
    <Modal title="Nowy portfel" onClose={() => (showCreate = false)}>
      <div class="space-y-4">
        <label class="block">
          <span class="mb-1.5 block text-sm text-muted">Nazwa</span>
          <input class="input input-bordered w-full rounded-xl" placeholder="IKE, IKZE, maklerski..." bind:value={newName} />
        </label>
        <button class="btn btn-primary w-full sm:w-auto" onclick={create}>Dodaj portfel</button>
      </div>
    </Modal>
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
  {
    label: "Więcej",
    icon: MoreHorizontal,
    submenu: [
      { label: snapshotting ? "Generowanie..." : "Wygeneruj snapshot", onclick: generateSnapshot, disabled: snapshotting },
      ...themeMenuItems()
    ]
  }
]} />
