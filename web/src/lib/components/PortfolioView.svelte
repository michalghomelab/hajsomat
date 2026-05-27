<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass } from "../format.js";
  import TransactionForm from "./TransactionForm.svelte";
  import PnlChart from "./PnlChart.svelte";
  let { id, onBack } = $props();
  let data = $state(null); let snapshots = $state([]);

  async function load() {
    data = await api.portfolio(id);
    snapshots = await api.snapshots(id);
  }
  async function refresh() { await api.refresh(); await load(); }
  onMount(load);
</script>

{#if data}
<div class="p-6 max-w-4xl mx-auto space-y-6">
  <button class="text-blue-600" onclick={onBack}>← Portfele</button>
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">{data.name}</h1>
    <button class="border px-3 py-1 rounded" onclick={refresh}>Odśwież ceny</button>
  </div>
  <div class="text-lg">
    Wartość: <strong>{money(data.totals.market_value_pln)}</strong>
    · <span class={pnlClass(data.totals.pnl_pln)}>P/L {money(data.totals.pnl_pln)}</span>
  </div>

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
