import { describe, it, expect } from "vitest";
import { money, signedMoney, pnlClass, percent, quantity, sharePercent, nextIn, updatedLabel } from "./format.js";

// Intl pl-PL uses (narrow) no-break spaces as group separators; compare on plain spaces.
const plain = (s) => s.replace(/\s/g, " ");

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

describe("signedMoney", () => {
  it("prefixes gains with a plus and keeps the minus on losses", () => {
    expect(plain(signedMoney("9024.46"))).toBe("+9024,46 zł");
    expect(plain(signedMoney("-206.99"))).toBe("-206,99 zł");
    expect(plain(signedMoney("0"))).toBe("0,00 zł");
  });
  it("renders an em dash when unknown", () => {
    expect(signedMoney(null)).toBe("—");
  });
});

describe("percent", () => {
  it("computes signed return on cost with a Polish decimal comma", () => {
    expect(percent("20", "80")).toBe("+25,00%");
    expect(percent("-10", "200")).toBe("-5,00%");
  });
  it("returns empty string when cost is zero", () => {
    expect(percent("5", "0")).toBe("");
  });
  it("returns empty string when P/L is unknown (no price yet)", () => {
    expect(percent(null, "100")).toBe("");
    expect(percent(undefined, "100")).toBe("");
    expect(percent("", "100")).toBe("");
  });
});

describe("quantity", () => {
  it("formats share counts with a decimal comma and no trailing zeros", () => {
    expect(quantity("9.7636")).toBe("9,7636");
    expect(quantity("18.143")).toBe("18,143");
    // pl-PL groups thousands only from 5 digits up (same as money()).
    expect(quantity("1234.5")).toBe("1234,5");
    expect(plain(quantity("12345.5"))).toBe("12 345,5");
  });
  it("renders an em dash for null", () => {
    expect(quantity(null)).toBe("—");
  });
});

describe("sharePercent", () => {
  it("formats a 0..1 share as a percentage with one decimal", () => {
    expect(sharePercent(0.478)).toBe("47,8%");
    expect(sharePercent(0.022)).toBe("2,2%");
  });
  it("renders an em dash when the share is unknown", () => {
    expect(sharePercent(null)).toBe("—");
  });
});

describe("nextIn", () => {
  it("describes the time until the next refresh in plain Polish", () => {
    expect(nextIn(30_000)).toBe("za chwilę");
    expect(nextIn(42 * 60_000)).toBe("za 42 min");
    expect(nextIn(65 * 60_000)).toBe("za 1 h 5 min");
    expect(nextIn(120 * 60_000)).toBe("za 2 h");
    expect(nextIn(26 * 3_600_000)).toBe("za 1 dzień");
    expect(nextIn(50 * 3_600_000)).toBe("za 2 dni");
  });
  it("is empty when there is no next refresh", () => {
    expect(nextIn(null)).toBe("");
  });
});

describe("updatedLabel", () => {
  const now = new Date(2026, 10, 3, 12, 0);
  it("shows only the time for today's prices", () => {
    expect(updatedLabel(new Date(2026, 10, 3, 9, 10).toISOString(), now)).toBe("zaktualizowano 09:10");
  });
  it("adds the date for older prices", () => {
    expect(updatedLabel(new Date(2026, 5, 6, 6, 51).toISOString(), now)).toBe("zaktualizowano 6.06, 06:51");
  });
  it("is empty without a timestamp", () => {
    expect(updatedLabel(null, now)).toBe("");
  });
});

describe("pnlClass", () => {
  it("is green for positive, red for negative, neutral for zero", () => {
    expect(pnlClass("10")).toBe("text-success");
    expect(pnlClass("-3")).toBe("text-error");
    expect(pnlClass("0")).toBe("text-base-content/60");
  });
});
