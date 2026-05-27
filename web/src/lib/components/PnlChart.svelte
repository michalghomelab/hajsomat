<script>
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  let { snapshots } = $props();
  let canvas;
  let chart;

  $effect(() => {
    if (!canvas || !snapshots?.length) return;
    chart?.destroy();
    chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: snapshots.map((s) => s.date),
        datasets: [{
          label: "Wartość portfela (PLN)",
          data: snapshots.map((s) => Number(s.total_value_pln)),
          borderColor: "#2563eb",
          tension: 0.2,
        }],
      },
      options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: true } } },
    });
    return () => chart?.destroy();
  });
</script>

{#if snapshots?.length}
  <div class="border rounded p-4" style="height: 320px"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-gray-500 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
