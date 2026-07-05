<#
.SYNOPSIS
    Cree un raccourci GameDraw sur le Bureau avec l'icone personnalisee.
.DESCRIPTION
    A executer une seule fois (double-clic ou clic droit > Executer avec PowerShell).
    Le raccourci cible PowerShell directement (pas de .bat, pas de .vbs) et demande
    l'elevation administrateur automatiquement au double-clic (flag patche dans le .lnk).
#>

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$root       = Split-Path -Parent $root  # remonte au dossier racine du package
$ps1Path    = Join-Path $root "scripts\Tirage-Jeux.ps1"
$configFile = Join-Path (Join-Path $env:USERPROFILE "GameDraw") "config.json"

$iconChoices = @{
    Original = "GameDraw_v2.ico"
    Bleu     = "GameDraw_icon_bleu.ico"
    Sombre   = "GameDraw_icon_sombre.ico"
}
$choix = "Original"
if (Test-Path $configFile) {
    try {
        $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($cfg.IconeApp -and $iconChoices.ContainsKey($cfg.IconeApp)) { $choix = $cfg.IconeApp }
    } catch { }
}
$iconPath     = Join-Path $root ("assets\" + $iconChoices[$choix])
$desktop      = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktop "GameDraw.lnk"

if (-not (Test-Path $ps1Path)) {
    Write-Host "Erreur : Tirage-Jeux.ps1 introuvable a $ps1Path" -ForegroundColor Red
    exit 1
}

$psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $psExe)) { $psExe = "powershell.exe" }

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath       = $psExe
$Shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1Path`""
$Shortcut.WorkingDirectory = Split-Path -Parent $ps1Path
if (Test-Path $iconPath) { $Shortcut.IconLocation = "$iconPath,0" }
$Shortcut.Description      = "Tirage au sort de jeux video Switch / PC"
$Shortcut.WindowStyle      = 7
$Shortcut.Save()

# Patch le flag "Executer en tant qu'administrateur" directement dans le .lnk
# (offset 0x15, bit 0x20) : evite d'avoir a cocher la case manuellement dans
# Proprietes > Avance, et evite tout script .bat/.vbs intermediaire.
try {
    $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
} catch {
    Write-Host "Avertissement : n'a pas pu definir l'elevation automatique sur le raccourci." -ForegroundColor Yellow
}

Write-Host "Raccourci cree sur le Bureau : $shortcutPath" -ForegroundColor Green
Write-Host "Double-clic = demande d'elevation UAC directe, sans fenetre de console." -ForegroundColor Cyan
