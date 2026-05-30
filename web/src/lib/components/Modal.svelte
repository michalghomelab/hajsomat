<script>
  let { title = "", onClose, children } = $props();
</script>

<div class="fixed inset-0 flex items-center justify-center z-50 p-4">
  <button type="button" class="absolute inset-0 bg-black/40" onclick={onClose} aria-label="Zamknij"></button>
  <div class="relative bg-base-100 text-base-content rounded-2xl shadow-xl max-w-lg w-full p-6"
       role="dialog" aria-modal="true" aria-label={title}>
    <div class="flex justify-between items-center mb-4">
      <h3 class="font-semibold text-lg">{title}</h3>
      <button class="btn btn-sm btn-circle btn-ghost" onclick={onClose} aria-label="Zamknij">✕</button>
    </div>
    {@render children?.()}
  </div>
</div>
