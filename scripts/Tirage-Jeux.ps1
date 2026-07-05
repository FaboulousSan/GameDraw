<#
.SYNOPSIS
    GameDraw v5 - Tirage au sort de jeux video multi-plateformes.
.DESCRIPTION
    Plateformes editables (ajout/suppression/activation), contraste corrige partout,
    effet de surbrillance (glow) sur le bouton principal, icone nette.
    v5 : correction des etoiles en or (5/5), correction du changement de theme,
    gestion d'erreurs avec journalisation (le lanceur masque la console).
#>

# =========================================================================
# Sensibilite DPI (corrige le flou general de l'interface, icone comprise,
# sur les ecrans avec mise a l'echelle >100% : powershell.exe n'est pas
# "DPI aware" par defaut, Windows redimensionne alors toute la fenetre en
# bitmap -> rendu flou. On force ici la sensibilite DPI par moniteur (V2).
# Doit s'executer avant toute creation de fenetre/UI.
# =========================================================================
try {
    Add-Type -Name NativeDpi -Namespace GameDraw -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
"@ -ErrorAction Stop
    # -4 = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 (Windows 10 1703+)
    $dpiOk = [GameDraw.NativeDpi]::SetProcessDpiAwarenessContext([IntPtr]::new(-4))
    if (-not $dpiOk) { [GameDraw.NativeDpi]::SetProcessDPIAware() | Out-Null }
} catch { }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

$script:gdVersion = "Beta 0.2"


# =========================================================================
# Journalisation des erreurs (le lancement via le raccourci masque toute fenetre,
# donc toute exception silencieuse rendait l'app "figee" sans aucun message).
# =========================================================================
$script:logFile = Join-Path (Join-Path $env:USERPROFILE "GameDraw") "error.log"

function Write-GDLog([string]$message) {
    try {
        $dir = Split-Path -Parent $script:logFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $message" | Add-Content -Path $script:logFile -Encoding UTF8
    } catch { }
}

function Invoke-Safe([scriptblock]$Action, [string]$Contexte) {
    try {
        & $Action
    } catch {
        Write-GDLog "ERREUR [$Contexte] : $($_.Exception.Message)`n$($_.ScriptStackTrace)"
        [System.Windows.MessageBox]::Show(
            "Une erreur est survenue ($Contexte) :`n$($_.Exception.Message)`n`nDetails enregistres dans :`n$script:logFile",
            "GameDraw - Erreur", 'OK', 'Error') | Out-Null
    }
}

# Convertit une couleur hexadecimale en Brush WPF reel (evite toute ambiguite
# de conversion implicite d'une chaine liee via {Binding} dans un DataTemplate).
function ConvertTo-GDBrush([string]$hex) {
    try {
        $bc = New-Object System.Windows.Media.BrushConverter
        $brush = $bc.ConvertFromString($hex)
        $brush.Freeze()
        return $brush
    } catch {
        return [System.Windows.Media.Brushes]::White
    }
}

$root         = Join-Path $env:USERPROFILE "GameDraw"
$platformFile = Join-Path $root "platforms.json"
$histFile     = Join-Path $root "historique.json"
if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root | Out-Null }

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = Split-Path -Parent $scriptRoot
$logoPath    = Join-Path $packageRoot "assets\GameDraw_logo.png"
$logoUri     = ([Uri]$logoPath).AbsoluteUri

# Icones d'application disponibles (fichier .ico + apercu .png pour le picker
# dans Options). "Original" = icone historique du projet. La config n'existe
# pas encore a ce stade du script (Get-GDConfig est definie plus bas) : on se
# contente ici de preparer les donnees et une valeur par defaut ; le calcul
# reel se fait via Update-IconUri, appelee juste avant l'affichage de chaque
# fenetre (boucle de rechargement).
$script:iconChoices = @{
    Original = @{ Nom = "Original";        Ico = "GameDraw_v2.ico";           Preview = "GameDraw_v2.ico" }
    Bleu     = @{ Nom = "Bleu (carnet)";    Ico = "GameDraw_icon_bleu.ico";    Preview = "GameDraw_icon_bleu_preview.png" }
    Sombre   = @{ Nom = "Sombre (neon)";    Ico = "GameDraw_icon_sombre.ico";  Preview = "GameDraw_icon_sombre_preview.png" }
}
$iconPath = Join-Path $packageRoot ("assets\" + $script:iconChoices["Original"].Ico)
$iconUri  = ([Uri]$iconPath).AbsoluteUri
function Update-IconUri {
    $choix = (Get-GDConfig).IconeApp
    if (-not $choix -or -not $script:iconChoices.ContainsKey($choix)) { $choix = "Original" }
    $script:iconPath = Join-Path $packageRoot ("assets\" + $script:iconChoices[$choix].Ico)
    $script:iconUri  = ([Uri]$script:iconPath).AbsoluteUri
}

# Cree un raccourci Bureau qui cible PowerShell directement (pas de .bat, pas
# de .vbs) avec une fenetre cachee, puis patche l'octet de flag "Executer en
# tant qu'administrateur" directement dans le fichier .lnk (technique
# standard : offset 0x15, bit 0x20). Resultat : un double-clic declenche
# l'UAC directement, sans double lancement de console ni script intermediaire.
function New-GDShortcut([string]$ps1Path, [string]$shortcutPath, [string]$iconFile) {
    $psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path $psExe)) { $psExe = "powershell.exe" }

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath       = $psExe
    $Shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1Path`""
    $Shortcut.WorkingDirectory = Split-Path -Parent $ps1Path
    if ($iconFile -and (Test-Path $iconFile)) { $Shortcut.IconLocation = "$iconFile,0" }
    $Shortcut.Description      = "Tirage au sort de jeux video"
    $Shortcut.WindowStyle      = 7
    $Shortcut.Save()

    try {
        $bytes = [System.IO.File]::ReadAllBytes($shortcutPath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20
        [System.IO.File]::WriteAllBytes($shortcutPath, $bytes)
    } catch {
        Write-GDLog "AVERTISSEMENT : impossible de definir 'Executer en tant qu'administrateur' sur le raccourci ($($_.Exception.Message)). Le raccourci fonctionne quand meme, mais demandera l'elevation via Launcher.bat si necessaire."
    }
}

function Init-JsonFile {
    param($Path, $Default)
    if (-not (Test-Path $Path)) { $Default | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8 }
}

Init-JsonFile -Path $platformFile -Default @(
    @{ Nom = "Switch"; Actif = $true;  Fichier = "switch_games.json" },
    @{ Nom = "PC";     Actif = $true;  Fichier = "pc_games.json" }
)
Init-JsonFile -Path $histFile -Default @()

function Load-Json($path) {
    $raw = Get-Content $path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $obj = $raw | ConvertFrom-Json
    return @($obj)
}
function Save-Json($path, $data) {
    $arr = @($data)
    if ($arr.Count -eq 0) {
        "[]" | Set-Content -Path $path -Encoding UTF8
        return
    }
    if ($arr.Count -eq 1) {
        $json = "[" + ($arr[0] | ConvertTo-Json -Depth 5 -Compress) + "]"
    } else {
        $json = $arr | ConvertTo-Json -Depth 5
    }
    $json | Set-Content -Path $path -Encoding UTF8
}


function Force-VerticalListBox($listBox) {
    $factory = New-Object System.Windows.FrameworkElementFactory ([System.Windows.Controls.StackPanel])
    $factory.SetValue([System.Windows.Controls.StackPanel]::OrientationProperty, [System.Windows.Controls.Orientation]::Vertical)
    $template = New-Object System.Windows.Controls.ItemsPanelTemplate
    $template.VisualTree = $factory
    $listBox.ItemsPanel = $template
    $listBox.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Stretch
}

function Ensure-GameFields($g) {
    if (-not (Get-Member -InputObject $g -Name "Note" -MemberType NoteProperty)) {
        $g | Add-Member -MemberType NoteProperty -Name "Note" -Value 0 -Force
    }
    if (-not (Get-Member -InputObject $g -Name "Refaire" -MemberType NoteProperty)) {
        $g | Add-Member -MemberType NoteProperty -Name "Refaire" -Value $false -Force
    }
    foreach ($champ in @("Cover", "Logo", "Screenshot", "Icone", "Commentaire")) {
        if (-not (Get-Member -InputObject $g -Name $champ -MemberType NoteProperty)) {
            $g | Add-Member -MemberType NoteProperty -Name $champ -Value "" -Force
        }
    }
    return $g
}

# Dossier des images par jeu : %USERPROFILE%\GameDraw\images\<plateforme>\<jeu>\<slot>.<ext>
function Get-GameImageFolder([string]$platformName, [string]$gameName) {
    $platDir = Join-Path $root "images"
    $platDir = Join-Path $platDir ($platformName -replace '[^a-zA-Z0-9_\-]', '_')
    $gameDir = Join-Path $platDir ($gameName -replace '[^a-zA-Z0-9_\-]', '_')
    if (-not (Test-Path $gameDir)) { New-Item -ItemType Directory -Path $gameDir -Force | Out-Null }
    return $gameDir
}

# Copie le fichier choisi par l'utilisateur dans le dossier d'images de l'app
# (plutot que de garder un chemin externe, qui casserait si le fichier source
# est deplace/supprime, et serait absent des sauvegardes .zip).
function Save-GameImage([string]$platformName, [string]$gameName, [string]$slot, [string]$sourcePath) {
    $dir = Get-GameImageFolder $platformName $gameName
    $ext = [System.IO.Path]::GetExtension($sourcePath)
    $dest = Join-Path $dir "$slot$ext"
    Copy-Item -Path $sourcePath -Destination $dest -Force
    return $dest
}

function Get-Platforms { @(Load-Json $platformFile) }
function Save-Platforms($p) { Save-Json $platformFile $p }

function Get-GameFile($platformName) {
    $plats = Get-Platforms
    $p = $plats | Where-Object { $_.Nom -eq $platformName }
    if (-not $p) { return $null }
    $path = Join-Path $root $p.Fichier
    Init-JsonFile -Path $path -Default @()
    return $path
}

function Sanitize-FileName($name) {
    $clean = ($name -replace '[^a-zA-Z0-9_\-]', '_').ToLower()
    return "$clean`_games.json"
}

# =========================================================================
# Themes visuels
# =========================================================================
$configFile = Join-Path $root "config.json"
Init-JsonFile -Path $configFile -Default @{ Theme = "Catppuccin"; CouleurEtoiles = "#FFD700"; IconeNotation = "Etoile" }
$catalogueFile = Join-Path $root "catalogues.json"

$themes = @{
    "Catppuccin" = @{
        ACCENT  = "#89B4FA"; SUCCESS = "#A6E3A1"; BG = "#181825"; CARD = "#1E1E2E"
        INPUT   = "#313244"; BORDER  = "#45475A"; DARKBG = "#11111B"; MUTED = "#BAC2DE"
        DANGER  = "#F38BA8"; WARNING = "#F9E2AF"
    }
    # Ocarina of Time : bois/cuir du menu (bruns), or de la Triforce et des
    # rubis, vert Kokiri pour la magie/succes, bleu Navi/Zora en accent info,
    # rouge pour le danger (coeurs).
    "Ocarina" = @{
        ACCENT  = "#D4AF37"; SUCCESS = "#4C8C4A"; BG = "#1B1710"; CARD = "#2B2418"
        INPUT   = "#3A2F1D"; BORDER  = "#5C4A2A"; DARKBG = "#100D08"; MUTED = "#C9B896"
        DANGER  = "#8B2E2E"; WARNING = "#5FA8D3"
    }
    "Cyberpunk" = @{
        ACCENT  = "#FF2E63"; SUCCESS = "#08D9D6"; BG = "#0A0A0F"; CARD = "#151521"
        INPUT   = "#1F1F2E"; BORDER  = "#3A3A55"; DARKBG = "#05050A"; MUTED = "#A9A9C2"
        DANGER  = "#FF2E63"; WARNING = "#FFD23F"
    }
    "Foret" = @{
        ACCENT  = "#57A773"; SUCCESS = "#A3D9A5"; BG = "#132A1E"; CARD = "#1C3B29"
        INPUT   = "#254A34"; BORDER  = "#3A6B4C"; DARKBG = "#0D1F16"; MUTED = "#C7DCC9"
        DANGER  = "#D9534F"; WARNING = "#E0C05C"
    }
    # Dracula : palette officielle, tres appreciee des devs
    "Dracula" = @{
        ACCENT  = "#BD93F9"; SUCCESS = "#50FA7B"; BG = "#282A36"; CARD = "#343746"
        INPUT   = "#3B3F51"; BORDER  = "#44475A"; DARKBG = "#191A21"; MUTED = "#F8F8F2"
        DANGER  = "#FF5555"; WARNING = "#F1FA8C"
    }
    # Pip-Boy (Fallout) : terminal phosphore vert monochrome
    "PipBoy" = @{
        ACCENT  = "#41FF00"; SUCCESS = "#7CFF3D"; BG = "#0A0F0A"; CARD = "#111C11"
        INPUT   = "#16260F"; BORDER  = "#2E4A1E"; DARKBG = "#050805"; MUTED = "#8FCB6B"
        DANGER  = "#FF3B30"; WARNING = "#FFD500"
    }
    # Super Mario : le vrai duo iconique bleu salopette + rouge (chemise/casquette),
    # vert Luigi/tuyau en succes, orange Bowser en danger, or des pieces en warning
    "Mario" = @{
        ACCENT  = "#E52521"; SUCCESS = "#43B047"; BG = "#0F2A66"; CARD = "#1B3B85"
        INPUT   = "#25499C"; BORDER  = "#3A63BF"; DARKBG = "#081736"; MUTED = "#CFE0FF"
        DANGER  = "#F26522"; WARNING = "#FBD000"
    }
    # Dragon : antre obscur, ecailles, feu et tresor
    "Dragon" = @{
        ACCENT  = "#FF6B1A"; SUCCESS = "#2E8B57"; BG = "#160B0B"; CARD = "#241212"
        INPUT   = "#341818"; BORDER  = "#5C2626"; DARKBG = "#0D0606"; MUTED = "#D9B08C"
        DANGER  = "#C0392B"; WARNING = "#FFB627"
    }
}
$script:themeOrder = @("Catppuccin", "Ocarina", "Cyberpunk", "Foret", "Dracula", "PipBoy", "Mario", "Dragon")
$script:themeLabels = @{
    Catppuccin = "Catppuccin"
    Ocarina    = "Ocarina of Time"
    Cyberpunk  = "Cyberpunk"
    Foret      = "Foret"
    Dracula    = "Dracula"
    PipBoy     = "Pip-Boy"
    Mario      = "Super Mario"
    Dragon     = "Dragon"
}

$script:gdConfigDefaults = @{
    Theme                  = "Catppuccin"
    CouleurEtoiles         = "#FFD700"
    IconeNotation          = "Etoile"
    Densite                = "Confortable"
    HistoriqueCount        = 15
    AnimationTirage        = $true
    EviterRepetitionDefaut = $true
    ObjectifDefaut         = ""
    IconeApp               = "Original"
}

