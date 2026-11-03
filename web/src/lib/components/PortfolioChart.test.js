import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render } from "@testing-library/svelte";

const built = [];
vi.mock("apexcharts/area", () => ({
  default: class {
    constructor(_el, options) {
      built.push(options);
      this.w = { globals: {} };
    }
    render() {}
    updateOptions() {}
    destroy() {}
  },
}));
vi.mock("apexcharts/column", () => ({}));
vi.mock("apexcharts/features/legend", () => ({}));
vi.mock("../chartZoom.js", () => ({ attachWheelZoom: () => () => {} }));

// bind:clientWidth relies on ResizeObserver, which jsdom lacks; it never fires here.
globalThis.ResizeObserver ??= class { observe() {} unobserve() {} disconnect() {} };

const { default: PortfolioChart } = await import("./PortfolioChart.svelte");

const snapshots = [
  { date: "2026-08-03", total_value_pln: "60000", total_cost_pln: "50000", pnl_pln: "10000" },
  { date: "2026-08-04", total_value_pln: "61500", total_cost_pln: "50000", pnl_pln: "11500" },
];

let widthSpy;
beforeEach(() => {
  built.length = 0;
  // jsdom has no layout; pretend every element is phone-width.
  widthSpy = vi.spyOn(HTMLElement.prototype, "clientWidth", "get").mockReturnValue(358);
});
afterEach(() => widthSpy.mockRestore());

describe("PortfolioChart", () => {
  it("builds the compact phone layout straight away instead of resizing after the first render", () => {
    render(PortfolioChart, { snapshots });
    expect(built).toHaveLength(1);
    expect(built[0].chart.height).toBe(300);
    expect(built[0].xaxis.labels.formatter(0)).toBe("03.08");
  });
});
