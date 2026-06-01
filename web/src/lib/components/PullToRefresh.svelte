<script>
  import RefreshCw from "@lucide/svelte/icons/refresh-cw";

  let { onRefresh, disabled = false, children } = $props();
  let host = $state(null);
  let distance = $state(0);
  let pulling = $state(false);
  let refreshing = $state(false);
  let armed = $state(false);
  let tracking = false;
  let startY = 0;
  let audioContext = null;

  const THRESHOLD = 94;
  const MAX_DISTANCE = 122;
  const RESISTANCE = 0.42;

  function coarsePointer() {
    return window.matchMedia?.("(pointer: coarse)").matches;
  }

  function canStart(event) {
    return !disabled && !refreshing && coarsePointer() && window.scrollY <= 0 && event.touches.length === 1;
  }

  function vibrate(pattern) {
    navigator.vibrate?.(pattern);
  }

  function clickSound(frequency = 1200) {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;

    audioContext ||= new AudioCtx();
    const ctx = audioContext;
    ctx.resume?.();

    const now = ctx.currentTime;
    const oscillator = ctx.createOscillator();
    const gain = ctx.createGain();
    oscillator.type = "square";
    oscillator.frequency.setValueAtTime(frequency, now);
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(0.035, now + 0.004);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.045);
    oscillator.connect(gain);
    gain.connect(ctx.destination);
    oscillator.start(now);
    oscillator.stop(now + 0.05);
  }

  $effect(() => {
    if (!host) return;

    const onTouchStart = (event) => {
      if (!canStart(event)) return;
      tracking = true;
      pulling = false;
      armed = false;
      distance = 0;
      startY = event.touches[0].clientY;
    };

    const onTouchMove = (event) => {
      if (!tracking) return;
      const delta = event.touches[0].clientY - startY;
      if (delta <= 0 || window.scrollY > 0) {
        tracking = false;
        pulling = false;
        armed = false;
        distance = 0;
        return;
      }

      event.preventDefault();
      pulling = true;
      distance = Math.min(MAX_DISTANCE, delta * RESISTANCE);
      if (!armed && distance >= THRESHOLD) {
        armed = true;
        vibrate(20);
        clickSound(1150);
      } else if (armed && distance < THRESHOLD - 12) {
        armed = false;
      }
    };

    const onTouchEnd = async () => {
      if (!tracking) return;
      const shouldRefresh = distance >= THRESHOLD;
      tracking = false;

      if (!shouldRefresh || !onRefresh) {
        pulling = false;
        armed = false;
        distance = 0;
        return;
      }

      refreshing = true;
      vibrate([18, 25, 28]);
      clickSound(1500);
      distance = 72;
      try {
        await onRefresh();
      } finally {
        refreshing = false;
        pulling = false;
        armed = false;
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
  <div class={`pointer-events-none fixed left-1/2 top-[max(0.75rem,env(safe-area-inset-top))] z-50 flex h-14 w-14 items-center justify-center rounded-full border-2 border-primary/45 bg-base-100 text-primary shadow-[0_16px_48px_rgba(0,0,0,0.28)] ring-4 backdrop-blur-md transition-opacity sm:hidden ${armed || refreshing ? "ring-primary/25" : "ring-primary/10"}`}
       class:opacity-100={pulling || refreshing}
       class:opacity-0={!pulling && !refreshing}
       style={`transform: translate(-50%, ${distance - 72}px) scale(${armed || refreshing ? 1.08 : 1});`}>
    <RefreshCw size={24}
               class={refreshing ? "animate-spin" : ""}
               style={refreshing ? "" : `transform: rotate(${Math.min(180, (distance / THRESHOLD) * 180)}deg);`} />
  </div>
  {@render children?.()}
</div>