function Get-GDConfig {
    try {
        if (Test-Path $configFile) {
            $raw = Get-Content -Path $configFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $obj = $raw | ConvertFrom-Json
                # Compatibilite avec un ancien fichier stocke sous forme de tableau
                if ($obj -is [System.Array]) { $obj = $obj[0] }
                if ($obj -and $obj.Theme -and $obj.CouleurEtoiles) {
                    # Complete les champs manquants (versions anterieures) avec les
                    # valeurs par defaut, sans jamais ecraser ce qui existe deja.
                    foreach ($k in $script:gdConfigDefaults.Keys) {
                        if (-not $obj.PSObject.Properties[$k]) {
                            $obj | Add-Member -NotePropertyName $k -NotePropertyValue $script:gdConfigDefaults[$k] -Force
                        }
                    }
                    return $obj
                }
            }
        }
    } catch {
        Write-GDLog "ERREUR lecture config.json : $($_.Exception.Message)"
    }
    return [pscustomobject]$script:gdConfigDefaults
}

# Fusionne uniquement les champs fournis dans $changes avec la config actuelle,
# puis sauvegarde le tout. Permet d'ajouter de nouveaux reglages sans jamais
# devoir retoucher la signature de cette fonction ni les appels existants.
function Set-GDConfig([hashtable]$changes) {
    try {
        $c = Get-GDConfig
        foreach ($k in $changes.Keys) {
            $c | Add-Member -NotePropertyName $k -NotePropertyValue $changes[$k] -Force
        }
        $json = $c | ConvertTo-Json -Depth 5
        Set-Content -Path $configFile -Value $json -Encoding UTF8 -Force
        # Verification immediate : on relit ce qu'on vient d'ecrire pour tracer
        # tout probleme de persistance directement dans le journal.
        $verif = Get-GDConfig
        Write-GDLog "Config ecrite -> $($changes.Keys -join ', ') / relue immediatement -> Theme=$($verif.Theme) Icone=$($verif.IconeNotation) Densite=$($verif.Densite)"
    } catch {
        Write-GDLog "ERREUR ecriture config.json : $($_.Exception.Message)"
    }
}

function Get-CurrentThemeName { return (Get-GDConfig).Theme }
function Get-StarColor        { return (Get-GDConfig).CouleurEtoiles }
function Get-RatingIconName   { return (Get-GDConfig).IconeNotation }
function Get-Densite          { return (Get-GDConfig).Densite }
function Get-HistoriqueCount  { $n = (Get-GDConfig).HistoriqueCount; if (-not $n -or $n -lt 1) { return 15 }; return [int]$n }
function Convert-ToGDBool($v) {
    if ($v -is [string]) { return ($v -eq 'true') }
    return [bool]$v
}
function Get-AnimationTirage  { return Convert-ToGDBool (Get-GDConfig).AnimationTirage }
function Get-EviterRepetitionDefaut { return Convert-ToGDBool (Get-GDConfig).EviterRepetitionDefaut }
function Get-ObjectifDefaut   { return (Get-GDConfig).ObjectifDefaut }
function Get-IconApp          { $v = (Get-GDConfig).IconeApp; if (-not $v -or -not $script:iconChoices.ContainsKey($v)) { return "Original" }; return $v }
function Save-IconApp([string]$choix) { Set-GDConfig @{ IconeApp = $choix } }
function Save-ThemeName([string]$name)      { Set-GDConfig @{ Theme = $name } }
function Save-StarColor([string]$hex)       { Set-GDConfig @{ CouleurEtoiles = $hex } }
function Save-RatingIconName([string]$name) { Set-GDConfig @{ IconeNotation = $name } }


# Jeux de caracteres disponibles pour representer la notation (rempli / vide).
# On passe par ConvertFromUtf32 pour les emoji hors du plan de base (surrogate
# pairs), plus fiable qu'un simple cast [char] qui echoue au-dela de U+FFFF.
function Get-RatingIconSet([string]$name) {
    switch ($name) {
        "Coeur"   { return @{ Nom = "Coeur";   Filled = [string][char]0x2764; Empty = [string][char]0x2661 } }
        "Pouce"   { return @{ Nom = "Pouce";   Filled = [System.Char]::ConvertFromUtf32(0x1F44D); Empty = [string][char]0x25CB } }
        "Trophee" { return @{ Nom = "Trophee"; Filled = [System.Char]::ConvertFromUtf32(0x1F3C6); Empty = [string][char]0x25CB } }
        "Diamant" { return @{ Nom = "Diamant"; Filled = [System.Char]::ConvertFromUtf32(0x1F48E); Empty = [string][char]0x25C7 } }
        default   { return @{ Nom = "Etoile";  Filled = [string][char]0x2605; Empty = [string][char]0x2606 } }
    }
}
$script:ratingIconOrder = @("Etoile", "Coeur", "Pouce", "Trophee", "Diamant")

# Listes indicatives (non exhaustives) utilisees pour initialiser catalogues.json
# la premiere fois. Elles sont ensuite entierement editables par l'utilisateur
# (ajout/suppression) et persistees dans ce fichier.
$script:catalogueKeys = @("Switch1", "Switch2", "PC")
$script:catalogueLabels = @{
    Switch1 = "Nintendo Switch (1)"
    Switch2 = "Nintendo Switch 2"
    PC      = "PC"
}
$script:catalogueDefaults = @{
    Switch1 = @(
        "The Legend of Zelda: Breath of the Wild"
        "The Legend of Zelda: Tears of the Kingdom"
        "Super Mario Odyssey"
        "Super Mario Bros. Wonder"
        "Super Mario Party Jamboree"
        "Mario Kart 8 Deluxe"
        "Super Smash Bros. Ultimate"
        "Animal Crossing: New Horizons"
        "Splatoon 2"
        "Splatoon 3"
        "Pokemon Epee / Bouclier"
        "Pokemon Ecarlate / Violet"
        "Pokemon Legends: Arceus"
        "Metroid Dread"
        "Metroid Prime Remastered"
        "Fire Emblem: Three Houses"
        "Fire Emblem Engage"
        "Xenoblade Chronicles 3"
        "Kirby et le Monde Oublie"
        "Luigi's Mansion 3"
        "Super Mario Maker 2"
        "Ring Fit Adventure"
        "Bayonetta 3"
        "Pikmin 4"
        "Donkey Kong Country: Tropical Freeze"
        "Mario Party Superstars"
        "1-2-Switch"
        "Astral Chain"
        "Captain Toad: Treasure Tracker"
    )
    Switch2 = @(
        "Mario Kart World"
        "Donkey Kong Bananza"
        "Kirby Air Riders"
        "Hyrule Warriors: Age of Imprisonment"
        "The Legend of Zelda: Breath of the Wild - Switch 2 Edition"
        "The Legend of Zelda: Tears of the Kingdom - Switch 2 Edition"
        "Super Mario Party Jamboree - Switch 2 Edition"
        "Super Mario Bros. Wonder - Switch 2 Edition"
        "Fast Fusion"
        "Nintendo Switch 2 Welcome Tour"
        "Cyberpunk 2077 (Switch 2)"
        "Hogwarts Legacy (Switch 2)"
        "ELDEN RING Tarnished Edition"
        "Metroid Prime 4: Beyond"
        "Pokemon Champions"
        "Professeur Layton et le Nouveau Monde a Vapeur"
        "The Duskbloods"
        "Fire Emblem: Fortune's Weave"
        "Yoshi and the Mysterious Book"
        "Monster Hunter Stories 3: Twisted Reflection"
    )
    PC = @(
        "The Witcher 3: Wild Hunt"
        "Baldur's Gate 3"
        "Elden Ring"
        "Cyberpunk 2077"
        "Half-Life 2"
        "Portal 2"
        "Counter-Strike 2"
        "Dota 2"
        "League of Legends"
        "Valorant"
        "Stardew Valley"
        "Hades"
        "Hollow Knight"
        "Terraria"
        "Minecraft"
        "Factorio"
        "Cities: Skylines"
        "Civilization VI"
        "Divinity: Original Sin 2"
        "Disco Elysium"
        "Red Dead Redemption 2"
        "Grand Theft Auto V"
        "DOOM Eternal"
        "The Elder Scrolls V: Skyrim"
        "World of Warcraft"
        "StarCraft II"
        "Overwatch 2"
        "Apex Legends"
        "Rocket League"
        "It Takes Two"
    )
}

function Get-Catalogues {
    try {
        if (Test-Path $catalogueFile) {
            $raw = Get-Content -Path $catalogueFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $obj = $raw | ConvertFrom-Json
                foreach ($k in $script:catalogueKeys) {
                    if (-not $obj.PSObject.Properties[$k]) {
                        $obj | Add-Member -NotePropertyName $k -NotePropertyValue @($script:catalogueDefaults[$k]) -Force
                    }
                }
                return $obj
            }
        }
    } catch {
        Write-GDLog "ERREUR lecture catalogues.json : $($_.Exception.Message)"
    }
    $default = [pscustomobject]@{}
    foreach ($k in $script:catalogueKeys) { $default | Add-Member -NotePropertyName $k -NotePropertyValue @($script:catalogueDefaults[$k]) }
    return $default
}

function Save-Catalogues($obj) {
    try {
        $json = $obj | ConvertTo-Json -Depth 5
        Set-Content -Path $catalogueFile -Value $json -Encoding UTF8 -Force
    } catch {
        Write-GDLog "ERREUR ecriture catalogues.json : $($_.Exception.Message)"
    }
}

function Get-CatalogueListe([string]$key) {
    $c = Get-Catalogues
    return @($c.$key)
}

function Add-CatalogueItem([string]$key, [string]$nom) {
    $c = Get-Catalogues
    $liste = @($c.$key)
    if ($liste -notcontains $nom) {
        $liste += $nom
        $c.$key = $liste
        Save-Catalogues $c
    }
}

function Remove-CatalogueItem([string]$key, [string]$nom) {
    $c = Get-Catalogues
    $liste = @($c.$key | Where-Object { $_ -ne $nom })
    $c.$key = $liste
    Save-Catalogues $c
}

if (-not (Test-Path $catalogueFile)) {
    $init = [pscustomobject]@{}
    foreach ($k in $script:catalogueKeys) { $init | Add-Member -NotePropertyName $k -NotePropertyValue @($script:catalogueDefaults[$k]) }
    Save-Catalogues $init
}

function Apply-Theme([string]$xamlText, [string]$themeName) {
    $t = $themes[$themeName]
    if (-not $t) { $t = $themes["Catppuccin"] }
    $result = $xamlText
    foreach ($key in $t.Keys) {
        $result = $result.Replace("{{$key}}", $t[$key])
    }
    return $result
}

$script:currentTheme = Get-CurrentThemeName
$script:starGoldColor = Get-StarColor

