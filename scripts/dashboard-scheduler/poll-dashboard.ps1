<#
.SYNOPSIS
    Multi-workspace dashboard watcher: gate that decides whether to spawn
    Claude Code in response to actionable messages on RooSync workspace
    dashboards.

.DESCRIPTION
    Cheap polling script (0 token cost per watched workspace). For each
    workspace in -Workspaces (or auto-discovered), reads its dashboard via
    roo-state-manager MCP, compares new message timestamps against a
    per-workspace "last ACK" marker, filters by allowed tags and optionally
    authors, and spawns Claude Code only when an actionable message is found.

    One task per machine, not one task per workspace. A single invocation
    sweeps every workspace this machine cares about.

    Phase 1 (current): stub mode — prints "would spawn" but does NOT invoke
    claude -p. Used to validate gating logic without consuming Opus tokens.

    Phase 2 (after 48h stub validation): wire spawn-claude.ps1 to actually
    invoke claude -p with the Opus 4.7 model.

.PARAMETER Workspaces
    Comma-separated list of workspace keys to poll (e.g., "nanoclaw,roo-extensions").
    If empty, auto-discovers from ROOSYNC_SHARED_PATH/dashboards/workspace-*.md,
    intersected with -AllowedWorkspaces if provided.

.PARAMETER Workspace
    DEPRECATED single-workspace param. Kept for backward compat with the v1
    scheduler entry. If set and -Workspaces is empty, its value is used.

.PARAMETER AllowedWorkspaces
    When auto-discovering, restrict to these workspaces (comma-separated). Empty
    = all discovered. Ignored when -Workspaces is set explicitly.

.PARAMETER AllowedTags
    Comma-separated tags that should trigger a spawn. Defaults to "ASK,TASK,BLOCKED".
    Tags INFO, FYI, DONE, ACK, REPLY are ignored by design.

.PARAMETER AllowedAuthors
    Optional comma-separated list of machine IDs to consider as actionable
    authors. Empty = all authors are actionable.

.PARAMETER LockDir
    Directory for last-ACK marker files. Defaults to repo-root/.claude/locks.
    One lock file per workspace: watcher-{workspace}.lastack.

.PARAMETER Stub
    Phase 1 flag (default: true in this version). When set, prints the decision
    but does not invoke spawn-claude.ps1.

.PARAMETER SpawnScript
    Path to spawn-claude.ps1 (only used when -Stub is $false). Defaults to sibling.

.PARAMETER McpConfig
    Path to MCP config JSON file (must contain roo-state-manager). Defaults to
    ~/.claude.json. Required because `claude -p` subprocesses do not load user
    MCP config automatically — without it, Invoke-DashboardRead fails silently
    with "ERROR: Could not parse message into JSON". See issue #1448.

.EXAMPLE
    .\poll-dashboard.ps1 -Workspaces "nanoclaw,roo-extensions"
    Polls both dashboards, logs "would spawn" per workspace if actionable.

.EXAMPLE
    .\poll-dashboard.ps1
    Auto-discovers every workspace dashboard on this machine and polls each.

.EXAMPLE
    .\poll-dashboard.ps1 -Workspaces nanoclaw -AllowedTags "ASK,TASK" -AllowedAuthors "myia-ai-01"
    Only spawn on ASK/TASK from myia-ai-01 on the nanoclaw workspace.

.NOTES
    Related: issue #1430 (multi-workspace architecture per user 2026-04-19),
    PROPOSAL nanoclaw 2026-04-16, lessons from #1423.
#>

