// ApexCharts options for the combined portfolio chart (value / deposits /
// profit areas on the left axis, daily change bars on the right axis).
import { loadHiddenSeries, saveHiddenSeries } from "./chartRange.js";

const VALUE = { light: "#141A33", dark: "#C9D1F0" };
const DEPOSITS = "#F2B705";
const PROFIT = { light: "#0E7490", dark: "#5EC4D4" };
const DEPOSIT_BARS = "#9AA3B8";

export function seriesColors(palette, dark) {
  const mode = dark ? "dark" : "light";
  return [VALUE[mode], DEPOSITS, PROFIT[mode], palette.gain, DEPOSIT_BARS];
}

// Theme colours for gain/loss, read from the active daisyUI theme.
export function chartPalette() {
  const css = getComputedStyle(document.documentElement);
  const read = (name, fallback) => css.getPropertyValue(name).trim() || fallback;
  return { gain: read("--color-success", "#148A55"), loss: read("--color-error", "#CC3D45") };
}

const pl1 = new Intl.NumberFormat("pl-PL", { maximumFractionDigits: 1 });
export function compactNumber(v) {
  const n = Number(v);
  if (Math.abs(n) >= 1000) return `${pl1.format(n / 1000)}k`;
  return String(Math.round(n));
}

const money = (v) => v.toLocaleString("pl-PL", { style: "currency", currency: "PLN" });
const plnAxis = (v) => Math.round(v).toLocaleString("pl-PL");
const fullDate = (date) => new Date(`${date}T00:00:00`).toLocaleDateString("pl-PL", {
  day: "2-digit", month: "2-digit", year: "numeric",
});
const shortDate = (date) => date.slice(8, 10) + "." + date.slice(5, 7);

const dateAt = (snaps, value) => {
  const index = Math.round(Number(value));
  return Number.isInteger(index) && snaps[index]?.date ? snaps[index].date : null;
};

// Split each day's value change into the deposit part (Δ cost basis = money
// added that day) and the market part (the rest = price/FX moves).
function dayChanges(snaps) {
  const out = [];
  for (let i = 1; i < snaps.length; i++) {
    const dValue = Number(snaps[i].total_value_pln) - Number(snaps[i - 1].total_value_pln);
    const dCost = Number(snaps[i].total_cost_pln) - Number(snaps[i - 1].total_cost_pln);
    out.push({ index: i, deposit: dCost, market: dValue - dCost });
  }
  return out;
}

// All series use the same { x, y } format — mixing object and tuple formats in
// one chart makes ApexCharts misparse the y-values of some series. Names are
// the keys of the persisted legend state, so they must not change.
export function buildSeries(snaps, palette) {
  const d = dayChanges(snaps);
  return [
    { name: "Wartość", type: "area", data: snaps.map((s, i) => ({ x: i, y: Number(s.total_value_pln) })) },
    { name: "Wpłaty", type: "area", data: snaps.map((s, i) => ({ x: i, y: Number(s.total_cost_pln) })) },
    { name: "Zysk", type: "area", data: snaps.map((s, i) => ({ x: i, y: Number(s.pnl_pln) })) },
    {
      name: "Zmiana rynkowa", type: "column",
      data: d.map((x) => ({ x: x.index, y: Number(x.market.toFixed(2)),
        fillColor: x.market >= 0 ? palette.gain : palette.loss })),
    },
    { name: "Wpłata (dzienna)", type: "column", data: d.map((x) => ({ x: x.index, y: Number(x.deposit.toFixed(2)) })) },
  ];
}

export function buildXaxis(snaps, { compact }) {
  const format = compact ? shortDate : fullDate;
  return {
    type: "numeric",
    min: 0,
    max: Math.max(0, snaps.length - 1),
    tickAmount: Math.min(compact ? 4 : 6, Math.max(1, snaps.length - 1)),
    labels: {
      rotate: 0,
      hideOverlappingLabels: true,
      formatter: (value) => {
        const date = dateAt(snaps, value);
        return date ? format(date) : "";
      },
    },
  };
}

