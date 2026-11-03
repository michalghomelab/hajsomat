<script>
  import RollingNumber from "./RollingNumber.svelte";
  import Countdown from "./Countdown.svelte";
  import { money, signedMoney, percent, updatedLabel } from "../format.js";

  // The navy "Automat" header: one big number, the P/L line in gold (or the
  // loss colour), what was paid in. `top` renders on the first row (title,
  // back link, rename); `extra` adds a line under the totals.
  let { value, pnl, cost, updatedAt = null, incomplete = false, top, extra } = $props();

  const blank = (v) => v === null || v === undefined || v === "";
  let gain = $derived(!blank(pnl) && Number(pnl) >= 0);
  let signedPnl = $derived(signedMoney(pnl));
  let returnPct = $derived(percent(pnl, cost));
</script>

<section class="hero -mx-3 -mt-6 rounded-b-[1.75rem] border-x-0 border-t-0 border-b bg-neutral px-5 pb-6 pt-[calc(env(safe-area-inset-top)+1.25rem)] text-neutral-content sm:mx-0 sm:mt-0 sm:rounded-3xl sm:border sm:px-7 sm:pt-6">
  <div class="flex items-start justify-between gap-3">
    <div class="min-w-0 flex-1">{@render top?.()}</div>
    <div class="shrink-0 text-right text-xs leading-relaxed text-neutral-content/65">
      {#if updatedAt}<div>{updatedLabel(updatedAt)}</div>{/if}
      <Countdown field="next_refresh_at" compact />
    </div>
  </div>
  <div class="mt-3 text-[2.5rem] font-extrabold leading-[1.1] tracking-tight sm:text-5xl">
    <RollingNumber value={value} text={money(value)} />
  </div>
  <div data-testid="hero-pnl"
       class="mt-1.5 flex flex-wrap gap-x-3 text-base font-semibold sm:text-lg {gain ? 'text-accent' : ''}"
       style={gain ? undefined : "color: var(--hero-loss)"}>
    <RollingNumber value={pnl} text={signedPnl} />
    {#if returnPct}<RollingNumber value={pnl} text={returnPct} />{/if}
  </div>
  <div class="mt-1 text-sm text-neutral-content/65">Wpłacono {money(cost)}</div>
  {@render extra?.()}
</section>
{#if incomplete}
  <p class="mt-3 rounded-xl bg-warning/12 px-3 py-2 text-sm text-warning">Część pozycji nie ma aktualnej wyceny. Odśwież ceny.</p>
{/if}
