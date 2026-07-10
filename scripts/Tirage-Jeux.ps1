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
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
public class GDNativeIcon {
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@
# Le processus est fondamentalement "powershell.exe" : Windows regroupe parfois
# la fenetre sous l'identite/icone de PowerShell lui-meme dans la barre des
# taches, plutot que d'utiliser l'icone propre a la fenetre WPF (comportement
# documente, cf. PowerShell/PowerShell#5013). Donner un identifiant
# d'application explicite et distinct force Windows a traiter GameDraw comme
# une application a part entiere, avec sa propre icone de barre des taches.
try { [GDNativeIcon]::SetCurrentProcessExplicitAppUserModelID("GameDraw.Application") | Out-Null } catch { }

$script:gdVersion = "Beta 0.36"


# =========================================================================
# Journalisation des erreurs (le lancement via le raccourci masque toute fenetre,
# donc toute exception silencieuse rendait l'app "figee" sans aucun message).
# =========================================================================
# =========================================================================
# Journalisation des erreurs (le lancement via le raccourci masque toute fenetre,
# donc toute exception silencieuse rendait l'app "figee" sans aucun message).
# Emplacement provisoire ici (avant que le dossier de donnees reel soit
# resolu juste plus bas) ; reaffecte ensuite pour vivre au meme endroit que
# le reste des donnees, ou qu'il se trouve.
# =========================================================================
$script:logFile = Join-Path (Join-Path $env:LOCALAPPDATA "GameDraw") "error.log"

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
        Show-GDMessageBox -Message "Une erreur est survenue ($Contexte) :`n$($_.Exception.Message)`n`nDetails enregistres dans :`n$script:logFile" -Title "GameDraw - Erreur" -Icon "Error" | Out-Null
    }
}

# Filet de securite global : Invoke-Safe protege les actions declenchees depuis
# l'interface (clics), mais tout ce qui se passe AVANT (parsing XAML, creation
# de la fenetre principale...) n'etait protege par rien - une erreur a cet
# endroit provoquait un plantage totalement silencieux (le lancement se fait
# fenetre cachee), sans aucun message ni trace. Ce "trap" attrape desormais
# n'importe quelle erreur fatale non interceptee ailleurs dans le script,
# journalise, affiche un message clair, puis quitte proprement.
trap {
    Write-GDLog "ERREUR FATALE (non interceptee) : $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try {
        Show-GDMessageBox -Message "Erreur fatale au demarrage de GameDraw :`n$($_.Exception.Message)`n`nDetails enregistres dans :`n$script:logFile" -Title "GameDraw - Erreur critique" -Icon "Error" | Out-Null
    } catch { }
    exit 1
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

# Brush degrade (couleur -> version assombrie) pour donner un peu de
# profondeur aux badges, plutot qu'un aplat de couleur plat.
function ConvertTo-GDGradientBrush([string]$hex) {
    try {
        $c = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
        $cFonce = [System.Windows.Media.Color]::FromRgb([byte]([Math]::Max(0, $c.R * 0.65)), [byte]([Math]::Max(0, $c.G * 0.65)), [byte]([Math]::Max(0, $c.B * 0.65)))
        $brush = New-Object System.Windows.Media.LinearGradientBrush
        $brush.StartPoint = New-Object System.Windows.Point(0, 0)
        $brush.EndPoint = New-Object System.Windows.Point(0, 1)
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop($c, 0))) | Out-Null
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop($cFonce, 1))) | Out-Null
        $brush.Freeze()
        return $brush
    } catch {
        return ConvertTo-GDBrush $hex
    }
}

# Calcule la couleur de texte (claire ou sombre) qui contraste le mieux avec
# une couleur de fond donnee - necessaire car un theme peut avoir a la fois
# des couleurs d'accent sombres/saturees (besoin de texte clair) et des
# couleurs pastel plus claires (besoin de texte sombre) : un seul token de
# theme ne peut pas convenir aux deux a la fois.
function Get-GDContrastText([string]$hexFond) {
    try {
        $c = [System.Windows.Media.ColorConverter]::ConvertFromString($hexFond)
        # Formule de luminance relative (W3C) simplifiee sur les canaux 0-255.
        # Constantes absolues (pas les tokens de theme) : le but ici est de
        # choisir entre clair/sombre pour CETTE couleur de fond precise,
        # independamment du token TEXT du theme (qui vaut toujours blanc pour
        # les themes sombres et ne conviendrait donc pas comme "texte sombre").
        $lum = (0.2126 * $c.R + 0.7152 * $c.G + 0.0722 * $c.B) / 255
        if ($lum -gt 0.55) {
            return "#1A1A1A"
        } else {
            return "#FFFFFF"
        }
    } catch {
        return "#FFFFFF"
    }
}

# =========================================================================
# Emplacement des donnees : configurable, pour repondre au retour utilisateur
# comme quoi un dossier directement a la racine du profil (%USERPROFILE%)
# est visible/intrusif. Un petit fichier "pointeur" dans %APPDATA% (l'endroit
# standard pour ce genre de reglage, quasiment invisible) indique OU sont
# reellement rangees les donnees ; l'emplacement par defaut est desormais
# %LOCALAPPDATA%\GameDraw (convention Windows habituelle), et peut etre
# change librement depuis Options -> Emplacement des donnees.
# =========================================================================
$script:appDataPointer = Join-Path $env:APPDATA "GameDraw\datalocation.txt"
$script:defaultDataRoot = Join-Path $env:LOCALAPPDATA "GameDraw"
$script:legacyDataRoot = Join-Path $env:USERPROFILE "GameDraw"

if (Test-Path $script:appDataPointer) {
    $root = (Get-Content $script:appDataPointer -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($root)) { $root = $script:defaultDataRoot }
} else {
    # Premier lancement avec ce mecanisme : si d'anciennes donnees existent a
    # l'ancien emplacement (racine du profil) et qu'aucune donnee n'existe
    # encore au nouvel emplacement, on migre automatiquement une seule fois
    # pour ne rien perdre - sinon on part simplement du nouvel emplacement.
    if ((Test-Path $script:legacyDataRoot) -and (-not (Test-Path $script:defaultDataRoot))) {
        try {
            New-Item -ItemType Directory -Path (Split-Path -Parent $script:defaultDataRoot) -Force -ErrorAction SilentlyContinue | Out-Null
            Move-Item -Path $script:legacyDataRoot -Destination $script:defaultDataRoot -Force
        } catch {
            # Si la migration echoue pour une raison quelconque (fichier verrouille,
            # permissions...), on continue avec l'ancien emplacement plutot que de
            # risquer une perte de donnees.
            $script:defaultDataRoot = $script:legacyDataRoot
        }
    }
    $root = $script:defaultDataRoot
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $script:appDataPointer) -Force -ErrorAction SilentlyContinue | Out-Null
        Set-Content -Path $script:appDataPointer -Value $root -Encoding UTF8
    } catch { }
}
if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
$script:root = $root
$script:logFile = Join-Path $root "error.log"

$platformFile = Join-Path $root "platforms.json"
$histFile     = Join-Path $root "historique.json"

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = Split-Path -Parent $scriptRoot

# Icones d'application disponibles (fichier .ico + apercu .png pour le picker
# dans Options, egalement reutilise comme logo dans l'en-tete de l'appli pour
# que l'icone choisie soit coherente partout, pas seulement sur la fenetre).
# "Original" = icone/logo historique du projet. La config n'existe pas encore
# a ce stade du script (Get-GDConfig est definie plus bas) : on se contente
# ici de preparer les donnees et une valeur par defaut ; le calcul reel se
# fait via Update-IconUri, appelee juste avant l'affichage de chaque fenetre
# (boucle de rechargement).
$script:iconChoices = @{
    Original = @{ Nom = "Original";        Ico = "GameDraw_v2.ico";           Preview = "GameDraw_v2.ico";                    HeaderLogo = "GameDraw_logo.png" }
    Bleu     = @{ Nom = "Bleu (carnet)";    Ico = "GameDraw_icon_bleu.ico";    Preview = "GameDraw_icon_bleu_preview.png";     HeaderLogo = "GameDraw_icon_bleu_preview.png" }
    Sombre   = @{ Nom = "Sombre (neon)";    Ico = "GameDraw_icon_sombre.ico";  Preview = "GameDraw_icon_sombre_preview.png";   HeaderLogo = "GameDraw_icon_sombre_preview.png" }
}
$iconPath = Join-Path $packageRoot ("assets\" + $script:iconChoices["Original"].Ico)
$iconUri  = ([Uri]$iconPath).AbsoluteUri
$logoPath = Join-Path $packageRoot ("assets\" + $script:iconChoices["Original"].HeaderLogo)
$logoUri  = ([Uri]$logoPath).AbsoluteUri
function Update-IconUri {
    $cfg = Get-GDConfig
    $choix = $cfg.IconeApp
    if ($choix -eq "Personnalise" -and $cfg.IconePersonnaliseChemin -and (Test-Path $cfg.IconePersonnaliseChemin)) {
        $script:iconPath = $cfg.IconePersonnaliseChemin
        $script:iconUri  = ([Uri]$script:iconPath).AbsoluteUri
        $script:logoPath = $cfg.IconePersonnaliseChemin
        $script:logoUri  = ([Uri]$script:logoPath).AbsoluteUri
        return
    }
    if (-not $choix -or -not $script:iconChoices.ContainsKey($choix)) { $choix = "Original" }
    $script:iconPath = Join-Path $packageRoot ("assets\" + $script:iconChoices[$choix].Ico)
    $script:iconUri  = ([Uri]$script:iconPath).AbsoluteUri
    $script:logoPath = Join-Path $packageRoot ("assets\" + $script:iconChoices[$choix].HeaderLogo)
    $script:logoUri  = ([Uri]$script:logoPath).AbsoluteUri
}

# Fondu doux a l'ouverture de n'importe quelle fenetre : simple, sans risque
# (une seule DoubleAnimation sur Opacity), applique de la meme facon partout.
function Enable-GDFadeIn($win) {
    $win.Opacity = 0
    $win.Add_Loaded({
        $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(200))))
        $this.BeginAnimation([System.Windows.Window]::OpacityProperty, $anim)

        # Bug Windows 11 documente (dotnet/wpf #11308) : si la fenetre met du
        # temps a apparaitre apres le demarrage du script (notre cas : XAML +
        # JSON charges avant la 1ere fenetre), la barre des taches prend un
        # instantane avec l'icone par defaut AVANT que la vraie icone soit
        # appliquee, et ne se rafraichit jamais toute seule ensuite - meme si
        # l'icone de la barre de titre, elle, est correcte. Reaffecter l'icone
        # ici (passer par $null d'abord, WPF ignore une reaffectation avec la
        # meme valeur) force Windows a la reprendre en compte pour la barre
        # des taches.
        $iconActuelle = $this.Icon
        $this.Icon = $null
        $this.Icon = $iconActuelle

        # Renfort : si le tour ci-dessus ne suffit pas (le comportement varie
        # selon les machines), on envoie directement le message Windows natif
        # WM_SETICON (0x0080) a la fenetre, avec ICON_SMALL (0) et ICON_BIG (1) -
        # c'est la methode la plus directe/fiable, independante des subtilites
        # internes de propagation de la propriete Icon de WPF.
        try {
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($this)).Handle
            if ($hwnd -ne [IntPtr]::Zero -and $script:iconPath -and (Test-Path $script:iconPath)) {
                $hIcon = [IntPtr]::Zero
                try {
                    $icoNative = New-Object System.Drawing.Icon($script:iconPath)
                    $hIcon = $icoNative.Handle
                } catch {
                    # Le fichier n'est pas un .ico valide (ex. icone personnalisee
                    # en .png/.jpg) : on extrait une icone depuis le bitmap a la place.
                    $bmpNative = New-Object System.Drawing.Bitmap($script:iconPath)
                    $hIcon = $bmpNative.GetHicon()
                }
                if ($hIcon -ne [IntPtr]::Zero) {
                    [GDNativeIcon]::SendMessage($hwnd, 0x0080, [IntPtr]0, $hIcon) | Out-Null
                    [GDNativeIcon]::SendMessage($hwnd, 0x0080, [IntPtr]1, $hIcon) | Out-Null
                }
            }
        } catch {
            Write-GDLog "AVERTISSEMENT : rafraichissement natif de l'icone (WM_SETICON) echoue : $($_.Exception.Message)"
        }
    })
}

# Cable le glissement de fenetre, le double-clic pour maximiser/restaurer et
# les 3 boutons (reduire/agrandir/fermer) de la barre de titre personnalisee.
# Partagee entre les 8 fenetres pour eviter de dupliquer cette logique.
# DragMove() leve une exception si la fenetre est deja maximisee, d'ou la garde.
function Enable-GDTitleBar($win, $ctrl) {
    $ctrl.titleBar.Add_MouseLeftButtonDown({
        $e = $args[1]
        if ($e.ClickCount -eq 2) {
            $win.WindowState = if ($win.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
        } elseif ($win.WindowState -eq 'Normal') {
            $win.DragMove()
        }
    }.GetNewClosure())
    $ctrl.btnMinimiser.Add_Click({ $win.WindowState = 'Minimized' }.GetNewClosure())
    $ctrl.btnMaximiser.Add_Click({
        $win.WindowState = if ($win.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' }
    }.GetNewClosure())
    $ctrl.btnFermerFenetre.Add_Click({ $win.Close() }.GetNewClosure())
    $win.Add_StateChanged({
        $ctrl.btnMaximiser.Content = if ($win.WindowState -eq 'Maximized') { [char]0xE923 } else { [char]0xE922 }
    }.GetNewClosure())
    # Echap ferme les fenetres secondaires (pas la fenetre principale, pour
    # eviter de quitter l'appli par accident) - raccourci clavier attendu
    # pour n'importe quelle boite de dialogue/fenetre secondaire.
    $win.Add_KeyDown({
        $e = $args[1]
        if ($e.Key -eq 'Escape' -and $win -ne $script:window) { $win.Close() }
    }.GetNewClosure())
}

# Remplace [System.Windows.MessageBox]::Show par une fenetre themee (le natif
# est une boite de dialogue Windows, impossible a recolorer). Meme convention
# d'appel/retour que MessageBox.Show pour rendre le remplacement mecanique :
# -Buttons parmi OK/OKCancel/YesNo/YesNoCancel, -Icon parmi
# Information/Warning/Error/Question ; retourne 'OK'/'Cancel'/'Yes'/'No' en
# String, comparable directement comme avant ($resultat -eq 'Yes').
# Pas de barre de titre personnalisee ici (delibere) : ce composant doit etre
# fiable a 100% partout dans l'appli, la bordure Windows native du haut est un
# compromis raisonnable face a la complexite/risque de WindowChrome pour un
# simple dialogue d'alerte modal.
function script:Show-GDMessageBox {
    param(
        [string]$Message,
        [string]$Title = "GameDraw",
        [string]$Buttons = "OK",
        [string]$Icon = "Information"
    )

    $t = $themes[$script:currentTheme]
    $couleurIcone = switch ($Icon) {
        "Error"   { $t.DANGER }
        "Warning" { $t.WARNING }
        "Question" { $t.ACCENT }
        default   { $t.ACCENT }
    }
    $glypheIcone = switch ($Icon) {
        "Error"    { "X" }
        "Warning"  { "!" }
        "Question" { "?" }
        default    { "i" }
    }

    $xamlMsgBox = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" SizeToContent="Height" Width="440" MinWidth="380"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner" ResizeMode="NoResize"
        Background="{{BG}}" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="18,9"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Margin" Value="8,0,0,0"/>
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
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}" BorderBrush="{{BORDER}}" BorderThickness="1">
        <Grid Margin="24">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,20" VerticalAlignment="Top">
                <Border Width="40" Height="40" CornerRadius="20" Margin="0,0,16,0" VerticalAlignment="Top" Background="$couleurIcone">
                    <TextBlock Text="$glypheIcone" FontSize="17" FontWeight="Bold" Foreground="{{DARKBG}}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <TextBlock Name="tbMessageDialogue" FontSize="13" Foreground="{{TEXT}}" TextWrapping="Wrap" VerticalAlignment="Center" Width="320"/>
            </StackPanel>
            <StackPanel Grid.Row="1" Name="stackBoutonsDialogue" Orientation="Horizontal" HorizontalAlignment="Right"/>
        </Grid>
    </Border>
</Window>
"@
    $xamlMsgBox2 = Apply-Theme $xamlMsgBox $script:currentTheme
    [xml]$xamlMB = $xamlMsgBox2
    $readerMB = New-Object System.Xml.XmlNodeReader $xamlMB
    $winMB = [Windows.Markup.XamlReader]::Load($readerMB)
    if (-not $winMB) {
        Start-Sleep -Milliseconds 150
        $readerMB = New-Object System.Xml.XmlNodeReader $xamlMB
        $winMB = [Windows.Markup.XamlReader]::Load($readerMB)
        if (-not $winMB) { return "OK" }
    }
    if ($script:window) { $winMB.Owner = $script:window }
    Enable-GDFadeIn $winMB
    $script:gdMsgBoxWin = $winMB
    $cmb = @{}
    $xamlMB.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cmb[$_.Name] = $winMB.FindName($_.Name)
    }
    $cmb.tbMessageDialogue.Text = $Message

    $script:gdMsgBoxResultat = "OK"
    $ajouterBouton = {
        param($libelle, $valeurRetour, $estSecondaire)
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $libelle
        $btn.MinWidth = 90
        if ($estSecondaire) { $btn.Style = $winMB.Resources["SecondaryButton"] }
        $btn.Tag = $valeurRetour
        $btn.Add_Click({
            $script:gdMsgBoxResultat = $this.Tag
            $script:gdMsgBoxWin.Close()
        })
        $cmb.stackBoutonsDialogue.Children.Add($btn) | Out-Null
    }

    switch ($Buttons) {
        "OKCancel"     { & $ajouterBouton "Annuler" "Cancel" $true; & $ajouterBouton "OK" "OK" $false }
        "YesNo"        { & $ajouterBouton "Non" "No" $true; & $ajouterBouton "Oui" "Yes" $false }
        "YesNoCancel"  { & $ajouterBouton "Annuler" "Cancel" $true; & $ajouterBouton "Non" "No" $true; & $ajouterBouton "Oui" "Yes" $false }
        default        { & $ajouterBouton "OK" "OK" $false }
    }

    $winMB.ShowDialog() | Out-Null
    return $script:gdMsgBoxResultat
}
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
    foreach ($champ in @("Cover", "Logo", "Screenshot", "Icone", "Commentaire", "Tags", "Description")) {
        if (-not (Get-Member -InputObject $g -Name $champ -MemberType NoteProperty)) {
            $g | Add-Member -MemberType NoteProperty -Name $champ -Value "" -Force
        }
    }
    if (-not (Get-Member -InputObject $g -Name "Statut" -MemberType NoteProperty)) {
        # Migration : les jeux existants n'avaient que DejaFait (bool). On en
        # deduit un statut de depart raisonnable, librement modifiable ensuite.
        $statutInitial = if ($g.DejaFait) { "Termine" } else { "NonCommence" }
        $g | Add-Member -MemberType NoteProperty -Name "Statut" -Value $statutInitial -Force
    }
    return $g
}

# Definitions des statuts possibles : cle interne, libelle, couleur (cle du
# theme actif). Badge = pastille pleine coloree (caractere simple et fiable,
# aucune dependance a un glyphe Segoe Fluent non confirme) + texte.
$script:statutsJeu = @{
    NonCommence = @{ Label = "Non commence"; CouleurCle = "MUTED" }
    EnCours     = @{ Label = "En cours";     CouleurCle = "ACCENT" }
    EnPause     = @{ Label = "En pause";     CouleurCle = "WARNING" }
    Termine     = @{ Label = "Termine";      CouleurCle = "SUCCESS" }
    Abandonne   = @{ Label = "Abandonne";    CouleurCle = "DANGER" }
}
$script:statutsOrdre = @("NonCommence", "EnCours", "EnPause", "Termine", "Abandonne")

function Get-StatutsPersonnalises { return @((Get-GDConfig).StatutsPersonnalises) }
function Save-StatutsPersonnalises([array]$liste) { Set-GDConfig @{ StatutsPersonnalises = @($liste) } }
function Get-StatutsMasques { return @((Get-GDConfig).StatutsMasques) }
function Save-StatutsMasques([array]$liste) { Set-GDConfig @{ StatutsMasques = @($liste) } }
function Get-IconesNotationMasquees { return @((Get-GDConfig).IconesNotationMasquees) }
function Save-IconesNotationMasquees([array]$liste) { Set-GDConfig @{ IconesNotationMasquees = @($liste) } }
function Get-StyleAnimationTirage {
    $v = (Get-GDConfig).StyleAnimationTirage
    if ($v -ne "Roue" -and $v -ne "Bandeau" -and $v -ne "Machine") { return "Roue" }
    return $v
}
function Save-StyleAnimationTirage([string]$style) { Set-GDConfig @{ StyleAnimationTirage = $style } }
function Get-SteamApiKey { return [string](Get-GDConfig).SteamApiKey }
function Save-SteamApiKey([string]$cle) { Set-GDConfig @{ SteamApiKey = $cle } }
function Get-SteamId64 { return [string](Get-GDConfig).SteamId64 }
function Save-SteamId64([string]$id) { Set-GDConfig @{ SteamId64 = $id } }

# Fusionne les 5 statuts integres (couleur liee au theme actif, s'adapte donc
# automatiquement) avec les statuts personnalises ajoutes par l'utilisateur
# (couleur fixe choisie a la creation) - retourne une liste ordonnee unique,
# chaque element ayant Cle/Label/CouleurResolue (deja un hex utilisable).
# Les statuts masques (Options) sont exclus, sauf si -InclureMasques est
# passe (necessaire par ex. pour continuer a afficher correctement un jeu
# deja affecte a un statut entre-temps masque).
function Get-TousLesStatuts([switch]$InclureMasques) {
    $masques = @(Get-StatutsMasques)
    $liste = @()
    foreach ($cle in $script:statutsOrdre) {
        if (-not $InclureMasques -and $masques -contains $cle) { continue }
        $info = $script:statutsJeu[$cle]
        $liste += [pscustomobject]@{ Cle = $cle; Label = $info.Label; CouleurResolue = $themes[$script:currentTheme][$info.CouleurCle] }
    }
    foreach ($perso in (Get-StatutsPersonnalises)) {
        if (-not $InclureMasques -and $masques -contains [string]$perso.Cle) { continue }
        $liste += [pscustomobject]@{ Cle = [string]$perso.Cle; Label = [string]$perso.Label; CouleurResolue = [string]$perso.Couleur }
    }
    return $liste
}

# Dossier des images par jeu : <dossier de donnees>\images\<plateforme>\<jeu>\<slot>.<ext>
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
function Get-PlatformImageFolder([string]$platformName) {
    $platDir = Join-Path $root "images"
    return Join-Path $platDir ($platformName -replace '[^a-zA-Z0-9_\-]', '_')
}

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
$sessionFile = Join-Path $root "session.json"

# Etat du dernier tirage / compte a rebours, persiste sur DISQUE plutot qu'en
# memoire de script : survit non seulement aux changements de theme (qui
# recreent la fenetre) mais aussi a une fermeture/relance complete de l'appli.
# Elimine aussi definitivement tout risque lie aux fermetures PowerShell
# (GetNewClosure() copie la portee - une lecture/ecriture disque n'a pas ce
# probleme puisqu'elle ne depend d'aucune portee de variable).
function script:Sauvegarder-SessionTirage($etat) {
    try { $etat | ConvertTo-Json -Depth 6 | Set-Content -Path $sessionFile -Encoding UTF8 } catch { }
}
function script:Charger-SessionTirage {
    try {
        if (Test-Path $sessionFile) { return Get-Content $sessionFile -Raw -Encoding UTF8 | ConvertFrom-Json }
    } catch { }
    return $null
}
function script:Effacer-SessionTirage {
    try { if (Test-Path $sessionFile) { Remove-Item $sessionFile -Force } } catch { }
}


