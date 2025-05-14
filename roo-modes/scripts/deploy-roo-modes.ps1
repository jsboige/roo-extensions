# Script de déploiement des modes personnalisés pour Roo
# Ce script permet de déployer des configurations de modes personnalisés
# dans l'environnement Roo local ou distant

param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\roo-modes\configs\custom-modes.json",
    
    [Parameter(Mandatory = $false)]
    [string]$TargetPath = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Backup = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$Merge = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force = $false
)

# Fonction pour afficher les messages d'information
function Write-InfoMessage {
    param (
        [string]$Message,
        [string]$Type = "Info" # Info, Warning, Error, Success
    )
    
    $color = switch ($Type) {
        "Info" { "Cyan" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Success" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

# Fonction pour vérifier si le fichier de configuration existe
function Test-ConfigFile {
    param (
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        Write-InfoMessage "Le fichier de configuration '$Path' n'existe pas." -Type "Error"
        return $false
    }
    
    # Vérifier que le fichier est un JSON valide
    try {
        $null = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $true
    }
    catch {
        Write-InfoMessage "Le fichier '$Path' n'est pas un JSON valide: $_" -Type "Error"
        return $false
    }
}

# Fonction pour déterminer le chemin cible
function Get-TargetPath {
    if ($TargetPath -ne "") {
        return $TargetPath
    }
    
    # Déterminer le chemin par défaut selon l'OS
    $defaultPath = if ($IsWindows -or $env:OS -match "Windows") {
        Join-Path -Path $env:APPDATA -ChildPath "Code\User\settings.json"
    }
    elseif ($IsMacOS) {
        Join-Path -Path $HOME -ChildPath "Library/Application Support/Code/User/settings.json"
    }
    elseif ($IsLinux) {
        Join-Path -Path $HOME -ChildPath ".config/Code/User/settings.json"
    }
    else {
        Write-InfoMessage "Système d'exploitation non reconnu." -Type "Error"
        exit 1
    }
    
    # Vérifier si le fichier settings.json existe
    if (-not (Test-Path -Path $defaultPath)) {
        Write-InfoMessage "Le fichier settings.json de VS Code n'a pas été trouvé à l'emplacement par défaut: $defaultPath" -Type "Warning"
        Write-InfoMessage "Veuillez spécifier le chemin avec le paramètre -TargetPath" -Type "Warning"
        exit 1
    }
    
    return $defaultPath
}

# Fonction pour créer une sauvegarde du fichier cible
function Backup-TargetFile {
    param (
        [string]$Path
    )
    
    if (-not $Backup) {
        return
    }
    
    $backupPath = "$Path.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try {
        Copy-Item -Path $Path -Destination $backupPath -Force
        Write-InfoMessage "Sauvegarde créée: $backupPath" -Type "Success"
    }
    catch {
        Write-InfoMessage "Impossible de créer une sauvegarde: $_" -Type "Error"
        if (-not $Force) {
            exit 1
        }
    }
}

# Fonction pour fusionner ou remplacer les modes dans le fichier cible
function Update-ModesConfiguration {
    param (
        [string]$ConfigPath,
        [string]$TargetPath
    )
    
    # Charger les configurations
    $customModes = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    
    try {
        $targetConfig = Get-Content -Path $TargetPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-InfoMessage "Impossible de lire le fichier cible: $_" -Type "Error"
        exit 1
    }
    
    # Vérifier si la propriété roo.modes existe
    if (-not (Get-Member -InputObject $targetConfig -Name "roo" -MemberType Properties)) {
        $targetConfig | Add-Member -NotePropertyName "roo" -NotePropertyValue @{}
    }
    
    if (-not (Get-Member -InputObject $targetConfig.roo -Name "modes" -MemberType Properties)) {
        $targetConfig.roo | Add-Member -NotePropertyName "modes" -NotePropertyValue @()
    }
    
    # Fusionner ou remplacer les modes
    if ($Merge) {
        # Mode fusion: ajouter ou mettre à jour les modes existants
        foreach ($mode in $customModes.modes) {
            $existingMode = $targetConfig.roo.modes | Where-Object { $_.slug -eq $mode.slug }
            
            if ($null -ne $existingMode) {
                # Mettre à jour le mode existant
                $index = [array]::IndexOf($targetConfig.roo.modes, $existingMode)
                $targetConfig.roo.modes[$index] = $mode
                Write-InfoMessage "Mode '$($mode.slug)' mis à jour." -Type "Info"
            }
            else {
                # Ajouter le nouveau mode
                $targetConfig.roo.modes += $mode
                Write-InfoMessage "Mode '$($mode.slug)' ajouté." -Type "Info"
            }
        }
    }
    else {
        # Mode remplacement: remplacer tous les modes
        $targetConfig.roo.modes = $customModes.modes
        Write-InfoMessage "Tous les modes ont été remplacés." -Type "Info"
    }
    
    # Enregistrer les modifications
    try {
        $targetConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $TargetPath
        Write-InfoMessage "Configuration mise à jour avec succès." -Type "Success"
    }
    catch {
        Write-InfoMessage "Erreur lors de l'enregistrement de la configuration: $_" -Type "Error"
        exit 1
    }
}

# Programme principal
Write-InfoMessage "Démarrage du déploiement des modes personnalisés..." -Type "Info"

# Vérifier le fichier de configuration
if (-not (Test-ConfigFile -Path $ConfigPath)) {
    exit 1
}

# Déterminer le chemin cible
$resolvedTargetPath = Get-TargetPath
Write-InfoMessage "Chemin cible: $resolvedTargetPath" -Type "Info"

# Créer une sauvegarde
Backup-TargetFile -Path $resolvedTargetPath

# Mettre à jour la configuration
Update-ModesConfiguration -ConfigPath $ConfigPath -TargetPath $resolvedTargetPath

Write-InfoMessage "Déploiement terminé avec succès!" -Type "Success"