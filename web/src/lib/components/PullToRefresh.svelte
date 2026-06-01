<script>
  import RefreshCw from "@lucide/svelte/icons/refresh-cw";

  let { onRefresh, disabled = false, children } = $props();
  let host = $state(null);
  let distance = $state(0);
  let pulling = $state(false);
  let refreshing = $state(false);
  let tracking = false;
  let startY = 0;

  const THRESHOLD = 76;
  const MAX_DISTANCE = 108;

  function coarsePointer() {
    return window.matchMedia?.("(pointer: coarse)").matches;
  }

  function canStart(event) {
    return !disabled && !refreshing && coarsePointer() && window.scrollY <= 0 && event.touches.length === 1;
  }

  $effect(() => {
    if (!host) return;

    const onTouchStart = (event) => {
      if (!canStart(event)) return;
      tracking = true;
      pulling = false;
      distance = 0;
      startY = event.touches[0].clientY;
    };

    const onTouchMove = (event) => {
      if (!tracking) return;
      const delta = event.touches[0].clientY - startY;
      if (delta <= 0 || window.scrollY > 0) {
        tracking = false;
        pulling = false;
        distance = 0;
        return;
      }

      event.preventDefault();
      pulling = true;
      distance = Math.min(MAX_DISTANCE, delta * 0.55);
    };

    const onTouchEnd = async () => {
      if (!tracking) return;
      const shouldRefresh = distance >= THRESHOLD;
      tracking = false;

      if (!shouldRefresh || !onRefresh) {
        pulling = false;
        distance = 0;
        return;
      }

      refreshing = true;
      distance = 58;
      try {
        await onRefresh();
      } finally {
        refreshing = false;
        pulling = false;
        distance = 0;
      }
    };

    host.addEventListener("touchstart", onTouchStart, { passive: true });
    host.addEventListener("touchmove", onTouchMove, { passive: false });
    host.addEventListener("touchend", onTouchEnd, { passive: true });
    host.addEventListener("touchcancel", onTouchEnd, { passive: true });
    return () => {
      host.removeEventListener("touchstart", onTouchStart);
      host.removeEventListener("touchmove", onTouchMove);
      host.removeEventListener("touchend", onTouchEnd);
      host.removeEventListener("touchcancel", onTouchEnd);
    };
  });
</script>

<div bind:this={host} class="relative">
  <div class="pointer-events-none fixed left-1/2 top-[max(0.75rem,env(safe-area-inset-top))] z-50 flex h-11 w-11 items-center justify-center rounded-full border border-base-300/70 bg-base-100/90 text-primary shadow-lg backdrop-blur-md transition-opacity sm:hidden"
       class:opacity-100={pulling || refreshing}
       class:opacity-0={!pulling && !refreshing}
       style={`transform: translate(-50%, ${distance - 58}px);`}>
    <RefreshCw size={20}
               class={refreshing ? "animate-spin" : ""}
               style={refreshing ? "" : `transform: rotate(${Math.min(180, (distance / THRESHOLD) * 180)}deg);`} />
  </div>
  {@render children?.()}
</div>
