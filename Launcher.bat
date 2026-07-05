@echo off
:: ============================================================
:: GameDraw - Launcher (elevation automatique + execution PS1)
:: Pour un lancement sans la moindre fenetre visible (recommande
:: au quotidien), utilise plutot le raccourci Bureau cree depuis
:: Options -> Creer un raccourci sur le Bureau : il elance
:: PowerShell directement, sans passer par ce .bat.
:: ============================================================
set "SCRIPT_DIR=%~dp0"
set "PS1_PATH=%SCRIPT_DIR%scripts\Tirage-Jeux.ps1"

net session >nul 2>&1
if %errorLevel% == 0 (
    goto :run
) else (
    powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%PS1_PATH%\"' -Verb RunAs"
    exit /b
)

:run
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%PS1_PATH%"
exit /b
