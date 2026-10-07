import { defineConfig } from "vitest/config";

// Les tests GameDraw sont des tests TypeScript purs. Ils n'ont pas besoin du
// plugin Svelte de vite.config.ts ; les isoler évite aussi de charger une
// configuration de plugin incompatible avec le Vite interne de Vitest.
export default defineConfig({
  test: {
    environment: "node",
  },
});
