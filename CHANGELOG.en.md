## GameDraw 1.0.7 — STAB-C6-HF2 (release / EXE)

- Fix eight blocking `npm run check` errors reported by DEV-HUB (`CodeRetour=40`) when running `--devhub-release`.
- Move cover regression checks to `cover-layout.test.mjs`: the same Vitest tests run in Node, outside application Svelte type checking, without a new npm dependency.
- Provide explicit `migrate<AppConfig>` return types in GitHub-consent tests without changing migration logic.
- Add DEV-HUB static guards and a Windows verification procedure.
- Keep **v1.0.7** and all C4/C5/C6/HF1 changes, with no additional features.
- Native Windows `--devhub-release` **still requires confirmation**.


## GameDraw 1.0.7 STAB-C6-HF1 (2026-10-24)
- Fix Rust `old_data_preserved_after_success` regression: sync the recovery marker using the same writable handle on Windows.
- Do not overwrite an existing marker; clean staging on marker failure.
- Add two regression tests and DEV-HUB static guards; keep the 1.0.7 feature freeze and previous C4/C5/C6 fixes.
- **Windows validation pending**: `--devhub-test`, `--devhub-validate`, `--devhub-build`.

# STAB-C6 — Library ZIP import hardening (2026-10-24)

Bounded ZIP metadata and extraction, staging of covers, rollback cleanup, skip duplicate covers, off-UI-thread processing; no new features. Rust tests included but not run without Cargo. Version remains 1.0.7.

## GameDraw 1.0.7 — STAB-C5 stabilization (2026-10-24)

- Full ZIP restore now validates and extracts in staging, checks unsafe paths and resource limits, and keeps the previous data folder as a recovery copy.
- Corrupt archives and incorrect passwords cannot partially overwrite the active dataset during extraction.
- Background extraction and mandatory app exit after successful restore; Rust regression tests added (not run here; Windows/Cargo verification pending). No new features.

## GameDraw 1.0.7 — stabilization STAB-C4 (2026-10-24)

- Game details artwork frame now follows the source image's native aspect ratio; no title or edge clipping by fixed 3:4 layout. No feature additions.
- DEV-HUB regression guard and Chromium CSS QA on five image ratios and two viewport widths.
- Windows/WebView2/EXE verification is still required.


## 1.0.7 — STAB-C3 (cover fixes only, no new features)
- Visual: preserves corner pixels under rounded frames, native artwork remains fully visible, Chromium checks five ratios.
- Reliability: stale asynchronous local-image fallback cannot overwrite a newly selected cover.
- Steam: resolves modern official hashed CDN portrait artwork first, including HD, without an API key.
- Validation: static audit PASS; compiled Svelte/Rust and Windows tests still pending.

## V1 stabilization candidate — full, centered covers (2026-10-23)

- Fix only: show complete covers across existing screens, without CSS cropping or clipped hover zoom.
- Added static DEV-HUB guard and Vitest regression tests for eight affected views.
- Added P0/P1 audit and Windows acceptance plan; no new features, application stays at 1.0.7 until Windows certification.

## 1.0.7 — Library and cover studio (2026-10-21)

- Unified Catalog and Import entry point for included game lists, with explicit preview and confirmation.
- SteamGridDB without an API key: preview an image URL before downloading and applying it.
- Polished import menus and artwork studio, preserving API-key gallery.
- npm, Rust, Tauri and DEV-HUB version aligned to 1.0.7.

## 1.0.6 — HF3 (2026-10-20)
- Fixed update permission dialog: corrected language binding; store Yes/No choice separately from the existence of `config.json`.
- Native responsive game details dialog with permanently accessible actions and internal scroll.
- Public SteamGridDB: "Import copied image" action after browser image right-click, with Ctrl+V fallback.
- Updated FR/EN documentation; application version unchanged.

# CHANGELOG — GameDraw 1.0.6

Release date: October 18, 2026

## UI and artwork
- A GameDraw **cover right-click menu** for edit, local import, SteamGridDB and confirmed cover removal (the game is preserved).
- Fix external SteamGridDB browser launches using Tauri `opener:default` permission for HTTP(S) links.
- The cover studio is rendered outside the transformed game-details dialog to avoid clipping.
- Persistent import success notice and a **Done — close artwork studio** button.

## Updates
- Publisher-only GitHub repository settings are hidden. Official repository: `FaboulousSan/GameDraw`; users can still select the update channel and toggle auto-checks.
- Animated notifications are preserved.
- Downloaded EXE installers are **not launched silently**. Signed Tauri auto-install remains a separate publisher signing phase.

## Quality and docs
- Rust, npm, Tauri, DEV-HUB and app version updated to 1.0.6.
- Changelog in **Settings → About**, bilingual README, Wiki.js.
- No user library schema migration or data deletion.

## Windows verification still required
Self-test → Sync → Validate → Test → Dev → Build → Release. Test SteamGridDB with and without a key, cover menu, local import, studio closing, window layout and Windows packages.


## Hotfix 1.0.6 HF2 — Responsive SteamGridDB studio and update opt-in (2026-10-19)

- A real top-layer HTML dialog keeps the studio close button visible even at small window sizes or Windows 125/150% scaling. Escape and scrollable content remain available.
- Without an API key, browse SteamGridDB's public website in a **GameDraw-managed WebView2 window**, then import a direct HTTPS image URL or a saved local image; external browser fallback retained.
- The automatic artwork gallery still requires a SteamGridDB API key; no scraping or authentication bypass.
- First launch now asks for a **Yes/No update-check preference** immediately after language selection, without connecting to GitHub beforehand. Existing preferences remain intact.
- Added targeted Tauri window permissions and updated bilingual documentation.

## Hotfix 1.0.6 HF1 — Bundled lists and Windows icon
- Direct import of the bundled PC (60), Switch 1 (60), Switch 2 (40) and combined Switch (100) lists from the installed application.
- Combined import (160 entries) routes games to PC and Switch, preserving generation tags, existing games and covers.
- Import preview, confirmation, duplicates skipped and result summary; included CSVs do not require a separate file in release builds.
- A 256 px icon is now used for the running window instead of replacing the EXE icon with a 64 px resource. Large Windows ICO sizes were optically enlarged while keeping small dedicated glyphs.
- No modification to Windows taskbar settings, game data schema or draw engine.


### V1.0.7 stability patch — uncropped covers and no-key sources
- Full visible, centered original artwork; decorative blurred background fills the frame without cropping the original.
- No-key workflow: official public Steam artwork plus user-initiated SteamGridDB public site image/URL/file imports.
- The SteamGridDB API still requires a key; no unattended page scraping.
- Network downloads capped during streaming; additional static checks. Version stays **1.0.7**, Windows runtime verification pending.
