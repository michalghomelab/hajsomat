<script>
  import ApexCharts from "apexcharts";
  import { untrack } from "svelte";
  import { attachWheelZoom } from "../chartZoom.js";
  let { snapshots } = $props();
  let el = $state(null);
  let chart = null;
  let detachZoom = null;
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;

  const series = (snaps) => [
    { name: "Wartość", data: snaps.map((s) => [s.date, Number(s.total_value_pln)]) },
    { name: "Wpłaty (koszt)", data: snaps.map((s) => [s.date, Number(s.total_cost_pln)]) },
    { name: "Zysk", data: snaps.map((s) => [s.date, Number(s.pnl_pln)]) },
  ];

  const money = (v) => v.toLocaleString("pl-PL", { style: "currency", currency: "PLN" });
  // For Wartość (0) and Zysk (2), append the % change vs the previous datapoint
  // (within the visible range); Wpłaty/koszt (1) stays plain.
  const withDelta = (v, { series: data, seriesIndex, dataPointIndex }) => {
    const prev = data[seriesIndex]?.[dataPointIndex - 1];
    if (seriesIndex === 1 || dataPointIndex <= 0 || prev == null || prev === 0) return money(v);
    const pct = ((v - prev) / Math.abs(prev)) * 100;
    return `${money(v)} (${pct >= 0 ? "+" : "−"}${Math.abs(pct).toFixed(2)}%)`;
  };

  // Build the chart once when the element mounts; reused across data changes.
  $effect(() => {
    if (!el) return;
    const instance = new ApexCharts(el, {
      chart: {
        type: "area", height: 320, fontFamily: "inherit", background: "transparent",
        toolbar: { show: false }, zoom: { enabled: false },
        animations: { easing: "easeinout" },
      },
      theme: { mode: dark ? "dark" : "light" },
      series: untrack(() => series(snapshots ?? [])),
      colors: ["#3b82f6", "#f59e0b", "#16a34a"],
      stroke: { curve: "smooth", width: [2.5, 2, 2], dashArray: [0, 5, 0] },
      fill: {
        type: ["gradient", "solid", "solid"],
        gradient: { shadeIntensity: 1, opacityFrom: 0.45, opacityTo: 0.05 },
        opacity: [1, 0, 0],
      },
      dataLabels: { enabled: false },
      legend: { position: "top" },
      xaxis: { type: "datetime" },
      yaxis: { labels: { formatter: (v) => Math.round(v).toLocaleString("pl-PL") } },
      grid: { borderColor: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)", strokeDashArray: 4 },
      tooltip: {
        x: { format: "dd.MM.yyyy" },
        y: { formatter: withDelta },
      },
    });
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

  // Push new data in place — no teardown, so the page doesn't jump or flicker.
  $effect(() => {
    const data = snapshots ?? [];
    if (!chart) return;
    chart.updateSeries(series(data));
    detachZoom?.();
    detachZoom = attachWheelZoom(chart, el);
  });
</script>

{#if snapshots?.length}
  <div class="card bg-base-100 shadow-sm p-2"><div bind:this={el}></div></div>
{:else}
  <p class="text-base-content/60 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
