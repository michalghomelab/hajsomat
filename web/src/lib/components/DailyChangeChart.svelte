<script>
  import ApexCharts from "apexcharts";
  let { snapshots } = $props();
  let el = $state(null);
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;

  // Split each day's value change into the deposit part (change in cost basis =
  // money added that day) and the market part (the rest = price/FX moves).
  function series(snaps) {
    const out = [];
    for (let i = 1; i < snaps.length; i++) {
      const dValue = Number(snaps[i].total_value_pln) - Number(snaps[i - 1].total_value_pln);
      const dCost = Number(snaps[i].total_cost_pln) - Number(snaps[i - 1].total_cost_pln);
      out.push({ date: snaps[i].date, deposit: dCost, market: dValue - dCost });
    }
    return out;
  }

  $effect(() => {
    const d = series(snapshots ?? []);
    if (!el || !d.length) return;
    const chart = new ApexCharts(el, {
      chart: {
        type: "bar", height: 320, stacked: true, fontFamily: "inherit",
        background: "transparent", toolbar: { show: false },
      },
      theme: { mode: dark ? "dark" : "light" },
      series: [
        {
          name: "Zmiana rynkowa",
          data: d.map((x) => ({
            x: x.date, y: Number(x.market.toFixed(2)),
            fillColor: x.market >= 0 ? "#16a34a" : "#dc2626",
          })),
        },
        { name: "Wpłata", data: d.map((x) => ({ x: x.date, y: Number(x.deposit.toFixed(2)) })) },
      ],
      colors: ["#16a34a", "#6366f1"],
      plotOptions: { bar: { columnWidth: "75%", borderRadius: 2 } },
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
    chart.render();
    return () => chart.destroy();
  });
</script>

{#if (snapshots?.length ?? 0) > 1}
  <div class="card bg-base-100 shadow-sm p-2"><div bind:this={el}></div></div>
{:else}
  <p class="text-base-content/60 text-sm">Zmiany dzienne pojawią się po co najmniej dwóch dziennych snapshotach.</p>
{/if}
