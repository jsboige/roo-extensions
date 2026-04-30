#!/usr/bin/env pwsh
<#
.SYNOPSIS
  RooSync HUD Statusline — #1855
  Displays real-time RooSync orchestration metrics from shared state files.

.DESCRIPTION
  Reads heartbeat and dashboard files directly from the GDrive shared state path.
  No MCP dependency — works from any terminal.

.PARAMETER Preset
  Display preset: minimal (default), verbose, focused

.PARAMETER SharedPath
  Override ROOSYNC_SHARED_PATH env var

.EXAMPLE
  .\roosync-statusline.ps1
  .\roosync-statusline.ps1 -Preset verbose
  .\roosync-statusline.ps1 -Preset minimal
#>

param(
    [ValidateSet('minimal', 'verbose', 'focused')]
    [string]$Preset = 'minimal',
    [string]$SharedPath = ''
)

$ErrorActionPreference = 'SilentlyContinue'

# Resolve shared state path
if (-not $SharedPath) {
    $SharedPath = $env:ROOSYNC_SHARED_PATH
}
if (-not $SharedPath) {
    # Try .env file from roo-state-manager
    $repoRoot = Join-Path (Join-Path $PSScriptRoot '..') '..'
    $resolvedRoot = if ($repoRoot) { [System.IO.Path]::GetFullPath($repoRoot) } else { '' }
    $envFile = if ($resolvedRoot) { Join-Path $resolvedRoot 'mcps\internal\servers\roo-state-manager\.env' } else { '' }
    if ($envFile -and (Test-Path $envFile)) {
        $raw = [System.IO.File]::ReadAllText($envFile)
        if ($raw -match 'ROOSYNC_SHARED_PATH\s*=\s*"?([^"\r\n]+)"?') {
            $SharedPath = $Matches[1].Trim()
        }
    }
}
if (-not $SharedPath) {
    Write-Host '[RooSync] SHARED_PATH not found' -ForegroundColor Red
    exit 1
}

# --- Data Collection ---

# Heartbeat data
$heartbeatDir = Join-Path $SharedPath 'heartbeats'
$online = @(); $offline = @(); $warning = @()
$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$staleThreshold = 10 * 60 * 1000  # 10 min
$offlineThreshold = 30 * 60 * 1000 # 30 min

if (Test-Path $heartbeatDir) {
    Get-ChildItem $heartbeatDir -Filter '*.json' | ForEach-Object {
        $name = $_.BaseName
        # Filter test artifacts
        if ($name -notmatch '^myia-') { return }

        try {
            $hb = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $lastHb = [DateTimeOffset]::Parse($hb.lastHeartbeat).ToUnixTimeMilliseconds()
            $age = $now - $lastHb

            if ($age -gt $offlineThreshold) {
                $offline += $name
            } elseif ($age -gt $staleThreshold) {
                $warning += $name
            } else {
                $online += $name
            }
        } catch {
            $offline += $name
        }
    }
}

$total = $online.Count + $offline.Count + $warning.Count

# Dashboard intercom data
$dashDir = Join-Path $SharedPath 'dashboards'
$activeClaims = @()
$activeStages = @()
$twoHoursAgo = $now - (2 * 60 * 60 * 1000)

$dashboardFile = Join-Path $dashDir 'workspace-roo-extensions.md'
if (Test-Path $dashboardFile) {
    $content = Get-Content $dashboardFile -Raw -Encoding UTF8

    # Extract intercom section
    if ($content -match '(?s)## Intercom\s*\n(.+)') {
        $intercom = $Matches[1]
        if ($intercom -notmatch '\*Aucun message\.\*') {
            # Split message blocks
            $blocks = $intercom -split '(?m)(?=^### \[)' | Where-Object { $_.Trim() }
            foreach ($block in $blocks) {
                $block = ($block -replace '(?m)\n---\s*$', '').Trim()
                if ($block -match '###\s+\[([^\]]+)\]\s+([^|]+)\|(\S+)') {
                    $ts = $Matches[1]
                    $machineId = $Matches[2].Trim()
                    $msgContent = ($block -replace '(?m)^###\s+\[[^\]]+\]\s+[^|]+\|\S+.*\n', '').Trim()

                    try {
                        $tsMs = [DateTimeOffset]::Parse($ts).ToUnixTimeMilliseconds()
                    } catch { continue }
                    if ($tsMs -lt $twoHoursAgo) { continue }

                    # CLAIMED
                    if ($msgContent -match '\[CLAIMED\]') {
                        $issue = 'unknown'
                        if ($msgContent -match '#(\d+)') { $issue = "#$($Matches[1])" }
                        $activeClaims += @{ machine = $machineId; issue = $issue }
                    }

                    # Pipeline stages
                    $stages = [regex]::Matches($msgContent, '\[(PLAN|PRD|EXEC|VERIFY|FIX|BLOCKED)\]')
                    foreach ($s in $stages) {
                        $activeStages += @{ machine = $machineId; stage = $s.Groups[1].Value }
                    }
                }
            }
        }
    }
}

