<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, signedMoney, pnlClass, percent, quantity, sharePercent } from "../format.js";
  import { shares, byValueDesc, displayName } from "../allocation.js";
  import Hero from "./Hero.svelte";
  import ShareBar from "./ShareBar.svelte";
  import SettingsMenu from "./SettingsMenu.svelte";
  import TransactionForm from "./TransactionForm.svelte";
  import ChartPanel from "./ChartPanel.svelte";
  import RollingNumber from "./RollingNumber.svelte";
  import Modal from "./Modal.svelte";
  import MobileNav from "./MobileNav.svelte";
  import PullToRefresh from "./PullToRefresh.svelte";
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
  import Pencil from "@lucide/svelte/icons/pencil";
  import ChevronLeft from "@lucide/svelte/icons/chevron-left";
  import ChevronRight from "@lucide/svelte/icons/chevron-right";
  import ExternalLink from "@lucide/svelte/icons/external-link";
  import Trash2 from "@lucide/svelte/icons/trash-2";
  import Plus from "@lucide/svelte/icons/plus";
  import RefreshCw from "@lucide/svelte/icons/refresh-cw";
  import MoreHorizontal from "@lucide/svelte/icons/more-horizontal";
  import Wallet from "@lucide/svelte/icons/wallet";
  import Clock from "@lucide/svelte/icons/clock";
  let { id, onBack } = $props();
  let data = $state(null); let snapshots = $state([]); let loading = $state(true);
  let refreshError = $state(""); let refreshing = $state(false); let backfilling = $state(false);
  let editingName = $state(false); let nameInput = $state(""); let nameError = $state("");
  let showAdd = $state(false);
  let showImport = $state(false); let importFile = $state(null); let importing = $state(false);
  let importResult = $state(null); let importError = $state("");

  async function doImport() {
    if (!importFile) return;
    importing = true; importError = ""; importResult = null;
    try { importResult = await api.importXtb(id, importFile); await load(true); }
    catch (e) { importError = e.message || "Import nie powiódł się"; }
    finally { importing = false; }
  }
  function closeImport() {
    showImport = false; importFile = null; importResult = null; importError = "";
  }

  function appleStocksLink(symbol) {
    return `https://stocks.apple.com/symbol/${encodeURIComponent(symbol)}`;
  }

  function yahooLink(symbol) {
    return `https://finance.yahoo.com/quote/${encodeURIComponent(symbol)}`;
  }

  function opensAppleStocks() {
    const ua = navigator.userAgent;
    return /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  }

  function instrumentLink(symbol) {
    const apple = opensAppleStocks();
    return {
      href: apple ? appleStocksLink(symbol) : yahooLink(symbol),
      title: apple ? "Otwórz w Giełdzie" : "Wykres na Yahoo",
      target: apple ? null : "_blank",
    };
  }

  async function load(silent = false) {
    if (!silent) loading = true;
    data = await api.portfolio(id);
    const next = await api.snapshots(id);
    if (!sameSnapshots(next, snapshots)) snapshots = next; // skip chart churn when unchanged
    if (!silent) loading = false;
  }
  async function refresh() {
    refreshError = ""; refreshing = true;
    try { await api.refresh(); await load(true); } // silent — update values in place, no skeleton
    catch (e) { refreshError = e.message || "Odświeżanie nie powiodło się"; }
    finally { refreshing = false; }
  }
  async function backfill() {
    refreshError = ""; backfilling = true;
    try { await api.backfill(); await load(); }
    catch (e) { refreshError = e.message || "Uzupełnianie historii nie powiodło się"; }
    finally { backfilling = false; }
  }
  async function pullRefresh() {
    if (refreshing) return;
    if (market.open) await refresh();
    else await load(true);
  }
  let expanded = $state({});
  // Largest holdings first; each row shows its slice of the portfolio value.
  let sortedPositions = $derived(byValueDesc(data?.positions ?? [], (p) => p.market_value_pln));
  let positionShares = $derived(shares(data?.positions ?? [], (p) => p.market_value_pln));
  function toggle(sym) { expanded[sym] = !expanded[sym]; }
  async function deleteTxn(txnId) {
    if (!confirm("Usunąć tę transakcję?")) return;
    await api.deleteTransaction(txnId);
    await load();
  }
  function startRename() { nameInput = data.name; nameError = ""; editingName = true; }
  async function saveName() {
    nameError = "";
    if (!nameInput.trim()) { nameError = "Nazwa nie może być pusta"; return; }
    try { await api.renamePortfolio(id, nameInput.trim()); editingName = false; await load(); }
    catch (e) { nameError = e.message || "Nie udało się zmienić nazwy"; }
  }
  onMount(() => {
    load();
    return onPriceRefresh(() => load(true)); // push from the server when prices refresh
  });
