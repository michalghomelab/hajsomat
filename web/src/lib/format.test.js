import { describe, it, expect } from "vitest";
import { money, pnlClass } from "./format.js";

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

describe("pnlClass", () => {
  it("is green for positive, red for negative, neutral for zero", () => {
    expect(pnlClass("10")).toBe("text-green-600");
    expect(pnlClass("-3")).toBe("text-red-600");
    expect(pnlClass("0")).toBe("text-gray-500");
  });
});
