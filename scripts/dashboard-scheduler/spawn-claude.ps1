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
    Hard kill timeout in minutes (default: 45).
    Opus 4.7 needs room for thinking + tool calls + detailed reply. 10 min was too tight
    (observed: nanoclaw review reply cut off mid-response).

.PARAMETER LockDir
    Directory for per-workspace lock files. Defaults to repo-root/.claude/locks.

.PARAMETER McpConfig
    Path to the MCP config JSON. Defaults to $env:USERPROFILE/.claude.json.
    Required so the spawned claude -p subprocess can reach roo-state-manager
    (see #1448: MCP is NOT inherited by subprocess — must be passed explicitly).

.EXAMPLE
    .\spawn-claude.ps1 -Workspace nanoclaw -Since "2026-04-17T00:00:00Z"

.NOTES
    - Lock file prevents concurrent spawns on the same workspace.
    - Exit code is Claude's exit code. claude -p sometimes returns non-zero
      even on success (auto-compact). Caller should not treat non-zero as
      failure without checking for a [REPLY]/[ACK] on the dashboard.
    - Output is truncated symmetrically if >1MB (threshold raised from 100KB in #1430
      review to avoid asymmetric 10x loss — previous behavior kept only ~10KB out of 100KB).

    Related: issue #1430, lessons from start-claude-worker.ps1 and #1423.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Workspace,

    [string]$Since = "",

    [string]$Model = "opus",

    [int]$TimeoutMinutes = 45,

    [string]$LockDir = "",

    [string]$McpConfig = ""
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

if ([string]::IsNullOrEmpty($McpConfig)) {
    $McpConfig = Join-Path $env:USERPROFILE ".claude.json"
}
if (-not (Test-Path $McpConfig)) {
    Write-Host "[$(Get-Date -Format o)] [ERROR] MCP config not found: $McpConfig"
    exit 11
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

    Write-Log "INFO" "Spawning claude -p (model=$Model, timeout=${TimeoutMinutes}min, mcp-config=$McpConfig) for workspace=$Workspace since=$Since"

    $outputFile = [System.IO.Path]::GetTempFileName()
    $errorFile = [System.IO.Path]::GetTempFileName()

    # `claude` on Windows is a .cmd shim, not a .exe — Start-Process can't
    # launch it directly. Resolve to the npm wrapper or VS Code native binary,
    # falling back to claude.cmd in PATH.
    $claudeExe = $null
    $candidates = @(
        (Get-ChildItem -Path "$env:USERPROFILE/.vscode/extensions/anthropic.claude-code-*-win32-x64/resources/native-binary/claude.exe" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1),
        (Get-Command claude.cmd -ErrorAction SilentlyContinue | Select-Object -First 1)
    )
    foreach ($c in $candidates) {
        if ($c -and $c.Path) { $claudeExe = $c.Path; break }
        if ($c -and $c.Source) { $claudeExe = $c.Source; break }
        if ($c -and $c.FullName) { $claudeExe = $c.FullName; break }
    }
    if (-not $claudeExe) {
        Write-Log "ERROR" "Cannot find claude executable (looked for VS Code native binary and claude.cmd in PATH)"
        return 11
    }
    Write-Log "INFO" "Using claude executable: $claudeExe"

    # Pass prompt via stdin (matches start-claude-worker.ps1 pattern from #1448).
    # Using `claude -p -` reads prompt from stdin which avoids cmd.exe arg quoting.
    $promptFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($promptFile, $prompt, [System.Text.UTF8Encoding]::new($false))

    $argList = @("-p", "-", "--dangerously-skip-permissions", "--model", $Model, "--output-format", "stream-json", "--verbose", "--include-partial-messages")
    if (-not [string]::IsNullOrEmpty($McpConfig) -and (Test-Path $McpConfig)) {
        $argList += @("--mcp-config", $McpConfig)
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $claudeExe
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Write([System.IO.File]::ReadAllText($promptFile))
    $proc.StandardInput.Close()

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    $timedOut = -not $proc.WaitForExit($TimeoutMinutes * 60 * 1000)

    if ($timedOut) {
        Write-Log "ERROR" "Spawn timed out after ${TimeoutMinutes}min. Killing process $($proc.Id)."
        try { $proc.Kill() } catch { }
        $exitCode = 124  # conventional timeout code
    } else {
        $exitCode = $proc.ExitCode
    }

    # ========== CAPTURE OUTPUT ==========

    # Drain async readers + persist to the temp files for the existing
    # truncation/logging code below.
    $stdoutText = $stdoutTask.Result
    $stderrText = $stderrTask.Result
    [System.IO.File]::WriteAllText($outputFile, $stdoutText, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($errorFile, $stderrText, [System.Text.UTF8Encoding]::new($false))
    Remove-Item -Path $promptFile -Force -ErrorAction SilentlyContinue

    $stdoutSize = 0
    $stderrSize = 0
    if (Test-Path $outputFile) { $stdoutSize = (Get-Item $outputFile).Length }
    if (Test-Path $errorFile) { $stderrSize = (Get-Item $errorFile).Length }

    # Truncation: >1MB keep last 1000 lines (~50KB). Threshold raised from 100KB/200 lines
    # per nanoclaw #1430 review — previous asymmetric ratio (kept 10KB out of 100KB) was arbitrary
    # and lost 90% of stream-json output where parse errors live.
    $TruncateThresholdBytes = 1048576  # 1 MB
    $TruncateTailLines = 1000

    $truncatedStdout = ""
    $truncatedStderr = ""
    if ($stdoutSize -gt 0) {
        if ($stdoutSize -gt $TruncateThresholdBytes) {
            $truncatedStdout = "...[truncated, $stdoutSize bytes total, last $TruncateTailLines lines]...`n"
            $truncatedStdout += Get-Content -Path $outputFile -Tail $TruncateTailLines -Raw
        } else {
            $truncatedStdout = Get-Content -Path $outputFile -Raw
        }
    }
    if ($stderrSize -gt 0) {
        if ($stderrSize -gt $TruncateThresholdBytes) {
            $truncatedStderr = "...[truncated, $stderrSize bytes total, last $TruncateTailLines lines]...`n"
            $truncatedStderr += Get-Content -Path $errorFile -Tail $TruncateTailLines -Raw
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
