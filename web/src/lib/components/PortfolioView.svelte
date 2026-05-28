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
  import { market } from "../marketStatus.svelte.js";
  import { onPriceRefresh } from "../priceStream.js";
  import { sameSnapshots } from "../snapshots.js";
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
<div class="p-6 max-w-4xl mx-auto space-y-6">
  <button class="btn btn-ghost btn-sm" onclick={onBack}>← Portfele</button>
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
        <button class="btn btn-ghost btn-xs text-primary font-normal" onclick={startRename}>✎ zmień nazwę</button>
      </h1>
    {/if}
  </div>

  <div class="flex justify-between items-center gap-2 border-y border-base-300 py-2">
    <button class="btn btn-success" onclick={() => (showAdd = true)}>+ Dodaj transakcję</button>
    <div class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-outline btn-sm">Akcje ▾</div>
      <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box shadow-lg z-10 w-56 p-2 mt-1">
        <li>
          <button onclick={refresh} disabled={refreshing || !market.open}
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
  <div class="flex items-center justify-end gap-3">
    <RefreshIntervalSelect />
    <Countdown field="next_refresh_at" label="odświeżenie cen" title="Następne automatyczne odświeżenie cen" />
  </div>
  {#if nameError}<p class="text-error text-sm">{nameError}</p>{/if}
  {#if refreshError}<p class="text-error text-sm">⚠ {refreshError}</p>{/if}

  <div class="card bg-base-100 shadow-sm">
    <div class="card-body py-4">
      <p class="text-lg">
        Wartość: <strong><RollingNumber value={data.totals.market_value_pln} text={money(data.totals.market_value_pln)} /></strong>
        · <span class={pnlClass(data.totals.pnl_pln)}>P/L <RollingNumber value={data.totals.pnl_pln} text={money(data.totals.pnl_pln)} />
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
        <th class="text-left">Symbol</th><th class="text-right">Ilość</th>
        <th class="text-right">Śr. cena</th><th class="text-right">Cena</th>
        <th class="text-right">Wartość (PLN)</th><th class="text-right">P/L (PLN)</th>
      </tr></thead>
      <tbody>
        {#each data.positions as pos (pos.symbol)}
          <tr class="cursor-pointer hover" onclick={() => toggle(pos.symbol)}>
            <td>
              {expanded[pos.symbol] ? "▾" : "▸"} {pos.symbol}
              <a href={`https://finance.yahoo.com/quote/${pos.symbol}`} target="_blank" rel="noopener"
                 class="link link-primary ml-1 text-xs" title="Wykres na Yahoo" onclick={(e) => e.stopPropagation()}>↗</a>
            </td>
            <td class="text-right">{pos.quantity}</td>
            <td class="text-right">{money(pos.avg_price, pos.currency)}</td>
            <td class="text-right">{money(pos.last_price, pos.currency)}</td>
            <td class="text-right"><RollingNumber value={pos.market_value_pln} text={money(pos.market_value_pln)} /></td>
            <td class="text-right {pnlClass(pos.pnl_pln)}"><RollingNumber value={pos.pnl_pln} text={money(pos.pnl_pln)} /></td>
          </tr>
          {#if expanded[pos.symbol]}
            <tr>
              <td colspan="6" class="p-0">
                <div class="bg-base-200/60 px-4 py-3">
                  <div class="text-xs font-semibold uppercase tracking-wide text-base-content/60 mb-2">
                    Zakupy ({pos.transactions.length})
                  </div>
                  <div class="space-y-1.5">
                    {#each pos.transactions as t (t.id)}
                      <div class="flex items-center gap-3 rounded-lg bg-base-100 px-3 py-2 text-sm">
                        <span class="text-base-content/60 w-24 shrink-0">{t.executed_at.slice(0, 10)}</span>
                        <span class="flex-1 text-right tabular-nums">{t.quantity} × {money(t.price, t.currency)}</span>
                        <span class="w-32 text-right font-medium tabular-nums">{money(Number(t.quantity) * Number(t.price), t.currency)}</span>
                        <button class="btn btn-ghost btn-xs btn-circle text-error" onclick={() => deleteTxn(t.id)} aria-label="Usuń">✕</button>
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
  <div class="p-6 max-w-4xl mx-auto space-y-6">
    <div class="skeleton h-8 w-32"></div>
    <div class="skeleton h-12 w-full"></div>
    <div class="skeleton h-24 w-full"></div>
    <div class="skeleton h-64 w-full"></div>
    <div class="skeleton h-80 w-full"></div>
  </div>
{/if}
