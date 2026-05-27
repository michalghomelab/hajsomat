<script>
  import ApexCharts from "apexcharts";
  import { untrack } from "svelte";
  import { attachWheelZoom } from "../chartZoom.js";
  let { snapshots } = $props();
  let el = $state(null);
  let chart = null;
  let detachZoom = null;
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;

  // Split each day's value change into the deposit part (change in cost basis =
  // money added that day) and the market part (the rest = price/FX moves).
  function dayChanges(snaps) {
    const out = [];
    for (let i = 1; i < snaps.length; i++) {
      const dValue = Number(snaps[i].total_value_pln) - Number(snaps[i - 1].total_value_pln);
      const dCost = Number(snaps[i].total_cost_pln) - Number(snaps[i - 1].total_cost_pln);
      out.push({ date: snaps[i].date, deposit: dCost, market: dValue - dCost });
    }
    return out;
  }

  const series = (snaps) => {
    const d = dayChanges(snaps);
    return [
      {
        name: "Zmiana rynkowa",
        data: d.map((x) => ({
          x: x.date, y: Number(x.market.toFixed(2)),
          fillColor: x.market >= 0 ? "#16a34a" : "#dc2626",
        })),
      },
      { name: "Wpłata", data: d.map((x) => ({ x: x.date, y: Number(x.deposit.toFixed(2)) })) },
    ];
  };

  // Build the chart once when the element mounts; reused across data changes.
  $effect(() => {
    if (!el) return;
    const instance = new ApexCharts(el, {
      chart: {
        type: "bar", height: 320, stacked: true, fontFamily: "inherit",
        background: "transparent", toolbar: { show: false }, zoom: { enabled: false },
      },
      theme: { mode: dark ? "dark" : "light" },
      series: untrack(() => series(snapshots ?? [])),
      colors: ["#16a34a", "#6366f1"],
      plotOptions: { bar: { columnWidth: "75%", borderRadius: 2 } },
      dataLabels: { enabled: false },
      legend: { position: "top" },
      xaxis: { type: "datetime", crosshairs: { width: 1 } },
      yaxis: { labels: { formatter: (v) => Math.round(v).toLocaleString("pl-PL") } },
      grid: { borderColor: dark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)", strokeDashArray: 4 },
      tooltip: {
        shared: true, intersect: false,
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

  // Push new data in place. updateOptions (not updateSeries) so the bar geometry
  // and x-axis range fully recompute when the point count changes — otherwise the
  // bars render shifted/with stale hit areas until a page reload. No teardown, so
  // the page still doesn't jump.
  $effect(() => {
    const data = snapshots ?? [];
    if (!chart) return;
    chart.updateOptions({ series: series(data) }, false, true);
    detachZoom?.();
    detachZoom = attachWheelZoom(chart, el);
  });
</script>

{#if (snapshots?.length ?? 0) > 1}
  <div class="card bg-base-100 shadow-sm p-2"><div bind:this={el}></div></div>
{:else}
  <p class="text-base-content/60 text-sm">Zmiany dzienne pojawią się po co najmniej dwóch dziennych snapshotach.</p>
{/if}
