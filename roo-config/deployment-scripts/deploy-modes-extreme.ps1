# Script de deploiement des modes simples/complex pour Roo (Version extreme)
# Cette version evite completement l'utilisation de caracteres speciaux

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestAfterDeploy,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

# Fonction pour afficher des messages colores
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

# Banniere
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Deploiement des modes simples/complex pour Roo" "Cyan"
Write-ColorOutput "   (Version extreme)" "Cyan"
Write-ColorOutput "=========================================================" "Cyan"

# Utiliser le chemin absolu pour le fichier de configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFilePath = Join-Path -Path $projectRoot -ChildPath "roo-modes\configs\standard-modes.json"
$fixedConfigPath = Join-Path -Path $projectRoot -ChildPath "roo-modes\configs\standard-modes-fixed.json"

Write-ColorOutput "Script directory: $scriptDir" "Yellow"
Write-ColorOutput "Projet root: $projectRoot" "Yellow"
Write-ColorOutput "Chemin du fichier de configuration: $configFilePath" "Yellow"

# Verifier que le fichier de configuration existe
if (-not (Test-Path -Path $configFilePath)) {
    Write-ColorOutput "Erreur: Le fichier de configuration 'standard-modes.json' n'existe pas." "Red"
    Write-ColorOutput "Assurez-vous que le fichier existe dans le repertoire 'roo-modes/configs/'." "Red"
    exit 1
}

# Determiner le chemin du fichier de destination
if ($DeploymentType -eq "global") {
    $destinationDir = Join-Path -Path $env:APPDATA -ChildPath "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    $destinationFile = Join-Path -Path $destinationDir -ChildPath "custom_modes.json"
    
    # Verifier que le repertoire de destination existe
    if (-not (Test-Path -Path $destinationDir)) {
        try {
            New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            Write-ColorOutput "Repertoire cree: $destinationDir" "Green"
        }
        catch {
            Write-ColorOutput "Erreur lors de la creation du repertoire: $destinationDir" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
            exit 1
        }
    }
} else {
    # Deploiement local (dans le repertoire du projet)
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-ColorOutput "`nDeploiement des modes simples/complex en mode $DeploymentType..." "Yellow"
Write-ColorOutput "Destination: $destinationFile" "Yellow"

# Verifier si le fichier de destination existe deja
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de destination existe deja. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-ColorOutput "Operation annulee." "Yellow"
            exit 0
        }
    }
}

# Creer une sauvegarde du fichier source
$backupFilePath = "$configFilePath.backup"
if (-not (Test-Path -Path $backupFilePath)) {
    try {
        Copy-Item -Path $configFilePath -Destination $backupFilePath -Force
        Write-ColorOutput "Sauvegarde du fichier source creee: $backupFilePath" "Green"
    } catch {
        Write-ColorOutput "Avertissement: Impossible de creer une sauvegarde du fichier source." "Yellow"
        Write-ColorOutput $_.Exception.Message "Yellow"
    }
}

# Etape 1: Utiliser le script fix-encoding-extreme.ps1 pour corriger l'encodage
Write-ColorOutput "`nEtape 1: Application de la correction d'encodage extreme..." "Magenta"

$fixEncodingScript = Join-Path -Path $scriptDir -ChildPath "..\encoding-scripts\fix-encoding-extreme.ps1"
if (Test-Path -Path $fixEncodingScript) {
    try {
        # Executer le script de correction d'encodage
        & $fixEncodingScript -SourcePath $configFilePath -OutputPath $fixedConfigPath -Force
        
        if (-not (Test-Path -Path $fixedConfigPath)) {
            Write-ColorOutput "Erreur: Le script de correction d'encodage n'a pas cree le fichier corrige." "Red"
            exit 1
        }
        
        Write-ColorOutput "Correction d'encodage reussie!" "Green"
    } catch {
        Write-ColorOutput "Erreur lors de l'execution du script de correction d'encodage:" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        exit 1
    }
} else {
    Write-ColorOutput "Erreur: Le script de correction d'encodage n'a pas ete trouve: $fixEncodingScript" "Red"
    exit 1
}

# Etape 2: Deployer le fichier corrige
Write-ColorOutput "`nEtape 2: Deploiement du fichier corrige..." "Magenta"

