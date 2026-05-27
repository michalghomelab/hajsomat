<script>
  let { title = "", onClose, children } = $props();
</script>

<div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onclick={onClose}>
  <div class="modal-box bg-base-100 max-w-lg w-full" onclick={(e) => e.stopPropagation()}>
    <div class="flex justify-between items-center mb-4">
      <h3 class="font-semibold text-lg">{title}</h3>
      <button class="btn btn-sm btn-circle btn-ghost" onclick={onClose} aria-label="Zamknij">✕</button>
    </div>
    {@render children?.()}
  </div>
</div>
