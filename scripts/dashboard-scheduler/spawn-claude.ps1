<#
.SYNOPSIS
    Spawn Claude Code (claude -p) in response to actionable dashboard messages.

.DESCRIPTION
    Invoked by poll-dashboard.ps1 when actionable messages are detected.
    Runs Claude Code headless with a scripted prompt to read the dashboard,
    act on the actionable messages, and post a reply.

    Uses Opus 4.7 by default (per #1430 budget validation). The poll script
    is responsible for gating — this script assumes the spawn is already
    approved by the gate (i.e., at least one ASK/TASK/BLOCKED message exists).

    Phase 2 implementation. In Phase 1, poll-dashboard.ps1 runs in -Stub mode
    and does not call this script.

.PARAMETER Workspace
    Workspace key to act upon. Required.

.PARAMETER Since
    ISO timestamp of the last ACK marker (oldest message to process). Required.

.PARAMETER Model
    Claude model to use (default: opus).

.PARAMETER TimeoutMinutes
    Hard kill timeout in minutes (default: 10).

.PARAMETER LockDir
    Directory for per-workspace lock files. Defaults to repo-root/.claude/locks.

.EXAMPLE
    .\spawn-claude.ps1 -Workspace nanoclaw -Since "2026-04-17T00:00:00Z"

.NOTES
    - Lock file prevents concurrent spawns on the same workspace.
    - Exit code is Claude's exit code. claude -p sometimes returns non-zero
      even on success (auto-compact). Caller should not treat non-zero as
      failure without checking for a [REPLY]/[ACK] on the dashboard.
    - Output is truncated if >100KB to avoid log saturation (#1423 lesson).

    Related: issue #1430, lessons from start-claude-worker.ps1 and #1423.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Workspace,

    [Parameter(Mandatory=$true)]
    [string]$Since,

    [string]$Model = "opus",

    [int]$TimeoutMinutes = 10,

    [string]$LockDir = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

if ([string]::IsNullOrEmpty($LockDir)) {
    $LockDir = Join-Path $RepoRoot ".claude/locks"
}

if (-not (Test-Path $LockDir)) {
    New-Item -ItemType Directory -Path $LockDir -Force | Out-Null
}

$lockFile = Join-Path $LockDir "spawn-$Workspace.lock"

function Write-Log($level, $msg) {
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Write-Host "[$ts] [$level] $msg"
}

# ========== LOCK ==========

if (Test-Path $lockFile) {
    $lockAge = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($lockAge.TotalMinutes -lt ($TimeoutMinutes + 2)) {
        Write-Log "WARN" "Another spawn is in progress (lock age=$([Math]::Round($lockAge.TotalMinutes, 1))min). Aborting."
        exit 10
    }
    Write-Log "WARN" "Stale lock detected (age=$([Math]::Round($lockAge.TotalMinutes, 1))min). Removing."
    Remove-Item $lockFile -Force
}

try {
    "$PID|$(Get-Date -Format o)" | Set-Content -Path $lockFile -Encoding UTF8

    # ========== PROMPT ==========

    $prompt = @"
Tu es invoqué par le dashboard-watcher pour répondre aux messages actionnables sur workspace-$Workspace depuis $Since.

ÉTAPES:
1. Lis le dashboard: roo-state-manager.roosync_dashboard(action: "read", type: "workspace", workspace: "$Workspace", section: "intercom", intercomLimit: 20)
2. Identifie les messages avec tag [ASK], [TASK], ou [BLOCKED] postés APRÈS $Since qui n'ont pas encore reçu de [REPLY] ou [ACK] de ta part.
3. Pour chaque message actionnable:
   - Analyse la demande avec le contexte complet
   - Produis une réponse technique ou un [ACK] explicite
   - Poste la réponse via roosync_dashboard(action: "append", type: "workspace", workspace: "$Workspace", tags: ["REPLY"] ou ["ACK"], content: "...")
4. Si aucune action nécessaire (déjà traité ou non actionnable sur reflection), poste un [ACK] explicatif pour marquer le sweep.
5. Termine avec un résumé bref.

CONTRAINTES:
- Budget: économise les tokens, réponse ciblée.
- Pas de branch git, pas de PR depuis ce workflow (modification de code doit passer par un autre circuit).
- Ne pas modifier le dashboard de manière destructive (pas de condense sauf si explicitement demandé).

Commence.
"@

    # ========== SPAWN ==========

    Write-Log "INFO" "Spawning claude -p (model=$Model, timeout=${TimeoutMinutes}min) for workspace=$Workspace since=$Since"

    $outputFile = [System.IO.Path]::GetTempFileName()
    $errorFile = [System.IO.Path]::GetTempFileName()

    $proc = Start-Process -FilePath "claude" `
        -ArgumentList @("-p", "--model", $Model, $prompt) `
        -NoNewWindow `
        -RedirectStandardOutput $outputFile `
        -RedirectStandardError $errorFile `
        -PassThru

    $timedOut = -not $proc.WaitForExit($TimeoutMinutes * 60 * 1000)

    if ($timedOut) {
        Write-Log "ERROR" "Spawn timed out after ${TimeoutMinutes}min. Killing process $($proc.Id)."
        try { $proc.Kill() } catch { }
        $exitCode = 124  # conventional timeout code
    } else {
        $exitCode = $proc.ExitCode
    }

    # ========== CAPTURE OUTPUT ==========

    $stdoutSize = 0
    $stderrSize = 0
    if (Test-Path $outputFile) { $stdoutSize = (Get-Item $outputFile).Length }
    if (Test-Path $errorFile) { $stderrSize = (Get-Item $errorFile).Length }

    $truncatedStdout = ""
    $truncatedStderr = ""
    if ($stdoutSize -gt 0) {
        if ($stdoutSize -gt 102400) {
            $truncatedStdout = "...[truncated, $stdoutSize bytes total, last 10KB]...`n"
            $truncatedStdout += Get-Content -Path $outputFile -Tail 200 -Raw
        } else {
            $truncatedStdout = Get-Content -Path $outputFile -Raw
        }
    }
    if ($stderrSize -gt 0) {
        if ($stderrSize -gt 102400) {
            $truncatedStderr = "...[truncated, $stderrSize bytes total, last 10KB]...`n"
            $truncatedStderr += Get-Content -Path $errorFile -Tail 200 -Raw
        } else {
            $truncatedStderr = Get-Content -Path $errorFile -Raw
        }
    }

    Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
    Remove-Item $errorFile -Force -ErrorAction SilentlyContinue

    Write-Log "INFO" "Spawn completed: exitCode=$exitCode stdout=${stdoutSize}B stderr=${stderrSize}B"
    if ($truncatedStdout) {
        Write-Log "STDOUT" "`n$truncatedStdout"
    }
    if ($truncatedStderr) {
        Write-Log "STDERR" "`n$truncatedStderr"
    }

    if ($exitCode -eq 0) {
        Write-Log "INFO" "Spawn exit 0. Success (but verify [REPLY]/[ACK] on dashboard)."
    } elseif ($exitCode -eq 1) {
        Write-Log "INFO" "Spawn exit 1. Often auto-compact — NOT a failure. Check dashboard for [REPLY]."
        $exitCode = 0  # treat as success per #1423 lesson
    } else {
        Write-Log "WARN" "Spawn exit $exitCode. Unexpected. Caller should verify dashboard state."
    }

    exit $exitCode
} finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}
