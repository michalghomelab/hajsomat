<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass, percent, dateTime } from "../format.js";
  import TransactionForm from "./TransactionForm.svelte";
  import ChartPanel from "./ChartPanel.svelte";
  import RefreshIntervalSelect from "./RefreshIntervalSelect.svelte";
  import Countdown from "./Countdown.svelte";
  import RollingNumber from "./RollingNumber.svelte";
  import Modal from "./Modal.svelte";
  import MobileNav from "./MobileNav.svelte";
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
  import Settings from "@lucide/svelte/icons/settings";
  import Pencil from "@lucide/svelte/icons/pencil";
  import ChevronLeft from "@lucide/svelte/icons/chevron-left";
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
  let expanded = $state({});
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

{#if data}
<div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto space-y-6">
  <button class="btn btn-outline btn-sm gap-1 pl-2 hidden sm:inline-flex" onclick={onBack} aria-label="Wróć do listy portfeli">
    <ChevronLeft size={18} /> Portfele
  </button>
  <div class="flex justify-between items-center gap-2">
    {#if editingName}
      <div class="flex gap-2 flex-1">
        <input class="input input-bordered flex-1 text-xl font-bold" bind:value={nameInput} />
        <button class="btn btn-primary btn-sm" onclick={saveName}>Zapisz</button>
        <button class="btn btn-ghost btn-sm" onclick={() => (editingName = false)}>Anuluj</button>
      </div>
    {:else}
      <h1 class="text-2xl font-bold flex items-center gap-2">
        {data.name}
        <button class="btn btn-ghost btn-xs btn-square text-primary" onclick={startRename} aria-label="Zmień nazwę" title="Zmień nazwę"><Pencil size={16} /></button>
      </h1>
    {/if}
  </div>

  <div class="hidden sm:flex items-center gap-2 border-y border-base-300 py-2">
    <button class="btn btn-success" onclick={() => (showAdd = true)}>+ Dodaj transakcję</button>
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-outline btn-square" aria-label="Akcje" title="Akcje">
        <Settings size={20} />
      </div>
      <ul class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-56 p-2 mt-1">
        <li>
          <button class="disabled:opacity-50" onclick={refresh} disabled={refreshing || !market.open}
                  title={market.open ? "" : "Poza sesją (pn–pt 9:00–22:00) — ceny się nie zmieniają"}>
            {refreshing ? "Odświeżanie…" : "Odśwież ceny"}
          </button>
        </li>
        <li>
          <button onclick={backfill} disabled={backfilling}>
            {backfilling ? "Uzupełnianie…" : "Uzupełnij historię"}
          </button>
        </li>
        <li><button onclick={() => (showImport = true)}>Importuj raport XTB</button></li>
      </ul>
    </div>
  </div>
  <div class="flex flex-wrap items-center justify-end gap-x-3 gap-y-1">
    <span class="hidden sm:inline-flex"><RefreshIntervalSelect /></span>
    <Countdown field="next_refresh_at" label="odświeżenie cen" title="Następne automatyczne odświeżenie cen" />
  </div>
  {#if nameError}<p class="text-error text-sm">{nameError}</p>{/if}
  {#if refreshError}<p class="text-error text-sm">⚠ {refreshError}</p>{/if}

  <div class="card bg-base-100 shadow-sm">
    <div class="card-body py-4">
      <p class="text-lg flex flex-wrap items-baseline gap-x-2 gap-y-1">
        <span class="whitespace-nowrap">Wartość: <strong><RollingNumber value={data.totals.market_value_pln} text={money(data.totals.market_value_pln)} /></strong></span>
        <span class="whitespace-nowrap {pnlClass(data.totals.pnl_pln)}">P/L <RollingNumber value={data.totals.pnl_pln} text={money(data.totals.pnl_pln)} />
        (<RollingNumber value={data.totals.pnl_pln} text={percent(data.totals.pnl_pln, data.totals.cost_pln)} />)</span>
      </p>
      <p class="text-xs text-base-content/60">Ceny zaktualizowane: {dateTime(data.last_updated)}</p>
      {#if data.totals.incomplete}
        <p class="text-warning text-sm">⚠ Część pozycji nie ma aktualnej wyceny — suma PLN jest niepełna. Kliknij „Odśwież ceny".</p>
      {/if}
    </div>
  </div>

  <div class="overflow-x-auto card bg-base-100 shadow-sm">
    <table class="table text-sm">
      <thead><tr>
        <th class="text-left">Symbol</th><th class="hidden text-right sm:table-cell">Ilość</th>
        <th class="hidden text-right sm:table-cell">Śr. cena</th><th class="hidden text-right sm:table-cell">Cena</th>
        <th class="hidden text-right sm:table-cell">Wartość (PLN)</th><th class="text-right">P/L (PLN)</th>
      </tr></thead>
      <tbody>
        {#each data.positions as pos (pos.symbol)}
          <tr class="cursor-pointer hover" onclick={() => toggle(pos.symbol)}>
            <td>
              {expanded[pos.symbol] ? "▾" : "▸"} <span title={pos.name}>{pos.symbol}</span>
              <a href={`https://finance.yahoo.com/quote/${pos.symbol}`} target="_blank" rel="noopener"
                 class="link link-primary ml-1 text-xs" title="Wykres na Yahoo" onclick={(e) => e.stopPropagation()}>↗</a>
            </td>
            <td class="hidden text-right sm:table-cell">{pos.quantity}</td>
            <td class="hidden text-right sm:table-cell">{money(pos.avg_price, pos.currency)}</td>
            <td class="hidden text-right sm:table-cell">{money(pos.last_price, pos.currency)}</td>
            <td class="hidden text-right sm:table-cell"><RollingNumber value={pos.market_value_pln} text={money(pos.market_value_pln)} /></td>
            <td class="text-right {pnlClass(pos.pnl_pln)}"><RollingNumber value={pos.pnl_pln} text={money(pos.pnl_pln)} /></td>
          </tr>
          {#if expanded[pos.symbol]}
            <tr>
              <td colspan="6" class="p-0">
                <div class="bg-base-200/60 px-4 py-3">
                  {#if pos.name}
                    <div class="text-xs font-light text-base-content/50 mb-2">{pos.name} ({pos.symbol})</div>
                  {/if}
                  <div class="mb-4 grid grid-cols-2 gap-2 text-sm sm:hidden">
                    <div class="rounded-lg bg-base-100 px-3 py-2">
                      <div class="text-xs text-base-content/50">Ilość</div>
                      <div class="font-medium tabular-nums">{pos.quantity}</div>
                    </div>
                    <div class="rounded-lg bg-base-100 px-3 py-2">
                      <div class="text-xs text-base-content/50">Wartość</div>
                      <div class="font-medium tabular-nums"><RollingNumber value={pos.market_value_pln} text={money(pos.market_value_pln)} /></div>
                    </div>
                    <div class="rounded-lg bg-base-100 px-3 py-2">
                      <div class="text-xs text-base-content/50">Śr. cena</div>
                      <div class="font-medium tabular-nums">{money(pos.avg_price, pos.currency)}</div>
                    </div>
                    <div class="rounded-lg bg-base-100 px-3 py-2">
                      <div class="text-xs text-base-content/50">Cena</div>
                      <div class="font-medium tabular-nums">{money(pos.last_price, pos.currency)}</div>
                    </div>
                  </div>
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">
                    Zakupy ({pos.transactions.length})
                  </div>
                  <div class="space-y-1.5">
                    {#each pos.transactions as t (t.id)}
                      <div class="rounded-lg bg-base-100 px-3 py-2 text-sm">
                        <div class="relative grid grid-cols-2 gap-2 pr-8 sm:hidden">
                          <button class="btn btn-ghost btn-xs btn-circle text-error absolute right-0 top-0" onclick={() => deleteTxn(t.id)} aria-label="Usuń">✕</button>
                          <div class="rounded-lg bg-base-200/60 px-3 py-2">
                            <div class="text-xs text-base-content/50">Data</div>
                            <div class="font-medium tabular-nums">{t.executed_at.slice(0, 10)}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/60 px-3 py-2">
                            <div class="text-xs text-base-content/50">Ilość</div>
                            <div class="font-medium tabular-nums">{t.quantity}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/60 px-3 py-2">
                            <div class="text-xs text-base-content/50">Cena</div>
                            <div class="font-medium tabular-nums">{money(t.price, t.currency)}</div>
                          </div>
                          <div class="rounded-lg bg-base-200/60 px-3 py-2">
                            <div class="text-xs text-base-content/50">Suma</div>
                            <div class="font-medium tabular-nums">{money(Number(t.quantity) * Number(t.price), t.currency)}</div>
                          </div>
                        </div>
                        <div class="hidden items-center gap-3 sm:flex">
                          <span class="text-base-content/60 sm:w-24 sm:shrink-0">{t.executed_at.slice(0, 10)}</span>
                          <span class="flex-1 text-right tabular-nums">{t.quantity} × {money(t.price, t.currency)}</span>
                          <span class="w-32 text-right font-medium tabular-nums">{money(Number(t.quantity) * Number(t.price), t.currency)}</span>
                          <button class="btn btn-ghost btn-xs btn-circle text-error hidden sm:inline-flex" onclick={() => deleteTxn(t.id)} aria-label="Usuń">✕</button>
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
      <div class="space-y-3">
        <p class="text-sm text-base-content/70">Wgraj plik .xlsx z historią operacji (Cash Operations) z XTB. Transakcje już zaimportowane zostaną pominięte.</p>
        <input type="file" accept=".xlsx" class="file-input file-input-bordered w-full"
               onchange={(e) => (importFile = e.currentTarget.files[0])} />
        <button class="btn btn-primary" onclick={doImport} disabled={!importFile || importing}>
          {importing ? "Importowanie…" : "Importuj"}
        </button>
        {#if importResult}
          <div class="alert alert-success text-sm py-2">
            <span>✓ Zaimportowano: <strong>{importResult.imported}</strong> · pominięto (już w bazie): <strong>{importResult.skipped}</strong></span>
          </div>
        {/if}
        {#if importError}
          <div class="alert alert-error text-sm py-2"><span>⚠ {importError}</span></div>
        {/if}
      </div>
    </Modal>
  {/if}
</div>
{:else if loading}
  <div class="p-6 pb-28 sm:pb-6 max-w-4xl mx-auto space-y-6">
    <div class="skeleton h-8 w-28"></div>
    <div class="skeleton h-8 w-48"></div>
    <div class="flex items-center gap-2 border-y border-base-300 py-2">
      <div class="skeleton h-12 w-40"></div>
      <div class="skeleton h-12 w-12"></div>
    </div>
    <div class="flex justify-end gap-3">
      <div class="skeleton h-8 w-28"></div>
      <div class="skeleton h-4 w-44"></div>
    </div>
    <div class="card bg-base-100 shadow-sm">
      <div class="card-body gap-2 py-4">
        <div class="flex flex-wrap items-baseline gap-2">
          <div class="skeleton h-6 w-44"></div>
          <div class="skeleton h-6 w-48"></div>
        </div>
        <div class="skeleton h-3 w-48"></div>
      </div>
    </div>
    <div class="overflow-x-auto card bg-base-100 shadow-sm">
      <table class="table text-sm">
        <thead>
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
{/if}

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
