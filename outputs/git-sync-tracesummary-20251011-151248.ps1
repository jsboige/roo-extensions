#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de suivi - Synchronisation Git TraceSummaryService + sous-modules
    Session: 2025-10-11 15:12

.DESCRIPTION
    Tâche spécifique :
    - Commit TraceSummaryService.ts (refactor compteurs globaux)
    - Commit RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
    - Pull dépôt principal (17 commits en retard)
    - Pull sous-module mcps/internal (divergence 11 local / 8 remote)
    - Push synchronisation complète

.NOTES
    État initial :
    - Dépôt principal : 17 commits en retard, 0 en avance
    - mcps/internal : Divergence (11 local, 8 remote)
    - 1 fichier modifié : TraceSummaryService.ts
    - 1 fichier non tracké : RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
    - 1 fichier exports/ : TRACE_CORRIGEE.md
#>

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════════════════════════════════════════╗
║  🎯 SYNCHRONISATION GIT - TraceSummaryService + Sous-Modules               ║
║  Session: 2025-10-11 15:12:48                                              ║
╚════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Contexte de la tâche
Write-Host @"

📋 CONTEXTE TÂCHE :
------------------
✅ Changement principal : TraceSummaryService.ts
   → Refactor : 7 compteurs séparés → 1 compteur global unifié
   → Améliore traçabilité chronologique des items
   
📦 Sous-module mcps/internal :
   → Divergence Git : 11 commits locaux vs 8 commits distants
   → Nécessite merge avec gestion des conflits potentiels
   
📊 État initial :
   → Dépôt principal : 17 commits en retard
   → 2 fichiers à commiter dans mcps/internal
   → 1 fichier non tracké dans exports/

"@ -ForegroundColor Yellow

# Confirmation
$proceed = Read-Host "Lancer la synchronisation complète ? (o/N)"
if ($proceed -ne 'o') {
    Write-Host "❌ Synchronisation annulée" -ForegroundColor Red
    exit 0
}

