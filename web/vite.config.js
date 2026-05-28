import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: true,
    allowedHosts: ["lvh.me", ".lvh.me", "localhost"],
    proxy: {
      "/api": "http://api:3000",
      "/cable": { target: "ws://api:3000", ws: true },
    },
    // Docker bind mounts on macOS drop fs events; poll so edits are reliably picked up.
    watch: { usePolling: true, interval: 300 },
  },
  test: { environment: "jsdom", globals: true },
});
