# Script de déploiement amélioré des modes personnalisés Roo
# Ce script permet de déployer une configuration de modes soit globalement, soit localement, soit les deux
# Il adapte également les chemins d'accès absolus et vérifie les permissions

param (
    [Parameter(Mandatory = $false)]
    [string]$SourceFile = ".roomodes",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local", "both")]
    [string]$DeploymentType = "both",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$AdaptPaths,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestAfterDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

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
            return $true
        }
        catch {
            Write-ColorOutput "Erreur lors de la création du répertoire: $Path" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            return $false
        }
    }
    return $true
}

# Fonction pour adapter les chemins d'accès absolus dans un fichier JSON
function Adapt-Paths {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonContent
    )
    
    try {
        # Convertir le contenu JSON en objet PowerShell
        $jsonObject = $JsonContent | ConvertFrom-Json
        
        # Parcourir tous les modes personnalisés
        foreach ($mode in $jsonObject.customModes) {
            # Adapter les chemins dans les instructions personnalisées
            if ($mode.customInstructions) {
                # Remplacer les chemins absolus par des chemins relatifs ou des variables d'environnement
                $mode.customInstructions = $mode.customInstructions -replace 'C:\\Users\\[^\\]+', '$env:USERPROFILE'
                $mode.customInstructions = $mode.customInstructions -replace 'D:\\', '.\'
            }
        }
        
        # Convertir l'objet PowerShell en JSON
        $adaptedJson = $jsonObject | ConvertTo-Json -Depth 10
        
        return $adaptedJson
    }
    catch {
        Write-ColorOutput "Erreur lors de l'adaptation des chemins d'accès:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        return $JsonContent
    }
}

# Fonction pour valider un fichier JSON
function Test-Json {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonContent
    )
    
    try {
        $null = $JsonContent | ConvertFrom-Json
        return $true
    }
    catch {
        Write-ColorOutput "Erreur: Le fichier JSON n'est pas valide." "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        return $false
    }
}

# Bannière
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement amélioré des modes personnalisés Roo" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Vérifier que le fichier source existe
if (-not (Test-Path -Path $SourceFile)) {
    Write-ColorOutput "Erreur: Le fichier source '$SourceFile' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le répertoire courant." "Red"
    exit 1
}

# Lire le contenu du fichier source
$sourceContent = Get-Content -Path $SourceFile -Raw

# Valider le JSON du fichier source
if (-not (Test-Json -JsonContent $sourceContent)) {
    Write-ColorOutput "Le fichier source contient du JSON invalide. Veuillez corriger les erreurs avant de continuer." "Red"
    exit 1
}

# Adapter les chemins d'accès si demandé
if ($AdaptPaths) {
    Write-ColorOutput "`nAdaptation des chemins d'accès absolus..." "Yellow"
    $sourceContent = Adapt-Paths -JsonContent $sourceContent
    
    # Valider le JSON après adaptation
    if (-not (Test-Json -JsonContent $sourceContent)) {
        Write-ColorOutput "L'adaptation des chemins a généré du JSON invalide. Veuillez vérifier manuellement." "Red"
        exit 1
    }
    
    Write-ColorOutput "Adaptation des chemins terminée." "Green"
}

# Déploiement global
if ($DeploymentType -eq "global" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nDéploiement global en cours..." "Yellow"
    
    # Déterminer le chemin du fichier de destination global
    $globalDestDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $globalDestFile = Join-Path -Path $globalDestDir -ChildPath "custom_modes.json"
    
    # Vérifier que le répertoire de destination existe
    if (-not (Ensure-PathExists -Path $globalDestDir)) {
        Write-ColorOutput "Impossible de créer le répertoire de destination global." "Red"
        exit 1
    }
    
    # Vérifier si le fichier de destination existe déjà
    if (Test-Path -Path $globalDestFile) {
        if (-not $Force) {
            $confirmation = Read-Host "Le fichier de destination global existe déjà. Voulez-vous le remplacer? (O/N)"
            if ($confirmation -ne "O" -and $confirmation -ne "o") {
                Write-ColorOutput "Déploiement global annulé." "Yellow"
            }
            else {
                # Copier le contenu
                Set-Content -Path $globalDestFile -Value $sourceContent
                Write-ColorOutput "Déploiement global réussi!" "Green"
            }
        }
        else {
            # Copier le contenu
            Set-Content -Path $globalDestFile -Value $sourceContent
            Write-ColorOutput "Déploiement global réussi!" "Green"
        }
    }
    else {
        # Copier le contenu
        Set-Content -Path $globalDestFile -Value $sourceContent
        Write-ColorOutput "Déploiement global réussi!" "Green"
    }
}

