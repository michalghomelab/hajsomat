import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/svelte";
import Hero from "./Hero.svelte";

vi.mock("../api.js", () => ({
  api: { schedule: vi.fn().mockResolvedValue({ next_refresh_at: null }) },
}));

const plain = (s) => s.replace(/\s/g, " ");
const pnlLine = () => screen.getByTestId("hero-pnl");

describe("Hero", () => {
  it("shows value, signed P/L with return and the deposited amount", () => {
    const { container } = render(Hero, { value: "65978.5", pnl: "13967.42", cost: "52011.08" });
    const text = plain(container.textContent);
    expect(text).toContain("65 978,50 zł");
    expect(text).toContain("+13 967,42 zł");
    expect(text).toContain("+26,85%");
    expect(text).toContain("Wpłacono 52 011,08 zł");
    expect(pnlLine().className).toContain("text-accent");
  });

  it("uses the loss colour, not gold, for a negative P/L", () => {
    const { container } = render(Hero, { value: "900", pnl: "-100", cost: "1000" });
    expect(plain(container.textContent)).toContain("-10,00%");
    expect(pnlLine().className).not.toContain("text-accent");
    expect(pnlLine().getAttribute("style")).toContain("--hero-loss");
  });

  it("renders an empty portfolio without NaN or Infinity", () => {
    const { container } = render(Hero, { value: "0", pnl: "0", cost: "0" });
    const text = plain(container.textContent);
    expect(text).toContain("0,00 zł");
    expect(text).not.toMatch(/NaN|Infinity/);
  });

  it("warns when some positions have no current price", () => {
    render(Hero, { value: "100", pnl: "10", cost: "90", incomplete: true });
    expect(screen.getByText(/Część pozycji nie ma aktualnej wyceny/)).toBeTruthy();
  });
});
