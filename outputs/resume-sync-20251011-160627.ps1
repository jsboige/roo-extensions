#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reprise synchronisation Git après coupure - Session 2025-10-11 16:06

.DESCRIPTION
    Script de reprise complet qui :
    1. Vérifie l'état actuel (où nous en sommes)
    2. Identifie les étapes complétées
    3. Continue les étapes restantes
    4. Journalise tout dans un fichier log

.NOTES
    Session initiale : 2025-10-11 15:12:48
    Reprise : 2025-10-11 16:06:27
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$rootDir = Get-Location
$logFile = Join-Path $rootDir "outputs/git-sync-resume-$timestamp.log"

# Fonction de logging améliorée
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "PHASE", "STEP")]
        [string]$Level = "INFO"
    )
    
    $timeStr = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timeStr] [$Level] $Message"
    
    # Écrire dans le fichier log
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    # Affichage console avec couleurs
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

# Fonction de confirmation avec logging
function Confirm-Step {
    param([string]$Question)
    Write-Log "QUESTION: $Question" -Level "WARN"
    $response = Read-Host $Question
    Write-Log "RÉPONSE: $response" -Level "INFO"
    return $response -eq 'o'
}

# Header
Write-Host @"
╔══════════════════════════════════════════════════════════════════════╗
║  🔄 REPRISE SYNCHRONISATION GIT                                      ║
║  Session: $timestamp                                        ║
║  Log: $logFile                                    ║
╚══════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Log "=== DÉBUT REPRISE SYNCHRONISATION ===" -Level "PHASE"
Write-Log "Fichier de log : $logFile" -Level "INFO"

