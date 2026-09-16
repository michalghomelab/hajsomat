<script>
  import { tick } from "svelte";
  import PortfolioChart from "./PortfolioChart.svelte";
  import {
    RELATIVE, RESOLUTIONS, availableYears,
    loadRange, saveRange, loadResolution, saveResolution,
    filterSnapshots, resample,
  } from "../chartRange.js";
  import ChevronDown from "@lucide/svelte/icons/chevron-down";
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
  let rangeGroupEl = $state(null);
  let resolutionGroupEl = $state(null);
  let rangeThumb = $state(null);
  let resolutionThumb = $state(null);
  let yearMenuEl = $state(null);
  let yearMenuOpen = $state(false);

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
  function selectYear(year) {
    selectRange(`year:${year}`);
    yearMenuOpen = false;
  }
  function selectResolution(id) {
    keepScrollPosition(() => {
      resolution = id;
      saveResolution(id);
    });
  }
  const segmentButtonBase = "relative z-10 min-h-9 cursor-pointer rounded-xl px-3 text-xs font-semibold transition-all";
  const rangeCls = (id) =>
    `${segmentButtonBase} ${effectiveRange === id ? "text-primary-content" : "text-base-content/60 hover:bg-base-content/10 hover:text-base-content"}`;
  const resCls = (id) =>
    `${segmentButtonBase} ${resolution === id ? "text-primary-content" : "text-base-content/60 hover:bg-base-content/10 hover:text-base-content"}`;
  const resShortLabel = (id) => ({ day: "D", week: "W", month: "M", quarter: "Q", year: "Y" })[id] ?? id;
  const rangeSegmentId = $derived(effectiveRange.startsWith("year:") ? "year" : effectiveRange);

  function thumbStyle(thumb) {
    if (!thumb) return "opacity: 0;";
    return `opacity: 1; width: ${thumb.width}px; height: ${thumb.height}px; transform: translate3d(${thumb.left}px, ${thumb.top}px, 0);`;
  }

  async function updateThumb(groupEl, segmentId, setThumb) {
    await tick();
    requestAnimationFrame(() => {
      const active = groupEl?.querySelector(`[data-segment="${segmentId}"]`);
      if (!groupEl || !active) {
        setThumb(null);
        return;
      }
      const group = groupEl.getBoundingClientRect();
      const item = active.getBoundingClientRect();
      setThumb({
        left: item.left - group.left,
        top: item.top - group.top,
        width: item.width,
        height: item.height,
      });
    });
  }

  $effect(() => {
    updateThumb(rangeGroupEl, rangeSegmentId, (next) => (rangeThumb = next));
  });

  $effect(() => {
    updateThumb(resolutionGroupEl, resolution, (next) => (resolutionThumb = next));
  });

  $effect(() => {
    const onResize = () => {
      updateThumb(rangeGroupEl, rangeSegmentId, (next) => (rangeThumb = next));
      updateThumb(resolutionGroupEl, resolution, (next) => (resolutionThumb = next));
    };
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  });

  $effect(() => {
    if (!yearMenuOpen) return;
    const closeOnOutsideClick = (event) => {
      if (!yearMenuEl?.contains(event.target)) yearMenuOpen = false;
    };
    document.addEventListener("pointerdown", closeOnOutsideClick);
    return () => document.removeEventListener("pointerdown", closeOnOutsideClick);
  });
</script>

