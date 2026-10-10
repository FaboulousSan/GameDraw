import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

// Config Vite adaptée aux contraintes Tauri :
// - ne jamais clear la console (les logs Rust y transitent aussi en dev)
// - port fixe, strictPort pour que Tauri sache toujours où pointer
// - ignorer src-tauri/ dans le watcher (évite les rebuilds en boucle)
export default defineConfig({
  plugins: [svelte()],
  clearScreen: false,
  server: {
    // Même interface de boucle locale que Tauri/WebView2 : pas de résolution ambiguë de localhost.
    host: "127.0.0.1",
    port: 1420,
    hmr: { host: "127.0.0.1", port: 1420, protocol: "ws" },
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
  envPrefix: ["VITE_", "TAURI_"],
  build: {
    target: process.env.TAURI_ENV_PLATFORM === "windows" ? "chrome105" : "safari13",
    minify: !process.env.TAURI_ENV_DEBUG ? "esbuild" : false,
    sourcemap: !!process.env.TAURI_ENV_DEBUG,
  },
});
