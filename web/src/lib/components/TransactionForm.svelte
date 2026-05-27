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
    if (!executedAt) { error = "Podaj datę zakupu"; return; }
    if (!quantity || !price) { error = "Podaj ilość i cenę"; return; }
    try {
      await api.addTransaction(portfolioId, {
        symbol: selected.symbol, mic: selected.mic, currency: selected.currency,
        quantity, price, executed_at: executedAt,
      });
      query = ""; selected = null; quantity = ""; price = ""; executedAt = "";
      onAdded();
    } catch (e) { error = e.message || "Nie udało się zapisać transakcji"; }
  }
</script>

<div class="space-y-3">
  <div class="relative">
    <input class="input input-bordered w-full" placeholder="Szukaj tickera (np. AAPL)" bind:value={query} oninput={search} />
    {#if results.length}
      <ul class="absolute z-10 bg-base-100 border border-base-300 rounded w-full mt-1 max-h-48 overflow-auto">
        {#each results as r}
          <li class="px-3 py-2 hover:bg-base-200 cursor-pointer" onclick={() => pick(r)}>{r.symbol} — {r.name}{r.currency ? ` (${r.currency})` : r.exchange ? ` · ${r.exchange}` : ""}</li>
        {/each}
      </ul>
    {/if}
  </div>
  <div class="grid grid-cols-3 gap-2">
    <input class="input input-bordered" placeholder="Ilość" bind:value={quantity} />
    <input class="input input-bordered" placeholder="Cena" bind:value={price} />
    <input class="input input-bordered" type="date" bind:value={executedAt} />
  </div>
  {#if error}<p class="text-error text-sm">{error}</p>{/if}
  <button class="btn btn-success" onclick={submit}>Zapisz</button>
</div>