param(
    [string]$Workspaces = "",

    [string]$Workspace = "",

    [string]$AllowedWorkspaces = "",

    [string]$AllowedTags = "ASK,TASK,BLOCKED",

    [string]$AllowedAuthors = "",

    [string]$LockDir = "",

    [switch]$Stub = $true,

    [string]$SpawnScript = "",

    [string]$McpConfig = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

if ([string]::IsNullOrEmpty($LockDir)) {
    $LockDir = Join-Path $RepoRoot ".claude/locks"
}
if ([string]::IsNullOrEmpty($SpawnScript)) {
    $SpawnScript = Join-Path $scriptDir "spawn-claude.ps1"
}

# Issue #1448: `claude -p` subprocess does NOT load ~/.claude.json by default,
# so MCP tools (roo-state-manager) are absent and Invoke-DashboardRead fails with
# "ERROR: Could not parse message into JSON". Pass --mcp-config explicitly.
if ([string]::IsNullOrEmpty($McpConfig)) {
    $McpConfig = Join-Path $HOME ".claude.json"
}

if (-not (Test-Path $LockDir)) {
    New-Item -ItemType Directory -Path $LockDir -Force | Out-Null
}

$tagList = $AllowedTags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
$authorList = @()
if (-not [string]::IsNullOrEmpty($AllowedAuthors)) {
    $authorList = $AllowedAuthors -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

function Write-Log($level, $msg) {
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    Write-Host "[$ts] [$level] $msg"
}

function Get-LockFile($ws) {
    return Join-Path $LockDir "watcher-$ws.lastack"
}

function Get-LastAckTimestamp($ws) {
    $lockFile = Get-LockFile $ws
    if (Test-Path $lockFile) {
        return (Get-Content $lockFile -Raw).Trim()
    }
    return ""
}

function Set-LastAckTimestamp($ws, $timestamp) {
    $lockFile = Get-LockFile $ws
    [System.IO.File]::WriteAllText(
        $lockFile,
        $timestamp,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Resolve-Workspaces {
    # Priority: explicit -Workspaces > legacy -Workspace > auto-discover
    if (-not [string]::IsNullOrEmpty($Workspaces)) {
        return $Workspaces -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }
    if (-not [string]::IsNullOrEmpty($Workspace)) {
        return @($Workspace)
    }

    # Auto-discover from $ROOSYNC_SHARED_PATH/dashboards/workspace-*.md
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($sharedPath) -or -not (Test-Path $sharedPath)) {
        Write-Log "WARN" "Cannot auto-discover: ROOSYNC_SHARED_PATH unset or missing. Provide -Workspaces."
        return @()
    }
    $dashboardDir = Join-Path $sharedPath "dashboards"
    if (-not (Test-Path $dashboardDir)) {
        Write-Log "WARN" "Auto-discover: dashboards dir not found at $dashboardDir"
        return @()
    }

    $discovered = Get-ChildItem -Path $dashboardDir -Filter "workspace-*.md" -File |
                  ForEach-Object { $_.BaseName -replace '^workspace-', '' }

    # Apply -AllowedWorkspaces filter if provided
    if (-not [string]::IsNullOrEmpty($AllowedWorkspaces)) {
        $allowed = $AllowedWorkspaces -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $discovered = $discovered | Where-Object { $allowed -contains $_ }
    }
    return @($discovered)
}

function Invoke-DashboardRead($ws) {
    # Call roo-state-manager MCP via the claude CLI in a cheap way.
    # This is the only part that reaches out to the MCP; it does not consume
    # Opus tokens (uses the default fast model for a pure tool call).
    $promptFile = [System.IO.Path]::GetTempFileName()
    $payload = @{
        action = "read"
        type = "workspace"
        workspace = $ws
        section = "intercom"
        intercomLimit = 20
    } | ConvertTo-Json -Compress

    # Use roo-state-manager via claude -p with minimal prompt.
    # The MCP tool returns the JSON payload; we parse messages out.
    $prompt = @"
Call the MCP tool roo-state-manager.roosync_dashboard with these exact parameters and output ONLY the raw JSON response:

$payload
"@
    Set-Content -Path $promptFile -Value $prompt -Encoding UTF8 -NoNewline

    try {
        # claude -p with haiku to minimize cost of the read.
        # --mcp-config is REQUIRED (#1448): subprocess does not inherit user MCP config,
        # so roo-state-manager must be loaded explicitly.
        if (-not (Test-Path $McpConfig)) {
            Write-Log "ERROR" "MCP config file not found: $McpConfig (needed to load roo-state-manager)"
            throw "MCP config missing"
        }
        $result = & claude -p --model haiku --mcp-config $McpConfig --output-format json (Get-Content $promptFile -Raw) 2>&1 |
                  Out-String
        return $result
    } finally {
        Remove-Item -Path $promptFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-ActionableMessage($msg, $lastAck) {
    # Tag check: content should contain at least one allowed tag
    $content = $msg.content
    $hasTag = $false
    foreach ($tag in $tagList) {
        # Tags appear either as bracketed markers [TAG] or in tags array.
        if ($content -match "\[$tag\b") { $hasTag = $true; break }
        if ($msg.PSObject.Properties['tags'] -and ($msg.tags -contains $tag)) {
            $hasTag = $true; break
        }
    }
    if (-not $hasTag) { return $false }

    # Author check if restricted
    if ($authorList.Count -gt 0) {
        $authorId = if ($msg.author) { $msg.author.machineId } else { "" }
        if (-not ($authorList -contains $authorId)) { return $false }
    }

    # Timestamp check: strictly newer than lastAck
    if ([string]::IsNullOrEmpty($lastAck)) {
        return $true
    }
    try {
        $msgTs = [DateTime]::Parse($msg.timestamp).ToUniversalTime()
        $ackTs = [DateTime]::Parse($lastAck).ToUniversalTime()
        return $msgTs -gt $ackTs
    } catch {
        Write-Log "WARN" "Failed to parse timestamps (msg=$($msg.timestamp), ack=$lastAck): $_"
        return $false
    }
}

# ========== MAIN ==========

$wsList = Resolve-Workspaces
if ($wsList.Count -eq 0) {
    Write-Log "WARN" "No workspaces to poll (provide -Workspaces or set ROOSYNC_SHARED_PATH). Exit 0."
    exit 0
}

Write-Log "INFO" "Polling $($wsList.Count) workspace(s): $($wsList -join ', ') | tags=[$AllowedTags] authors=[$AllowedAuthors] stub=$Stub"

$overallExitCode = 0
$spawnErrors = 0

foreach ($ws in $wsList) {
    Write-Log "INFO" "--- Workspace: $ws ---"

    $lastAck = Get-LastAckTimestamp $ws
    if ([string]::IsNullOrEmpty($lastAck)) {
        Write-Log "INFO" "[$ws] No last-ACK marker, treating as first run."
    } else {
        Write-Log "INFO" "[$ws] Last ACK timestamp: $lastAck"
    }

    try {
        $raw = Invoke-DashboardRead $ws
    } catch {
        Write-Log "ERROR" "[$ws] Dashboard read failed: $_"
        $overallExitCode = 2
        continue
    }

    # Extract JSON from claude -p output (it may include preamble text).
    $jsonMatch = [regex]::Match($raw, '\{[\s\S]*"intercom"[\s\S]*\}')
    if (-not $jsonMatch.Success) {
        Write-Log "ERROR" "[$ws] Could not extract intercom JSON from dashboard response."
        Write-Log "DEBUG" "[$ws] Raw output (first 500 chars): $($raw.Substring(0, [Math]::Min(500, $raw.Length)))"
        $overallExitCode = 3
        continue
    }

    try {
        $parsed = $jsonMatch.Value | ConvertFrom-Json
    } catch {
        Write-Log "ERROR" "[$ws] JSON parse failed: $_"
        $overallExitCode = 3
        continue
    }

    $messages = @()
    if ($parsed.data -and $parsed.data.intercom -and $parsed.data.intercom.messages) {
        $messages = $parsed.data.intercom.messages
    } elseif ($parsed.intercom -and $parsed.intercom.messages) {
        $messages = $parsed.intercom.messages
    }

    Write-Log "INFO" "[$ws] Received $($messages.Count) message(s) from dashboard."

    $actionable = @()
    foreach ($msg in $messages) {
        if (Test-ActionableMessage $msg $lastAck) {
            $actionable += $msg
        }
    }

    if ($actionable.Count -eq 0) {
        Write-Log "INFO" "[$ws] No actionable messages since last ACK."
        continue
    }

    Write-Log "INFO" "[$ws] Found $($actionable.Count) actionable message(s)."
    $latestTs = ($actionable | Sort-Object -Property timestamp | Select-Object -Last 1).timestamp

    if ($Stub) {
        Write-Log "STUB" "[$ws] Would spawn: $SpawnScript -Workspace $ws -Since $lastAck"
        foreach ($msg in $actionable) {
            $preview = $msg.content.Substring(0, [Math]::Min(120, $msg.content.Length)).Replace("`n", " ")
            Write-Log "STUB" "[$ws]   [$($msg.timestamp)] $($msg.author.machineId): $preview..."
        }

        # Still advance the ACK marker so the same messages don't trip the stub twice.
        Set-LastAckTimestamp $ws $latestTs
        Write-Log "INFO" "[$ws] Last-ACK marker advanced to $latestTs."
        continue
    }

    # Phase 2: real spawn
    if (-not (Test-Path $SpawnScript)) {
        Write-Log "ERROR" "[$ws] SpawnScript not found: $SpawnScript"
        $overallExitCode = 4
        $spawnErrors++
        continue
    }

    Write-Log "INFO" "[$ws] Invoking spawn-claude.ps1 for $($actionable.Count) message(s)..."
    $spawnArgs = @(
        "-Workspace", $ws,
        "-Since", $lastAck,
        "-Model", "opus",
        "-McpConfig", $McpConfig
    )
    & pwsh -File $SpawnScript @spawnArgs
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Set-LastAckTimestamp $ws $latestTs
        Write-Log "INFO" "[$ws] Spawn completed cleanly. Last-ACK advanced to $latestTs."
    } else {
        Write-Log "WARN" "[$ws] Spawn exited with code $exitCode. Last-ACK NOT advanced (will retry next poll)."
        $spawnErrors++
        $overallExitCode = $exitCode
    }
}

if ($spawnErrors -gt 0) {
    Write-Log "WARN" "Summary: $spawnErrors spawn error(s) across $($wsList.Count) workspace(s). Exit $overallExitCode."
} else {
    Write-Log "INFO" "Summary: $($wsList.Count) workspace(s) processed without spawn errors."
}

exit $overallExitCode