function Show-MainWindow {
# =========================================================================
# XAML principal
# =========================================================================
$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GameDraw - Theme : $script:currentTheme" Height="740" Width="1000" MinHeight="600" MinWidth="860"
        Icon="$iconUri"
        WindowStartupLocation="CenterScreen"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>

        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="{{CARD}}"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="18"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="#000000" BlurRadius="18" ShadowDepth="4" Direction="270" Opacity="0.28"/>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.85"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
        </Style>

        <!-- Bouton principal avec effet glow (DropShadow etendu, non attenue) -->
        <Style x:Key="GlowButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="{{ACCENT}}" BlurRadius="28" ShadowDepth="0" Opacity="0.9"/>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Effect">
                        <Setter.Value>
                            <DropShadowEffect Color="{{SUCCESS}}" BlurRadius="40" ShadowDepth="0" Opacity="1"/>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="Label">
            <Setter Property="Foreground" Value="{{MUTED}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

        <Style x:Key="ComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{{BORDER}}"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyle}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleBtn" Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="24"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="#FFFFFF"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="{{INPUT}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{{DARKBG}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
            <Setter Property="ItemTemplate">
                <Setter.Value>
                    <DataTemplate>
                        <TextBlock Text="{Binding}" Foreground="#FFFFFF" FontWeight="SemiBold" FontSize="13" TextWrapping="Wrap"/>
                    </DataTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="ItemsPanel">
                <Setter.Value>
                    <ItemsPanelTemplate>
                        <StackPanel Orientation="Vertical"/>
                    </ItemsPanelTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Cle explicite avec Foreground FORCE blanc + template complet pour eviter tout heritage de couleur claire -->
        <Style x:Key="ListBoxItemStyle" TargetType="ListBoxItem">
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,2">
                            <ContentPresenter TextBlock.Foreground="#FFFFFF" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{BORDER}}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ListBoxItem" BasedOn="{StaticResource ListBoxItemStyle}"/>
    </Window.Resources>

    <Grid Margin="24">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0" Margin="0,0,0,20">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal">
                <Image Source="$logoUri" Width="40" Height="40" Margin="0,0,12,0" RenderOptions.BitmapScalingMode="HighQuality" Stretch="Uniform" UseLayoutRounding="True" SnapsToDevicePixels="True"/>
                <TextBlock Text="GameDraw" FontSize="28" FontWeight="Bold" Foreground="{{ACCENT}}" VerticalAlignment="Center"/>
            </StackPanel>
            <Button Grid.Column="1" Name="btnTheme" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0" Padding="10,8" Width="44" ToolTip="Changer de theme">
                <TextBlock Text="&#xE790;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"/>
            </Button>
            <Button Grid.Column="2" Name="btnOptions" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0" Padding="10,8" Width="44" ToolTip="Options">
                <TextBlock Text="&#xE713;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"/>
            </Button>
            <Button Grid.Column="3" Name="btnStats" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0" ToolTip="Voir les statistiques">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE9D2;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" VerticalAlignment="Center"/>
                    <TextBlock Text=" Statistiques" VerticalAlignment="Center" Margin="6,0,0,0"/>
                </StackPanel>
            </Button>
            <Button Grid.Column="4" Name="btnBacklog" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0" ToolTip="Voir le backlog (bibliotheque complete)">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE8F1;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" VerticalAlignment="Center"/>
                    <TextBlock Text=" Backlog" VerticalAlignment="Center" Margin="6,0,0,0"/>
                </StackPanel>
            </Button>
            <Button Grid.Column="5" Name="btnGererPlateformes" Content="Gerer les plateformes" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
            <Button Grid.Column="6" Name="btnGererJeux" Content="Gerer les jeux" Style="{StaticResource SecondaryButton}"/>

            <!-- Popup reel (et non un panneau dans la grille) : il flotte par-dessus
                 la fenetre sans jamais influencer la largeur des colonnes voisines. -->
            <Popup Name="popupTheme" PlacementTarget="{Binding ElementName=btnTheme}" Placement="Bottom"
                   StaysOpen="False" AllowsTransparency="True" PopupAnimation="Fade">
                <Border Width="230" Margin="0,4,0,0"
                        Background="{{CARD}}" BorderBrush="{{ACCENT}}" BorderThickness="1" CornerRadius="12" Padding="10">
                    <Border.Effect>
                        <DropShadowEffect Color="#000000" BlurRadius="22" ShadowDepth="4" Opacity="0.55"/>
                    </Border.Effect>
                    <StackPanel>
                        <TextBlock Text="CHOISIR UN THEME" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="4,0,0,8"/>
                        <StackPanel Name="stackThemeList"/>
                    </StackPanel>
                </Border>
            </Popup>
        </Grid>



        <Border Grid.Row="1" Style="{StaticResource CardStyle}">
            <StackPanel>
                <TextBlock Text="PARAMETRES DU TIRAGE" Foreground="#FFFFFF" FontWeight="Bold" FontSize="14" Margin="0,0,0,14"/>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <StackPanel Grid.Column="0" Margin="0,0,10,0">
                        <Label Content="PLATEFORME"/>
                        <ComboBox Name="cmbPlatform" Height="38"/>
                    </StackPanel>

                    <StackPanel Grid.Column="1" Margin="0,0,10,0">
                        <Label Content="LIMITER LE TEMPS"/>
                        <CheckBox Name="chkLimiterTemps" Content="Activer une duree" IsChecked="True" VerticalAlignment="Center" Margin="4,10,0,0"/>
                    </StackPanel>

                    <StackPanel Grid.Column="2" Margin="0,0,10,0">
                        <Label Content="DUREE"/>
                        <StackPanel Orientation="Horizontal">
                            <TextBox Name="txtDuree" Width="55" Height="38" Text="1"/>
                            <ComboBox Name="cmbUnite" Width="120" Height="38" Margin="6,0,0,0">
                                <ComboBoxItem Content="Heures"/>
                                <ComboBoxItem Content="Jours" IsSelected="True"/>
                                <ComboBoxItem Content="Semaines"/>
                            </ComboBox>
                        </StackPanel>
                    </StackPanel>

                    <StackPanel Grid.Column="3">
                        <Label Content="MODE DE FIN VISE"/>
                        <ComboBox Name="cmbObjectif" Height="38">
                            <ComboBoxItem Content="Terminer l'histoire" IsSelected="True"/>
                            <ComboBoxItem Content="Finir a 100%"/>
                            <ComboBoxItem Content="Libre (sans objectif precis)"/>
                        </ComboBox>
                    </StackPanel>
                </Grid>
                <CheckBox Name="chkEviterRepetition" Content="Eviter les repetitions (roulement equitable)" IsChecked="True" Margin="0,16,0,0"/>
            </StackPanel>
        </Border>

        <Grid Grid.Row="2" Name="gridResultatHistorique">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="1.2*"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Border Grid.Column="0" Name="cardResultat" Style="{StaticResource CardStyle}">
                <Grid>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="RESULTAT DU TIRAGE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center"/>
                        <Image Name="imgCoverResultat" Height="140" Stretch="Uniform" Margin="0,12,0,0" Visibility="Collapsed"/>
                        <TextBlock Name="lblJeuTire" Text="Aucun tirage" FontSize="26" FontWeight="Bold" Foreground="{{SUCCESS}}"
                                   TextWrapping="Wrap" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,14,0,6"
                                   RenderTransformOrigin="0.5,0.5">
                            <TextBlock.RenderTransform>
                                <ScaleTransform x:Name="lblJeuTireScale" ScaleX="1" ScaleY="1"/>
                            </TextBlock.RenderTransform>
                        </TextBlock>
                        <TextBlock Name="lblObjectif" Text="" FontSize="13" FontWeight="Bold" Foreground="{{WARNING}}" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                        <TextBlock Name="lblFin" Text="" FontSize="13" Foreground="#FFFFFF" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
                        <TextBlock Name="lblPool" Text="" FontSize="11" Foreground="{{MUTED}}" HorizontalAlignment="Center" Margin="0,10,0,2"/>
                        <ProgressBar Name="prgPool" Height="8" Minimum="0" Maximum="100" Value="0" Margin="0,0,0,0"
                                     Background="{{INPUT}}" Foreground="{{ACCENT}}" BorderThickness="0"/>
                        <Button Name="btnTirer" Content="LANCER LE TIRAGE" Style="{StaticResource GlowButton}" FontSize="15" Margin="0,24,0,10" Padding="14,12"/>
                        <Button Name="btnTerminer" Content="Marquer comme termine" Style="{StaticResource SecondaryButton}"/>
                    </StackPanel>
                    <Canvas Name="canvasConfetti" IsHitTestVisible="False" ClipToBounds="True"/>
                </Grid>
            </Border>

            <Border Grid.Column="2" Name="cardHistorique" Style="{StaticResource CardStyle}">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Text="HISTORIQUE DES TIRAGES" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,10"/>
                    <ListBox Grid.Row="1" Name="lstHistorique"/>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="2" Text="$script:gdVersion" Foreground="{{MUTED}}" FontSize="10" FontWeight="SemiBold"
                   HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,4,4" Opacity="0.55" IsHitTestVisible="False"/>
    </Grid>
</Window>
"@

Write-GDLog "Ouverture fenetre principale - Theme demande : $script:currentTheme"
$xamlString = Apply-Theme $xamlString $script:currentTheme
[xml]$xaml = $xamlString
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
    if (-not $window) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'principale' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [Windows.Markup.XamlReader]::Load($reader)
        if (-not $window) { throw "Echec du chargement de la fenetre 'principale' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
$controls = @{}
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    $controls[$_.Name] = $window.FindName($_.Name)
}

# =========================================================================
# XAML "Gerer les jeux"
# =========================================================================
$xamlGestionString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Gerer les jeux" Height="600" Width="580" MinHeight="480" MinWidth="480"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
        <Style x:Key="ComboBoxItemStyleG" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,8"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyleG}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleBtn" Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="24"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="#FFFFFF"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="{{INPUT}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="{{MUTED}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{{DARKBG}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="ItemsPanel">
                <Setter.Value>
                    <ItemsPanelTemplate>
                        <StackPanel Orientation="Vertical"/>
                    </ItemsPanelTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ListBoxItemStyleG" TargetType="ListBoxItem">
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,2">
                            <ContentPresenter TextBlock.Foreground="#FFFFFF" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{BORDER}}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ListBoxItem" BasedOn="{StaticResource ListBoxItemStyleG}"/>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,14">
            <Label Content="Plateforme :" VerticalAlignment="Center"/>
            <ComboBox Name="cmbPlatformG" Width="150" Height="36" Margin="8,0,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBox Name="txtNouveauJeu" Width="260" Height="36" Margin="0,0,8,0"/>
            <Button Name="btnAjouter" Content="Ajouter le jeu" Margin="0,0,8,0"/>
            <Button Name="btnCatalogue" Style="{StaticResource SecondaryButton}">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE16D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" VerticalAlignment="Center"/>
                    <TextBlock Text=" Catalogue" VerticalAlignment="Center" Margin="6,0,0,0"/>
                </StackPanel>
            </Button>
        </StackPanel>

        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBox Name="txtRechercheJeu" Width="320" Height="34"/>
            <TextBlock Text="Recherche par nom..." Foreground="{{MUTED}}" FontSize="11" VerticalAlignment="Center" Margin="10,0,0,0"/>
        </StackPanel>

        <ListBox Grid.Row="3" Name="lstGamesG" Margin="0,0,0,14"/>

        <Grid Grid.Row="4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" Name="btnSupprimer" Content="Supprimer" Style="{StaticResource DangerButton}" Margin="0,0,6,0"/>
            <Button Grid.Column="1" Name="btnBasculerFait" Content="Basculer 'deja fait'" Style="{StaticResource SecondaryButton}" Margin="6,0,6,0"/>
            <Button Grid.Column="2" Name="btnResetPool" Content="Reset pool complet" Style="{StaticResource SecondaryButton}" Margin="6,0,6,0"/>
            <Button Grid.Column="3" Name="btnFicheJeu" Content="Fiche du jeu" Margin="6,0,0,0"/>
        </Grid>

        <Grid Grid.Row="5" Margin="0,14,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="Astuce : clique directement sur les icones de note dans la liste pour noter." Foreground="{{MUTED}}" FontSize="11" VerticalAlignment="Center" TextWrapping="Wrap" Width="260"/>
            <Button Grid.Column="1" Name="btnNote0" Content="Effacer la note" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Margin="0,0,10,0"/>
            <CheckBox Grid.Column="2" Name="chkRefaire" Content="Envie de refaire" VerticalAlignment="Center"/>
        </Grid>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Fiche du jeu"
# =========================================================================
$xamlFicheString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Fiche du jeu" Height="640" Width="760" MinHeight="560" MinWidth="680"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource SecondaryButton}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Name="lblFicheTitre" Text="Fiche du jeu" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,16"/>

        <Grid Grid.Row="1" Margin="0,0,0,18">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="180"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="16"/>
                <ColumnDefinition Width="90"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0">
                <TextBlock Text="JAQUETTE (COVER)" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,6"/>
                <Border Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8" Height="200">
                    <Image Name="imgCover" Stretch="Uniform" Margin="4"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                    <Button Name="btnChoisirCover" Content="Choisir..." Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
                    <Button Name="btnRetirerCover" Content="Retirer" Style="{StaticResource DangerButton}"/>
                </StackPanel>
            </StackPanel>

            <StackPanel Grid.Column="2">
                <TextBlock Text="LOGO" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,6"/>
                <Border Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8" Height="90">
                    <Image Name="imgLogo" Stretch="Uniform" Margin="4"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                    <Button Name="btnChoisirLogo" Content="Choisir..." Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
                    <Button Name="btnRetirerLogo" Content="Retirer" Style="{StaticResource DangerButton}"/>
                </StackPanel>

                <TextBlock Text="CAPTURE D'ECRAN" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,14,0,6"/>
                <Border Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8" Height="90">
                    <Image Name="imgScreenshot" Stretch="Uniform" Margin="4"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                    <Button Name="btnChoisirScreenshot" Content="Choisir..." Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
                    <Button Name="btnRetirerScreenshot" Content="Retirer" Style="{StaticResource DangerButton}"/>
                </StackPanel>
            </StackPanel>

            <StackPanel Grid.Column="4">
                <TextBlock Text="ICONE" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,6"/>
                <Border Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8" Height="90" Width="90" HorizontalAlignment="Left">
                    <Image Name="imgIcone" Stretch="Uniform" Margin="4"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
                    <Button Name="btnChoisirIcone" Content="Choisir..." Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
                    <Button Name="btnRetirerIcone" Content="Retirer" Style="{StaticResource DangerButton}"/>
                </StackPanel>
            </StackPanel>
        </Grid>

        <TextBlock Grid.Row="2" Text="COMMENTAIRE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
        <TextBox Grid.Row="3" Name="txtCommentaire" AcceptsReturn="True" TextWrapping="Wrap"
                  VerticalScrollBarVisibility="Auto" VerticalContentAlignment="Top" Margin="0,0,0,14"/>

        <Grid Grid.Row="4">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" Name="btnChercherJaquette" Content="Chercher une jaquette en ligne" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Left"/>
            <Button Grid.Column="2" Name="btnEnregistrerFiche" Content="Enregistrer" Margin="0,0,10,0"/>
            <Button Grid.Column="3" Name="btnFermerFiche" Content="Fermer" Style="{StaticResource SecondaryButton}"/>
        </Grid>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Gerer les plateformes"
# =========================================================================
$xamlPlatformsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Gerer les plateformes" Height="500" Width="520" MinHeight="400" MinWidth="440"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{{DARKBG}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="ItemTemplate">
                <Setter.Value>
                    <DataTemplate>
                        <TextBlock Text="{Binding}" Foreground="#FFFFFF" FontWeight="SemiBold" FontSize="13" TextWrapping="Wrap"/>
                    </DataTemplate>
                </Setter.Value>
            </Setter>
            <Setter Property="ItemsPanel">
                <Setter.Value>
                    <ItemsPanelTemplate>
                        <StackPanel Orientation="Vertical"/>
                    </ItemsPanelTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ListBoxItemStyleP" TargetType="ListBoxItem">
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,2">
                            <ContentPresenter TextBlock.Foreground="#FFFFFF" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{BORDER}}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ListBoxItem" BasedOn="{StaticResource ListBoxItemStyleP}"/>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,14">
            <TextBox Name="txtNouvellePlateforme" Width="320" Height="36" Margin="0,0,8,0"/>
            <Button Name="btnAjouterPlateforme" Content="Ajouter"/>
        </StackPanel>

        <ListBox Grid.Row="1" Name="lstPlatforms" Margin="0,0,0,14"/>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button Grid.Column="0" Name="btnRenommerPlateforme" Content="Renommer" Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
            <Button Grid.Column="1" Name="btnBasculerActif" Content="Activer / Desactiver" Style="{StaticResource SecondaryButton}" Margin="6,0,6,0"/>
            <Button Grid.Column="2" Name="btnSupprimerPlateforme" Content="Supprimer" Style="{StaticResource DangerButton}" Margin="6,0,0,0"/>
        </Grid>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Options"
# =========================================================================
$xamlOptionsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Options" Height="640" Width="500" MinHeight="450" MinWidth="420"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Stretch" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.85"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="{{MUTED}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style x:Key="ComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{{BORDER}}"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyle}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleBtn" Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="24"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="#FFFFFF"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="{{INPUT}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="OPTIONS" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,16"/>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,14,0">

                <TextBlock Text="ICONE DE NOTATION" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Name="stackIconList" Margin="0,0,0,18"/>

                <TextBlock Text="COULEUR DE L'ICONE AU MAXIMUM (5/5)" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Top" Margin="0,0,0,18">
                    <TextBox Name="txtCouleurEtoiles" Width="120" Height="36" VerticalAlignment="Center"/>
                    <Button Name="btnAppliquerCouleur" Content="Appliquer" Style="{StaticResource SecondaryButton}" Margin="10,0,0,0"/>
                </StackPanel>

                <TextBlock Text="DENSITE DE L'AFFICHAGE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Name="stackDensite" Margin="0,0,0,18"/>

                <TextBlock Text="ICONE DE L'APPLICATION" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,4"/>
                <TextBlock Text="Un changement d'icone s'applique a la prochaine ouverture de fenetre." Foreground="{{MUTED}}" FontSize="10" Margin="0,0,0,8"/>
                <StackPanel Name="stackIconeApp" Orientation="Horizontal" Margin="0,0,0,18"/>

                <TextBlock Text="TIRAGE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <CheckBox Name="chkAnimationTirage" Content="Activer l'animation de tirage (defilement rapide avant le resultat)" Margin="0,0,0,8"/>
                <CheckBox Name="chkEviterRepetitionDefaut" Content="Eviter les repetitions par defaut au demarrage" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Label Content="Objectif par defaut :" VerticalAlignment="Center"/>
                    <ComboBox Name="cmbObjectifDefaut" Width="220" Height="34" Margin="8,0,0,0">
                        <ComboBoxItem Content="(aucune preference)"/>
                        <ComboBoxItem Content="Terminer l'histoire"/>
                        <ComboBoxItem Content="Finir a 100%"/>
                        <ComboBoxItem Content="Libre (sans objectif precis)"/>
                    </ComboBox>
                </StackPanel>

                <TextBlock Text="HISTORIQUE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Label Content="Nombre de tirages affiches :" VerticalAlignment="Center"/>
                    <TextBox Name="txtHistoriqueCount" Width="60" Height="34" Margin="8,0,0,0" TextAlignment="Center"/>
                </StackPanel>

                <TextBlock Text="RACCOURCI" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,0,18">
                    <Button Name="btnCreerRaccourci" Content="Creer un raccourci sur le Bureau" Style="{StaticResource SecondaryButton}"/>
                </StackPanel>

                <TextBlock Text="SAUVEGARDE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" Margin="0,0,0,8"/>
                <StackPanel Orientation="Horizontal" Margin="0,0,4,4">
                    <Button Name="btnSauvegarderConfig" Content="Sauvegarder la config" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                    <Button Name="btnRestaurerConfig" Content="Restaurer une config" Style="{StaticResource DangerButton}"/>
                </StackPanel>
                <TextBlock Text="La sauvegarde regroupe plateformes, bibliotheques de jeux, historique et catalogues dans un seul .zip." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap"/>

            </StackPanel>
        </ScrollViewer>

        <Button Grid.Row="2" Name="btnFermerOptions" Content="Fermer" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Width="120" Margin="0,14,0,0"/>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Catalogue Switch"
