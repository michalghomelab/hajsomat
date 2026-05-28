<script>
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  let selected = $state(refreshEvery.minutes);
  // Reflect the server-loaded / externally-changed value.
  $effect(() => {
    selected = refreshEvery.minutes;
  });
</script>

<label class="flex items-center gap-1 text-xs text-base-content/60 whitespace-nowrap">
  Auto-odświeżanie
  <select class="select select-bordered select-xs" bind:value={selected}
          onchange={() => refreshEvery.set(selected)}>
    {#each INTERVALS as i}
      <option value={i.minutes}>{i.label}</option>
    {/each}
  </select>
</label>
