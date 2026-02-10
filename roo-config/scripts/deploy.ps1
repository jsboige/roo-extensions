# Script de déploiement des modes personnalisés Roo
# Ce script copie le fichier .roomodes vers le fichier global custom_modes.json
# et vérifie que l'installation est correcte.

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White"
    )
    
    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# Fonction pour vérifier si un chemin existe et le créer si nécessaire
function Ensure-PathExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Répertoire créé: $Path" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $Path" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier .roomodes existe
$sourceFile = Join-Path -Path $PSScriptRoot -ChildPath "..\..\.roomodes"
if (-not (Test-Path $sourceFile)) {
    Write-ColorOutput "Erreur: Le fichier .roomodes n'a pas été trouvé." "Red"
    Write-ColorOutput "Chemin recherché: $sourceFile" "Red"
    Write-ColorOutput "PSScriptRoot: $PSScriptRoot" "Red"
    exit 1
}
$sourceFile = Resolve-Path $sourceFile

Write-ColorOutput "`n[1/4] Fichier source trouvé: $sourceFile" "Green"

# Déterminer le chemin du fichier de destination
$destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"

# Vérifier que le répertoire de destination existe
Ensure-PathExists -Path $destinationDir

Write-ColorOutput "`n[2/4] Copie du fichier .roomodes vers $destinationFile" "Yellow"

# Copier le fichier
try {
    Copy-Item -Path $sourceFile -Destination $destinationFile -Force
    Write-ColorOutput "Copie réussie!" "Green"
}
catch {
    Write-ColorOutput "Erreur lors de la copie du fichier:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que les fichiers sont identiques
Write-ColorOutput "`n[3/4] Vérification de l'installation..." "Yellow"

try {
    $diff = Compare-Object -ReferenceObject (Get-Content $sourceFile) -DifferenceObject (Get-Content $destinationFile)
    
    if ($null -eq $diff) {
        Write-ColorOutput "Vérification réussie: Les fichiers sont identiques." "Green"
    }
    else {
        Write-ColorOutput "Avertissement: Les fichiers ne sont pas identiques." "Yellow"
        Write-ColorOutput "Différences trouvées:" "Yellow"
        $diff | Format-Table -AutoSize
        exit 1
    }
}
catch {
    Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Vérifier que le fichier JSON est valide
Write-ColorOutput "`n[4/4] Validation du format JSON..." "Yellow"

try {
    $json = Get-Content $destinationFile -Raw | ConvertFrom-Json
    $modesCount = $json.customModes.Count
    
    Write-ColorOutput "Validation réussie: Le fichier JSON est valide." "Green"
    Write-ColorOutput "Nombre de modes personnalisés trouvés: $modesCount" "Green"
    
    # Afficher les modes trouvés
    Write-ColorOutput "`nModes personnalisés installés:" "Cyan"
    foreach ($mode in $json.customModes) {
        Write-ColorOutput "- $($mode.name) ($($mode.slug))" "White"
    }
}
catch {
    Write-ColorOutput "Erreur: Le fichier JSON n'est pas valide." "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Installation terminée avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"
Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`nPour plus d'informations, consultez:" "White"
Write-ColorOutput "roo-modes/custom/docs/implementation/deploiement.md" "White"
Write-ColorOutput "`n" "White"