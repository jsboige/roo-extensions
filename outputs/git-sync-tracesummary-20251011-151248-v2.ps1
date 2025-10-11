#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Synchronisation Git TraceSummaryService - Version avec journalisation amelioree
    Session: 2025-10-11 15:12

.DESCRIPTION
    Journal detaille dans: outputs/git-sync-log-20251011-151248.json
    
.NOTES
    Etat initial :
    - Depot principal : 17 commits en retard
    - mcps/internal : Divergence (11 local, 8 remote)
    - TraceSummaryService.ts modifie (refactor compteurs)
#>

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "outputs/git-sync-log-$timestamp.json"
$textLog = "outputs/git-sync-log-$timestamp.txt"

# Structure de log
$log = @{
    session = $timestamp
    task = "TraceSummaryService Sync"
    phases = @()
    errors = @()
    status = "running"
}

function Write-LogEntry {
    param(
        [string]$Phase,
        [string]$Action,
        [string]$Status,
        [string]$Message,
        [hashtable]$Data = @{}
    )
    
    $entry = @{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        phase = $Phase
        action = $Action
        status = $Status
        message = $Message
        data = $Data
    }
    
    $log.phases += $entry
    
    # Sortie console simplifiee
    $statusIcon = switch ($Status) {
        "success" { "[OK]" }
        "error" { "[ERROR]" }
        "info" { "[INFO]" }
        "warn" { "[WARN]" }
        default { "[LOG]" }
    }
    
    Write-Host "$statusIcon $Phase > $Action : $Message"
    Add-Content -Path $textLog -Value "$statusIcon $Phase > $Action : $Message"
}

function Save-Log {
    $log | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host "`n[LOG] Journal complet sauvegarde : $logFile" -ForegroundColor Cyan
}

# Debut
Write-Host @"
===============================================================================
  SYNCHRONISATION GIT - TraceSummaryService + Sous-Modules
  Session: 2025-10-11 15:12:48
===============================================================================
"@ -ForegroundColor Cyan

Write-Host @"

CONTEXTE TACHE :
------------------
* Changement principal : TraceSummaryService.ts
  -> Refactor : 7 compteurs separes -> 1 compteur global unifie
  -> Ameliore tracabilite chronologique des items
   
* Sous-module mcps/internal :
  -> Divergence Git : 11 commits locaux vs 8 commits distants
  -> Necessite merge avec gestion des conflits potentiels
   
* Etat initial :
  -> Depot principal : 17 commits en retard
  -> 2 fichiers a commiter dans mcps/internal
  -> 1 fichier non tracke dans exports/

Journaux :
  -> JSON : $logFile
  -> Texte : $textLog

"@ -ForegroundColor Yellow

# Confirmation
$proceed = Read-Host "Lancer la synchronisation complete ? (o/N)"
if ($proceed -ne 'o') {
    Write-Host "[ABORT] Synchronisation annulee" -ForegroundColor Red
    $log.status = "aborted"
    Save-Log
    exit 0
}