$themes = @{
    "Catppuccin" = @{
        ACCENT  = "#89B4FA"; SUCCESS = "#A6E3A1"; BG = "#181825"; CARD = "#3E3E4B"
        INPUT   = "#313244"; BORDER  = "#5F6171"; DARKBG = "#11111B"; MUTED = "#BAC2DE"
        DANGER  = "#F38BA8"; WARNING = "#F9E2AF"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Ocarina of Time : bois/cuir du menu (bruns), or de la Triforce et des
    # rubis, vert Kokiri pour la magie/succes, bleu Navi/Zora en accent info,
    # rouge pour le danger (coeurs).
    "Ocarina" = @{
        ACCENT  = "#D4AF37"; SUCCESS = "#4C8C4A"; BG = "#1B1710"; CARD = "#443E34"
        INPUT   = "#3A2F1D"; BORDER  = "#706044"; DARKBG = "#100D08"; MUTED = "#C9B896"
        DANGER  = "#D15151"; WARNING = "#5FA8D3"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    "Cyberpunk" = @{
        ACCENT  = "#FCEE0A"; SUCCESS = "#00E5A0"; BG = "#0D0D0D"; CARD = "#383838"
        INPUT   = "#262626"; BORDER  = "#5B5B5B"; DARKBG = "#000000"; MUTED = "#9E9E9E"
        DANGER  = "#FF003C"; WARNING = "#FCEE0A"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    "Foret" = @{
        ACCENT  = "#57A773"; SUCCESS = "#A3D9A5"; BG = "#132A1E"; CARD = "#334F3E"
        INPUT   = "#254A34"; BORDER  = "#487559"; DARKBG = "#0D1F16"; MUTED = "#C7DCC9"
        DANGER  = "#D9534F"; WARNING = "#E0C05C"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Dracula : palette officielle, tres appreciee des devs
    "Dracula" = @{
        ACCENT  = "#BD93F9"; SUCCESS = "#50FA7B"; BG = "#282A36"; CARD = "#4A4D5A"
        INPUT   = "#3B3F51"; BORDER  = "#6F7180"; DARKBG = "#191A21"; MUTED = "#F8F8F2"
        DANGER  = "#FF5555"; WARNING = "#F1FA8C"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # The Witcher : acier/argent du medaillon du Loup et des epees en accent
    # (pas d'or/jaune - trop proche du Cyberpunk ci-dessus), cuir et bois
    # sombres en fond, vert des potions/toxicite en succes, rouge sang
    # affirme en danger (signature visuelle forte de la saga).
    "Witcher" = @{
        ACCENT  = "#A9B4BC"; SUCCESS = "#5A8448"; BG = "#15120F"; CARD = "#3E3A37"
        INPUT   = "#2C2520"; BORDER  = "#655D56"; DARKBG = "#0C0A08"; MUTED = "#A79C8C"
        DANGER  = "#DF3939"; WARNING = "#B08D57"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Pip-Boy (Fallout) : terminal phosphore vert monochrome
    "PipBoy" = @{
        ACCENT  = "#41FF00"; SUCCESS = "#7CFF3D"; BG = "#0A0F0A"; CARD = "#323C32"
        INPUT   = "#16260F"; BORDER  = "#4B633E"; DARKBG = "#050805"; MUTED = "#8FCB6B"
        DANGER  = "#FF3B30"; WARNING = "#FFD500"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Super Mario : le vrai duo iconique bleu salopette + rouge (chemise/casquette),
    # vert Luigi/tuyau en succes, orange Bowser en danger, or des pieces en warning
    "Mario" = @{
        ACCENT  = "#F13A37"; SUCCESS = "#43B047"; BG = "#0F2A66"; CARD = "#304D90"
        INPUT   = "#25499C"; BORDER  = "#4C71C5"; DARKBG = "#081736"; MUTED = "#CFE0FF"
        DANGER  = "#F26522"; WARNING = "#FBD000"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Dragon : antre obscur, ecailles, feu et tresor
    "Dragon" = @{
        ACCENT  = "#FF6B1A"; SUCCESS = "#2E8B57"; BG = "#160B0B"; CARD = "#453636"
        INPUT   = "#341818"; BORDER  = "#7D5151"; DARKBG = "#0D0606"; MUTED = "#D9B08C"
        DANGER  = "#DC3E2D"; WARNING = "#FFB627"; TEXT    = "#FFFFFF"; GLOW = "#000000"
    }
    # Blanc Premium : theme clair, base sur la charte graphique fournie
    # (fond blanc pur, surfaces tres legerement teintees, accents pastel vifs
    # indigo/vert/orange/rose). DARKBG sert ici de couleur de texte POUR les
    # boutons a fond ACCENT (indigo assez sature pour justifier du blanc par-
    # dessus, malgre le nom du token qui suggere plutot un fond sombre).
    "Clair" = @{
        ACCENT  = "#6366F1"; SUCCESS = "#22C55E"; BG = "#FFFFFF"; CARD = "#F8FAFC"
        INPUT   = "#F1F5F9"; BORDER  = "#E5E7EB"; DARKBG = "#FFFFFF"; MUTED = "#64748B"
        DANGER  = "#B91365"; WARNING = "#F59E0B"; TEXT    = "#0F172A"; GLOW = "#000000"
    }
    # Sombre Premium : esthetique "dark UI" moderne authentique (dans l'esprit
    # Vercel/Linear/Discord) plutot qu'un simple dark mode generique - fond
    # quasi noir, carte tres proche du fond (volontairement subtil, comme pour
    # Blanc Premium : la definition vient de la bordure + du halo colore, pas
    # d'un grand ecart de luminosite), accent electrique qui ressort net sur
    # ce fond tres sombre.
    "SombrePremium" = @{
        ACCENT  = "#818CF8"; SUCCESS = "#4ADE80"; BG = "#09090B"; CARD = "#18181B"
        INPUT   = "#101012"; BORDER  = "#27272A"; DARKBG = "#0A0A0F"; MUTED = "#A1A1AA"
        DANGER  = "#F472B6"; WARNING = "#FBBF24"; TEXT    = "#F4F4F5"; GLOW = "#818CF8"
    }
}
$script:themeOrder = @("Catppuccin", "Ocarina", "Cyberpunk", "Foret", "Dracula", "Witcher", "PipBoy", "Mario", "Dragon", "Clair", "SombrePremium")
$script:themeLabels = @{
    Catppuccin = "Catppuccin"
    Ocarina    = "Ocarina of Time"
    Cyberpunk  = "Cyberpunk"
    Foret      = "Foret"
    Dracula    = "Dracula"
    Witcher    = "The Witcher"
    PipBoy     = "Pip-Boy"
    Mario      = "Super Mario"
    Dragon     = "Dragon"
    Clair      = "Blanc Premium"
    SombrePremium = "Sombre Premium"
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
    IconePersonnaliseChemin = ""
    RawgApiKey = ""
    ObjectifsListe = @("Terminer l'histoire", "Finir a 100%", "Libre (sans objectif precis)")
    AvertirNouveauTirage = $true
    NotifierFinSession = $true
    StatutsPersonnalises = @()
    StatutsMasques = @()
    IconesNotationMasquees = @()
    StyleAnimationTirage = "Roue"
    SteamApiKey = ""
    SteamId64 = ""
    BoutonsMasques         = @()
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
function Get-IconApp          { $v = (Get-GDConfig).IconeApp; if ($v -eq "Personnalise") { return $v }; if (-not $v -or -not $script:iconChoices.ContainsKey($v)) { return "Original" }; return $v }
function Get-BoutonsMasques   { $v = (Get-GDConfig).BoutonsMasques; if (-not $v) { return @() }; return @($v) }
function Set-BoutonsMasques([array]$liste) { Set-GDConfig @{ BoutonsMasques = @($liste) } }
function Get-RawgApiKey { return [string](Get-GDConfig).RawgApiKey }
function Save-RawgApiKey([string]$cle) { Set-GDConfig @{ RawgApiKey = $cle } }
function Get-ObjectifsListe {
    $v = (Get-GDConfig).ObjectifsListe
    if (-not $v -or @($v).Count -eq 0) { return @("Terminer l'histoire", "Finir a 100%", "Libre (sans objectif precis)") }
    return @($v)
}
function Save-ObjectifsListe([array]$liste) { Set-GDConfig @{ ObjectifsListe = @($liste) } }
function Get-AvertirNouveauTirage { return [bool](Get-GDConfig).AvertirNouveauTirage }
function Save-AvertirNouveauTirage([bool]$val) { Set-GDConfig @{ AvertirNouveauTirage = $val } }
function Get-NotifierFinSession { return [bool](Get-GDConfig).NotifierFinSession }
function Save-NotifierFinSession([bool]$val) { Set-GDConfig @{ NotifierFinSession = $val } }
function Save-IconApp([string]$choix) { Set-GDConfig @{ IconeApp = $choix } }
function Save-ThemeName([string]$name)      { Set-GDConfig @{ Theme = $name } }
function Save-StarColor([string]$hex)       { Set-GDConfig @{ CouleurEtoiles = $hex } }
function Save-RatingIconName([string]$name) { Set-GDConfig @{ IconeNotation = $name } }


# Jeux de caracteres disponibles pour representer la notation (rempli / vide).
# On passe par ConvertFromUtf32 pour les emoji hors du plan de base (surrogate
# pairs), plus fiable qu'un simple cast [char] qui echoue au-dela de U+FFFF.
function Get-RatingIconSet([string]$name) {
    $policeFluent = "Segoe Fluent Icons, Segoe MDL2 Assets, Segoe UI"
    $policeNormale = "Segoe UI"
    switch ($name) {
        # Codes verifies aupres de la documentation officielle Microsoft
        # (learn.microsoft.com/.../segoe-fluent-icons-font) : FavoriteStar/
        # FavoriteStarFill, Like confirmes explicitement ; la paire coeur
        # (EB51/EB52) est confirmee via l'exemple officiel de superposition
        # de glyphes ("black outline drawn on top of the zero-width red
        # heart"). Trophee/Diamant n'ont pas de code fiable trouve : gardes
        # en emoji plutot que de risquer un carre vide (tofu).
        "Coeur"   { return @{ Nom = "Coeur";   Filled = [string][char]0xEB52; Empty = [string][char]0xEB51; Police = $policeFluent } }
        "Pouce"   { return @{ Nom = "Pouce";   Filled = [string][char]0xE8E1; Empty = [string][char]0x25CB; Police = $policeFluent } }
        "Trophee" { return @{ Nom = "Trophee"; Filled = [System.Char]::ConvertFromUtf32(0x1F3C6); Empty = [string][char]0x25CB; Police = $policeNormale } }
        "Diamant" { return @{ Nom = "Diamant"; Filled = [System.Char]::ConvertFromUtf32(0x1F48E); Empty = [string][char]0x25C7; Police = $policeNormale } }
        default   { return @{ Nom = "Etoile";  Filled = [string][char]0xE735; Empty = [string][char]0xE734; Police = $policeFluent } }
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
# Bloc XAML partage (style ComboBox + ComboBoxItem) reutilise dans toutes
# les fenetres secondaires, pour eviter de dupliquer ~70 lignes identiques
# a chaque fenetre (optimisation / maintenabilite).
$xamlComboBoxBlock = @'
        <Style x:Key="ComboBoxItemStyle" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{{ACCENT}}"/>
                    <Setter Property="Foreground" Value="{{DARKBG}}"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{{BORDER}}"/>
                    <Setter Property="Foreground" Value="{{TEXT}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="ItemContainerStyle" Value="{StaticResource ComboBoxItemStyle}"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
                                              TextBlock.Foreground="{{TEXT}}"/>
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
'@

# Bloc XAML partage de la barre de titre personnalisee, reutilise dans les 8
# fenetres (WindowChrome, CaptionHeight=0). Here-string DOUBLE-quotee (pas
# simple-quotee comme le bloc ComboBox) car $logoUri doit etre interpole ici ;
# {{CLE}} reste bien litteral car sans prefixe $, non touche par
# l'interpolation, et sera remplace plus tard par Apply-Theme comme d'habitude.
$xamlTitleBarBlock = @"
        <Grid Grid.Row="0" Name="titleBar" Background="{{DARKBG}}" Height="36" shell:WindowChrome.IsHitTestVisibleInChrome="True">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal" Margin="12,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False">
                <Image Source="$logoUri" Width="16" Height="16" Margin="0,0,8,0" RenderOptions.BitmapScalingMode="HighQuality" Stretch="Uniform"/>
                <TextBlock Text="{Binding RelativeSource={RelativeSource AncestorType=Window}, Path=Title}" Foreground="{{MUTED}}" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>
            </StackPanel>
            <Button Grid.Column="1" Name="btnMinimiser" Content="&#xE921;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10"
                    Width="46" Height="36" Background="Transparent" Foreground="{{MUTED}}" BorderThickness="0" Cursor="Arrow">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
            <Button Grid.Column="2" Name="btnMaximiser" Content="&#xE922;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10"
                    Width="46" Height="36" Background="Transparent" Foreground="{{MUTED}}" BorderThickness="0" Cursor="Arrow">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
            <Button Grid.Column="3" Name="btnFermerFenetre" Content="&#xE8BB;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10"
                    Width="46" Height="36" Background="Transparent" Foreground="{{MUTED}}" BorderThickness="0" Cursor="Arrow">
                <Button.Template>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{DANGER}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Button.Template>
            </Button>
        </Grid>
"@



$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="GameDraw - Theme : $script:currentTheme" Height="860" Width="1050" MinHeight="700" MinWidth="900"
        Icon="$iconUri"
        WindowStartupLocation="CenterScreen"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>

        <Style x:Key="CardStyle" TargetType="Border">
            <Setter Property="Background" Value="{{CARD}}"/>
            <Setter Property="CornerRadius" Value="14"/>
            <Setter Property="Padding" Value="18"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="Effect">
                <Setter.Value>
                    <DropShadowEffect Color="{{GLOW}}" BlurRadius="22" ShadowDepth="4" Direction="270" Opacity="0.32"/>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>

$xamlComboBoxBlock
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{{DARKBG}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,2">
                            <ContentPresenter TextBlock.Foreground="{{TEXT}}" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
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

    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="24">
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
                    <TextBlock Text="&#xE9F9;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" VerticalAlignment="Center"/>
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
                <TextBlock Text="PARAMETRES DU TIRAGE" Foreground="{{TEXT}}" FontWeight="Bold" FontSize="14" Margin="0,0,0,14"/>
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
                                <ComboBoxItem Content="Minutes"/>
                                <ComboBoxItem Content="Heures"/>
                                <ComboBoxItem Content="Jours" IsSelected="True"/>
                                <ComboBoxItem Content="Semaines"/>
                            </ComboBox>
                        </StackPanel>
                    </StackPanel>

                    <StackPanel Grid.Column="3">
                        <Label Content="MODE DE FIN VISE"/>
                        <ComboBox Name="cmbObjectif" Height="38"/>
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
                    <StackPanel VerticalAlignment="Top" Margin="0,10,0,0">
                        <TextBlock Text="RESULTAT DU TIRAGE" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" HorizontalAlignment="Center"/>
                        <Grid Name="rouletteWheelContainer" Width="220" Height="230" HorizontalAlignment="Center" Margin="0,10,0,10" Visibility="Collapsed">
                            <Canvas Name="rouletteWheelCanvas" Width="220" Height="220" VerticalAlignment="Top" RenderTransformOrigin="0.5,0.5">
                                <Canvas.RenderTransform>
                                    <RotateTransform x:Name="rouletteRotate" Angle="0"/>
                                </Canvas.RenderTransform>
                                <Canvas.Effect>
                                    <DropShadowEffect Color="#000000" BlurRadius="20" ShadowDepth="0" Opacity="0.4"/>
                                </Canvas.Effect>
                            </Canvas>
                            <Path Data="M 0,0 L 13,20 L -13,20 Z" Fill="{{ACCENT}}" Stretch="Fill" Width="26" Height="20"
                                  HorizontalAlignment="Center" VerticalAlignment="Top" Margin="0,-4,0,0">
                                <Path.Effect>
                                    <DropShadowEffect Color="#000000" BlurRadius="6" ShadowDepth="1" Opacity="0.5"/>
                                </Path.Effect>
                            </Path>
                            <Ellipse Width="66" Height="66" VerticalAlignment="Top" Margin="0,77,0,0" Fill="{{CARD}}" Stroke="{{BORDER}}" StrokeThickness="2"/>
                            <Image Source="$logoUri" Width="42" Height="42" VerticalAlignment="Top" Margin="0,89,0,0" Stretch="Uniform"/>
                        </Grid>
                        <Border Name="reelViewport" Height="50" ClipToBounds="True" Margin="0,14,0,6" Visibility="Collapsed">
                            <StackPanel Name="reelStrip" Orientation="Vertical" HorizontalAlignment="Center"/>
                        </Border>
                        <Border Name="slotMachineContainer" Visibility="Collapsed" Margin="0,14,0,6" Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="10" Padding="18,14" HorizontalAlignment="Center">
                            <StackPanel Orientation="Horizontal">
                                <Border Background="{{INPUT}}" CornerRadius="8" Width="60" Height="60" Margin="0,0,10,0">
                                    <TextBlock Name="tbSlot1" Text="&#x2680;" FontSize="34" Foreground="{{ACCENT}}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <Border Background="{{INPUT}}" CornerRadius="8" Width="60" Height="60" Margin="0,0,10,0">
                                    <TextBlock Name="tbSlot2" Text="&#x2680;" FontSize="34" Foreground="{{ACCENT}}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <Border Background="{{INPUT}}" CornerRadius="8" Width="60" Height="60">
                                    <TextBlock Name="tbSlot3" Text="&#x2680;" FontSize="34" Foreground="{{ACCENT}}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                            </StackPanel>
                        </Border>
                        <TextBlock Name="lblJeuTire" Text="Aucun tirage" FontSize="26" FontWeight="Bold" Foreground="{{ACCENT}}"
                                   TextWrapping="Wrap" HorizontalAlignment="Center" TextAlignment="Center" Margin="0,14,0,6"
                                   RenderTransformOrigin="0.5,0.5">
                            <TextBlock.RenderTransform>
                                <ScaleTransform x:Name="lblJeuTireScale" ScaleX="1" ScaleY="1"/>
                            </TextBlock.RenderTransform>
                        </TextBlock>
                        <Image Name="imgCoverResultat" Height="140" Stretch="Uniform" Margin="0,4,0,8" Visibility="Hidden" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        <TextBlock Name="lblObjectif" Text="" FontSize="13" FontWeight="Bold" Foreground="{{WARNING}}" HorizontalAlignment="Center" Margin="0,0,0,4"/>
                        <TextBlock Name="lblFin" Text="" FontSize="13" Foreground="{{TEXT}}" HorizontalAlignment="Center" TextWrapping="Wrap" TextAlignment="Center"/>
                        <Border Name="cardCompteARebours" Background="{{INPUT}}" CornerRadius="12" Padding="14,10" Margin="0,10,0,0" Visibility="Collapsed" HorizontalAlignment="Center">
                            <StackPanel>
                                <TextBlock Name="lblCompteARebours" Text="" FontSize="22" FontWeight="Bold" Foreground="{{ACCENT}}" HorizontalAlignment="Center"/>
                                <TextBlock Text="restant avant la fin de la session" FontSize="10" Foreground="{{MUTED}}" HorizontalAlignment="Center" Margin="0,2,0,8"/>
                                <ProgressBar Name="prgCompteARebours" Height="6" Width="220" Minimum="0" Maximum="100" Value="0"
                                             Background="{{DARKBG}}" Foreground="{{ACCENT}}" BorderThickness="0"/>
                            </StackPanel>
                        </Border>
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
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="0" Text="HISTORIQUE DES TIRAGES" Foreground="{{MUTED}}" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
                        <Button Grid.Column="1" Name="btnEffacerHistorique" Style="{StaticResource SecondaryButton}" Width="30" Height="26" Padding="0" ToolTip="Effacer l'historique">
                            <TextBlock Text="&#xE74D;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13"/>
                        </Button>
                    </Grid>
                    <ListBox Grid.Row="1" Name="lstHistorique"/>
                </Grid>
            </Border>
        </Grid>

        <TextBlock Grid.Row="2" Text="$script:gdVersion" Foreground="{{MUTED}}" FontSize="10" FontWeight="SemiBold"
                   HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,4,4" Opacity="0.55" IsHitTestVisible="False"/>
        </Grid>
    </Grid>
    </Border>
</Window>
"@

Write-GDLog "Ouverture fenetre principale - Theme demande : $script:currentTheme"
$xamlString = Apply-Theme $xamlString $script:currentTheme
[xml]$xaml = $xamlString
$reader = New-Object System.Xml.XmlNodeReader $xaml
$script:window = [Windows.Markup.XamlReader]::Load($reader)
    if (-not $window) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'principale' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $script:window = [Windows.Markup.XamlReader]::Load($reader)
        if (-not $window) { throw "Echec du chargement de la fenetre 'principale' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
Enable-GDFadeIn $window
if ($script:gdFenetrePos) {
    try {
        $window.WindowStartupLocation = 'Manual'
        $window.Left = $script:gdFenetrePos.Left
        $window.Top = $script:gdFenetrePos.Top
        $window.Width = $script:gdFenetrePos.Width
        $window.Height = $script:gdFenetrePos.Height
        if ($script:gdFenetrePos.State -eq [System.Windows.WindowState]::Maximized) {
            $window.WindowState = [System.Windows.WindowState]::Maximized
        }
    } catch { }
}
$script:controls = @{}
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
    $controls[$_.Name] = $window.FindName($_.Name)
}
Enable-GDTitleBar $window $controls

# Espace lance le tirage (raccourci clavier pratique), sauf si le focus est
# dans un champ de texte (pour ne pas interferer avec la saisie, ex. le champ
# "Objectif" ou la duree de session).
$window.Add_KeyDown({
    $e = $args[1]
    if ($e.Key -eq 'Space' -and $controls.btnTirer.IsEnabled) {
        $focusActuel = [System.Windows.Input.Keyboard]::FocusedElement
        if ($focusActuel -isnot [System.Windows.Controls.TextBox]) {
            $e.Handled = $true
            $controls.btnTirer.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
        }
    }
}.GetNewClosure())

# Avertir avant de fermer completement l'application (pas un simple
# changement de theme) si une session chronometree est encore en cours -
# evite de perdre le fil d'un decompte par une fermeture accidentelle.
$window.Add_Closing({
    $e = $args[1]
    if ((-not $script:reloadRequested) -and $script:timerCompteARebours -and $script:timerCompteARebours.IsEnabled) {
        $confirmFermeture = Show-GDMessageBox -Message "Une session chronometree est encore en cours. Fermer quand meme GameDraw ?" -Title "Session en cours" -Buttons "YesNo" -Icon "Warning"
        if ($confirmFermeture -ne 'Yes') { $e.Cancel = $true }
    }
}.GetNewClosure())

# Diagnostic : verifie que les controles essentiels au tirage sont bien
# resolus des l'ouverture. Si l'un d'eux est absent/null, on le sait tout de
# suite dans le log plutot que de decouvrir un plantage plus tard au clic.
foreach ($nomCritique in @("lblJeuTire", "lblObjectif", "lblFin", "lblPool", "imgCoverResultat", "canvasConfetti", "btnTirer", "prgPool", "rouletteWheelContainer", "rouletteWheelCanvas", "rouletteRotate", "reelViewport", "slotMachineContainer", "tbSlot1", "tbSlot2", "tbSlot3")) {
    if (-not $controls.ContainsKey($nomCritique) -or $null -eq $controls[$nomCritique]) {
        Write-GDLog "DIAGNOSTIC : le controle '$nomCritique' est absent ou null juste apres l'ouverture de la fenetre principale (cle presente dans le dictionnaire : $($controls.ContainsKey($nomCritique)))."
    }
}

# =========================================================================
# XAML "Gerer les jeux"
# =========================================================================
$xamlGestionString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Gerer les jeux" Height="700" Width="660" MinHeight="560" MinWidth="600"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
            <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
        <Style x:Key="ComboBoxItemStyleG" TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
                                              TextBlock.Foreground="{{TEXT}}"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,1">
                            <Grid>
                                <Border x:Name="AccentBar" Width="4" HorizontalAlignment="Left" Background="{{ACCENT}}" CornerRadius="2" Opacity="0" Margin="-10,-8,0,-8"/>
                                <ContentPresenter Margin="6,0,0,0" TextBlock.Foreground="{{TEXT}}" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{{BORDER}}"/>
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="AccentBar" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.15"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="AccentBar" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.15"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
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
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
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
            <Button Name="btnExporterBiblio" Content="Exporter" Style="{StaticResource SecondaryButton}" Margin="14,0,0,0" ToolTip="Exporter cette bibliotheque (jeux + jaquettes) vers un fichier"/>
            <Button Name="btnImporterBiblio" Content="Importer" Style="{StaticResource SecondaryButton}" Margin="8,0,0,0" ToolTip="Importer une bibliotheque depuis un fichier exporte"/>
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
            <Button Name="btnRechercheRawg" Style="{StaticResource SecondaryButton}" Margin="8,0,0,0" ToolTip="Cherche le nom tape ci-contre sur RAWG.io et propose sa jaquette">
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE721;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="15" VerticalAlignment="Center"/>
                    <TextBlock Text=" En ligne" VerticalAlignment="Center" Margin="6,0,0,0"/>
                </StackPanel>
            </Button>
            <Button Name="btnImportSteam" Content="Steam" Style="{StaticResource SecondaryButton}" Margin="8,0,0,0" ToolTip="Importer des jeux depuis ta bibliotheque Steam"/>
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
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Fiche du jeu"
# =========================================================================
$xamlFicheString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Fiche du jeu" Height="680" Width="880" MinHeight="600" MinWidth="800"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="11"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource SecondaryButton}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Name="lblFicheTitre" Text="Fiche du jeu" Foreground="{{ACCENT}}" FontSize="21" FontWeight="Bold" Margin="0,0,0,2"/>
        <TextBlock Grid.Row="0" Name="lblFichePlateforme" Text="" Foreground="{{MUTED}}" FontSize="12" Margin="0,27,0,18" VerticalAlignment="Top"/>

        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="220"/>
                <ColumnDefinition Width="24"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0">
                <Border Background="{{CARD}}" BorderBrush="{{BORDER}}" BorderThickness="1" CornerRadius="10" Height="260" Width="220">
                    <Border.Effect>
                        <DropShadowEffect Color="#000000" BlurRadius="14" ShadowDepth="3" Opacity="0.3"/>
                    </Border.Effect>
                    <Image Name="imgCover" Stretch="Uniform" Margin="4" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                    <Button Name="btnChoisirCover" Content="Choisir..." Style="{StaticResource SecondaryButton}" Margin="0,0,6,0"/>
                    <Button Name="btnRetirerCover" Content="Retirer" Style="{StaticResource DangerButton}"/>
                </StackPanel>
            </StackPanel>

            <Grid Grid.Column="2">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Margin="0,0,0,16">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Margin="0,0,16,0">
                        <TextBlock Text="STATUT" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                        <WrapPanel Name="wrapStatutJeu" Orientation="Horizontal"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1">
                        <TextBlock Text="NOTE" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                        <TextBlock Name="tbNoteFiche" FontSize="22" Cursor="Hand" ToolTip="Clique pour noter"/>
                    </StackPanel>
                </Grid>

                <StackPanel Grid.Row="1" Margin="0,0,0,16">
                    <TextBlock Text="TAGS (separes par une virgule)" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                    <TextBox Name="txtTagsJeu" Height="34"/>
                </StackPanel>

                <StackPanel Grid.Row="2" Margin="0,0,0,16">
                    <TextBlock Text="DESCRIPTION" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                    <TextBox Name="txtDescriptionJeu" Height="72" AcceptsReturn="True" TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto" VerticalContentAlignment="Top"/>
                </StackPanel>

                <TextBlock Grid.Row="3" Text="COMMENTAIRE PERSONNEL" Foreground="{{MUTED}}" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBox Grid.Row="4" Name="txtCommentaire" AcceptsReturn="True" TextWrapping="Wrap"
                          VerticalScrollBarVisibility="Auto" VerticalContentAlignment="Top"/>
            </Grid>
        </Grid>

        <Grid Grid.Row="2" Margin="0,18,0,0">
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
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Gerer les plateformes"
# =========================================================================
$xamlPlatformsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Gerer les plateformes" Height="500" Width="520" MinHeight="400" MinWidth="440"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
            <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="{{DARKBG}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="ItemTemplate">
                <Setter.Value>
                    <DataTemplate>
                        <TextBlock Text="{Binding}" Foreground="{{TEXT}}" FontWeight="SemiBold" FontSize="13" TextWrapping="Wrap"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ListBoxItem">
                        <Border x:Name="Bd" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}" Margin="0,2">
                            <ContentPresenter TextBlock.Foreground="{{TEXT}}" TextBlock.FontWeight="SemiBold" TextBlock.FontSize="13"/>
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
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
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
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Options"
# =========================================================================
$xamlOptionsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Options" Height="780" Width="700" MinHeight="600" MinWidth="620"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
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
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style x:Key="SectionCard" TargetType="Border">
            <Setter Property="Background" Value="{{CARD}}"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="10"/>
            <Setter Property="Padding" Value="16"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
        </Style>
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="{{MUTED}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="Margin" Value="0,0,0,4"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="BdNav" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="BdNav" Property="Background" Value="{{INPUT}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
$xamlComboBoxBlock
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="OPTIONS" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,16"/>

        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="168"/>
                <ColumnDefinition Width="20"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <StackPanel Grid.Column="0" Name="stackNavOptions">
                <Button Name="navTirage" Content="Tirage" Style="{StaticResource NavButton}" Tag="pageTirage"/>
                <Button Name="navStatuts" Content="Jeux &amp; Statuts" Style="{StaticResource NavButton}" Tag="pageStatuts"/>
                <Button Name="navApparence" Content="Apparence" Style="{StaticResource NavButton}" Tag="pageApparence"/>
                <Button Name="navConnexion" Content="Connexion" Style="{StaticResource NavButton}" Tag="pageConnexion"/>
                <Button Name="navDonnees" Content="Donnees" Style="{StaticResource NavButton}" Tag="pageDonnees"/>
            </StackPanel>

            <ScrollViewer Grid.Column="2" VerticalScrollBarVisibility="Auto">
                <Grid>

                <StackPanel Name="pageTirage" Visibility="Visible">
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="COMPORTEMENT" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <CheckBox Name="chkAnimationTirage" Content="Activer l'animation de tirage (roue qui tourne avant le resultat)" Margin="0,0,0,8"/>
                            <TextBlock Text="Style de l'animation :" Foreground="{{MUTED}}" FontSize="11" Margin="0,0,0,4"/>
                            <WrapPanel Name="stackStyleAnimation" Orientation="Horizontal" Margin="0,0,0,8"/>
                            <CheckBox Name="chkEviterRepetitionDefaut" Content="Eviter les repetitions par defaut au demarrage" Margin="0,0,0,8"/>
                            <CheckBox Name="chkAvertirNouveauTirage" Content="Avertir avant de relancer un tirage si une session est encore en cours" Margin="0,0,0,8"/>
                            <CheckBox Name="chkNotifierFinSession" Content="Notification Windows quand le temps de session est ecoule"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="OBJECTIFS" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                                <Label Content="Objectif par defaut :" VerticalAlignment="Center"/>
                                <ComboBox Name="cmbObjectifDefaut" Width="220" Height="34" Margin="8,0,0,0"/>
                            </StackPanel>
                            <TextBlock Text="Liste des objectifs proposes" Foreground="{{MUTED}}" FontSize="11" Margin="0,0,0,4"/>
                            <StackPanel Name="stackObjectifsListe" Margin="0,0,0,8"/>
                            <StackPanel Orientation="Horizontal">
                                <TextBox Name="txtNouvelObjectif" Width="220" Height="32" Margin="0,0,8,0"/>
                                <Button Name="btnAjouterObjectif" Content="Ajouter" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="HISTORIQUE" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal">
                                <Label Content="Nombre de tirages affiches :" VerticalAlignment="Center"/>
                                <TextBox Name="txtHistoriqueCount" Width="60" Height="34" Margin="8,0,0,0" TextAlignment="Center"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <StackPanel Name="pageStatuts" Visibility="Collapsed">
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="ICONE DE NOTATION" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <TextBlock Text="Styles a proposer :" Foreground="{{MUTED}}" FontSize="11" Margin="0,0,0,4"/>
                            <WrapPanel Name="wrapIconesAAfficher" Margin="0,0,0,8"/>
                            <StackPanel Name="stackIconList"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="COULEUR DE L'ICONE AU MAXIMUM (5/5)" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <WrapPanel Name="wrapPaletteCouleurs" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Top">
                                <TextBox Name="txtCouleurEtoiles" Width="120" Height="36" VerticalAlignment="Center"/>
                                <Button Name="btnAppliquerCouleur" Content="Appliquer" Style="{StaticResource SecondaryButton}" Margin="10,0,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="STATUTS PERSONNALISES (EN PLUS DES 5 PAR DEFAUT)" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Name="stackStatutsListe" Margin="0,0,0,8"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                <TextBox Name="txtNouveauStatut" Width="180" Height="32" Margin="0,0,8,0"/>
                                <Button Name="btnAjouterStatut" Content="Ajouter" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                            <WrapPanel Name="wrapPaletteStatut" Margin="0,0,0,14"/>
                            <TextBlock Text="Statuts a afficher" Foreground="{{MUTED}}" FontSize="11" Margin="0,0,0,4"/>
                            <WrapPanel Name="wrapStatutsAAfficher"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <StackPanel Name="pageApparence" Visibility="Collapsed">
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="DENSITE DE L'AFFICHAGE" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Name="stackDensite"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="ICONE DE L'APPLICATION" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Un changement d'icone s'applique a la prochaine ouverture de fenetre." Foreground="{{MUTED}}" FontSize="10" Margin="0,0,0,8"/>
                            <WrapPanel Name="stackIconeApp" Orientation="Horizontal"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="BOUTONS DE L'EN-TETE" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Masquer un bouton s'applique a la prochaine ouverture de fenetre. Le bouton Options reste toujours visible." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <CheckBox Name="chkMasquerTheme" Content="Theme" Margin="0,0,0,6"/>
                            <CheckBox Name="chkMasquerStats" Content="Statistiques" Margin="0,0,0,6"/>
                            <CheckBox Name="chkMasquerBacklog" Content="Backlog" Margin="0,0,0,6"/>
                            <CheckBox Name="chkMasquerPlateformes" Content="Gerer les plateformes" Margin="0,0,0,6"/>
                            <CheckBox Name="chkMasquerGererJeux" Content="Gerer les jeux"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <StackPanel Name="pageConnexion" Visibility="Collapsed">
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="RECHERCHE EN LIGNE (RAWG)" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Permet de chercher un jeu par son nom et de recuperer automatiquement sa jaquette (comme sur Steam/OBS). Cle gratuite a obtenir sur rawg.io/apidocs (compte gratuit, 2 minutes)." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal">
                                <TextBox Name="txtRawgApiKey" Width="260" Height="34" Margin="0,0,10,0"/>
                                <Button Name="btnEnregistrerRawgKey" Content="Enregistrer" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="IMPORT STEAM" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Importe automatiquement les jeux de ta bibliotheque Steam. Necessite une cle API (steamcommunity.com/dev/apikey, compte gratuit) et ton SteamID64 (visible via steamid.io en collant l'URL de ton profil). Ton profil Steam doit etre public pour que ça fonctionne." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                <TextBox Name="txtSteamApiKey" Width="260" Height="34" Margin="0,0,10,0"/>
                                <Button Name="btnEnregistrerSteamKey" Content="Enregistrer la cle" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal">
                                <TextBox Name="txtSteamId64" Width="260" Height="34" Margin="0,0,10,0"/>
                                <Button Name="btnEnregistrerSteamId" Content="Enregistrer l'ID" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </StackPanel>

                <StackPanel Name="pageDonnees" Visibility="Collapsed">
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="EMPLACEMENT DES DONNEES" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,4"/>
                            <TextBlock Text="Bibliotheques de jeux, historique, catalogues et images. Deplacer copie tout vers le nouvel emplacement." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <TextBox Name="txtEmplacementDonnees" IsReadOnly="True" Height="34" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal">
                                <Button Name="btnChangerEmplacement" Content="Changer l'emplacement..." Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                                <Button Name="btnOuvrirEmplacement" Content="Ouvrir le dossier" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="RACCOURCI" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <Button Name="btnCreerRaccourci" Content="Creer un raccourci sur le Bureau" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Left"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource SectionCard}">
                        <StackPanel>
                            <TextBlock Text="SAUVEGARDE" Foreground="{{MUTED}}" FontSize="11" FontWeight="Bold" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
                                <Button Name="btnSauvegarderConfig" Content="Sauvegarder la config" Style="{StaticResource SecondaryButton}" Margin="0,0,10,0"/>
                                <Button Name="btnRestaurerConfig" Content="Restaurer une config" Style="{StaticResource DangerButton}"/>
                            </StackPanel>
                            <TextBlock Text="La sauvegarde regroupe plateformes, bibliotheques de jeux, historique et catalogues dans un seul .zip." Foreground="{{MUTED}}" FontSize="10" TextWrapping="Wrap"/>
                        </StackPanel>
                    </Border>
                </StackPanel>

                </Grid>
            </ScrollViewer>
        </Grid>

        <Button Grid.Row="2" Name="btnFermerOptions" Content="Fermer" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Width="120" Margin="0,14,0,0"/>
        </Grid>
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Catalogue Switch"
# =========================================================================
$xamlCatalogueString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Catalogue de jeux" Height="680" Width="560" MinHeight="450" MinWidth="460"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
        <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{DANGER}}"/>
            <Setter Property="Padding" Value="6,2"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="Margin" Value="0,2"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
        </Style>
$xamlComboBoxBlock
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
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
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Statistiques"
# =========================================================================
$xamlStatsString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Statistiques" Height="560" Width="620" MinHeight="400" MinWidth="480"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
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
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Backlog" (vue bibliotheque en grille avec pochettes)
# =========================================================================
$xamlBacklogString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Backlog" Height="720" Width="900" MinHeight="500" MinWidth="620"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="Background" Value="{{INPUT}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="{{BORDER}}"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
$xamlComboBoxBlock
    </Window.Resources>
    <Border CornerRadius="10" ClipToBounds="True" Background="{{BG}}">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="BACKLOG" Foreground="{{ACCENT}}" FontSize="20" FontWeight="Bold" Margin="0,0,0,14"/>

        <StackPanel Grid.Row="1" Margin="0,0,0,14">
            <Grid Margin="0,0,0,8">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="Plateforme :" VerticalAlignment="Center" Foreground="{{MUTED}}"/>
                <ComboBox Grid.Column="1" Name="cmbPlatformBacklog" Width="160" Height="34" Margin="8,0,14,0"/>
                <TextBox Grid.Column="2" Name="txtRechercheBacklog" Height="34"/>
            </Grid>
            <WrapPanel Name="wrapStatutTabs" Orientation="Horizontal" Margin="0,0,0,10"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="Note :" VerticalAlignment="Center" Foreground="{{MUTED}}"/>
                <ComboBox Grid.Column="1" Name="cmbFiltreNote" Width="150" Height="32" Margin="8,0,0,0">
                    <ComboBoxItem Content="Toutes les notes" IsSelected="True"/>
                    <ComboBoxItem Content="5/5 uniquement"/>
                    <ComboBoxItem Content="4/5 et plus"/>
                    <ComboBoxItem Content="3/5 et plus"/>
                    <ComboBoxItem Content="Non note"/>
                </ComboBox>
            </Grid>
        </StackPanel>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <WrapPanel Name="wrapBacklog" Orientation="Horizontal"/>
        </ScrollViewer>

        <Grid Grid.Row="3" Margin="0,14,0,0">
            <TextBlock Name="lblBacklogCompte" Text="" Foreground="{{MUTED}}" FontSize="11" VerticalAlignment="Center"/>
            <Button Name="btnFermerBacklog" Content="Fermer" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Width="120"/>
        </Grid>
        </Grid>
    </Grid>
    </Border>
</Window>
"@

# =========================================================================
# XAML "Recherche en ligne (RAWG)"
# =========================================================================
$xamlRawgString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Recherche en ligne" Height="750" Width="780" MinHeight="500" MinWidth="620"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="0.85" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                                <Trigger.ExitActions>
                                    <BeginStoryboard>
                                        <Storyboard>
                                            <DoubleAnimation Storyboard.TargetName="Bd" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.12"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="RECHERCHE EN LIGNE (RAWG)" Foreground="{{ACCENT}}" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>
        <TextBlock Grid.Row="1" Name="lblRawgStatut" Text="Recherche en cours..." Foreground="{{MUTED}}" FontSize="12" Margin="0,0,0,14"/>

        <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
            <WrapPanel Name="wrapRawgResultats" Orientation="Horizontal"/>
        </ScrollViewer>

        <Button Grid.Row="3" Name="btnFermerRawg" Content="Fermer" Style="{StaticResource SecondaryButton}" HorizontalAlignment="Right" Width="120" Margin="0,14,0,0"/>
        </Grid>
    </Grid>
</Window>
"@

$xamlSteamString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Import Steam" Height="700" Width="600" MinHeight="480" MinWidth="480"
        Icon="$iconUri"
        WindowStartupLocation="CenterOwner"
        Background="{{BG}}" FontFamily="Segoe UI">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="10"/>
    </shell:WindowChrome.WindowChrome>
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Background" Value="{{ACCENT}}"/>
            <Setter Property="Foreground" Value="{{DARKBG}}"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="BorderThickness" Value="0"/>
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
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.65"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
            <Setter Property="Background" Value="{{BORDER}}"/>
            <Setter Property="Foreground" Value="{{TEXT}}"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

$xamlTitleBarBlock

        <Grid Grid.Row="1" Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Text="IMPORT STEAM" Foreground="{{ACCENT}}" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>
        <TextBlock Grid.Row="1" Name="lblSteamStatut" Text="Chargement de la bibliotheque..." Foreground="{{MUTED}}" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,10"/>
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="btnSteamToutSelectionner" Content="Tout selectionner" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
            <Button Name="btnSteamToutDeselectionner" Content="Tout deselectionner" Style="{StaticResource SecondaryButton}"/>
        </StackPanel>

        <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
            <StackPanel Name="stackSteamJeux"/>
        </ScrollViewer>

        <Grid Grid.Row="4" Margin="0,14,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Name="lblSteamSelection" Text="0 jeu(x) selectionne(s)" Foreground="{{MUTED}}" VerticalAlignment="Center"/>
            <Button Grid.Column="1" Name="btnImporterSteam" Content="Importer la selection" Margin="0,0,10,0"/>
            <Button Grid.Column="2" Name="btnFermerSteam" Content="Fermer" Style="{StaticResource SecondaryButton}"/>
        </Grid>
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

$boutonsMasquesDemarrage = Get-BoutonsMasques
if ($boutonsMasquesDemarrage -contains "Theme") { $controls.btnTheme.Visibility = 'Collapsed' }
if ($boutonsMasquesDemarrage -contains "Stats") { $controls.btnStats.Visibility = 'Collapsed' }
if ($boutonsMasquesDemarrage -contains "Backlog") { $controls.btnBacklog.Visibility = 'Collapsed' }
if ($boutonsMasquesDemarrage -contains "Plateformes") { $controls.btnGererPlateformes.Visibility = 'Collapsed' }
if ($boutonsMasquesDemarrage -contains "GererJeux") { $controls.btnGererJeux.Visibility = 'Collapsed' }
foreach ($obj in (Get-ObjectifsListe)) {
    $itemObj = New-Object System.Windows.Controls.ComboBoxItem
    $itemObj.Content = $obj
    $controls.cmbObjectif.Items.Add($itemObj) | Out-Null
}
if ($controls.cmbObjectif.Items.Count -gt 0) { $controls.cmbObjectif.SelectedIndex = 0 }
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
                $img.HorizontalAlignment = 'Center'
                $img.VerticalAlignment = 'Center'
                $img.Margin = '0,0,8,0'
                $img.VerticalAlignment = 'Center'
                $item.Children.Add($img) | Out-Null
            } catch { }
        }

        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = "[$plat] $nomJeu  |  $duree  |  objectif: $($_.Objectif)"
        $tb.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
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

$controls.btnEffacerHistorique.Add_Click({
    Invoke-Safe -Contexte "Effacer l'historique" -Action {
        $confirmHist = Show-GDMessageBox -Message "Effacer tout l'historique des tirages ? Cette action est irreversible." -Title "Confirmation" -Buttons "YesNo" -Icon "Warning"
        if ($confirmHist -ne 'Yes') { return }
        Save-Json $histFile @()
        Write-GDLog "Historique des tirages efface"
        Refresh-Historique
    }
})

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
    Enable-GDFadeIn $winP
    $script:cp = @{}
    $xamlP.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cp[$_.Name] = $winP.FindName($_.Name)
    }
    Enable-GDTitleBar $winP $cp

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
                Show-GDMessageBox -Message "Cette plateforme existe deja." -Title "Info" | Out-Null
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
                Show-GDMessageBox -Message "Saisissez le nouveau nom dans le champ texte, puis cliquez sur Renommer." -Title "Info" | Out-Null
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
            $confirm = Show-GDMessageBox -Message "Supprimer la plateforme '$([string]$cible.Nom)' ? (sa bibliotheque de jeux ne sera pas effacee du disque)" -Title "Confirmation" -Buttons "YesNo" -Icon "Warning"
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
    Enable-GDFadeIn $winG
    $script:cg = @{}
    $xamlGestion.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cg[$_.Name] = $winG.FindName($_.Name)
    }
    Enable-GDTitleBar $winG $cg

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
        $brushBlanc = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
        $brushAccentTitre = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
        $icones     = Get-RatingIconSet (Get-RatingIconName)
        $filtre     = if ($cg.txtRechercheJeu) { $cg.txtRechercheJeu.Text.Trim() } else { "" }
        $compact    = ((Get-Densite) -eq "Compacte")
        $tailleTitre  = if ($compact) { 11 } else { 12 }
        $tailleIcones = if ($compact) { 12 } else { 13 }
        $margeItem    = if ($compact) { '0,0,0,0' } else { '0,1,0,1' }

        if ($games.Count -eq 0) {
            $accueilVide = New-Object System.Windows.Controls.StackPanel
            $accueilVide.Margin = '20,50,20,20'
            $accueilVide.HorizontalAlignment = 'Center'
            $tbTitreVide = New-Object System.Windows.Controls.TextBlock
            $tbTitreVide.Text = "Bibliotheque vide"
            $tbTitreVide.FontSize = 18
            $tbTitreVide.FontWeight = 'Bold'
            $tbTitreVide.Foreground = $brushAccentTitre
            $tbTitreVide.HorizontalAlignment = 'Center'
            $accueilVide.Children.Add($tbTitreVide) | Out-Null
            $tbSousTitreVide = New-Object System.Windows.Controls.TextBlock
            $tbSousTitreVide.Text = "Ajoute un premier jeu avec le champ ci-dessus, importe un catalogue predefini, cherche en ligne (RAWG) ou importe directement ta bibliotheque Steam."
            $tbSousTitreVide.FontSize = 12
            $tbSousTitreVide.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].MUTED
            $tbSousTitreVide.TextWrapping = 'Wrap'
            $tbSousTitreVide.TextAlignment = 'Center'
            $tbSousTitreVide.MaxWidth = 320
            $tbSousTitreVide.Margin = '0,10,0,0'
            $accueilVide.Children.Add($tbSousTitreVide) | Out-Null
            $cg.lstGamesG.Items.Add($accueilVide) | Out-Null
        } elseif ($filtre -and -not (@($games | Where-Object { ([string]$_.Nom).ToLower().Contains($filtre.ToLower()) }))) {
            $accueilFiltre = New-Object System.Windows.Controls.TextBlock
            $accueilFiltre.Text = "Aucun jeu ne correspond a '$filtre'."
            $accueilFiltre.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].MUTED
            $accueilFiltre.FontSize = 13
            $accueilFiltre.HorizontalAlignment = 'Center'
            $accueilFiltre.Margin = '20,40,20,20'
            $cg.lstGamesG.Items.Add($accueilFiltre) | Out-Null
        }

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
                    $bmpVignette.DecodePixelWidth = 30
                    $bmpVignette.UriSource = New-Object System.Uri((Resolve-Path $cheminVignette).Path, [System.UriKind]::Absolute)
                    $bmpVignette.EndInit()
                    $bmpVignette.Freeze()
                    $imgVignette = New-Object System.Windows.Controls.Image
                    $imgVignette.Source = $bmpVignette
                    $imgVignette.Width = 26
                    $imgVignette.Height = 26
                    $imgVignette.Stretch = 'UniformToFill'
                    $imgVignette.HorizontalAlignment = 'Center'
                    $imgVignette.Margin = '0,0,8,0'
                    $imgVignette.VerticalAlignment = 'Top'
                    $panelItem.Children.Add($imgVignette) | Out-Null
                } catch { }
            }

            $textStack = New-Object System.Windows.Controls.StackPanel
            $textStack.Orientation = 'Vertical'

            $tbTitre = New-Object System.Windows.Controls.TextBlock
            $tbTitre.Text = $titre
            $tbTitre.Foreground = $brushAccentTitre
            $tbTitre.FontWeight = 'SemiBold'
            $tbTitre.FontSize = $tailleTitre
            $tbTitre.TextWrapping = 'Wrap'
            $textStack.Children.Add($tbTitre) | Out-Null

            $ligneNote = New-Object System.Windows.Controls.StackPanel
            $ligneNote.Orientation = 'Horizontal'
            $ligneNote.Margin = '0,1,0,0'

            # Notation en un clic direct sur les icones (avec previsualisation au
            # survol). Le texte reste isole de l'indicateur "refaire" pour que le
            # calcul de zone de clic (X / largeur * 5) porte uniquement sur les 5
            # icones et ne soit jamais fausse par un suffixe.
            $tbEtoiles = New-Object System.Windows.Controls.TextBlock
            $tbEtoiles.Text = $etoiles
            $tbEtoiles.FontFamily = New-Object System.Windows.Media.FontFamily($icones.Police)
            $tbEtoiles.Foreground = $(if ($estOr) { $brushOr } else { $brushBlanc })
            $tbEtoiles.FontWeight = 'Bold'
            $tbEtoiles.FontSize = $tailleIcones
            $tbEtoiles.Cursor = 'Hand'
            $tbEtoiles.Tag = $realIndex
            $tbEtoiles.ToolTip = "Clique sur une icone pour noter"
            $tbEtoiles.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
            $tbEtoiles.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1, 1)

            $tbEtoiles.Add_MouseEnter({
                # Petit "pulse" pour signaler que la zone est cliquable : monte a
                # 1.15x puis revient a 1x. AutoReverse gere le retour, pas besoin
                # de fermeture differee ici (BeginAnimation est gere par WPF en
                # interne, aucun risque de variable perimee).
                $easeSortie = New-Object System.Windows.Media.Animation.QuadraticEase
                $easeSortie.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
                $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 1.15, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(120))))
                $anim.AutoReverse = $true
                $anim.EasingFunction = $easeSortie
                $this.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $anim)
                $this.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $anim)
            })
            $tbEtoiles.Add_MouseMove({
                if ($script:gdCascadingIndices -and $script:gdCascadingIndices.Contains([int]$this.Tag)) { return }
                $e = $args[1]
                $ratio = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
                $hoverN = [Math]::Ceiling($ratio * 5)
                if ($hoverN -lt 1) { $hoverN = 1 }
                if ($hoverN -gt 5) { $hoverN = 5 }
                $ic = Get-RatingIconSet (Get-RatingIconName)
                $this.Text = ($ic.Filled * $hoverN) + ($ic.Empty * (5 - $hoverN))
                $this.Foreground = ConvertTo-GDBrush $script:starGoldColor
            })
            $tbEtoiles.Add_MouseLeave({
                if ($script:gdCascadingIndices -and $script:gdCascadingIndices.Contains([int]$this.Tag)) { return }
                Refresh-ListG
            })
            $tbEtoiles.Add_MouseLeftButtonDown({
                $e = $args[1]
                $e.Handled = $true
                $ratio = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
                $hoverN = [Math]::Ceiling($ratio * 5)
                if ($hoverN -lt 1) { $hoverN = 1 }
                if ($hoverN -gt 5) { $hoverN = 5 }

                # Remplissage en cascade : les icones se remplissent une par une
                # avant d'enregistrer la note. Tout ce dont le timer a besoin est
                # capture ici (idx/element/icones/cible), au moment ou le clic se
                # produit reellement - donc toujours valide quand le Tick se
                # declenche plus tard, meme si Refresh-ListG (qui a cree ce
                # gestionnaire) a deja termine son execution depuis longtemps.
                $idxCapture = $this.Tag
                $elementCapture = $this
                $iconesCapture = Get-RatingIconSet (Get-RatingIconName)
                $cibleCapture = $hoverN
                $etapeCascade = [pscustomobject]@{ N = 0 }

                if (-not $script:gdCascadingIndices) { $script:gdCascadingIndices = New-Object 'System.Collections.Generic.HashSet[int]' }
                $script:gdCascadingIndices.Add([int]$idxCapture) | Out-Null

                $timerCascade = New-Object System.Windows.Threading.DispatcherTimer
                $timerCascade.Interval = [TimeSpan]::FromMilliseconds(90)
                $timerCascade.Add_Tick({
                    try {
                        $etapeCascade.N++
                        $elementCapture.Text = ($iconesCapture.Filled * $etapeCascade.N) + ($iconesCapture.Empty * (5 - $etapeCascade.N))
                        if ($etapeCascade.N -ge $cibleCapture) {
                            $timerCascade.Stop()
                            if (-not $script:gdCascadingIndices) { $script:gdCascadingIndices = New-Object 'System.Collections.Generic.HashSet[int]' }
                            $script:gdCascadingIndices.Remove([int]$idxCapture) | Out-Null
                            Set-NoteJeuParIndex -idx $idxCapture -note $cibleCapture
                        }
                    } catch {
                        try { $timerCascade.Stop() } catch { }
                        try { if ($script:gdCascadingIndices) { $script:gdCascadingIndices.Remove([int]$idxCapture) | Out-Null } } catch { }
                        try {
                            $detail = $_.Exception.Message
                            if ($_.Exception.InnerException) { $detail += " | Cause interne : $($_.Exception.InnerException.Message)" }
                            Write-GDLog "ERREUR [Cascade de notation] ($($_.Exception.GetType().FullName)) : $detail`n$($_.ScriptStackTrace)"
                        } catch { }
                    }
                }.GetNewClosure())
                $timerCascade.Start()
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
            $panelItem.Cursor = 'Hand'
            $panelItem.Add_MouseLeftButtonDown({
                $idxLigne = $this.Tag
                Invoke-Safe -Contexte "Fiche du jeu" -Action {
                    if (-not $cg.cmbPlatformG.SelectedItem) { return }
                    $platActuelle = $cg.cmbPlatformG.SelectedItem.Content
                    Open-FicheJeu -PlateformeCible $platActuelle -IndexJeu $idxLigne -OnSaved { Refresh-ListG }
                }
            })
            $cg.lstGamesG.Items.Add($panelItem) | Out-Null
        }
    }

    function script:Get-SelectionIndex {
        $sel = $cg.lstGamesG.SelectedItem
        if (-not $sel) { return -1 }
        return [int]$sel.Tag
    }

    # Selectionne et met en valeur le jeu qui vient d'etre ajoute : selection
    # (declenche deja la barre d'accent animee du style de ligne), defilement
    # automatique jusqu'a la ligne, et un leger "pop" d'echelle en plus pour
    # bien capter l'oeil au moment ou la ligne apparait.
    function script:Mettre-EnValeur-NouveauJeu([int]$idxCible) {
        foreach ($item in $cg.lstGamesG.Items) {
            if ([int]$item.Tag -eq $idxCible) {
                $cg.lstGamesG.SelectedItem = $item
                $cg.lstGamesG.ScrollIntoView($item)

                $itemContainer = $cg.lstGamesG.ItemContainerGenerator.ContainerFromItem($item)
                if ($itemContainer) {
                    $scalePop = New-Object System.Windows.Media.ScaleTransform(0.94, 0.94)
                    $itemContainer.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
                    $itemContainer.RenderTransform = $scalePop
                    $easePop = New-Object System.Windows.Media.Animation.BackEase
                    $easePop.Amplitude = 0.4
                    $easePop.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
                    $animScale = New-Object System.Windows.Media.Animation.DoubleAnimation(0.94, 1.0, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(300))))
                    $animScale.EasingFunction = $easePop
                    $scalePop.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $animScale)
                    $scalePop.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $animScale)
                }
                break
            }
        }
    }

    Refresh-ListG
    Force-VerticalListBox $cg.lstGamesG

    $cg.cmbPlatformG.Add_SelectionChanged({ $cg.txtRechercheJeu.Text = ""; Refresh-ListG })

    $cg.btnExporterBiblio.Add_Click({
        Invoke-Safe -Contexte "Exporter la bibliotheque" -Action {
            if (-not $cg.cmbPlatformG.SelectedItem) { return }
            $platExport = $cg.cmbPlatformG.SelectedItem.Content
            $dlg = New-Object Microsoft.Win32.SaveFileDialog
            $dlg.Filter = "Bibliotheque GameDraw (*.zip)|*.zip"
            $dlg.FileName = "GameDraw_$($platExport)_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
            if ($dlg.ShowDialog() -ne $true) { return }

            $tempDirExport = Join-Path $env:TEMP "GameDraw_Export_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDirExport -Force | Out-Null
            $fichierJeuxExport = Get-GameFile $platExport
            if (Test-Path $fichierJeuxExport) { Copy-Item $fichierJeuxExport (Join-Path $tempDirExport "jeux.json") -Force }
            $dossierImagesExport = Get-PlatformImageFolder $platExport
            if (Test-Path $dossierImagesExport) {
                Copy-Item -Path $dossierImagesExport -Destination (Join-Path $tempDirExport "images") -Recurse -Force
            }
            [pscustomobject]@{ Plateforme = $platExport; ExporteLe = (Get-Date).ToString("o"); Version = $script:gdVersion } |
                ConvertTo-Json | Set-Content -Path (Join-Path $tempDirExport "manifest.json") -Encoding UTF8

            if (Test-Path $dlg.FileName) { Remove-Item $dlg.FileName -Force }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDirExport, $dlg.FileName)
            Remove-Item $tempDirExport -Recurse -Force

            Write-GDLog "Bibliotheque exportee : $platExport -> $($dlg.FileName)"
            Show-GDMessageBox -Message "Bibliotheque '$platExport' exportee :`n$($dlg.FileName)" -Title "GameDraw" | Out-Null
        }
    })

    $cg.btnImporterBiblio.Add_Click({
        Invoke-Safe -Contexte "Importer une bibliotheque" -Action {
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Selectionne d'abord la plateforme de destination." -Title "Info" | Out-Null
                return
            }
            $platImport = $cg.cmbPlatformG.SelectedItem.Content
            $dlg = New-Object Microsoft.Win32.OpenFileDialog
            $dlg.Filter = "Bibliotheque GameDraw (*.zip)|*.zip"
            if ($dlg.ShowDialog() -ne $true) { return }

            $confirmImport = Show-GDMessageBox -Message "Importer ce fichier dans la plateforme '$platImport' ? Les jeux seront ajoutes a la bibliotheque existante (pas de remplacement)." -Title "Confirmation" -Buttons "YesNo" -Icon "Question"
            if ($confirmImport -ne 'Yes') { return }

            $tempDirImport = Join-Path $env:TEMP "GameDraw_Import_$(Get-Date -Format 'yyyyMMddHHmmss')"
            New-Item -ItemType Directory -Path $tempDirImport -Force | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($dlg.FileName, $tempDirImport)

            $fichierJeuxImportes = Join-Path $tempDirImport "jeux.json"
            if (-not (Test-Path $fichierJeuxImportes)) {
                Show-GDMessageBox -Message "Fichier invalide : ce n'est pas une bibliotheque GameDraw exportee." -Title "Erreur" -Icon "Error" | Out-Null
                Remove-Item $tempDirImport -Recurse -Force
                return
            }

            $jeuxImportes = @(Load-Json $fichierJeuxImportes)
            $dossierImagesImportees = Join-Path $tempDirImport "images"
            $dossierImagesDestination = Get-PlatformImageFolder $platImport
            if (Test-Path $dossierImagesImportees) {
                if (-not (Test-Path $dossierImagesDestination)) { New-Item -ItemType Directory -Path $dossierImagesDestination -Force | Out-Null }
                Copy-Item -Path (Join-Path $dossierImagesImportees "*") -Destination $dossierImagesDestination -Recurse -Force
            }

            $fichierJeuxDestination = Get-GameFile $platImport
            $jeuxExistants = @(Load-Json $fichierJeuxDestination)
            $nomsExistants = @($jeuxExistants | ForEach-Object { [string]$_.Nom })
            $nbAjoutes = 0
            foreach ($jeuImporte in $jeuxImportes) {
                Ensure-GameFields $jeuImporte | Out-Null
                if ($nomsExistants -contains [string]$jeuImporte.Nom) { continue }
                $jeuxExistants += $jeuImporte
                $nbAjoutes++
            }
            Save-Json $fichierJeuxDestination $jeuxExistants
            Remove-Item $tempDirImport -Recurse -Force

            Write-GDLog "Bibliotheque importee dans '$platImport' : $nbAjoutes jeu(x) ajoute(s) sur $($jeuxImportes.Count)"
            Refresh-ListG
            Show-GDMessageBox -Message "$nbAjoutes jeu(x) ajoute(s) a '$platImport' ($($jeuxImportes.Count - $nbAjoutes) deja present(s), ignore(s))." -Title "GameDraw" | Out-Null
        }
    })
    $cg.txtRechercheJeu.Add_TextChanged({ Refresh-ListG })

    $cg.btnCatalogue.Add_Click({
    Invoke-Safe -Contexte "Catalogue" -Action {
        $platActuelle = if ($cg.cmbPlatformG.SelectedItem) { $cg.cmbPlatformG.SelectedItem.Content } else { $null }
        Open-Catalogue -PlateformeCible $platActuelle -OnAdded { Refresh-ListG }
    }
})

    $cg.btnAjouter.Add_Click({
        Invoke-Safe -Contexte "Ajouter un jeu" -Action {
            $nom = $cg.txtNouveauJeu.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nom)) { return }
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
                return
            }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            $games += [pscustomobject]@{ Nom = $nom; DejaFait = $false; TypeFin = "" }
            $nouvelIndex = $games.Count - 1
            Save-Json $file $games
            $cg.txtNouveauJeu.Text = ""
            Refresh-ListG
            Mettre-EnValeur-NouveauJeu $nouvelIndex
            Open-FicheJeu -PlateformeCible $platName -IndexJeu $nouvelIndex -OnSaved { Refresh-ListG }
        }
    })

    $cg.btnRechercheRawg.Add_Click({
        Invoke-Safe -Contexte "Recherche en ligne" -Action {
            $terme = $cg.txtNouveauJeu.Text.Trim()
            $platActuelle = if ($cg.cmbPlatformG.SelectedItem) { $cg.cmbPlatformG.SelectedItem.Content } else { $null }
            Open-RawgRecherche -Terme $terme -PlateformeCible $platActuelle -OnAdded {
                param($idxAjoute)
                Refresh-ListG
                Mettre-EnValeur-NouveauJeu $idxAjoute
            }
        }
    })

    $cg.btnImportSteam.Add_Click({
        Invoke-Safe -Contexte "Import Steam" -Action {
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Selectionne d'abord la plateforme de destination." -Title "Info" | Out-Null
                return
            }
            $platActuelle = $cg.cmbPlatformG.SelectedItem.Content
            Open-SteamImport -PlateformeCible $platActuelle -OnImported { Refresh-ListG }
        }
    })

    $cg.btnSupprimer.Add_Click({
        Invoke-Safe -Contexte "Supprimer un jeu" -Action {
            $idx = Get-SelectionIndex
            if ($idx -lt 0) { return }
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
                return
            }
            $platName = $cg.cmbPlatformG.SelectedItem.Content
            $file = Get-GameFile $platName
            $games = @(Load-Json $file)
            $nomJeu = [string]$games[$idx].Nom
            $confirm = Show-GDMessageBox -Message "Supprimer '$nomJeu' de la bibliotheque ?" -Title "Confirmation" -Buttons "YesNo" -Icon "Warning"
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
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
                return
            }
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
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
                return
            }
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
                Show-GDMessageBox -Message "Selectionnez un jeu dans la liste." -Title "Info" | Out-Null
                return
            }
            if (-not $cg.cmbPlatformG.SelectedItem) {
                Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
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
            if (-not $cg.cmbPlatformG.SelectedItem) { return }
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
            Show-GDMessageBox -Message "Selectionnez un jeu dans la liste." -Title "Info" | Out-Null
            return
        }
        if (-not $cg.cmbPlatformG.SelectedItem) { return }
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
    Enable-GDFadeIn $winF
    $script:cf = @{}
    $xamlF.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cf[$_.Name] = $winF.FindName($_.Name)
    }
    Enable-GDTitleBar $winF $cf

    $file = Get-GameFile $PlateformeCible
    $games = @(Load-Json $file)
    if ($IndexJeu -lt 0 -or $IndexJeu -ge $games.Count) {
        Show-GDMessageBox -Message "Jeu introuvable (la liste a peut-etre change entre-temps). Reouvre la fiche." -Title "Info" | Out-Null
        return
    }
    $g = Ensure-GameFields $games[$IndexJeu]

    $cf.lblFicheTitre.Text = "Fiche du jeu : $([string]$g.Nom)"
    $cf.lblFichePlateforme.Text = "Plateforme : $PlateformeCible"
    $cf.txtCommentaire.Text = [string]$g.Commentaire
    $cf.txtTagsJeu.Text = [string]$g.Tags
    $cf.txtDescriptionJeu.Text = [string]$g.Description

    function script:Populate-StatutFiche {
        $cf.wrapStatutJeu.Children.Clear()
        $statutActuel = if ([string]$g.Statut) { [string]$g.Statut } else { "NonCommence" }
        foreach ($statutDef in (Get-TousLesStatuts)) {
            $cleStatut = $statutDef.Cle
            $estActif = ($cleStatut -eq $statutActuel)
            $couleurStatut = $statutDef.CouleurResolue

            $badgeStatut = New-Object System.Windows.Controls.Border
            $badgeStatut.CornerRadius = 20
            $badgeStatut.Padding = '12,7'
            $badgeStatut.Margin = '0,0,8,8'
            $badgeStatut.Cursor = 'Hand'
            $badgeStatut.Tag = $cleStatut
            $badgeStatut.BorderThickness = if ($estActif) { 2 } else { 1 }
            $badgeStatut.BorderBrush = ConvertTo-GDBrush $couleurStatut
            $badgeStatut.Background = if ($estActif) { ConvertTo-GDGradientBrush $couleurStatut } else { [System.Windows.Media.Brushes]::Transparent }
            $badgeStatut.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
            $badgeStatut.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1, 1)
            if ($estActif) {
                $badgeStatut.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
                    Color = [System.Windows.Media.Color]::FromRgb(0,0,0); BlurRadius = 8; ShadowDepth = 2; Opacity = 0.4
                }
            }

            $contenuBadge = New-Object System.Windows.Controls.StackPanel
            $contenuBadge.Orientation = 'Horizontal'
            $dotStatut = New-Object System.Windows.Controls.TextBlock
            $dotStatut.Text = [string][char]0x25CF
            $dotStatut.FontSize = 9
            $dotStatut.VerticalAlignment = 'Center'
            $dotStatut.Margin = '0,0,6,0'
            $dotStatut.Foreground = if ($estActif) { ConvertTo-GDBrush (Get-GDContrastText $couleurStatut) } else { ConvertTo-GDBrush $couleurStatut }
            if ($estActif -and $cleStatut -eq "EnCours") {
                $animPoulsFiche = New-Object System.Windows.Media.Animation.DoubleAnimation(0.3, 1.0, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(900))))
                $animPoulsFiche.AutoReverse = $true
                $animPoulsFiche.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                $dotStatut.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty, $animPoulsFiche)
            }
            $contenuBadge.Children.Add($dotStatut) | Out-Null

            $tbStatut = New-Object System.Windows.Controls.TextBlock
            $tbStatut.Text = $statutDef.Label
            $tbStatut.FontSize = 12
            $tbStatut.FontWeight = 'SemiBold'
            $tbStatut.Foreground = if ($estActif) { ConvertTo-GDBrush (Get-GDContrastText $couleurStatut) } else { ConvertTo-GDBrush $couleurStatut }
            $contenuBadge.Children.Add($tbStatut) | Out-Null
            $badgeStatut.Child = $contenuBadge

            $badgeStatut.Add_MouseEnter({
                $this.RenderTransform.ScaleX = 1.06
                $this.RenderTransform.ScaleY = 1.06
            })
            $badgeStatut.Add_MouseLeave({
                $this.RenderTransform.ScaleX = 1.0
                $this.RenderTransform.ScaleY = 1.0
            })

            $badgeStatut.Add_MouseLeftButtonDown({
                $cleChoisie = $this.Tag
                Invoke-Safe -Contexte "Changer le statut" -Action {
                    $g.Statut = $cleChoisie
                    Populate-StatutFiche
                }
            })
            $cf.wrapStatutJeu.Children.Add($badgeStatut) | Out-Null
        }
    }
    Populate-StatutFiche

    function script:Refresh-NoteFiche {
        $noteActuelle = 0
        [void][int]::TryParse([string]$g.Note, [ref]$noteActuelle)
        if ($noteActuelle -lt 0) { $noteActuelle = 0 }
        if ($noteActuelle -gt 5) { $noteActuelle = 5 }
        $iconesFiche = Get-RatingIconSet (Get-RatingIconName)
        $cf.tbNoteFiche.FontFamily = New-Object System.Windows.Media.FontFamily($iconesFiche.Police)
        $cf.tbNoteFiche.Text = ($iconesFiche.Filled * $noteActuelle) + ($iconesFiche.Empty * (5 - $noteActuelle))
        $cf.tbNoteFiche.Foreground = if ($noteActuelle -ge 5) { ConvertTo-GDBrush $script:starGoldColor } else { (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT) }
    }
    Refresh-NoteFiche

    $cf.tbNoteFiche.Add_MouseMove({
        $e = $args[1]
        $ratioFiche = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
        $hoverFiche = [Math]::Ceiling($ratioFiche * 5)
        if ($hoverFiche -lt 1) { $hoverFiche = 1 }
        if ($hoverFiche -gt 5) { $hoverFiche = 5 }
        $icHover = Get-RatingIconSet (Get-RatingIconName)
        $this.Text = ($icHover.Filled * $hoverFiche) + ($icHover.Empty * (5 - $hoverFiche))
        $this.Foreground = ConvertTo-GDBrush $script:starGoldColor
    })
    $cf.tbNoteFiche.Add_MouseLeave({ Refresh-NoteFiche })
    $cf.tbNoteFiche.Add_MouseLeftButtonDown({
        $e = $args[1]
        $ratioFiche = [Math]::Min(1.0, [Math]::Max(0.01, $e.GetPosition($this).X / [Math]::Max(1, $this.ActualWidth)))
        $hoverFiche = [Math]::Ceiling($ratioFiche * 5)
        if ($hoverFiche -lt 1) { $hoverFiche = 1 }
        if ($hoverFiche -gt 5) { $hoverFiche = 5 }
        Invoke-Safe -Contexte "Noter depuis la fiche" -Action {
            $g.Note = $hoverFiche
            Refresh-NoteFiche
        }
    })

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

    $cf.btnRetirerCover.Add_Click({ Invoke-Safe -Contexte "Retirer la jaquette" -Action { $g.Cover = ""; Load-FicheImage $cf.imgCover "" } })

    $cf.btnChercherJaquette.Add_Click({
        Invoke-Safe -Contexte "Chercher une jaquette" -Action {
            $requete = [System.Uri]::EscapeDataString([string]$g.Nom)
            Start-Process "https://www.steamgriddb.com/search/grids?term=$requete"
        }
    })

    $cf.btnEnregistrerFiche.Add_Click({
        Invoke-Safe -Contexte "Enregistrer la fiche du jeu" -Action {
            $g.Commentaire = $cf.txtCommentaire.Text
            $g.Tags = $cf.txtTagsJeu.Text.Trim()
            $g.Description = $cf.txtDescriptionJeu.Text
            Save-Json $file $games
            Write-GDLog "Fiche du jeu enregistree : $([string]$g.Nom)"
            if ($OnSaved) { & $OnSaved }
            Show-GDMessageBox -Message "Fiche enregistree." -Title "GameDraw" | Out-Null
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
    Enable-GDFadeIn $winO
    $script:co = @{}
    $xamlO.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $co[$_.Name] = $winO.FindName($_.Name)
    }
    Enable-GDTitleBar $winO $co

    # Navigation par categories : une seule page visible a la fois, bouton actif
    # mis en evidence (fond accent, texte fonce) - meme principe que le reste
    # de l'app pour les etats "actifs" (badges de statut, icones, themes...).
    $script:pagesOptions = @("pageTirage", "pageStatuts", "pageApparence", "pageConnexion", "pageDonnees")
    $script:navsOptions = @("navTirage", "navStatuts", "navApparence", "navConnexion", "navDonnees")
    function script:Afficher-PageOptions([string]$nomPage) {
        foreach ($p in $script:pagesOptions) {
            $co[$p].Visibility = if ($p -eq $nomPage) { 'Visible' } else { 'Collapsed' }
        }
        foreach ($n in $script:navsOptions) {
            $estActif = ($co[$n].Tag -eq $nomPage)
            $co[$n].Background = if ($estActif) { ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT } else { [System.Windows.Media.Brushes]::Transparent }
            $co[$n].Foreground = if ($estActif) { ConvertTo-GDBrush $themes[$script:currentTheme].DARKBG } else { ConvertTo-GDBrush $themes[$script:currentTheme].MUTED }
        }
    }
    foreach ($nomNav in $script:navsOptions) {
        $co[$nomNav].Add_Click({
            Invoke-Safe -Contexte "Navigation Options" -Action { Afficher-PageOptions $this.Tag }
        })
    }
    Afficher-PageOptions "pageTirage"

    function script:Populate-IconMenu {
        $co.stackIconList.Children.Clear()
        $iconeActuelle = Get-RatingIconName
        $masqueesIcones = @(Get-IconesNotationMasquees)
        foreach ($key in $script:ratingIconOrder) {
            if ($masqueesIcones -contains $key) { continue }
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
            $preview.FontFamily = New-Object System.Windows.Media.FontFamily($ic.Police)
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

    function script:Populate-IconesAAfficher {
        $co.wrapIconesAAfficher.Children.Clear()
        $masqueesActuelles = @(Get-IconesNotationMasquees)
        foreach ($key in $script:ratingIconOrder) {
            $chkIcone = New-Object System.Windows.Controls.CheckBox
            $chkIcone.Content = $key
            $chkIcone.IsChecked = ($masqueesActuelles -notcontains $key)
            $chkIcone.Margin = '0,0,14,6'
            $chkIcone.Tag = $key
            $chkIcone.Add_Click({
                $cleBascule = $this.Tag
                Invoke-Safe -Contexte "Basculer l'affichage d'une icone de notation" -Action {
                    $masquees = @(Get-IconesNotationMasquees)
                    $visiblesRestantes = $script:ratingIconOrder.Count - $masquees.Count
                    if (-not $this.IsChecked -and $visiblesRestantes -le 1) {
                        $this.IsChecked = $true
                        Show-GDMessageBox -Message "Au moins un style d'icone doit rester propose." -Title "Info" | Out-Null
                        return
                    }
                    if ($this.IsChecked) {
                        $masquees = @($masquees | Where-Object { $_ -ne $cleBascule })
                    } else {
                        $masquees += $cleBascule
                    }
                    Save-IconesNotationMasquees $masquees
                    Populate-IconMenu
                }
            })
            $co.wrapIconesAAfficher.Children.Add($chkIcone) | Out-Null
        }
    }
    Populate-IconesAAfficher

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
        $cfgIcone = Get-GDConfig
        $cheminPerso = [string]$cfgIcone.IconePersonnaliseChemin

        $clesAAfficher = @("Original", "Bleu", "Sombre")

        foreach ($key in $clesAAfficher) {
            $info = $script:iconChoices[$key]
            $isActive = ($key -eq $choixActuel)

            $item = New-Object System.Windows.Controls.StackPanel
            $item.Margin = '0,0,14,10'
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
                    $img.HorizontalAlignment = 'Center'
                    $img.VerticalAlignment = 'Center'
                    $border.Child = $img
                } catch { }
            }
            $item.Children.Add($border) | Out-Null

            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $info.Nom
            $lbl.FontSize = 11
            $lbl.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
            $lbl.HorizontalAlignment = 'Center'
            $lbl.Margin = '0,4,0,0'
            $item.Children.Add($lbl) | Out-Null

            if ($isActive) {
                $checkApp = New-Object System.Windows.Controls.TextBlock
                $checkApp.Text = [string][char]0xE73E
                $checkApp.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
                $checkApp.FontSize = 11
                $checkApp.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
                $checkApp.HorizontalAlignment = 'Center'
                $checkApp.Margin = '0,2,0,0'
                $item.Children.Add($checkApp) | Out-Null
            }

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

        # Tuile "Personnalise" : uniquement si l'utilisateur a deja fourni sa
        # propre image (sinon rien a montrer / previsualiser).
        if ($cheminPerso -and (Test-Path $cheminPerso)) {
            $isActive = ($choixActuel -eq "Personnalise")
            $itemP = New-Object System.Windows.Controls.StackPanel
            $itemP.Margin = '0,0,14,10'
            $itemP.Cursor = 'Hand'
            $itemP.Tag = "Personnalise"

            $borderP = New-Object System.Windows.Controls.Border
            $borderP.Width = 64
            $borderP.Height = 64
            $borderP.CornerRadius = 10
            $borderP.ClipToBounds = $true
            $borderP.BorderThickness = if ($isActive) { 2 } else { 1 }
            $borderP.BorderBrush = if ($isActive) { ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT } else { ConvertTo-GDBrush $themes[$script:currentTheme].BORDER }
            try {
                $bmpP = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmpP.BeginInit()
                $bmpP.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmpP.DecodePixelWidth = 96
                $bmpP.UriSource = New-Object System.Uri((Resolve-Path $cheminPerso).Path, [System.UriKind]::Absolute)
                $bmpP.EndInit()
                $bmpP.Freeze()
                $imgP = New-Object System.Windows.Controls.Image
                $imgP.Source = $bmpP
                $imgP.Stretch = 'UniformToFill'
                $imgP.HorizontalAlignment = 'Center'
                $borderP.Child = $imgP
            } catch { }
            $itemP.Children.Add($borderP) | Out-Null

            $lblP = New-Object System.Windows.Controls.TextBlock
            $lblP.Text = "Personnalise"
            $lblP.FontSize = 11
            $lblP.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
            $lblP.HorizontalAlignment = 'Center'
            $lblP.Margin = '0,4,0,0'
            $itemP.Children.Add($lblP) | Out-Null

            if ($isActive) {
                $checkP = New-Object System.Windows.Controls.TextBlock
                $checkP.Text = [string][char]0xE73E
                $checkP.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
                $checkP.FontSize = 11
                $checkP.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
                $checkP.HorizontalAlignment = 'Center'
                $checkP.Margin = '0,2,0,0'
                $itemP.Children.Add($checkP) | Out-Null
            }

            $itemP.Add_MouseLeftButtonDown({
                Invoke-Safe -Contexte "Changer l'icone de l'application" -Action {
                    Save-IconApp "Personnalise"
                    Write-GDLog "Icone d'application changee : Personnalise -> rechargement de la fenetre principale"
                    $script:reloadRequested = $true
                    $winO.Close()
                    $window.Close()
                }
            })
            $co.stackIconeApp.Children.Add($itemP) | Out-Null
        }

        # Tuile "+" : choisir sa propre image comme icone.
        $itemAjout = New-Object System.Windows.Controls.StackPanel
        $itemAjout.Cursor = 'Hand'
        $borderAjout = New-Object System.Windows.Controls.Border
        $borderAjout.Width = 64
        $borderAjout.Height = 64
        $borderAjout.CornerRadius = 10
        $borderAjout.BorderThickness = 1
        $borderAjout.BorderBrush = ConvertTo-GDBrush $themes[$script:currentTheme].BORDER
        $borderAjout.Background = ConvertTo-GDBrush $themes[$script:currentTheme].INPUT
        $glyphAjout = New-Object System.Windows.Controls.TextBlock
        $glyphAjout.Text = [string][char]0xE710
        $glyphAjout.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
        $glyphAjout.FontSize = 22
        $glyphAjout.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].MUTED
        $glyphAjout.HorizontalAlignment = 'Center'
        $glyphAjout.VerticalAlignment = 'Center'
        $borderAjout.Child = $glyphAjout
        $itemAjout.Children.Add($borderAjout) | Out-Null

        $lblAjout = New-Object System.Windows.Controls.TextBlock
        $lblAjout.Text = "Ajouter..."
        $lblAjout.FontSize = 11
        $lblAjout.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].MUTED
        $lblAjout.HorizontalAlignment = 'Center'
        $lblAjout.Margin = '0,4,0,0'
        $itemAjout.Children.Add($lblAjout) | Out-Null

        $itemAjout.Add_MouseLeftButtonDown({
            Invoke-Safe -Contexte "Ajouter une icone personnalisee" -Action {
                $dlg = New-Object Microsoft.Win32.OpenFileDialog
                $dlg.Filter = "Images et icones (*.ico;*.png;*.jpg;*.jpeg;*.bmp)|*.ico;*.png;*.jpg;*.jpeg;*.bmp"
                $dlg.Title = "Choisir une icone pour GameDraw"
                if ($dlg.ShowDialog() -ne $true) { return }

                $extension = [System.IO.Path]::GetExtension($dlg.FileName)
                $dest = Join-Path $root "icone_personnalisee$extension"
                Copy-Item -Path $dlg.FileName -Destination $dest -Force

                Set-GDConfig @{ IconeApp = "Personnalise"; IconePersonnaliseChemin = $dest }
                Write-GDLog "Icone personnalisee ajoutee : $dest -> rechargement de la fenetre principale"

                if ($extension -ne ".ico") {
                    Show-GDMessageBox -Message "Icone appliquee. Note : pour le raccourci Bureau, un fichier .ico donne un meilleur resultat qu'une image .png/.jpg (Windows l'affiche parfois mal sur les raccourcis, meme si l'icone de l'application elle-meme s'affichera correctement)." -Title "GameDraw" | Out-Null
                }

                $script:reloadRequested = $true
                $winO.Close()
                $window.Close()
            }
        })
        $co.stackIconeApp.Children.Add($itemAjout) | Out-Null
    }
    Populate-IconeAppMenu

    $co.txtCouleurEtoiles.Text = Get-StarColor

    function script:Appliquer-CouleurEtoile([string]$hex) {
        Save-StarColor $hex
        $script:starGoldColor = $hex
        $co.txtCouleurEtoiles.Text = $hex
    }

    $paletteCouleursEtoiles = @("#FFD700", "#F87171", "#FB923C", "#6366F1", "#22D3EE", "#EC4899", "#2DD4BF", "#A78BFA", "#34D399", "#FFFFFF")
    foreach ($nuance in $paletteCouleursEtoiles) {
        $swatch = New-Object System.Windows.Controls.Border
        $swatch.Width = 30
        $swatch.Height = 30
        $swatch.CornerRadius = 15
        $swatch.Margin = '0,0,8,8'
        $swatch.Cursor = 'Hand'
        $swatch.Background = ConvertTo-GDBrush $nuance
        $swatch.BorderBrush = ConvertTo-GDBrush $themes[$script:currentTheme].BORDER
        $swatch.BorderThickness = 2
        $swatch.Tag = $nuance
        $swatch.ToolTip = $nuance
        $swatch.Add_MouseEnter({ $this.BorderThickness = 3 })
        $swatch.Add_MouseLeave({ $this.BorderThickness = 2 })
        $swatch.Add_MouseLeftButtonDown({
            $nuanceChoisie = $this.Tag
            Invoke-Safe -Contexte "Choisir une couleur d'icone" -Action { Appliquer-CouleurEtoile $nuanceChoisie }
        })
        $co.wrapPaletteCouleurs.Children.Add($swatch) | Out-Null
    }
    $co.chkAnimationTirage.IsChecked = Get-AnimationTirage

    function script:Populate-StyleAnimation {
        $co.stackStyleAnimation.Children.Clear()
        $styleActuel = Get-StyleAnimationTirage
        foreach ($style in @("Roue", "Bandeau", "Machine")) {
            $estActif = ($style -eq $styleActuel)
            $badgeStyle = New-Object System.Windows.Controls.Border
            $badgeStyle.CornerRadius = 16
            $badgeStyle.Padding = '14,7'
            $badgeStyle.Margin = '0,0,8,8'
            $badgeStyle.Cursor = 'Hand'
            $badgeStyle.Tag = $style
            $badgeStyle.BorderThickness = if ($estActif) { 2 } else { 1 }
            $badgeStyle.BorderBrush = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
            $badgeStyle.Background = if ($estActif) { ConvertTo-GDGradientBrush $themes[$script:currentTheme].ACCENT } else { [System.Windows.Media.Brushes]::Transparent }
            $tbStyle = New-Object System.Windows.Controls.TextBlock
            $tbStyle.Text = switch ($style) { "Roue" { "Roue de roulette" }; "Bandeau" { "Bandeau defilant" }; "Machine" { "Machine a sous (des)" } }
            $tbStyle.FontSize = 12
            $tbStyle.FontWeight = 'SemiBold'
            $tbStyle.Foreground = if ($estActif) { ConvertTo-GDBrush $themes[$script:currentTheme].DARKBG } else { ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT }
            $badgeStyle.Child = $tbStyle
            $badgeStyle.Add_MouseLeftButtonDown({
                $styleChoisi = $this.Tag
                Invoke-Safe -Contexte "Choisir le style d'animation" -Action {
                    Save-StyleAnimationTirage $styleChoisi
                    Populate-StyleAnimation
                }
            })
            $co.stackStyleAnimation.Children.Add($badgeStyle) | Out-Null
        }
    }
    Populate-StyleAnimation
    $co.chkEviterRepetitionDefaut.IsChecked = Get-EviterRepetitionDefaut
    $co.chkAvertirNouveauTirage.IsChecked = Get-AvertirNouveauTirage
    $co.chkNotifierFinSession.IsChecked = Get-NotifierFinSession
    $co.txtHistoriqueCount.Text = [string](Get-HistoriqueCount)

    function script:Populate-ObjectifsUI {
        $co.cmbObjectifDefaut.Items.Clear()
        $itemAucune = New-Object System.Windows.Controls.ComboBoxItem
        $itemAucune.Content = "(aucune preference)"
        $co.cmbObjectifDefaut.Items.Add($itemAucune) | Out-Null
        foreach ($obj in (Get-ObjectifsListe)) {
            $itemO = New-Object System.Windows.Controls.ComboBoxItem
            $itemO.Content = $obj
            $co.cmbObjectifDefaut.Items.Add($itemO) | Out-Null
        }
        $objDefaut = Get-ObjectifDefaut
        $co.cmbObjectifDefaut.SelectedIndex = 0
        for ($i = 0; $i -lt $co.cmbObjectifDefaut.Items.Count; $i++) {
            if ($co.cmbObjectifDefaut.Items[$i].Content -eq $objDefaut) { $co.cmbObjectifDefaut.SelectedIndex = $i }
        }

        $co.stackObjectifsListe.Children.Clear()
        foreach ($obj in (Get-ObjectifsListe)) {
            $ligneObj = New-Object System.Windows.Controls.Grid
            $ligneObj.Margin = '0,0,0,6'
            $colTexte = New-Object System.Windows.Controls.ColumnDefinition
            $colTexte.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
            $colBtn = New-Object System.Windows.Controls.ColumnDefinition
            $colBtn.Width = 'Auto'
            $ligneObj.ColumnDefinitions.Add($colTexte) | Out-Null
            $ligneObj.ColumnDefinitions.Add($colBtn) | Out-Null

            $tbObj = New-Object System.Windows.Controls.TextBlock
            $tbObj.Text = $obj
            $tbObj.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
            $tbObj.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($tbObj, 0)
            $ligneObj.Children.Add($tbObj) | Out-Null

            $btnDelObj = New-Object System.Windows.Controls.Button
            $btnDelObj.Content = [string][char]0xE74D
            $btnDelObj.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
            $btnDelObj.Width = 30
            $btnDelObj.Height = 26
            $btnDelObj.Padding = '0'
            $btnDelObj.Style = $winO.Resources["SecondaryButton"]
            $btnDelObj.Tag = $obj
            [System.Windows.Controls.Grid]::SetColumn($btnDelObj, 1)
            $btnDelObj.Add_Click({
                $objACapte = $this.Tag
                Invoke-Safe -Contexte "Supprimer un objectif" -Action {
                    $liste = @(Get-ObjectifsListe | Where-Object { $_ -ne $objACapte })
                    Save-ObjectifsListe $liste
                    Populate-ObjectifsUI
                }
            })
            $ligneObj.Children.Add($btnDelObj) | Out-Null

            $co.stackObjectifsListe.Children.Add($ligneObj) | Out-Null
        }
    }
    Populate-ObjectifsUI

    $co.btnAjouterObjectif.Add_Click({
        Invoke-Safe -Contexte "Ajouter un objectif" -Action {
            $nouvel = $co.txtNouvelObjectif.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($nouvel)) { return }
            $liste = @(Get-ObjectifsListe)
            if ($liste -contains $nouvel) {
                Show-GDMessageBox -Message "Cet objectif existe deja." -Title "Info" | Out-Null
                return
            }
            $liste += $nouvel
            Save-ObjectifsListe $liste
            $co.txtNouvelObjectif.Text = ""
            Populate-ObjectifsUI
        }
    })

    function script:Populate-StatutsUI {
        $co.stackStatutsListe.Children.Clear()
        foreach ($perso in (Get-StatutsPersonnalises)) {
            $ligneStatut = New-Object System.Windows.Controls.Grid
            $ligneStatut.Margin = '0,0,0,6'
            $colPastille = New-Object System.Windows.Controls.ColumnDefinition
            $colPastille.Width = 'Auto'
            $colTexte = New-Object System.Windows.Controls.ColumnDefinition
            $colTexte.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
            $colBtn = New-Object System.Windows.Controls.ColumnDefinition
            $colBtn.Width = 'Auto'
            $ligneStatut.ColumnDefinitions.Add($colPastille) | Out-Null
            $ligneStatut.ColumnDefinitions.Add($colTexte) | Out-Null
            $ligneStatut.ColumnDefinitions.Add($colBtn) | Out-Null

            $pastilleStatut = New-Object System.Windows.Controls.Border
            $pastilleStatut.Width = 16
            $pastilleStatut.Height = 16
            $pastilleStatut.CornerRadius = 8
            $pastilleStatut.Margin = '0,0,8,0'
            $pastilleStatut.Background = ConvertTo-GDBrush ([string]$perso.Couleur)
            [System.Windows.Controls.Grid]::SetColumn($pastilleStatut, 0)
            $ligneStatut.Children.Add($pastilleStatut) | Out-Null

            $tbStatutPerso = New-Object System.Windows.Controls.TextBlock
            $tbStatutPerso.Text = [string]$perso.Label
            $tbStatutPerso.Foreground = [System.Windows.Media.Brushes]::White
            $tbStatutPerso.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($tbStatutPerso, 1)
            $ligneStatut.Children.Add($tbStatutPerso) | Out-Null

            $btnDelStatut = New-Object System.Windows.Controls.Button
            $btnDelStatut.Content = [string][char]0x2715
            $btnDelStatut.Width = 30
            $btnDelStatut.Height = 26
            $btnDelStatut.Padding = '0'
            $btnDelStatut.Style = $winO.Resources["SecondaryButton"]
            $btnDelStatut.Tag = [string]$perso.Cle
            [System.Windows.Controls.Grid]::SetColumn($btnDelStatut, 2)
            $btnDelStatut.Add_Click({
                $cleACapte = $this.Tag
                Invoke-Safe -Contexte "Supprimer un statut personnalise" -Action {
                    $liste = @(Get-StatutsPersonnalises | Where-Object { [string]$_.Cle -ne $cleACapte })
                    Save-StatutsPersonnalises $liste
                    Populate-StatutsUI
                }
            })
            $ligneStatut.Children.Add($btnDelStatut) | Out-Null

            $co.stackStatutsListe.Children.Add($ligneStatut) | Out-Null
        }
    }
    Populate-StatutsUI

    $paletteCouleursStatut = @("#F87171", "#FB923C", "#FBBF24", "#4ADE80", "#22D3EE", "#6366F1", "#A78BFA", "#EC4899", "#94A3B8", "#FFFFFF")
    foreach ($nuanceStatut in $paletteCouleursStatut) {
        $swatchStatut = New-Object System.Windows.Controls.Border
        $swatchStatut.Width = 28
        $swatchStatut.Height = 28
        $swatchStatut.CornerRadius = 14
        $swatchStatut.Margin = '0,0,8,8'
        $swatchStatut.Cursor = 'Hand'
        $swatchStatut.Background = ConvertTo-GDBrush $nuanceStatut
        $swatchStatut.BorderBrush = ConvertTo-GDBrush $themes[$script:currentTheme].BORDER
        $swatchStatut.BorderThickness = 2
        $swatchStatut.Tag = $nuanceStatut
        $swatchStatut.ToolTip = "Cliquer pour ajouter le nouveau statut avec cette couleur"
        $swatchStatut.Add_MouseEnter({ $this.BorderThickness = 3 })
        $swatchStatut.Add_MouseLeave({ $this.BorderThickness = 2 })
        $swatchStatut.Add_MouseLeftButtonDown({
            $couleurChoisie = $this.Tag
            Invoke-Safe -Contexte "Ajouter un statut personnalise" -Action {
                $nomStatut = $co.txtNouveauStatut.Text.Trim()
                if ([string]::IsNullOrWhiteSpace($nomStatut)) {
                    Show-GDMessageBox -Message "Tape d'abord un nom pour le nouveau statut, puis clique une couleur." -Title "Info" | Out-Null
                    return
                }
                $cleGeneree = "Perso_" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
                $liste = @(Get-StatutsPersonnalises)
                $liste += [pscustomobject]@{ Cle = $cleGeneree; Label = $nomStatut; Couleur = $couleurChoisie }
                Save-StatutsPersonnalises $liste
                $co.txtNouveauStatut.Text = ""
                Populate-StatutsUI
                Show-GDMessageBox -Message "Statut '$nomStatut' ajoute." -Title "GameDraw" | Out-Null
            }
        })
        $co.wrapPaletteStatut.Children.Add($swatchStatut) | Out-Null
    }

    $co.btnAjouterStatut.Add_Click({
        Invoke-Safe -Contexte "Ajouter un statut personnalise" -Action {
            if ([string]::IsNullOrWhiteSpace($co.txtNouveauStatut.Text)) {
                Show-GDMessageBox -Message "Tape d'abord un nom pour le nouveau statut." -Title "Info" | Out-Null
                return
            }
            Show-GDMessageBox -Message "Clique maintenant une couleur dans la palette juste en dessous pour valider l'ajout." -Title "Info" | Out-Null
        }
    })

    function script:Populate-StatutsAAfficher {
        $co.wrapStatutsAAfficher.Children.Clear()
        $masquesActuels = @(Get-StatutsMasques)
        foreach ($cle in $script:statutsOrdre) {
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Content = $script:statutsJeu[$cle].Label
            $chk.IsChecked = ($masquesActuels -notcontains $cle)
            $chk.Margin = '0,0,18,8'
            $chk.Tag = $cle
            $chk.Add_Click({
                $cleBascule = $this.Tag
                Invoke-Safe -Contexte "Basculer l'affichage d'un statut" -Action {
                    $masques = @(Get-StatutsMasques)
                    if ($this.IsChecked) {
                        $masques = @($masques | Where-Object { $_ -ne $cleBascule })
                    } else {
                        $masques += $cleBascule
                    }
                    Save-StatutsMasques $masques
                }
            })
            $co.wrapStatutsAAfficher.Children.Add($chk) | Out-Null
        }
    }
    Populate-StatutsAAfficher

    $boutonsMasquesActuels = Get-BoutonsMasques
    $co.chkMasquerTheme.IsChecked = ($boutonsMasquesActuels -contains "Theme")
    $co.chkMasquerStats.IsChecked = ($boutonsMasquesActuels -contains "Stats")
    $co.chkMasquerBacklog.IsChecked = ($boutonsMasquesActuels -contains "Backlog")
    $co.chkMasquerPlateformes.IsChecked = ($boutonsMasquesActuels -contains "Plateformes")
    $co.chkMasquerGererJeux.IsChecked = ($boutonsMasquesActuels -contains "GererJeux")

    function script:Toggle-BoutonMasque([string]$cle, [bool]$masque) {
        $liste = @(Get-BoutonsMasques)
        if ($masque) {
            if ($liste -notcontains $cle) { $liste += $cle }
        } else {
            $liste = @($liste | Where-Object { $_ -ne $cle })
        }
        Set-BoutonsMasques $liste
    }
    $co.chkMasquerTheme.Add_Click({
        Invoke-Safe -Contexte "Masquer le bouton theme" -Action { Toggle-BoutonMasque "Theme" ([bool]$co.chkMasquerTheme.IsChecked) }
    })
    $co.chkMasquerStats.Add_Click({
        Invoke-Safe -Contexte "Masquer le bouton statistiques" -Action { Toggle-BoutonMasque "Stats" ([bool]$co.chkMasquerStats.IsChecked) }
    })
    $co.chkMasquerBacklog.Add_Click({
        Invoke-Safe -Contexte "Masquer le bouton backlog" -Action { Toggle-BoutonMasque "Backlog" ([bool]$co.chkMasquerBacklog.IsChecked) }
    })
    $co.chkMasquerPlateformes.Add_Click({
        Invoke-Safe -Contexte "Masquer le bouton plateformes" -Action { Toggle-BoutonMasque "Plateformes" ([bool]$co.chkMasquerPlateformes.IsChecked) }
    })
    $co.chkMasquerGererJeux.Add_Click({
        Invoke-Safe -Contexte "Masquer le bouton gerer les jeux" -Action { Toggle-BoutonMasque "GererJeux" ([bool]$co.chkMasquerGererJeux.IsChecked) }
    })

    $co.chkAnimationTirage.Add_Click({
        Invoke-Safe -Contexte "Basculer l'animation" -Action { Set-GDConfig @{ AnimationTirage = [bool]$co.chkAnimationTirage.IsChecked } }
    })
    $co.chkEviterRepetitionDefaut.Add_Click({
        Invoke-Safe -Contexte "Basculer eviter repetition par defaut" -Action { Set-GDConfig @{ EviterRepetitionDefaut = [bool]$co.chkEviterRepetitionDefaut.IsChecked } }
    })
    $co.chkAvertirNouveauTirage.Add_Click({
        Invoke-Safe -Contexte "Basculer avertissement nouveau tirage" -Action { Save-AvertirNouveauTirage ([bool]$co.chkAvertirNouveauTirage.IsChecked) }
    })
    $co.chkNotifierFinSession.Add_Click({
        Invoke-Safe -Contexte "Basculer notification fin de session" -Action { Save-NotifierFinSession ([bool]$co.chkNotifierFinSession.IsChecked) }
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
                Show-GDMessageBox -Message "Format invalide. Utilisez un code hexadecimal du type #FFD700." -Title "Info" | Out-Null
                return
            }
            Appliquer-CouleurEtoile $hex
            Show-GDMessageBox -Message "Couleur mise a jour." -Title "GameDraw" | Out-Null
        }
    })

    $co.txtEmplacementDonnees.Text = $script:root
    $co.txtRawgApiKey.Text = Get-RawgApiKey

    $co.btnEnregistrerRawgKey.Add_Click({
        Invoke-Safe -Contexte "Enregistrer la cle RAWG" -Action {
            Save-RawgApiKey $co.txtRawgApiKey.Text.Trim()
            Show-GDMessageBox -Message "Cle enregistree." -Title "GameDraw" | Out-Null
        }
    })

    $co.txtSteamApiKey.Text = Get-SteamApiKey
    $co.txtSteamId64.Text = Get-SteamId64

    $co.btnEnregistrerSteamKey.Add_Click({
        Invoke-Safe -Contexte "Enregistrer la cle Steam" -Action {
            Save-SteamApiKey $co.txtSteamApiKey.Text.Trim()
            Show-GDMessageBox -Message "Cle Steam enregistree." -Title "GameDraw" | Out-Null
        }
    })
    $co.btnEnregistrerSteamId.Add_Click({
        Invoke-Safe -Contexte "Enregistrer le SteamID64" -Action {
            Save-SteamId64 $co.txtSteamId64.Text.Trim()
            Show-GDMessageBox -Message "SteamID64 enregistre." -Title "GameDraw" | Out-Null
        }
    })

    $co.btnOuvrirEmplacement.Add_Click({
        Invoke-Safe -Contexte "Ouvrir le dossier de donnees" -Action {
            Start-Process "explorer.exe" -ArgumentList "`"$script:root`""
        }
    })

    $co.btnChangerEmplacement.Add_Click({
        Invoke-Safe -Contexte "Changer l'emplacement des donnees" -Action {
            $dlgDossier = New-Object System.Windows.Forms.FolderBrowserDialog
            $dlgDossier.Description = "Choisir le nouvel emplacement des donnees GameDraw"
            $dlgDossier.SelectedPath = $script:root
            $resultat = $dlgDossier.ShowDialog()
            if ($resultat -ne [System.Windows.Forms.DialogResult]::OK) { return }

            $nouveauDossier = $dlgDossier.SelectedPath
            if ($nouveauDossier -eq $script:root) { return }

            # Le nouveau dossier choisi doit etre vide ou nouveau : on n'ecrase
            # jamais silencieusement des fichiers existants a la destination.
            $nouveauSousDossier = Join-Path $nouveauDossier "GameDraw"
            if ((Test-Path $nouveauSousDossier) -and (Get-ChildItem $nouveauSousDossier -ErrorAction SilentlyContinue)) {
                $ecraser = Show-GDMessageBox -Message "Le dossier '$nouveauSousDossier' existe deja et n'est pas vide. Continuer quand meme et fusionner/ecraser son contenu ?" -Title "Confirmation" -Buttons "YesNo" -Icon "Warning"
                if ($ecraser -ne 'Yes') { return }
            }

            $confirm = Show-GDMessageBox -Message "Toutes les donnees (bibliotheques, historique, catalogues, images) vont etre copiees vers :`n$nouveauSousDossier`n`nL'ancien emplacement n'est pas supprime (copie de securite). Continuer ?" -Title "Confirmation" -Buttons "YesNo" -Icon "Question"
            if ($confirm -ne 'Yes') { return }

            New-Item -ItemType Directory -Path $nouveauSousDossier -Force | Out-Null
            Get-ChildItem -Path $script:root -Filter "*.json" -ErrorAction SilentlyContinue | Copy-Item -Destination $nouveauSousDossier -Force
            $ancienImages = Join-Path $script:root "images"
            if (Test-Path $ancienImages) {
                Copy-Item -Path $ancienImages -Destination (Join-Path $nouveauSousDossier "images") -Recurse -Force
            }
            $ancienLog = Join-Path $script:root "error.log"
            if (Test-Path $ancienLog) { Copy-Item -Path $ancienLog -Destination $nouveauSousDossier -Force }

            New-Item -ItemType Directory -Path (Split-Path -Parent $script:appDataPointer) -Force -ErrorAction SilentlyContinue | Out-Null
            Set-Content -Path $script:appDataPointer -Value $nouveauSousDossier -Encoding UTF8

            Write-GDLog "Emplacement des donnees change : $script:root -> $nouveauSousDossier"
            Show-GDMessageBox -Message "Donnees copiees vers le nouvel emplacement.`n`nAncien emplacement conserve (non supprime) : $script:root`n`nGameDraw doit redemarrer completement pour utiliser le nouvel emplacement (un simple rechargement de fenetre ne suffit pas) - l'application va se fermer, relance-la avec ton raccourci habituel." -Title "GameDraw" | Out-Null

            $winO.Close()
            $window.Close()
            [Environment]::Exit(0)
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
                Show-GDMessageBox -Message "Tirage-Jeux.ps1 introuvable a : $ps1Path" -Title "Erreur" | Out-Null
                return
            }

            New-GDShortcut -ps1Path $ps1Path -shortcutPath $shortcutPath -iconFile $iconPathLnk

            Write-GDLog "Raccourci bureau cree : $shortcutPath"
            Show-GDMessageBox -Message "Raccourci cree sur le Bureau. Double-clic = demande d'elevation directe, sans fenetre intermediaire." -Title "GameDraw" | Out-Null
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
            Show-GDMessageBox -Message "Sauvegarde creee :`n$($dlg.FileName)" -Title "GameDraw" | Out-Null
        }
    })

    $co.btnRestaurerConfig.Add_Click({
        Invoke-Safe -Contexte "Restauration de la config" -Action {
            $dlg = New-Object Microsoft.Win32.OpenFileDialog
            $dlg.Filter = "Archive GameDraw (*.zip)|*.zip"
            if ($dlg.ShowDialog() -ne $true) { return }

            $confirm = Show-GDMessageBox -Message "Cette operation va ECRASER toutes les donnees actuelles (jeux, historique, plateformes, config, catalogues, images) avec celles de l'archive.`n`nContinuer ?" -Title "Confirmation" -Buttons "YesNo" -Icon "Warning"
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
            Show-GDMessageBox -Message "Restauration terminee. La fenetre va se recharger." -Title "GameDraw" | Out-Null

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
    Enable-GDFadeIn $winC
    $script:cc = @{}
    $xamlC.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cc[$_.Name] = $winC.FindName($_.Name)
    }
    Enable-GDTitleBar $winC $cc

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
                Show-GDMessageBox -Message "Selectionne d'abord une plateforme dans 'Gerer les jeux'." -Title "Info" | Out-Null
                return
            }
            $selection = @($cc.stackCatalogue.Children | ForEach-Object { $_.Children[0] } | Where-Object { $_.IsChecked })
            if ($selection.Count -eq 0) {
                Show-GDMessageBox -Message "Aucun jeu coche." -Title "Info" | Out-Null
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
            Show-GDMessageBox -Message "$ajoutes jeu(x) ajoute(s) a la bibliotheque '$PlateformeCible'." -Title "GameDraw" | Out-Null
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
        "Minutes"  { return $n }
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
    Enable-GDFadeIn $winS
    $script:cs = @{}
    $xamlS.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cs[$_.Name] = $winS.FindName($_.Name)
    }
    Enable-GDTitleBar $winS $cs

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
        $card.BorderBrush = ConvertTo-GDBrush ($themes[$script:currentTheme].BORDER)
        $card.BorderThickness = 1
        $card.CornerRadius = 10
        $card.Padding = 16
        $card.Margin = '0,0,0,12'
        $card.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
            Color = [System.Windows.Media.Color]::FromRgb(0,0,0); BlurRadius = 12; ShadowDepth = 2; Opacity = 0.22
        }

        $stack = New-Object System.Windows.Controls.StackPanel
        $tbNom = New-Object System.Windows.Controls.TextBlock
        $tbNom.Text = "$([string]$p.Nom)$(if (-not $p.Actif) { '  (inactive)' })"
        $tbNom.FontWeight = 'Bold'
        $tbNom.FontSize = 15
        $tbNom.Foreground = ConvertTo-GDBrush ($themes[$script:currentTheme].ACCENT)
        $stack.Children.Add($tbNom) | Out-Null

        $tbDetail = New-Object System.Windows.Controls.TextBlock
        $tbDetail.Text = "$total jeu(x) au total  |  $notes note(s) ($pctNotes%)  |  $dejaTires deja tire(s) ce cycle"
        $tbDetail.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
        $tbDetail.Margin = '0,6,0,0'
        $tbDetail.TextWrapping = 'Wrap'
        $stack.Children.Add($tbDetail) | Out-Null

        $prgNotes = New-Object System.Windows.Controls.ProgressBar
        $prgNotes.Height = 6
        $prgNotes.Minimum = 0
        $prgNotes.Maximum = 100
        $prgNotes.Value = $pctNotes
        $prgNotes.Margin = '0,8,0,0'
        $prgNotes.Background = ConvertTo-GDBrush $themes[$script:currentTheme].INPUT
        $prgNotes.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
        $prgNotes.BorderThickness = 0
        $stack.Children.Add($prgNotes) | Out-Null

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
        $tbVide.Foreground = (ConvertTo-GDBrush $themes[$script:currentTheme].TEXT)
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
    Enable-GDFadeIn $winB
    $script:cb = @{}
    $xamlB.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cb[$_.Name] = $winB.FindName($_.Name)
    }
    Enable-GDTitleBar $winB $cb

    $script:backlogFiltreStatutActif = "Tous"
    function script:Populate-StatutTabs {
        $cb.wrapStatutTabs.Children.Clear()
        $labelsTabs = @("Tous") + @((Get-TousLesStatuts) | ForEach-Object { $_.Label })
        foreach ($labelTab in $labelsTabs) {
            $estActifTab = ($labelTab -eq $script:backlogFiltreStatutActif)
            $ongletStatut = New-Object System.Windows.Controls.Border
            $ongletStatut.CornerRadius = 16
            $ongletStatut.Padding = '14,7'
            $ongletStatut.Margin = '0,0,8,0'
            $ongletStatut.Cursor = 'Hand'
            $ongletStatut.Tag = $labelTab
            $ongletStatut.Background = if ($estActifTab) { ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT } else { ConvertTo-GDBrush $themes[$script:currentTheme].INPUT }
            $tbOnglet = New-Object System.Windows.Controls.TextBlock
            $tbOnglet.Text = $labelTab
            $tbOnglet.FontSize = 12
            $tbOnglet.FontWeight = 'SemiBold'
            $tbOnglet.Foreground = if ($estActifTab) { ConvertTo-GDBrush $themes[$script:currentTheme].DARKBG } else { ConvertTo-GDBrush $themes[$script:currentTheme].MUTED }
            $ongletStatut.Child = $tbOnglet
            $ongletStatut.Add_MouseLeftButtonDown({
                $labelChoisi = $this.Tag
                Invoke-Safe -Contexte "Filtrer par statut" -Action {
                    $script:backlogFiltreStatutActif = $labelChoisi
                    Populate-StatutTabs
                    Refresh-Backlog
                }
            })
            $cb.wrapStatutTabs.Children.Add($ongletStatut) | Out-Null
        }
    }
    Populate-StatutTabs

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
        $filtreStatut = if ($script:backlogFiltreStatutActif) { $script:backlogFiltreStatutActif } else { "Tous" }
        $filtreNote = if ($cb.cmbFiltreNote.SelectedItem) { $cb.cmbFiltreNote.SelectedItem.Content } else { "Toutes les notes" }
        $t = $themes[$script:currentTheme]
        $icones = Get-RatingIconSet (Get-RatingIconName)
        $affiches = 0

        for ($idx = 0; $idx -lt $games.Count; $idx++) {
            $g = $games[$idx]
            $nomStr = [string]$g.Nom
            if ($filtre -and ($nomStr.ToLower() -notlike "*$filtre*")) { continue }

            $note = 0
            [void][int]::TryParse([string]$g.Note, [ref]$note)
            if ($note -lt 0) { $note = 0 }
            if ($note -gt 5) { $note = 5 }

            $statutJeuFiltre = if ([string]$g.Statut) { [string]$g.Statut } else { "NonCommence" }
            $defFiltre = (Get-TousLesStatuts -InclureMasques) | Where-Object { $_.Cle -eq $statutJeuFiltre } | Select-Object -First 1
            $labelStatutFiltre = if ($defFiltre) { $defFiltre.Label } else { "Non commence" }
            if ($filtreStatut -ne "Tous" -and $filtreStatut -ne $labelStatutFiltre) { continue }

            switch ($filtreNote) {
                "5/5 uniquement" { if ($note -ne 5) { continue } }
                "4/5 et plus"    { if ($note -lt 4) { continue } }
                "3/5 et plus"    { if ($note -lt 3) { continue } }
                "Non note"       { if ($note -ne 0) { continue } }
            }

            $affiches++

            $carte = New-Object System.Windows.Controls.Border
            $carte.Width = 148
            $carte.Margin = '0,0,14,14'
            $carte.CornerRadius = 12
            $carte.Background = ConvertTo-GDBrush $t.CARD
            $carte.BorderThickness = 2
            $carte.BorderBrush = [System.Windows.Media.Brushes]::Transparent
            $carte.Cursor = 'Hand'
            $carte.Tag = $idx
            $carte.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
            $carte.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1, 1)
            $carte.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
                Color = [System.Windows.Media.Color]::FromRgb(0,0,0); BlurRadius = 14; ShadowDepth = 3; Opacity = 0.4
            }

            # Effet de survol "wow" : leger agrandissement + bordure accentuee.
            # On relit $themes/$script:currentTheme (globaux, toujours valides)
            # plutot que $t (variable locale a Refresh-Backlog qui aura deja
            # termine son execution au moment ou la souris survolera la carte -
            # meme categorie de piege que le bug $platName corrige ci-dessus).
            $carte.Add_MouseEnter({
                $this.BorderBrush = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
                $this.RenderTransform.ScaleX = 1.05
                $this.RenderTransform.ScaleY = 1.05
            })
            $carte.Add_MouseLeave({
                $this.BorderBrush = [System.Windows.Media.Brushes]::Transparent
                $this.RenderTransform.ScaleX = 1.0
                $this.RenderTransform.ScaleY = 1.0
            })

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
                    $bmp.DecodePixelWidth = 320
                    $bmp.UriSource = New-Object System.Uri((Resolve-Path $cheminCover).Path, [System.UriKind]::Absolute)
                    $bmp.EndInit()
                    $bmp.Freeze()
                    $img = New-Object System.Windows.Controls.Image
                    $img.Source = $bmp
                    $img.Stretch = 'UniformToFill'
                    $img.HorizontalAlignment = 'Center'
                    $img.VerticalAlignment = 'Center'
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

            # Badge de statut (pastille coloree + texte), au lieu du fin bandeau precedent
            $statutJeuActuel = if ([string]$g.Statut) { [string]$g.Statut } else { "NonCommence" }
            $tousStatutsCarte = Get-TousLesStatuts -InclureMasques
            $infoStatutCarte = $tousStatutsCarte | Where-Object { $_.Cle -eq $statutJeuActuel } | Select-Object -First 1
            if (-not $infoStatutCarte) { $infoStatutCarte = $tousStatutsCarte | Where-Object { $_.Cle -eq "NonCommence" } | Select-Object -First 1 }
            $couleurStatutCarte = $infoStatutCarte.CouleurResolue

            $zoneTexte = New-Object System.Windows.Controls.StackPanel
            $zoneTexte.Margin = '10,8,10,10'

            $badgeCarteStatut = New-Object System.Windows.Controls.Border
            $badgeCarteStatut.Background = ConvertTo-GDGradientBrush $couleurStatutCarte
            $badgeCarteStatut.CornerRadius = 20
            $badgeCarteStatut.Padding = '9,4'
            $badgeCarteStatut.HorizontalAlignment = 'Left'
            $badgeCarteStatut.Margin = '0,0,0,8'
            $badgeCarteStatut.Effect = New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
                Color = [System.Windows.Media.Color]::FromRgb(0,0,0); BlurRadius = 6; ShadowDepth = 1; Opacity = 0.35
            }
            $contenuBadgeCarte = New-Object System.Windows.Controls.StackPanel
            $contenuBadgeCarte.Orientation = 'Horizontal'
            $dotBadgeCarte = New-Object System.Windows.Controls.TextBlock
            $dotBadgeCarte.Text = [string][char]0x25CF
            $dotBadgeCarte.FontSize = 8
            $dotBadgeCarte.Foreground = ConvertTo-GDBrush (Get-GDContrastText $couleurStatutCarte)
            $dotBadgeCarte.Opacity = 0.55
            $dotBadgeCarte.Margin = '0,0,5,0'
            $dotBadgeCarte.VerticalAlignment = 'Center'
            if ($statutJeuActuel -eq "EnCours") {
                $animPouls = New-Object System.Windows.Media.Animation.DoubleAnimation(0.3, 0.9, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(900))))
                $animPouls.AutoReverse = $true
                $animPouls.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                $dotBadgeCarte.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty, $animPouls)
            }
            $contenuBadgeCarte.Children.Add($dotBadgeCarte) | Out-Null
            $tbBadgeCarte = New-Object System.Windows.Controls.TextBlock
            $tbBadgeCarte.Text = $infoStatutCarte.Label
            $tbBadgeCarte.FontSize = 10
            $tbBadgeCarte.FontWeight = 'Bold'
            $tbBadgeCarte.Foreground = ConvertTo-GDBrush (Get-GDContrastText $couleurStatutCarte)
            $contenuBadgeCarte.Children.Add($tbBadgeCarte) | Out-Null
            $badgeCarteStatut.Child = $contenuBadgeCarte
            $zoneTexte.Children.Add($badgeCarteStatut) | Out-Null

            $tbNom = New-Object System.Windows.Controls.TextBlock
            $tbNom.Text = $nomStr
            $tbNom.Foreground = ConvertTo-GDBrush $t.ACCENT
            $tbNom.FontWeight = 'SemiBold'
            $tbNom.FontSize = 12
            $tbNom.TextWrapping = 'Wrap'
            $tbNom.MaxHeight = 34
            $zoneTexte.Children.Add($tbNom) | Out-Null

            $tbEtoiles = New-Object System.Windows.Controls.TextBlock
            $tbEtoiles.Text = ($icones.Filled * $note) + ($icones.Empty * (5 - $note))
            $tbEtoiles.FontFamily = New-Object System.Windows.Media.FontFamily($icones.Police)
            $tbEtoiles.Foreground = if ($note -ge 5) { ConvertTo-GDBrush $script:starGoldColor } else { ConvertTo-GDBrush $t.MUTED }
            $tbEtoiles.FontSize = 12
            $tbEtoiles.Margin = '0,4,0,0'
            $zoneTexte.Children.Add($tbEtoiles) | Out-Null

            if ([string]$g.Tags) {
                $wrapTagsCarte = New-Object System.Windows.Controls.WrapPanel
                $wrapTagsCarte.Margin = '0,6,0,0'
                foreach ($tagBrut in ([string]$g.Tags -split ',')) {
                    $tagPropre = $tagBrut.Trim()
                    if (-not $tagPropre) { continue }
                    $chipTag = New-Object System.Windows.Controls.Border
                    $chipTag.Background = ConvertTo-GDBrush $t.INPUT
                    $chipTag.CornerRadius = 8
                    $chipTag.Padding = '6,2'
                    $chipTag.Margin = '0,0,4,4'
                    $tbTag = New-Object System.Windows.Controls.TextBlock
                    $tbTag.Text = $tagPropre
                    $tbTag.FontSize = 9
                    $tbTag.Foreground = ConvertTo-GDBrush $t.MUTED
                    $chipTag.Child = $tbTag
                    $wrapTagsCarte.Children.Add($chipTag) | Out-Null
                }
                $zoneTexte.Children.Add($wrapTagsCarte) | Out-Null
            }

            $contenu.Children.Add($zoneTexte) | Out-Null
            $carte.Child = $contenu

            $carte.Add_MouseLeftButtonDown({
                $idxCarte = $this.Tag
                Invoke-Safe -Contexte "Ouvrir la fiche depuis le backlog" -Action {
                    $platActuelle = $cb.cmbPlatformBacklog.SelectedItem.Content
                    Open-FicheJeu -PlateformeCible $platActuelle -IndexJeu $idxCarte -OnSaved { Refresh-Backlog }
                }
            })

            $cb.wrapBacklog.Children.Add($carte) | Out-Null
        }

        $cb.lblBacklogCompte.Text = "$affiches jeu(x) affiche(s)"
    }
    Refresh-Backlog

    $cb.cmbPlatformBacklog.Add_SelectionChanged({ Refresh-Backlog })
    $cb.txtRechercheBacklog.Add_TextChanged({ Refresh-Backlog })
    $cb.cmbFiltreNote.Add_SelectionChanged({ Refresh-Backlog })
    $cb.btnFermerBacklog.Add_Click({ $winB.Close() })

    $winB.ShowDialog() | Out-Null
}


