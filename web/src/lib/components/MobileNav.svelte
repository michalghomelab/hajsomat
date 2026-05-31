<script>
  import { fly, scale } from "svelte/transition";
  import { cubicOut } from "svelte/easing";

  let { items = [] } = $props();
  let expanded = $state(false);
  let openIndex = $state(null);

  function activate(item, index) {
    if (item.submenu?.length) {
      openIndex = openIndex === index ? null : index;
      return;
    }
    openIndex = null;
    item.onclick?.();
    expanded = false;
  }

  function select(action) {
    if (action.keepOpen) {
      action.onclick?.();
      return;
    }
    openIndex = null;
    action.onclick?.();
    expanded = false;
  }

  function toggleExpanded() {
    expanded = !expanded;
    if (!expanded) openIndex = null;
  }
</script>

<nav class="fixed bottom-[max(0.75rem,env(safe-area-inset-bottom))] left-3 z-40 sm:hidden"
     aria-label="Nawigacja mobilna">
  {#if expanded}
    <div class="fixed inset-x-3 bottom-[max(0.75rem,env(safe-area-inset-bottom))] rounded-3xl border border-white/35 bg-white/25 shadow-[0_18px_60px_rgba(0,0,0,0.18),inset_0_1px_0_rgba(255,255,255,0.55)] backdrop-blur-3xl supports-[backdrop-filter]:bg-base-100/35"
         transition:fly={{ y: 18, duration: 180, easing: cubicOut }}>
      {#if openIndex != null && items[openIndex]?.submenu?.length}
        <div class="absolute right-0 bottom-[calc(100%+0.5rem)] w-60 origin-bottom-right rounded-3xl border border-base-300/80 bg-base-100/95 p-2 shadow-[0_12px_36px_rgba(0,0,0,0.16)] backdrop-blur-md supports-[backdrop-filter]:bg-base-100/90"
             transition:scale={{ start: 0.96, duration: 140, easing: cubicOut }}>
          {#each items[openIndex].submenu as action}
            <button type="button"
                    class={`flex w-full items-center justify-between gap-3 rounded-2xl px-4 py-3 text-left text-sm text-base-content hover:bg-base-content/10 disabled:opacity-40 ${action.active ? "bg-primary/10" : ""}`}
                    class:text-primary={action.active}
                    onclick={() => select(action)}
                    disabled={action.disabled}>
              <span>{action.label}</span>
              {#if action.meta}<span class="text-xs text-base-content/50">{action.meta}</span>{/if}
            </button>
          {/each}
        </div>
      {/if}

      <div class="grid p-2" style={`grid-template-columns: repeat(${items.length}, minmax(0, 1fr));`}>
        {#each items as item, index}
          {@const Icon = item.icon}
          <button type="button"
                  class={`flex min-h-14 flex-col items-center justify-center gap-1 rounded-2xl px-1 py-2 text-xs text-base-content/70 transition-colors hover:bg-base-content/10 disabled:opacity-40 ${item.primary ? "bg-primary/15" : ""}`}
                  class:text-primary={item.primary || openIndex === index}
                  onclick={() => activate(item, index)}
                  disabled={item.disabled}
                  aria-label={item.label}
                  title={item.title ?? item.label}>
            <Icon size={21} strokeWidth={2.2} />
            <span class="max-w-full truncate">{item.label}</span>
          </button>
        {/each}
      </div>
    </div>
  {:else}
    <button type="button"
            class="flex h-16 w-16 items-center justify-center rounded-full border border-white/35 bg-white/25 shadow-[0_18px_50px_rgba(0,0,0,0.20),inset_0_1px_0_rgba(255,255,255,0.55)] backdrop-blur-3xl supports-[backdrop-filter]:bg-base-100/35"
            transition:scale={{ start: 0.9, duration: 150, easing: cubicOut }}
            onclick={toggleExpanded}
            aria-label="Pokaż menu"
            title="Menu">
      <img src="/favicon.svg" alt="" class="h-10 w-10 opacity-80 grayscale saturate-0 contrast-125 dark:invert" />
    </button>
  {/if}
</nav>