try {
    # =========================================================================
    # PHASE 1 : COMMITS SOUS-MODULE mcps/internal
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 1 : COMMITS SOUS-MODULE mcps/internal" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    Push-Location "mcps/internal"
    
    Write-LogEntry -Phase "Phase1" -Action "Stage_TraceSummaryService" -Status "info" `
        -Message "Stage TraceSummaryService.ts"
    
    git add servers/roo-state-manager/src/services/TraceSummaryService.ts
    
    Write-LogEntry -Phase "Phase1" -Action "Commit_TraceSummaryService" -Status "info" `
        -Message "Commit refactor compteurs"
    
    $commitMsg = @"
refactor(TraceSummaryService): Unified global counter for chronological item numbering

- Replace 7 type-specific counters with single globalCounter
- Improves readability and chronological traceability
- Affects: user, assistant, tool, error, condensation, instruction, completion items
- Better alignment with trace summary timeline
"@
    
    $commitResult = git commit -m $commitMsg 2>&1
    Write-LogEntry -Phase "Phase1" -Action "Commit_TraceSummaryService" -Status "success" `
        -Message "Commit cree" -Data @{ output = $commitResult }
    
    Write-LogEntry -Phase "Phase1" -Action "Stage_Rapport" -Status "info" `
        -Message "Stage rapport Phase 4"
    
    git add servers/jupyter-papermill-mcp-server/RAPPORT_MISSION_PHASE4_TRIPLE_GROUNDING.md
    
    Write-LogEntry -Phase "Phase1" -Action "Commit_Rapport" -Status "info" `
        -Message "Commit rapport"
    
    $rapportCommit = git commit -m "docs(jupyter-mcp): Add Phase 4 Triple Grounding mission report" 2>&1
    Write-LogEntry -Phase "Phase1" -Action "Commit_Rapport" -Status "success" `
        -Message "Commit cree" -Data @{ output = $rapportCommit }
    
    Write-Host "`n[OK] Commits crees dans sous-module mcps/internal" -ForegroundColor Green
    git log --oneline -3
    
    Pop-Location
    
    # =========================================================================
    # PHASE 2 : COMMIT FICHIER EXPORTS (Depot Principal)
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 2 : COMMIT FICHIER EXPORTS (Depot Principal)" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    if (Test-Path "exports/TRACE_CORRIGEE.md") {
        Write-LogEntry -Phase "Phase2" -Action "Stage_Exports" -Status "info" `
            -Message "Stage exports/TRACE_CORRIGEE.md"
        
        git add exports/TRACE_CORRIGEE.md
        
        Write-LogEntry -Phase "Phase2" -Action "Commit_Exports" -Status "info" `
            -Message "Commit fichier exports"
        
        $exportsCommit = git commit -m "docs: Add corrected trace export" 2>&1
        Write-LogEntry -Phase "Phase2" -Action "Commit_Exports" -Status "success" `
            -Message "Commit cree" -Data @{ output = $exportsCommit }
        
        Write-Host "[OK] Fichier exports commite" -ForegroundColor Green
    } else {
        Write-LogEntry -Phase "Phase2" -Action "Check_Exports" -Status "warn" `
            -Message "Fichier exports/TRACE_CORRIGEE.md introuvable"
        Write-Host "[INFO] Fichier exports/TRACE_CORRIGEE.md introuvable (deja commite ?)" -ForegroundColor Gray
    }
    
    # =========================================================================
    # PHASE 3 : COMMIT SOUS-MODULE DANS DEPOT PRINCIPAL
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 3 : COMMIT SOUS-MODULE DANS DEPOT PRINCIPAL" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    Write-LogEntry -Phase "Phase3" -Action "Stage_Submodule" -Status "info" `
        -Message "Stage sous-module mcps/internal"
    
    git add mcps/internal
    
    Write-LogEntry -Phase "Phase3" -Action "Commit_Submodule" -Status "info" `
        -Message "Commit sous-module"
    
    $submoduleCommit = git commit -m @"
feat(mcps/internal): Update submodule with TraceSummaryService refactor

- TraceSummaryService: Unified global counter system
- Added Phase 4 Triple Grounding mission report
"@ 2>&1
    
    Write-LogEntry -Phase "Phase3" -Action "Commit_Submodule" -Status "success" `
        -Message "Sous-module commite" -Data @{ output = $submoduleCommit }
    
    Write-Host "[OK] Sous-module commite dans depot principal" -ForegroundColor Green
    
    # =========================================================================
    # PHASE 4 : PULL DEPOT PRINCIPAL (17 commits)
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 4 : PULL DEPOT PRINCIPAL (17 commits en retard)" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    Write-Host "`nCommits distants a integrer :" -ForegroundColor Yellow
    $remoteCommits = git log --oneline HEAD..origin/main | Select-Object -First 17
    $remoteCommits | ForEach-Object { Write-Host "  $_" }
    
    Write-LogEntry -Phase "Phase4" -Action "Show_Remote_Commits" -Status "info" `
        -Message "17 commits distants identifies" -Data @{ commits = $remoteCommits }
    
    $pullConfirm = Read-Host "`nPuller avec strategie merge ? (o/N)"
    if ($pullConfirm -eq 'o') {
        Write-LogEntry -Phase "Phase4" -Action "Pull_Main" -Status "info" `
            -Message "Debut pull avec merge"
        
        try {
            $pullOutput = git pull origin main --no-rebase 2>&1
            Write-LogEntry -Phase "Phase4" -Action "Pull_Main" -Status "success" `
                -Message "Pull reussi" -Data @{ output = $pullOutput }
            Write-Host "`n[OK] Pull reussi !" -ForegroundColor Green
        } catch {
            Write-LogEntry -Phase "Phase4" -Action "Pull_Main" -Status "error" `
                -Message "Conflit detecte" -Data @{ error = $_.Exception.Message }
            
            Write-Host "`n[ERROR] CONFLIT DETECTE !" -ForegroundColor Red
            Write-Host @"

RESOLUTION MANUELLE REQUISE :
--------------------------------
1. Verifier fichiers en conflit : git status
2. Ouvrir fichiers et chercher <<<<<<< ======= >>>>>>>
3. Resoudre manuellement les conflits
4. git add <fichiers_resolus>
5. git commit (pour finaliser le merge)

Ensuite, relancer ce script pour continuer.
"@ -ForegroundColor Yellow
            throw
        }
    } else {
        Write-LogEntry -Phase "Phase4" -Action "Pull_Main" -Status "warn" `
            -Message "Pull ignore par utilisateur"
        Write-Host "[WARN] Pull ignore - a effectuer manuellement" -ForegroundColor Yellow
    }
    
    # =========================================================================
    # PHASE 5 : PULL SOUS-MODULE mcps/internal (Divergence)
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 5 : PULL SOUS-MODULE mcps/internal (Divergence)" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    Push-Location "mcps/internal"
    
    Write-Host "`n[WARN] Divergence Git : 11 commits locaux vs 8 distants" -ForegroundColor Yellow
    Write-Host "Commits distants :" -ForegroundColor Yellow
    $subRemoteCommits = git log --oneline HEAD..origin/main | Select-Object -First 8
    $subRemoteCommits | ForEach-Object { Write-Host "  $_" }
    
    Write-LogEntry -Phase "Phase5" -Action "Show_Submodule_Remote" -Status "info" `
        -Message "8 commits distants identifies" -Data @{ commits = $subRemoteCommits }
    
    $subPullConfirm = Read-Host "`nPuller sous-module avec merge ? (o/N)"
    if ($subPullConfirm -eq 'o') {
        Write-LogEntry -Phase "Phase5" -Action "Pull_Submodule" -Status "info" `
            -Message "Debut pull sous-module"
        
        try {
            $subPullOutput = git pull origin main --no-rebase 2>&1
            Write-LogEntry -Phase "Phase5" -Action "Pull_Submodule" -Status "success" `
                -Message "Pull sous-module reussi" -Data @{ output = $subPullOutput }
            Write-Host "`n[OK] Pull sous-module reussi !" -ForegroundColor Green
        } catch {
            Write-LogEntry -Phase "Phase5" -Action "Pull_Submodule" -Status "error" `
                -Message "Conflit dans sous-module" -Data @{ error = $_.Exception.Message }
            Write-Host "`n[ERROR] CONFLIT DANS SOUS-MODULE !" -ForegroundColor Red
            Write-Host "Resolution manuelle requise dans mcps/internal/" -ForegroundColor Yellow
            throw
        }
    }
    
    Pop-Location
    
    # Verifier si sous-module a change
    $submoduleStatus = git status --porcelain | Select-String "modified:.*mcps/internal"
    if ($submoduleStatus) {
        Write-LogEntry -Phase "Phase5" -Action "Commit_Submodule_Update" -Status "info" `
            -Message "Commit mise a jour sous-module"
        
        git add mcps/internal
        $subUpdateCommit = git commit -m "chore: Update mcps/internal submodule after merge" 2>&1
        
        Write-LogEntry -Phase "Phase5" -Action "Commit_Submodule_Update" -Status "success" `
            -Message "Sous-module mis a jour" -Data @{ output = $subUpdateCommit }
        Write-Host "[OK] Sous-module mis a jour" -ForegroundColor Green
    }
    
    # =========================================================================
    # PHASE 6 : VALIDATION PRE-PUSH
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 6 : VALIDATION PRE-PUSH" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    Write-Host "`nEtat working tree :" -ForegroundColor Yellow
    $finalStatus = git status --porcelain
    if ($finalStatus) {
        Write-LogEntry -Phase "Phase6" -Action "Check_Status" -Status "warn" `
            -Message "Working tree non propre" -Data @{ status = $finalStatus }
        Write-Host "[WARN] Working tree non propre :" -ForegroundColor Yellow
        git status --short
    } else {
        Write-LogEntry -Phase "Phase6" -Action "Check_Status" -Status "success" `
            -Message "Working tree propre"
        Write-Host "[OK] Working tree propre" -ForegroundColor Green
    }
    
    Write-Host "`nCommits a pusher :" -ForegroundColor Yellow
    $commitsAhead = git rev-list --count origin/main..HEAD
    $commitsToPush = git log --oneline origin/main..HEAD
    Write-Host "Nombre : $commitsAhead"
    $commitsToPush | ForEach-Object { Write-Host "  $_" }
    
    Write-LogEntry -Phase "Phase6" -Action "Count_Commits" -Status "info" `
        -Message "$commitsAhead commits a pusher" -Data @{ commits = $commitsToPush }
    
    Write-Host "`nDry-run push :" -ForegroundColor Yellow
    $dryRun = git push --dry-run origin main 2>&1
    Write-Host $dryRun
    
    Write-LogEntry -Phase "Phase6" -Action "Dry_Run" -Status "info" `
        -Message "Dry-run execute" -Data @{ output = $dryRun }
    
    # =========================================================================
    # PHASE 7 : PUSH FINAL
    # =========================================================================
    Write-Host "`n===============================================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 7 : PUSH FINAL" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    
    $pushConfirm = Read-Host "`nPusher $commitsAhead commits vers origin/main ? (o/N)"
    if ($pushConfirm -eq 'o') {
        Write-LogEntry -Phase "Phase7" -Action "Push_Main" -Status "info" `
            -Message "Debut push depot principal"
        
        $pushOutput = git push origin main 2>&1
        Write-LogEntry -Phase "Phase7" -Action "Push_Main" -Status "success" `
            -Message "Push depot principal reussi" -Data @{ output = $pushOutput }
        Write-Host "[OK] Push depot principal reussi !" -ForegroundColor Green
        
        Write-LogEntry -Phase "Phase7" -Action "Push_Submodule" -Status "info" `
            -Message "Debut push sous-module"
        
        Push-Location "mcps/internal"
        $subPushOutput = git push origin main 2>&1
        Pop-Location
        
        Write-LogEntry -Phase "Phase7" -Action "Push_Submodule" -Status "success" `
            -Message "Push sous-module reussi" -Data @{ output = $subPushOutput }
        Write-Host "[OK] Push sous-module reussi !" -ForegroundColor Green
    } else {
        Write-LogEntry -Phase "Phase7" -Action "Push" -Status "warn" `
            -Message "Push ignore par utilisateur"
        Write-Host "[WARN] Push ignore - a effectuer manuellement" -ForegroundColor Yellow
    }
