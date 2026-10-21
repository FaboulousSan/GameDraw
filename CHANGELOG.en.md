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