try {
    # =============================================================================
    # PHASE 1 : COMMITS SOUS-MODULE mcps/internal
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  📦 PHASE 1 : COMMITS SOUS-MODULE mcps/internal                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Push-Location "mcps/internal"
    
    Write-Host "`n1️⃣ Stage TraceSummaryService.ts..." -ForegroundColor Yellow
    git add servers/roo-state-manager/src/services/TraceSummaryService.ts
    
    Write-Host "2️⃣ Commit refactor compteurs..." -ForegroundColor Yellow
    git commit -m @"
refactor(TraceSummaryService): Unified global counter for chronological item numbering

- Replace 7 type-specific counters with single globalCounter
- Improves readability and chronological traceability
- Affects: user, assistant, tool, error, condensation, instruction, completion items
- Better alignment with trace summary timeline
"@
    
    Write-Host "3️⃣ Stage rapport Phase 4..." -ForegroundColor Yellow
    git add servers/jupyter-papermill-mcp-server/RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
    
    Write-Host "4️⃣ Commit rapport..." -ForegroundColor Yellow
    git commit -m "docs(jupyter-mcp): Add Phase 4 Triple Grounding mission report"
    
    Write-Host "`n✅ Commits créés dans sous-module mcps/internal" -ForegroundColor Green
    git log --oneline -3
    
    Pop-Location
    
    # =============================================================================
    # PHASE 2 : COMMIT FICHIER EXPORTS (Dépôt Principal)
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  📄 PHASE 2 : COMMIT FICHIER EXPORTS (Dépôt Principal)         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    if (Test-Path "exports/TRACE_CORRIGEE.md") {
        Write-Host "`n1️⃣ Stage exports/TRACE_CORRIGEE.md..." -ForegroundColor Yellow
        git add exports/TRACE_CORRIGEE.md
        
        Write-Host "2️⃣ Commit..." -ForegroundColor Yellow
        git commit -m "docs: Add corrected trace export"
        
        Write-Host "`n✅ Fichier exports commité" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Fichier exports/TRACE_CORRIGEE.md introuvable (déjà commité ?)" -ForegroundColor Gray
    }
    
    # =============================================================================
    # PHASE 3 : COMMIT SOUS-MODULE DANS DÉPÔT PRINCIPAL
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🔗 PHASE 3 : COMMIT SOUS-MODULE DANS DÉPÔT PRINCIPAL          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "`n1️⃣ Stage sous-module mcps/internal..." -ForegroundColor Yellow
    git add mcps/internal
    
    Write-Host "2️⃣ Commit..." -ForegroundColor Yellow
    git commit -m @"
feat(mcps/internal): Update submodule with TraceSummaryService refactor

- TraceSummaryService: Unified global counter system
- Added Phase 4 Triple Grounding mission report
"@
    
    Write-Host "`n✅ Sous-module commité dans dépôt principal" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 4 : PULL DÉPÔT PRINCIPAL (17 commits)
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  ⬇️ PHASE 4 : PULL DÉPÔT PRINCIPAL (17 commits en retard)      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "`n📜 Commits distants à intégrer :" -ForegroundColor Yellow
    git log --oneline HEAD..origin/main | Select-Object -First 17
    
    $pullConfirm = Read-Host "`nPuller avec stratégie merge ? (o/N)"
    if ($pullConfirm -eq 'o') {
        Write-Host "`n1️⃣ Pull avec merge..." -ForegroundColor Yellow
        try {
            git pull origin main --no-rebase
            Write-Host "`n✅ Pull réussi !" -ForegroundColor Green
        } catch {
            Write-Host "`n❌ CONFLIT DÉTECTÉ !" -ForegroundColor Red
            Write-Host @"

🛠️ RÉSOLUTION MANUELLE REQUISE :
--------------------------------
1. Vérifier fichiers en conflit : git status
2. Ouvrir fichiers et chercher <<<<<<< ======= >>>>>>>
3. Résoudre manuellement les conflits
4. git add <fichiers_résolus>
5. git commit (pour finaliser le merge)

Ensuite, relancer ce script pour continuer.
"@ -ForegroundColor Yellow
            throw
        }
    } else {
        Write-Host "⚠️ Pull ignoré - à effectuer manuellement" -ForegroundColor Yellow
    }
    
    # =============================================================================
    # PHASE 5 : PULL SOUS-MODULE mcps/internal (Divergence)
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  📦 PHASE 5 : PULL SOUS-MODULE mcps/internal (Divergence)      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Push-Location "mcps/internal"
    
    Write-Host "`n⚠️ Divergence Git : 11 commits locaux vs 8 distants" -ForegroundColor Yellow
    Write-Host "📜 Commits distants :" -ForegroundColor Yellow
    git log --oneline HEAD..origin/main | Select-Object -First 8
    
    $subPullConfirm = Read-Host "`nPuller sous-module avec merge ? (o/N)"
    if ($subPullConfirm -eq 'o') {
        Write-Host "`n1️⃣ Pull sous-module..." -ForegroundColor Yellow
        try {
            git pull origin main --no-rebase
            Write-Host "`n✅ Pull sous-module réussi !" -ForegroundColor Green
        } catch {
            Write-Host "`n❌ CONFLIT DANS SOUS-MODULE !" -ForegroundColor Red
            Write-Host "Résolution manuelle requise dans mcps/internal/" -ForegroundColor Yellow
            throw
        }
    }
    
    Pop-Location
    
    # Vérifier si sous-module a changé
    $submoduleStatus = git status --porcelain | Select-String "modified:.*mcps/internal"
    if ($submoduleStatus) {
        Write-Host "`n2️⃣ Commit mise à jour sous-module..." -ForegroundColor Yellow
        git add mcps/internal
        git commit -m "chore: Update mcps/internal submodule after merge"
        Write-Host "✅ Sous-module mis à jour" -ForegroundColor Green
    }
    
    # =============================================================================
    # PHASE 6 : VALIDATION PRÉ-PUSH
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  ✅ PHASE 6 : VALIDATION PRÉ-PUSH                               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "`n📊 État working tree :" -ForegroundColor Yellow
    $finalStatus = git status --porcelain
    if ($finalStatus) {
        Write-Host "⚠️ Working tree non propre :" -ForegroundColor Yellow
        git status --short
    } else {
        Write-Host "✅ Working tree propre" -ForegroundColor Green
    }
    
    Write-Host "`n📤 Commits à pusher :" -ForegroundColor Yellow
    $commitsAhead = git rev-list --count origin/main..HEAD
    Write-Host "Nombre : $commitsAhead"
    git log --oneline origin/main..HEAD
    
    Write-Host "`n🔍 Dry-run push :" -ForegroundColor Yellow
    git push --dry-run origin main
    
    # =============================================================================
    # PHASE 7 : PUSH FINAL
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🚀 PHASE 7 : PUSH FINAL                                        ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $pushConfirm = Read-Host "`n🚀 Pusher $commitsAhead commits vers origin/main ? (o/N)"
    if ($pushConfirm -eq 'o') {
        Write-Host "`n1️⃣ Push dépôt principal..." -ForegroundColor Yellow
        git push origin main
        Write-Host "✅ Push dépôt principal réussi !" -ForegroundColor Green
        
        Write-Host "`n2️⃣ Push sous-module mcps/internal..." -ForegroundColor Yellow
        Push-Location "mcps/internal"
        git push origin main
        Pop-Location
        Write-Host "✅ Push sous-module réussi !" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Push ignoré - à effectuer manuellement" -ForegroundColor Yellow
    }
    
    # =============================================================================
    # VÉRIFICATION FINALE
    # =============================================================================
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🎯 VÉRIFICATION FINALE                                         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "`n📊 État final dépôt principal :" -ForegroundColor Yellow
    git status
    
    Write-Host "`n📦 État final sous-modules :" -ForegroundColor Yellow
    git submodule status
    
    Write-Host "`n✅ SYNCHRONISATION TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
    Write-Host @"

📋 RÉSUMÉ :
-----------
✅ TraceSummaryService.ts : Refactor compteurs commité
✅ Rapport Phase 4 : Commité
✅ Dépôt principal : Synchronisé (pull + push)
✅ Sous-module mcps/internal : Synchronisé (pull + push)
✅ Working tree : Propre

"@ -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ ERREUR DURANT SYNCHRONISATION" -ForegroundColor Red
    Write-Host "Message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host @"

🔧 ACTIONS DE RÉCUPÉRATION :
-----------------------------
1. Vérifier état : git status
2. Si conflits : résoudre manuellement
3. Si problème sous-module : cd mcps/internal && git status
4. Relancer script après résolution

"@ -ForegroundColor Yellow
    exit 1
}