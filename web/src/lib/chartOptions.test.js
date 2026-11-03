import { describe, it, expect } from "vitest";
import { buildChartOptions, seriesColors, compactNumber } from "./chartOptions.js";

const snaps = [
  { date: "2026-08-03", total_value_pln: "60000", total_cost_pln: "50000", pnl_pln: "10000" },
  { date: "2026-08-04", total_value_pln: "61500", total_cost_pln: "50000", pnl_pln: "11500" },
  { date: "2026-08-05", total_value_pln: "61000", total_cost_pln: "50500", pnl_pln: "10500" },
];
const palette = { gain: "#148A55", loss: "#CC3D45" };
const build = (opts) => buildChartOptions(snaps, { palette, dark: false, compact: false, ...opts });

describe("buildChartOptions", () => {
  it("keeps the five series in their remembered order and names", () => {
    expect(build().series.map((s) => s.name)).toEqual([
      "Wartość", "Wpłaty", "Zysk", "Zmiana rynkowa", "Wpłata (dzienna)",
    ]);
  });

  it("fades the value area vertically in the series colour, not a grey horizontal wash", () => {
    const { fill } = build();
    expect(fill.type[0]).toBe("gradient");
    expect(fill.gradient.type).toBe("vertical");
    expect(fill.gradient.shadeIntensity).toBe(0);
  });

  it("uses Automat navy for value in light mode and a light navy in dark mode", () => {
    expect(build().colors[0]).toBe("#141A33");
    expect(build({ dark: true }).colors[0]).toBe("#C9D1F0");
    expect(build().colors[1]).toBe("#F2B705");
  });

  it("colours daily market bars green for gains and red for losses", () => {
    const bars = build().series[3].data;
    expect(bars[0].fillColor).toBe(palette.gain); // +1500 - 0 deposit
    expect(bars[1].fillColor).toBe(palette.loss); // -500 value, +500 deposit → -1000 market
  });

  it("drops rotated axis titles and rotated dates on narrow screens", () => {
    const { yaxis, xaxis } = build({ compact: true });
    yaxis.forEach((axis) => expect(axis.title?.text).toBeFalsy());
    expect(xaxis.labels.rotate).toBe(0);
    expect(xaxis.labels.formatter(0)).toBe("03.08");
  });

  it("keeps axis titles and full dates on wide screens", () => {
    const { yaxis, xaxis } = build();
    expect(yaxis[0].title.text).toBeTruthy();
    expect(xaxis.labels.formatter(0)).toBe("03.08.2026");
  });

  it("abbreviates the daily-change axis on narrow screens", () => {
    expect(build({ compact: true }).yaxis[1].labels.formatter(1500)).toBe("1,5k");
  });
});

describe("seriesColors", () => {
  it("returns value, deposits, profit, gain bars, deposit bars", () => {
    expect(seriesColors(palette, false)).toHaveLength(5);
    expect(seriesColors(palette, false)[3]).toBe(palette.gain);
  });
});

describe("compactNumber", () => {
  it("shortens thousands with a Polish comma", () => {
    expect(compactNumber(1500)).toBe("1,5k");
    expect(compactNumber(-2000)).toBe("-2k");
    expect(compactNumber(450)).toBe("450");
  });
});
