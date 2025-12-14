# Commits Orchestrés Multi-Composants - Mission Critique
# Phase 3: Commits séquentiels sécurisés par ordre de dépendances

$ErrorActionPreference = "Continue"
$originalLocation = Get-Location

Write-Host "COMMITS ORCHESTRES MULTI-COMPOSANTS" -ForegroundColor Yellow
Write-Host "=" * 50

try {
    Set-Location "d:/dev/roo-extensions"
    
    # ============================================================================
    # ETAPE 1: COMMIT SOUS-MODULE MCPS/INTERNAL (PRIORITE 1)
    # ============================================================================
    
    Write-Host "`n[ETAPE 1] SOUS-MODULE mcps/internal" -ForegroundColor Cyan
    
    if (Test-Path "mcps/internal") {
        Push-Location "mcps/internal"
        
        # Vérifier état du sous-module
        $submoduleStatus = git status --porcelain
        $currentBranch = git branch --show-current
        
        Write-Host "Branche courante: $currentBranch" -ForegroundColor Yellow
        Write-Host "Changements detectes: $($submoduleStatus.Count)" -ForegroundColor $(if ($submoduleStatus.Count -gt 0) { 'Yellow' } else { 'Green' })
        
        if ($submoduleStatus) {
            Write-Host "Details changements sous-module:" -ForegroundColor White
            $submoduleStatus | ForEach-Object { Write-Host "  $_" }
            
            # Commit sous-module
            Write-Host "`nCommit sous-module en cours..." -ForegroundColor Cyan
            
            git add .
            
            $commitMessage = "[INFRA] mcps/internal - Synchronisation multi-composants $(Get-Date -Format 'yyyy-MM-dd-HH:mm')"
            git commit -m $commitMessage
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: Sous-module mcps/internal commite" -ForegroundColor Green
                $submoduleCommitted = $true
            } else {
                Write-Host "ECHEC: Commit sous-module mcps/internal" -ForegroundColor Red
                $submoduleCommitted = $false
            }
        } else {
            Write-Host "Aucun changement dans sous-module mcps/internal" -ForegroundColor Green
            $submoduleCommitted = $true
        }
        
        Pop-Location
    } else {
        Write-Host "Sous-module mcps/internal introuvable" -ForegroundColor Red
        $submoduleCommitted = $false
    }
    
    # ============================================================================
    # ETAPE 2: COMMIT DEPOT PRINCIPAL (PRIORITE 2)
    # ============================================================================
    
    Write-Host "`n[ETAPE 2] DEPOT PRINCIPAL" -ForegroundColor Cyan
    
    $mainStatus = git status --porcelain
    Write-Host "Changements depot principal: $($mainStatus.Count)" -ForegroundColor $(if ($mainStatus.Count -gt 0) { 'Yellow' } else { 'Green' })
    
    if ($mainStatus) {
        Write-Host "Details changements depot principal:" -ForegroundColor White
        $mainStatus | ForEach-Object { Write-Host "  $_" }
        
        # Séparation scripts de diagnostic/utilitaires vs changements système
        $scriptFiles = $mainStatus | Where-Object { $_ -match "scripts/git-safe-operations/" }
        $systemFiles = $mainStatus | Where-Object { $_ -notmatch "scripts/git-safe-operations/" }
        
        Write-Host "`nAnalyse changements:" -ForegroundColor Cyan
        Write-Host "  Scripts utilitaires: $($scriptFiles.Count)" -ForegroundColor Blue
        Write-Host "  Changements systeme: $($systemFiles.Count)" -ForegroundColor $(if ($systemFiles.Count -gt 0) { 'Yellow' } else { 'Green' })
        
        # Commit par catégories
        if ($scriptFiles.Count -gt 0) {
            Write-Host "`nCommit scripts utilitaires..." -ForegroundColor Cyan
            
            # Add seulement les scripts
            $scriptFiles | ForEach-Object {
                $file = ($_ -split " ", 2)[1]
                git add $file
                Write-Host "  Ajoute: $file" -ForegroundColor Gray
            }
            
            $scriptCommitMessage = "[TOOLS] Scripts diagnostic Git multi-sous-modules - Operation critique $(Get-Date -Format 'yyyy-MM-dd-HH:mm')"
            git commit -m $scriptCommitMessage
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: Scripts utilitaires commites" -ForegroundColor Green
                $scriptsCommitted = $true
            } else {
                Write-Host "ECHEC: Commit scripts utilitaires" -ForegroundColor Red
                $scriptsCommitted = $false
            }
        }
        
        if ($systemFiles.Count -gt 0) {
            Write-Host "`nCommit changements systeme..." -ForegroundColor Cyan
            
            # Add changements système
            $systemFiles | ForEach-Object {
                $file = ($_ -split " ", 2)[1]
                git add $file
                Write-Host "  Ajoute: $file" -ForegroundColor Gray
            }
            
            $systemCommitMessage = "[SYSTEM] Mise a jour sous-modules - Synchronisation $(Get-Date -Format 'yyyy-MM-dd-HH:mm')"
            git commit -m $systemCommitMessage
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: Changements systeme commites" -ForegroundColor Green
                $systemCommitted = $true
            } else {
                Write-Host "ECHEC: Commit changements systeme" -ForegroundColor Red
                $systemCommitted = $false
            }
        }
        
    } else {
        Write-Host "Aucun changement dans depot principal" -ForegroundColor Green
        $scriptsCommitted = $true
        $systemCommitted = $true
    }
    
    # ============================================================================
    # ETAPE 3: VERIFICATION POST-COMMITS
    # ============================================================================
    
    Write-Host "`n[VERIFICATION] ETAT POST-COMMITS" -ForegroundColor Yellow
    
    # Vérification état final
    $finalStatus = git status --porcelain
    Write-Host "Etat final depot principal:" -ForegroundColor Cyan
    if ($finalStatus) {
        $finalStatus | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        Write-Host "Changements restants: $($finalStatus.Count)" -ForegroundColor Yellow
    } else {
        Write-Host "  Working directory propre" -ForegroundColor Green
    }
    
    # Vérification sous-modules
    Write-Host "`nEtat sous-modules:" -ForegroundColor Cyan
    git submodule status | ForEach-Object {
        if ($_ -match "^\+") {
            Write-Host "  MODIFIE: $_" -ForegroundColor Yellow
        } elseif ($_ -match "^-") {
            Write-Host "  NON_INIT: $_" -ForegroundColor Red
        } else {
            Write-Host "  SYNC: $_" -ForegroundColor Green
        }
    }
    
    # ============================================================================
    # RAPPORT FINAL COMMITS
    # ============================================================================
    
    Write-Host "`nRAPPORT COMMITS ORCHESTRES:" -ForegroundColor Yellow
    Write-Host "-" * 40
    
    $commitResults = @{
        SubmoduleCommitted = $submoduleCommitted
        ScriptsCommitted = $scriptsCommitted  
        SystemCommitted = $systemCommitted
        FinalChanges = $finalStatus.Count
    }
    
    $allCommitsSuccess = $submoduleCommitted -and $scriptsCommitted -and $systemCommitted
    
    Write-Host "Sous-module mcps/internal: $(if ($submoduleCommitted) { 'SUCCESS' } else { 'ECHEC' })" -ForegroundColor $(if ($submoduleCommitted) { 'Green' } else { 'Red' })
    Write-Host "Scripts utilitaires: $(if ($scriptsCommitted) { 'SUCCESS' } else { 'ECHEC' })" -ForegroundColor $(if ($scriptsCommitted) { 'Green' } else { 'Red' })
    Write-Host "Changements systeme: $(if ($systemCommitted) { 'SUCCESS' } else { 'ECHEC' })" -ForegroundColor $(if ($systemCommitted) { 'Green' } else { 'Red' })
    Write-Host "Etat final: $(if ($finalStatus.Count -eq 0) { 'PROPRE' } else { "$($finalStatus.Count) changements restants" })" -ForegroundColor $(if ($finalStatus.Count -eq 0) { 'Green' } else { 'Yellow' })
    
    if ($allCommitsSuccess -and $finalStatus.Count -eq 0) {
        Write-Host "`nRESULTAT: COMMITS ORCHESTRES REUSSIS" -ForegroundColor Green
    } elseif ($allCommitsSuccess) {
        Write-Host "`nRESULTAT: COMMITS REUSSIS - Changements restants a traiter" -ForegroundColor Yellow
    } else {
        Write-Host "`nRESULTAT: ECHECS DETECTES - Verification necessaire" -ForegroundColor Red
    }
    
    Write-Host "=" * 50
    
} catch {
    Write-Host "ERREUR COMMITS: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Set-Location $originalLocation
}