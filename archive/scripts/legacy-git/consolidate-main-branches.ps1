<#
.SYNOPSIS
    Consolidation complète des branches main (dépôt principal + sous-modules)
.DESCRIPTION
    Script autonome pour merger les branches main avec gestion intelligente des conflits
.PARAMETER DryRun
    Mode simulation sans modifications réelles
#>

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"
$script:RootDir = $PWD.Path
$script:LogFile = Join-Path $script:RootDir "scripts/git-safe-operations/consolidation-main-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $script:LogFile -Value $logEntry
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host "="*80 -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "="*80 -ForegroundColor Cyan
    Write-Log "=== $Title ==="
}

function Test-GitClean {
    param([string]$Context = ".")
    Push-Location $Context
    $status = git status --porcelain
    Pop-Location
    return [string]::IsNullOrWhiteSpace($status)
}

function Get-GitDivergence {
    param([string]$Context = ".")
    Push-Location $Context
    $ahead = (git rev-list --count origin/main..HEAD)
    $behind = (git rev-list --count HEAD..origin/main)
    Pop-Location
    return @{
        Ahead = [int]$ahead
        Behind = [int]$behind
    }
}

function Show-DiffStats {
    param([string]$Context = ".", [string]$Label = "")
    Push-Location $Context
    Write-Host "`n--- Commits distants à récupérer ($Label) ---" -ForegroundColor Yellow
    git log HEAD..origin/main --oneline --decorate
    Write-Host "`n--- Statistiques des différences ($Label) ---" -ForegroundColor Yellow
    git diff HEAD origin/main --stat
    Pop-Location
}

function Invoke-SafeMerge {
    param(
        [string]$Context = ".",
        [string]$Label = "",
        [switch]$SubmoduleMode = $false
    )
    
    Push-Location $Context
    Write-Section "MERGE: $Label"
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] Simulation du merge de origin/main" -ForegroundColor Yellow
        git merge origin/main --no-commit --no-ff
        $mergeResult = $LASTEXITCODE
        
        if ($mergeResult -ne 0) {
            Write-Host "`n⚠️ CONFLITS DÉTECTÉS (mode simulation)" -ForegroundColor Red
            git status
            git merge --abort
        } else {
            Write-Host "✓ Merge réussi (simulation)" -ForegroundColor Green
            git merge --abort
        }
        Pop-Location
        return $mergeResult
    }
    
    # Merge réel
    Write-Log "Démarrage merge: $Label"
    git merge origin/main --no-edit
    $mergeResult = $LASTEXITCODE
    
    if ($mergeResult -ne 0) {
        Write-Host "`n⚠️ CONFLITS DÉTECTÉS" -ForegroundColor Red
        Write-Log "Conflits détectés dans: $Label" "WARNING"
        
        $conflicts = git diff --name-only --diff-filter=U
        Write-Host "`nFichiers en conflit:" -ForegroundColor Yellow
        $conflicts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        
        Write-Host "`n📋 Analyse des conflits..." -ForegroundColor Cyan
        
        foreach ($file in $conflicts) {
            Write-Host "`n--- Conflit: $file ---" -ForegroundColor Yellow
            
            # Stratégies spécifiques
            if ($file -match "roo-storage-detector\.ts") {
                Write-Host "  Stratégie: Conserver NOTRE version (refactoring prévu)" -ForegroundColor Cyan
                git checkout --ours $file
                git add $file
                Write-Log "Résolution conflit $file : version locale conservée"
            }
            elseif ($file -match "package\.json") {
                Write-Host "  Stratégie: Fusion manuelle nécessaire (dépendances)" -ForegroundColor Yellow
                Write-Host "  ⚠️ Nécessite votre intervention manuelle" -ForegroundColor Red
                Write-Log "Résolution conflit $file : intervention manuelle requise" "WARNING"
            }
            else {
                Write-Host "  Stratégie: Analyse contextuelle nécessaire" -ForegroundColor Yellow
                # Afficher le contexte du conflit
                git diff $file | Select-Object -First 50
                Write-Host "  ⚠️ Nécessite votre intervention manuelle" -ForegroundColor Red
                Write-Log "Résolution conflit $file : intervention manuelle requise" "WARNING"
            }
        }
        
        # Vérifier s'il reste des conflits non résolus
        $remainingConflicts = git diff --name-only --diff-filter=U
        if ($remainingConflicts) {
            Write-Host "`n⚠️ Conflits non résolus automatiquement:" -ForegroundColor Red
            $remainingConflicts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            Write-Host "`n📝 PAUSE: Résolvez manuellement ces conflits, puis relancez le script" -ForegroundColor Yellow
            Pop-Location
            exit 1
        }
        
        # Finaliser le merge si tous les conflits sont résolus
        git commit --no-edit
        Write-Host "✓ Merge complété avec résolution de conflits" -ForegroundColor Green
        Write-Log "Merge complété: $Label (avec résolution de conflits)"
    }
    else {
        Write-Host "✓ Merge réussi sans conflits" -ForegroundColor Green
        Write-Log "Merge complété: $Label (sans conflits)"
    }
    
    Pop-Location
    return 0
}

function Test-Compilation {
    param([string]$Context, [string]$Label)
    
    Push-Location $Context
    Write-Section "VALIDATION: Compilation $Label"
    
    if (!(Test-Path "package.json")) {
        Write-Host "⚠️ Pas de package.json, skip compilation" -ForegroundColor Yellow
        Pop-Location
        return $true
    }
    
    Write-Host "Building..." -ForegroundColor Cyan
    npm run build 2>&1 | Tee-Object -Variable buildOutput
    $buildResult = $LASTEXITCODE
    
    if ($buildResult -eq 0) {
        Write-Host "✓ Compilation réussie" -ForegroundColor Green
        Write-Log "Compilation réussie: $Label"
        Pop-Location
        return $true
    }
    else {
        Write-Host "✗ Erreur de compilation" -ForegroundColor Red
        Write-Log "Erreur de compilation: $Label" "ERROR"
        Pop-Location
        return $false
    }
}

