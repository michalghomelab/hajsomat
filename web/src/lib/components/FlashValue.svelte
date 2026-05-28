<script>
  // Briefly flashes its content (fades in from lighter to the target colour)
  // whenever `value` changes. No flash on first render. Colour is untouched —
  // just an opacity pulse, so it works for black and coloured text alike.
  let { value, children } = $props();
  let on = $state(false);
  let prev = value;

  $effect(() => {
    if (value === prev) return;
    prev = value;
    on = false; // restart the animation even on back-to-back changes
    requestAnimationFrame(() => (on = true));
  });
</script>

<span class={on ? "value-flash" : ""}>{@render children()}</span>
