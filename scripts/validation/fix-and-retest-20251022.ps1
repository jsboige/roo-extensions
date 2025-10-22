# Correction complète et re-test de la hiérarchie
# Date: 2025-10-22

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"
$baseStorage = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline"
$childTaskId = "18141742-f376-4053-8e1f-804d79daaf6d"

Write-Host "`n=== CORRECTION ET RE-TEST HIÉRARCHIE ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY-RUN (simulation)' } else { 'EXÉCUTION RÉELLE' })`n" -ForegroundColor Yellow

# ÉTAPE 1: Nettoyer les fichiers dans les mauvais emplacements
Write-Host "[1] Nettoyage des fichiers dupliqués..." -ForegroundColor Cyan

$wrongPath = "$baseStorage\.skeletons\$childTaskId.json"
$correctPath = "$baseStorage\tasks\.skeletons\$childTaskId.json"

if (Test-Path $wrongPath) {
    $wrongFile = Get-Item $wrongPath
    Write-Host "   Fichier dans mauvais emplacement trouvé:" -ForegroundColor Yellow
    Write-Host "   - Taille: $([math]::Round($wrongFile.Length/1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "   - Modifié: $($wrongFile.LastWriteTime)" -ForegroundColor Gray
    
    if (-not $DryRun) {
        Remove-Item $wrongPath -Force
        Write-Host "   ✅ Fichier supprimé" -ForegroundColor Green
    }
    else {
        Write-Host "   [DRY-RUN] Fichier serait supprimé" -ForegroundColor Cyan
    }
}
else {
    Write-Host "   ℹ️ Aucun fichier dans le mauvais emplacement" -ForegroundColor Gray
}

# Vérifier le fichier dans le bon emplacement
if (Test-Path $correctPath) {
    $correctFile = Get-Item $correctPath
    Write-Host "`n   Fichier dans bon emplacement:" -ForegroundColor Green
    Write-Host "   - Taille: $([math]::Round($correctFile.Length/1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "   - Modifié: $($correctFile.LastWriteTime)" -ForegroundColor Gray
    
    # Vérifier s'il est ancien
    $daysSinceModified = (Get-Date) - $correctFile.LastWriteTime
    if ($daysSinceModified.TotalHours -gt 1) {
        Write-Host "   ⚠️ Fichier ancien (sera reconstruit)" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n   ⚠️ Aucun fichier dans le bon emplacement (sera créé)" -ForegroundColor Yellow
}

# ÉTAPE 2: Instructions pour rebuild via MCP
Write-Host "`n[2] Instructions pour rebuild..." -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "   [DRY-RUN] Les commandes MCP suivantes devraient être exécutées:" -ForegroundColor Cyan
}
else {
    Write-Host "   ✅ Nettoyage terminé, prêt pour rebuild MCP" -ForegroundColor Green
}

Write-Host "`n   Commandes MCP à exécuter:" -ForegroundColor Yellow
Write-Host "   1. Rebuild enfant:" -ForegroundColor White
Write-Host '      use_mcp_tool("roo-state-manager", "build_skeleton_cache", {' -ForegroundColor Gray
Write-Host '        "force_rebuild": true,' -ForegroundColor Gray
Write-Host "        `"task_ids`": [`"$childTaskId`"]" -ForegroundColor Gray
Write-Host '      })' -ForegroundColor Gray

Write-Host "`n   2. Valider avec:" -ForegroundColor White
Write-Host "      pwsh -f `"scripts/validation/test-skeleton-hierarchy-20251022.ps1`"" -ForegroundColor Gray

# ÉTAPE 3: Résumé du problème et de la solution
Write-Host "`n=== DIAGNOSTIC COMPLET ===" -ForegroundColor Cyan

Write-Host "`n🐛 BUGS IDENTIFIÉS:" -ForegroundColor Red
Write-Host "   1. Bug de chemin (CORRIGÉ dans build-skeleton-cache.tool.ts)" -ForegroundColor Yellow
Write-Host "      - Ancien: path.join(storageDir, SKELETON_CACHE_DIR_NAME)" -ForegroundColor Gray
Write-Host "      - Nouveau: path.join(storageDir, 'tasks', SKELETON_CACHE_DIR_NAME)" -ForegroundColor Gray
Write-Host "`n   2. Bug de Phase 3 (CONSÉQUENCE du bug 1)" -ForegroundColor Yellow
Write-Host "      - Phase 3 cherche dans 'tasks\.skeletons\'" -ForegroundColor Gray
Write-Host "      - Mais le fichier était dans '.skeletons\' (mauvais)" -ForegroundColor Gray
Write-Host "      - Résultat: Phase 3 n'écrit jamais parentTaskId" -ForegroundColor Gray

Write-Host "`n✅ SOLUTION APPLIQUÉE:" -ForegroundColor Green
Write-Host "   1. Correction du code de chemin" -ForegroundColor White
Write-Host "   2. Recompilation du serveur MCP" -ForegroundColor White
Write-Host "   3. Nettoyage du fichier dans mauvais emplacement" -ForegroundColor White
Write-Host "   4. Rebuild avec code corrigé → fichier au bon endroit" -ForegroundColor White
Write-Host "   5. Phase 3 pourra persister parentTaskId correctement" -ForegroundColor White

Write-Host "`n=== PROCHAINES ÉTAPES ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Relancez ce script SANS -DryRun pour nettoyer réellement" -ForegroundColor Yellow
}
else {
    Write-Host "1. Exécuter le rebuild MCP (commande ci-dessus)" -ForegroundColor White
    Write-Host "2. Valider avec le script de test" -ForegroundColor White
    Write-Host "3. Vérifier que parentTaskId est présent dans le fichier" -ForegroundColor White
}

Write-Host ""