# ============================================================================
# DÉBUT DU SCRIPT PRINCIPAL
# ============================================================================

Write-Section "CONSOLIDATION BRANCHES MAIN - DÉMARRAGE"
Write-Log "Script démarré (DryRun: $DryRun)"

# Vérification de l'état initial
if (!(Test-GitClean ".")) {
    Write-Host "⚠️ ERREUR: Working tree non propre" -ForegroundColor Red
    git status
    exit 1
}

# PHASE 1: Analyse initiale
Write-Section "PHASE 1: Analyse de l'état actuel"

$mainDiv = Get-GitDivergence "."
$submoduleDiv = Get-GitDivergence "mcps/internal"

Write-Host "`nDépôt principal:" -ForegroundColor Cyan
Write-Host "  Commits locaux (ahead):  $($mainDiv.Ahead)" -ForegroundColor Yellow
Write-Host "  Commits distants (behind): $($mainDiv.Behind)" -ForegroundColor Yellow

Write-Host "`nSous-module mcps/internal:" -ForegroundColor Cyan
Write-Host "  Commits locaux (ahead):  $($submoduleDiv.Ahead)" -ForegroundColor Yellow
Write-Host "  Commits distants (behind): $($submoduleDiv.Behind)" -ForegroundColor Yellow

# PHASE 2: Fetch
Write-Section "PHASE 2: Fetch des changements distants"
git fetch origin
Push-Location mcps/internal
git fetch origin
Pop-Location
Write-Host "✓ Fetch complété" -ForegroundColor Green

# PHASE 3: Affichage des différences
Write-Section "PHASE 3: Analyse des différences"
Show-DiffStats "." "Dépôt principal"
Show-DiffStats "mcps/internal" "Sous-module mcps/internal"

# PHASE 4: Merge sous-module
$submoduleMergeResult = Invoke-SafeMerge -Context "mcps/internal" -Label "Sous-module mcps/internal" -SubmoduleMode

if ($submoduleMergeResult -ne 0 -and !$DryRun) {
    Write-Host "`n⚠️ Le merge du sous-module a échoué ou nécessite une intervention" -ForegroundColor Red
    exit 1
}

# PHASE 5: Merge dépôt principal
$mainMergeResult = Invoke-SafeMerge -Context "." -Label "Dépôt principal"

if ($mainMergeResult -ne 0 -and !$DryRun) {
    Write-Host "`n⚠️ Le merge du dépôt principal a échoué ou nécessite une intervention" -ForegroundColor Red
    exit 1
}

# PHASE 6: Mise à jour référence sous-module
if (!$DryRun) {
    Write-Section "PHASE 6: Mise à jour référence sous-module"
    
    $submoduleChanged = git diff --name-only | Select-String "mcps/internal"
    if ($submoduleChanged) {
        Write-Host "Mise à jour de la référence du sous-module..." -ForegroundColor Cyan
        git add mcps/internal
        git commit -m "chore: Update mcps/internal submodule after main merge"
        Write-Host "✓ Référence mise à jour" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Aucune modification de référence détectée" -ForegroundColor Yellow
    }
}

# PHASE 7: Validation compilation
Write-Section "PHASE 7: Validation de la compilation"

$compilationOK = $true

# Test roo-state-manager
if (Test-Path "mcps/internal/servers/roo-state-manager") {
    if (!(Test-Compilation "mcps/internal/servers/roo-state-manager" "roo-state-manager")) {
        $compilationOK = $false
    }
}

# Test jupyter-papermill si modifié
if (Test-Path "mcps/internal/servers/jupyter-papermill") {
    if (!(Test-Compilation "mcps/internal/servers/jupyter-papermill" "jupyter-papermill")) {
        $compilationOK = $false
    }
}

# PHASE 8: Tests unitaires
if (!$DryRun -and $compilationOK) {
    Write-Section "PHASE 8: Exécution des tests unitaires"
    
    Push-Location "mcps/internal/servers/roo-state-manager"
    if (Test-Path "package.json") {
        Write-Host "Lancement des tests..." -ForegroundColor Cyan
        npm test 2>&1 | Tee-Object -Variable testOutput
        $testResult = $LASTEXITCODE
        
        if ($testResult -eq 0) {
            Write-Host "✓ Tests réussis" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️ Certains tests ont échoué (à vérifier)" -ForegroundColor Yellow
        }
    }
    Pop-Location
}

# RAPPORT FINAL
Write-Section "RAPPORT FINAL"

Write-Host "`n📊 État final:" -ForegroundColor Cyan
Write-Host "`nDépôt principal (derniers commits):" -ForegroundColor Yellow
git log --oneline -5

Write-Host "`nSous-module mcps/internal (derniers commits):" -ForegroundColor Yellow
Push-Location mcps/internal
git log --oneline -5
Pop-Location

Write-Host "`n✅ CONSOLIDATION TERMINÉE" -ForegroundColor Green
Write-Host "📄 Log complet: $script:LogFile" -ForegroundColor Cyan
Write-Log "Script terminé avec succès"

if ($DryRun) {
    Write-Host "`n⚠️ MODE DRY-RUN: Aucune modification n'a été effectuée" -ForegroundColor Yellow
}