# =========================================================================
$xamlCatalogueString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Catalogue de jeux" Height="680" Width="560" MinHeight="450" MinWidth="460"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
            <Setter Property="Padding" Value="6,2"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="Margin" Value="0,2"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
        <Style x:Key="ComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{{BORDER}}"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyle}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleBtn" Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="24"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="#FFFFFF"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="{{INPUT}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="CATALOGUE DE JEUX" Foreground="{{ACCENT}}" FontSize="18" FontWeight="Bold" Margin="0,0,0,4"/>
        <TextBlock Grid.Row="1" Text="Liste editable - coche ce qui t'interesse puis ajoute a la bibliotheque de la plateforme selectionnee." Foreground="{{MUTED}}" FontSize="11" TextWrapping="Wrap" Margin="0,0,0,10"/>

        <Grid Grid.Row="2" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Label Grid.Column="0" Content="Catalogue :" VerticalAlignment="Center" Foreground="{{MUTED}}"/>
            <ComboBox Grid.Column="1" Name="cmbTypeCatalogue" Margin="8,0,8,0" Height="34"/>
        </Grid>

        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="stackCatalogue" Margin="0,0,10,0"/>
        </ScrollViewer>

        <StackPanel Grid.Row="4" Margin="0,14,0,0">
            <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
                <TextBox Name="txtNouvelleEntree" Width="330" Height="34" Margin="0,0,8,0"/>
                <Button Name="btnAjouterCatalogue" Content="Ajouter au catalogue" Style="{StaticResource SecondaryButton}"/>
            </StackPanel>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Button Grid.Column="0" Name="btnToutBasculer" Content="Tout cocher / decocher" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Left"/>
                <Button Grid.Column="1" Name="btnAjouterSelection" Content="Ajouter la selection a la bibliotheque" Margin="0,0,10,0"/>
                <Button Grid.Column="2" Name="btnFermerCatalogue" Content="Fermer" Style="{StaticResource SecondaryButton}"/>
            </Grid>
        </StackPanel>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Statistiques"
# =========================================================================
$xamlStatsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Statistiques" Height="560" Width="620" MinHeight="400" MinWidth="480"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="STATISTIQUES" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,4"/>
        <TextBlock Grid.Row="1" Text="'Notes' = jeux ayant recu au moins une note. 'Deja tires' = jeux marques dans le pool du cycle actuel." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,14"/>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="stackStats"/>
        </ScrollViewer>

        <Button Grid.Row="3" Name="btnFermerStats" Content="Fermer" HorizontalAlignment="Right" Width="120" Margin="0,14,0,0"/>
    </Grid>
</Window>
"@

# =========================================================================
# XAML "Backlog" (vue bibliotheque en grille avec pochettes)
# =========================================================================
$xamlBacklogString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Backlog" Height="720" Width="900" MinHeight="500" MinWidth="620"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style x:Key="ComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{{BORDER}}"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyle}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleBtn" Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          Focusable="False" ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                                BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition Width="*"/>
                                                    <ColumnDefinition Width="24"/>
                                                </Grid.ColumnDefinitions>
                                                <TextBlock Grid.Column="1" Text="&#xE70D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="11" Foreground="#CDD6F4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}"
                                              VerticalAlignment="Center" HorizontalAlignment="Left"
                                              TextBlock.Foreground="#FFFFFF"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="{{INPUT}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="8"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="220">
                                    <ScrollViewer>
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="BACKLOG" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,14"/>

        <Grid Grid.Row="1" Margin="0,0,0,14">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Label Grid.Column="0" Content="Plateforme :" VerticalAlignment="Center" Foreground="{{MUTED}}"/>
            <ComboBox Grid.Column="1" Name="cmbPlatformBacklog" Width="160" Height="34" Margin="8,0,14,0"/>
            <TextBox Grid.Column="2" Name="txtRechercheBacklog" Height="34"/>
        </Grid>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <WrapPanel Name="wrapBacklog" Orientation="Horizontal"/>
        </ScrollViewer>

        <Grid Grid.Row="3" Margin="0,14,0,0">
            <TextBlock Name="lblBacklogCompte" Text="" Foreground="{{MUTED}}" FontSize="11" VerticalAlignment="Center"/>
            <Button Name="btnFermerBacklog" Content="Fermer" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Width="120"/>
        </Grid>
    </Grid>
</Window>
"@

function script:Refresh-PlatformCombo {
    $plats = @(Get-Platforms | Where-Object { $_.Actif })
    $controls.cmbPlatform.Items.Clear()
    foreach ($p in $plats) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = [string]$p.Nom
        $controls.cmbPlatform.Items.Add($item) | Out-Null
    }
    if ($controls.cmbPlatform.Items.Count -gt 0) { $controls.cmbPlatform.SelectedIndex = 0 }
}
Refresh-PlatformCombo

function script:Update-PoolStatus {
    if (-not $controls.cmbPlatform.SelectedItem) {
        $controls.lblPool.Text = ""
        $controls.prgPool.Value = 0
        return
    }
    $platName = $controls.cmbPlatform.SelectedItem.Content
    $file = Get-GameFile $platName
    $games = @(Load-Json $file)
    $total = $games.Count
    if ($total -eq 0) {
        $controls.lblPool.Text = "Bibliotheque vide"
        $controls.prgPool.Value = 0
        return
    }
    $restants = @($games | Where-Object { -not $_.DejaFait }).Count
    $controls.lblPool.Text = "$restants jeu(x) restant(s) sur $total avant reset automatique"
    $controls.prgPool.Value = [Math]::Round((($total - $restants) / $total) * 100)
}
$controls.cmbPlatform.Add_SelectionChanged({ Update-PoolStatus })
Update-PoolStatus

$controls.chkEviterRepetition.IsChecked = Get-EviterRepetitionDefaut
$gdObjDefaut = Get-ObjectifDefaut
if ($gdObjDefaut) {
    for ($i = 0; $i -lt $controls.cmbObjectif.Items.Count; $i++) {
        if ($controls.cmbObjectif.Items[$i].Content -eq $gdObjDefaut) { $controls.cmbObjectif.SelectedIndex = $i }
    }
}

# ---- Interface adaptive : sous ~850px de large, le resultat et l'historique
#      passent d'une disposition cote-a-cote a une disposition empilee, pour
#      rester utilisable si la fenetre est reduite ou sur un petit ecran.
$script:gdLayoutEtroit = $null
function script:Update-AdaptiveLayout {
    $etroit = ($window.ActualWidth -lt 850)
    if ($etroit -eq $script:gdLayoutEtroit) { return }
    $script:gdLayoutEtroit = $etroit
    $cols = $controls.gridResultatHistorique.ColumnDefinitions
    if ($etroit) {
        $cols[0].Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $cols[1].Width = New-Object System.Windows.GridLength(0)
        $cols[2].Width = New-Object System.Windows.GridLength(0)
        [System.Windows.Controls.Grid]::SetRow($controls.cardResultat, 0)
        [System.Windows.Controls.Grid]::SetColumn($controls.cardResultat, 0)
        [System.Windows.Controls.Grid]::SetRow($controls.cardHistorique, 1)
        [System.Windows.Controls.Grid]::SetColumn($controls.cardHistorique, 0)
        $controls.cardHistorique.MinHeight = 220
    } else {
        $cols[0].Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $cols[1].Width = New-Object System.Windows.GridLength(16)
        $cols[2].Width = New-Object System.Windows.GridLength(1.2, [System.Windows.GridUnitType]::Star)
        [System.Windows.Controls.Grid]::SetRow($controls.cardResultat, 0)
        [System.Windows.Controls.Grid]::SetColumn($controls.cardResultat, 0)
        [System.Windows.Controls.Grid]::SetRow($controls.cardHistorique, 0)
        [System.Windows.Controls.Grid]::SetColumn($controls.cardHistorique, 2)
        $controls.cardHistorique.MinHeight = 0
    }
}
$window.Add_SizeChanged({ Update-AdaptiveLayout })
Update-AdaptiveLayout


function script:Refresh-Historique {
    $hist = @(Load-Json $histFile)
    $controls.lstHistorique.Items.Clear()
    $cacheJeux = @{}
    $hist | Sort-Object { [datetime]$_.DateTirage } -Descending | Select-Object -First (Get-HistoriqueCount) | ForEach-Object {
        $duree = if ($_.Duree) { $_.Duree } else { "sans limite" }
        $plat = [string]$_.Plateforme
        $nomJeu = [string]$_.Jeu

        if (-not $cacheJeux.ContainsKey($plat)) {
            try { $cacheJeux[$plat] = @(Load-Json (Get-GameFile $plat)) } catch { $cacheJeux[$plat] = @() }
        }
        $jeuData = $cacheJeux[$plat] | Where-Object { [string]$_.Nom -eq $nomJeu } | Select-Object -First 1
        $chemin = ""
        if ($jeuData) { $chemin = if ([string]$jeuData.Cover) { [string]$jeuData.Cover } else { [string]$jeuData.Icone } }

        $item = New-Object System.Windows.Controls.StackPanel
        $item.Orientation = 'Horizontal'
        $item.Margin = '0,2,0,2'

        if ($chemin -and (Test-Path $chemin)) {
            try {
                $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.DecodePixelWidth = 32
                $bmp.UriSource = New-Object System.Uri((Resolve-Path $chemin).Path, [System.UriKind]::Absolute)
                $bmp.EndInit()
                $bmp.Freeze()
                $img = New-Object System.Windows.Controls.Image
                $img.Source = $bmp
                $img.Width = 28
                $img.Height = 28
                $img.Stretch = 'UniformToFill'
                $img.Margin = '0,0,8,0'
                $img.VerticalAlignment = 'Center'
                $item.Children.Add($img) | Out-Null
            } catch { }
        }

        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "[$plat] $nomJeu  |  $duree  |  objectif: $($_.Objectif)"
        $tb.Foreground = [System.Windows.Media.Brushes]::White
        $tb.FontWeight = 'SemiBold'
        $tb.FontSize = 13
        $tb.VerticalAlignment = 'Center'
        $tb.TextWrapping = 'Wrap'
        $item.Children.Add($tb) | Out-Null

        $controls.lstHistorique.Items.Add($item) | Out-Null
    }
}
Refresh-Historique
Force-VerticalListBox $controls.lstHistorique

$controls.chkLimiterTemps.Add_Checked({ $controls.txtDuree.IsEnabled = $true; $controls.cmbUnite.IsEnabled = $true })
$controls.chkLimiterTemps.Add_Unchecked({ $controls.txtDuree.IsEnabled = $false; $controls.cmbUnite.IsEnabled = $false })

function Open-GestionPlateformes {
    $xamlPlatformsString2 = Apply-Theme $xamlPlatformsString $script:currentTheme
    [xml]$xamlP = $xamlPlatformsString2
    $readerP = New-Object System.Xml.XmlNodeReader $xamlP
    $winP = [Windows.Markup.XamlReader]::Load($readerP)
    if (-not $winP) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Gerer les plateformes' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerP = New-Object System.Xml.XmlNodeReader $xamlP
        $winP = [Windows.Markup.XamlReader]::Load($readerP)
        if (-not $winP) { throw "Echec du chargement de la fenetre 'Gerer les plateformes' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winP.Owner = $window
    $cp = @{}
    $xamlP.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cp[$_.Name] = $winP.FindName($_.Name)
    }

    function script:Refresh-PlatformList {
        $plats = Get-Platforms
        $cp.lstPlatforms.Items.Clear()
        foreach ($p in $plats) {
            $nomStr = [string]$p.Nom
            $statut = if ($p.Actif) { "[active]" } else { "[desactivee]" }
            $cp.lstPlatforms.Items.Add("$nomStr   $statut") | Out-Null
        }
    }
    Refresh-PlatformList
    Force-VerticalListBox $cp.lstPlatforms

    $cp.btnAjouterPlateforme.Add_Click({
        Invoke-Safe -Contexte "Ajouter une plateforme" -Action {
            $nom = $cp.txtNouvellePlateforme.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nom)) { return }
            $plats = @(Get-Platforms)
            if ($plats | Where-Object { $_.Nom -eq $nom }) {
                [System.Windows.MessageBox]::Show("Cette plateforme existe deja.", "Info") | Out-Null
                return
            }
            $plats += [pscustomobject]@{ Nom = $nom; Actif = $true; Fichier = (Sanitize-FileName $nom) }
            Save-Platforms $plats
            $cp.txtNouvellePlateforme.Text = ""
            Refresh-PlatformList
            Refresh-PlatformCombo
        }
    })

    $cp.btnRenommerPlateforme.Add_Click({
        Invoke-Safe -Contexte "Renommer une plateforme" -Action {
            if ($cp.lstPlatforms.SelectedIndex -lt 0) { return }
            $plats = @(Get-Platforms)
            $p = $plats[$cp.lstPlatforms.SelectedIndex]
            $nouveauNom = $cp.txtNouvellePlateforme.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nouveauNom)) {
                [System.Windows.MessageBox]::Show("Saisissez le nouveau nom dans le champ texte, puis cliquez sur Renommer.", "Info") | Out-Null
                return
            }
            $p.Nom = $nouveauNom
            Save-Platforms $plats
            $cp.txtNouvellePlateforme.Text = ""
            Refresh-PlatformList
            Refresh-PlatformCombo
        }
    })

    $cp.btnBasculerActif.Add_Click({
        Invoke-Safe -Contexte "Activer/desactiver une plateforme" -Action {
            if ($cp.lstPlatforms.SelectedIndex -lt 0) { return }
            $plats = @(Get-Platforms)
            $p = $plats[$cp.lstPlatforms.SelectedIndex]
            $p.Actif = -not $p.Actif
            Save-Platforms $plats
            Refresh-PlatformList
            Refresh-PlatformCombo
        }
    })

    $cp.btnSupprimerPlateforme.Add_Click({
        Invoke-Safe -Contexte "Supprimer une plateforme" -Action {
            if ($cp.lstPlatforms.SelectedIndex -lt 0) { return }
            $plats = @(Get-Platforms)
            $cible = $plats[$cp.lstPlatforms.SelectedIndex]
            $confirm = [System.Windows.MessageBox]::Show("Supprimer la plateforme '$([string]$cible.Nom)' ? (sa bibliotheque de jeux ne sera pas effacee du disque)", "Confirmation", 'YesNo', 'Warning')
            if ($confirm -ne 'Yes') { return }
            $plats = @($plats | Where-Object { $_ -ne $cible })
            Save-Platforms $plats
            Refresh-PlatformList
            Refresh-PlatformCombo
        }
    })

    $winP.ShowDialog() | Out-Null
}