function Open-RawgRecherche {
    param(
        [string]$Terme,
        [string]$PlateformeCible,
        [scriptblock]$OnAdded
    )

    $cle = Get-RawgApiKey
    if ([string]::IsNullOrWhiteSpace($cle)) {
        Show-GDMessageBox -Message "Configure d'abord ta cle API RAWG dans Options -> Recherche en ligne (gratuite sur rawg.io/apidocs, ~2 minutes)." -Title "Info" | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($Terme)) {
        Show-GDMessageBox -Message "Tape un nom de jeu dans le champ avant de chercher en ligne." -Title "Info" | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($PlateformeCible)) {
        Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes' pour en creer une." -Title "Info" | Out-Null
        return
    }

    # Recherche synchrone : le reste de l'appli est brievement non-reactif le
    # temps de l'appel reseau (typiquement <2s), acceptable pour une action
    # manuelle et ponctuelle. Une version avec recherche en arriere-plan serait
    # plus polie mais ajoute une complexite de threading qu'on evite ici.
    $resultats = @()
    try {
        $url = "https://api.rawg.io/api/games?search=$([Uri]::EscapeDataString($Terme))&key=$cle&page_size=10"
        $reponse = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 12 -UserAgent "GameDraw/1.0"
        $resultats = @($reponse.results)
    } catch {
        Write-GDLog "ERREUR recherche RAWG : $($_.Exception.Message)"
        Show-GDMessageBox -Message "Impossible de contacter RAWG (verifie ta connexion et ta cle API) :`n$($_.Exception.Message)" -Title "Erreur" | Out-Null
        return
    }

    $xamlRawgString2 = Apply-Theme $xamlRawgString $script:currentTheme
    [xml]$xamlR = $xamlRawgString2
    $readerR = New-Object System.Xml.XmlNodeReader $xamlR
    $winR = [Windows.Markup.XamlReader]::Load($readerR)
    if (-not $winR) {
        Write-GDLog "AVERTISSEMENT : premier chargement de la fenetre 'Recherche en ligne' a retourne null, nouvelle tentative..."
        Start-Sleep -Milliseconds 150
        $readerR = New-Object System.Xml.XmlNodeReader $xamlR
        $winR = [Windows.Markup.XamlReader]::Load($readerR)
        if (-not $winR) { throw "Echec du chargement de la fenetre 'Recherche en ligne' apres 2 tentatives (XamlReader.Load a retourne null)." }
    }
    $winR.Owner = $window
    Enable-GDFadeIn $winR
    $script:cr = @{}
    $xamlR.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cr[$_.Name] = $winR.FindName($_.Name)
    }
    Enable-GDTitleBar $winR $cr

    if ($resultats.Count -eq 0) {
        $cr.lblRawgStatut.Text = "Aucun resultat pour '$Terme'."
    } else {
        $cr.lblRawgStatut.Text = "$($resultats.Count) resultat(s) pour '$Terme' - clique une jaquette pour l'ajouter."
    }

    $t = $themes[$script:currentTheme]
    foreach ($jeu in $resultats) {
        $nomJeu = [string]$jeu.name
        $urlImage = [string]$jeu.background_image

        $carte = New-Object System.Windows.Controls.Border
        $carte.Width = 148
        $carte.Margin = '0,0,14,14'
        $carte.CornerRadius = 10
        $carte.Background = ConvertTo-GDBrush $t.CARD
        $carte.Cursor = 'Hand'
        $carte.Tag = @{ Nom = $nomJeu; UrlImage = $urlImage }

        $contenu = New-Object System.Windows.Controls.StackPanel

        $zoneCover = New-Object System.Windows.Controls.Border
        $zoneCover.Height = 110
        $zoneCover.CornerRadius = New-Object System.Windows.CornerRadius(10,10,0,0)
        $zoneCover.ClipToBounds = $true
        $zoneCover.Background = ConvertTo-GDBrush $t.INPUT
        if ($urlImage) {
            try {
                $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.DecodePixelWidth = 160
                $bmp.UriSource = New-Object System.Uri($urlImage, [System.UriKind]::Absolute)
                $bmp.EndInit()
                $img = New-Object System.Windows.Controls.Image
                $img.Source = $bmp
                $img.Stretch = 'UniformToFill'
                $img.HorizontalAlignment = 'Center'
                $img.VerticalAlignment = 'Center'
                $zoneCover.Child = $img
            } catch { }
        }
        $contenu.Children.Add($zoneCover) | Out-Null

        $tbNom = New-Object System.Windows.Controls.TextBlock
        $tbNom.Text = $nomJeu
        $tbNom.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
        $tbNom.FontWeight = 'SemiBold'
        $tbNom.FontSize = 12
        $tbNom.TextWrapping = 'Wrap'
        $tbNom.Margin = '10,8,10,10'
        $contenu.Children.Add($tbNom) | Out-Null

        $carte.Child = $contenu
        $carte.Add_MouseLeftButtonDown({
            $infos = $this.Tag
            Invoke-Safe -Contexte "Ajouter un jeu depuis RAWG" -Action {
                $file = Get-GameFile $PlateformeCible
                $games = @(Load-Json $file)
                $nomsExistants = @($games | ForEach-Object { ([string]$_.Nom).ToLower() })
                if ($nomsExistants -contains $infos.Nom.ToLower()) {
                    Show-GDMessageBox -Message "'$($infos.Nom)' est deja dans cette bibliotheque." -Title "Info" | Out-Null
                    return
                }
                $nouveauJeu = [pscustomobject]@{ Nom = $infos.Nom; DejaFait = $false; TypeFin = "" }
                $games += $nouveauJeu
                $nouvelIndexRawg = $games.Count - 1
                Save-Json $file $games

                if ($infos.UrlImage) {
                    try {
                        $dir = Get-GameImageFolder -platformName $PlateformeCible -gameName $infos.Nom
                        $dest = Join-Path $dir "Cover.jpg"
                        Invoke-WebRequest -Uri $infos.UrlImage -OutFile $dest -TimeoutSec 15 -UserAgent "GameDraw/1.0"
                        $gamesMaj = @(Load-Json $file)
                        $gMaj = Ensure-GameFields ($gamesMaj | Where-Object { $_.Nom -eq $infos.Nom } | Select-Object -First 1)
                        $gMaj.Cover = $dest
                        Save-Json $file $gamesMaj
                    } catch {
                        Write-GDLog "AVERTISSEMENT : jeu ajoute mais jaquette non telechargee ($($_.Exception.Message))"
                    }
                }

                Write-GDLog "Jeu ajoute depuis RAWG : $($infos.Nom) -> $PlateformeCible"
                $winR.Close()
                if ($OnAdded) { & $OnAdded $nouvelIndexRawg }
                Show-GDMessageBox -Message "'$($infos.Nom)' ajoute avec sa jaquette." -Title "GameDraw" | Out-Null
            }
        })
        $cr.wrapRawgResultats.Children.Add($carte) | Out-Null
    }

    $cr.btnFermerRawg.Add_Click({ $winR.Close() })
    $winR.ShowDialog() | Out-Null
}

