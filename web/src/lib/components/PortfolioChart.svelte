<script>
  import ApexCharts from "apexcharts";
  import { untrack } from "svelte";
  import { attachWheelZoom } from "../chartZoom.js";
  let { snapshots } = $props();
  let el = $state(null);
  let chart = null;
  let detachZoom = null;
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;

  // Split each day's value change into the deposit part (Δ cost basis = money
  // added that day) and the market part (the rest = price/FX moves).
  function dayChanges(snaps) {
    const out = [];
    for (let i = 1; i < snaps.length; i++) {
      const dValue = Number(snaps[i].total_value_pln) - Number(snaps[i - 1].total_value_pln);
      const dCost = Number(snaps[i].total_cost_pln) - Number(snaps[i - 1].total_cost_pln);
      out.push({ date: snaps[i].date, deposit: dCost, market: dValue - dCost });
    }
    return out;
  }

  // Cumulative figures (Wartość/Wpłaty/Zysk) share the left axis; the daily
  // change bars are ~2 orders of magnitude smaller, so they live on the right
  // axis. The legend toggles any series, so the chart stays readable even with
  // both scales present.
  const series = (snaps) => {
    const d = dayChanges(snaps);
    // All series use the same { x, y } object format — mixing object and tuple
    // formats in one chart makes ApexCharts misparse the y-values of some series.
    return [
      { name: "Wartość", type: "area", data: snaps.map((s) => ({ x: s.date, y: Number(s.total_value_pln) })) },
      { name: "Wpłaty", type: "area", data: snaps.map((s) => ({ x: s.date, y: Number(s.total_cost_pln) })) },
      { name: "Zysk", type: "area", data: snaps.map((s) => ({ x: s.date, y: Number(s.pnl_pln) })) },
      {
        name: "Zmiana rynkowa", type: "column",
        data: d.map((x) => ({ x: x.date, y: Number(x.market.toFixed(2)),
          fillColor: x.market >= 0 ? "#16a34a" : "#dc2626" })),
      },
      { name: "Wpłata (dzienna)", type: "column", data: d.map((x) => ({ x: x.date, y: Number(x.deposit.toFixed(2)) })) },
    ];
  };

  const money = (v) => v.toLocaleString("pl-PL", { style: "currency", currency: "PLN" });
  const plnAxis = (v) => Math.round(v).toLocaleString("pl-PL");

  // Wartość (0) and Zysk (2) append the % change vs the previous visible point,
  // coloured green/red; the other series just show the money value.
  const tooltipY = (v, { seriesIndex, dataPointIndex, series: data }) => {
    if (v == null) return "—";
    if (seriesIndex === 0 || seriesIndex === 2) {
      const prev = data[seriesIndex]?.[dataPointIndex - 1];
      if (dataPointIndex > 0 && prev != null && prev !== 0) {
        const pct = ((v - prev) / Math.abs(prev)) * 100;
        const color = pct >= 0 ? "#16a34a" : "#dc2626";
        return `${money(v)} <span style="color:${color}">(${pct >= 0 ? "+" : "−"}${Math.abs(pct).toFixed(2)}%)</span>`;
      }
    }
    return money(v);
  };

  const options = (snaps) => ({
    chart: {
      type: "line", height: 380, stacked: false,
      fontFamily: "inherit", background: "transparent",
      toolbar: { show: false }, zoom: { enabled: false }, animations: { easing: "easeinout" },
    },
    theme: { mode: dark ? "dark" : "light" },
    series: series(snaps),
    colors: ["#3b82f6", "#f59e0b", "#16a34a", "#16a34a", "#6366f1"],
    stroke: { curve: "smooth", width: [2.5, 2, 2, 0, 0], dashArray: [0, 5, 0, 0, 0] },
    fill: {
      type: ["gradient", "solid", "solid", "solid", "solid"],
      gradient: { shadeIntensity: 1, opacityFrom: 0.45, opacityTo: 0.05 },
      opacity: [1, 0, 0, 1, 1],
    },
    plotOptions: { bar: { columnWidth: "70%", borderRadius: 2 } },
    dataLabels: { enabled: false },
    legend: { position: "top" },
    xaxis: { type: "datetime" },
    // Two axes, each binding all of its series by name: cumulative figures share
    // the left axis, the daily bars share the right one (~100x smaller scale).
    yaxis: [
      { seriesName: ["Wartość", "Wpłaty", "Zysk"], labels: { formatter: plnAxis }, title: { text: "PLN (skumulowane)" } },
      { seriesName: ["Zmiana rynkowa", "Wpłata (dzienna)"], opposite: true, labels: { formatter: plnAxis },
        title: { text: "zł / dzień" } },
    ],
    grid: { borderColor: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)", strokeDashArray: 4 },
    tooltip: { shared: true, intersect: false, x: { format: "dd.MM.yyyy" }, y: { formatter: tooltipY } },
  });

  // Build the chart once when the element mounts; reused across data changes.
  $effect(() => {
    if (!el) return;
    const instance = new ApexCharts(el, untrack(() => options(snapshots ?? [])));
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
    if (!chart) return;
    chart.updateOptions({ series: series(data) }, false, true);
    detachZoom?.();
    detachZoom = attachWheelZoom(chart, el);
  });
</script>

{#if snapshots?.length}
  <div class="card bg-base-100 shadow-sm p-2"><div bind:this={el}></div></div>
{:else}
  <p class="text-base-content/60 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
