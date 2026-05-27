<script>
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  const dark = window.matchMedia?.("(prefers-color-scheme: dark)").matches;
  Chart.defaults.color = dark ? "#cbd5e1" : "#334155";
  Chart.defaults.borderColor = dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)";
  let { snapshots } = $props();
  let canvas = $state(null);

  $effect(() => {
    if (!canvas || !snapshots?.length) return;
    const chart = new Chart(canvas, {
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
    return () => chart.destroy();
  });
</script>

{#if snapshots?.length}
  <div class="card bg-base-100 shadow-sm p-4" style="height: 320px"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-base-content/60 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
