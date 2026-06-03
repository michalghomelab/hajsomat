<script>
  import PortfolioChart from "./PortfolioChart.svelte";
  import {
    RELATIVE, RESOLUTIONS, availableYears,
    loadRange, saveRange, loadResolution, saveResolution,
    filterSnapshots, resample,
  } from "../chartRange.js";
  import MoveHorizontal from "@lucide/svelte/icons/move-horizontal";

  let { snapshots = [], onRangeChange = () => {} } = $props();
  let range = $state(loadRange());
  let resolution = $state(loadResolution());

  let years = $derived(availableYears(snapshots));
  // Fall back to lifetime if the persisted year isn't present in the data.
  let effectiveRange = $derived(
    range.startsWith("year:") && !years.includes(range.slice(5)) ? "all" : range
  );
  let view = $derived(resample(filterSnapshots(snapshots, effectiveRange), resolution));
  let panelEl = $state(null);

  function keepScrollPosition(fn) {
    const beforeTop = panelEl?.getBoundingClientRect().top;
    fn();
    requestAnimationFrame(() => {
      if (beforeTop == null || !panelEl) return;
      const afterTop = panelEl.getBoundingClientRect().top;
      window.scrollBy(0, afterTop - beforeTop);
    });
  }

  function selectRange(id) {
    keepScrollPosition(() => {
      range = id;
      saveRange(id);
      onRangeChange(id);
    });
  }
  function selectResolution(id) {
    keepScrollPosition(() => {
      resolution = id;
      saveResolution(id);
    });
  }
  const segmentButtonBase = "min-h-9 sm:min-h-8 rounded-lg px-3 sm:px-2.5 text-sm sm:text-xs font-medium transition-all";
  const rangeCls = (id) =>
    `${segmentButtonBase} ${effectiveRange === id ? "bg-primary text-primary-content shadow-sm" : "text-base-content/65 hover:bg-base-100 hover:text-base-content"}`;
  const resCls = (id) =>
    `${segmentButtonBase} ${resolution === id ? "bg-primary text-primary-content shadow-sm" : "text-base-content/65 hover:bg-base-100 hover:text-base-content"}`;
  const resShortLabel = (id) => ({ day: "D", week: "W", month: "M", quarter: "Q", year: "Y" })[id] ?? id;
</script>

<div class="space-y-3" bind:this={panelEl}>
  {#if snapshots.length}
    <div class="flex flex-col gap-1.5 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45 sm:mr-auto">Zakres</span>
      <div class="flex flex-wrap justify-end gap-1 rounded-xl border border-base-300/70 bg-base-200/70 p-1 shadow-inner">
        {#each RELATIVE as r}
          <button class={rangeCls(r.id)} onclick={() => selectRange(r.id)}>{r.label}</button>
        {/each}
        {#if years.length}
          <select class="select select-sm min-h-9 sm:min-h-8 h-9 sm:h-8 w-[5.25rem] rounded-lg border-0 px-2 text-sm sm:text-xs font-medium {effectiveRange.startsWith('year:') ? 'bg-primary! text-primary-content! shadow-sm' : 'bg-transparent text-base-content/65 hover:bg-base-100'}"
                  onchange={(e) => e.currentTarget.value && selectRange(`year:${e.currentTarget.value}`)}>
            <option value="" selected={!effectiveRange.startsWith('year:')}>Rok</option>
            {#each years as y}
              <option value={y} selected={effectiveRange === `year:${y}`}>{y}</option>
            {/each}
          </select>
        {/if}
        <button class={`${rangeCls("all")} aspect-square px-2.5`} onclick={() => selectRange("all")} aria-label="Cały zakres" title="Cały zakres">
          <MoveHorizontal size={16} />
        </button>
      </div>
    </div>
    <div class="flex flex-col gap-1.5 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45 sm:mr-auto">Rozdzielczość</span>
      <div class="flex flex-wrap justify-end gap-1 rounded-xl border border-base-300/70 bg-base-200/70 p-1 shadow-inner">
        {#each RESOLUTIONS as r}
          <button class={`${resCls(r.id)} min-w-9 sm:min-w-8 px-2`} onclick={() => selectResolution(r.id)} title={r.label}>{resShortLabel(r.id)}</button>
        {/each}
      </div>
    </div>
  {/if}
  <PortfolioChart snapshots={view} />
</div>
