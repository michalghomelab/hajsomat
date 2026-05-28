<script>
  // Pulses its content (fades in from lighter to the target colour) whenever
  // `value` changes. Re-keying remounts the span so the CSS animation reliably
  // replays on every change. No flash on first render.
  let { value, children } = $props();
  let key = $state(0);
  let prev = value;

  $effect(() => {
    if (value !== prev) {
      prev = value;
      key += 1;
    }
  });
</script>

{#key key}
  <span class={key > 0 ? "value-flash" : ""}>{@render children()}</span>
{/key}