function Open-SteamImport {
    param(
        [string]$PlateformeCible,
        [scriptblock]$OnImported
    )

    $apiKeySteam = Get-SteamApiKey
    $idSteam = Get-SteamId64
    if (-not $apiKeySteam -or -not $idSteam) {
        Show-GDMessageBox -Message "Configure d'abord ta cle API et ton SteamID64 dans Options -> Connexion." -Title "Info" | Out-Null
        return
    }

    $xamlSteamString2 = Apply-Theme $xamlSteamString $script:currentTheme
    [xml]$xamlSteam = $xamlSteamString2
    $readerSteam = New-Object System.Xml.XmlNodeReader $xamlSteam
    $winSteam = [Windows.Markup.XamlReader]::Load($readerSteam)
    $winSteam.Owner = $script:window
    Enable-GDFadeIn $winSteam
    $cst = @{}
    $xamlSteam.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object {
        $cst[$_.Name] = $winSteam.FindName($_.Name)
    }
    Enable-GDTitleBar $winSteam $cst

    $script:steamCheckboxes = @()

    function script:Mettre-A-Jour-CompteurSteam {
        $nb = @($script:steamCheckboxes | Where-Object { $_.IsChecked }).Count
        $cst.lblSteamSelection.Text = "$nb jeu(x) selectionne(s)"
    }

    try {
        $urlSteam = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=$apiKeySteam&steamid=$idSteam&format=json&include_appinfo=true&include_played_free_games=true"
        $reponseSteam = Invoke-RestMethod -Uri $urlSteam -UserAgent "GameDraw/1.0" -TimeoutSec 15
        $jeuxSteam = @($reponseSteam.response.games)
        if ($jeuxSteam.Count -eq 0) {
            $cst.lblSteamStatut.Text = "Aucun jeu trouve. Verifie que ton profil Steam est bien public, et que la cle/le SteamID64 sont corrects."
        } else {
            $jeuxSteam = $jeuxSteam | Sort-Object name
            $cst.lblSteamStatut.Text = "$($jeuxSteam.Count) jeu(x) trouve(s) dans ta bibliotheque Steam. Coche ceux a importer."
            foreach ($jeuSteam in $jeuxSteam) {
                $chkJeuSteam = New-Object System.Windows.Controls.CheckBox
                $heuresJoueesSteam = [Math]::Round([double]$jeuSteam.playtime_forever / 60, 1)
                $chkJeuSteam.Content = "$([string]$jeuSteam.name)  -  ${heuresJoueesSteam}h"
                $chkJeuSteam.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].TEXT
                $chkJeuSteam.Margin = '0,0,0,8'
                $chkJeuSteam.Tag = $jeuSteam
                $chkJeuSteam.Add_Click({ Mettre-A-Jour-CompteurSteam })
                $cst.stackSteamJeux.Children.Add($chkJeuSteam) | Out-Null
                $script:steamCheckboxes += $chkJeuSteam
            }
        }
    } catch {
        $cst.lblSteamStatut.Text = "Erreur lors de la recuperation de la bibliotheque Steam."
        Write-GDLog "ERREUR [Import Steam] : $($_.Exception.Message)"
        Show-GDMessageBox -Message "Impossible de recuperer la bibliotheque Steam. Verifie ta cle API, ton SteamID64, et que ton profil est public.`n`nDetail : $($_.Exception.Message)" -Title "Erreur" -Icon "Error" | Out-Null
    }
    Mettre-A-Jour-CompteurSteam

    $cst.btnSteamToutSelectionner.Add_Click({
        foreach ($c in $script:steamCheckboxes) { $c.IsChecked = $true }
        Mettre-A-Jour-CompteurSteam
    })
    $cst.btnSteamToutDeselectionner.Add_Click({
        foreach ($c in $script:steamCheckboxes) { $c.IsChecked = $false }
        Mettre-A-Jour-CompteurSteam
    })

    $cst.btnImporterSteam.Add_Click({
        Invoke-Safe -Contexte "Importer depuis Steam" -Action {
            $selectionSteam = @($script:steamCheckboxes | Where-Object { $_.IsChecked })
            if ($selectionSteam.Count -eq 0) {
                Show-GDMessageBox -Message "Aucun jeu selectionne." -Title "Info" | Out-Null
                return
            }
            $fichierSteam = Get-GameFile $PlateformeCible
            $jeuxSteamActuels = @(Load-Json $fichierSteam)
            $nomsSteamActuels = @($jeuxSteamActuels | ForEach-Object { ([string]$_.Nom).ToLower() })
            $nbAjoutesSteam = 0
            $nbIgnoresSteam = 0
            foreach ($chkSteam in $selectionSteam) {
                $infoJeuSteam = $chkSteam.Tag
                $nomJeuSteam = [string]$infoJeuSteam.name
                if ($nomsSteamActuels -contains $nomJeuSteam.ToLower()) { $nbIgnoresSteam++; continue }
                $nouveauJeuSteam = [pscustomobject]@{ Nom = $nomJeuSteam; DejaFait = $false; TypeFin = "" }
                $jeuxSteamActuels += $nouveauJeuSteam
                $nbAjoutesSteam++
            }
            Save-Json $fichierSteam $jeuxSteamActuels

            # Telechargement des jaquettes (CDN officiel Steam) apres coup,
            # jeu par jeu - un echec de jaquette individuel n'empeche pas
            # l'ajout du jeu lui-meme, meme principe que l'import RAWG.
            foreach ($chkSteam in $selectionSteam) {
                $infoJeuSteam = $chkSteam.Tag
                $nomJeuSteam = [string]$infoJeuSteam.name
                if ($nomsSteamActuels -contains $nomJeuSteam.ToLower()) { continue }
                try {
                    $urlCoverSteam = "https://cdn.cloudflare.steamstatic.com/steam/apps/$($infoJeuSteam.appid)/library_600x900.jpg"
                    $dirSteam = Get-GameImageFolder -platformName $PlateformeCible -gameName $nomJeuSteam
                    $destSteam = Join-Path $dirSteam "Cover.jpg"
                    Invoke-WebRequest -Uri $urlCoverSteam -OutFile $destSteam -TimeoutSec 15 -UserAgent "GameDraw/1.0"
                    $jeuxSteamMaj = @(Load-Json $fichierSteam)
                    $gSteamMaj = Ensure-GameFields ($jeuxSteamMaj | Where-Object { $_.Nom -eq $nomJeuSteam } | Select-Object -First 1)
                    $gSteamMaj.Cover = $destSteam
                    Save-Json $fichierSteam $jeuxSteamMaj
                } catch {
                    Write-GDLog "AVERTISSEMENT : jeu Steam '$nomJeuSteam' ajoute mais jaquette non telechargee ($($_.Exception.Message))"
                }
            }

            Write-GDLog "Import Steam termine : $nbAjoutesSteam ajoute(s), $nbIgnoresSteam deja present(s)"
            if ($OnImported) { & $OnImported }
            Show-GDMessageBox -Message "$nbAjoutesSteam jeu(x) importe(s) depuis Steam.$(if ($nbIgnoresSteam -gt 0) { " ($nbIgnoresSteam deja present(s), ignore(s))" })" -Title "GameDraw" | Out-Null
            $winSteam.Close()
        }
    })
    $cst.btnFermerSteam.Add_Click({ $winSteam.Close() })

    $winSteam.ShowDialog() | Out-Null
}

