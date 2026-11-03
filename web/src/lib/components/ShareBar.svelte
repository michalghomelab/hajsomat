<script>
  // Thin gold bar showing a 0..1 share of the whole; nothing when unknown.
  let { share = null } = $props();
</script>

{#if share !== null && share !== undefined && !Number.isNaN(share)}
  <div class="mt-2 h-1 overflow-hidden rounded-full bg-base-300" aria-hidden="true">
    <div class="h-full rounded-full bg-accent" style={`width: ${Math.min(100, Math.max(0, share * 100))}%`}></div>
  </div>
{/if}
