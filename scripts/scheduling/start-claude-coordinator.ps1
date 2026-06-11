<#
.SYNOPSIS
    Lance le coordinateur schedule via Claude Code (Tier Coordinator de l'architecture 3x2)

.DESCRIPTION
    Issue #540 - Coordinator tier (ai-01 ONLY)
    Issue #1980 - Idle guard: skip session when no work is pending

    Ce script :
    1. Analyse le trafic RooSync (messages envoyes/recus par machine)
    2. Analyse l'activite Git recente (commits merges, auteurs)
    3. Evalue l'equilibre de charge entre les 6 machines
    4. Dispatche/rebalance si necessaire
    5. Produit un rapport coordinateur sur GDrive

    IDLE GUARD (#1980):
    Before launching Claude, checks 3 conditions (0 tokens):
    - Recent interactive [DONE] from ai-01 on dashboard (< IdleThresholdHours)
    - Open PRs in both repos (parent + submod)
    - RooSync inbox files on GDrive
    If all conditions indicate "no work" → skip session entirely (0 cost).
    Use -Force to override.

    Frequence : 6-12h
    Model : Sonnet baseline avec escalation sub-agent Opus pour PR reviews (#1027)
    Machine : myia-ai-01 UNIQUEMENT

.PARAMETER Model
    Modele Claude a utiliser (defaut: sonnet)

.PARAMETER LookbackHours
    Fenetre d'analyse en heures (defaut: 48)

.PARAMETER DryRun
    Mode simulation sans execution reelle

.PARAMETER IdleThresholdHours
    Hours since last interactive [DONE] before coordinator runs (defaut: 6)

.PARAMETER Force
    Skip idle guard — always run the coordinator session

.EXAMPLE
    .\start-claude-coordinator.ps1
    # Lance la coordination en mode Sonnet (baseline), with idle guard

.EXAMPLE
    .\start-claude-coordinator.ps1 -Force
    # Force run even if idle guard would skip

.EXAMPLE
    .\start-claude-coordinator.ps1 -Model "opus" -DryRun
    # Simulation avec modele Opus (escalade manuelle)

.NOTES
    Auteur: Claude Code (myia-ai-01)
    Date: 2026-03-05
    Version: 1.2.0
    Issue: #540, #1980, #2264
#>

[CmdletBinding()]
param(
    [string]$Model = "sonnet",
    [int]$LookbackHours = 48,
    [double]$MaxBudgetUsd = 1.50,
    [switch]$DryRun = $false,
    [double]$IdleThresholdHours = 8,
    [switch]$Force = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path "$ScriptDir\..\.."
$LogDir = if (-not [string]::IsNullOrWhiteSpace($env:CLAUDE_COORDINATOR_LOG_DIR)) {
    $env:CLAUDE_COORDINATOR_LOG_DIR
} else {
    Join-Path $RepoRoot "outputs\scheduling\logs"
}
$MachineName = $env:COMPUTERNAME.ToLower()

# Verifier que c'est bien ai-01
if ($MachineName -ne "myia-ai-01") {
    Write-Host "[ERROR] Ce script ne doit tourner que sur myia-ai-01 (machine actuelle: $MachineName)" -ForegroundColor Red
    exit 1
}

# Creer repertoire logs si necessaire
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$LogFile = Join-Path $LogDir "coordinator-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# === Concurrency Guard: skip if another coordinator is already running ===
$LockFile = Join-Path $LogDir "coordinator.lock"
if (Test-Path $LockFile) {
    try {
        $LockContent = Get-Content $LockFile -Raw | ConvertFrom-Json
        if ($LockContent.pid) {
            $ExistingProcess = Get-Process -Id $LockContent.pid -ErrorAction SilentlyContinue
            if ($ExistingProcess) {
                $StartedAt = $LockContent.startedAt
                Write-Host "[SKIP] Another coordinator is already running (PID $($LockContent.pid), started $StartedAt)" -ForegroundColor Yellow
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

Write-Log "=== COORDINATOR START ==="
Write-Log "Machine: $MachineName"
Write-Log "Model: $Model"
Write-Log "Lookback: ${LookbackHours}h"
Write-Log "Repo: $RepoRoot"
Write-Log "DryRun: $DryRun"

# Pre-flight
if (-not (Test-ClaudeCLI)) {
    Write-Log "ABORT: Claude CLI introuvable" "ERROR"
    exit 1
}

# =============================================================================
# IDLE GUARD (#1980) — Skip session if interactive already handled coordination
# Costs 0 tokens: pure PowerShell checks before launching Claude.
# =============================================================================

if (-not $Force) {
    Write-Log "IDLE GUARD: Checking if session should be skipped..."

    $IdleSkip = $true  # Assume skip unless a reason to run is found
    $IdleReasons = @()

    # Check 1: Recent interactive [DONE] on dashboard workspace (< IdleThresholdHours)
    $DashboardFile = Join-Path $env:ROOSYNC_SHARED_PATH "dashboards\workspace-roo-extensions.md"
    if (Test-Path $DashboardFile) {
        try {
            $DashboardContent = Get-Content $DashboardFile -Raw -ErrorAction Stop
            # Find all timestamp patterns from interactive Claude sessions
            # Format: ### [2026-05-05T08:53:12.213Z] myia-ai-01|roo-extensions
            $RecentInteractive = $DashboardContent | Select-String -Pattern '(?m)^###\s+\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})' -AllMatches |
                ForEach-Object { $_.Matches } |
                ForEach-Object {
                    $ts = [DateTime]::Parse($_.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                    # Check if this message section contains [DONE] or [CLAIMED] from ai-01
                    $msgStart = $_.Index
                    $nextSection = $DashboardContent.IndexOf("`n### ", $msgStart + 1)
                    if ($nextSection -eq -1) { $nextSection = $DashboardContent.Length }
                    $msgBlock = $DashboardContent.Substring($msgStart, [Math]::Min($nextSection - $msgStart, 500))
                    @{ Timestamp = $ts; HasDone = $msgBlock -match '\[DONE\]'; HasClaimed = $msgBlock -match '\[CLAIMED\]'; FromAi01 = $msgBlock -match 'myia-ai-01' }
                } |
                Where-Object { $_.FromAi01 -and ($_.HasDone -or $_.HasClaimed) } |
                Sort-Object Timestamp -Descending |
                Select-Object -First 1

            if ($RecentInteractive) {
                $TimeSince = ((Get-Date).ToUniversalTime() - $RecentInteractive.Timestamp).TotalHours
                $TimeSinceStr = $TimeSince.ToString('F1')
                if ($TimeSince -lt $IdleThresholdHours) {
                    $IdleReasons += "Recent interactive [DONE]/[CLAIMED] from ai-01 ${TimeSinceStr}h ago (threshold: ${IdleThresholdHours}h)"
                } else {
                    $IdleSkip = $false
                    $IdleReasons += "Last interactive [DONE]/[CLAIMED] was ${TimeSinceStr}h ago (> ${IdleThresholdHours}h threshold)"
                }
            } else {
                $IdleSkip = $false
                $IdleReasons += "No recent interactive [DONE]/[CLAIMED] from ai-01 on dashboard"
            }
        } catch {
            $IdleSkip = $false
            $IdleReasons += "Could not read dashboard: $_"
        }
    } else {
        $IdleSkip = $false
        $IdleReasons += "Dashboard file not found at $DashboardFile"
    }

    # Check 2: Open PRs needing review (any open PR = reason to run)
    try {
        $OpenPRs = & gh pr list --repo jsboige/roo-extensions --state open --json number 2>$null | ConvertFrom-Json
        $OpenSubmodPRs = & gh pr list --repo jsboige/jsboige-mcp-servers --state open --json number 2>$null | ConvertFrom-Json
        $TotalPRs = ($OpenPRs | Measure-Object).Count + ($OpenSubmodPRs | Measure-Object).Count
        if ($TotalPRs -gt 0) {
            $IdleSkip = $false
            $IdleReasons += "$TotalPRs open PR(s) need review"
        } else {
            $IdleReasons += "No open PRs"
        }
    } catch {
        # gh might not be available — don't block on this check
        $IdleReasons += "Could not check open PRs: $_"
    }

    # Check 3: RooSync inbox on GDrive — check for unread marker files (0 tokens)
    try {
        $InboxDir = Join-Path $env:ROOSYNC_SHARED_PATH "roosync\myia-ai-01\inbox"
        if (Test-Path $InboxDir) {
            $UnreadFiles = Get-ChildItem $InboxDir -Filter "*.json" -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -gt 0 }
            $UnreadCount = ($UnreadFiles | Measure-Object).Count
            if ($UnreadCount -gt 0) {
                $IdleSkip = $false
                $IdleReasons += "$UnreadCount RooSync inbox file(s)"
            } else {
                $IdleReasons += "RooSync inbox empty"
            }
        } else {
            $IdleReasons += "RooSync inbox dir not found"
        }
    } catch {
        $IdleReasons += "Could not check RooSync inbox: $_"
    }

    # Decision with consecutive IDLE cap (#2127)
    $IdleCounterFile = Join-Path $LogDir "coordinator-idle-counter.json"
    $MaxConsecutiveIdle = 2

    if ($IdleSkip) {
        # Increment consecutive IDLE counter
        $IdleCount = 1
        try {
            if (Test-Path $IdleCounterFile) {
                $CounterData = Get-Content $IdleCounterFile -Raw | ConvertFrom-Json
                $IdleCount = $CounterData.consecutiveIdle + 1
            }
        } catch { $IdleCount = 1 }

        # Save counter
        @{ consecutiveIdle = $IdleCount; lastIdleAt = (Get-Date).ToUniversalTime().ToString('o') } |
            ConvertTo-Json | Set-Content $IdleCounterFile -Encoding utf8NoBOM

        if ($IdleCount -gt $MaxConsecutiveIdle) {
            Write-Log "IDLE GUARD: HARD CAP — $IdleCount consecutive idle cycles (max $MaxConsecutiveIdle). Stopping until next [WAKE-CLAUDE] or scheduled window." "WARN"
            Write-Log "=== COORDINATOR IDLE CAP EXIT (#2127) ===" "WARN"
            exit 0
        }

        Write-Log "IDLE GUARD: SKIP — All checks indicate no work needed ($IdleCount/$MaxConsecutiveIdle consecutive):" "WARN"
        foreach ($reason in $IdleReasons) {
            Write-Log "  - $reason" "WARN"
        }
        Write-Log "IDLE GUARD: Use -Force to override. === COORDINATOR IDLE EXIT ===" "WARN"
        exit 0
    } else {
        # Reset counter on productive cycle
        if (Test-Path $IdleCounterFile) { Remove-Item $IdleCounterFile -Force -ErrorAction SilentlyContinue }
        Write-Log "IDLE GUARD: PROCEED — Reasons to run:"
        foreach ($reason in $IdleReasons) {
            Write-Log "  - $reason"
        }
    }
} else {
    Write-Log "IDLE GUARD: BYPASSED (-Force flag set)" "WARN"
}

# Construire le prompt coordinateur (slim — Epic #1997 #1999)
$Today = Get-Date -Format "yyyy-MM-dd"

$Prompt = @"
COORDINATEUR SCHEDULE Claude Code, myia-ai-01, $Today.

ROLE: Triage rapide. Pas de modif harnais. Max 3 actions/session.

ETAPES (cible: <10 min, pas de boucle compaction) :

1. Dashboard recent: roosync_dashboard(action: "read", type: "workspace", section: "intercom", intercomLimit: 5).
   Si [WAKE-CLAUDE]/[ASK]/[BLOCKED] <6h → traiter. Sinon → etape 3.

2. Inbox unread: roosync_read(mode: "inbox", status: "unread", limit: 10). Repondre les [ASK]/[URGENT].

3. PRs ouvertes:
   - gh pr list --repo jsboige/roo-extensions --state open --json number,title,additions,deletions,author
   - gh pr list --repo jsboige/jsboige-mcp-servers --state open --json number,title,additions,deletions,author
   TIER-GATE (#2565): Ce coordinator tourne sur ai-01 (Opus-class). Si ce script est invoque depuis une machine GLM-class (po-2023/24/25/26, web1), les PRs NON-triviales DOIVENT etre escalees (ne PAS merger). Trivial = pr-trivial-merge-policy.md criteria.
   Pour chaque PR <100 LOC, CI green, pas de suppression sans preuve, pas de stub, pas de console.log :
     gh pr merge {n} --squash --delete-branch
   PRs >=100 LOC ou ambigues → laisser pour interactif.

4. Bilan dashboard (OBLIGATOIRE): roosync_dashboard(action: "append", type: "workspace",
     tags: ["DONE", "claude-scheduled"], content: "[$Today HH:MM] Coord scheduled - {N} messages, {M} PRs vues, {K} mergees, {actions/aucune}").

CONTRAINTES:
- 0 modif harnais. 0 fermeture issue sans Evidence. 0 dispatch (interactif /coordinate dispatche).
- Sceptique: verifie avant de propager. Pas de Project #67 GraphQL load (couteux, deja vu en interactif).
- Si rien de pertinent → bilan minimal et exit.
"@

# Sauvegarder le prompt dans un fichier temporaire
$PromptFile = Join-Path $LogDir "coordinator-prompt-$Today.txt"
[System.IO.File]::WriteAllText($PromptFile, $Prompt, [System.Text.UTF8Encoding]::new($false))

Write-Log "Prompt sauvegarde: $PromptFile"

if ($DryRun) {
    Write-Log "[DRY-RUN] Commande qui serait executee:"
    Write-Log "  cd $RepoRoot && Get-Content '$PromptFile' -Raw | claude -p --model $Model --max-budget-usd $MaxBudgetUsd --dangerously-skip-permissions"
    Write-Log "=== COORDINATOR DRY-RUN END ==="
    exit 0
}

# Lancer Claude en mode pipe avec timeout protection
$MaxMinutes = 110  # Generous internal timeout (2h schtask limit, 110min internal for graceful exit)
Write-Log "Lancement Claude coordinateur (timeout: ${MaxMinutes}min, budget: `$$MaxBudgetUsd)..."
$StartTime = Get-Date

try {
    Push-Location $RepoRoot

    # Launch Claude as a background job with timeout
    $ClaudeJob = Start-Job -ScriptBlock {
        param($promptFile, $model, $budget, $repoRoot)
        Set-Location $repoRoot
        Get-Content $promptFile -Raw | & claude -p --model $model --max-budget-usd $budget --dangerously-skip-permissions 2>&1
    } -ArgumentList $PromptFile, $Model, $MaxBudgetUsd, $RepoRoot

    $Completed = Wait-Job $ClaudeJob -Timeout ($MaxMinutes * 60)

    if ($null -eq $Completed) {
        # Timeout reached - kill the job and all child processes
        Write-Log "TIMEOUT: Claude depasse ${MaxMinutes}min, arret force" "WARN"
        Stop-Job $ClaudeJob -PassThru | Remove-Job -Force
        # Also kill any orphaned claude processes from this session
        Get-Process -Name "claude" -ErrorAction SilentlyContinue | Where-Object {
            $_.StartTime -ge $StartTime
        } | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log "=== COORDINATOR TIMEOUT ==="
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

    Write-Log "=== COORDINATOR SUCCESS ==="
    exit 0

} catch {
    $Duration = (Get-Date) - $StartTime
    Write-Log "ERREUR: $_" "ERROR"
    Write-Log "Duration: $($Duration.TotalMinutes.ToString('F1')) min" "ERROR"
    Write-Log "=== COORDINATOR FAILED ==="
    exit 1
} finally {
    Pop-Location
    # Release lock file
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    # Cleanup prompt files (garder les 5 derniers)
    Get-ChildItem (Join-Path $LogDir "coordinator-prompt-*.txt") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