$controls.btnGererJeux.Add_Click({
    Write-GDLog "DIAGNOSTIC : avant ouverture Gerer les jeux - gdDernierTirage present=$(if ($script:gdDernierTirage) { 'oui' } else { 'non' })"
    Invoke-Safe -Contexte "Gerer les jeux" -Action { Open-GestionJeux }
    Write-GDLog "DIAGNOSTIC : apres fermeture Gerer les jeux - gdDernierTirage present=$(if ($script:gdDernierTirage) { 'oui' } else { 'non' })"
})
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

        # Preserver position/taille/etat de la fenetre : sans ca, chaque
        # changement de theme recentrait la fenetre (WindowStartupLocation=
        # CenterScreen), meme si l'utilisateur l'avait deplacee/redimensionnee -
        # rendait la transition beaucoup plus brutale qu'elle ne doit l'etre.
        $script:gdFenetrePos = @{
            Left = $window.Left; Top = $window.Top
            Width = $window.Width; Height = $window.Height
            State = $window.WindowState
        }

        # Fondu de sortie avant fermeture : la fenetre precedente s'efface au
        # lieu de disparaitre instantanement, et la nouvelle apparait en fondu
        # (Enable-GDFadeIn) - donne une transition continue plutot qu'un
        # ferme/relance brutal.
        $animSortie = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(150))))
        $animSortie.Add_Completed({ $window.Close() }.GetNewClosure())
        $window.BeginAnimation([System.Windows.Window]::OpacityProperty, $animSortie)
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
    $controls.imgCoverResultat.Visibility = 'Hidden'
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

