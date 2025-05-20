# Script de deploiement des modes simples/complex pour Roo (Version ultra-simplifiee)
# Cette version utilise un script de correction d'encodage ultra-simplifie

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("global", "local")]
    [string]$DeploymentType = "global",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode
)

# Banniere
Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "   Deploiement des modes simples/complex pour Roo" -ForegroundColor Cyan
Write-Host "   (Version ultra-simplifiee)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Utiliser le chemin absolu pour le fichier de configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
$configFilePath = Join-Path -Path $projectRoot -ChildPath "roo-modes\configs\standard-modes.json"
$fixedConfigPath = Join-Path -Path $projectRoot -ChildPath "roo-modes\configs\standard-modes-fixed.json"

Write-Host "Script directory: $scriptDir" -ForegroundColor Yellow
Write-Host "Projet root: $projectRoot" -ForegroundColor Yellow
Write-Host "Chemin du fichier de configuration: $configFilePath" -ForegroundColor Yellow

# Verifier que le fichier de configuration existe
if (-not (Test-Path -Path $configFilePath)) {
    Write-Host "Erreur: Le fichier de configuration 'standard-modes.json' n'existe pas." -ForegroundColor Red
    Write-Host "Assurez-vous que le fichier existe dans le repertoire 'roo-modes/configs/'." -ForegroundColor Red
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
            Write-Host "Repertoire cree: $destinationDir" -ForegroundColor Green
        }
        catch {
            Write-Host "Erreur lors de la creation du repertoire: $destinationDir" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
} else {
    # Deploiement local (dans le repertoire du projet)
    $destinationFile = Join-Path -Path $projectRoot -ChildPath ".roomodes"
}

Write-Host "`nDeploiement des modes simples/complex en mode $DeploymentType..." -ForegroundColor Yellow
Write-Host "Destination: $destinationFile" -ForegroundColor Yellow

# Verifier si le fichier de destination existe deja
if (Test-Path -Path $destinationFile) {
    if (-not $Force) {
        $confirmation = Read-Host "Le fichier de destination existe deja. Voulez-vous le remplacer? (O/N)"
        if ($confirmation -ne "O" -and $confirmation -ne "o") {
            Write-Host "Operation annulee." -ForegroundColor Yellow
            exit 0
        }
    }
}

