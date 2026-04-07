<#
.SYNOPSIS
    Lance un audit meta-analyse via Claude Code (Tier Meta-Analyst de l'architecture 3x2)

.DESCRIPTION
    Issue #551 - Meta-Analyst tier

    Ce script :
    1. Analyse les traces locales Roo et Claude
    2. Effectue une analyse croisee des deux harnais
    3. Ecrit les findings dans META-INTERCOM
    4. Propose des issues GitHub avec label needs-approval si applicable

    Frequence : 72h
    Model : Sonnet baseline avec escalation sub-agent Opus pour recommandations architecturales (#1027)
    Machines : TOUTES

    ESCALATION MECHANISM (#1027):
    - Thread principal sur Sonnet (analyse traces, detection incoherences)
    - Recommandations architecturales complexes : deleguer a sub-agent Opus
    - MinimumModel guard non applicable (Sonnet suffisant pour harnais actuel)

.PARAMETER Model
    Modele Claude a utiliser (defaut: sonnet)

.PARAMETER DryRun
    Mode simulation sans execution reelle

.EXAMPLE
    .\start-meta-audit.ps1
    # Lance l'audit meta-analyse en mode Sonnet (baseline)

.EXAMPLE
    .\start-meta-audit.ps1 -Model "opus" -DryRun
    # Simulation avec modele Opus (escalade manuelle)

.NOTES
    Auteur: Claude Code (myia-ai-01)
    Date: 2026-03-04
    Version: 1.0.0
    Issue: #551
#>

[CmdletBinding()]
param(
    [string]$Model = "sonnet",
    [switch]$DryRun = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$LogDir = Join-Path $RepoRoot ".claude\logs"

# Fix #726: Load ROOSYNC_MACHINE_ID from .env (primary), with COMPUTERNAME fallback
$EnvPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\.env"
$MachineName = 'unknown'

if (Test-Path $EnvPath) {
    $EnvLine = Get-Content $EnvPath | Where-Object { $_ -match '^ROOSYNC_MACHINE_ID=' }
    if ($EnvLine) {
        $MachineName = ($EnvLine -split '=', 2)[1].Trim().ToLower()
    }
}

if ($MachineName -eq 'unknown' -and $env:COMPUTERNAME) {
    $MachineName = $env:COMPUTERNAME.ToLower()
}

# Creer repertoire logs si necessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "meta-audit-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# === Concurrency Guard: skip if another meta-audit is already running ===
$LockFile = Join-Path $LogDir "meta-audit.lock"
if (Test-Path $LockFile) {
    try {
        $LockContent = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($LockContent.pid) {
            $ExistingProcess = Get-Process -Id $LockContent.pid -ErrorAction SilentlyContinue
            if ($ExistingProcess) {
                $StartedAt = $LockContent.startedAt
                Write-Host "[SKIP] Another meta-audit is already running (PID $($LockContent.pid), started $StartedAt)" -ForegroundColor Yellow
                exit 0
            }
        }
    } catch {
        # Stale or corrupt lock file - proceed
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
# Acquire lock
@{ pid = $PID; startedAt = (Get-Date -Format "o"); machine = $MachineName } | ConvertTo-Json | Set-Content $LockFile -Force

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

function Test-ClaudeCLI {
    try {
        $Version = & claude --version 2>&1
        Write-Log "Claude CLI: $Version"
        return $true
    } catch {
        Write-Log "Claude CLI non disponible: $_" "ERROR"
        return $false
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Log "=== META-AUDIT START ==="
Write-Log "Machine: $MachineName"
Write-Log "Model: $Model"
Write-Log "Repo: $RepoRoot"
Write-Log "DryRun: $DryRun"

# Pre-flight
if (-not (Test-ClaudeCLI)) {
    Write-Log "ABORT: Claude CLI introuvable" "ERROR"
    exit 1
}

# Construire le prompt meta-analyse
$Today = Get-Date -Format "yyyy-MM-dd"
$MetaIntercomPath = ".claude/local/META-INTERCOM-$MachineName.md"
$MetaIntercomTemplatePath = ".claude/local/META-INTERCOM_TEMPLATE.md"

$Prompt = @"
Tu es le META-ANALYSTE Claude Code sur la machine $MachineName.
Date du cycle : $Today

## TON ROLE

Tu analyses les DEUX schedulers (Roo et Claude) sur cette machine pour identifier des ameliorations.
Tu ne modifies RIEN, tu ne dispatches RIEN. Tu PROPOSES uniquement.

## ETAPES

### 1. Collecte des traces Roo (5 dernieres taches)

Utilise Bash pour lister les taches Roo recentes :
``````
ls -lt "$env:APPDATA/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/" 2>/dev/null | head -10
``````

Pour chaque tache recente, lire les ui_messages.json (derniers 50 lignes).

### 2. Collecte des traces Claude

Lister les sessions Claude recentes :
``````
ls -lt ~/.claude/projects/*/  2>/dev/null | head -10
``````

### 3. Analyse croisee des harnais

Lire les fichiers cles des DEUX harnais :

**Roo :**
- .roo/rules/ (tous les fichiers)
- .roo/scheduler-workflow-coordinator.md
- .roo/scheduler-workflow-executor.md
- .roo/scheduler-workflow-meta-analyst.md

**Claude :**
- CLAUDE.md
- .claude/rules/ (tous les fichiers)

Identifier :
- Incoherences entre les deux harnais
- Lacunes (regles presentes d'un cote mais pas l'autre)
- Ameliorations potentielles

### 4. Ecrire dans META-INTERCOM

Fichier : $MetaIntercomPath
Template (si fichier n'existe pas) : $MetaIntercomTemplatePath

Ajouter EN FIN du fichier un rapport avec ce format :

## [$Today] claude-code -> roo [META]
### Analyse Meta-Analyste Claude (cycle $Today)

**Traces Roo (analyse croisee) :**
- {N} taches analysees, taux succes {X}%
- Modes utilises : {liste}
- Escalades observees : {details}

**Traces Claude (auto-analyse) :**
- {N} sessions recentes
- Worker executions : {details}
- Patterns remarques

**Analyse harnais :**
- Incoherences : {N} (severity)
- Lacunes : {N}
- Ameliorations proposees : {N}

**Recommandations :**
1. {Rec 1} -> [action: INFO|needs-approval|harness-change]

**ESCALATION PATTERN (#1027) :**
Pour recommandations architecturales complexes (ex: refactoring majeur, nouveaux patterns), deleguer l'analyse a un sub-agent Opus :
```
Task(tool="code-explorer", prompt="Analyse l'architecture [composant] pour identifier [probleme]. Return un plan d'action detaille.", model="opus")
```

---

### 5. Creer des issues si recommandations actionnables

UNIQUEMENT si tu identifies des problemes concrets :
- Utilise ``gh issue create`` avec label ``needs-approval``
- Si changement de harnais : ajouter label ``harness-change``
- Maximum 3 issues par cycle
- NE PAS creer d'issue pour des observations purement informationnelles

## CONTRAINTES ABSOLUES

- NE MODIFIE AUCUN fichier de harnais (.roo/rules/, .claude/rules/, CLAUDE.md, .roomodes)
- NE FERME/ARCHIVE AUCUNE issue GitHub
- NE DISPATCHE AUCUNE tache
- TOUTE issue creee DOIT avoir le label needs-approval
- Limite tes outputs (pas de dump complet de fichiers)
- NE CREER AUCUN fichier rapport dans le depot (docs/, .claude/, etc.) — les rapports vont sur le dashboard ou en issues GitHub (#1179)
"@

# Sauvegarder le prompt dans un fichier temporaire (evite les problemes de quoting PS)
$PromptFile = Join-Path $RepoRoot ".claude\logs\meta-audit-prompt-$Today.txt"
[System.IO.File]::WriteAllText($PromptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

Write-Log "Prompt sauvegarde: $PromptFile"

if ($DryRun) {
    Write-Log "[DRY-RUN] Commande qui serait executee:"
    Write-Log "  cd $RepoRoot && Get-Content '$PromptFile' -Raw | claude -p --model $Model --dangerously-skip-permissions --output-format stream-json --verbose"
    Write-Log "=== META-AUDIT DRY-RUN END ==="
    exit 0
}

# Lancer Claude en mode pipe avec timeout protection
$MaxMinutes = 110  # Generous internal timeout (2h schtask limit, 110min internal for graceful exit)
Write-Log "Lancement Claude meta-audit (timeout: ${MaxMinutes}min)..."
$StartTime = Get-Date

try {
    Push-Location $RepoRoot

    # Launch Claude as a background job with timeout
    $ClaudeJob = Start-Job -ScriptBlock {
        param($promptFile, $model, $repoRoot)
        Set-Location $repoRoot
        Get-Content $promptFile -Raw | & claude -p --model $model --dangerously-skip-permissions 2>&1
    } -ArgumentList $PromptFile, $Model, $RepoRoot

    $Completed = Wait-Job $ClaudeJob -Timeout ($MaxMinutes * 60)

    if ($null -eq $Completed) {
        # Timeout reached - kill the job and all child processes
        Write-Log "TIMEOUT: Claude depasse ${MaxMinutes}min, arret force" "WARN"
        Stop-Job $ClaudeJob -PassThru | Remove-Job -Force
        Get-Process -Name "claude" -ErrorAction SilentlyContinue | Where-Object {
            $_.StartTime -ge $StartTime
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log "=== META-AUDIT TIMEOUT ==="
        exit 2
    }

    $ClaudeOutput = Receive-Job $ClaudeJob
    Remove-Job $ClaudeJob -Force -ErrorAction SilentlyContinue

    $Duration = (Get-Date) - $StartTime
    Write-Log "Claude termine en $($Duration.TotalMinutes.ToString('F1')) minutes"
    Write-Log "Output (dernieres 20 lignes):"

    $OutputLines = ($ClaudeOutput -split "`n")
    $LastLines = $OutputLines | Select-Object -Last 20
    foreach ($line in $LastLines) {
        Write-Log "  $line"
    }

    # Envoyer un rapport RooSync (si ROOSYNC_SHARED_PATH configure)
    $SharedPath = $env:ROOSYNC_SHARED_PATH
    if ($SharedPath) {
        Write-Log "Envoi rapport RooSync..."
        $ReportSubject = "Meta-Audit Report - $MachineName - $Today"
        $ReportBody = "## Meta-Audit Report`n`n**Machine:** $MachineName`n**Date:** $Today`n**Duration:** $($Duration.TotalMinutes.ToString('F1')) min`n**Model:** $Model`n`n### Output (last 10 lines)`n$(($OutputLines | Select-Object -Last 10) -join "`n")"

        # Ecrire le rapport en JSON dans l'outbox
        $OutboxPath = Join-Path $SharedPath "messages\outbox"
        if (Test-Path $OutboxPath) {
            $ReportId = "msg-$(Get-Date -Format 'yyyyMMddTHHmmss')-meta-audit"
            $Report = @{
                id = $ReportId
                from = "$MachineName`:roo-extensions"
                to = "myia-ai-01"
                subject = $ReportSubject
                body = $ReportBody
                priority = "LOW"
                timestamp = (Get-Date -Format "o")
                status = "unread"
            } | ConvertTo-Json -Depth 3
            $ReportFile = Join-Path $OutboxPath "$ReportId.json"
            [System.IO.File]::WriteAllText($ReportFile, $Report, [System.Text.UTF8Encoding]::new($false))
            Write-Log "Rapport RooSync envoye: $ReportId"
        }
    }

    Write-Log "=== META-AUDIT SUCCESS ==="
    exit 0

} catch {
    $Duration = (Get-Date) - $StartTime
    Write-Log "ERREUR: $_" "ERROR"
    Write-Log "Duration: $($Duration.TotalMinutes.ToString('F1')) min" "ERROR"
    Write-Log "=== META-AUDIT FAILED ==="
    exit 1
} finally {
    Pop-Location
    # Release lock file
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    # Cleanup prompt file (garder les 5 derniers)
    Get-ChildItem (Join-Path $LogDir "meta-audit-prompt-*.txt") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
