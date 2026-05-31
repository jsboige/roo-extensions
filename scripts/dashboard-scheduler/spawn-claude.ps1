<#
.SYNOPSIS
    Spawn Claude Code (claude -p) with a triggering [WAKE-CLAUDE] message.

.DESCRIPTION
    Invoked by dashboard-listener.ps1 when a [WAKE-CLAUDE] tagged message is
    detected on a workspace dashboard. Runs Claude Code headless with the
    triggering message embedded in the prompt — no re-read of the dashboard
    required (#2004 Phase 2 push pattern, fixes #2004 token waste).

    Uses Haiku by default (per #2172 credit optimization). The listener
    is responsible for gating — this script assumes the spawn is already
    approved (cooldown OK, workspace path resolved, [WAKE-CLAUDE] tag found).

    MCP availability: builds a merged config combining top-level mcpServers
    + projects[$WorkspacePath].mcpServers from $McpConfig, so the spawned
    Claude has access to ALL MCPs configured for the target workspace.

.PARAMETER Workspace
    Workspace key to act upon. Required.

.PARAMETER Model
    Claude model to use (default: haiku per #2172).

.PARAMETER TimeoutMinutes
    Hard kill timeout in minutes (default: 45).

.PARAMETER LockDir
    Directory for per-workspace lock files. Defaults to repo-root/.claude/locks.

.PARAMETER McpConfig
    Path to the MCP config JSON (~/.claude.json). Required so the spawned
    claude -p subprocess can reach roo-state-manager + workspace-specific MCPs
    (#1448: MCP is NOT inherited by subprocess — must be passed explicitly).

.PARAMETER WorkspacePath
    Absolute on-disk path of the target workspace. Used as WorkingDirectory for
    the spawned claude -p process so it loads the correct CLAUDE.md / .claude/rules.
    Resolved by the listener from a per-workspace map.

.PARAMETER MessagePayloadFile
    Path to a UTF-8 JSON file containing the triggering message:
    `{ "timestamp": "...", "author": {"machineId": "...", "workspace": "..."}, "content": "..." }`.
    Written by the listener and cleaned up by this script. Required.

.EXAMPLE
    .\spawn-claude.ps1 -Workspace nanoclaw -WorkspacePath "D:\nanoclaw" -MessagePayloadFile "C:\Temp\wake-claude-payload.json"

.NOTES
    - Lock file prevents concurrent spawns on the same workspace.
    - Exit code is Claude's exit code. claude -p sometimes returns non-zero
      even on success (auto-compact). Caller should not treat non-zero as
      failure without checking for a [REPLY]/[ACK] on the dashboard.
    - Output is truncated symmetrically if >1MB.

    Related: #2004 (push pattern fix), #1430 (budget), #1448 (MCP inheritance), #1423 (auto-compact).
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Workspace,

    [string]$Model = "haiku",

    [int]$TimeoutMinutes = 45,

    [string]$LockDir = "",

    [string]$McpConfig = "",

    [string]$WorkspacePath = "",

    # #2004 Phase 2: path to a JSON file containing the triggering message
    # ({timestamp, author{machineId,workspace}, content}). The listener writes
    # this file and passes the path so we don't have to hand-craft a long
    # multi-line argument across PowerShell quoting layers.
    [Parameter(Mandatory=$true)]
    [string]$MessagePayloadFile
)

$ErrorActionPreference = "Stop"

# Universal compact window/threshold (single source of truth, user GO 2026-05-25).
# Supersedes #2173 model-aware override: ALL models (Claude + GLM/Qwen) now use
# 200k window / 90% threshold (180k effective). These override settings.json
# per-invocation via env vars.
$COMPACT_WINDOW = "200000"   # 200k context window (all model families)
$COMPACT_PCT    = "90"       # 90% threshold (180k effective). JAMAIS 50%.

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

    # ========== PROMPT (#2004 Phase 2: push pattern) ==========

    if (-not (Test-Path $MessagePayloadFile)) {
        Write-Log "ERROR" "MessagePayloadFile not found: $MessagePayloadFile"
        exit 12
    }
    try {
        $payloadRaw = [System.IO.File]::ReadAllText($MessagePayloadFile, [System.Text.UTF8Encoding]::new($false))
        $payload = $payloadRaw | ConvertFrom-Json
    } catch {
        Write-Log "ERROR" "Failed to parse MessagePayloadFile: $_"
        exit 13
    }

    $msgTimestamp = $payload.timestamp
    $msgAuthorMachine = $payload.author.machineId
    $msgAuthorWorkspace = $payload.author.workspace
    $msgContent = $payload.content

    $prompt = @"
Tu es invoqué par le dashboard-listener car un message [WAKE-CLAUDE] a été posté sur workspace ``$Workspace``.

MESSAGE DÉCLENCHEUR:
- Timestamp: $msgTimestamp
- Auteur: $msgAuthorMachine ($msgAuthorWorkspace)
- Contenu:
---
$msgContent
---

INSTRUCTIONS:
1. Analyse la demande ci-dessus avec le contexte du workspace courant ($Workspace).
2. Si la demande est claire et actionnable: traite-la, puis poste un [REPLY] avec ta réponse technique.
3. Si la demande est ambiguë: poste un [ACK] avec une question clarifiante via tag [ASK].
4. Si tu déduis que la demande a déjà été traitée (vérification rapide du dashboard récent autorisée): poste un [ACK] court explicatif pour marquer le sweep.
5. Termine.

POSTE LA RÉPONSE VIA:
roo-state-manager.roosync_dashboard(action: "append", type: "workspace", workspace: "$Workspace", tags: ["REPLY"] ou ["ACK"], content: "...")

CONTRAINTES:
- Budget: réponse ciblée, économise les tokens. Le message déclencheur est ci-dessus — pas besoin de re-lire le dashboard sauf vérification ciblée.
- Pas de branch git, pas de PR depuis ce workflow (modification de code = autre circuit).
- Ne pas modifier le dashboard de manière destructive (pas de condense sauf si explicitement demandé dans le message ci-dessus).

Commence.
"@

    # ========== SPAWN ==========

    Write-Log "INFO" "Spawning claude -p (model=$Model, timeout=${TimeoutMinutes}min, mcp-config=$McpConfig) for workspace=$Workspace trigger=$msgTimestamp from=$msgAuthorMachine"

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

    # Universal compact override (user GO 2026-05-25, supersedes #2173 model-aware).
    # ALL model families (Claude + GLM/Qwen) = 200k window / 90% threshold (180k effective).
    # These env vars take precedence over settings.json per Claude Code's env var hierarchy.
    $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $COMPACT_WINDOW
    $env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = $COMPACT_PCT
    Write-Log "INFO" "Compact override: $Model → window=200k, threshold=90% (universal)"

    # MCP tool-call timeout (#2402 follow-up). Unset → Claude Code default ~180s, which
    # STRANGLES the dashboard auto-condensation (budgeted CONDENSE_LLM_TIMEOUT_MS=720s in
    # roo-state-manager dashboard.ts) → append-hang at 180s fleet-wide. 900s > 720s budget.
    $env:MCP_TOOL_TIMEOUT = "900000"

    $argList = @("-p", "-", "--dangerously-skip-permissions", "--model", $Model, "--output-format", "stream-json", "--verbose")
    if ($env:DASHBOARD_WATCHER_DEBUG_SPAWN -eq "1") {
        $argList += "--include-partial-messages"
    }

    # #2004 Phase 2: Build a merged MCP config (top-level + workspace overrides
    # from $McpConfig.projects[$WorkspacePath]) so the spawned claude -p sees ALL
    # MCPs available for the target workspace, not just the top-level ones.
    # Without this merge, a workspace-scoped MCP override is silently dropped.
    $mergedMcpFile = $null
    if (-not [string]::IsNullOrEmpty($McpConfig) -and (Test-Path $McpConfig)) {
        try {
            $rawCfg = [System.IO.File]::ReadAllText($McpConfig, [System.Text.UTF8Encoding]::new($false))
            $cfgObj = $rawCfg | ConvertFrom-Json -AsHashtable
            $merged = [ordered]@{}
            if ($cfgObj.ContainsKey('mcpServers') -and $null -ne $cfgObj['mcpServers']) {
                foreach ($k in $cfgObj['mcpServers'].Keys) { $merged[$k] = $cfgObj['mcpServers'][$k] }
            }
            # Workspace-specific overrides (key = absolute path, exact or normalized match)
            if ($cfgObj.ContainsKey('projects') -and $null -ne $cfgObj['projects'] -and -not [string]::IsNullOrEmpty($WorkspacePath)) {
                $wsKey = $null
                $wsNormalized = ($WorkspacePath -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
                foreach ($pk in $cfgObj['projects'].Keys) {
                    $pkNormalized = ($pk -replace '\\', '/').TrimEnd('/').ToLowerInvariant()
                    if ($pkNormalized -eq $wsNormalized) { $wsKey = $pk; break }
                }
                if ($null -ne $wsKey) {
                    $proj = $cfgObj['projects'][$wsKey]
                    if ($proj -is [hashtable] -and $proj.ContainsKey('mcpServers') -and $null -ne $proj['mcpServers']) {
                        foreach ($k in $proj['mcpServers'].Keys) { $merged[$k] = $proj['mcpServers'][$k] }
                    }
                }
            }
            $mergedMcpFile = Join-Path $env:TEMP "spawn-claude-mcp-$Workspace-$([guid]::NewGuid().ToString('N').Substring(0,8)).json"
            $mergedJson = @{ mcpServers = $merged } | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($mergedMcpFile, $mergedJson, [System.Text.UTF8Encoding]::new($false))
            $argList += @("--mcp-config", $mergedMcpFile)
            Write-Log "INFO" "MCP config merged: $($merged.Keys.Count) servers available ($($merged.Keys -join ', ')) → $mergedMcpFile"
        } catch {
            Write-Log "WARN" "Failed to merge MCP config — falling back to original: $_"
            $argList += @("--mcp-config", $McpConfig)
        }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $claudeExe
    foreach ($a in $argList) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    # Working directory = target workspace (so claude -p loads its CLAUDE.md / .claude/rules).
    # Fall back to listener's repo root only if caller didn't resolve a path.
    if (-not [string]::IsNullOrEmpty($WorkspacePath) -and (Test-Path $WorkspacePath -PathType Container)) {
        $psi.WorkingDirectory = $WorkspacePath
        Write-Log "INFO" "WorkingDirectory = $WorkspacePath"
    } else {
        if (-not [string]::IsNullOrEmpty($WorkspacePath)) {
            Write-Log "WARN" "WorkspacePath not found on disk: $WorkspacePath — falling back to RepoRoot"
        }
        $psi.WorkingDirectory = $RepoRoot
    }

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
        # #1605 + nanoclaw retry-loop fix 2026-05-18: distinguish auto-compact
        # (benign #1423 case) from rapid_refill_breaker (context bloat — session
        # killed before producing any reply).
        #
        # PRIOR behavior: kept exitCode=1 so poll-dashboard would NOT advance
        # lastack — but this caused an infinite retry loop (next spawn hits the
        # same bloat, same trigger, same kill — ~$2.68/spawn wasted indefinitely).
        # Observed nanoclaw 2026-05-17/18: 5 spawns over 14h, all killed by
        # breaker, ~$13.40 wasted, growing stdout (62KB to 152KB) confirming the
        # bloat replicates per retry.
        #
        # NEW behavior: emit dedicated exitCode=42 for breaker_kill. poll-dashboard
        # treats 42 as "advance lastack to break the loop, but flag as ERROR so the
        # missed trigger is visible". The single trigger may be lost, but that is
        # strictly better than an infinite retry burning budget.
        $breakerMatch = $truncatedStdout -match '"terminal_reason"\s*:\s*"rapid_refill_breaker"'
        if ($breakerMatch) {
            Write-Log "ERROR" "Spawn killed by rapid_refill_breaker (context bloat). Emitting exitCode=42 so poll-dashboard advances lastack and breaks the retry loop. Cost ~`$2.68/spawn. Investigate context bloat for this workspace."
            $exitCode = 42
        } else {
            Write-Log "INFO" "Spawn exit 1. Likely auto-compact produced reply (#1423). Treating as success."
            $exitCode = 0
        }
    } else {
        Write-Log "WARN" "Spawn exit $exitCode. Unexpected. Caller should verify dashboard state."
    }

    exit $exitCode
} finally {
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
    # #2004 Phase 2 cleanup: temp files written by listener + this script
    if (-not [string]::IsNullOrEmpty($MessagePayloadFile) -and (Test-Path $MessagePayloadFile)) {
        Remove-Item $MessagePayloadFile -Force -ErrorAction SilentlyContinue
    }
    if (-not [string]::IsNullOrEmpty($mergedMcpFile) -and (Test-Path $mergedMcpFile)) {
        Remove-Item $mergedMcpFile -Force -ErrorAction SilentlyContinue
    }
}
