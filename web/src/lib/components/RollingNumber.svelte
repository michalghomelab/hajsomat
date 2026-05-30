<script>
  import { cubicOut } from "svelte/easing";

  // Odometer/drum effect: each digit sits on a reel. When `value` rises the
  // digits roll down; when it falls they roll up. Non-digits (spaces, comma,
  // currency, sign) render as plain text. `text` is the formatted string.
  let { value, text } = $props();
  let dir = $state(1);
  let prev = $state(null);

  $effect(() => {
    const n = Number(value);
    if (Number.isNaN(n)) return;
    if (prev == null) {
      prev = n;
      return;
    }
    if (n !== prev) {
      dir = n > prev ? 1 : -1;
      prev = n;
    }
  });

  let chars = $derived([...String(text ?? "")]);

  function roll(_node, { y }) {
    return { duration: 350, easing: cubicOut, css: (_t, u) => `transform: translateY(${u * y}%)` };
  }
</script>

<span class="rolling tabular-nums">{#each chars as ch, i (i)}{#if ch >= "0" && ch <= "9"}<span class="slot"><span class="ghost">0</span><span class="window">{#key ch}<span class="digit" in:roll={{ y: dir > 0 ? -100 : 100 }} out:roll={{ y: dir > 0 ? 100 : -100 }}>{ch}</span>{/key}</span></span>{:else}{ch}{/if}{/each}</span>

<style>
  .rolling {
    display: inline-block;
    white-space: nowrap;
  }
  .slot {
    position: relative;
    display: inline-block;
    vertical-align: baseline;
    line-height: 1;
  }
  .ghost {
    visibility: hidden;
    line-height: 1;
  }
  /* Clipping lives here, not on .slot: overflow:hidden on an inline-block would
     move its baseline to the bottom edge and push the digits up. */
  .window {
    position: absolute;
    inset: 0;
    overflow: hidden;
  }
  .digit {
    position: absolute;
    inset: 0;
    line-height: 1;
    text-align: center;
  }
</style>
