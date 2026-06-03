<script>
  let { title = "", onClose, children } = $props();
</script>

<div class="fixed inset-0 z-50 flex items-center justify-center p-4">
  <button type="button" class="absolute inset-0 bg-black/45 backdrop-blur-sm" onclick={onClose} aria-label="Zamknij"></button>
  <div class="relative max-h-[calc(100dvh-2rem)] w-full max-w-lg overflow-auto rounded-2xl border border-base-300/70 bg-base-100/95 p-5 text-base-content shadow-[0_24px_80px_rgba(0,0,0,0.28)] backdrop-blur-xl sm:p-6"
       role="dialog" aria-modal="true" aria-label={title}>
    <div class="mb-5 flex items-start justify-between gap-4">
      <div>
        <h3 class="text-lg font-semibold leading-tight">{title}</h3>
      </div>
      <button class="btn btn-circle btn-ghost min-h-12 h-12 w-12 text-xl sm:min-h-10 sm:h-10 sm:w-10" onclick={onClose} aria-label="Zamknij">✕</button>
    </div>
    {@render children?.()}
  </div>
</div>
