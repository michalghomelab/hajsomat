<script>
  import { INTERVALS, refreshEvery } from "../refreshInterval.svelte.js";
  let selected = $state(refreshEvery.value);
  $effect(() => {
    refreshEvery.set(selected);
  });
</script>

<label class="flex items-center gap-1 text-xs text-base-content/60 whitespace-nowrap">
  Auto-odświeżanie
  <select class="select select-bordered select-xs" bind:value={selected}>
    {#each INTERVALS as i}
      <option value={i.ms}>{i.label}</option>
    {/each}
  </select>
</label>