function Open-GestionJeux {
    $xamlGestionString2 = Apply-Theme $xamlGestionString $script:currentTheme
    [xml]$xamlGestion = $xamlGestionString2
    $readerG = New-Object System.Xml.XmlNodeReader $xamlGestion
    $winG = [Windows.Markup.XamlReader]::Load($readerG)
    if (-not $winG) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Gerer les jeux' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerG = New-Object System.Xml.XmlNodeReader $xamlGestion
        $winG = [Windows.Markup.XamlReader]::Load($readerG)
        if (-not $winG) { throw "Echec du chargement de la fenetre 'Gerer les jeux' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winG.Owner = $window
    $cg = @{}
    $xamlGestion.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cg[$_.Name] = $winG.FindName($_.Name)
    }

    $allPlats = Get-Platforms
    foreach ($p in $allPlats) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = [string]$p.Nom
        $cg.cmbPlatformG.Items.Add($item) | Out-Null
    }
    if ($cg.cmbPlatformG.Items.Count -gt 0) { $cg.cmbPlatformG.SelectedIndex = 0 }

    function script:Refresh-ListG {
        if (-not $cg.cmbPlatformG.SelectedItem) { return }
        $platName = $cg.cmbPlatformG.SelectedItem.Content
        $file = Get-GameFile $platName
        $games = @(Load-Json $file)
        foreach ($g in $games) { Ensure-GameFields $g | Out-Null }
        $cg.lstGamesG.Items.Clear()
        $brushOr    = ConvertTo-GDBrush $script:starGoldColor
        $brushBlanc = [System.Windows.Media.Brushes]::White
        $icones     = Get-RatingIconSet (Get-RatingIconName)
        $filtre     = if ($cg.txtRechercheJeu) { $cg.txtRechercheJeu.Text.Trim() } else { "" }
        $compact    = ((Get-Densite) -eq "Compacte")
        $tailleTitre  = if ($compact) { 12 } else { 13 }
        $tailleIcones = if ($compact) { 14 } else { 16 }
        $margeItem    = if ($compact) { '0,1,0,1' } else { '0,3,0,3' }

        for ($realIndex = 0; $realIndex -lt $games.Count; $realIndex++) {
            $g = $games[$realIndex]
            $nomStr = [string]$g.Nom
            if ($filtre -and ($nomStr.ToLower() -notlike "*$($filtre.ToLower())*")) { continue }

            $statut = if ($g.DejaFait) { "[deja fait]" } else { "[disponible]" }
            $note = 0
            [void][int]::TryParse([string]$g.Note, [ref]$note)
            if ($note -lt 0) { $note = 0 }
            if ($note -gt 5) { $note = 5 }
            $etoiles = ($icones.Filled * $note) + ($icones.Empty * (5 - $note))
            $titre = "$nomStr   $statut   (Note enregistree : $note/5)"
            $estOr = ($note -ge 5)

            # Construction directe des elements visuels (pas de {Binding}) pour
            # garantir que la couleur calculee en PowerShell soit bien celle
            # affichee a l'ecran, sans dependre de la conversion XAML.
            $panelItem = New-Object System.Windows.Controls.StackPanel
            $panelItem.Orientation = 'Horizontal'
            $panelItem.Tag = $realIndex
            $panelItem.Margin = $margeItem

            $cheminVignette = if ([string]$g.Cover) { [string]$g.Cover } else { [string]$g.Icone }
            if ($cheminVignette -and (Test-Path $cheminVignette)) {
                try {
                    $bmpVignette = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bmpVignette.BeginInit()
                    $bmpVignette.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bmpVignette.DecodePixelWidth = 40
                    $bmpVignette.UriSource = New-Object System.Uri((Resolve-Path $cheminVignette).Path, [System.UriKind]::Absolute)
                    $bmpVignette.EndInit()
                    $bmpVignette.Freeze()
                    $imgVignette = New-Object System.Windows.Controls.Image
                    $imgVignette.Source = $bmpVignette
                    $imgVignette.Width = 36
                    $imgVignette.Height = 36
                    $imgVignette.Stretch = 'UniformToFill'
                    $imgVignette.Margin = '0,0,10,0'
                    $imgVignette.VerticalAlignment = 'Top'
                    $panelItem.Children.Add($imgVignette) | Out-Null
                } catch { }
            }

            $textStack = New-Object System.Windows.Controls.StackPanel
            $textStack.Orientation = 'Vertical'

            $tbTitre = New-Object System.Windows.Controls.TextBlock
            $tbTitre.Text = $titre
            $tbTitre.Foreground = $brushBlanc
            $tbTitre.FontWeight = 'SemiBold'
            $tbTitre.FontSize = $tailleTitre
            $tbTitre.TextWrapping = 'Wrap'
            $textStack.Children.Add($tbTitre) | Out-Null

            $ligneNote = New-Object System.Windows.Controls.StackPanel
            $ligneNote.Orientation = 'Horizontal'
            $ligneNote.Margin = '0,3,0,0'

            # Notation en un clic direct sur les icones (avec previsualisation au
            # survol). Le texte reste isole de l'indicateur "refaire" pour que le
            # calcul de zone de clic (X / largeur * 5) porte uniquement sur les 5
            # icones et ne soit jamais fausse par un suffixe.
            $tbEtoiles = New-Object System.Windows.Controls.TextBlock
            $tbEtoiles.Text = $etoiles
            $tbEtoiles.Foreground = $(if ($estOr) { $brushOr } else { $brushBlanc })
            $tbEtoiles.FontWeight = 'Bold'
            $tbEtoiles.FontSize = $tailleIcones
            $tbEtoiles.Cursor = 'Hand'
            $tbEtoiles.Tag = $realIndex
            $tbEtoiles.ToolTip = "Clique sur une icone pour noter"

            $tbEtoiles.Add_MouseMove({
                $e = $args[1]
                $ratio = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
                $hoverN = [Math]::Ceiling($ratio * 5)
                if ($hoverN -lt 1) { $hoverN = 1 }
                if ($hoverN -gt 5) { $hoverN = 5 }
                $ic = Get-RatingIconSet (Get-RatingIconName)
                $this.Text = ($ic.Filled * $hoverN) + ($ic.Empty * (5 - $hoverN))
                $this.Foreground = ConvertTo-GDBrush $script:starGoldColor
            })
            $tbEtoiles.Add_MouseLeave({ Refresh-ListG })
            $tbEtoiles.Add_MouseLeftButtonDown({
                $e = $args[1]
                $ratio = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
                $hoverN = [Math]::Ceiling($ratio * 5)
                if ($hoverN -lt 1) { $hoverN = 1 }
                if ($hoverN -gt 5) { $hoverN = 5 }
                Set-NoteJeuParIndex -idx $this.Tag -note $hoverN
            })
            $ligneNote.Children.Add($tbEtoiles) | Out-Null

            $panelItem.Children.Add($textStack) | Out-Null

            if ($g.Refaire) {
                $tbRefaire = New-Object System.Windows.Controls.TextBlock
                $tbRefaire.Text = "  $([char]0xE777)"
                $tbRefaire.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
                $tbRefaire.FontSize = 15
                $tbRefaire.Foreground = $brushBlanc
                $tbRefaire.ToolTip = "Envie de refaire"
                $ligneNote.Children.Add($tbRefaire) | Out-Null
            }

            $textStack.Children.Add($ligneNote) | Out-Null
            $cg.lstGamesG.Items.Add($panelItem) | Out-Null
        }
    }

    function script:Get-SelectionIndex {
        $sel = $cg.lstGamesG.SelectedItem
        if (-not $sel) { return -1 }
        return [int]$sel.Tag
    }

    Refresh-ListG
    Force-VerticalListBox $cg.lstGamesG

    $cg.cmbPlatformG.Add_SelectionChanged({ $cg.txtRechercheJeu.Text = ""; Refresh-ListG })
    $cg.txtRechercheJeu.Add_TextChanged({ Refresh-ListG })

    $cg.btnCatalogue.Add_Click({ Invoke-Safe -Contexte "Catalogue" -Action { Open-Catalogue -PlateformeCible $cg.cmbPlatformG.SelectedItem.Content -OnAdded { Refresh-ListG } } })

    $cg.btnAjouter.Add_Click({
        Invoke-Safe -Contexte "Ajouter un jeu" -Action {
            $nom = $cg.txtNouveauJeu.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nom)) { return }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            $games += [pscustomobject]@{ Nom = $nom; DejaFait = $false; TypeFin = "" }
            Save-Json $file $games
            $cg.txtNouveauJeu.Text = ""
            Refresh-ListG
        }
    })

    $cg.btnSupprimer.Add_Click({
        Invoke-Safe -Contexte "Supprimer un jeu" -Action {
            $idx = Get-SelectionIndex
            if ($idx -lt 0) { return }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            $nomJeu = [string]$games[$idx].Nom
            $confirm = [System.Windows.MessageBox]::Show("Supprimer '$nomJeu' de la bibliotheque ?", "Confirmation", 'YesNo', 'Warning')
            if ($confirm -ne 'Yes') { return }
            $games = @($games | Where-Object { $_ -ne $games[$idx] })
            Save-Json $file $games
            Refresh-ListG
        }
    })

    $cg.btnBasculerFait.Add_Click({
        Invoke-Safe -Contexte "Basculer deja fait" -Action {
            $idx = Get-SelectionIndex
            if ($idx -lt 0) { return }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            $g = $games[$idx]
            $g.DejaFait = -not $g.DejaFait
            Save-Json $file $games
            Refresh-ListG
        }
    })

    $cg.btnResetPool.Add_Click({
        Invoke-Safe -Contexte "Reset du pool" -Action {
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            foreach ($g in $games) { $g.DejaFait = $false }
            Save-Json $file $games
            Refresh-ListG
        }
    })

    $cg.btnFicheJeu.Add_Click({
        Invoke-Safe -Contexte "Fiche du jeu" -Action {
            $idx = Get-SelectionIndex
            if ($idx -lt 0) {
                [System.Windows.MessageBox]::Show("Selectionnez un jeu dans la liste.", "Info") | Out-Null
                return
            }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            Open-FicheJeu -PlateformeCible $platName -IndexJeu $idx -OnSaved { Refresh-ListG }
        }
    })

    function script:Set-NoteJeuParIndex {
        param([int]$idx, [int]$note)
        Invoke-Safe -Contexte "Noter un jeu" -Action {
            if ($idx -lt 0) { return }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            if ($idx -ge $games.Count) { return }
            $g = Ensure-GameFields $games[$idx]
            $g.Note = $note
            Save-Json $file $games
            Refresh-ListG
        }
    }

    $cg.btnNote0.Add_Click({ Set-NoteJeuParIndex -idx (Get-SelectionIndex) -note 0 })

    $cg.chkRefaire.Add_Click({
        Invoke-Safe -Contexte "Basculer envie de refaire" -Action {
        $idx = Get-SelectionIndex
        if ($idx -lt 0) {
            [System.Windows.MessageBox]::Show("Selectionnez un jeu dans la liste.", "Info") | Out-Null
            return
        }
        $platName = $cg.cmbPlatformG.SelectedItem.Content
        $file = Get-GameFile $platName
        $games = @(Load-Json $file)
        $g = Ensure-GameFields $games[$idx]
        $g.Refaire = $cg.chkRefaire.IsChecked
        Save-Json $file $games
        Refresh-ListG
        }
    })

    $winG.ShowDialog() | Out-Null
}

