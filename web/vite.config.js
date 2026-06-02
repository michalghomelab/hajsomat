import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { VitePWA } from "vite-plugin-pwa";
import { execSync } from "node:child_process";

const buildId = process.env.VITE_BUILD_ID || (() => {
  try {
    return execSync("git rev-parse --short HEAD", { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch {
    return "dev";
  }
})();

export default defineConfig({
  define: { __BUILD_ID__: JSON.stringify(buildId) },
  plugins: [
    svelte(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.svg", "apple-touch-icon-180x180.png"],
      manifest: {
        name: "hajsomat",
        short_name: "hajsomat",
        description: "Tracker portfela akcji i ETF-ów",
        lang: "pl",
        theme_color: "#863bff",
        background_color: "#ffffff",
        display: "standalone",
        start_url: "/",
        scope: "/",
        icons: [
          { src: "pwa-192x192.png", sizes: "192x192", type: "image/png" },
          { src: "pwa-512x512.png", sizes: "512x512", type: "image/png" },
          { src: "maskable-icon-512x512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
      workbox: {
        // Precache the app shell; serve live data from the network but fall back
        // to the last response when offline (the UI's "Ceny zaktualizowane" stamp
        // makes staleness visible). POSTs (refresh/snapshot) always hit the network.
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/api\//, /^\/cable/],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/api/"),
            handler: "NetworkFirst",
            options: {
              cacheName: "api",
              networkTimeoutSeconds: 5,
              expiration: { maxEntries: 64, maxAgeSeconds: 60 * 60 * 24 * 7 },
              cacheableResponse: { statuses: [0, 200] },
            },
          },
        ],
      },
      devOptions: { enabled: false },
    }),
  ],
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
  build: {
    chunkSizeWarningLimit: 550,
  },
  test: { environment: "jsdom", globals: true },
});
