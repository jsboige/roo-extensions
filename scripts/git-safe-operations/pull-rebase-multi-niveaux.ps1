# Pull/Rebase Multi-Niveaux - Mission Critique
# Phase 4: Synchronisation avec gestion conflits architecture distribuée

$ErrorActionPreference = "Continue" 
$originalLocation = Get-Location

Write-Host "PULL/REBASE MULTI-NIVEAUX - SYNCHRONISATION CRITIQUE" -ForegroundColor Yellow
Write-Host "=" * 60

try {
    Set-Location "d:/dev/roo-extensions"
    
    # ============================================================================
    # ETAPE 1: DIAGNOSTIC PRE-REBASE COMPLET
    # ============================================================================
    
    Write-Host "`n[ETAPE 1] DIAGNOSTIC PRE-REBASE" -ForegroundColor Cyan
    
    # État local vs remote
    Write-Host "Etat divergence:" -ForegroundColor White
    git status --branch --porcelain=v1 | Where-Object { $_ -match "ahead|behind|diverged" } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Yellow
    }
    
    # Vérification working tree propre
    $workingTreeStatus = git status --porcelain
    if ($workingTreeStatus) {
        Write-Host "ATTENTION: Working tree non propre" -ForegroundColor Red
        $workingTreeStatus | ForEach-Object { Write-Host "  $_" }
        Write-Host "Nettoyage requis avant rebase" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "Working tree: PROPRE" -ForegroundColor Green
    }
    
    # Analyse commits locaux
    Write-Host "`nCommits locaux (non pushes):" -ForegroundColor White
    $localCommits = git log --oneline origin/main..HEAD
    if ($localCommits) {
        $localCommits | ForEach-Object { Write-Host "  LOCAL: $_" -ForegroundColor Cyan }
        Write-Host "Total commits locaux: $(($localCommits | Measure-Object).Count)" -ForegroundColor Cyan
    } else {
        Write-Host "  Aucun commit local unique" -ForegroundColor Green
    }
    
    # Analyse commits distants
    Write-Host "`nCommits distants (a integrer):" -ForegroundColor White
    git fetch origin 2>$null
    $remoteCommits = git log --oneline HEAD..origin/main
    if ($remoteCommits) {
        $remoteCommits | Select-Object -First 5 | ForEach-Object { Write-Host "  REMOTE: $_" -ForegroundColor Magenta }
        Write-Host "Total commits distants: $(($remoteCommits | Measure-Object).Count)" -ForegroundColor Magenta
        if (($remoteCommits | Measure-Object).Count -gt 5) {
            Write-Host "  ... et $((($remoteCommits | Measure-Object).Count) - 5) autres" -ForegroundColor Gray
        }
    }
    
    # ============================================================================
    # ETAPE 2: REBASE SOUS-MODULES (PRIORITE 1)
    # ============================================================================
    
    Write-Host "`n[ETAPE 2] REBASE SOUS-MODULES CRITIQUES" -ForegroundColor Cyan
    
    # Identifier sous-modules avec branches feature
    $criticalSubmodules = @("mcps/internal")
    
    foreach ($submodule in $criticalSubmodules) {
        if (Test-Path $submodule) {
            Write-Host "`n  SOUS-MODULE: $submodule" -ForegroundColor Magenta
            Push-Location $submodule
            
            $currentBranch = git branch --show-current
            $hasRemoteTrackingBranch = git rev-parse --abbrev-ref "@{upstream}" 2>$null
            
            Write-Host "    Branche courante: $currentBranch" -ForegroundColor White
            Write-Host "    Remote tracking: $hasRemoteTrackingBranch" -ForegroundColor Gray
            
            if ($hasRemoteTrackingBranch) {
                Write-Host "    Pull rebase sous-module..." -ForegroundColor Cyan
                git fetch origin 2>$null
                
                $rebaseResult = git pull --rebase origin $currentBranch 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    SUCCESS: Rebase sous-module reussi" -ForegroundColor Green
                } else {
                    Write-Host "    WARNING: Probleme rebase sous-module" -ForegroundColor Yellow
                    Write-Host "    Details: $rebaseResult" -ForegroundColor Gray
                }
            } else {
                Write-Host "    INFO: Pas de remote tracking branch" -ForegroundColor Blue
            }
            
            Pop-Location
        }
    }
    
    # ============================================================================
    # ETAPE 3: REBASE DEPOT PRINCIPAL (CRITIQUE)
    # ============================================================================
    
    Write-Host "`n[ETAPE 3] REBASE DEPOT PRINCIPAL" -ForegroundColor Cyan
    
    Write-Host "Preparation rebase principal..." -ForegroundColor White
    git fetch origin
    
    # Sauvegarde état actuel
    $currentCommit = git rev-parse HEAD
    Write-Host "Commit actuel sauvegarde: $currentCommit" -ForegroundColor Gray
    
    # Rebase interactif avec strategie
    Write-Host "`nDemarrage rebase critique..." -ForegroundColor Yellow
    Write-Host "ATTENTION: Rebase de 11 commits distants sur 2 commits locaux" -ForegroundColor Red
    
    # Rebase automatique d'abord
    $rebaseOutput = git rebase origin/main 2>&1
    $rebaseExitCode = $LASTEXITCODE
    
    if ($rebaseExitCode -eq 0) {
        Write-Host "SUCCESS: Rebase automatique reussi" -ForegroundColor Green
        
        # Vérification post-rebase
        $postRebaseStatus = git status --porcelain
        if (-not $postRebaseStatus) {
            Write-Host "Working tree propre apres rebase" -ForegroundColor Green
            $rebaseSuccess = $true
        } else {
            Write-Host "WARNING: Changements detectes apres rebase" -ForegroundColor Yellow
            $postRebaseStatus | ForEach-Object { Write-Host "  $_" }
            $rebaseSuccess = $false
        }
        
    } else {
        Write-Host "CONFLIT DETECTE pendant rebase" -ForegroundColor Red
        Write-Host "Output rebase:" -ForegroundColor White
        Write-Host $rebaseOutput -ForegroundColor Gray
        
        # Analyser conflits
        $conflictFiles = git diff --name-only --diff-filter=U
        if ($conflictFiles) {
            Write-Host "`nFichiers en conflit:" -ForegroundColor Red
            $conflictFiles | ForEach-Object { Write-Host "  CONFLIT: $_" -ForegroundColor Red }
            
            # Instructions pour résolution manuelle
            Write-Host "`nINSTRUCTIONS RESOLUTION CONFLIT:" -ForegroundColor Yellow
            Write-Host "1. Resoudre manuellement les conflits dans les fichiers listes" -ForegroundColor White
            Write-Host "2. git add <fichiers-resolus>" -ForegroundColor White  
            Write-Host "3. git rebase --continue" -ForegroundColor White
            Write-Host "4. Ou git rebase --abort pour annuler" -ForegroundColor White
            
            Write-Host "`nEtat actuel du rebase:" -ForegroundColor Cyan
            git status
            
            $rebaseSuccess = $false
        } else {
            Write-Host "Pas de conflit detecte mais echec rebase" -ForegroundColor Red
            $rebaseSuccess = $false
        }
    }
    
    # ============================================================================
    # ETAPE 4: VALIDATION POST-REBASE
    # ============================================================================
    
    Write-Host "`n[ETAPE 4] VALIDATION POST-REBASE" -ForegroundColor Yellow
    
    if ($rebaseSuccess) {
        # Vérification synchronisation
        Write-Host "Verification synchronisation..." -ForegroundColor Cyan
        
        $finalStatus = git status --porcelain
        $branchInfo = git status --branch --porcelain=v1 | Select-Object -First 1
        
        Write-Host "Etat final:" -ForegroundColor White
        Write-Host "  $branchInfo" -ForegroundColor $(if ($branchInfo -match "ahead") { 'Yellow' } else { 'Green' })
        
        if ($finalStatus) {
            Write-Host "Changements restants:" -ForegroundColor Yellow
            $finalStatus | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "Working tree: PROPRE" -ForegroundColor Green
        }
        
        # Vérification sous-modules
        Write-Host "`nEtat sous-modules post-rebase:" -ForegroundColor Cyan
        git submodule status | ForEach-Object {
            $status = if ($_ -match "^\+") { "MODIFIE" } 
                     elseif ($_ -match "^-") { "NON_INIT" } 
                     else { "SYNC" }
            $color = if ($status -eq "SYNC") { "Green" } else { "Yellow" }
            Write-Host "  $status : $_" -ForegroundColor $color
        }
        
        Write-Host "`nRESULTAT: REBASE MULTI-NIVEAUX REUSSI" -ForegroundColor Green
        
    } else {
        Write-Host "`nRESULTAT: REBASE NECESSITE INTERVENTION MANUELLE" -ForegroundColor Red
        Write-Host "Commit sauvegarde pour rollback: $currentCommit" -ForegroundColor Yellow
        Write-Host "Commande rollback si necessaire: git reset --hard $currentCommit" -ForegroundColor Yellow
    }
    
    Write-Host "=" * 60
    
} catch {
    Write-Host "ERREUR CRITIQUE REBASE: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "RECOMMANDATION: Verifier etat avec git status" -ForegroundColor Yellow
} finally {
    Set-Location $originalLocation
}