function Open-FicheJeu {
    param(
        [string]$PlateformeCible,
        [int]$IndexJeu,
        [scriptblock]$OnSaved
    )

    $xamlFicheString2 = Apply-Theme $xamlFicheString $script:currentTheme
    [xml]$xamlF = $xamlFicheString2
    $readerF = New-Object System.Xml.XmlNodeReader $xamlF
    $winF = [Windows.Markup.XamlReader]::Load($readerF)
    if (-not $winF) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Fiche du jeu' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerF = New-Object System.Xml.XmlNodeReader $xamlF
        $winF = [Windows.Markup.XamlReader]::Load($readerF)
        if (-not $winF) { throw "Echec du chargement de la fenetre 'Fiche du jeu' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winF.Owner = $window
    $cf = @{}
    $xamlF.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cf[$_.Name] = $winF.FindName($_.Name)
    }

    $file = Get-GameFile $PlateformeCible
    $games = @(Load-Json $file)
    if ($IndexJeu -lt 0 -or $IndexJeu -ge $games.Count) {
        [System.Windows.MessageBox]::Show("Jeu introuvable (la liste a peut-etre change entre-temps). Reouvre la fiche.", "Info") | Out-Null
        return
    }
    $g = Ensure-GameFields $games[$IndexJeu]

    $cf.lblFicheTitre.Text = "Fiche du jeu : $([string]$g.Nom)"
    $cf.txtCommentaire.Text = [string]$g.Commentaire

    function script:Load-FicheImage($imgControl, [string]$path) {
        $imgControl.Source = $null
        if ($path -and (Test-Path $path)) {
            try {
                $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.UriSource = New-Object System.Uri((Resolve-Path $path).Path, [System.UriKind]::Absolute)
                $bmp.EndInit()
                $bmp.Freeze()
                $imgControl.Source = $bmp
            } catch {
                Write-GDLog "ERREUR chargement image '$path' : $($_.Exception.Message)"
            }
        }
    }
    Load-FicheImage $cf.imgCover      ([string]$g.Cover)
    Load-FicheImage $cf.imgLogo       ([string]$g.Logo)
    Load-FicheImage $cf.imgScreenshot ([string]$g.Screenshot)
    Load-FicheImage $cf.imgIcone      ([string]$g.Icone)

    function script:Choisir-FicheImage([string]$slot, $imgControl) {
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "Images (*.png;*.jpg;*.jpeg;*.bmp;*.gif)|*.png;*.jpg;*.jpeg;*.bmp;*.gif|Tous les fichiers (*.*)|*.*"
        $dlg.Title = "Choisir une image"
        if ($dlg.ShowDialog() -eq $true) {
            $dest = Save-GameImage -platformName $PlateformeCible -gameName ([string]$g.Nom) -slot $slot -sourcePath $dlg.FileName
            $g.$slot = $dest
            Load-FicheImage $imgControl $dest
        }
    }

    $cf.btnChoisirCover.Add_Click({ Invoke-Safe -Contexte "Choisir la jaquette" -Action { Choisir-FicheImage "Cover" $cf.imgCover } })
    $cf.btnChoisirLogo.Add_Click({ Invoke-Safe -Contexte "Choisir le logo" -Action { Choisir-FicheImage "Logo" $cf.imgLogo } })
    $cf.btnChoisirScreenshot.Add_Click({ Invoke-Safe -Contexte "Choisir la capture" -Action { Choisir-FicheImage "Screenshot" $cf.imgScreenshot } })
    $cf.btnChoisirIcone.Add_Click({ Invoke-Safe -Contexte "Choisir l'icone" -Action { Choisir-FicheImage "Icone" $cf.imgIcone } })

    $cf.btnRetirerCover.Add_Click({ Invoke-Safe -Contexte "Retirer la jaquette" -Action { $g.Cover = ""; Load-FicheImage $cf.imgCover "" } })
    $cf.btnRetirerLogo.Add_Click({ Invoke-Safe -Contexte "Retirer le logo" -Action { $g.Logo = ""; Load-FicheImage $cf.imgLogo "" } })
    $cf.btnRetirerScreenshot.Add_Click({ Invoke-Safe -Contexte "Retirer la capture" -Action { $g.Screenshot = ""; Load-FicheImage $cf.imgScreenshot "" } })
    $cf.btnRetirerIcone.Add_Click({ Invoke-Safe -Contexte "Retirer l'icone" -Action { $g.Icone = ""; Load-FicheImage $cf.imgIcone "" } })

    $cf.btnChercherJaquette.Add_Click({
        Invoke-Safe -Contexte "Chercher une jaquette" -Action {
            $requete = [System.Uri]::EscapeDataString([string]$g.Nom)
            Start-Process "https://www.steamgriddb.com/search/grids?term=$requete"
        }
    })

    $cf.btnEnregistrerFiche.Add_Click({
        Invoke-Safe -Contexte "Enregistrer la fiche du jeu" -Action {
            $g.Commentaire = $cf.txtCommentaire.Text
            Save-Json $file $games
            Write-GDLog "Fiche du jeu enregistree : $([string]$g.Nom)"
            if ($OnSaved) { & $OnSaved }
            [System.Windows.MessageBox]::Show("Fiche enregistree.", "GameDraw") | Out-Null
        }
    })
    $cf.btnFermerFiche.Add_Click({ $winF.Close() })

    $winF.ShowDialog() | Out-Null
}

function Open-GestionOptions {
    $xamlOptionsString2 = Apply-Theme $xamlOptionsString $script:currentTheme
    [xml]$xamlO = $xamlOptionsString2
    $readerO = New-Object System.Xml.XmlNodeReader $xamlO
    $winO = [Windows.Markup.XamlReader]::Load($readerO)
    if (-not $winO) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Options' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerO = New-Object System.Xml.XmlNodeReader $xamlO
        $winO = [Windows.Markup.XamlReader]::Load($readerO)
        if (-not $winO) { throw "Echec du chargement de la fenetre 'Options' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winO.Owner = $window
    $co = @{}
    $xamlO.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $co[$_.Name] = $winO.FindName($_.Name)
    }

    function script:Populate-IconMenu {
        $co.stackIconList.Children.Clear()
        $iconeActuelle = Get-RatingIconName
        foreach ($key in $script:ratingIconOrder) {
            $ic = Get-RatingIconSet $key
            $isActive = ($key -eq $iconeActuelle)

            $btn = New-Object System.Windows.Controls.Button
            $btn.Style = $winO.FindResource("SecondaryButton")
            $btn.HorizontalContentAlignment = 'Stretch'
            $btn.Margin = '0,0,0,4'
            $btn.Tag = $key
            if ($isActive) { $btn.BorderThickness = 1 }

            $row = New-Object System.Windows.Controls.Grid
            foreach ($w in @('Auto', '*', 'Auto')) {
                $cd = New-Object System.Windows.Controls.ColumnDefinition
                if ($w -eq '*') { $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }
                else { $cd.Width = [System.Windows.GridLength]::Auto }
                $row.ColumnDefinitions.Add($cd) | Out-Null
            }

            $preview = New-Object System.Windows.Controls.TextBlock
            $preview.Text = "$($ic.Filled)$($ic.Filled)$($ic.Filled)"
            $preview.FontSize = 15
            $preview.Margin = '0,0,10,0'
            $preview.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($preview, 0)
            $row.Children.Add($preview) | Out-Null

            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $ic.Nom
            $lbl.VerticalAlignment = 'Center'
            $lbl.FontWeight = 'SemiBold'
            [System.Windows.Controls.Grid]::SetColumn($lbl, 1)
            $row.Children.Add($lbl) | Out-Null

            if ($isActive) {
                $check = New-Object System.Windows.Controls.TextBlock
                $check.Text = [string][char]0xE73E
                $check.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
                $check.FontWeight = 'Bold'
                $check.VerticalAlignment = 'Center'
                $check.Margin = '8,0,0,0'
                [System.Windows.Controls.Grid]::SetColumn($check, 2)
                $row.Children.Add($check) | Out-Null
            }

            $btn.Content = $row
            $btn.Add_Click({
                $tagIcone = $this.Tag
                Invoke-Safe -Contexte "Changer l'icone de notation" -Action {
                    Save-RatingIconName $tagIcone
                    Write-GDLog "Icone de notation changee : $tagIcone"
                    Populate-IconMenu
                }
            })
            $co.stackIconList.Children.Add($btn) | Out-Null
        }
    }
    Populate-IconMenu

    function script:Populate-DensiteMenu {
        $co.stackDensite.Children.Clear()
        $densiteActuelle = Get-Densite
        $options = @(
            @{ Key = "Confortable"; Label = "Confortable"; Desc = "Texte plus grand, plus d'espacement" }
            @{ Key = "Compacte";    Label = "Compacte";    Desc = "Plus de jeux visibles a l'ecran" }
        )
        foreach ($opt in $options) {
            $isActive = ($opt.Key -eq $densiteActuelle)
            $btn = New-Object System.Windows.Controls.Button
            $btn.Style = $winO.FindResource("SecondaryButton")
            $btn.HorizontalContentAlignment = 'Left'
            $btn.Margin = '0,0,0,4'
            $btn.Tag = $opt.Key
            if ($isActive) { $btn.BorderThickness = 1 }

            $txt = "$($opt.Label) - $($opt.Desc)$(if ($isActive) { '   [' + [string][char]0x2713 + ']' })"
            $btn.Content = $txt
            $btn.Add_Click({
                $tagDensite = $this.Tag
                Invoke-Safe -Contexte "Changer la densite" -Action {
                    Set-GDConfig @{ Densite = $tagDensite }
                    Populate-DensiteMenu
                }
            })
            $co.stackDensite.Children.Add($btn) | Out-Null
        }
    }
    Populate-DensiteMenu

    function script:Populate-IconeAppMenu {
        $co.stackIconeApp.Children.Clear()
        $choixActuel = Get-IconApp
        foreach ($key in @("Original", "Bleu", "Sombre")) {
            $info = $script:iconChoices[$key]
            $isActive = ($key -eq $choixActuel)

            $item = New-Object System.Windows.Controls.StackPanel
            $item.Margin = '0,0,14,0'
            $item.Cursor = 'Hand'
            $item.Tag = $key

            $previewPath = Join-Path $packageRoot ("assets\" + $info.Preview)
            $border = New-Object System.Windows.Controls.Border
            $border.Width = 64
            $border.Height = 64
            $border.CornerRadius = 10
            $border.ClipToBounds = $true
            $border.BorderThickness = if ($isActive) { 2 } else { 1 }
            $border.BorderBrush = if ($isActive) { ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT } else { ConvertTo-GDBrush $themes[$script:currentTheme].BORDER }
            if (Test-Path $previewPath) {
                try {
                    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bmp.BeginInit()
                    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bmp.DecodePixelWidth = 96
                    $bmp.UriSource = New-Object System.Uri((Resolve-Path $previewPath).Path, [System.UriKind]::Absolute)
                    $bmp.EndInit()
                    $bmp.Freeze()
                    $img = New-Object System.Windows.Controls.Image
                    $img.Source = $bmp
                    $img.Stretch = 'UniformToFill'
                    $border.Child = $img
                } catch { }
            }
            $item.Children.Add($border) | Out-Null

            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = "$($info.Nom)$(if ($isActive) { '  ' + [string][char]0xE73E } else { '' })"
            $lbl.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets, Segoe UI")
            $lbl.FontSize = 11
            $lbl.Foreground = [System.Windows.Media.Brushes]::White
            $lbl.HorizontalAlignment = 'Center'
            $lbl.Margin = '0,4,0,0'
            $item.Children.Add($lbl) | Out-Null

            $item.Add_MouseLeftButtonDown({
                $tagIcone = $this.Tag
                Invoke-Safe -Contexte "Changer l'icone de l'application" -Action {
                    Save-IconApp $tagIcone
                    Write-GDLog "Icone d'application changee : $tagIcone -> rechargement de la fenetre principale"
                    $script:reloadRequested = $true
                    $winO.Close()
                    $window.Close()
                }
            })
            $co.stackIconeApp.Children.Add($item) | Out-Null
        }
    }
    Populate-IconeAppMenu

    $co.txtCouleurEtoiles.Text = Get-StarColor
    $co.chkAnimationTirage.IsChecked = Get-AnimationTirage
    $co.chkEviterRepetitionDefaut.IsChecked = Get-EviterRepetitionDefaut
    $co.txtHistoriqueCount.Text = [string](Get-HistoriqueCount)
    $objDefaut = Get-ObjectifDefaut
    $co.cmbObjectifDefaut.SelectedIndex = 0
    for ($i = 0; $i -lt $co.cmbObjectifDefaut.Items.Count; $i++) {
        if ($co.cmbObjectifDefaut.Items[$i].Content -eq $objDefaut) { $co.cmbObjectifDefaut.SelectedIndex = $i }
    }

    $co.chkAnimationTirage.Add_Click({
        Invoke-Safe -Contexte "Basculer l'animation" -Action { Set-GDConfig @{ AnimationTirage = [bool]$co.chkAnimationTirage.IsChecked } }
    })
    $co.chkEviterRepetitionDefaut.Add_Click({
        Invoke-Safe -Contexte "Basculer eviter repetition par defaut" -Action { Set-GDConfig @{ EviterRepetitionDefaut = [bool]$co.chkEviterRepetitionDefaut.IsChecked } }
    })
    $co.cmbObjectifDefaut.Add_SelectionChanged({
        Invoke-Safe -Contexte "Objectif par defaut" -Action {
            $val = if ($co.cmbObjectifDefaut.SelectedItem -and $co.cmbObjectifDefaut.SelectedIndex -gt 0) { $co.cmbObjectifDefaut.SelectedItem.Content } else { "" }
            Set-GDConfig @{ ObjectifDefaut = $val }
        }
    })
    $co.txtHistoriqueCount.Add_LostFocus({
        Invoke-Safe -Contexte "Nombre d'elements historique" -Action {
            $n = 15
            [void][int]::TryParse($co.txtHistoriqueCount.Text, [ref]$n)
            if ($n -lt 1) { $n = 1 }
            if ($n -gt 200) { $n = 200 }
            $co.txtHistoriqueCount.Text = [string]$n
            Set-GDConfig @{ HistoriqueCount = $n }
        }
    })

    $co.btnAppliquerCouleur.Add_Click({
        Invoke-Safe -Contexte "Appliquer la couleur" -Action {
            $hex = $co.txtCouleurEtoiles.Text.Trim()
            if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') {
                [System.Windows.MessageBox]::Show("Format invalide. Utilisez un code hexadecimal du type #FFD700.", "Info") | Out-Null
                return
            }
            Save-StarColor $hex
            $script:starGoldColor = $hex
            [System.Windows.MessageBox]::Show("Couleur mise a jour.", "GameDraw") | Out-Null
        }
    })

    $co.btnCreerRaccourci.Add_Click({
        Invoke-Safe -Contexte "Creer un raccourci bureau" -Action {
            $ps1Path = Join-Path $scriptRoot "Tirage-Jeux.ps1"
            $ps1Path = [System.IO.Path]::GetFullPath($ps1Path)
            $iconPathLnk = [System.IO.Path]::GetFullPath($script:iconPath)
            $desktop = [Environment]::GetFolderPath("Desktop")
            $shortcutPath = Join-Path $desktop "GameDraw.lnk"

            if (-not (Test-Path $ps1Path)) {
                [System.Windows.MessageBox]::Show("Tirage-Jeux.ps1 introuvable a : $ps1Path", "Erreur") | Out-Null
                return
            }

            New-GDShortcut -ps1Path $ps1Path -shortcutPath $shortcutPath -iconFile $iconPathLnk

            Write-GDLog "Raccourci bureau cree : $shortcutPath"
            [System.Windows.MessageBox]::Show("Raccourci cree sur le Bureau. Double-clic = demande d'elevation directe, sans fenetre intermediaire.", "GameDraw") | Out-Null
        }
    })

    $co.btnSauvegarderConfig.Add_Click({
        Invoke-Safe -Contexte "Sauvegarde de la config" -Action {
            $dlg = New-Object Microsoft.Win32.SaveFileDialog
            $dlg.Filter = "Archive GameDraw (*.zip)|*.zip"
            $dlg.FileName = "GameDraw_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
            if ($dlg.ShowDialog() -ne $true) { return }

            $tempDir = Join-Path $env:TEMP "GameDraw_Backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            Get-ChildItem -Path $root -Filter "*.json" | Copy-Item -Destination $tempDir -Force
            $imagesDir = Join-Path $root "images"
            if (Test-Path $imagesDir) {
                Copy-Item -Path $imagesDir -Destination (Join-Path $tempDir "images") -Recurse -Force
            }

            if (Test-Path $dlg.FileName) { Remove-Item $dlg.FileName -Force }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $dlg.FileName)
            Remove-Item $tempDir -Recurse -Force

            Write-GDLog "Sauvegarde creee : $($dlg.FileName)"
            [System.Windows.MessageBox]::Show("Sauvegarde creee :`n$($dlg.FileName)", "GameDraw") | Out-Null
        }
    })

    $co.btnRestaurerConfig.Add_Click({
        Invoke-Safe -Contexte "Restauration de la config" -Action {
            $dlg = New-Object Microsoft.Win32.OpenFileDialog
            $dlg.Filter = "Archive GameDraw (*.zip)|*.zip"
            if ($dlg.ShowDialog() -ne $true) { return }

            $confirm = [System.Windows.MessageBox]::Show(
                "Cette operation va ECRASER toutes les donnees actuelles (jeux, historique, plateformes, config, catalogues, images) avec celles de l'archive.`n`nContinuer ?",
                "Confirmation", 'YesNo', 'Warning')
            if ($confirm -ne 'Yes') { return }

            $tempDir = Join-Path $env:TEMP "GameDraw_Restore_$(Get-Date -Format 'yyyyMMddHHmmss')"
            [System.IO.Compression.ZipFile]::ExtractToDirectory($dlg.FileName, $tempDir)
            Get-ChildItem -Path $tempDir -Filter "*.json" -Recurse | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination (Join-Path $root $_.Name) -Force
            }
            $imagesSrc = Join-Path $tempDir "images"
            if (Test-Path $imagesSrc) {
                $imagesDst = Join-Path $root "images"
                if (Test-Path $imagesDst) { Remove-Item $imagesDst -Recurse -Force }
                Copy-Item -Path $imagesSrc -Destination $imagesDst -Recurse -Force
            }
            Remove-Item $tempDir -Recurse -Force

            Write-GDLog "Restauration effectuee depuis : $($dlg.FileName)"
            [System.Windows.MessageBox]::Show("Restauration terminee. La fenetre va se recharger.", "GameDraw") | Out-Null

            $script:currentTheme  = Get-CurrentThemeName
            $script:starGoldColor = Get-StarColor
            $script:reloadRequested = $true
            $winO.Close()
            $window.Close()
        }
    })

    $co.btnFermerOptions.Add_Click({ $winO.Close() })

    $winO.ShowDialog() | Out-Null
}

