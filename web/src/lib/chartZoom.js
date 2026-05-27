// Wheel-to-zoom on the X axis for ApexCharts, zooming toward the cursor.
// ApexCharts couples its built-in wheel zoom with drag-selection (same setup
// path), so the only way to get "wheel zoom, no selection box" is to disable
// its zoom entirely and drive chart.zoomX() ourselves.
export function attachWheelZoom(chart, el) {
  const g = chart.w.globals;
  let lo, hi; // full data range, captured on first wheel (before any zoom)

  const onWheel = (e) => {
    const svg = el.querySelector(".apexcharts-svg");
    if (!svg) return;
    e.preventDefault();

    if (lo === undefined) {
      lo = g.minX;
      hi = g.maxX;
    }
    const min = g.minX;
    const max = g.maxX;
    const range = max - min;
    if (!range) return;

    const rect = svg.getBoundingClientRect();
    const frac = Math.min(1, Math.max(0, (e.clientX - rect.left - g.translateX) / g.gridWidth));
    const focus = min + frac * range;

    let newRange = range * (e.deltaY < 0 ? 0.8 : 1.25);
    if (newRange >= hi - lo) {
      chart.zoomX(lo, hi);
      return;
    }
    let newMin = focus - frac * newRange;
    let newMax = newMin + newRange;
    if (newMin < lo) [newMin, newMax] = [lo, lo + newRange];
    if (newMax > hi) [newMin, newMax] = [hi - newRange, hi];

    chart.zoomX(newMin, newMax);
  };

  el.addEventListener("wheel", onWheel, { passive: false });
  return () => el.removeEventListener("wheel", onWheel);
}
