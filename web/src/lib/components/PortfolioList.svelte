<script>
  import { onMount } from "svelte";
  import { api } from "../api.js";
  import { money, pnlClass } from "../format.js";
  let { onSelect } = $props();
  let portfolios = $state([]);
  let newName = $state("");

  async function load() { portfolios = await api.portfolios(); }
  async function create() {
    if (!newName.trim()) return;
    await api.createPortfolio(newName.trim());
    newName = ""; await load();
  }
  onMount(load);
</script>

<div class="p-6 max-w-3xl mx-auto">
  <h1 class="text-2xl font-bold mb-4">Moje portfele</h1>
  <div class="flex gap-2 mb-6">
    <input class="border rounded px-3 py-2 flex-1" placeholder="Nazwa portfela" bind:value={newName} />
    <button class="bg-blue-600 text-white px-4 py-2 rounded" onclick={create}>Dodaj</button>
  </div>
  <ul class="space-y-2">
    {#each portfolios as p}
      <li class="border rounded p-4 flex justify-between cursor-pointer hover:bg-gray-50" onclick={() => onSelect(p.id)}>
        <span class="font-medium">{p.name}</span>
        <span class={pnlClass(p.pnl_pln)}>
          {money(p.market_value_pln)} ({money(p.pnl_pln)}){#if p.incomplete}<span class="text-amber-600" title="Suma niepełna — brak części wycen"> *</span>{/if}
        </span>
      </li>
    {/each}
  </ul>
</div>