function Open-Catalogue {
    param(
        [string]$PlateformeCible,
        [scriptblock]$OnAdded
    )
    $xamlCatalogueString2 = Apply-Theme $xamlCatalogueString $script:currentTheme
    [xml]$xamlC = $xamlCatalogueString2
    $readerC = New-Object System.Xml.XmlNodeReader $xamlC
    $winC = [Windows.Markup.XamlReader]::Load($readerC)
    if (-not $winC) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Catalogue' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerC = New-Object System.Xml.XmlNodeReader $xamlC
        $winC = [Windows.Markup.XamlReader]::Load($readerC)
        if (-not $winC) { throw "Echec du chargement de la fenetre 'Catalogue' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winC.Owner = $window
    $cc = @{}
    $xamlC.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cc[$_.Name] = $winC.FindName($_.Name)
    }

    foreach ($key in $script:catalogueKeys) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $script:catalogueLabels[$key]
        $item.Tag = $key
        $cc.cmbTypeCatalogue.Items.Add($item) | Out-Null
    }
    $cc.cmbTypeCatalogue.SelectedIndex = 0

    function script:Refresh-Catalogue {
        $cc.stackCatalogue.Children.Clear()
        $key = $cc.cmbTypeCatalogue.SelectedItem.Tag
        $liste = Get-CatalogueListe $key
        foreach ($nomJeu in $liste) {
            $ligne = New-Object System.Windows.Controls.Grid
            foreach ($w in @('*', 'Auto')) {
                $cd = New-Object System.Windows.Controls.ColumnDefinition
                if ($w -eq '*') { $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }
                else { $cd.Width = [System.Windows.GridLength]::Auto }
                $ligne.ColumnDefinitions.Add($cd) | Out-Null
            }
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Content = $nomJeu
            $chk.Tag = $nomJeu
            [System.Windows.Controls.Grid]::SetColumn($chk, 0)
            $ligne.Children.Add($chk) | Out-Null

            $btnDel = New-Object System.Windows.Controls.Button
            $btnDel.Content = [char]0xE74D
            $btnDel.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
            $btnDel.Style = $winC.FindResource("DangerButton")
            $btnDel.Tag = $nomJeu
            $btnDel.ToolTip = "Retirer du catalogue"
            $btnDel.Add_Click({
                $capturedTag = $this.Tag
                Invoke-Safe -Contexte "Retirer du catalogue" -Action {
                    Remove-CatalogueItem -key $cc.cmbTypeCatalogue.SelectedItem.Tag -nom $capturedTag
                    Refresh-Catalogue
                }
            })
            [System.Windows.Controls.Grid]::SetColumn($btnDel, 1)
            $ligne.Children.Add($btnDel) | Out-Null

            $cc.stackCatalogue.Children.Add($ligne) | Out-Null
        }
    }
    Refresh-Catalogue

    $cc.cmbTypeCatalogue.Add_SelectionChanged({ Refresh-Catalogue })

    $cc.btnAjouterCatalogue.Add_Click({
        Invoke-Safe -Contexte "Ajouter au catalogue" -Action {
            $nom = $cc.txtNouvelleEntree.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nom)) { return }
            Add-CatalogueItem -key $cc.cmbTypeCatalogue.SelectedItem.Tag -nom $nom
            $cc.txtNouvelleEntree.Text = ""
            Refresh-Catalogue
        }
    })

    $cc.btnToutBasculer.Add_Click({
        Invoke-Safe -Contexte "Tout cocher/decocher" -Action {
            $cases = @($cc.stackCatalogue.Children | ForEach-Object { $_.Children[0] })
            $tousCoches = -not ($cases | Where-Object { -not $_.IsChecked } | Select-Object -First 1)
            foreach ($chk in $cases) { $chk.IsChecked = -not $tousCoches }
        }
    })

    $cc.btnAjouterSelection.Add_Click({
        Invoke-Safe -Contexte "Ajout depuis le catalogue" -Action {
            if ([string]::IsNullOrWhiteSpace($PlateformeCible)) {
                [System.Windows.MessageBox]::Show("Selectionne d'abord une plateforme dans 'Gerer les jeux'.", "Info") | Out-Null
                return
            }
            $selection = @($cc.stackCatalogue.Children | ForEach-Object { $_.Children[0] } | Where-Object { $_.IsChecked })
            if ($selection.Count -eq 0) {
                [System.Windows.MessageBox]::Show("Aucun jeu coche.", "Info") | Out-Null
                return
            }
            $file = Get-GameFile $PlateformeCible
            $games = @(Load-Json $file)
            $nomsExistants = @($games | ForEach-Object { ([string]$_.Nom).ToLower() })
            $ajoutes = 0
            foreach ($chk in $selection) {
                $nomJeu = [string]$chk.Tag
                if ($nomsExistants -contains $nomJeu.ToLower()) { continue }
                $games += [pscustomobject]@{ Nom = $nomJeu; DejaFait = $false; TypeFin = "" }
                $ajoutes++
            }
            Save-Json $file $games
            Write-GDLog "Catalogue : $ajoutes jeu(x) ajoute(s) a la plateforme $PlateformeCible"
            [System.Windows.MessageBox]::Show("$ajoutes jeu(x) ajoute(s) a la bibliotheque '$PlateformeCible'.", "GameDraw") | Out-Null
            if ($OnAdded) { & $OnAdded }
        }
    })

    $cc.btnFermerCatalogue.Add_Click({ $winC.Close() })

    $winC.ShowDialog() | Out-Null
}

function ConvertTo-GDMinutes([string]$dureeTxt) {
    if ([string]::IsNullOrWhiteSpace($dureeTxt)) { return 0 }
    $parts = $dureeTxt -split ' '
    if ($parts.Count -lt 2) { return 0 }
    $n = 0
    [void][int]::TryParse($parts[0], [ref]$n)
    switch ($parts[1]) {
        "Heures"   { return $n * 60 }
        "Jours"    { return $n * 1440 }
        "Semaines" { return $n * 10080 }
        default    { return 0 }
    }
}

function Format-GDDuree([int]$minutes) {
    if ($minutes -le 0) { return "0 min" }
    $h = [Math]::Floor($minutes / 60)
    $m = $minutes % 60
    if ($h -gt 0) { return "${h}h ${m}min" }
    return "${m} min"
}

function Open-Statistiques {
    $xamlStatsString2 = Apply-Theme $xamlStatsString $script:currentTheme
    [xml]$xamlS = $xamlStatsString2
    $readerS = New-Object System.Xml.XmlNodeReader $xamlS
    $winS = [Windows.Markup.XamlReader]::Load($readerS)
    if (-not $winS) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Statistiques' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerS = New-Object System.Xml.XmlNodeReader $xamlS
        $winS = [Windows.Markup.XamlReader]::Load($readerS)
        if (-not $winS) { throw "Echec du chargement de la fenetre 'Statistiques' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winS.Owner = $window
    $cs = @{}
    $xamlS.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cs[$_.Name] = $winS.FindName($_.Name)
    }

    $hist = @(Load-Json $histFile)
    $plats = Get-Platforms
    foreach ($p in $plats) {
        $file = Get-GameFile $p.Nom
        $games = @(Load-Json $file)
        $total = $games.Count
        $notes = @($games | Where-Object {
            $n = 0; [void][int]::TryParse([string]$_.Note, [ref]$n); $n -gt 0
        }).Count
        $dejaTires = @($games | Where-Object { $_.DejaFait }).Count
        $pctNotes = if ($total -gt 0) { [Math]::Round(($notes / $total) * 100) } else { 0 }
        $minutesTotal = ($hist | Where-Object { $_.Plateforme -eq $p.Nom } | ForEach-Object { ConvertTo-GDMinutes $_.Duree } | Measure-Object -Sum).Sum
        if (-not $minutesTotal) { $minutesTotal = 0 }
        $nbTirages = @($hist | Where-Object { $_.Plateforme -eq $p.Nom }).Count

        $card = New-Object System.Windows.Controls.Border
        $card.Background = ConvertTo-GDBrush ($themes[$script:currentTheme].CARD)
        $card.CornerRadius = 10
        $card.Padding = 14
        $card.Margin = '0,0,0,10'

        $stack = New-Object System.Windows.Controls.StackPanel
        $tbNom = New-Object System.Windows.Controls.TextBlock
        $tbNom.Text = "$([string]$p.Nom)$(if (-not $p.Actif) { '  (inactive)' })"
        $tbNom.FontWeight = 'Bold'
        $tbNom.FontSize = 15
        $tbNom.Foreground = ConvertTo-GDBrush ($themes[$script:currentTheme].ACCENT)
        $stack.Children.Add($tbNom) | Out-Null

        $tbDetail = New-Object System.Windows.Controls.TextBlock
        $tbDetail.Text = "$total jeu(x) au total  |  $notes note(s) ($pctNotes%)  |  $dejaTires deja tire(s) ce cycle"
        $tbDetail.Foreground = [System.Windows.Media.Brushes]::White
        $tbDetail.Margin = '0,6,0,0'
        $tbDetail.TextWrapping = 'Wrap'
        $stack.Children.Add($tbDetail) | Out-Null

        $tbTemps = New-Object System.Windows.Controls.TextBlock
        $tbTemps.Text = "$nbTirages tirage(s) enregistre(s)  |  temps suivi cumule : $(Format-GDDuree $minutesTotal)"
        $tbTemps.Foreground = ConvertTo-GDBrush ($themes[$script:currentTheme].MUTED)
        $tbTemps.FontSize = 11
        $tbTemps.Margin = '0,4,0,0'
        $tbTemps.TextWrapping = 'Wrap'
        $stack.Children.Add($tbTemps) | Out-Null

        $card.Child = $stack
        $cs.stackStats.Children.Add($card) | Out-Null
    }

    if ($plats.Count -eq 0) {
        $tbVide = New-Object System.Windows.Controls.TextBlock
        $tbVide.Text = "Aucune plateforme configuree."
        $tbVide.Foreground = [System.Windows.Media.Brushes]::White
        $cs.stackStats.Children.Add($tbVide) | Out-Null
    }

    $cs.btnFermerStats.Add_Click({ $winS.Close() })
    $winS.ShowDialog() | Out-Null
}

