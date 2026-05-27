<script>
  import PnlChart from "./PnlChart.svelte";
  import DailyChangeChart from "./DailyChangeChart.svelte";
  import { RELATIVE, availableYears, loadRange, saveRange, filterSnapshots } from "../chartRange.js";

  let { snapshots = [] } = $props();
  let range = $state(loadRange());

  let years = $derived(availableYears(snapshots));
  // Fall back to lifetime if the persisted year isn't present in the data.
  let effectiveRange = $derived(
    range.startsWith("year:") && !years.includes(range.slice(5)) ? "all" : range
  );
  let filtered = $derived(filterSnapshots(snapshots, effectiveRange));

  function select(id) {
    range = id;
    saveRange(id);
  }
  const cls = (id) => `btn btn-xs ${effectiveRange === id ? "btn-primary" : "btn-ghost"}`;
</script>

<div class="space-y-2">
  {#if snapshots.length}
    <div class="flex flex-wrap gap-1 justify-end">
      {#each RELATIVE as r}
        <button class={cls(r.id)} onclick={() => select(r.id)}>{r.label}</button>
      {/each}
      {#each years as y}
        <button class={cls(`year:${y}`)} onclick={() => select(`year:${y}`)}>{y}</button>
      {/each}
      <button class={cls("all")} onclick={() => select("all")}>Całość</button>
    </div>
  {/if}
  <PnlChart snapshots={filtered} />
  <div>
    <h3 class="text-sm font-semibold text-base-content/70 mb-1">Zmiana dzień do dnia (wpłaty vs rynek)</h3>
    <DailyChangeChart snapshots={filtered} />
  </div>
</div>
