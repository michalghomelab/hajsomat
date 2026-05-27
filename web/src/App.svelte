<script>
  import PortfolioList from "./lib/components/PortfolioList.svelte";
  import PortfolioView from "./lib/components/PortfolioView.svelte";

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