function Open-Backlog {
    $xamlBacklogString2 = Apply-Theme $xamlBacklogString $script:currentTheme
    [xml]$xamlB = $xamlBacklogString2
    $readerB = New-Object System.Xml.XmlNodeReader $xamlB
    $winB = [Windows.Markup.XamlReader]::Load($readerB)
    if (-not $winB) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Backlog' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerB = New-Object System.Xml.XmlNodeReader $xamlB
        $winB = [Windows.Markup.XamlReader]::Load($readerB)
        if (-not $winB) { throw "Echec du chargement de la fenetre 'Backlog' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winB.Owner = $window
    $cb = @{}
    $xamlB.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cb[$_.Name] = $winB.FindName($_.Name)
    }

    foreach ($p in (Get-Platforms | Where-Object { $_.Actif })) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = [string]$p.Nom
        $cb.cmbPlatformBacklog.Items.Add($item) | Out-Null
    }
    if ($cb.cmbPlatformBacklog.Items.Count -gt 0) { $cb.cmbPlatformBacklog.SelectedIndex = 0 }

    function script:Refresh-Backlog {
        $cb.wrapBacklog.Children.Clear()
        if (-not $cb.cmbPlatformBacklog.SelectedItem) { return }
        $platName = $cb.cmbPlatformBacklog.SelectedItem.Content
        $file = Get-GameFile $platName
        $games = @(Load-Json $file)
        foreach ($g in $games) { Ensure-GameFields $g | Out-Null }
        $filtre = $cb.txtRechercheBacklog.Text.Trim().ToLower()
        $t = $themes[$script:currentTheme]
        $icones = Get-RatingIconSet (Get-RatingIconName)
        $affiches = 0

        for ($idx = 0; $idx -lt $games.Count; $idx++) {
            $g = $games[$idx]
            $nomStr = [string]$g.Nom
            if ($filtre -and ($nomStr.ToLower() -notlike "*$filtre*")) { continue }
            $affiches++

            $note = 0
            [void][int]::TryParse([string]$g.Note, [ref]$note)
            if ($note -lt 0) { $note = 0 }
            if ($note -gt 5) { $note = 5 }

            $carte = New-Object System.Windows.Controls.Border
            $carte.Width = 148
            $carte.Margin = '0,0,14,14'
            $carte.CornerRadius = 12
            $carte.Background = ConvertTo-GDBrush $t.CARD
            $carte.Cursor = 'Hand'
            $carte.Tag = $idx
            $carte.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
                Color = [System.Windows.Media.Color]::FromRgb(0,0,0); BlurRadius = 14; ShadowDepth = 3; Opacity = 0.4
            }

            $contenu = New-Object System.Windows.Controls.StackPanel

            # Pochette (cover > icone > placeholder illustre)
            $zoneCover = New-Object System.Windows.Controls.Border
            $zoneCover.Height = 148
            $zoneCover.CornerRadius = New-Object System.Windows.CornerRadius(12,12,0,0)
            $zoneCover.ClipToBounds = $true
            $cheminCover = if ([string]$g.Cover) { [string]$g.Cover } else { [string]$g.Icone }
            $imageChargee = $false
            if ($cheminCover -and (Test-Path $cheminCover)) {
                try {
                    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                    $bmp.BeginInit()
                    $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $bmp.DecodePixelWidth = 160
                    $bmp.UriSource = New-Object System.Uri((Resolve-Path $cheminCover).Path, [System.UriKind]::Absolute)
                    $bmp.EndInit()
                    $bmp.Freeze()
                    $img = New-Object System.Windows.Controls.Image
                    $img.Source = $bmp
                    $img.Stretch = 'UniformToFill'
                    $zoneCover.Child = $img
                    $imageChargee = $true
                } catch { }
            }
            if (-not $imageChargee) {
                $zoneCover.Background = ConvertTo-GDBrush $t.INPUT
                $glyphe = New-Object System.Windows.Controls.TextBlock
                $glyphe.Text = [char]0xE7FC
                $glyphe.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
                $glyphe.FontSize = 42
                $glyphe.Foreground = ConvertTo-GDBrush $t.BORDER
                $glyphe.HorizontalAlignment = 'Center'
                $glyphe.VerticalAlignment = 'Center'
                $zoneCover.Child = $glyphe
            }
            $contenu.Children.Add($zoneCover) | Out-Null

            # Bandeau statut (deja fait / disponible)
            $bandeau = New-Object System.Windows.Controls.Border
            $bandeau.Background = if ($g.DejaFait) { ConvertTo-GDBrush $t.SUCCESS } else { ConvertTo-GDBrush $t.ACCENT }
            $bandeau.Height = 4

            $zoneTexte = New-Object System.Windows.Controls.StackPanel
            $zoneTexte.Margin = '10,8,10,10'

            $tbNom = New-Object System.Windows.Controls.TextBlock
            $tbNom.Text = $nomStr
            $tbNom.Foreground = [System.Windows.Media.Brushes]::White
            $tbNom.FontWeight = 'SemiBold'
            $tbNom.FontSize = 12
            $tbNom.TextWrapping = 'Wrap'
            $tbNom.MaxHeight = 34
            $zoneTexte.Children.Add($tbNom) | Out-Null

            $tbEtoiles = New-Object System.Windows.Controls.TextBlock
            $tbEtoiles.Text = ($icones.Filled * $note) + ($icones.Empty * (5 - $note))
            $tbEtoiles.Foreground = if ($note -ge 5) { ConvertTo-GDBrush $script:starGoldColor } else { ConvertTo-GDBrush $t.MUTED }
            $tbEtoiles.FontSize = 12
            $tbEtoiles.Margin = '0,4,0,0'
            $zoneTexte.Children.Add($tbEtoiles) | Out-Null

            $contenu.Children.Add($bandeau) | Out-Null
            $contenu.Children.Add($zoneTexte) | Out-Null
            $carte.Child = $contenu

            $carte.Add_MouseLeftButtonDown({
                $idxCarte = $this.Tag
                Invoke-Safe -Contexte "Ouvrir la fiche depuis le backlog" -Action {
                    Open-FicheJeu -PlateformeCible $platName -IndexJeu $idxCarte -OnSaved { Refresh-Backlog }
                }
            })

            $cb.wrapBacklog.Children.Add($carte) | Out-Null
        }

        $cb.lblBacklogCompte.Text = "$affiches jeu(x) affiche(s)"
    }
    Refresh-Backlog

    $cb.cmbPlatformBacklog.Add_SelectionChanged({ Refresh-Backlog })
    $cb.txtRechercheBacklog.Add_TextChanged({ Refresh-Backlog })
    $cb.btnFermerBacklog.Add_Click({ $winB.Close() })

    $winB.ShowDialog() | Out-Null
}

$controls.btnGererJeux.Add_Click({ Invoke-Safe -Contexte "Gerer les jeux" -Action { Open-GestionJeux } })
$controls.btnGererPlateformes.Add_Click({ Invoke-Safe -Contexte "Gerer les plateformes" -Action { Open-GestionPlateformes } })
$controls.btnOptions.Add_Click({ Invoke-Safe -Contexte "Options" -Action { Open-GestionOptions } })
$controls.btnStats.Add_Click({ Invoke-Safe -Contexte "Statistiques" -Action { Open-Statistiques } })
$controls.btnBacklog.Add_Click({ Invoke-Safe -Contexte "Backlog" -Action { Open-Backlog } })

$controls.btnTheme.Add_Click({ $controls.popupTheme.IsOpen = -not $controls.popupTheme.IsOpen })

function script:Switch-Theme([string]$name) {
    Write-GDLog "Clic sur le theme : $name (theme actuel avant clic : $script:currentTheme)"
    Invoke-Safe -Contexte "Changement de theme" -Action {
        $controls.popupTheme.IsOpen = $false
        Save-ThemeName $name
        $script:currentTheme = $name
        $script:reloadRequested = $true
        $window.Close()
    }
}

function script:Populate-ThemeMenu {
    $controls.stackThemeList.Children.Clear()
    foreach ($key in $script:themeOrder) {
        $t        = $themes[$key]
        $label    = $script:themeLabels[$key]
        $isActive = ($key -eq $script:currentTheme)

        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource("SecondaryButton")
        $btn.HorizontalContentAlignment = 'Stretch'
        $btn.Margin = '0,0,0,4'
        $btn.Tag = $key
        if ($isActive) {
            $btn.Background = ConvertTo-GDBrush $t.INPUT
            $btn.BorderThickness = 1
        }

        $row = New-Object System.Windows.Controls.Grid
        foreach ($w in @('Auto', '*', 'Auto')) {
            $cd = New-Object System.Windows.Controls.ColumnDefinition
            if ($w -eq '*') { $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) }
            else { $cd.Width = [System.Windows.GridLength]::Auto }
            $row.ColumnDefinitions.Add($cd) | Out-Null
        }

        $swatch = New-Object System.Windows.Shapes.Ellipse
        $swatch.Width = 14; $swatch.Height = 14
        $swatch.Fill = ConvertTo-GDBrush $t.ACCENT
        $swatch.Margin = '0,0,8,0'
        $swatch.VerticalAlignment = 'Center'
        [System.Windows.Controls.Grid]::SetColumn($swatch, 0)
        $row.Children.Add($swatch) | Out-Null

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $label
        $lbl.VerticalAlignment = 'Center'
        $lbl.FontWeight = 'SemiBold'
        [System.Windows.Controls.Grid]::SetColumn($lbl, 1)
        $row.Children.Add($lbl) | Out-Null

        if ($isActive) {
            $check = New-Object System.Windows.Controls.TextBlock
            $check.Text = [string][char]0xE73E
            $check.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
            $check.FontWeight = 'Bold'
            $check.VerticalAlignment = 'Center'
            $check.Margin = '8,0,0,0'
            $check.Foreground = ConvertTo-GDBrush $t.ACCENT
            [System.Windows.Controls.Grid]::SetColumn($check, 2)
            $row.Children.Add($check) | Out-Null
        }

        $btn.Content = $row
        $btn.Add_Click({ Switch-Theme $this.Tag })
        $controls.stackThemeList.Children.Add($btn) | Out-Null
    }
}
Populate-ThemeMenu

function script:Show-CoverJeu($jeu) {
    $chemin = ""
    if ($jeu) { $chemin = if ([string]$jeu.Cover) { [string]$jeu.Cover } else { [string]$jeu.Icone } }
    if ($chemin -and (Test-Path $chemin)) {
        try {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.DecodePixelHeight = 280
            $bmp.UriSource = New-Object System.Uri((Resolve-Path $chemin).Path, [System.UriKind]::Absolute)
            $bmp.EndInit()
            $bmp.Freeze()
            $controls.imgCoverResultat.Source = $bmp
            $controls.imgCoverResultat.Visibility = 'Visible'
            return
        } catch { }
    }
    $controls.imgCoverResultat.Visibility = 'Collapsed'
}

function script:Play-PopAnimation {
    $ease = New-Object System.Windows.Media.Animation.BackEase
    $ease.Amplitude = 0.4
    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
    $duree = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(400))

    $animX = New-Object System.Windows.Media.Animation.DoubleAnimation(0.5, 1.0, $duree)
    $animX.EasingFunction = $ease
    $animY = New-Object System.Windows.Media.Animation.DoubleAnimation(0.5, 1.0, $duree)
    $animY.EasingFunction = $ease

    $controls.lblJeuTireScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animX)
    $controls.lblJeuTireScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animY)
}

function script:Play-Confetti {
    $canvas = $controls.canvasConfetti
    $canvas.Children.Clear()
    $t = $themes[$script:currentTheme]
    $couleurs = @($t.ACCENT, $t.SUCCESS, $t.WARNING, $t.DANGER)
    $largeur = [Math]::Max(240, $canvas.ActualWidth)

    for ($i = 0; $i -lt 20; $i++) {
        $piece = New-Object System.Windows.Shapes.Rectangle
        $taille = Get-Random -Minimum 6 -Maximum 12
        $piece.Width = $taille
        $piece.Height = $taille
        $piece.RadiusX = 1
        $piece.RadiusY = 1
        $piece.Fill = ConvertTo-GDBrush ($couleurs | Get-Random)
        $piece.Opacity = 1

        $startX = Get-Random -Minimum 10 -Maximum ([int]$largeur - 10)
        [System.Windows.Controls.Canvas]::SetLeft($piece, $startX)
        [System.Windows.Controls.Canvas]::SetTop($piece, -10)
        $canvas.Children.Add($piece) | Out-Null

        $dureeMs = Get-Random -Minimum 900 -Maximum 1500
        $dureeAnim = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($dureeMs))

        $animTop = New-Object System.Windows.Media.Animation.DoubleAnimation(-10, (Get-Random -Minimum 160 -Maximum 260), $dureeAnim)
        $animLeft = New-Object System.Windows.Media.Animation.DoubleAnimation($startX, ($startX + (Get-Random -Minimum -60 -Maximum 60)), $dureeAnim)
        $animOpacity = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0, $dureeAnim)
        $animOpacity.BeginTime = [TimeSpan]::FromMilliseconds([Math]::Round($dureeMs * 0.5))

        $piece.BeginAnimation([System.Windows.Controls.Canvas]::TopProperty, $animTop)
        $piece.BeginAnimation([System.Windows.Controls.Canvas]::LeftProperty, $animLeft)
        $piece.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animOpacity)
    }
}

$controls.btnTirer.Add_Click({
  Invoke-Safe -Contexte "Lancer le tirage" -Action {
    if (-not $controls.cmbPlatform.SelectedItem) {
        [System.Windows.MessageBox]::Show("Aucune plateforme active. Utilisez 'Gerer les plateformes'.", "Info") | Out-Null
        return
    }
    $platName = $controls.cmbPlatform.SelectedItem.Content
    $file = Get-GameFile $platName
    $games = @(Load-Json $file)
    if ($games.Count -eq 0) {
        [System.Windows.MessageBox]::Show("La bibliotheque est vide. Utilisez 'Gerer les jeux' pour en ajouter.", "Info") | Out-Null
        return
    }
    $pool = $games
    if ($controls.chkEviterRepetition.IsChecked) {
        $pool = @($games | Where-Object { -not $_.DejaFait })
        if ($pool.Count -eq 0) {
            foreach ($g in $games) { $g.DejaFait = $false }
            $pool = $games
        }
    }
    $tire = $pool | Get-Random

    $objectif     = $controls.cmbObjectif.SelectedItem.Content
    $limiterTemps = $controls.chkLimiterTemps.IsChecked
    $dateDebut    = Get-Date

    # ---- Animation "roulette" : defile rapidement des noms avant de reveler
    #      le resultat final, puis seulement finalise (sauvegarde, historique,
    #      jauge de pool). Etat porte par un objet mutable (PSCustomObject)
    #      plutot que des variables $script: : un objet reste le MEME objet
    #      quelle que soit la fermeture qui le referme, ce qui evite toute
    #      ambiguite de portee entre DispatcherTimer / GetNewClosure / $script:.
    $controls.btnTirer.IsEnabled = $false
    $nomsAnim = @($games | ForEach-Object { [string]$_.Nom })
    if ($nomsAnim.Count -eq 0) { $nomsAnim = @($tire.Nom) }
    $controls.lblObjectif.Text = ""
    $controls.lblFin.Text = ""
    $controls.imgCoverResultat.Visibility = 'Collapsed'
    $controls.canvasConfetti.Children.Clear()

    $finaliser = {
        $tire.DejaFait = $true
        Save-Json $file $games

        $controls.lblJeuTire.Text = $tire.Nom
        $controls.lblObjectif.Text = "Objectif : $objectif"
        Show-CoverJeu $tire
        Play-PopAnimation
        Play-Confetti

        $dureeTxt = ""
        $dateFinTxt = ""
        if ($limiterTemps) {
            [int]$duree = 1
            [void][int]::TryParse($controls.txtDuree.Text, [ref]$duree)
            if ($duree -le 0) { $duree = 1 }
            $unite = $controls.cmbUnite.SelectedItem.Content
            $dateFin = switch ($unite) {
                "Heures"   { $dateDebut.AddHours($duree) }
                "Jours"    { $dateDebut.AddDays($duree) }
                "Semaines" { $dateDebut.AddDays($duree * 7) }
            }
            $controls.lblFin.Text = "Fin prevue le $($dateFin.ToString('dd/MM/yyyy HH:mm'))"
            $dureeTxt = "$duree $unite"
            $dateFinTxt = $dateFin.ToString("dd/MM/yyyy HH:mm")
        } else {
            $controls.lblFin.Text = "Aucune limite de temps (jouer jusqu'a atteindre l'objectif)"
        }

        $hist = @(Load-Json $histFile)
        $hist += [pscustomobject]@{
            Jeu        = $tire.Nom
            Plateforme = $platName
            DateTirage = $dateDebut.ToString("o")
            DateFin    = $dateFinTxt
            Duree      = $dureeTxt
            Objectif   = $objectif
        }
        Save-Json $histFile $hist
        Refresh-Historique
        Update-PoolStatus
        $controls.btnTirer.IsEnabled = $true
    }.GetNewClosure()

    if (Get-AnimationTirage) {
        $animEtat = [pscustomobject]@{ Ticks = 0; Max = 16 }
        $animTimer = New-Object System.Windows.Threading.DispatcherTimer
        $animTimer.Interval = [TimeSpan]::FromMilliseconds(70)
        $animTimer.Add_Tick({
            $animEtat.Ticks++
            if ($animEtat.Ticks -ge $animEtat.Max) {
                $animTimer.Stop()
                & $finaliser
            } else {
                $controls.lblJeuTire.Text = ($nomsAnim | Get-Random)
            }
        }.GetNewClosure())
        $animTimer.Start()
    } else {
        & $finaliser
    }
  }
})

$controls.btnTerminer.Add_Click({
    $controls.lblJeuTire.Text = "Aucun tirage"
    $controls.lblObjectif.Text = ""
    $controls.lblFin.Text = ""
})


    $window.ShowDialog() | Out-Null
}

$script:reloadRequested = $true
while ($script:reloadRequested) {
    $script:reloadRequested = $false
    $script:currentTheme = Get-CurrentThemeName
    $script:starGoldColor = Get-StarColor
    Update-IconUri
    Show-MainWindow
}