# Déploiement local
if ($DeploymentType -eq "local" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nDéploiement local en cours..." "Yellow"
    
    # Déterminer le chemin du fichier de destination local
    $localDestFile = ".roomodes"
    
    # Vérifier si le fichier de destination existe déjà
    if (Test-Path -Path $localDestFile -and $localDestFile -ne $SourceFile) {
        if (-not $Force) {
            $confirmation = Read-Host "Le fichier de destination local existe déjà. Voulez-vous le remplacer? (O/N)"
            if ($confirmation -ne "O" -and $confirmation -ne "o") {
                Write-ColorOutput "Déploiement local annulé." "Yellow"
            }
            else {
                # Copier le contenu
                Set-Content -Path $localDestFile -Value $sourceContent
                Write-ColorOutput "Déploiement local réussi!" "Green"
            }
        }
        else {
            # Copier le contenu
            Set-Content -Path $localDestFile -Value $sourceContent
            Write-ColorOutput "Déploiement local réussi!" "Green"
        }
    }
    elseif ($localDestFile -ne $SourceFile) {
        # Copier le contenu
        Set-Content -Path $localDestFile -Value $sourceContent
        Write-ColorOutput "Déploiement local réussi!" "Green"
    }
    else {
        Write-ColorOutput "Le fichier source et le fichier de destination local sont identiques. Aucune action nécessaire." "Green"
    }
}

# Vérifier que les fichiers sont identiques
if ($DeploymentType -eq "both") {
    Write-ColorOutput "`nVérification de la synchronisation..." "Yellow"
    
    $globalDestFile = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.json"
    $localDestFile = ".roomodes"
    
    if (Test-Path -Path $globalDestFile -and Test-Path -Path $localDestFile) {
        try {
            $diff = Compare-Object -ReferenceObject (Get-Content $localDestFile) -DifferenceObject (Get-Content $globalDestFile)
            
            if ($null -eq $diff) {
                Write-ColorOutput "Vérification réussie: Les fichiers sont synchronisés." "Green"
            }
            else {
                Write-ColorOutput "Avertissement: Les fichiers ne sont pas synchronisés." "Yellow"
                Write-ColorOutput "Différences trouvées:" "Yellow"
                $diff | Format-Table -AutoSize
            }
        }
        catch {
            Write-ColorOutput "Erreur lors de la vérification des fichiers:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
}

# Exécuter les tests si demandé
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExécution des tests après déploiement..." "Magenta"
    
    # Test du mécanisme d'escalade interne
    if (Test-Path -Path "test-escalade-code.js") {
        Write-ColorOutput "Test du mécanisme d'escalade interne..." "Magenta"
        try {
            node "test-escalade-code.js"
            Write-ColorOutput "Test d'escalade interne réussi!" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors du test d'escalade interne:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Fichier de test d'escalade interne non trouvé." "Yellow"
    }
    
    # Test du mécanisme de désescalade
    if (Test-Path -Path "test-desescalade-code.js") {
        Write-ColorOutput "Test du mécanisme de désescalade..." "Magenta"
        try {
            node "test-desescalade-code.js"
            Write-ColorOutput "Test de désescalade réussi!" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors du test de désescalade:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    }
    else {
        Write-ColorOutput "Fichier de test de désescalade non trouvé." "Yellow"
    }
}

# Afficher un résumé des modes installés
Write-ColorOutput "`nModes personnalisés installés:" "Cyan"
try {
    $json = $sourceContent | ConvertFrom-Json
    $modesCount = $json.customModes.Count
    
    Write-ColorOutput "Nombre de modes personnalisés: $modesCount" "Green"
    
    foreach ($mode in $json.customModes) {
        Write-ColorOutput "- $($mode.name) ($($mode.slug)) - Modèle: $($mode.model)" "White"
    }
}
catch {
    Write-ColorOutput "Erreur lors de l'affichage des modes installés:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
}

# Résumé
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Déploiement terminé avec succès!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés globalement et seront disponibles dans toutes les instances de VS Code." "White"
}
if ($DeploymentType -eq "local" -or $DeploymentType -eq "both") {
    Write-ColorOutput "`nLes modes personnalisés ont été déployés localement et seront disponibles dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes personnalisés:" "White"
Write-ColorOutput "1. Redémarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et sélectionnez un mode personnalisé" "White"
Write-ColorOutput "`n" "White"