# Creer une sauvegarde du fichier source
$backupFilePath = "$configFilePath.backup"
if (-not (Test-Path -Path $backupFilePath)) {
    try {
        Copy-Item -Path $configFilePath -Destination $backupFilePath -Force
        Write-Host "Sauvegarde du fichier source creee: $backupFilePath" -ForegroundColor Green
    } catch {
        Write-Host "Avertissement: Impossible de creer une sauvegarde du fichier source." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}

# Etape 1: Utiliser le script fix-encoding-ultra-simple.ps1 pour corriger l'encodage
Write-Host "`nEtape 1: Application de la correction d'encodage ultra-simplifiee..." -ForegroundColor Magenta

$fixEncodingScript = Join-Path -Path $scriptDir -ChildPath "..\encoding-scripts\fix-encoding-ultra-simple.ps1"
if (Test-Path -Path $fixEncodingScript) {
    try {
        # Executer le script de correction d'encodage
        & $fixEncodingScript -SourcePath $configFilePath -OutputPath $fixedConfigPath -Force
        
        if (-not (Test-Path -Path $fixedConfigPath)) {
            Write-Host "Erreur: Le script de correction d'encodage n'a pas cree le fichier corrige." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Correction d'encodage reussie!" -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors de l'execution du script de correction d'encodage:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Erreur: Le script de correction d'encodage n'a pas ete trouve: $fixEncodingScript" -ForegroundColor Red
    exit 1
}

# Etape 2: Deployer le fichier corrige
Write-Host "`nEtape 2: Deploiement du fichier corrige..." -ForegroundColor Magenta

try {
    # Verifier l'encodage du fichier corrige et supprimer le BOM si present
    $bytes = [System.IO.File]::ReadAllBytes($fixedConfigPath)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    if ($hasBom) {
        Write-Host "Le fichier corrige est encode en UTF-8 avec BOM" -ForegroundColor Yellow
        # Lire le contenu sans tenir compte du BOM
        $content = [System.IO.File]::ReadAllText($fixedConfigPath)
        # Reecrire sans BOM
        [System.IO.File]::WriteAllText($fixedConfigPath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "BOM supprime du fichier corrige" -ForegroundColor Green
    } else {
        Write-Host "Le fichier corrige est encode en UTF-8 sans BOM" -ForegroundColor Green
    }
    
    # Lire le contenu du fichier corrige
    $jsonContent = [System.IO.File]::ReadAllText($fixedConfigPath)
    
    if ($DebugMode) {
        Write-Host "Contenu brut du fichier corrige (premiers 500 caracteres):" -ForegroundColor Yellow
        Write-Host $jsonContent.Substring(0, [Math]::Min(500, $jsonContent.Length)) -ForegroundColor Yellow
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
    
    Write-Host "Deploiement reussi!" -ForegroundColor Green
    
    # Verifier l'encodage du fichier de destination de maniere plus robuste
    $destBytes = [System.IO.File]::ReadAllBytes($destinationFile)
    $destEncoding = if ($destBytes.Length -ge 3 -and $destBytes[0] -eq 0xEF -and $destBytes[1] -eq 0xBB -and $destBytes[2] -eq 0xBF) {
        "UTF-8 with BOM"
    } else {
        "UTF-8 without BOM"
    }
    Write-Host "Encodage du fichier de destination: $destEncoding" -ForegroundColor Cyan
    
    # Verifier que le JSON de destination est valide
    $destContent = [System.IO.File]::ReadAllText($destinationFile)
    try {
        $null = ConvertFrom-Json $destContent
        Write-Host "Validation JSON: Le fichier de destination contient du JSON valide." -ForegroundColor Green
    } catch {
        Write-Host "Avertissement: Le fichier de destination ne contient pas du JSON valide." -ForegroundColor Red
        Write-Host "Le deploiement a ete effectue mais le fichier pourrait ne pas fonctionner correctement." -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur lors du deploiement:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Resume
Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "   Deploiement des modes simples/complex termine avec succes!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Cyan

if ($DeploymentType -eq "global") {
    Write-Host "`nLes modes simples/complex ont ete deployes globalement et seront disponibles dans toutes les instances de VS Code." -ForegroundColor White
} else {
    Write-Host "`nLes modes simples/complex ont ete deployes localement et seront disponibles uniquement dans ce projet." -ForegroundColor White
}

Write-Host "`nPour activer les modes simples/complex:" -ForegroundColor White
Write-Host "1. Redemarrez Visual Studio Code" -ForegroundColor White
Write-Host "2. Ouvrez la palette de commandes (Ctrl+Shift+P)" -ForegroundColor White
Write-Host "3. Tapez 'Roo: Switch Mode' et selectionnez un des modes suivants:" -ForegroundColor White
Write-Host "   - Code Simple" -ForegroundColor White
Write-Host "   - Code Complex" -ForegroundColor White
Write-Host "   - Debug Simple" -ForegroundColor White
Write-Host "   - Debug Complex" -ForegroundColor White
Write-Host "   - Architect Simple" -ForegroundColor White
Write-Host "   - Architect Complex" -ForegroundColor White
Write-Host "   - Ask Simple" -ForegroundColor White
Write-Host "   - Ask Complex" -ForegroundColor White
Write-Host "   - Orchestrator Simple" -ForegroundColor White
Write-Host "   - Orchestrator Complex" -ForegroundColor White
Write-Host "   - Manager" -ForegroundColor White
Write-Host "`n" -ForegroundColor White