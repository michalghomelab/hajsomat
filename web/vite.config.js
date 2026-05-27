import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  plugins: [svelte()],
  server: {
    host: true,
    proxy: { "/api": "http://api:3000" },
  },
  test: { environment: "jsdom", globals: true },
});
