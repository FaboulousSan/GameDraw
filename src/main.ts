import { mount } from "svelte";
import "./app.css";
import "./lib/animations/animations.css";
import App from "./App.svelte";
import { api } from "./lib/api";

// Filet de sécurité global : toute erreur JS/promesse non interceptée finit
// dans error.log (même fichier que les erreurs Rust), pas seulement dans la
// console DevTools qu'on n'aura pas sous les yeux une fois l'app packagée.
window.addEventListener("error", (e) => {
  void api.logError(`window.onerror: ${e.message} (${e.filename}:${e.lineno})`);
});
window.addEventListener("unhandledrejection", (e) => {
  void api.logError(`unhandledrejection: ${String(e.reason)}`);
});

const app = mount(App, { target: document.getElementById("app")! });

export default app;
