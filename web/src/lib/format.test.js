import { describe, it, expect } from "vitest";
import { money, pnlClass, percent } from "./format.js";

describe("money", () => {
  it("formats a PLN value", () => {
    const out = money("1234.5", "PLN");
    expect(out).toContain("1");
    expect(out).toContain("234");
    expect(out).toMatch(/zł/); // "zł"
  });
  it("renders an em dash for null", () => {
    expect(money(null, "PLN")).toBe("—");
  });
});

describe("percent", () => {
  it("computes signed return on cost", () => {
    expect(percent("20", "80")).toBe("+25.00%");
    expect(percent("-10", "200")).toBe("-5.00%");
  });
  it("returns empty string when cost is zero", () => {
    expect(percent("5", "0")).toBe("");
  });
});

describe("pnlClass", () => {
  it("is green for positive, red for negative, neutral for zero", () => {
    expect(pnlClass("10")).toBe("text-success");
    expect(pnlClass("-3")).toBe("text-error");
    expect(pnlClass("0")).toBe("text-base-content/60");
  });
});
