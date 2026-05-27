<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass } from "../format.js";
  import TransactionForm from "./TransactionForm.svelte";
  import PnlChart from "./PnlChart.svelte";
  let { id, onBack } = $props();
  let data = $state(null); let snapshots = $state([]);
  let refreshError = $state(""); let refreshing = $state(false);
  let editingName = $state(false); let nameInput = $state(""); let nameError = $state("");

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
  <button class="text-blue-600" onclick={onBack}>← Portfele</button>
  <div class="flex justify-between items-center gap-2">
    {#if editingName}
      <div class="flex gap-2 flex-1">
        <input class="border rounded px-3 py-2 flex-1 text-xl font-bold" bind:value={nameInput} />
        <button class="bg-blue-600 text-white px-3 py-1 rounded" onclick={saveName}>Zapisz</button>
        <button class="border px-3 py-1 rounded" onclick={() => (editingName = false)}>Anuluj</button>
      </div>
    {:else}
      <h1 class="text-2xl font-bold flex items-center gap-2">
        {data.name}
        <button class="text-sm text-blue-600 font-normal" onclick={startRename}>✎ zmień nazwę</button>
      </h1>
      <button class="border px-3 py-1 rounded" onclick={refresh} disabled={refreshing}>
        {refreshing ? "Odświeżanie…" : "Odśwież ceny"}
      </button>
    {/if}
  </div>
  {#if nameError}<p class="text-red-600 text-sm">{nameError}</p>{/if}
  {#if refreshError}<p class="text-red-600 text-sm">⚠ {refreshError}</p>{/if}
  <div class="text-lg">
    Wartość: <strong>{money(data.totals.market_value_pln)}</strong>
    · <span class={pnlClass(data.totals.pnl_pln)}>P/L {money(data.totals.pnl_pln)}</span>
  </div>
  {#if data.totals.incomplete}
    <p class="text-amber-600 text-sm">⚠ Część pozycji nie ma aktualnej wyceny — suma PLN jest niepełna. Kliknij „Odśwież ceny".</p>
  {/if}

  <table class="w-full text-sm border">
    <thead class="bg-gray-100"><tr>
      <th class="text-left p-2">Symbol</th><th class="text-right p-2">Ilość</th>
      <th class="text-right p-2">Śr. cena</th><th class="text-right p-2">Cena</th>
      <th class="text-right p-2">Wartość (PLN)</th><th class="text-right p-2">P/L (PLN)</th>
    </tr></thead>
    <tbody>
      {#each data.positions as pos}
        <tr class="border-t">
          <td class="p-2">{pos.symbol}</td>
          <td class="p-2 text-right">{pos.quantity}</td>
          <td class="p-2 text-right">{money(pos.avg_price, pos.currency)}</td>
          <td class="p-2 text-right">{money(pos.last_price, pos.currency)}</td>
          <td class="p-2 text-right">{money(pos.market_value_pln)}</td>
          <td class="p-2 text-right {pnlClass(pos.pnl_pln)}">{money(pos.pnl_pln)}</td>
        </tr>
      {/each}
    </tbody>
  </table>

  <PnlChart {snapshots} />
  <TransactionForm portfolioId={id} onAdded={load} />
</div>
{/if}
