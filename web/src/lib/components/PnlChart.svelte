<script>
  import { onMount } from "svelte";
  import { Chart, registerables } from "chart.js";
  Chart.register(...registerables);
  let { snapshots } = $props();
  let canvas;
  onMount(() => {
    if (!snapshots?.length) return;
    new Chart(canvas, {
      type: "line",
      data: {
        labels: snapshots.map((s) => s.date),
        datasets: [{ label: "Wartość portfela (PLN)", data: snapshots.map((s) => Number(s.total_value_pln)), borderColor: "#2563eb", tension: 0.2 }],
      },
      options: { responsive: true, plugins: { legend: { display: true } } },
    });
  });
</script>

{#if snapshots?.length}
  <div class="border rounded p-4"><canvas bind:this={canvas}></canvas></div>
{:else}
  <p class="text-gray-500 text-sm">Brak danych historycznych — pojawią się po pierwszym dziennym snapshotcie.</p>
{/if}
