<script>
  let { title = "", onClose, children } = $props();
</script>

<div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4" onclick={onClose}>
  <div class="bg-white rounded-lg shadow-lg max-w-lg w-full" onclick={(e) => e.stopPropagation()}>
    <div class="flex justify-between items-center px-4 py-3 border-b">
      <h3 class="font-semibold">{title}</h3>
      <button class="text-gray-500 text-2xl leading-none hover:text-gray-800" onclick={onClose} aria-label="Zamknij">×</button>
    </div>
    <div class="p-4">
      {@render children?.()}
    </div>
  </div>
</div>
