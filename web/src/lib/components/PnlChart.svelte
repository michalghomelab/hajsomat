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
  ];

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
      colors: ["#3b82f6", "#f59e0b"],
      stroke: { curve: "smooth", width: [2.5, 2], dashArray: [0, 5] },
      fill: {
        type: ["gradient", "solid"],
        gradient: { shadeIntensity: 1, opacityFrom: 0.45, opacityTo: 0.05 },
        opacity: [1, 0],
      },
      dataLabels: { enabled: false },
      legend: { position: "top" },
      xaxis: { type: "datetime" },
      yaxis: { labels: { formatter: (v) => Math.round(v).toLocaleString("pl-PL") } },
      grid: { borderColor: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)", strokeDashArray: 4 },
      tooltip: {
        x: { format: "dd.MM.yyyy" },
        y: { formatter: (v) => v.toLocaleString("pl-PL", { style: "currency", currency: "PLN" }) },
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
