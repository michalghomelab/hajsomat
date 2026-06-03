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

<div class="space-y-4">
  <div class="relative">
    <label class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45" for="ticker-search">Instrument</label>
    <input id="ticker-search" class="input input-bordered w-full rounded-xl" placeholder="Szukaj tickera (np. AAPL)" bind:value={query} oninput={search} />
    {#if results.length}
      <ul class="absolute z-10 mt-2 max-h-56 w-full overflow-auto rounded-xl border border-base-300/70 bg-base-100 p-1 shadow-xl">
        {#each results as r}
          <li>
            <button type="button" class="w-full rounded-lg px-3 py-2 text-left hover:bg-base-200" onclick={() => pick(r)}>
              <span class="block font-semibold">{r.symbol}</span>
              <span class="block truncate text-xs text-base-content/60">{r.name}{r.currency ? ` (${r.currency})` : r.exchange ? ` · ${r.exchange}` : ""}</span>
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </div>
  <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
    <label class="block">
      <span class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45">Ilość</span>
      <input class="input input-bordered w-full rounded-xl" placeholder="0" inputmode="decimal" bind:value={quantity} />
    </label>
    <label class="block">
      <span class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45">Cena</span>
      <input class="input input-bordered w-full rounded-xl" placeholder="0,00" inputmode="decimal" bind:value={price} />
    </label>
    <label class="block">
      <span class="mb-1.5 block text-xs font-medium uppercase tracking-wide text-base-content/45">Data</span>
      <input class="input input-bordered w-full rounded-xl" type="date" bind:value={executedAt} />
    </label>
  </div>
  {#if error}<p class="rounded-xl bg-error/10 px-3 py-2 text-sm text-error">{error}</p>{/if}
  <button class="btn btn-success w-full sm:w-auto" onclick={submit}>Zapisz transakcję</button>
</div>
