<script>
  import PortfolioList from "./lib/components/PortfolioList.svelte";
  import PortfolioView from "./lib/components/PortfolioView.svelte";
  let selectedId = $state(null);
</script>

{#if selectedId}
  <PortfolioView id={selectedId} onBack={() => (selectedId = null)} />
{:else}
  <PortfolioList onSelect={(id) => (selectedId = id)} />
{/if}
