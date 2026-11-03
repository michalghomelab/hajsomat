<script>
  import ApexCharts from "apexcharts/area";
  import "apexcharts/column";
  import "apexcharts/features/legend";
  import { untrack } from "svelte";
  import { attachWheelZoom } from "../chartZoom.js";
  import { buildChartOptions, buildSeries, buildXaxis, buildTooltip, seriesColors, chartPalette } from "../chartOptions.js";

  let { snapshots } = $props();
  let el = $state(null);
  let width = $state(0);
  let chart = null;
  let detachZoom = null;

  // Narrow containers (phones) get a compact layout: no axis titles, short dates.
  let compact = $derived(width > 0 && width < 640);

  function isDark() {
    const theme = document.documentElement.dataset.theme;
    if (theme === "dark") return true;
    if (theme === "light") return false;
    return window.matchMedia?.("(prefers-color-scheme: dark)").matches ?? false;
  }

  const fullOptions = (snaps, isCompact) =>
    buildChartOptions(snaps, { palette: chartPalette(), dark: isDark(), compact: isCompact });

  function rewireZoom() {
    detachZoom?.();
    detachZoom = attachWheelZoom(chart, el);
  }

  // Build the chart once when the element mounts; reused across data changes.
  $effect(() => {
    if (!el) return;
    const instance = new ApexCharts(el, untrack(() => fullOptions(snapshots ?? [], compact)));
    instance.render();
    chart = instance;
    detachZoom = attachWheelZoom(instance, el);
    return () => {
      detachZoom?.();
      detachZoom = null;
      instance.destroy();
      chart = null;
    };
  });

  // Push new data in place. updateOptions (not updateSeries) so the bar geometry
  // and x-axis range fully recompute when the point count changes — otherwise the
  // bars render shifted/with stale hit areas until a page reload.
  $effect(() => {
    const data = snapshots ?? [];
    const isCompact = compact;
    if (!chart) return;
    const palette = chartPalette();
    chart.updateOptions({
      series: buildSeries(data, palette),
      colors: seriesColors(palette, isDark()),
      xaxis: buildXaxis(data, { compact: isCompact }),
      tooltip: buildTooltip(data, palette),
    }, true, true);
    rewireZoom();
  });

  // Layout (compact) and theme changes need the full option set.
  $effect(() => {
    const isCompact = compact;
    if (!chart) return;
    untrack(() => chart.updateOptions(fullOptions(snapshots ?? [], isCompact), false, true));
    rewireZoom();
  });

  $effect(() => {
    const refreshTheme = () => {
      if (!chart) return;
      chart.updateOptions(fullOptions(snapshots ?? [], compact), false, true);
      rewireZoom();
    };
    const media = window.matchMedia?.("(prefers-color-scheme: dark)");
    window.addEventListener("hajsomat:themechange", refreshTheme);
    media?.addEventListener("change", refreshTheme);
    return () => {
      window.removeEventListener("hajsomat:themechange", refreshTheme);
      media?.removeEventListener("change", refreshTheme);
    };
  });
</script>

{#if snapshots?.length}
  <div bind:clientWidth={width}><div bind:this={el}></div></div>
{:else}
  <p class="px-1 py-2 text-sm text-muted">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
