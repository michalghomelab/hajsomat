// Colour mode (Dzień / Auto / Noc), persisted per browser. Initialised from
// main.js before the app mounts, so the theme applies even when no switch is
// on screen (the switch now lives inside menus).
const KEY = "hajsomat:theme";

export const THEME_MODES = [
  { id: "light", label: "Dzień" },
  { id: "auto", label: "Auto" },
  { id: "dark", label: "Noc" },
];

let mode = $state("auto");

export const theme = {
  get mode() {
    return mode;
  },
};

export function setTheme(next) {
  mode = next;
  try {
    localStorage.setItem(KEY, next);
  } catch {
    // selection just won't persist
  }
  const root = document.documentElement;
  if (next === "auto") root.removeAttribute("data-theme");
  else root.dataset.theme = next;
  window.dispatchEvent(new CustomEvent("hajsomat:themechange", { detail: { mode: next } }));
}

export function initTheme() {
  let saved = "auto";
  try {
    saved = localStorage.getItem(KEY) || "auto";
  } catch {
    // storage unavailable (private mode) — use the system setting
  }
  setTheme(THEME_MODES.some((m) => m.id === saved) ? saved : "auto");
}
