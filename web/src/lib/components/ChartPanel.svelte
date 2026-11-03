<script>
  import { tick } from "svelte";
  import PortfolioChart from "./PortfolioChart.svelte";
  import {
    RELATIVE, RESOLUTIONS, availableYears,
    loadRange, saveRange, loadResolution, saveResolution,
    filterSnapshots, resample,
  } from "../chartRange.js";
  import ChevronDown from "@lucide/svelte/icons/chevron-down";

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
  let headerEl = $state(null);
  let scrollerEl = $state(null);
  let rangeGroupEl = $state(null);
  let rangeThumb = $state(null);
  let yearButtonEl = $state(null);
  let yearMenuEl = $state(null);
  let yearMenuOpen = $state(false);
  let yearMenuLeft = $state(0);
  let yearMenuTop = $state(0);

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
  // The segments scroll horizontally on narrow screens, which would clip the
  // year list — so the list lives outside the scroller, positioned under its button.
  function toggleYearMenu() {
    if (!yearMenuOpen && yearButtonEl && headerEl) {
      const header = headerEl.getBoundingClientRect();
      const button = yearButtonEl.getBoundingClientRect();
      yearMenuLeft = Math.max(0, Math.min(button.left - header.left, header.width - 96));
      yearMenuTop = button.bottom - header.top + 4;
    }
    yearMenuOpen = !yearMenuOpen;
  }

  const segmentButtonBase = "relative z-10 min-h-9 shrink-0 cursor-pointer rounded-xl px-2.5 text-xs font-semibold transition-colors";
  const rangeCls = (id) =>
    `${segmentButtonBase} ${rangeSegmentId === id ? "text-primary-content" : "text-muted hover:bg-base-content/10 hover:text-base-content"}`;
  const rangeSegmentId = $derived(effectiveRange.startsWith("year:") ? "year" : effectiveRange);

  function thumbStyle(thumb) {
    if (!thumb) return "opacity: 0;";
    return `opacity: 1; width: ${thumb.width}px; height: ${thumb.height}px; transform: translate3d(${thumb.left}px, ${thumb.top}px, 0);`;
  }

  async function updateThumb() {
    await tick();
    requestAnimationFrame(() => {
      const active = rangeGroupEl?.querySelector(`[data-segment="${rangeSegmentId}"]`);
      if (!rangeGroupEl || !active) {
        rangeThumb = null;
        return;
      }
      const group = rangeGroupEl.getBoundingClientRect();
      const item = active.getBoundingClientRect();
      rangeThumb = { left: item.left - group.left, top: item.top - group.top, width: item.width, height: item.height };
      // Keep the selected segment visible when the row scrolls (only the row —
      // scrollIntoView would also scroll the page to the chart).
      if (scrollerEl) {
        const scroller = scrollerEl.getBoundingClientRect();
        if (item.right > scroller.right) scrollerEl.scrollLeft += item.right - scroller.right;
        else if (item.left < scroller.left) scrollerEl.scrollLeft -= scroller.left - item.left;
      }
    });
  }

  // Re-measure when the selection changes or the segment row (re)appears —
  // it only renders once snapshots have loaded.
  $effect(() => {
    rangeSegmentId;
    if (!rangeGroupEl) return;
    updateThumb();
  });

  $effect(() => {
    const group = rangeGroupEl;
    window.addEventListener("resize", updateThumb);
    const observer = group && typeof ResizeObserver !== "undefined" ? new ResizeObserver(() => updateThumb()) : null;
    observer?.observe(group);
    return () => {
      window.removeEventListener("resize", updateThumb);
      observer?.disconnect();
    };
  });

  $effect(() => {
    if (!yearMenuOpen) return;
    const closeOnOutsideClick = (event) => {
      if (!yearMenuEl?.contains(event.target) && !yearButtonEl?.contains(event.target)) yearMenuOpen = false;
    };
    const closeOnScroll = () => (yearMenuOpen = false);
    document.addEventListener("pointerdown", closeOnOutsideClick);
    scrollerEl?.addEventListener("scroll", closeOnScroll);
    return () => {
      document.removeEventListener("pointerdown", closeOnOutsideClick);
      scrollerEl?.removeEventListener("scroll", closeOnScroll);
    };
  });
</script>

<div class="rounded-2xl border border-base-300 bg-base-100 p-3 sm:p-4" bind:this={panelEl}>
  {#if snapshots.length}
    <div class="relative mb-2 flex flex-wrap items-center justify-between gap-2" bind:this={headerEl}>
      <div class="no-scrollbar min-w-0 max-w-full overflow-x-auto" bind:this={scrollerEl}>
        <div class="relative flex w-max gap-0.5 rounded-xl bg-base-200 p-0.5" bind:this={rangeGroupEl}>
          <span class="pointer-events-none absolute left-0 top-0 z-0 transition-[transform,width,height,opacity] duration-300 ease-[cubic-bezier(.2,.8,.2,1.15)]" style={thumbStyle(rangeThumb)}>
            {#key rangeSegmentId}
              <span class="block h-full w-full rounded-xl bg-primary animate-[segment-recede_300ms_ease-out]"></span>
            {/key}
          </span>
          {#each RELATIVE as r}
            <button type="button" class={rangeCls(r.id)} data-segment={r.id} onclick={() => selectRange(r.id)}>{r.label}</button>
          {/each}
          {#if years.length}
            <button type="button" class="{rangeCls('year')} inline-flex items-center gap-0.5" data-segment="year"
                    bind:this={yearButtonEl}
                    aria-haspopup="listbox" aria-expanded={yearMenuOpen}
                    onclick={toggleYearMenu}
                    onkeydown={(event) => event.key === "Escape" && (yearMenuOpen = false)}>
              {effectiveRange.startsWith("year:") ? effectiveRange.slice(5) : "Rok"}
              <ChevronDown size={13} class="transition-transform {yearMenuOpen ? 'rotate-180' : ''}" />
            </button>
          {/if}
          <button type="button" class={rangeCls("all")} data-segment="all" onclick={() => selectRange("all")}>Całość</button>
        </div>
      </div>
      <select class="select select-sm w-auto shrink-0 rounded-xl border-base-300 text-xs font-semibold"
              aria-label="Rozdzielczość" value={resolution}
              onchange={(e) => selectResolution(e.currentTarget.value)}>
        {#each RESOLUTIONS as r}
          <option value={r.id}>{r.label}</option>
        {/each}
      </select>
      {#if yearMenuOpen}
        <ul class="absolute z-30 w-24 overflow-hidden rounded-xl border border-base-300 bg-base-100 p-1 text-base-content shadow-xl"
            style={`left: ${yearMenuLeft}px; top: ${yearMenuTop}px`}
            bind:this={yearMenuEl}
            role="listbox" aria-label="Wybierz rok"
            onkeydown={(event) => event.key === "Escape" && (yearMenuOpen = false)}>
          {#each years as y}
            <li>
              <button type="button"
                      class="w-full cursor-pointer rounded-lg px-2 py-1.5 text-left text-xs font-semibold hover:bg-base-200 {effectiveRange === `year:${y}` ? 'bg-primary text-primary-content hover:bg-primary' : ''}"
                      role="option" aria-selected={effectiveRange === `year:${y}`}
                      onclick={() => selectYear(y)}>{y}</button>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  {/if}
  <PortfolioChart snapshots={view} />
</div>
