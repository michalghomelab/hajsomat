<script>
  import { onMount, onDestroy } from "svelte";
  import { api } from "../api.js";

  // `field` selects which time from /api/schedule to count down to.
  let { field, label, title } = $props();
  let nextAt = $state(null);
  let now = $state(Date.now());
  let timer;
  let rolling = false;

  async function loadSchedule() {
    if (rolling) return;
    rolling = true;
    try {
      const s = await api.schedule();
      nextAt = s[field] ? new Date(s[field]).getTime() : null;
    } catch {
      nextAt = null;
    } finally {
      rolling = false;
    }
  }

  let remaining = $derived(nextAt ? Math.max(0, nextAt - now) : null);
  let text = $derived.by(() => {
    if (remaining == null) return null;
    const t = Math.floor(remaining / 1000);
    const pad = (n) => String(n).padStart(2, "0");
    const days = Math.floor(t / 86400);
    const hms = `${pad(Math.floor((t % 86400) / 3600))}:${pad(Math.floor((t % 3600) / 60))}:${pad(t % 60)}`;
    return days > 0 ? `${days}d ${hms}` : hms;
  });

  onMount(() => {
    loadSchedule();
    let ticks = 0;
    timer = setInterval(() => {
      now = Date.now();
      ticks += 1;
      // Refetch on rollover, and periodically so interval changes are reflected.
      if ((nextAt && now >= nextAt) || ticks % 60 === 0) loadSchedule();
    }, 1000);
  });
  onDestroy(() => clearInterval(timer));
</script>

{#if text}
  <span class="text-xs text-base-content/60 tabular-nums" {title}>⏱ {label} za {text}</span>
{/if}
