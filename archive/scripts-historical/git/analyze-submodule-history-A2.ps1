# Analyse de l'historique du sous-module mcps/internal - Action A.2
# Date: 2025-10-13

$ErrorActionPreference = "Continue"

Write-Host "=== ANALYSE HISTORIQUE mcps/internal ===" -ForegroundColor Cyan
Write-Host ""

Push-Location mcps/internal
try {
    $localRef = "a5770dc"
    $remoteRef = "584810d"
    
    Write-Host "1. COMMIT LOCAL ($localRef):" -ForegroundColor Yellow
    git log $localRef -1 --pretty=format:"   Hash: %H%n   Auteur: %an <%ae>%n   Date: %ad%n   Message: %s%n   Corps:%n%b" --date=iso
    Write-Host ""
    
    Write-Host "`n2. COMMIT REMOTE ($remoteRef):" -ForegroundColor Yellow
    git log $remoteRef -1 --pretty=format:"   Hash: %H%n   Auteur: %an <%ae>%n   Date: %ad%n   Message: %s%n   Corps:%n%b" --date=iso
    Write-Host ""
    
    Write-Host "`n3. ANCÊTRE COMMUN:" -ForegroundColor Yellow
    $mergeBase = git merge-base $localRef $remoteRef
    if ($mergeBase) {
        Write-Host "   Hash: $mergeBase" -ForegroundColor Green
        git log $mergeBase -1 --oneline
        Write-Host ""
        
        Write-Host "`n4. COMMITS DEPUIS L'ANCÊTRE COMMUN:" -ForegroundColor Yellow
        
        Write-Host "`n   Chemin LOCAL ($mergeBase..$localRef):" -ForegroundColor Cyan
        $localCommits = git log "$mergeBase..$localRef" --oneline
        if ($localCommits) {
            $localCommits | ForEach-Object { Write-Host "   + $_" -ForegroundColor Green }
            Write-Host "   Total: $(($localCommits | Measure-Object).Count) commits" -ForegroundColor Gray
        } else {
            Write-Host "   (aucun)" -ForegroundColor Gray
        }
        
        Write-Host "`n   Chemin REMOTE ($mergeBase..$remoteRef):" -ForegroundColor Cyan
        $remoteCommits = git log "$mergeBase..$remoteRef" --oneline
        if ($remoteCommits) {
            $remoteCommits | ForEach-Object { Write-Host "   + $_" -ForegroundColor Yellow }
            Write-Host "   Total: $(($remoteCommits | Measure-Object).Count) commits" -ForegroundColor Gray
        } else {
            Write-Host "   (aucun)" -ForegroundColor Gray
        }
        
    } else {
        Write-Host "   [AUCUN ANCÊTRE COMMUN TROUVÉ]" -ForegroundColor Red
        Write-Host "   Les historiques sont complètement divergents" -ForegroundColor Red
    }
    
    Write-Host "`n5. FICHIERS MODIFIÉS:" -ForegroundColor Yellow
    
    Write-Host "`n   Fichiers modifiés dans LOCAL:" -ForegroundColor Cyan
    if ($mergeBase) {
        $localFiles = git diff --name-only "$mergeBase..$localRef"
        if ($localFiles) {
            $localFiles | ForEach-Object { Write-Host "   M $_" -ForegroundColor Green }
        } else {
            Write-Host "   (aucun)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n   Fichiers modifiés dans REMOTE:" -ForegroundColor Cyan
    if ($mergeBase) {
        $remoteFiles = git diff --name-only "$mergeBase..$remoteRef"
        if ($remoteFiles) {
            $remoteFiles | ForEach-Object { Write-Host "   M $_" -ForegroundColor Yellow }
        } else {
            Write-Host "   (aucun)" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n6. CONFLITS POTENTIELS:" -ForegroundColor Yellow
    if ($mergeBase) {
        $localFilesList = git diff --name-only "$mergeBase..$localRef"
        $remoteFilesList = git diff --name-only "$mergeBase..$remoteRef"
        
        $conflicts = @()
        foreach ($file in $localFilesList) {
            if ($remoteFilesList -contains $file) {
                $conflicts += $file
            }
        }
        
        if ($conflicts.Count -gt 0) {
            Write-Host "   Fichiers modifiés des DEUX côtés (conflits potentiels):" -ForegroundColor Red
            $conflicts | ForEach-Object { Write-Host "   ! $_" -ForegroundColor Red }
            Write-Host "   Total: $($conflicts.Count) fichiers" -ForegroundColor Red
        } else {
            Write-Host "   [PAS DE CONFLITS DÉTECTÉS]" -ForegroundColor Green
            Write-Host "   Les deux branches modifient des fichiers différents" -ForegroundColor Green
        }
    }
    
    Write-Host "`n=== STRATÉGIE RECOMMANDÉE ===" -ForegroundColor Cyan
    Write-Host ""
    
    if ($mergeBase) {
        if ($conflicts.Count -eq 0) {
            Write-Host "Situation FAVORABLE:" -ForegroundColor Green
            Write-Host "  - Les deux branches ont un ancêtre commun" -ForegroundColor White
            Write-Host "  - Aucun fichier modifié des deux côtés" -ForegroundColor White
            Write-Host "  - Le merge devrait être automatique" -ForegroundColor White
            Write-Host ""
            Write-Host "Action recommandée:" -ForegroundColor Yellow
            Write-Host "  git merge $remoteRef --no-edit" -ForegroundColor Gray
            Write-Host "  git push origin local-integration-internal-mcps" -ForegroundColor Gray
        } else {
            Write-Host "Situation COMPLEXE:" -ForegroundColor Yellow
            Write-Host "  - $($conflicts.Count) fichiers modifiés des deux côtés" -ForegroundColor White
            Write-Host "  - Risque de conflits de contenu" -ForegroundColor White
            Write-Host ""
            Write-Host "Action recommandée:" -ForegroundColor Yellow
            Write-Host "  1. git merge $remoteRef" -ForegroundColor Gray
            Write-Host "  2. Résoudre les conflits manuellement" -ForegroundColor Gray
            Write-Host "  3. git add [fichiers résolus]" -ForegroundColor Gray
            Write-Host "  4. git commit" -ForegroundColor Gray
            Write-Host "  5. git push origin local-integration-internal-mcps" -ForegroundColor Gray
        }
    } else {
        Write-Host "Situation CRITIQUE:" -ForegroundColor Red
        Write-Host "  - Aucun ancêtre commun" -ForegroundColor White
        Write-Host "  - Historiques complètement divergents" -ForegroundColor White
        Write-Host ""
        Write-Host "Nécessite une analyse manuelle approfondie" -ForegroundColor Red
    }
    
} finally {
    Pop-Location
}

Write-Host "`n=== FIN DE L'ANALYSE ===" -ForegroundColor Cyan