function script:Mettre-A-Jour-CompteARebours {
    try {
        $restant = $script:compteARebours_Fin - (Get-Date)
        if ($restant.TotalSeconds -le 0) {
            $controls.lblCompteARebours.Text = "Temps ecoule !"
            $controls.lblCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].DANGER
            $controls.prgCompteARebours.Value = 100
            if ($script:timerCompteARebours) { $script:timerCompteARebours.Stop() }
            if (-not $script:compteARebours_Notifie) {
                $script:compteARebours_Notifie = $true
                if (Get-NotifierFinSession) {
                    $texteJeuNotif = if ($script:compteARebours_NomJeu) { "Session terminee pour : $($script:compteARebours_NomJeu)" } else { "La session de jeu est terminee." }
                    $toastReussi = $false
                    try {
                        # Vrai toast natif Windows 11 (API WinRT) : bien plus moderne
                        # que la bulle classique NotifyIcon. Necessite l'identifiant
                        # d'application defini au demarrage (SetCurrentProcessExplicit-
                        # AppUserModelID) pour s'afficher correctement.
                        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                        $toastXml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
                        $noeudsTexte = $toastXml.GetElementsByTagName("text")
                        $noeudsTexte.Item(0).AppendChild($toastXml.CreateTextNode("Temps ecoule !")) | Out-Null
                        $noeudsTexte.Item(1).AppendChild($toastXml.CreateTextNode($texteJeuNotif)) | Out-Null
                        $toastNotif = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
                        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("GameDraw.Application").Show($toastNotif)
                        $toastReussi = $true
                    } catch {
                        Write-GDLog "AVERTISSEMENT : toast Windows 11 natif indisponible, repli sur la bulle classique : $($_.Exception.Message)"
                    }
                    if (-not $toastReussi) {
                        try {
                            $script:notifIconSession = New-Object System.Windows.Forms.NotifyIcon
                            $script:notifIconSession.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($script:iconPath)
                            $script:notifIconSession.Visible = $true
                            $script:notifIconSession.BalloonTipTitle = "GameDraw - Temps ecoule !"
                            $script:notifIconSession.BalloonTipText = $texteJeuNotif
                            $script:notifIconSession.ShowBalloonTip(6000)
                            $timerNettoyageNotif = New-Object System.Windows.Threading.DispatcherTimer
                            $timerNettoyageNotif.Interval = [TimeSpan]::FromSeconds(7)
                            $timerNettoyageNotif.Add_Tick({
                                try { $script:notifIconSession.Dispose() } catch { }
                                try { $timerNettoyageNotif.Stop() } catch { }
                            }.GetNewClosure())
                            $timerNettoyageNotif.Start()
                        } catch {
                            Write-GDLog "AVERTISSEMENT : notification systeme de fin de session (bulle classique) egalement echouee : $($_.Exception.Message)"
                        }
                    }
                }
            }
            return
        }
        $jours = [Math]::Floor($restant.TotalDays)
        $texteRestant = if ($jours -ge 1) {
            "{0}j {1:D2}:{2:D2}:{3:D2}" -f [int]$jours, $restant.Hours, $restant.Minutes, $restant.Seconds
        } else {
            "{0:D2}:{1:D2}:{2:D2}" -f $restant.Hours, $restant.Minutes, $restant.Seconds
        }
        $controls.lblCompteARebours.Text = $texteRestant
        $ecoule = $script:compteARebours_DureeTotale - $restant.TotalSeconds
        $pctRestant = 100 - [Math]::Min(100, [Math]::Max(0, ($ecoule / $script:compteARebours_DureeTotale) * 100))
        $controls.prgCompteARebours.Value = [Math]::Min(100, [Math]::Max(0, ($ecoule / $script:compteARebours_DureeTotale) * 100))

        # Couleur progressive selon le temps restant (pas juste vert puis
        # rouge au dernier moment) + pulsation quand c'est vraiment critique -
        # demarree une seule fois en entrant dans la zone critique, pas a
        # chaque tick, pour ne pas re-declencher l'animation inutilement.
        if ($pctRestant -le 10) {
            $controls.lblCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].DANGER
            $controls.prgCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].DANGER
            if (-not $script:compteARebours_PulseDemarre) {
                $script:compteARebours_PulseDemarre = $true
                $animPulseCompte = New-Object System.Windows.Media.Animation.DoubleAnimation(1.0, 0.55, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(650))))
                $animPulseCompte.AutoReverse = $true
                $animPulseCompte.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
                $controls.cardCompteARebours.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $animPulseCompte)
            }
        } elseif ($pctRestant -le 30) {
            $controls.lblCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].WARNING
            $controls.prgCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].WARNING
            if ($script:compteARebours_PulseDemarre) {
                $script:compteARebours_PulseDemarre = $false
                $controls.cardCompteARebours.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
                $controls.cardCompteARebours.Opacity = 1.0
            }
        } else {
            $controls.lblCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
            $controls.prgCompteARebours.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
            if ($script:compteARebours_PulseDemarre) {
                $script:compteARebours_PulseDemarre = $false
                $controls.cardCompteARebours.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
                $controls.cardCompteARebours.Opacity = 1.0
            }
        }
    } catch { }
}

