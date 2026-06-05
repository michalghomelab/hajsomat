<script>
  import { tick } from "svelte";
  import { onMount } from "svelte";
  import Sun from "@lucide/svelte/icons/sun";
  import Moon from "@lucide/svelte/icons/moon";
  import MonitorCog from "@lucide/svelte/icons/monitor-cog";

  const KEY = "hajsomat:theme";
  const MODES = [
    { id: "light", label: "Dzień", icon: Sun },
    { id: "auto", label: "Auto", icon: MonitorCog },
    { id: "dark", label: "Noc", icon: Moon },
  ];

  let mode = $state("auto");
  let groupEl = $state(null);
  let thumb = $state(null);

  function thumbStyle(next) {
    if (!next) return "opacity: 0;";
    return `opacity: 1; width: ${next.width}px; height: ${next.height}px; transform: translate3d(${next.left}px, ${next.top}px, 0);`;
  }

  async function updateThumb(activeMode) {
    await tick();
    requestAnimationFrame(() => {
      const active = groupEl?.querySelector(`[data-segment="${activeMode}"]`);
      if (!groupEl || !active) {
        thumb = null;
        return;
      }
      const group = groupEl.getBoundingClientRect();
      const item = active.getBoundingClientRect();
      thumb = {
        left: item.left - group.left,
        top: item.top - group.top,
        width: item.width,
        height: item.height,
      };
    });
  }

  function applyTheme(next) {
    mode = next;
    try {
      localStorage.setItem(KEY, next);
    } catch {
      // selection just won't persist
    }

    if (next === "auto") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.dataset.theme = next;
    window.dispatchEvent(new CustomEvent("hajsomat:themechange", { detail: { mode: next } }));
  }

  onMount(() => {
    let saved = "auto";
    try {
      saved = localStorage.getItem(KEY) || "auto";
    } catch {
      // ignore
    }
    applyTheme(MODES.some((item) => item.id === saved) ? saved : "auto");
  });

  $effect(() => {
    updateThumb(mode);
  });

  $effect(() => {
    const onResize = () => updateThumb(mode);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  });
</script>

<div aria-label="Tryb kolorów">
  <div class="relative flex rounded-2xl border border-base-300/70 bg-base-200/70 p-1 shadow-inner backdrop-blur-xl" bind:this={groupEl}>
    <span class="pointer-events-none absolute left-0 top-0 z-0 transition-[transform,width,height,opacity] duration-300 ease-[cubic-bezier(.2,.8,.2,1.15)]" style={thumbStyle(thumb)}>
      {#key mode}
        <span class="block h-full w-full rounded-xl bg-primary shadow-[inset_0_1px_0_rgba(255,255,255,0.25),0_1px_2px_rgba(0,0,0,0.10)] animate-[segment-recede_300ms_ease-out]"></span>
      {/key}
    </span>
    {#each MODES as item}
      {@const Icon = item.icon}
      <button
        type="button"
        class={`relative z-10 flex h-9 w-9 cursor-pointer items-center justify-center rounded-xl transition-all ${mode === item.id ? "text-primary-content" : "text-base-content/60 hover:bg-base-content/10 hover:text-base-content"}`}
        data-segment={item.id}
        aria-pressed={mode === item.id}
        aria-label={item.label}
        title={item.label}
        onclick={() => applyTheme(item.id)}>
        {#if Icon}<Icon size={16} strokeWidth={2.3} />{/if}
      </button>
    {/each}
  </div>
</div>
