<script>
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  let { snapshots } = $props();
  let canvas;

  function deltas(snaps) {
    const out = [];
    for (let i = 1; i < snaps.length; i++) {
      out.push({
        date: snaps[i].date,
        change: Number(snaps[i].total_value_pln) - Number(snaps[i - 1].total_value_pln),
      });
    }
    return out;
  }

  $effect(() => {
    const d = deltas(snapshots ?? []);
    if (!canvas || !d.length) return;
    const chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: d.map((x) => x.date),
        datasets: [{
          label: "Zmiana dzienna (PLN)",
          data: d.map((x) => x.change),
          backgroundColor: d.map((x) => (x.change >= 0 ? "#16a34a" : "#dc2626")),
        }],
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: true } } },
    });
    return () => chart.destroy();
  });
</script>

{#if (snapshots?.length ?? 0) > 1}
  <div class="border rounded p-4" style="height: 320px"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-gray-500 text-sm">Zmiany dzienne pojawią się po co najmniej dwóch dziennych snapshotach.</p>
{/if}