</script>

<PullToRefresh onRefresh={pullRefresh} disabled={loading || showAdd || showImport}>
{#if data}
<div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto space-y-6">
  <div>
    <Hero value={data.totals.market_value_pln} pnl={data.totals.pnl_pln} cost={data.totals.cost_pln}
          updatedAt={data.last_updated} incomplete={data.totals.incomplete}>
      {#snippet top()}
        <button type="button" class="mb-2 hidden items-center gap-1 text-sm text-neutral-content/70 hover:text-neutral-content sm:inline-flex"
                onclick={onBack} aria-label="Wróć do listy portfeli">
          <ChevronLeft size={16} /> Portfele
        </button>
        {#if editingName}
          <div class="flex flex-col gap-2 sm:flex-row">
            <input class="input flex-1 text-lg font-bold text-base-content" bind:value={nameInput} aria-label="Nazwa portfela" />
            <div class="flex gap-2">
              <button class="btn btn-accent btn-sm" onclick={saveName}>Zapisz</button>
              <button class="btn btn-ghost btn-sm text-neutral-content" onclick={() => (editingName = false)}>Anuluj</button>
            </div>
          </div>
        {:else}
          <div class="flex items-center gap-1.5">
            <h1 class="truncate text-xl font-bold leading-tight sm:text-2xl">{data.name}</h1>
            <button class="btn btn-ghost btn-xs btn-square text-accent hover:bg-white/10" onclick={startRename} aria-label="Zmień nazwę" title="Zmień nazwę">
              <Pencil size={15} />
            </button>
          </div>
        {/if}
      {/snippet}
    </Hero>
  </div>

  <div class="hidden items-center gap-2 sm:flex">
    <button class="btn btn-primary gap-2" onclick={() => (showAdd = true)}><Plus size={18} /> Dodaj transakcję</button>
    <SettingsMenu actions={[
      { label: refreshing ? "Odświeżanie…" : "Odśwież ceny", onclick: refresh, disabled: refreshing || !market.open,
        title: market.open ? "" : "Poza sesją (pn–pt 9:00–22:00) — ceny się nie zmieniają" },
      { label: backfilling ? "Uzupełnianie…" : "Uzupełnij historię", onclick: backfill, disabled: backfilling },
      { label: "Importuj raport XTB", onclick: () => (showImport = true) },
    ]} />
  </div>
  {#if nameError}<p class="text-error text-sm">{nameError}</p>{/if}
  {#if refreshError}<p class="text-error text-sm">⚠ {refreshError}</p>{/if}

  <div class="overflow-hidden rounded-2xl border border-base-300 bg-base-100">
    <table class="table text-sm">
      <thead><tr class="border-base-300 text-muted">
        <th class="text-left font-medium">Pozycja</th>
        <th class="hidden text-right font-medium sm:table-cell">Ilość</th>
        <th class="hidden text-right font-medium sm:table-cell">Śr. cena</th>
        <th class="hidden text-right font-medium sm:table-cell">Cena</th>
        <th class="hidden text-right font-medium sm:table-cell">Wartość</th>
        <th class="text-right font-medium">Zysk</th>
      </tr></thead>
      <tbody>
        {#each sortedPositions as pos (pos.symbol)}
          {@const link = instrumentLink(pos.symbol)}
          {@const share = positionShares.get(pos) ?? null}
          {@const returnPct = percent(pos.pnl_pln, pos.cost_pln)}
          <tr class="cursor-pointer border-base-300 align-top transition-colors hover:bg-base-200/60" onclick={() => toggle(pos.symbol)}>
            <td class="w-full min-w-0">
              <div class="flex items-start gap-2">
                <ChevronRight class={`mt-0.5 shrink-0 text-muted transition-transform ${expanded[pos.symbol] ? "rotate-90" : ""}`} size={16} />
                <div class="min-w-0 flex-1">
                  <div class="font-semibold leading-snug text-base-content">{displayName(pos)}</div>
                  <div class="mt-0.5 flex items-center gap-2 text-xs text-muted">
                    <span>{pos.symbol}</span>
                    <a href={link.href} target={link.target} rel="noopener"
                       class="inline-flex text-muted hover:text-base-content" title={link.title} onclick={(e) => e.stopPropagation()}>
                      <ExternalLink size={12} />
                    </a>
                    <span>{sharePercent(share)}</span>
                  </div>
                  <ShareBar {share} />
                </div>
              </div>
            </td>
            <td class="hidden whitespace-nowrap text-right sm:table-cell">{quantity(pos.quantity)}</td>
            <td class="hidden whitespace-nowrap text-right sm:table-cell">{money(pos.avg_price, pos.currency)}</td>
            <td class="hidden whitespace-nowrap text-right sm:table-cell">{money(pos.last_price, pos.currency)}</td>
            <td class="hidden whitespace-nowrap text-right sm:table-cell"><RollingNumber value={pos.market_value_pln} text={money(pos.market_value_pln)} /></td>
            <td class="whitespace-nowrap text-right">
              <div class="font-semibold {pnlClass(pos.pnl_pln)}"><RollingNumber value={pos.pnl_pln} text={signedMoney(pos.pnl_pln)} /></div>
              <div class="mt-0.5 text-xs font-medium {pnlClass(pos.pnl_pln)}">
                {#if returnPct}<RollingNumber value={pos.pnl_pln} text={returnPct} />{:else}—{/if}
              </div>
            </td>
          </tr>
          {#if expanded[pos.symbol]}
            <tr>
              <td colspan="6" class="p-0">
                <div class="border-y border-base-300/60 bg-base-200/60 px-4 py-3">
                  <div class="mb-4 grid grid-cols-2 gap-2 text-sm sm:hidden">
                    <div class="rounded-xl border border-base-300/50 bg-base-100 px-3 py-2">
                      <div class="text-xs text-muted">Ilość</div>
                      <div class="font-medium tabular-nums">{quantity(pos.quantity)}</div>
                    </div>
                    <div class="rounded-xl border border-base-300/50 bg-base-100 px-3 py-2">
                      <div class="text-xs text-muted">Wartość</div>
                      <div class="font-medium tabular-nums"><RollingNumber value={pos.market_value_pln} text={money(pos.market_value_pln)} /></div>
                    </div>
                    <div class="rounded-xl border border-base-300/50 bg-base-100 px-3 py-2">
                      <div class="text-xs text-muted">Śr. cena</div>
                      <div class="font-medium tabular-nums">{money(pos.avg_price, pos.currency)}</div>
                    </div>
                    <div class="rounded-xl border border-base-300/50 bg-base-100 px-3 py-2">
                      <div class="text-xs text-muted">Cena</div>
                      <div class="font-medium tabular-nums">{money(pos.last_price, pos.currency)}</div>
                    </div>
                  </div>
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">
                    Zakupy ({pos.transactions.length})
                  </div>
                  <div class="space-y-1.5">
                    {#each pos.transactions as t (t.id)}
                      <div class="rounded-xl border border-base-300/50 bg-base-100 px-3 py-2 text-sm">
                        <div class="relative grid grid-cols-2 gap-2 pr-8 sm:hidden">
                          <button class="btn btn-ghost btn-xs btn-circle text-error absolute right-0 top-0" onclick={() => deleteTxn(t.id)} aria-label="Usuń">
                            <Trash2 size={14} />
                          </button>
                          <div class="rounded-lg bg-base-200/70 px-3 py-2">
                            <div class="text-xs text-muted">Data</div>
                            <div class="font-medium tabular-nums">{t.executed_at.slice(0, 10)}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/70 px-3 py-2">
                            <div class="text-xs text-muted">Ilość</div>
                            <div class="font-medium tabular-nums">{quantity(t.quantity)}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/70 px-3 py-2">
                            <div class="text-xs text-muted">Cena</div>
                            <div class="font-medium tabular-nums">{money(t.price, t.currency)}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/70 px-3 py-2">
                            <div class="text-xs text-muted">Suma</div>
                            <div class="font-medium tabular-nums">{money(Number(t.quantity) * Number(t.price), t.currency)}</div>
                          </div>
                        </div>
                        <div class="hidden items-center gap-3 sm:flex">
                          <span class="text-base-content/60 sm:w-24 sm:shrink-0">{t.executed_at.slice(0, 10)}</span>
                          <span class="flex-1 text-right tabular-nums">{quantity(t.quantity)} × {money(t.price, t.currency)}</span>
                          <span class="w-32 text-right font-medium tabular-nums">{money(Number(t.quantity) * Number(t.price), t.currency)}</span>
                          <button class="btn btn-ghost btn-xs btn-circle text-error hidden sm:inline-flex" onclick={() => deleteTxn(t.id)} aria-label="Usuń">
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>
                    {/each}
                  </div>
                </div>
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  </div>

  <ChartPanel {snapshots} />
  {#if showAdd}
    <Modal title="Dodaj transakcję" onClose={() => (showAdd = false)}>
      <TransactionForm portfolioId={id} onAdded={() => { showAdd = false; load(); }} />
    </Modal>
  {/if}
  {#if showImport}
    <Modal title="Importuj raport XTB" onClose={closeImport}>
      <div class="space-y-4">
        <p class="rounded-xl bg-base-200/70 px-3 py-2 text-sm text-base-content/70">Wgraj plik .xlsx z historii operacji XTB. Transakcje już zaimportowane zostaną pominięte.</p>
        <label class="block">
          <span class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45">Plik Cash Operations</span>
          <input type="file" accept=".xlsx" class="file-input file-input-bordered w-full rounded-xl"
                 onchange={(e) => (importFile = e.currentTarget.files[0])} />
        </label>
        <button class="btn btn-primary w-full sm:w-auto" onclick={doImport} disabled={!importFile || importing}>
          {importing ? "Importowanie…" : "Importuj"}
        </button>
        {#if importResult}
          <div class="alert alert-success rounded-xl py-2 text-sm">
            <span>✓ Zaimportowano: <strong>{importResult.imported}</strong> · pominięto (już w bazie): <strong>{importResult.skipped}</strong></span>
          </div>
        {/if}
        {#if importError}
          <div class="alert alert-error rounded-xl py-2 text-sm"><span>⚠ {importError}</span></div>
        {/if}
      </div>
    </Modal>
  {/if}
</div>
{:else if loading}
  <div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto space-y-6">
    <div class="skeleton h-8 w-28"></div>
    <div class="rounded-2xl border border-base-300/60 bg-base-100/90 p-4 shadow-sm sm:p-5">
      <div class="space-y-4">
        <div class="flex items-start gap-3">
          <div class="skeleton h-11 w-11 shrink-0 rounded-xl"></div>
          <div class="min-w-0 flex-1 space-y-2">
            <div class="skeleton h-8 w-48"></div>
            <div class="skeleton h-3 w-44"></div>
          </div>
        </div>
        <div class="grid grid-cols-1 gap-2 sm:grid-cols-3">
          {#each Array(3) as _}
            <div class="rounded-xl bg-base-200/70 px-3 py-2.5">
              <div class="skeleton h-3 w-20"></div>
              <div class="mt-2 skeleton h-6 w-32"></div>
            </div>
          {/each}
        </div>
      </div>
    </div>
    <div class="hidden items-center gap-2 rounded-xl border border-base-300/60 bg-base-100/70 p-2 shadow-sm sm:flex">
      <div class="skeleton h-12 w-44"></div>
      <div class="skeleton h-12 w-12"></div>
    </div>
    <div class="flex justify-end gap-3">
      <div class="skeleton h-8 w-28"></div>
      <div class="skeleton h-4 w-44"></div>
    </div>
    <div class="overflow-hidden rounded-2xl border border-base-300/60 bg-base-100/90 shadow-sm">
      <table class="table text-sm">
        <thead class="bg-base-200/60">
          <tr>
            {#each Array(6) as _}
              <th><div class="skeleton h-4 w-full min-w-16"></div></th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each Array(4) as _}
            <tr>
              <td><div class="skeleton h-4 w-24"></div></td>
              <td><div class="skeleton h-4 w-16 ml-auto"></div></td>
              <td><div class="skeleton h-4 w-20 ml-auto"></div></td>
              <td><div class="skeleton h-4 w-20 ml-auto"></div></td>
              <td><div class="skeleton h-4 w-24 ml-auto"></div></td>
              <td><div class="skeleton h-4 w-24 ml-auto"></div></td>
            </tr>
          {/each}
        </tbody>
      </table>
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
{/if}
</PullToRefresh>

<MobileNav items={[
  { label: "Portfele", icon: Wallet, onclick: onBack },
  { label: "Dodaj", icon: Plus, onclick: () => (showAdd = true), disabled: !data },
  {
    label: refreshing ? "Trwa..." : "Ceny",
    icon: RefreshCw,
    onclick: refresh,
    disabled: !data || refreshing || !market.open,
    title: market.open ? "Odśwież ceny" : "Poza sesją"
  },
  {
    label: "Auto",
    icon: Clock,
    disabled: !data,
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
    disabled: !data,
    submenu: [
      { label: backfilling ? "Uzupełnianie..." : "Uzupełnij historię", onclick: backfill, disabled: backfilling },
      { label: "Importuj raport XTB", onclick: () => (showImport = true) }
    ]
  }
]} />
