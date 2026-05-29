<script>
  import PortfolioChart from "./PortfolioChart.svelte";
  import {
    RELATIVE, RESOLUTIONS, availableYears,
    loadRange, saveRange, loadResolution, saveResolution,
    filterSnapshots, resample,
  } from "../chartRange.js";

  let { snapshots = [] } = $props();
  let range = $state(loadRange());
  let resolution = $state(loadResolution());

  let years = $derived(availableYears(snapshots));
  // Fall back to lifetime if the persisted year isn't present in the data.
  let effectiveRange = $derived(
    range.startsWith("year:") && !years.includes(range.slice(5)) ? "all" : range
  );
  let view = $derived(resample(filterSnapshots(snapshots, effectiveRange), resolution));

  function selectRange(id) {
    range = id;
    saveRange(id);
  }
  function selectResolution(id) {
    resolution = id;
    saveResolution(id);
  }
  const rangeCls = (id) => `btn btn-xs ${effectiveRange === id ? "btn-primary" : "btn-ghost"}`;
  const resCls = (id) => `btn btn-xs ${resolution === id ? "btn-primary" : "btn-ghost"}`;
</script>

<div class="space-y-2">
  {#if snapshots.length}
    <div class="flex flex-wrap gap-1 items-center">
      <span class="text-xs text-base-content/50 mr-auto">Zakres</span>
      {#each RELATIVE as r}
        <button class={rangeCls(r.id)} onclick={() => selectRange(r.id)}>{r.label}</button>
      {/each}
      {#each years as y}
        <button class={rangeCls(`year:${y}`)} onclick={() => selectRange(`year:${y}`)}>{y}</button>
      {/each}
      <button class={rangeCls("all")} onclick={() => selectRange("all")}>Całość</button>
    </div>
    <div class="flex flex-wrap gap-1 items-center">
      <span class="text-xs text-base-content/50 mr-auto">Rozdzielczość</span>
      {#each RESOLUTIONS as r}
        <button class={resCls(r.id)} onclick={() => selectResolution(r.id)}>{r.label}</button>
      {/each}
    </div>
  {/if}
  <PortfolioChart snapshots={view} />
</div>