// Wartość (0) and Zysk (2) append the % change vs the previous visible point.
export function buildTooltip(snaps, palette) {
  return {
    shared: true,
    intersect: false,
    x: { formatter: (value) => {
      const date = dateAt(snaps, value);
      return date ? fullDate(date) : "";
    } },
    y: { formatter: (v, { seriesIndex, dataPointIndex, series: data }) => {
      if (v == null) return "—";
      if (seriesIndex === 0 || seriesIndex === 2) {
        const prev = data[seriesIndex]?.[dataPointIndex - 1];
        if (dataPointIndex > 0 && prev != null && prev !== 0) {
          const pct = ((v - prev) / Math.abs(prev)) * 100;
          const color = pct >= 0 ? palette.gain : palette.loss;
          return `${money(v)} <span style="color:${color}">(${pct >= 0 ? "+" : "−"}${Math.abs(pct).toFixed(2).replace(".", ",")}%)</span>`;
        }
      }
      return money(v);
    } },
  };
}

function yaxis({ compact }) {
  const title = (text) => ({ text: compact ? undefined : text });
  return [
    { seriesName: ["Wartość", "Wpłaty", "Zysk"], labels: { formatter: compact ? compactNumber : plnAxis },
      title: title("PLN (skumulowane)") },
    { seriesName: ["Zmiana rynkowa", "Wpłata (dzienna)"], opposite: true,
      labels: { formatter: compact ? compactNumber : plnAxis }, title: title("zł / dzień") },
  ];
}

export function buildChartOptions(snaps, { palette, dark, compact }) {
  return {
    chart: {
      type: "line", height: compact ? 300 : 380, stacked: false,
      fontFamily: "inherit", background: "transparent",
      toolbar: { show: false }, zoom: { enabled: false }, animations: { easing: "easeinout" },
      events: {
        // Restore the persisted on/off state once the chart is on screen, and
        // persist every legend toggle so it survives reloads.
        mounted: (ctx) => loadHiddenSeries().forEach((name) => ctx.hideSeries(name)),
        legendClick: (ctx, i) => {
          const name = ctx.w.globals.seriesNames[i];
          if (!name) return;
          const hidden = new Set(loadHiddenSeries());
          hidden.has(name) ? hidden.delete(name) : hidden.add(name);
          saveHiddenSeries([...hidden]);
        },
      },
    },
    theme: { mode: dark ? "dark" : "light" },
    series: buildSeries(snaps, palette),
    colors: seriesColors(palette, dark),
    stroke: { curve: "smooth", width: [2.5, 2, 2, 0, 0], dashArray: [0, 5, 0, 0, 0] },
    fill: {
      type: ["gradient", "solid", "solid", "solid", "solid"],
      gradient: { type: "vertical", shade: "light", shadeIntensity: 0, opacityFrom: 0.22, opacityTo: 0, stops: [0, 95] },
      opacity: [1, 0, 0, 1, 1],
    },
    plotOptions: { bar: { columnWidth: "68%", borderRadius: 2 } },
    dataLabels: { enabled: false },
    legend: {
      position: "top",
      horizontalAlign: "left",
      fontSize: "12px",
      markers: { size: 4 },
      itemMargin: { horizontal: 8, vertical: 2 },
      labels: { colors: dark ? "#A7AEC9" : "#646B85" },
    },
    xaxis: buildXaxis(snaps, { compact }),
    yaxis: yaxis({ compact }),
    grid: { borderColor: dark ? "rgba(255,255,255,0.06)" : "rgba(20,26,51,0.06)", strokeDashArray: 3,
      padding: { left: compact ? 0 : 8, right: compact ? 0 : 8 } },
    states: {
      hover: { filter: { type: "lighten", value: 0.04 } },
      active: { filter: { type: "none" } },
    },
    tooltip: buildTooltip(snaps, palette),
  };
}
