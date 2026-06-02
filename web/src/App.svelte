<script>
  import PortfolioList from "./lib/components/PortfolioList.svelte";
  import PortfolioView from "./lib/components/PortfolioView.svelte";

  const buildId = __BUILD_ID__;

  function parseHash() {
    const m = location.hash.match(/^#\/portfolio\/(\d+)/);
    return m ? Number(m[1]) : null;
  }

  let selectedId = $state(parseHash());

  function open(id) { location.hash = `#/portfolio/${id}`; }
  function back() { location.hash = "#/"; }

  $effect(() => {
    const onHash = () => { selectedId = parseHash(); };
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  });
</script>

<div class="min-h-screen">
  {#if selectedId}
    {#key selectedId}
      <PortfolioView id={selectedId} onBack={back} />
    {/key}
  {:else}
    <PortfolioList onSelect={open} />
  {/if}

  <footer class="-mt-24 px-6 pb-[calc(env(safe-area-inset-bottom)+0.5rem)] text-center text-[10px] leading-none text-base-content/30 sm:-mt-2">
    {buildId}
  </footer>
</div>
