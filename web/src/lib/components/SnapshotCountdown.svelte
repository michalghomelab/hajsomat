<script>
  import { onMount, onDestroy } from "svelte";
  import { api } from "../api.js";

  let nextAt = $state(null);
  let now = $state(Date.now());
  let timer;
  let rolling = false;

  async function loadSchedule() {
    if (rolling) return;
    rolling = true;
    try {
      const s = await api.schedule();
      nextAt = new Date(s.next_snapshot_at).getTime();
    } catch {
      nextAt = null;
    } finally {
      rolling = false;
    }
  }

  let remaining = $derived(nextAt ? Math.max(0, nextAt - now) : null);
  let label = $derived.by(() => {
    if (remaining == null) return null;
    const t = Math.floor(remaining / 1000);
    const pad = (n) => String(n).padStart(2, "0");
    const days = Math.floor(t / 86400);
    const hms = `${pad(Math.floor((t % 86400) / 3600))}:${pad(Math.floor((t % 3600) / 60))}:${pad(t % 60)}`;
    return days > 0 ? `${days}d ${hms}` : hms;
  });

  onMount(() => {
    loadSchedule();
    timer = setInterval(() => {
      now = Date.now();
      // Rolled past the scheduled time — fetch the next occurrence.
      if (nextAt && now >= nextAt) loadSchedule();
    }, 1000);
  });
  onDestroy(() => clearInterval(timer));
</script>

{#if label}
  <span class="text-xs text-base-content/60 tabular-nums" title="Następny dzienny snapshot">
    ⏱ następny snapshot za {label}
  </span>
{/if}
