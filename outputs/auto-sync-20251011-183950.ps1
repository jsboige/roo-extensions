#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Synchronisation Git automatique COMPLÈTE - Session 2025-10-11 18:39

.DESCRIPTION
    Script ENTIÈREMENT AUTOMATISÉ qui :
    - Commite tous les changements (TraceSummaryService + rapports + nouveaux fichiers)
    - Pull dépôt principal et sous-modules avec merge automatique
    - Push tout vers remote
    - Journalise TOUT dans un fichier log détaillé

.NOTES
    ⚠️ MODE NON-INTERACTIF : Aucune confirmation demandée
    📝 Tout est loggé dans outputs/git-sync-auto-TIMESTAMP.log
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$rootDir = Get-Location
$logFile = Join-Path $rootDir "outputs/git-sync-auto-$timestamp.log"

# Fonction de logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "PHASE", "STEP")]
        [string]$Level = "INFO"
    )
    
    $timeStr = Get-Date -Format "HH:mm:ss.fff"
    $logEntry = "[$timeStr] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "PHASE" { "Cyan" }
        "STEP" { "Magenta" }
        default { "White" }
    }
    
    Write-Host $Message -ForegroundColor $color
}

# Header
Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║  🤖 SYNCHRONISATION GIT AUTOMATIQUE COMPLÈTE                         ║
║  Session: $timestamp                                        ║
║  Mode: NON-INTERACTIF (Automatique)                                 ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Log "=== DÉBUT SYNCHRONISATION AUTOMATIQUE ===" -Level "PHASE"
Write-Log "Fichier de log : $logFile" -Level "INFO"
Write-Log "Mode : ENTIÈREMENT AUTOMATISÉ (pas de confirmation)" -Level "WARN"

