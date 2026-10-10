/* GameDraw boot watchdog (sans dépendance et sans appel système mutateur).
   Chargé AVANT le module Svelte pour capturer les erreurs de chargement Vite/WebView2. */
(function () {
  "use strict";
  const screen = document.getElementById("gd-boot");
  const caption = document.getElementById("gd-boot-caption");
  const detail = document.getElementById("gd-boot-error");
  if (!screen || !caption || !detail) return;

  let ready = false;
  const errors = [];
  let reported = false;
  const dev = location.protocol === "http:" || location.protocol === "https:";

  function collect(message) {
    if (!message) return;
    const info = String(message).slice(0, 600);
    if (!errors.includes(info)) errors.push(info);
    if (errors.length > 8) errors.shift();
  }

  function persist(message) {
    if (reported) return;
    reported = true;
    try {
      const invoke = window.__TAURI_INTERNALS__ && window.__TAURI_INTERNALS__.invoke;
      if (typeof invoke === "function") {
        Promise.resolve(invoke("log_error", { message: "[boot-watchdog] " + message.slice(0, 2500) })).catch(function () {});
      }
    } catch (_) { /* Diagnostics toujours visibles même sans IPC */ }
  }

  function fail(message) {
    if (ready) return;
    collect(message);
    caption.textContent = "L’interface GameDraw n’a pas démarré correctement.";
    detail.hidden = false;
    const extra = dev
      ? "\n\nVérification : ouvrir " + location.origin + "/ dans le navigateur pendant que DEV-HUB/Dev fonctionne. Vérifier la console WebView2 (Ctrl+Maj+I)."
      : "\n\nConsulter le journal error.log dans les données locales de GameDraw.";
    detail.textContent = (errors.length ? errors.join("\n") : "Aucun détail JavaScript reçu.") + extra;
    persist(errors.join("\n") || String(message));
  }

  window.addEventListener("error", function (event) {
    const node = event.target;
    if (node && node !== window && (node.src || node.href)) {
      collect("Ressource impossible à charger : " + (node.src || node.href));
    } else {
      collect("Erreur JavaScript : " + (event.message || "inconnue") + (event.filename ? " (" + event.filename + ":" + event.lineno + ")" : ""));
    }
    if (!ready) setTimeout(function () { if (!ready) fail("Échec de chargement du frontend."); }, 1000);
  }, true);
  window.addEventListener("unhandledrejection", function (event) {
    collect("Promesse rejetée : " + String(event.reason));
    if (!ready) setTimeout(function () { if (!ready) fail("Échec d'initialisation JavaScript."); }, 1000);
  });
  window.addEventListener("gamedraw:fatal", function (event) {
    fail(event.detail || "Erreur fatale lors de l'initialisation Svelte.");
  });
  window.addEventListener("gamedraw:ready", function () {
    ready = true;
    screen.hidden = true;
  });

  // Les très longs démarrages ne deviennent plus une page blanche silencieuse.
  setTimeout(function () {
    if (!ready) fail("Délai de 25 s dépassé avant l'affichage de l'interface.");
  }, 25000);
})();