# --- Output Formatting ---

$statusColor = if ($offline.Count -gt 0) { 'Red' }
               elseif ($warning.Count -gt 0) { 'Yellow' }
               else { 'Green' }

$statusLabel = if ($offline.Count -gt 0) { 'CRITICAL' }
               elseif ($warning.Count -gt 0) { 'WARNING' }
               else { 'HEALTHY' }

function Short-Machine([string]$m) {
    # myia-po-2023 → po23, myia-ai-01 → ai01, myia-web1 → web1
    if ($m -match 'myia-(ai|web)\d*$') { return $Matches[1] }
    if ($m -match 'myia-po-(\d{2})(\d+)$') { return "po$($Matches[1])$($Matches[2])" }
    return $m
}

switch ($Preset) {
    'minimal' {
        # One line: [RooSync] HEALTHY | 5/6 agents | 2 claims | EXEC:po23 VERIFY:po24
        $parts = @()
        $parts += "[$statusLabel]"
        $parts += "$($online.Count)/$total agents"
        if ($activeClaims.Count -gt 0) {
            $parts += "$($activeClaims.Count) claim$(if ($activeClaims.Count -gt 1) { 's' })"
        }
        if ($activeStages.Count -gt 0) {
            $stageStr = ($activeStages | ForEach-Object { "$($_.stage):$(Short-Machine $_.machine)" }) -join ' '
            $parts += $stageStr
        }
        if ($offline.Count -gt 0) {
            $parts += "OFFLINE:$($offline -join ',')"
        }
        Write-Host "[$(Get-Date -Format 'HH:mm')]" -ForegroundColor DarkGray -NoNewline
        Write-Host " $($parts -join ' | ')" -ForegroundColor $statusColor
    }

    'verbose' {
        Write-Host "=== RooSync Status ===" -ForegroundColor Cyan
        Write-Host "Status: " -NoNewline; Write-Host $statusLabel -ForegroundColor $statusColor
        Write-Host "Agents: $($online.Count) online / $($warning.Count) warning / $($offline.Count) offline (total: $total)"
        if ($online.Count -gt 0) {
            Write-Host "  Online : $($online -join ', ')" -ForegroundColor Green
        }
        if ($warning.Count -gt 0) {
            Write-Host "  Warning: $($warning -join ', ')" -ForegroundColor Yellow
        }
        if ($offline.Count -gt 0) {
            Write-Host "  Offline: $($offline -join ', ')" -ForegroundColor Red
        }
        if ($activeClaims.Count -gt 0) {
            Write-Host "`nActive Claims:" -ForegroundColor Cyan
            foreach ($c in $activeClaims) {
                Write-Host "  $($c.machine) → $($c.issue)" -ForegroundColor White
            }
        }
        if ($activeStages.Count -gt 0) {
            Write-Host "`nPipeline Stages:" -ForegroundColor Cyan
            foreach ($s in $activeStages) {
                Write-Host "  $($s.stage) → $($s.machine)" -ForegroundColor White
            }
        }
    }

    'focused' {
        # Agent-centric: one line per active agent with their claim/stage
        Write-Host "[$statusLabel] $($online.Count)/$total" -ForegroundColor $statusColor -NoNewline
        Write-Host " | " -NoNewline

        $agentParts = @()
        foreach ($m in ($online + $warning)) {
            $short = Short-Machine $m
            $stage = $activeStages | Where-Object { $_.machine -eq $m } | Select-Object -First 1
            $claim = $activeClaims | Where-Object { $_.machine -eq $m } | Select-Object -First 1
            if ($stage) {
                $agentParts += "${short}:$($stage.stage)"
            } elseif ($claim) {
                $agentParts += "${short}:$($claim.issue)"
            } else {
                $agentParts += "${short}:idle"
            }
        }
        Write-Host ($agentParts -join ' ')
    }
}
