import { describe, it, expect } from "vitest";
import { shares, byValueDesc, displayName } from "./allocation.js";

const value = (x) => x.v;

describe("shares", () => {
  it("divides each value by the total of priced items", () => {
    const a = { v: "300" }, b = { v: "100" }, c = { v: null };
    const s = shares([a, b, c], value);
    expect(s.get(a)).toBeCloseTo(0.75);
    expect(s.get(b)).toBeCloseTo(0.25);
    expect(s.get(c)).toBeNull();
  });
  it("gives null shares instead of NaN/Infinity when the total is zero", () => {
    const z = { v: "0" };
    expect(shares([z], value).get(z)).toBeNull();
  });
  it("handles an empty list", () => {
    expect(shares([], value).size).toBe(0);
  });
});

describe("byValueDesc", () => {
  it("sorts by value descending with unpriced items last", () => {
    const a = { v: "300" }, b = { v: "100" }, c = { v: null };
    expect(byValueDesc([b, c, a], value)).toEqual([a, b, c]);
  });
  it("does not mutate the input", () => {
    const list = [{ v: "1" }, { v: "2" }];
    byValueDesc(list, value);
    expect(list[0].v).toBe("1");
  });
});

describe("displayName", () => {
  it("prefers the instrument name", () => {
    expect(displayName({ name: "iShares Core S&P 500", symbol: "SXR8.DE" })).toBe("iShares Core S&P 500");
  });
  it("falls back to the symbol when the name is missing", () => {
    expect(displayName({ name: "", symbol: "SXR8.DE" })).toBe("SXR8.DE");
    expect(displayName({ name: null, symbol: "SXR8.DE" })).toBe("SXR8.DE");
  });
});
