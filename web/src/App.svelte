<script>
  import PortfolioList from "./lib/components/PortfolioList.svelte";
  import PortfolioView from "./lib/components/PortfolioView.svelte";
  import ThemeSwitch from "./lib/components/ThemeSwitch.svelte";
  import { unlockAudio } from "./lib/audioFeedback.js";

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

  $effect(() => {
    const unlock = () => void unlockAudio();
    window.addEventListener("pointerdown", unlock, { once: true, passive: true });
    window.addEventListener("touchend", unlock, { once: true, passive: true });
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("touchend", unlock);
    };
  });
</script>

<div class="min-h-screen">
  <div class="mx-auto hidden max-w-4xl justify-end px-6 pt-[max(0.75rem,env(safe-area-inset-top))] sm:flex">
    <ThemeSwitch />
  </div>

  {#if selectedId}
    {#key selectedId}
      <PortfolioView id={selectedId} onBack={back} />
    {/key}
  {:else}
    <PortfolioList onSelect={open} />
  {/if}

  <div class="mx-auto flex max-w-4xl justify-end px-6 pb-4 sm:hidden">
    <ThemeSwitch />
  </div>

  <footer class="px-6 pb-[calc(env(safe-area-inset-bottom)+0.5rem)] text-center text-[10px] leading-none text-base-content/30 sm:-mt-2">
    {buildId}
  </footer>
</div>