try {
    # =========================================================================
    # ÉTAPE 0 : DIAGNOSTIC ÉTAT ACTUEL
    # =========================================================================
    Write-Log "`n=== 📊 ÉTAPE 0 : DIAGNOSTIC ÉTAT ACTUEL ===" -Level "PHASE"
    
    Write-Log "Vérification dépôt principal..." -Level "STEP"
    $mainStatus = git status --porcelain
    $mainStatusFull = git status
    Write-Log "État dépôt principal:" -Level "INFO"
    Write-Log $mainStatusFull -Level "INFO"
    
    Write-Log "`nVérification derniers commits..." -Level "STEP"
    $lastCommits = git log --oneline -5
    Write-Log "Derniers commits:" -Level "INFO"
    $lastCommits | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    Write-Log "`nComparaison avec remote..." -Level "STEP"
    git fetch origin 2>&1 | Out-Null
    $behind = git rev-list --count HEAD..origin/main 2>$null
    $ahead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "Commits en retard (remote → local): $behind" -Level "WARN"
    Write-Log "Commits en avance (local → remote): $ahead" -Level "INFO"
    
    Write-Log "`nVérification sous-module mcps/internal..." -Level "STEP"
    Push-Location "mcps/internal"
    $subStatus = git status --porcelain
    $subStatusFull = git status
    Write-Log "État sous-module:" -Level "INFO"
    Write-Log $subStatusFull -Level "INFO"
    
    $subLastCommits = git log --oneline -5
    Write-Log "`nDerniers commits sous-module:" -Level "INFO"
    $subLastCommits | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    $subBehind = git rev-list --count HEAD..origin/main 2>$null
    $subAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "Sous-module - En retard: $subBehind | En avance: $subAhead" -Level "INFO"
    Pop-Location
    
    # Analyse de ce qui reste à faire
    Write-Log "`n=== 🎯 ANALYSE ÉTAPES RESTANTES ===" -Level "PHASE"
    
    $needsSubmoduleCommit = $subStatus.Count -gt 0
    $needsMainCommit = $mainStatus.Count -gt 0
    $needsMainPull = $behind -gt 0
    $needsSubPull = $subBehind -gt 0
    $needsMainPush = $ahead -gt 0
    $needsSubPush = $subAhead -gt 0
    
    Write-Log "☐ Commits sous-module mcps/internal : $(if ($needsSubmoduleCommit) { 'OUI (fichiers modifiés)' } else { 'NON (déjà fait)' })" -Level $(if ($needsSubmoduleCommit) { "WARN" } else { "SUCCESS" })
    Write-Log "☐ Commits dépôt principal : $(if ($needsMainCommit) { 'OUI (fichiers modifiés)' } else { 'NON (déjà fait)' })" -Level $(if ($needsMainCommit) { "WARN" } else { "SUCCESS" })
    Write-Log "☐ Pull dépôt principal : $(if ($needsMainPull) { "OUI ($behind commits en retard)" } else { 'NON (à jour)' })" -Level $(if ($needsMainPull) { "WARN" } else { "SUCCESS" })
    Write-Log "☐ Pull sous-module : $(if ($needsSubPull) { "OUI ($subBehind commits en retard)" } else { 'NON (à jour)' })" -Level $(if ($needsSubPull) { "WARN" } else { "SUCCESS" })
    Write-Log "☐ Push dépôt principal : $(if ($needsMainPush) { "OUI ($ahead commits)" } else { 'NON (déjà pushé)' })" -Level $(if ($needsMainPush) { "WARN" } else { "SUCCESS" })
    Write-Log "☐ Push sous-module : $(if ($needsSubPush) { "OUI ($subAhead commits)" } else { 'NON (déjà pushé)' })" -Level $(if ($needsSubPush) { "WARN" } else { "SUCCESS" })
    
    if (-not (Confirm-Step "`n⚠️ Continuer la synchronisation ?")) {
        Write-Log "Synchronisation annulée par l'utilisateur" -Level "WARN"
        exit 0
    }
    
    # =========================================================================
    # ÉTAPE 1 : COMMITS SOUS-MODULE (si nécessaire)
    # =========================================================================
    if ($needsSubmoduleCommit) {
        Write-Log "`n=== 💾 ÉTAPE 1 : COMMITS SOUS-MODULE mcps/internal ===" -Level "PHASE"
        
        Push-Location "mcps/internal"
        
        Write-Log "Fichiers modifiés dans sous-module:" -Level "INFO"
        git status --short | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        # Identifier les fichiers TraceSummaryService
        $hasTraceSummary = git status --short | Select-String "TraceSummaryService"
        $hasRapport = git status --short | Select-String "RAPPORT_MISSION"
        
        if ($hasTraceSummary) {
            Write-Log "`n1️⃣ Commit TraceSummaryService.ts" -Level "STEP"
            git add servers/roo-state-manager/src/services/TraceSummaryService.ts
            git commit -m @"
refactor(TraceSummaryService): Unified global counter for chronological item numbering

- Replace 7 type-specific counters with single globalCounter
- Improves readability and chronological traceability
- Affects: user, assistant, tool, error, condensation, instruction, completion items
- Better alignment with trace summary timeline
"@
            Write-Log "✅ TraceSummaryService.ts commité" -Level "SUCCESS"
        }
        
        if ($hasRapport) {
            Write-Log "`n2️⃣ Commit rapport Phase 4" -Level "STEP"
            git add servers/jupyter-papermill-mcp-server/RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
            git commit -m "docs(jupyter-mcp): Add Phase 4 Triple Grounding mission report"
            Write-Log "✅ Rapport Phase 4 commité" -Level "SUCCESS"
        }
        
        # S'il reste d'autres fichiers modifiés
        $remainingFiles = git status --porcelain
        if ($remainingFiles) {
            Write-Log "`n⚠️ Autres fichiers modifiés détectés:" -Level "WARN"
            git status --short | ForEach-Object { Write-Log $_ -Level "INFO" }
            
            if (Confirm-Step "Commiter tous les fichiers restants ?") {
                $commitMsg = Read-Host "Message de commit"
                git add -A
                git commit -m $commitMsg
                Write-Log "✅ Fichiers restants commités" -Level "SUCCESS"
            }
        }
        
        Pop-Location
    } else {
        Write-Log "`n=== ✅ ÉTAPE 1 : COMMITS SOUS-MODULE ===" -Level "PHASE"
        Write-Log "Sous-module déjà propre, passage à l'étape suivante" -Level "SUCCESS"
    }
    
    # =========================================================================
    # ÉTAPE 2 : COMMIT SOUS-MODULE DANS DÉPÔT PRINCIPAL
    # =========================================================================
    Write-Log "`n=== 🔗 ÉTAPE 2 : COMMIT SOUS-MODULE DANS DÉPÔT PRINCIPAL ===" -Level "PHASE"
    
    $submoduleModified = git status --porcelain | Select-String "mcps/internal"
    if ($submoduleModified) {
        Write-Log "Sous-module modifié, commit nécessaire" -Level "WARN"
        git add mcps/internal
        git commit -m @"
feat(mcps/internal): Update submodule with TraceSummaryService refactor

- TraceSummaryService: Unified global counter system
- Added Phase 4 Triple Grounding mission report
"@
        Write-Log "✅ Sous-module commité dans dépôt principal" -Level "SUCCESS"
    } else {
        Write-Log "Sous-module déjà à jour dans dépôt principal" -Level "SUCCESS"
    }
    
    # =========================================================================
    # ÉTAPE 3 : COMMIT FICHIERS EXPORTS (si nécessaire)
    # =========================================================================
    Write-Log "`n=== 📄 ÉTAPE 3 : COMMIT FICHIERS EXPORTS ===" -Level "PHASE"
    
    $exportsFile = "exports/TRACE_CORRIGEE.md"
    if ((Test-Path $exportsFile) -and (git status --porcelain $exportsFile)) {
        Write-Log "Fichier $exportsFile non tracké" -Level "WARN"
        if (Confirm-Step "Commiter $exportsFile ?") {
            git add $exportsFile
            git commit -m "docs: Add corrected trace export"
            Write-Log "✅ $exportsFile commité" -Level "SUCCESS"
        }
    } else {
        Write-Log "Pas de fichier exports/ à commiter" -Level "SUCCESS"
    }
    
    # =========================================================================
    # ÉTAPE 4 : PULL DÉPÔT PRINCIPAL
    # =========================================================================
    if ($needsMainPull) {
        Write-Log "`n=== ⬇️ ÉTAPE 4 : PULL DÉPÔT PRINCIPAL ===" -Level "PHASE"
        
        Write-Log "$behind commits en retard sur origin/main" -Level "WARN"
        Write-Log "`n📜 Commits distants à intégrer:" -Level "INFO"
        git log --oneline HEAD..origin/main | Select-Object -First 20 | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        if (Confirm-Step "`nPuller avec stratégie merge ?") {
            Write-Log "Début pull avec merge..." -Level "STEP"
            try {
                $pullOutput = git pull origin main --no-rebase 2>&1
                $pullOutput | ForEach-Object { Write-Log $_ -Level "INFO" }
                Write-Log "✅ Pull réussi !" -Level "SUCCESS"
            } catch {
                Write-Log "❌ CONFLIT DÉTECTÉ durant le pull !" -Level "ERROR"
                Write-Log "Message d'erreur: $_" -Level "ERROR"
                
                $conflictFiles = git diff --name-only --diff-filter=U
                Write-Log "`nFichiers en conflit:" -Level "ERROR"
                $conflictFiles | ForEach-Object { Write-Log " - $_" -Level "ERROR" }
                
                Write-Log @"

🛠️ RÉSOLUTION MANUELLE REQUISE :
---------------------------------
1. Ouvrir chaque fichier en conflit
2. Chercher les markers <<<<<<< ======= >>>>>>>
3. Résoudre manuellement les conflits
4. git add <fichiers_résolus>
5. git commit (pour finaliser le merge)

Après résolution, relancer ce script pour continuer.
"@ -Level "WARN"
                throw "Conflits nécessitent résolution manuelle"
            }
        } else {
            Write-Log "Pull ignoré - à effectuer manuellement plus tard" -Level "WARN"
        }
    } else {
        Write-Log "`n=== ✅ ÉTAPE 4 : PULL DÉPÔT PRINCIPAL ===" -Level "PHASE"
        Write-Log "Dépôt principal déjà à jour" -Level "SUCCESS"
    }
    
    # =========================================================================
    # ÉTAPE 5 : PULL SOUS-MODULE mcps/internal
    # =========================================================================
    if ($needsSubPull) {
        Write-Log "`n=== 📦 ÉTAPE 5 : PULL SOUS-MODULE mcps/internal ===" -Level "PHASE"
        
        Push-Location "mcps/internal"
        
        Write-Log "$subBehind commits en retard sur origin/main (sous-module)" -Level "WARN"
        Write-Log "`n📜 Commits distants sous-module:" -Level "INFO"
        git log --oneline HEAD..origin/main | Select-Object -First 10 | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        if (Confirm-Step "`nPuller sous-module avec merge ?") {
            Write-Log "Début pull sous-module..." -Level "STEP"
            try {
                $subPullOutput = git pull origin main --no-rebase 2>&1
                $subPullOutput | ForEach-Object { Write-Log $_ -Level "INFO" }
                Write-Log "✅ Pull sous-module réussi !" -Level "SUCCESS"
            } catch {
                Write-Log "❌ CONFLIT dans sous-module !" -Level "ERROR"
                Write-Log "Message d'erreur: $_" -Level "ERROR"
                
                $subConflictFiles = git diff --name-only --diff-filter=U
                Write-Log "`nFichiers en conflit (sous-module):" -Level "ERROR"
                $subConflictFiles | ForEach-Object { Write-Log " - $_" -Level "ERROR" }
                
                Write-Log "Résolution manuelle requise dans mcps/internal/" -Level "WARN"
                throw "Conflits sous-module nécessitent résolution manuelle"
            }
        }
        
        Pop-Location
        
        # Vérifier si sous-module a changé après pull
        $submoduleChanged = git status --porcelain | Select-String "mcps/internal"
        if ($submoduleChanged) {
            Write-Log "`nMise à jour référence sous-module dans dépôt principal" -Level "STEP"
            git add mcps/internal
            git commit -m "chore: Update mcps/internal submodule after merge"
            Write-Log "✅ Référence sous-module mise à jour" -Level "SUCCESS"
        }
    } else {
        Write-Log "`n=== ✅ ÉTAPE 5 : PULL SOUS-MODULE ===" -Level "PHASE"
        Write-Log "Sous-module déjà à jour" -Level "SUCCESS"
    }
    
    # =========================================================================
    # ÉTAPE 6 : VALIDATION PRÉ-PUSH
    # =========================================================================
    Write-Log "`n=== ✅ ÉTAPE 6 : VALIDATION PRÉ-PUSH ===" -Level "PHASE"
    
    Write-Log "Vérification finale de l'état..." -Level "STEP"
    
    $finalMainStatus = git status --porcelain
    if ($finalMainStatus) {
        Write-Log "⚠️ Working tree non propre:" -Level "WARN"
        $finalMainStatus | ForEach-Object { Write-Log $_ -Level "WARN" }
    } else {
        Write-Log "✅ Working tree propre" -Level "SUCCESS"
    }
    
    $finalAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "`n📤 $finalAhead commits à pusher (dépôt principal)" -Level "INFO"
    
    if ($finalAhead -gt 0) {
        Write-Log "`n📜 Commits à pusher:" -Level "INFO"
        git log --oneline origin/main..HEAD | ForEach-Object { Write-Log $_ -Level "INFO" }
        
        Write-Log "`n🔍 Dry-run push:" -Level "STEP"
        $dryRunOutput = git push --dry-run origin main 2>&1
        $dryRunOutput | ForEach-Object { Write-Log $_ -Level "INFO" }
    }
    
    Push-Location "mcps/internal"
    $finalSubAhead = git rev-list --count origin/main..HEAD 2>$null
    Write-Log "`n📤 $finalSubAhead commits à pusher (sous-module)" -Level "INFO"
    Pop-Location
    
    # =========================================================================
    # ÉTAPE 7 : PUSH FINAL
    # =========================================================================
    Write-Log "`n=== 🚀 ÉTAPE 7 : PUSH FINAL ===" -Level "PHASE"
    
    if ($finalAhead -gt 0) {
        if (Confirm-Step "`n🚀 Pusher $finalAhead commits vers origin/main (dépôt principal) ?") {
            Write-Log "Push dépôt principal en cours..." -Level "STEP"
            $pushOutput = git push origin main 2>&1
            $pushOutput | ForEach-Object { Write-Log $_ -Level "INFO" }
            Write-Log "✅ Push dépôt principal réussi !" -Level "SUCCESS"
        } else {
            Write-Log "Push dépôt principal ignoré" -Level "WARN"
        }
    } else {
        Write-Log "Rien à pusher pour le dépôt principal" -Level "SUCCESS"
    }
    
    if ($finalSubAhead -gt 0) {
        if (Confirm-Step "`nPusher $finalSubAhead commits vers origin/main (sous-module) ?") {
            Write-Log "Push sous-module en cours..." -Level "STEP"
            Push-Location "mcps/internal"
            $subPushOutput = git push origin main 2>&1
            $subPushOutput | ForEach-Object { Write-Log $_ -Level "INFO" }
            Pop-Location
            Write-Log "✅ Push sous-module réussi !" -Level "SUCCESS"
        } else {
            Write-Log "Push sous-module ignoré" -Level "WARN"
        }
    } else {
        Write-Log "Rien à pusher pour le sous-module" -Level "SUCCESS"
    }
    
    # =========================================================================
    # VÉRIFICATION FINALE
    # =========================================================================
    Write-Log "`n=== 🎯 VÉRIFICATION FINALE ===" -Level "PHASE"
    
    Write-Log "`n📊 État final dépôt principal:" -Level "INFO"
    $finalStatus = git status
    $finalStatus | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    Write-Log "`n📦 État final sous-modules:" -Level "INFO"
    $submoduleStatus = git submodule status
    $submoduleStatus | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    Write-Log "`n📜 Derniers commits:" -Level "INFO"
    git log --oneline -5 | ForEach-Object { Write-Log $_ -Level "INFO" }
    
    # Récapitulatif final
    Write-Log "`n=== ✅ SYNCHRONISATION TERMINÉE AVEC SUCCÈS ! ===" -Level "SUCCESS"
    Write-Log @"

📋 RÉSUMÉ COMPLET :
-------------------
✅ Tous les commits effectués
✅ Pulls synchronisés (dépôt principal + sous-modules)
✅ Pushs effectués
✅ Working tree propre
✅ Aucun conflit non résolu

📄 Log complet : $logFile
"@ -Level "SUCCESS"

} catch {
    Write-Log "`n❌ ERREUR DURANT SYNCHRONISATION" -Level "ERROR"
    Write-Log "Message: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "StackTrace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Log "`n📄 Log disponible : $logFile" -Level "ERROR"
    
    Write-Log @"

🔧 ACTIONS DE RÉCUPÉRATION :
-----------------------------
1. Consulter le log : $logFile
2. Vérifier l'état : git status
3. Si conflits : résoudre manuellement puis :
   - git add <fichiers_résolus>
   - git commit (pour merge) OU git rebase --continue (pour rebase)
4. Relancer ce script après résolution

"@ -Level "WARN"
    exit 1
}