function script:Sauvegarder-DernierTirage($nom, $objectifTexte, $cover, $icone) {
    $etat = [pscustomobject]@{
        Nom = $nom
        ObjectifTexte = $objectifTexte
        Cover = $cover
        Icone = $icone
        FinTexte = ""
        CompteARebours = $null
    }
    $script:gdDernierTirage = $etat
    Sauvegarder-SessionTirage $etat
    Write-GDLog "DIAGNOSTIC : session sauvegardee sur disque -> Nom='$nom' Cover='$cover'"
}
function script:Sauvegarder-FinTirage([string]$texte) {
    if ($script:gdDernierTirage) {
        $script:gdDernierTirage.FinTexte = $texte
        Sauvegarder-SessionTirage $script:gdDernierTirage
    }
}

function script:Get-DernierTirage {
    if ($script:gdDernierTirage) { return $script:gdDernierTirage }
    return Charger-SessionTirage
}

function script:Demarrer-CompteARebours($debut, $fin, $nomJeuSession) {
    if ($script:timerCompteARebours) { try { $script:timerCompteARebours.Stop() } catch { } }
    $controls.cardCompteARebours.Visibility = 'Visible'
    $script:compteARebours_Fin = $fin
    $script:compteARebours_Notifie = $false
    $script:compteARebours_PulseDemarre = $false
    $script:compteARebours_NomJeu = $nomJeuSession
    $script:compteARebours_DureeTotale = ($fin - $debut).TotalSeconds
    if ($script:compteARebours_DureeTotale -le 0) { $script:compteARebours_DureeTotale = 1 }

    if ($script:gdDernierTirage) {
        $script:gdDernierTirage.CompteARebours = [pscustomobject]@{
            Fin = $fin.ToString("o"); DureeTotale = $script:compteARebours_DureeTotale; NomJeu = $nomJeuSession
        }
        Sauvegarder-SessionTirage $script:gdDernierTirage
    }

    Mettre-A-Jour-CompteARebours

    $script:timerCompteARebours = New-Object System.Windows.Threading.DispatcherTimer
    $script:timerCompteARebours.Interval = [TimeSpan]::FromSeconds(1)
    $script:timerCompteARebours.Add_Tick({
        try { Mettre-A-Jour-CompteARebours } catch { try { $script:timerCompteARebours.Stop() } catch { } }
    })
    $script:timerCompteARebours.Start()
}

