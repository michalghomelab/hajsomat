<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass, percent } from "../format.js";
  import TransactionForm from "./TransactionForm.svelte";
  import PnlChart from "./PnlChart.svelte";
  import DailyChangeChart from "./DailyChangeChart.svelte";
  import Modal from "./Modal.svelte";
  let { id, onBack } = $props();
  let data = $state(null); let snapshots = $state([]);
  let refreshError = $state(""); let refreshing = $state(false); let backfilling = $state(false);
  let editingName = $state(false); let nameInput = $state(""); let nameError = $state("");
  let showAdd = $state(false);

  async function load() {
    data = await api.portfolio(id);
    snapshots = await api.snapshots(id);
  }
  async function refresh() {
    refreshError = ""; refreshing = true;
    try { await api.refresh(); await load(); }
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
  onMount(load);
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
    <div class="flex gap-2">
      <button class="btn btn-outline btn-sm" onclick={refresh} disabled={refreshing}>
        {refreshing ? "Odświeżanie…" : "Odśwież ceny"}
      </button>
      <button class="btn btn-outline btn-sm" onclick={backfill} disabled={backfilling}>
        {backfilling ? "Uzupełnianie…" : "Uzupełnij historię"}
      </button>
    </div>
  </div>
  {#if nameError}<p class="text-error text-sm">{nameError}</p>{/if}
  {#if refreshError}<p class="text-error text-sm">⚠ {refreshError}</p>{/if}

  <div class="card bg-base-100 shadow-sm">
    <div class="card-body py-4">
      <p class="text-lg">
        Wartość: <strong>{money(data.totals.market_value_pln)}</strong>
        · <span class={pnlClass(data.totals.pnl_pln)}>P/L {money(data.totals.pnl_pln)} ({percent(data.totals.pnl_pln, data.totals.cost_pln)})</span>
      </p>
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
        {#each data.positions as pos}
          <tr class="cursor-pointer hover" onclick={() => toggle(pos.symbol)}>
            <td>{expanded[pos.symbol] ? "▾" : "▸"} {pos.symbol}</td>
            <td class="text-right">{pos.quantity}</td>
            <td class="text-right">{money(pos.avg_price, pos.currency)}</td>
            <td class="text-right">{money(pos.last_price, pos.currency)}</td>
            <td class="text-right">{money(pos.market_value_pln)}</td>
            <td class="text-right {pnlClass(pos.pnl_pln)}">{money(pos.pnl_pln)}</td>
          </tr>
          {#if expanded[pos.symbol]}
            <tr class="bg-base-200">
              <td colspan="6" class="p-2">
                <div class="font-semibold text-xs mb-1">Zakupy ({pos.transactions.length})</div>
                <table class="w-full text-xs">
                  <thead><tr class="text-base-content/60">
                    <th class="text-left p-1">Data</th><th class="text-right p-1">Ilość</th>
                    <th class="text-right p-1">Cena</th><th class="text-right p-1">Wartość</th><th class="p-1"></th>
                  </tr></thead>
                  <tbody>
                    {#each pos.transactions as t}
                      <tr class="border-t border-base-300">
                        <td class="p-1">{t.executed_at.slice(0, 10)}</td>
                        <td class="p-1 text-right">{t.quantity}</td>
                        <td class="p-1 text-right">{money(t.price, t.currency)}</td>
                        <td class="p-1 text-right">{money(Number(t.quantity) * Number(t.price), t.currency)}</td>
                        <td class="p-1 text-right"><button class="btn btn-ghost btn-xs text-error" onclick={() => deleteTxn(t.id)}>usuń</button></td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  </div>

  <PnlChart {snapshots} />
  <div>
    <h2 class="text-sm font-semibold text-base-content/70 mb-1">Zmiana dzień do dnia</h2>
    <DailyChangeChart {snapshots} />
  </div>
  {#if showAdd}
    <Modal title="Dodaj transakcję" onClose={() => (showAdd = false)}>
      <TransactionForm portfolioId={id} onAdded={() => { showAdd = false; load(); }} />
    </Modal>
  {/if}
</div>
{/if}
