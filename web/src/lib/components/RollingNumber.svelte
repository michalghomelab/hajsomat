<script>
  import { cubicOut } from "svelte/easing";

  // Odometer/drum effect: each digit sits on a reel. When `value` rises the
  // digits roll down; when it falls they roll up. Non-digits (spaces, comma,
  // currency, sign) render as plain text. `text` is the formatted string.
  let { value, text } = $props();
  let dir = $state(1);
  let prev = Number(value);

  $effect(() => {
    const n = Number(value);
    if (!Number.isNaN(n) && n !== prev) {
      dir = n > prev ? 1 : -1;
      prev = n;
    }
  });

  let chars = $derived([...String(text ?? "")]);

  function roll(_node, { y }) {
    return { duration: 350, easing: cubicOut, css: (_t, u) => `transform: translateY(${u * y}%)` };
  }
</script>

<span class="rolling tabular-nums">{#each chars as ch, i (i)}{#if ch >= "0" && ch <= "9"}<span class="slot"><span class="ghost">0</span>{#key ch}<span class="digit" in:roll={{ y: dir > 0 ? -100 : 100 }} out:roll={{ y: dir > 0 ? 100 : -100 }}>{ch}</span>{/key}</span>{:else}{ch}{/if}{/each}</span>

<style>
  .rolling {
    display: inline-block;
    white-space: nowrap;
  }
  .slot {
    position: relative;
    display: inline-block;
    overflow: hidden;
    vertical-align: baseline;
  }
  .ghost {
    visibility: hidden;
  }
  .digit {
    position: absolute;
    left: 0;
    top: 0;
    width: 100%;
    text-align: center;
  }
</style>
