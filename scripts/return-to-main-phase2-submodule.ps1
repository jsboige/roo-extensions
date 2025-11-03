# PHASE 2: Opération sous-module - Retour sur main sécurisé
# Stratégie SDDD - Merge Safe pour préserver l'historique

param(
    [switch]$Verbose,
    [switch]$Force
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Fonctions utilitaires
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-CommandSuccess {
    param([string]$Command, [string]$Args = "")
    try {
        $result = Invoke-Expression "$Command $Args" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
        return $result
    }
    catch {
        Write-Log "Command failed: $Command $Args" -Level "ERROR"
        Write-Log "Error: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Début PHASE 2
Write-Log "=== DÉBUT PHASE 2: OPÉRATION SOUS-MODULE ===" -Level "SUCCESS"

# Vérification répertoire sous-module
$submodulePath = "mcps/internal"
if (-not (Test-Path $submodulePath)) {
    Write-Log "ERREUR: Répertoire du sous-module non trouvé: $submodulePath" -Level "ERROR"
    exit 1
}

Write-Log "Navigation vers le sous-module: $submodulePath"
Set-Location $submodulePath

# État actuel du sous-module
Write-Log "État actuel du sous-module:"
$currentBranch = Test-CommandSuccess "git" "branch --show-current"
Write-Log "Branche actuelle: $currentBranch"

$currentStatus = Test-CommandSuccess "git" "status --porcelain"
if ([string]::IsNullOrWhiteSpace($currentStatus)) {
    Write-Log "✅ État Git clean" -Level "SUCCESS"
} else {
    Write-Log "⚠️ Changements en cours détectés:" -Level "WARN"
    Write-Host $currentStatus
    
    if (-not $Force) {
        Write-Log "Utilisez -Force pour continuer malgré les changements" -Level "WARN"
        exit 1
    }
}

# 1. Checkout main (MERGE SAFE)
Write-Log "1. Checkout de la branche main..."
$checkoutResult = Test-CommandSuccess "git" "checkout main"
if ($null -eq $checkoutResult) {
    Write-Log "ERREUR: Impossible de faire checkout sur main" -Level "ERROR"
    exit 1
}
Write-Log "✅ Checkout main réussi" -Level "SUCCESS"

# 2. Fetch origin
Write-Log "2. Récupération des changements distants..."
$fetchResult = Test-CommandSuccess "git" "fetch origin"
if ($null -eq $fetchResult) {
    Write-Log "ERREUR: Impossible de faire fetch origin" -Level "ERROR"
    exit 1
}
Write-Log "✅ Fetch origin réussi" -Level "SUCCESS"

# 3. Merge origin/main (APPROCHE MERGE SAFE)
Write-Log "3. Merge origin/main (MERGE SAFE - préservation historique)..."
$mergeResult = Test-CommandSuccess "git" "merge origin/main"
if ($null -eq $mergeResult) {
    Write-Log "ERREUR: Impossible de merger origin/main" -Level "ERROR"
    Write-Log "Vérifiez les conflits et résolvez-les manuellement" -Level "ERROR"
    exit 1
}
Write-Log "✅ Merge origin/main réussi" -Level "SUCCESS"

# 4. Validation post-merge
Write-Log "4. Validation post-merge..."
$lastCommits = Test-CommandSuccess "git" "log --oneline -5"
Write-Log "Derniers commits après merge:"
Write-Host $lastCommits

$finalStatus = Test-CommandSuccess "git" "status --porcelain"
if ([string]::IsNullOrWhiteSpace($finalStatus)) {
    Write-Log "✅ État Git clean post-merge" -Level "SUCCESS"
} else {
    Write-Log "⚠️ Changements en cours post-merge:" -Level "WARN"
    Write-Host $finalStatus
}

# 5. Validation compilation TypeScript (CRITIQUE)
Write-Log "5. Validation compilation TypeScript (CRITIQUE)..."
if (Test-Path "package.json") {
    Write-Log "Installation des dépendances..."
    $installResult = Test-CommandSuccess "npm" "install --silent"
    if ($null -eq $installResult) {
        Write-Log "ERREUR: npm install a échoué" -Level "ERROR"
        exit 1
    }
    Write-Log "✅ npm install réussi" -Level "SUCCESS"
    
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
    if ($packageJson.scripts.PSObject.Properties.Name -contains "build") {
        Write-Log "Compilation TypeScript..."
        $buildResult = Test-CommandSuccess "npm" "run build"
        if ($null -eq $buildResult) {
            Write-Log "ERREUR: npm run build a échoué" -Level "ERROR"
            Write-Log "Ceci est un problème critique qui doit être résolu" -Level "ERROR"
            exit 1
        }
        Write-Log "✅ Compilation TypeScript réussie" -Level "SUCCESS"
    } else {
        Write-Log "ℹ️ Pas de script build trouvé dans package.json" -Level "WARN"
    }
} else {
    Write-Log "ℹ️ package.json non trouvé, pas de validation TypeScript" -Level "WARN"
}

# Retour au répertoire principal
Write-Log "Retour au répertoire principal..."
Set-Location ../..

Write-Log "=== PHASE 2 TERMINÉE AVEC SUCCÈS ===" -Level "SUCCESS"
Write-Log "Sous-module mcps/internal maintenant sur main avec compilation validée" -Level "SUCCESS"

# Rapport de synthèse
Write-Log "RAPPORT DE SYNTHÈSE PHASE 2:" -Level "SUCCESS"
Write-Log "- Sous-module: mcps/internal" 
Write-Log "- Branche: main"
Write-Log "- Merge: origin/main (MERGE SAFE)"
Write-Log "- Compilation: Validée"
Write-Log "- État: Prêt pour PHASE 3"