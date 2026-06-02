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

{#if selectedId}
  {#key selectedId}
    <PortfolioView id={selectedId} onBack={back} />
  {/key}
{:else}
  <PortfolioList onSelect={open} />
{/if}

<footer class="px-6 pb-28 pt-2 text-center text-[11px] text-base-content/35 sm:pb-4">
  build {buildId}
</footer>
