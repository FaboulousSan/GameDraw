import { describe, expect, it } from "vitest";
import tauriConfig from "../../src-tauri/tauri.conf.json";

// Régression HF21 : une compilation Rust réussie ne garantit pas que WebView2
// autorise les URL d'images (asset protocol Windows en HTTP, miniatures HTTPS).
describe("jaquettes : configuration WebView2", () => {
  for (const [nom, csp] of [["release", tauriConfig.app.security.csp], ["dev", tauriConfig.app.security.devCsp]] as const) {
    it(`autorise les jaquettes locales et distantes en ${nom}`, () => {
      const images = csp.split(";").map((part) => part.trim()).find((part) => part.startsWith("img-src"));
      expect(images).toBeTruthy();
      for (const origine of ["http://asset.localhost", "https://asset.localhost", "https:", "data:"]) {
        expect(images).toContain(origine);
      }
    });
    it(`n'élargit pas connect-src aux réseaux publics en ${nom}`, () => {
      const connect = csp.split(";").map((part) => part.trim()).find((part) => part.startsWith("connect-src"));
      expect(connect).not.toContain("https:");
    });
  }
});