# Reprend un compte a rebours deja en cours (retrouve sur disque, que ce soit
# apres un changement de theme ou une relance complete de l'application) a
# partir de sa date de fin et de sa duree totale d'origine, deja connues.
function script:Reprendre-CompteARebours($finPersistee, $dureeTotalePersistee, $nomJeuPersiste) {
    if ($script:timerCompteARebours) { try { $script:timerCompteARebours.Stop() } catch { } }
    $controls.cardCompteARebours.Visibility = 'Visible'
    $script:compteARebours_Fin = $finPersistee
    $script:compteARebours_Notifie = $false
    $script:compteARebours_PulseDemarre = $false
    $script:compteARebours_NomJeu = $nomJeuPersiste
    $script:compteARebours_DureeTotale = $dureeTotalePersistee
    if ($script:compteARebours_DureeTotale -le 0) { $script:compteARebours_DureeTotale = 1 }

    Mettre-A-Jour-CompteARebours

    $script:timerCompteARebours = New-Object System.Windows.Threading.DispatcherTimer
    $script:timerCompteARebours.Interval = [TimeSpan]::FromSeconds(1)
    $script:timerCompteARebours.Add_Tick({
        try { Mettre-A-Jour-CompteARebours } catch { try { $script:timerCompteARebours.Stop() } catch { } }
    })
    $script:timerCompteARebours.Start()
}

function script:Arreter-CompteARebours {
    if ($script:timerCompteARebours) { try { $script:timerCompteARebours.Stop() } catch { } }
    $controls.cardCompteARebours.Visibility = 'Collapsed'
    if ($script:gdDernierTirage) {
        $script:gdDernierTirage.CompteARebours = $null
        Sauvegarder-SessionTirage $script:gdDernierTirage
    }
}

function script:Build-RouletteWheel {
    $canvas = $controls.rouletteWheelCanvas
    if ($canvas.Children.Count -gt 0) { return }  # deja construite, pas besoin de refaire les tranches a chaque tirage
    $rayon = 108
    $centre = 110
    $couleurs = @("#3B82F6", "#22D3EE", "#2DD4BF", "#34D399", "#FBBF24", "#FB923C", "#F87171", "#EC4899", "#A78BFA", "#8B5CF6")
    $nbTranches = $couleurs.Count
    $angleTranche = 360.0 / $nbTranches
    for ($i = 0; $i -lt $nbTranches; $i++) {
        $angleDebut = $i * $angleTranche
        $angleFin = ($i + 1) * $angleTranche
        $radDebut = $angleDebut * [Math]::PI / 180
        $radFin = $angleFin * [Math]::PI / 180
        $x1 = [Math]::Round($centre + $rayon * [Math]::Sin($radDebut), 2)
        $y1 = [Math]::Round($centre - $rayon * [Math]::Cos($radDebut), 2)
        $x2 = [Math]::Round($centre + $rayon * [Math]::Sin($radFin), 2)
        $y2 = [Math]::Round($centre - $rayon * [Math]::Cos($radFin), 2)
        $data = "M $centre,$centre L $x1,$y1 A $rayon,$rayon 0 0,1 $x2,$y2 Z"
        $tranche = New-Object System.Windows.Shapes.Path
        $tranche.Data = [System.Windows.Media.Geometry]::Parse($data)
        $tranche.Fill = ConvertTo-GDBrush $couleurs[$i]
        $tranche.Stroke = ConvertTo-GDBrush "#1A1A1A"
        $tranche.StrokeThickness = 1.5
        $canvas.Children.Add($tranche) | Out-Null
    }
}

function script:Play-Confetti {
    $canvas = $controls.canvasConfetti
    $canvas.Children.Clear()
    $t = $themes[$script:currentTheme]
    $couleurs = @($t.ACCENT, $t.SUCCESS, $t.WARNING, $t.DANGER)
    # Garde explicite contre NaN : si le canvas n'a encore jamais ete mesure
    # (par ex. tout premier tirage juste apres l'ouverture de la fenetre),
    # ActualWidth peut valoir NaN - et Math.Max(240, NaN) retourne NaN en .NET
    # (cas particulier documente), ce qui ferait ensuite planter la conversion
    # en entier plus bas.
    $largeurBrute = $canvas.ActualWidth
    if (-not $largeurBrute -or [double]::IsNaN($largeurBrute) -or $largeurBrute -lt 240) {
        $largeur = 240
    } else {
        $largeur = $largeurBrute
    }

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
    if ((Get-AvertirNouveauTirage) -and $controls.cardCompteARebours.Visibility -eq 'Visible' -and $controls.lblCompteARebours.Text -ne "Temps ecoule !") {
        $confirmNouveauTirage = Show-GDMessageBox -Message "Une session de jeu est encore en cours (le compte a rebours n'est pas termine). Lancer quand meme un nouveau tirage ?" -Title "Session en cours" -Buttons "YesNo" -Icon "Warning"
        if ($confirmNouveauTirage -ne 'Yes') { return }
    }
    if (-not $controls.cmbPlatform.SelectedItem) {
        Show-GDMessageBox -Message "Aucune plateforme active. Utilisez 'Gerer les plateformes'." -Title "Info" | Out-Null
        return
    }
    $platName = $controls.cmbPlatform.SelectedItem.Content
    $file = Get-GameFile $platName
    $games = @(Load-Json $file)
    if ($games.Count -eq 0) {
        Show-GDMessageBox -Message "La bibliotheque est vide. Utilisez 'Gerer les jeux' pour en ajouter." -Title "Info" | Out-Null
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
    $controls.imgCoverResultat.Visibility = 'Hidden'
    $controls.canvasConfetti.Children.Clear()
    $controls.rouletteWheelContainer.Visibility = 'Collapsed'
    $controls.reelViewport.Visibility = 'Collapsed'
    $controls.slotMachineContainer.Visibility = 'Collapsed'
    $controls.lblJeuTire.Visibility = 'Visible'
    Arreter-CompteARebours

    $finaliser = {
        $tire.DejaFait = $true
        Save-Json $file $games

        $controls.lblJeuTire.Text = $tire.Nom
        $controls.lblObjectif.Text = "Objectif : $objectif"
        Show-CoverJeu $tire
        Play-PopAnimation
        Play-Confetti

        # Sauvegarde en portee script : necessaire pour pouvoir restaurer cet
        # affichage si la fenetre est recreee (changement de theme) pendant
        # qu'un resultat est encore affiche - sans ca, le resultat "sautait"
        # (retour a "Aucun tirage") a chaque changement de theme.
        # IMPORTANT : passe par une fonction nommee plutot qu'une affectation
        # directe ici - $finaliser est un GetNewClosure(), qui opere sur une
        # copie privee de la portee. Une affectation $script: ecrite
        # directement dans la fermeture ne modifie que cette copie privee, pas
        # la vraie portee du script (c'est ce qui empechait la restauration de
        # fonctionner, alors que Demarrer-CompteARebours, appelee de la meme
        # maniere mais elle-meme une fonction nommee, fonctionnait). Un appel
        # de fonction nommee "s'echappe" correctement vers la vraie portee.
        Sauvegarder-DernierTirage $tire.Nom "Objectif : $objectif" ([string]$tire.Cover) ([string]$tire.Icone)

        $dureeTxt = ""
        $dateFinTxt = ""
        if ($limiterTemps) {
            [int]$duree = 1
            [void][int]::TryParse($controls.txtDuree.Text, [ref]$duree)
            if ($duree -le 0) { $duree = 1 }
            $unite = $controls.cmbUnite.SelectedItem.Content
            $dateFin = switch ($unite) {
                "Minutes"  { $dateDebut.AddMinutes($duree) }
                "Heures"   { $dateDebut.AddHours($duree) }
                "Jours"    { $dateDebut.AddDays($duree) }
                "Semaines" { $dateDebut.AddDays($duree * 7) }
            }
            $controls.lblFin.Text = "Fin prevue le $($dateFin.ToString('dd/MM/yyyy HH:mm'))"
            $dureeTxt = "$duree $unite"
            $dateFinTxt = $dateFin.ToString("dd/MM/yyyy HH:mm")
            Sauvegarder-FinTirage $controls.lblFin.Text
            Demarrer-CompteARebours $dateDebut $dateFin $tire.Nom
        } else {
            $controls.lblFin.Text = "Aucune limite de temps (jouer jusqu'a atteindre l'objectif)"
            Sauvegarder-FinTirage $controls.lblFin.Text
            Arreter-CompteARebours
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

    if ((Get-AnimationTirage) -and (Get-StyleAnimationTirage) -eq "Roue") {
        # Vraie roue de roulette (tranches colorees qui tournent + pointeur
        # fixe), fidele aux visuels de reference demandes. La roue est
        # purement decorative (ses tranches ne representent pas les jeux
        # individuellement, comme une roulette de casino classique) ; le vrai
        # resultat est revele juste apres, une fois la roue arretee.
        Build-RouletteWheel
        $controls.rouletteRotate.Angle = 0
        $controls.rouletteWheelContainer.Visibility = 'Visible'
        $controls.lblJeuTire.Visibility = 'Collapsed'

        $toursComplets = Get-Random -Minimum 4 -Maximum 7
        $angleFinal = $toursComplets * 360 + (Get-Random -Minimum 0 -Maximum 360)
        $easeRoue = New-Object System.Windows.Media.Animation.PowerEase
        $easeRoue.Power = 4
        $easeRoue.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $animRoue = New-Object System.Windows.Media.Animation.DoubleAnimation(0, $angleFinal, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(2200))))
        $animRoue.EasingFunction = $easeRoue
        $animRoue.Add_Completed({
            try {
                $controls.rouletteWheelContainer.Visibility = 'Collapsed'
                $controls.lblJeuTire.Visibility = 'Visible'
                & $finaliser
            } catch {
                try { $controls.rouletteWheelContainer.Visibility = 'Collapsed' } catch { }
                try { $controls.lblJeuTire.Visibility = 'Visible' } catch { }
                try { $controls.btnTirer.IsEnabled = $true } catch { }
                try {
                    $detail = $_.Exception.Message
                    if ($_.Exception.InnerException) { $detail += " | Cause interne : $($_.Exception.InnerException.Message)" }
                    Write-GDLog "ERREUR [Fin de la roulette] ($($_.Exception.GetType().FullName)) : $detail`n$($_.ScriptStackTrace)"
                } catch { }
                try {
                    Show-GDMessageBox -Message "Une erreur est survenue a la fin du tirage. Details enregistres dans :`n$script:logFile" -Title "GameDraw - Erreur" -Icon "Error" | Out-Null
                } catch { }
            }
        }.GetNewClosure())
        $controls.rouletteRotate.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animRoue)
    } elseif ((Get-AnimationTirage) -and (Get-StyleAnimationTirage) -eq "Bandeau") {
        # Style "Bandeau" : une bande de noms (aleatoires, le dernier etant le
        # vrai resultat) defile verticalement dans un viewport qui la
        # decoupe, avec une deceleration naturelle - alternative plus sobre
        # a la roue, au choix dans Options.
        $nbItemsReel = 20
        $itemHeight = 50
        $itemsReel = @()
        for ($i = 0; $i -lt ($nbItemsReel - 1); $i++) { $itemsReel += ($nomsAnim | Get-Random) }
        $itemsReel += $tire.Nom

        $controls.reelStrip.Children.Clear()
        foreach ($nomItem in $itemsReel) {
            $tbReel = New-Object System.Windows.Controls.TextBlock
            $tbReel.Text = $nomItem
            $tbReel.FontSize = 22
            $tbReel.FontWeight = 'Bold'
            $tbReel.Foreground = ConvertTo-GDBrush $themes[$script:currentTheme].ACCENT
            $tbReel.HorizontalAlignment = 'Center'
            $tbReel.TextAlignment = 'Center'
            $tbReel.Height = $itemHeight
            $tbReel.MaxWidth = 320
            $tbReel.TextTrimming = 'CharacterEllipsis'
            $controls.reelStrip.Children.Add($tbReel) | Out-Null
        }
        $transformReel = New-Object System.Windows.Media.TranslateTransform(0, 0)
        $controls.reelStrip.RenderTransform = $transformReel
        $controls.reelViewport.Visibility = 'Visible'
        $controls.lblJeuTire.Visibility = 'Collapsed'

        $distanceFinaleReel = -1.0 * $itemHeight * ($itemsReel.Count - 1)
        $easeReel = New-Object System.Windows.Media.Animation.PowerEase
        $easeReel.Power = 4
        $easeReel.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
        $animReel = New-Object System.Windows.Media.Animation.DoubleAnimation(0, $distanceFinaleReel, (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(1900))))
        $animReel.EasingFunction = $easeReel
        $animReel.Add_Completed({
            try {
                $controls.reelViewport.Visibility = 'Collapsed'
                $controls.lblJeuTire.Visibility = 'Visible'
                & $finaliser
            } catch {
                try { $controls.reelViewport.Visibility = 'Collapsed' } catch { }
                try { $controls.lblJeuTire.Visibility = 'Visible' } catch { }
                try { $controls.btnTirer.IsEnabled = $true } catch { }
                try {
                    $detail = $_.Exception.Message
                    if ($_.Exception.InnerException) { $detail += " | Cause interne : $($_.Exception.InnerException.Message)" }
                    Write-GDLog "ERREUR [Fin du bandeau] ($($_.Exception.GetType().FullName)) : $detail`n$($_.ScriptStackTrace)"
                } catch { }
                try {
                    Show-GDMessageBox -Message "Une erreur est survenue a la fin du tirage. Details enregistres dans :`n$script:logFile" -Title "GameDraw - Erreur" -Icon "Error" | Out-Null
                } catch { }
            }
        }.GetNewClosure())
        $transformReel.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $animReel)
    } elseif ((Get-AnimationTirage) -and (Get-StyleAnimationTirage) -eq "Machine") {
        # Style "Machine a sous" : trois des (caracteres Unicode standards,
        # pas des glyphes de police specifiques) qui defilent rapidement et
        # s'arretent l'un apres l'autre (gauche, puis milieu, puis droite),
        # comme une vraie machine a sous - purement decoratif, comme les
        # autres styles, le vrai resultat est revele juste apres.
        $facesDes = @([char]0x2680, [char]0x2681, [char]0x2682, [char]0x2683, [char]0x2684, [char]0x2685)
        $controls.slotMachineContainer.Visibility = 'Visible'
        $controls.lblJeuTire.Visibility = 'Collapsed'

        $etatMachine = [pscustomobject]@{ Ticks = 0; Arret1 = 10; Arret2 = 15; Arret3 = 20 }
        $timerMachine = New-Object System.Windows.Threading.DispatcherTimer
        $timerMachine.Interval = [TimeSpan]::FromMilliseconds(90)
        $timerMachine.Add_Tick({
            try {
                $etatMachine.Ticks++
                if ($etatMachine.Ticks -le $etatMachine.Arret1) { $controls.tbSlot1.Text = ($facesDes | Get-Random) }
                if ($etatMachine.Ticks -le $etatMachine.Arret2) { $controls.tbSlot2.Text = ($facesDes | Get-Random) }
                if ($etatMachine.Ticks -le $etatMachine.Arret3) { $controls.tbSlot3.Text = ($facesDes | Get-Random) }
                if ($etatMachine.Ticks -ge $etatMachine.Arret3) {
                    $timerMachine.Stop()
                    $controls.slotMachineContainer.Visibility = 'Collapsed'
                    $controls.lblJeuTire.Visibility = 'Visible'
                    & $finaliser
                }
            } catch {
                try { $timerMachine.Stop() } catch { }
                try { $controls.slotMachineContainer.Visibility = 'Collapsed' } catch { }
                try { $controls.lblJeuTire.Visibility = 'Visible' } catch { }
                try { $controls.btnTirer.IsEnabled = $true } catch { }
                try {
                    $detail = $_.Exception.Message
                    if ($_.Exception.InnerException) { $detail += " | Cause interne : $($_.Exception.InnerException.Message)" }
                    Write-GDLog "ERREUR [Fin de la machine a sous] ($($_.Exception.GetType().FullName)) : $detail`n$($_.ScriptStackTrace)"
                } catch { }
                try {
                    Show-GDMessageBox -Message "Une erreur est survenue a la fin du tirage. Details enregistres dans :`n$script:logFile" -Title "GameDraw - Erreur" -Icon "Error" | Out-Null
                } catch { }
            }
        }.GetNewClosure())
        $timerMachine.Start()
    } else {
        & $finaliser
    }
  }
})

$controls.btnTerminer.Add_Click({
    $controls.lblJeuTire.Text = "Aucun tirage"
    $controls.lblObjectif.Text = ""
    $controls.lblFin.Text = ""
    $script:gdDernierTirage = $null
    Arreter-CompteARebours
    Effacer-SessionTirage
})

# Restaurer l'affichage du dernier tirage et/ou du compte a rebours en cours,
# si la fenetre vient d'etre recreee suite a un changement de theme (les
# donnees survivent en portee script, mais l'affichage lui est reconstruit a
# neuf a chaque fois - sans cette restauration, tirage et decompte
# "sautaient" (revenaient a l'etat initial) a chaque changement de theme).
# Utilise un minuteur a declenchement unique (300ms) plutot que l'evenement
# Loaded : mecanisme plus simple et plus previsible a garantir, elimine toute
# ambiguite sur le moment exact ou l'evenement se declenche reellement.
Write-GDLog "DIAGNOSTIC : minuteur de restauration cree et demarre - gdDernierTirage present=$(if ($script:gdDernierTirage) { 'oui' } else { 'non' })"
$timerRestauration = New-Object System.Windows.Threading.DispatcherTimer
$timerRestauration.Interval = [TimeSpan]::FromMilliseconds(300)
$timerRestauration.Add_Tick({
    try {
        $timerRestauration.Stop()
        $dernierTirageLu = Get-DernierTirage
        Write-GDLog "DIAGNOSTIC : tick du minuteur de restauration declenche - session presente=$(if ($dernierTirageLu) { 'oui' } else { 'non' })"
        if ($dernierTirageLu) {
            Write-GDLog "DIAGNOSTIC : restauration -> Nom='$($dernierTirageLu.Nom)' Cover='$($dernierTirageLu.Cover)' Icone='$($dernierTirageLu.Icone)'"
            $controls.lblJeuTire.Text = $dernierTirageLu.Nom
            $controls.lblObjectif.Text = $dernierTirageLu.ObjectifTexte
            if ($dernierTirageLu.FinTexte) { $controls.lblFin.Text = $dernierTirageLu.FinTexte }
            $jeuRestaure = [pscustomobject]@{ Cover = $dernierTirageLu.Cover; Icone = $dernierTirageLu.Icone }
            Show-CoverJeu $jeuRestaure
            Write-GDLog "DIAGNOSTIC : apres restauration -> lblJeuTire.Text='$($controls.lblJeuTire.Text)' imgCoverResultat.Visibility='$($controls.imgCoverResultat.Visibility)'"

            if ($dernierTirageLu.CompteARebours) {
                $finPersistee = [DateTime]::Parse($dernierTirageLu.CompteARebours.Fin, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)
                if ($finPersistee -gt (Get-Date)) {
                    Write-GDLog "DIAGNOSTIC : reprise du compte a rebours -> fin='$finPersistee'"
                    Reprendre-CompteARebours $finPersistee ([double]$dernierTirageLu.CompteARebours.DureeTotale) ([string]$dernierTirageLu.CompteARebours.NomJeu)
                } else {
                    Write-GDLog "DIAGNOSTIC : compte a rebours persiste deja expire, non repris"
                }
            }
        }
    } catch {
        Write-GDLog "ERREUR [Restauration au chargement] : $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    }
}.GetNewClosure())
$timerRestauration.Start()

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
