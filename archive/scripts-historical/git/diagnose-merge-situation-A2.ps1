# Diagnostic détaillé de la situation de merge - Action A.2
# Date: 2025-10-13

$ErrorActionPreference = "Continue"

Write-Host "=== DIAGNOSTIC COMPLET DE LA SITUATION ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. État du dépôt principal LOCAL:" -ForegroundColor Yellow
Write-Host "   Branche actuelle:" -ForegroundColor Cyan
git branch --show-current

Write-Host "`n   Dernier commit LOCAL:" -ForegroundColor Cyan
git log -1 --oneline

Write-Host "`n   Référence actuelle du sous-module mcps/internal:" -ForegroundColor Cyan
git ls-tree HEAD mcps/internal

Write-Host "`n2. État du dépôt principal REMOTE (origin/main):" -ForegroundColor Yellow
git fetch origin main 2>&1 | Out-Null

Write-Host "   Dernier commit REMOTE:" -ForegroundColor Cyan
git log origin/main -1 --oneline

Write-Host "`n   Référence du sous-module mcps/internal sur REMOTE:" -ForegroundColor Cyan
git ls-tree origin/main mcps/internal

Write-Host "`n3. Historique récent du dépôt principal:" -ForegroundColor Yellow
Write-Host "   5 derniers commits LOCAL:" -ForegroundColor Cyan
git log -5 --oneline --graph

Write-Host "`n   5 derniers commits REMOTE:" -ForegroundColor Cyan
git log origin/main -5 --oneline --graph

Write-Host "`n4. Différences entre LOCAL et REMOTE:" -ForegroundColor Yellow
Write-Host "   Commits en avance (LOCAL non pushés):" -ForegroundColor Cyan
$ahead = git log origin/main..HEAD --oneline
if ($ahead) {
    $ahead | ForEach-Object { Write-Host "   + $_" -ForegroundColor Green }
} else {
    Write-Host "   (aucun)" -ForegroundColor Gray
}

Write-Host "`n   Commits en retard (REMOTE non pullés):" -ForegroundColor Cyan
$behind = git log HEAD..origin/main --oneline
if ($behind) {
    $behind | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
} else {
    Write-Host "   (aucun)" -ForegroundColor Gray
}

Write-Host "`n5. État du sous-module mcps/internal:" -ForegroundColor Yellow
Push-Location mcps/internal
try {
    Write-Host "   Branche actuelle:" -ForegroundColor Cyan
    $subBranch = git branch --show-current
    if ($subBranch) {
        Write-Host "   $subBranch" -ForegroundColor Green
    } else {
        Write-Host "   [DETACHED HEAD]" -ForegroundColor Red
    }
    
    Write-Host "`n   Commit actuel:" -ForegroundColor Cyan
    git log -1 --oneline
    
    Write-Host "`n   Statut:" -ForegroundColor Cyan
    $status = git status --short
    if ($status) {
        Write-Host "   Modifications:" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   Propre" -ForegroundColor Green
    }
    
    Write-Host "`n   Remote:" -ForegroundColor Cyan
    git remote -v | Select-Object -First 2
    
    Write-Host "`n   Branches disponibles:" -ForegroundColor Cyan
    git branch -a | Select-Object -First 10
    
} finally {
    Pop-Location
}

Write-Host "`n6. Analyse des conflits potentiels:" -ForegroundColor Yellow
Write-Host "   Comparaison des références de sous-module:" -ForegroundColor Cyan
$localRef = git ls-tree HEAD mcps/internal | ForEach-Object { $_.Split()[2] }
$remoteRef = git ls-tree origin/main mcps/internal | ForEach-Object { $_.Split()[2] }

Write-Host "   LOCAL:  $localRef" -ForegroundColor $(if ($localRef -eq $remoteRef) { 'Green' } else { 'Yellow' })
Write-Host "   REMOTE: $remoteRef" -ForegroundColor $(if ($localRef -eq $remoteRef) { 'Green' } else { 'Yellow' })

if ($localRef -ne $remoteRef) {
    Write-Host "`n   [DIVERGENCE DÉTECTÉE]" -ForegroundColor Red
    Write-Host "   Les deux références pointent vers des commits différents" -ForegroundColor Yellow
    
    Write-Host "`n   Analyse de la relation entre les commits:" -ForegroundColor Cyan
    Push-Location mcps/internal
    try {
        $isAncestor = git merge-base --is-ancestor $remoteRef $localRef 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   REMOTE ($remoteRef) est un ancêtre de LOCAL ($localRef)" -ForegroundColor Green
            Write-Host "   => Fast-forward possible" -ForegroundColor Green
        } else {
            $isAncestor2 = git merge-base --is-ancestor $localRef $remoteRef 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   LOCAL ($localRef) est un ancêtre de REMOTE ($remoteRef)" -ForegroundColor Yellow
                Write-Host "   => Besoin de pull dans le sous-module d'abord" -ForegroundColor Yellow
            } else {
                Write-Host "   Les commits ont divergé - merge nécessaire" -ForegroundColor Red
            }
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`n   [PAS DE DIVERGENCE]" -ForegroundColor Green
    Write-Host "   Les références sont identiques" -ForegroundColor Green
}

Write-Host "`n=== RECOMMANDATIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Basé sur cette analyse:" -ForegroundColor Yellow
if ($localRef -ne $remoteRef) {
    Write-Host "1. Vérifier l'historique des deux commits dans mcps/internal" -ForegroundColor White
    Write-Host "2. Décider quelle référence est la bonne (ou merger)" -ForegroundColor White
    Write-Host "3. Résoudre dans le sous-module d'abord" -ForegroundColor White
    Write-Host "4. Puis merger dans le dépôt principal" -ForegroundColor White
} else {
    Write-Host "Pas de conflit de sous-module - le merge devrait être simple" -ForegroundColor Green
}

Write-Host "`n=== FIN DU DIAGNOSTIC ===" -ForegroundColor Cyan