try {
    # Verifier l'encodage du fichier corrige et supprimer le BOM si present
    $bytes = [System.IO.File]::ReadAllBytes($fixedConfigPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    if ($hasBom) {
        Write-ColorOutput "Le fichier corrige est encode en UTF-8 avec BOM" "Yellow"
        # Lire le contenu sans tenir compte du BOM
        $content = [System.IO.File]::ReadAllText($fixedConfigPath)
        # Reecrire sans BOM
        [System.IO.File]::WriteAllText($fixedConfigPath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-ColorOutput "BOM supprime du fichier corrige" "Green"
    } else {
        Write-ColorOutput "Le fichier corrige est encode en UTF-8 sans BOM" "Green"
    }
    
    # Lire le contenu du fichier corrige
    $jsonContent = [System.IO.File]::ReadAllText($fixedConfigPath)
    
    if ($DebugMode) {
        Write-ColorOutput "Contenu brut du fichier corrige (premiers 500 caracteres):" "Yellow"
        Write-ColorOutput $jsonContent.Substring(0, [Math]::Min(500, $jsonContent.Length)) "Yellow"
    }
    
    # Convertir le JSON en objet PowerShell
    $jsonObject = ConvertFrom-Json $jsonContent
    
    # Ajouter les attributs family et allowedFamilyTransitions
    foreach ($mode in $jsonObject.customModes) {
        if ($mode.slug -match "-simple$") {
            $mode | Add-Member -NotePropertyName "family" -NotePropertyValue "simple" -Force
            $mode | Add-Member -NotePropertyName "allowedFamilyTransitions" -NotePropertyValue @("simple") -Force
            
            # Ajouter le modele pour les modes simples
            $mode | Add-Member -NotePropertyName "model" -NotePropertyValue "anthropic/claude-3.5-sonnet" -Force
        } elseif ($mode.slug -match "-complex$" -or $mode.slug -eq "manager") {
            $mode | Add-Member -NotePropertyName "family" -NotePropertyValue "complex" -Force
            $mode | Add-Member -NotePropertyName "allowedFamilyTransitions" -NotePropertyValue @("complex") -Force
            
            # Ajouter le modele pour les modes complexes
            $mode | Add-Member -NotePropertyName "model" -NotePropertyValue "anthropic/claude-3.7-sonnet" -Force
        }
    }
    
    # Convertir l'objet PowerShell en JSON avec encodage UTF-8 et formatage preserve
    $jsonString = ConvertTo-Json $jsonObject -Depth 100 -Compress:$false
    
    # Ecrire le contenu en UTF-8 sans BOM pour une meilleure compatibilite
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($destinationFile, $jsonString, $utf8NoBomEncoding)
    
    Write-ColorOutput "Deploiement reussi!" "Green"
    
    # Verifier l'encodage du fichier de destination de maniere plus robuste
    $destBytes = [System.IO.File]::ReadAllBytes($destinationFile)
    $destEncoding = if ($destBytes.Length -ge 3 -and $destBytes[0] -eq 0xEF -and $destBytes[1] -eq 0xBB -and $destBytes[2] -eq 0xBF) {
        "UTF-8 with BOM"
    } else {
        "UTF-8 without BOM"
    }
    Write-ColorOutput "Encodage du fichier de destination: $destEncoding" "Cyan"
    
    # Verifier que le JSON de destination est valide
    $destContent = [System.IO.File]::ReadAllText($destinationFile)
    try {
        $null = ConvertFrom-Json $destContent
        Write-ColorOutput "Validation JSON: Le fichier de destination contient du JSON valide." "Green"
    } catch {
        Write-ColorOutput "Avertissement: Le fichier de destination ne contient pas du JSON valide." "Red"
        Write-ColorOutput "Le deploiement a ete effectue mais le fichier pourrait ne pas fonctionner correctement." "Red"
    }
} catch {
    Write-ColorOutput "Erreur lors du deploiement:" "Red"
    Write-ColorOutput $_.Exception.Message "Red"
    exit 1
}

# Executer les tests si demande
if ($TestAfterDeploy) {
    Write-ColorOutput "`nExecution des tests apres deploiement..." "Magenta"
    
    # Test du mecanisme d'escalade interne
    if (Test-Path -Path "$projectRoot/test-escalade-code.js") {
        Write-ColorOutput "Test du mecanisme d'escalade interne..." "Magenta"
        try {
            node "$projectRoot/test-escalade-code.js"
            Write-ColorOutput "Test d'escalade interne reussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test d'escalade interne:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test d'escalade interne non trouve." "Yellow"
    }
    
    # Test du mecanisme de desescalade
    if (Test-Path -Path "$projectRoot/test-desescalade-code.js") {
        Write-ColorOutput "Test du mecanisme de desescalade..." "Magenta"
        try {
            node "$projectRoot/test-desescalade-code.js"
            Write-ColorOutput "Test de desescalade reussi!" "Green"
        } catch {
            Write-ColorOutput "Erreur lors du test de desescalade:" "Red"
            Write-ColorOutput $_.Exception.Message "Red"
        }
    } else {
        Write-ColorOutput "Fichier de test de desescalade non trouve." "Yellow"
    }
}

# Resume
Write-ColorOutput "`n=========================================================" "Cyan"
Write-ColorOutput "   Deploiement des modes simples/complex termine avec succes!" "Green"
Write-ColorOutput "=========================================================" "Cyan"

if ($DeploymentType -eq "global") {
    Write-ColorOutput "`nLes modes simples/complex ont ete deployes globalement et seront disponibles dans toutes les instances de VS Code." "White"
} else {
    Write-ColorOutput "`nLes modes simples/complex ont ete deployes localement et seront disponibles uniquement dans ce projet." "White"
}

Write-ColorOutput "`nPour activer les modes simples/complex:" "White"
Write-ColorOutput "1. Redemarrez Visual Studio Code" "White"
Write-ColorOutput "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" "White"
Write-ColorOutput "3. Tapez 'Roo: Switch Mode' et selectionnez un des modes suivants:" "White"
Write-ColorOutput "   - Code Simple" "White"
Write-ColorOutput "   - Code Complex" "White"
Write-ColorOutput "   - Debug Simple" "White"
Write-ColorOutput "   - Debug Complex" "White"
Write-ColorOutput "   - Architect Simple" "White"
Write-ColorOutput "   - Architect Complex" "White"
Write-ColorOutput "   - Ask Simple" "White"
Write-ColorOutput "   - Ask Complex" "White"
Write-ColorOutput "   - Orchestrator Simple" "White"
Write-ColorOutput "   - Orchestrator Complex" "White"
Write-ColorOutput "   - Manager" "White"
Write-ColorOutput "`n" "White"