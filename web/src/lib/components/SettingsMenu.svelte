<script>
  import Settings from "@lucide/svelte/icons/settings";
  import RefreshIntervalSelect from "./RefreshIntervalSelect.svelte";
  import ThemeSwitch from "./ThemeSwitch.svelte";

  // Desktop-only gear menu: the view's actions, auto-refresh and colour mode.
  // actions: { label, onclick, disabled?, title? }[]
  let { actions = [] } = $props();
</script>

<div class="dropdown dropdown-end hidden sm:inline-block">
  <div tabindex="0" role="button" class="btn btn-square border-base-300 bg-base-100 text-base-content hover:bg-base-200" aria-label="Ustawienia i akcje" title="Ustawienia i akcje">
    <Settings size={19} />
  </div>
  <div class="dropdown-content z-30 mt-2 w-72 rounded-2xl border border-base-300 bg-base-100 p-2 shadow-xl">
    <ul class="menu w-full p-0">
      {#each actions as action}
        <li>
          <button type="button" class="disabled:opacity-50" onclick={action.onclick} disabled={action.disabled} title={action.title}>
            {action.label}
          </button>
        </li>
      {/each}
    </ul>
    <div class="mt-2 space-y-3 border-t border-base-300 px-3 pb-2 pt-3">
      <RefreshIntervalSelect />
      <div class="flex items-center justify-between gap-3 text-sm text-muted">
        <span>Motyw</span>
        <ThemeSwitch />
      </div>
    </div>
  </div>
</div>
