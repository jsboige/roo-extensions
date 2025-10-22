# Investigation du bug de persistence Phase 3
# Le rebuild rapporte un succès mais ne modifie pas le fichier
# Date: 2025-10-22

$ErrorActionPreference = "Stop"

Write-Host "`n=== INVESTIGATION BUG PHASE 3 ===" -ForegroundColor Cyan
Write-Host "Problème: build_skeleton_cache rapporte succès mais ne persiste pas parentTaskId`n" -ForegroundColor Yellow

# 1. Recherche du code de Phase 3 (persistence)
Write-Host "[1] Recherche du code de Phase 3..." -ForegroundColor Yellow

$sourceFile = "mcps\internal\servers\roo-state-manager\src\tools\cache\build-skeleton-cache.tool.ts"

if (Test-Path $sourceFile) {
    $content = Get-Content $sourceFile -Raw -Encoding UTF8
    
    # Recherche des patterns de persistence
    Write-Host "`n--- Patterns de persistence trouvés ---" -ForegroundColor Cyan
    
    # Pattern 1: Écriture de parentTaskId
    if ($content -match "parentTaskId\s*[:=]") {
        Write-Host "✅ Code assignant parentTaskId trouvé" -ForegroundColor Green
    }
    else {
        Write-Host "❌ AUCUNE assignation de parentTaskId trouvée" -ForegroundColor Red
    }
    
    # Pattern 2: Sauvegarde du squelette
    if ($content -match "writeFile.*skeleton|fs\.writeFile.*skeleton") {
        Write-Host "✅ Code de sauvegarde fs.writeFile trouvé" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Aucun fs.writeFile explicite pour skeleton" -ForegroundColor Yellow
    }
    
    # Pattern 3: Mise à jour du squelette existant
    if ($content -match "Object\.assign.*skeleton|skeleton\s*=\s*\{.*skeleton") {
        Write-Host "✅ Code de mise à jour de skeleton trouvé" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Aucune mise à jour de skeleton existant" -ForegroundColor Yellow
    }
    
    # Extraction des sections pertinentes
    Write-Host "`n--- Extraction du code Phase 3 ---" -ForegroundColor Cyan
    
    # Ligne où parentTaskId devrait être assigné
    $lines = $content -split "`n"
    $phase3Lines = @()
    $inPhase3 = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Détection de Phase 3
        if ($line -match "Phase 3.*parent matching|parent matching|parentTaskId") {
            $inPhase3 = $true
        }
        
        if ($inPhase3) {
            $phase3Lines += "$($i + 1): $line"
            
            # Fin de Phase 3 (heuristique)
            if ($line -match "^\s*\}.*phase.*3|^\s*console\.log.*Phase 3 complete") {
                $inPhase3 = $false
            }
        }
    }
    
    if ($phase3Lines.Count -gt 0) {
        Write-Host "Lignes de code Phase 3 trouvées:" -ForegroundColor Green
        $phase3Lines | Select-Object -First 50 | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        
        if ($phase3Lines.Count -gt 50) {
            Write-Host "... ($($phase3Lines.Count - 50) lignes supplémentaires)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "❌ Aucune section Phase 3 identifiable" -ForegroundColor Red
    }
    
    # 2. Vérification des logs du serveur
    Write-Host "`n[2] Recherche des logs MCP récents..." -ForegroundColor Yellow
    
    $vscodeLogDir = "$env:APPDATA\Code\logs"
    if (Test-Path $vscodeLogDir) {
        $latestLog = Get-ChildItem $vscodeLogDir -Directory | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($latestLog) {
            Write-Host "Répertoire de logs le plus récent: $($latestLog.Name)" -ForegroundColor Cyan
            
            $extHostLog = Join-Path $latestLog.FullName "exthost\output_logging_*\*-Roo*.log"
            $logFiles = Get-ChildItem $extHostLog -ErrorAction SilentlyContinue
            
            if ($logFiles) {
                Write-Host "Fichiers de log Roo trouvés: $($logFiles.Count)" -ForegroundColor Green
                
                # Recherche des erreurs Phase 3
                foreach ($logFile in $logFiles | Select-Object -First 1) {
                    Write-Host "`nAnalyse de: $($logFile.Name)" -ForegroundColor Cyan
                    $logContent = Get-Content $logFile.FullName -Tail 200 -ErrorAction SilentlyContinue
                    
                    $phase3Logs = $logContent | Where-Object { $_ -match "Phase 3|parentTaskId|hierarchy.*found" }
                    
                    if ($phase3Logs) {
                        Write-Host "Logs Phase 3 récents:" -ForegroundColor Yellow
                        $phase3Logs | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
                    }
                    else {
                        Write-Host "Aucun log Phase 3 trouvé dans les 200 dernières lignes" -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Host "⚠️ Aucun fichier de log Roo trouvé" -ForegroundColor Yellow
            }
        }
    }
}
else {
    Write-Host "❌ Fichier source introuvable: $sourceFile" -ForegroundColor Red
    exit 1
}

# 3. Hypothèses sur le bug
Write-Host "`n=== HYPOTHÈSES SUR LE BUG ===" -ForegroundColor Cyan
Write-Host "1. Phase 3 détecte le parent (log 'hierarchy relations found: 1')" -ForegroundColor Yellow
Write-Host "2. Mais ne PERSISTE pas le parentTaskId dans le fichier" -ForegroundColor Yellow
Write-Host "`nCauses possibles:" -ForegroundColor Yellow
Write-Host "   A. Le code assigne parentTaskId à un objet temporaire non sauvegardé" -ForegroundColor Gray
Write-Host "   B. Le fs.writeFile n'est jamais appelé après l'assignation" -ForegroundColor Gray
Write-Host "   C. Le squelette est rechargé depuis le disque après l'assignation" -ForegroundColor Gray
Write-Host "   D. Une condition empêche la sauvegarde (ex: !isDirty flag)" -ForegroundColor Gray

Write-Host "`n=== PROCHAINES ÉTAPES ===" -ForegroundColor Cyan
Write-Host "1. Lire le code complet de Phase 3 avec read_file" -ForegroundColor White
Write-Host "2. Identifier où parentTaskId devrait être persisté" -ForegroundColor White
Write-Host "3. Ajouter un fs.writeFile explicite si manquant" -ForegroundColor White
Write-Host "4. Recompiler et relancer le test" -ForegroundColor White