<script>
  import PortfolioChart from "./PortfolioChart.svelte";
  import {
    RELATIVE, RESOLUTIONS, availableYears,
    loadRange, saveRange, loadResolution, saveResolution,
    filterSnapshots, resample,
  } from "../chartRange.js";
  import MoveHorizontal from "@lucide/svelte/icons/move-horizontal";

  let { snapshots = [] } = $props();
  let range = $state(loadRange());
  let resolution = $state(loadResolution());

  let years = $derived(availableYears(snapshots));
  // Fall back to lifetime if the persisted year isn't present in the data.
  let effectiveRange = $derived(
    range.startsWith("year:") && !years.includes(range.slice(5)) ? "all" : range
  );
  let view = $derived(resample(filterSnapshots(snapshots, effectiveRange), resolution));
  let chartKey = $derived(`${effectiveRange}:${resolution}`);

  function selectRange(id) {
    range = id;
    saveRange(id);
  }
  function selectResolution(id) {
    resolution = id;
    saveResolution(id);
  }
  const chartButtonBase = "btn btn-sm sm:btn-xs";
  const rangeCls = (id) => `${chartButtonBase} ${effectiveRange === id ? "btn-primary" : "btn-ghost"}`;
  const resCls = (id) => `${chartButtonBase} ${resolution === id ? "btn-primary" : "btn-ghost"}`;
</script>

<div class="space-y-2">
  {#if snapshots.length}
    <div class="flex flex-col gap-1 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-xs text-base-content/50 sm:mr-auto">Zakres</span>
      <div class="flex flex-wrap justify-end gap-1">
        {#each RELATIVE as r}
          <button class={rangeCls(r.id)} onclick={() => selectRange(r.id)}>{r.label}</button>
        {/each}
        {#if years.length}
          <select class="select select-sm sm:select-xs min-h-0 h-8 sm:h-6 w-[5.25rem] sm:w-[4.75rem] px-2 {effectiveRange.startsWith('year:') ? 'bg-primary! text-primary-content! border-primary!' : 'select-ghost text-base-content/70'}"
                  onchange={(e) => e.currentTarget.value && selectRange(`year:${e.currentTarget.value}`)}>
            <option value="" selected={!effectiveRange.startsWith('year:')}>Rok</option>
            {#each years as y}
              <option value={y} selected={effectiveRange === `year:${y}`}>{y}</option>
            {/each}
          </select>
        {/if}
        <button class={`${rangeCls("all")} btn-square`} onclick={() => selectRange("all")} aria-label="Cały zakres" title="Cały zakres">
          <MoveHorizontal size={16} />
        </button>
      </div>
    </div>
    <div class="flex flex-col gap-1 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-xs text-base-content/50 sm:mr-auto">Rozdzielczość</span>
      <div class="flex flex-wrap justify-end gap-1">
        {#each RESOLUTIONS as r}
          <button class={resCls(r.id)} onclick={() => selectResolution(r.id)}>{r.label}</button>
        {/each}
      </div>
    </div>
  {/if}
  {#key chartKey}
    <PortfolioChart snapshots={view} />
  {/key}
</div>
