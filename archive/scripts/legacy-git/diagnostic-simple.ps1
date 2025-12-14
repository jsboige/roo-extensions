# Diagnostic Git Multi-Composants - Mission Critique
# Version simplifiée pour éviter erreurs syntaxe complexes

$ErrorActionPreference = "Continue"
$originalLocation = Get-Location

Write-Host "DIAGNOSTIC ARCHITECTURE GIT - MULTI-COMPOSANTS" -ForegroundColor Yellow
Write-Host "=" * 60

try {
    Set-Location "d:/dev/roo-extensions"
    Write-Host "Workspace: $(Get-Location)" -ForegroundColor Cyan
    
    # DEPOT PRINCIPAL
    Write-Host "`nDEPOT PRINCIPAL:" -ForegroundColor Cyan
    $mainStatus = git status --porcelain
    if ($mainStatus) {
        Write-Host "CHANGEMENTS DETECTES:" -ForegroundColor Yellow
        $mainStatus | ForEach-Object { Write-Host "  $_" }
        Write-Host "Total changements: $($mainStatus.Count)" -ForegroundColor Yellow
    } else {
        Write-Host "DEPOT PRINCIPAL: Propre" -ForegroundColor Green
    }
    
    # SOUS-MODULES OFFICIELS
    Write-Host "`nSOUS-MODULES OFFICIELS:" -ForegroundColor Cyan
    if (Test-Path ".gitmodules") {
        Write-Host "Fichier .gitmodules trouve" -ForegroundColor Green
        Get-Content ".gitmodules"
        git submodule status
    } else {
        Write-Host "Aucun sous-module officiel" -ForegroundColor Blue
    }
    
    # REPERTOIRES GIT INDEPENDANTS
    Write-Host "`nREPERTOIRES GIT INDEPENDANTS:" -ForegroundColor Cyan
    $gitDirectories = Get-ChildItem -Directory | Where-Object { 
        Test-Path (Join-Path $_.FullName '.git') 
    }
    
    $totalChanges = 0
    $componentsWithChanges = 0
    
    if ($gitDirectories) {
        foreach ($dir in $gitDirectories) {
            Write-Host "`nCOMPOSANT: $($dir.Name)" -ForegroundColor Magenta
            Push-Location $dir.FullName
            
            $componentStatus = git status --porcelain
            $branch = git branch --show-current
            $remoteUrl = git remote get-url origin 2>$null
            
            Write-Host "  Branche: $branch" -ForegroundColor $(if ($branch -eq 'main') { 'Green' } else { 'Yellow' })
            Write-Host "  Remote: $remoteUrl" -ForegroundColor Gray
            
            if ($componentStatus) {
                Write-Host "  Changements: $($componentStatus.Count)" -ForegroundColor Yellow
                $componentStatus | ForEach-Object { Write-Host "    $_" }
                $totalChanges += $componentStatus.Count
                $componentsWithChanges++
            } else {
                Write-Host "  Status: PROPRE" -ForegroundColor Green
            }
            
            Pop-Location
        }
        
        # SYNTHESE
        Write-Host "`nSYNTHESE ARCHITECTURE:" -ForegroundColor Yellow
        Write-Host "Composants detectes: $($gitDirectories.Count)"
        Write-Host "Composants avec changements: $componentsWithChanges" -ForegroundColor $(if ($componentsWithChanges -gt 0) { 'Yellow' } else { 'Green' })
        Write-Host "Total changements: $totalChanges" -ForegroundColor $(if ($totalChanges -gt 0) { 'Yellow' } else { 'Green' })
        
        # RECOMMANDATIONS
        Write-Host "`nRECOMMANDATIONS:" -ForegroundColor Yellow
        if ($totalChanges -eq 0) {
            Write-Host "ARCHITECTURE STABLE - Validation simple" -ForegroundColor Green
        } elseif ($totalChanges -lt 10) {
            Write-Host "CHANGEMENTS MODERES - Commits sequentiels" -ForegroundColor Yellow  
        } else {
            Write-Host "CHANGEMENTS IMPORTANTS - Operation critique" -ForegroundColor Red
        }
        
        # ORDRE DE TRAITEMENT
        Write-Host "`nORDRE DE TRAITEMENT SUGGERE:" -ForegroundColor Cyan
        $gitDirectories | ForEach-Object {
            $priority = if ($_.Name -eq "mcps") { "[INFRA]" } 
                       elseif ($_.Name -like "*roo-*") { "[CORE]" } 
                       else { "[COMP]" }
            Write-Host "  $priority $($_.Name)"
        }
        
    } else {
        Write-Host "Aucun repertoire Git independant detecte" -ForegroundColor Blue
    }
    
    Write-Host "`nDIAGNOSTIC COMPLETE" -ForegroundColor Green
    
} catch {
    Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Set-Location $originalLocation
}