import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { THEME_MODES, theme, setTheme, initTheme } from "./theme.svelte.js";

const root = document.documentElement;

beforeEach(() => {
  localStorage.clear();
  root.removeAttribute("data-theme");
});
afterEach(() => vi.restoreAllMocks());

describe("THEME_MODES", () => {
  it("lists Dzień, Auto and Noc in that order", () => {
    expect(THEME_MODES.map((m) => [m.id, m.label])).toEqual([
      ["light", "Dzień"], ["auto", "Auto"], ["dark", "Noc"],
    ]);
  });
});

describe("initTheme", () => {
  it("applies the saved mode before anything renders", () => {
    localStorage.setItem("hajsomat:theme", "dark");
    initTheme();
    expect(root.dataset.theme).toBe("dark");
    expect(theme.mode).toBe("dark");
  });
  it("falls back to auto for an unknown saved value", () => {
    localStorage.setItem("hajsomat:theme", "bogus");
    initTheme();
    expect(theme.mode).toBe("auto");
    expect(root.hasAttribute("data-theme")).toBe(false);
  });
  it("falls back to auto when storage is unavailable", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => { throw new Error("blocked"); });
    expect(() => initTheme()).not.toThrow();
    expect(theme.mode).toBe("auto");
  });
});

describe("setTheme", () => {
  it("auto removes the data-theme attribute, persists, and announces the change", () => {
    root.dataset.theme = "dark";
    const seen = [];
    const onChange = (e) => seen.push(e.detail.mode);
    window.addEventListener("hajsomat:themechange", onChange);
    setTheme("auto");
    window.removeEventListener("hajsomat:themechange", onChange);
    expect(root.hasAttribute("data-theme")).toBe(false);
    expect(localStorage.getItem("hajsomat:theme")).toBe("auto");
    expect(seen).toEqual(["auto"]);
    expect(theme.mode).toBe("auto");
  });
  it("light sets the data-theme attribute", () => {
    setTheme("light");
    expect(root.dataset.theme).toBe("light");
  });
});
