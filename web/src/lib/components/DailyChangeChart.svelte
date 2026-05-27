<script>
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;
  Chart.defaults.color = dark ? "#cbd5e1" : "#334155";
  Chart.defaults.borderColor = dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)";
  let { snapshots } = $props();
  let canvas = $state(null);

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
    if (!canvas || !d.length) return;
    const chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.map((x) => x.date),
        datasets: [
          {
            label: "Zmiana rynkowa (PLN)",
            data: d.map((x) => x.market),
            backgroundColor: d.map((x) => (x.market >= 0 ? "#16a34a" : "#dc2626")),
          },
          {
            label: "Wpłata (PLN)",
            data: d.map((x) => x.deposit),
            backgroundColor: "#2563eb",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: { x: { stacked: true }, y: { stacked: true } },
        plugins: { legend: { display: true } },
      },
    });
    return () => chart.destroy();
  });
</script>

{#if (snapshots?.length ?? 0) > 1}
  <div class="card bg-base-100 shadow-sm p-4" style="height: 320px"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-base-content/60 text-sm">Zmiany dzienne pojawią się po co najmniej dwóch dziennych snapshotach.</p>
{/if}