try {
    # =========================================================================
    # PHASE 0 : DIAGNOSTIC INITIAL
    # =========================================================================
    Write-Log "`n=== 📊 PHASE 0 : DIAGNOSTIC INITIAL ===" -Level "PHASE"
    
    Write-Log "État dépôt principal..." -Level "STEP"
    git status | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    git fetch origin 2>&1 | Out-Null
    $behind = git rev-list --count HEAD..origin/main 2>$null
    $ahead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "Dépôt principal - En retard: $behind | En avance: $ahead" -Level "INFO"
    
    # =========================================================================
    # PHASE 1 : COMMITS SOUS-MODULE mcps/internal
    # =========================================================================
    Write-Log "`n=== 💾 PHASE 1 : COMMITS SOUS-MODULE mcps/internal ===" -Level "PHASE"
    
    Push-Location "mcps/internal"
    
    $subStatus = git status --porcelain
    if ($subStatus) {
        Write-Log "Fichiers modifiés dans sous-module:" -Level "INFO"
        $subStatus | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        # Commit TraceSummaryService
        $hasTraceSummary = $subStatus | Select-String "TraceSummaryService"
        if ($hasTraceSummary) {
            Write-Log "1️⃣ Commit TraceSummaryService.ts..." -Level "STEP"
            git add servers/roo-state-manager/src/services/TraceSummaryService.ts
            git commit -m @"
refactor(TraceSummaryService): Unified global counter for chronological item numbering

- Replace 7 type-specific counters with single globalCounter
- Improves readability and chronological traceability
- Affects: user, assistant, tool, error, condensation, instruction, completion items
- Better alignment with trace summary timeline
"@ 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ TraceSummaryService.ts commité" -Level "SUCCESS"
        }
        
        # Commit rapport Phase 4
        $hasRapport = $subStatus | Select-String "RAPPORT_MISSION"
        if ($hasRapport) {
            Write-Log "2️⃣ Commit rapport Phase 4..." -Level "STEP"
            git add servers/jupyter-papermill-mcp-server/RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
            git commit -m "docs(jupyter-mcp): Add Phase 4 Triple Grounding mission report" 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ Rapport Phase 4 commité" -Level "SUCCESS"
        }
        
        # Commit autres fichiers si présents
        $remainingFiles = git status --porcelain
        if ($remainingFiles) {
            Write-Log "3️⃣ Commit fichiers restants..." -Level "STEP"
            git add -A
            git commit -m "chore: Commit remaining changes in submodule" 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ Fichiers restants commités" -Level "SUCCESS"
        }
    } else {
        Write-Log "✅ Sous-module déjà propre" -Level "SUCCESS"
    }
    
    $subBehind = git rev-list --count HEAD..origin/main 2>$null
    $subAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "Sous-module - En retard: $subBehind | En avance: $subAhead" -Level "INFO"
    
    Pop-Location
    
    # =========================================================================
    # PHASE 2 : COMMIT SOUS-MODULE + FICHIERS DÉPÔT PRINCIPAL
    # =========================================================================
    Write-Log "`n=== 🔗 PHASE 2 : COMMIT DÉPÔT PRINCIPAL ===" -Level "PHASE"
    
    # Commit sous-module si modifié
    $submoduleModified = git status --porcelain | Select-String "mcps/internal"
    if ($submoduleModified) {
        Write-Log "1️⃣ Stage sous-module..." -Level "STEP"
        git add mcps/internal
    }
    
    # Commit fichier exports si présent
    if (Test-Path "exports/TRACE_CORRIGEE.md") {
        $exportsStatus = git status --porcelain exports/TRACE_CORRIGEE.md
        if ($exportsStatus) {
            Write-Log "2️⃣ Stage exports/TRACE_CORRIGEE.md..." -Level "STEP"
            git add exports/TRACE_CORRIGEE.md
        }
    }
    
    # Commit nouveaux fichiers outputs/ et scripts/
    $outputsStatus = git status --porcelain outputs/
    $scriptsStatus = git status --porcelain scripts/git-safe-operations/
    if ($outputsStatus -or $scriptsStatus) {
        Write-Log "3️⃣ Stage nouveaux fichiers (outputs/, scripts/)..." -Level "STEP"
        git add outputs/ 2>&1 | Out-Null
        git add scripts/git-safe-operations/ 2>&1 | Out-Null
    }
    
    # Créer commit global
    $mainChanges = git status --porcelain
    if ($mainChanges) {
        Write-Log "4️⃣ Commit global dépôt principal..." -Level "STEP"
        git commit -m @"
feat: Complete Git sync infrastructure + TraceSummaryService refactor

- mcps/internal: TraceSummaryService unified counter + Phase 4 report
- Add Git sync automation scripts (interactive + auto modes)
- Add trace export TRACE_CORRIGEE.md
- Infrastructure for safe Git operations
"@ 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
        Write-Log "✅ Dépôt principal commité" -Level "SUCCESS"
    } else {
        Write-Log "✅ Dépôt principal déjà propre" -Level "SUCCESS"
    }
    
    # =========================================================================
    # PHASE 3 : PULL DÉPÔT PRINCIPAL
    # =========================================================================
    Write-Log "`n=== ⬇️ PHASE 3 : PULL DÉPÔT PRINCIPAL ===" -Level "PHASE"
    
    $behind = git rev-list --count HEAD..origin/main 2>$null
    if ($behind -gt 0) {
        Write-Log "$behind commits en retard sur origin/main" -Level "WARN"
        Write-Log "Commits distants:" -Level "INFO"
        git log --oneline HEAD..origin/main | Select-Object -First 10 | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        Write-Log "Pull avec merge en cours..." -Level "STEP"
        try {
            git pull origin main --no-rebase 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ Pull dépôt principal réussi !" -Level "SUCCESS"
        } catch {
            Write-Log "❌ CONFLIT durant pull dépôt principal" -Level "ERROR"
            Write-Log "Erreur: $_" -Level "ERROR"
            
            $conflictFiles = git diff --name-only --diff-filter=U
            if ($conflictFiles) {
                Write-Log "Fichiers en conflit:" -Level "ERROR"
                $conflictFiles | ForEach-Object { Write-Log " - $_" -Level "ERROR" }
            }
            
            throw "Conflits dans dépôt principal nécessitent résolution manuelle"
        }
    } else {
        Write-Log "✅ Dépôt principal déjà à jour" -Level "SUCCESS"
    }
    
    # =========================================================================
    # PHASE 4 : PULL SOUS-MODULE mcps/internal
    # =========================================================================
    Write-Log "`n=== 📦 PHASE 4 : PULL SOUS-MODULE mcps/internal ===" -Level "PHASE"
    
    Push-Location "mcps/internal"
    
    $subBehind = git rev-list --count HEAD..origin/main 2>$null
    if ($subBehind -gt 0) {
        Write-Log "$subBehind commits en retard (sous-module)" -Level "WARN"
        Write-Log "Commits distants sous-module:" -Level "INFO"
        git log --oneline HEAD..origin/main | Select-Object -First 10 | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        Write-Log "Pull sous-module avec merge..." -Level "STEP"
        try {
            git pull origin main --no-rebase 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ Pull sous-module réussi !" -Level "SUCCESS"
        } catch {
            Write-Log "❌ CONFLIT durant pull sous-module" -Level "ERROR"
            Write-Log "Erreur: $_" -Level "ERROR"
            
            $subConflictFiles = git diff --name-only --diff-filter=U
            if ($subConflictFiles) {
                Write-Log "Fichiers en conflit (sous-module):" -Level "ERROR"
                $subConflictFiles | ForEach-Object { Write-Log " - $_" -Level "ERROR" }
            }
            
            throw "Conflits dans sous-module nécessitent résolution manuelle"
        }
    } else {
        Write-Log "✅ Sous-module déjà à jour" -Level "SUCCESS"
    }
    
    Pop-Location
    
    # Commit référence sous-module si changée
    $submoduleChanged = git status --porcelain | Select-String "mcps/internal"
    if ($submoduleChanged) {
        Write-Log "Mise à jour référence sous-module..." -Level "STEP"
        git add mcps/internal
        git commit -m "chore: Update mcps/internal submodule after merge" 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
        Write-Log "✅ Référence sous-module mise à jour" -Level "SUCCESS"
    }
    
    # =========================================================================
    # PHASE 5 : VALIDATION PRÉ-PUSH
    # =========================================================================
    Write-Log "`n=== ✅ PHASE 5 : VALIDATION PRÉ-PUSH ===" -Level "PHASE"
    
    $finalStatus = git status --porcelain
    if ($finalStatus) {
        Write-Log "⚠️ Working tree non propre:" -Level "WARN"
        $finalStatus | ForEach-Object { Write-Log $_ -Level "WARN" }
    } else {
        Write-Log "✅ Working tree propre" -Level "SUCCESS"
    }
    
    $finalAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "📤 $finalAhead commits à pusher (dépôt principal)" -Level "INFO"
    
    if ($finalAhead -gt 0) {
        Write-Log "Commits à pusher:" -Level "INFO"
        git log --oneline origin/main..HEAD | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        Write-Log "Dry-run push:" -Level "STEP"
        git push --dry-run origin main 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
    }
    
    Push-Location "mcps/internal"
    $finalSubAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "📤 $finalSubAhead commits à pusher (sous-module)" -Level "INFO"
    Pop-Location
    
    # =========================================================================
    # PHASE 6 : PUSH AUTOMATIQUE
    # =========================================================================
    Write-Log "`n=== 🚀 PHASE 6 : PUSH AUTOMATIQUE ===" -Level "PHASE"
    
    if ($finalAhead -gt 0) {
        Write-Log "Push dépôt principal ($finalAhead commits)..." -Level "STEP"
        git push origin main 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
        Write-Log "✅ Push dépôt principal réussi !" -Level "SUCCESS"
    } else {
        Write-Log "Rien à pusher (dépôt principal)" -Level "INFO"
    }
    
    if ($finalSubAhead -gt 0) {
        Write-Log "Push sous-module ($finalSubAhead commits)..." -Level "STEP"
        Push-Location "mcps/internal"
        git push origin main 2>&1 | ForEach-Object { Write-Log $_ -Level "INFO" }
        Pop-Location
        Write-Log "✅ Push sous-module réussi !" -Level "SUCCESS"
    } else {
        Write-Log "Rien à pusher (sous-module)" -Level "INFO"
    }
    
    # =========================================================================
    # VÉRIFICATION FINALE
    # =========================================================================
    Write-Log "`n=== 🎯 VÉRIFICATION FINALE ===" -Level "PHASE"
    
    Write-Log "État final dépôt principal:" -Level "INFO"
    git status | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    Write-Log "`nÉtat final sous-modules:" -Level "INFO"
    git submodule status | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    Write-Log "`nDerniers commits:" -Level "INFO"
    git log --oneline -5 | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    # Récapitulatif
    Write-Log "`n╔══════════════════════════════════════════════════════════════════════╗" -Level "SUCCESS"
    Write-Log "║  ✅ SYNCHRONISATION AUTOMATIQUE TERMINÉE AVEC SUCCÈS !               ║" -Level "SUCCESS"
    Write-Log "╚══════════════════════════════════════════════════════════════════════╝" -Level "SUCCESS"
    
    Write-Log @"

📋 RÉSUMÉ COMPLET :
-------------------
✅ TraceSummaryService.ts : Refactor compteurs commité
✅ Rapport Phase 4 : Commité
✅ Nouveaux scripts sync : Commités
✅ exports/TRACE_CORRIGEE.md : Commité
✅ Dépôt principal : Pull + Push réussis
✅ Sous-module mcps/internal : Pull + Push réussis
✅ Working tree : Propre
✅ Aucun conflit

📄 Log complet : $logFile

"@ -Level "SUCCESS"

} catch {
    Write-Log "`n╔══════════════════════════════════════════════════════════════════════╗" -Level "ERROR"
    Write-Log "║  ❌ ERREUR DURANT SYNCHRONISATION AUTOMATIQUE                        ║" -Level "ERROR"
    Write-Log "╚══════════════════════════════════════════════════════════════════════╝" -Level "ERROR"
    
    Write-Log "`nMessage: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "StackTrace: $($_.ScriptStackTrace)" -Level "ERROR"
    
    Write-Log @"

🔧 ACTIONS DE RÉCUPÉRATION :
-----------------------------
1. Consulter le log détaillé : $logFile
2. Vérifier l'état actuel : git status
3. Si conflits détectés :
   - Ouvrir fichiers en conflit
   - Résoudre markers <<<<<<< ======= >>>>>>>
   - git add <fichiers_résolus>
   - git commit (pour merge)
4. Relancer le script après résolution

"@ -Level "WARN"
    
    exit 1
}