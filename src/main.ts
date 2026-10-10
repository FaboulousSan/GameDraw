import { mount } from "svelte";
import "./app.css";
import "./lib/animations/animations.css";
import App from "./App.svelte";
import { api } from "./lib/api";

// Filet de sécurité global : toute erreur JS/promesse non interceptée finit
// dans error.log (même fichier que les erreurs Rust), pas seulement dans la
// console DevTools qu'on n'aura pas sous les yeux une fois l'app packagée.
window.addEventListener("error", (e) => {
  void api.logError(`window.onerror: ${e.message} (${e.filename}:${e.lineno})`).catch(() => {});
});
window.addEventListener("unhandledrejection", (e) => {
  void api.logError(`unhandledrejection: ${String(e.reason)}`).catch(() => {});
});

const target = document.getElementById("app");
if (!target) {
  window.dispatchEvent(new CustomEvent("gamedraw:fatal", { detail: "Conteneur #app absent du document." }));
  throw new Error("GameDraw: #app absent");
}

let app: ReturnType<typeof mount>;
try {
  app = mount(App, { target });
} catch (error) {
  const message = `Montage Svelte impossible : ${String(error)}`;
  window.dispatchEvent(new CustomEvent("gamedraw:fatal", { detail: message }));
  void api.logError(message).catch(() => {});
  throw error;
}

export default app;
