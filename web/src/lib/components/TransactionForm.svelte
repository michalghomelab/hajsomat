<script>
  import { api } from "../api.js";
  let { portfolioId, onAdded } = $props();
  let query = $state(""); let results = $state([]); let selected = $state(null);
  let quantity = $state(""); let price = $state(""); let executedAt = $state("");
  let error = $state("");

  async function search() { results = query.trim() ? await api.searchInstruments(query) : []; }
  function pick(r) { selected = r; query = `${r.symbol} — ${r.name}`; results = []; }
  async function submit() {
    error = "";
    if (!selected) { error = "Wybierz instrument z listy"; return; }
    try {
      await api.addTransaction(portfolioId, {
        symbol: selected.symbol, mic: selected.mic, currency: selected.currency,
        quantity, price, executed_at: new Date(executedAt).toISOString(),
      });
      query = ""; selected = null; quantity = ""; price = ""; executedAt = "";
      onAdded();
    } catch (e) { error = "Nie udało się zapisać transakcji"; }
  }
</script>

<div class="border rounded p-4 space-y-3">
  <h3 class="font-semibold">Dodaj transakcję</h3>
  <div class="relative">
    <input class="border rounded px-3 py-2 w-full" placeholder="Szukaj tickera (np. AAPL)" bind:value={query} oninput={search} />
    {#if results.length}
      <ul class="absolute z-10 bg-white border rounded w-full mt-1 max-h-48 overflow-auto">
        {#each results as r}
          <li class="px-3 py-2 hover:bg-gray-100 cursor-pointer" onclick={() => pick(r)}>{r.symbol} — {r.name}{r.currency ? ` (${r.currency})` : r.exchange ? ` · ${r.exchange}` : ""}</li>
        {/each}
      </ul>
    {/if}
  </div>
  <div class="grid grid-cols-3 gap-2">
    <input class="border rounded px-3 py-2" placeholder="Ilość" bind:value={quantity} />
    <input class="border rounded px-3 py-2" placeholder="Cena" bind:value={price} />
    <input class="border rounded px-3 py-2" type="date" bind:value={executedAt} />
  </div>
  {#if error}<p class="text-red-600 text-sm">{error}</p>{/if}
  <button class="bg-green-600 text-white px-4 py-2 rounded" onclick={submit}>Zapisz</button>
</div>