<div class="space-y-3" bind:this={panelEl}>
  {#if snapshots.length}
    <div class="flex flex-col gap-1.5 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45 sm:mr-auto">Zakres</span>
      <div class="relative z-20 flex flex-wrap justify-end gap-1 rounded-2xl border border-base-300/70 bg-base-200/70 p-1 shadow-inner backdrop-blur-xl" bind:this={rangeGroupEl}>
        <span class="pointer-events-none absolute left-0 top-0 z-0 transition-[transform,width,height,opacity] duration-300 ease-[cubic-bezier(.2,.8,.2,1.15)]" style={thumbStyle(rangeThumb)}>
          {#key rangeSegmentId}
            <span class="block h-full w-full rounded-xl bg-primary shadow-[inset_0_1px_0_rgba(255,255,255,0.25),0_1px_2px_rgba(0,0,0,0.10)] animate-[segment-recede_300ms_ease-out]"></span>
          {/key}
        </span>
        {#each RELATIVE as r}
          <button class={rangeCls(r.id)} data-segment={r.id} onclick={() => selectRange(r.id)}>{r.label}</button>
        {/each}
        {#if years.length}
          <div class="relative z-20 w-[5.25rem]"
               data-segment="year"
               bind:this={yearMenuEl}>
            <button type="button"
                    class="flex min-h-9 w-full cursor-pointer items-center justify-between rounded-xl bg-transparent px-2 text-xs font-semibold transition-all {effectiveRange.startsWith('year:') ? 'text-primary-content' : 'text-base-content/60 hover:bg-base-content/10 hover:text-base-content'}"
                    aria-haspopup="listbox"
                    aria-expanded={yearMenuOpen}
                    onclick={() => (yearMenuOpen = !yearMenuOpen)}
                    onkeydown={(event) => event.key === "Escape" && (yearMenuOpen = false)}>
              <span>{effectiveRange.startsWith("year:") ? effectiveRange.slice(5) : "Rok"}</span>
              <ChevronDown size={14} class="transition-transform {yearMenuOpen ? 'rotate-180' : ''}" />
            </button>
            {#if yearMenuOpen}
              <ul class="absolute right-0 top-[calc(100%+0.25rem)] z-30 w-full overflow-hidden rounded-xl border border-base-300 bg-base-100 p-1 text-base-content shadow-xl"
                  role="listbox"
                  aria-label="Wybierz rok"
                  onkeydown={(event) => event.key === "Escape" && (yearMenuOpen = false)}>
                {#each years as y}
                  <li>
                    <button type="button"
                            class="w-full cursor-pointer rounded-lg px-2 py-1.5 text-left text-xs font-semibold hover:bg-base-200 {effectiveRange === `year:${y}` ? 'bg-primary text-primary-content hover:bg-primary' : ''}"
                            role="option"
                            aria-selected={effectiveRange === `year:${y}`}
                            onclick={() => selectYear(y)}>{y}</button>
                  </li>
                {/each}
              </ul>
            {/if}
          </div>
        {/if}
        <button class={`${rangeCls("all")} aspect-square px-2.5`} data-segment="all" onclick={() => selectRange("all")} aria-label="Cały zakres" title="Cały zakres">
          <MoveHorizontal size={16} />
        </button>
      </div>
    </div>
    <div class="flex flex-col gap-1.5 sm:flex-row sm:flex-wrap sm:items-center">
      <span class="text-[0.7rem] font-medium uppercase tracking-wide text-base-content/45 sm:mr-auto">Rozdzielczość</span>
      <div class="relative flex flex-wrap justify-end gap-1 rounded-2xl border border-base-300/70 bg-base-200/70 p-1 shadow-inner backdrop-blur-xl" bind:this={resolutionGroupEl}>
        <span class="pointer-events-none absolute left-0 top-0 z-0 transition-[transform,width,height,opacity] duration-300 ease-[cubic-bezier(.2,.8,.2,1.15)]" style={thumbStyle(resolutionThumb)}>
          {#key resolution}
            <span class="block h-full w-full rounded-xl bg-primary shadow-[inset_0_1px_0_rgba(255,255,255,0.25),0_1px_2px_rgba(0,0,0,0.10)] animate-[segment-recede_300ms_ease-out]"></span>
          {/key}
        </span>
        {#each RESOLUTIONS as r}
          <button class={`${resCls(r.id)} min-w-9 sm:min-w-8 px-2`} data-segment={r.id} onclick={() => selectResolution(r.id)} title={r.label}>{resShortLabel(r.id)}</button>
        {/each}
      </div>
    </div>
  {/if}
  <PortfolioChart snapshots={view} />
</div>
