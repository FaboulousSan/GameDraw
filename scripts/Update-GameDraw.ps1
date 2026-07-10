<#
.SYNOPSIS
    Met a jour GameDraw a partir d'un nouveau .zip ou dossier telecharge,
    sans jamais toucher aux donnees utilisateur.
.DESCRIPTION
    Les donnees (bibliotheques de jeux, historique, plateformes, config,
    catalogues) vivent dans le dossier de donnees choisi par l'utilisateur (Options ->
.   Emplacement des donnees ; par defaut %LOCALAPPDATA%\GameDraw) et ne sont JAMAIS dans le
    dossier d'installation. Ce script ne copie donc que le code et les
    ressources (scripts\, assets\, docs\, Launcher.bat) par-dessus
    l'installation actuelle. Aucune donnee de jeu n'est jamais supprimee ou
    modifiee par cette operation.
.PARAMETER Source
    Chemin vers le nouveau .zip telecharge, OU vers le dossier
    "GameDraw_Package" deja extrait.
.EXAMPLE
    .\Update-GameDraw.ps1 -Source "C:\Users\moi\Downloads\GameDraw_Package_v21.zip"
.EXAMPLE
    .\Update-GameDraw.ps1 -Source "C:\Users\moi\Downloads\GameDraw_Package_v21\GameDraw_Package"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Source
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# Dossier d'installation actuel = parent de scripts\ (ce script vit dans scripts\)
$installDir = Split-Path -Parent $PSScriptRoot
Write-Host "Installation actuelle : $installDir" -ForegroundColor Cyan

if (-not (Test-Path $Source)) {
    Write-Host "Introuvable : $Source" -ForegroundColor Red
    exit 1
}

$tempExtract = $null
$sourceDir = $Source

# Si un .zip est fourni, on l'extrait dans un dossier temporaire
if ((Get-Item $Source).PSIsContainer -eq $false -and $Source -match '\.zip$') {
    $tempExtract = Join-Path $env:TEMP "GameDraw_Update_$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Path $tempExtract -Force | Out-Null
    Write-Host "Extraction de l'archive..." -ForegroundColor Cyan
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Source, $tempExtract)
    $sourceDir = $tempExtract
}

# Le zip peut contenir directement scripts\/assets\, ou un sous-dossier
# "GameDraw_Package" qui les contient - on detecte automatiquement.
if (-not (Test-Path (Join-Path $sourceDir "scripts"))) {
    $sousDossier = Get-ChildItem -Path $sourceDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "scripts")
    } | Select-Object -First 1
    if ($sousDossier) { $sourceDir = $sousDossier.FullName }
}

if (-not (Test-Path (Join-Path $sourceDir "scripts"))) {
    Write-Host "Structure invalide : dossier 'scripts' introuvable dans la source." -ForegroundColor Red
    if ($tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    exit 1
}

Write-Host "Source detectee : $sourceDir" -ForegroundColor Cyan

# Sauvegarde de securite de l'installation actuelle avant ecrasement
$backupDir = Join-Path $env:TEMP "GameDraw_AvantMAJ_$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "Sauvegarde de securite de l'installation actuelle -> $backupDir" -ForegroundColor Yellow
Copy-Item -Path $installDir -Destination $backupDir -Recurse -Force

# Copie du nouveau code par-dessus l'installation (jamais les donnees, qui ne
# sont de toute facon pas dans ce dossier).
foreach ($item in @("scripts", "assets", "docs", "Launcher.bat")) {
    $src = Join-Path $sourceDir $item
    if (Test-Path $src) {
        Write-Host "Mise a jour de $item..." -ForegroundColor Cyan
        Copy-Item -Path $src -Destination $installDir -Recurse -Force
    }
}

if ($tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "Mise a jour terminee." -ForegroundColor Green
Write-Host "Sauvegarde de l'ancienne version conservee dans : $backupDir" -ForegroundColor Green
Write-Host "Tes donnees (jeux, historique, config) n'ont pas ete touchees (voir Options -> Emplacement des donnees pour savoir ou elles vivent)." -ForegroundColor Green
