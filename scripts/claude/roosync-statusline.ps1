<#
.SYNOPSIS
RooSync HUD Statusline for Claude Code

.DESCRIPTION
Reads RooSync shared state files (presence, workspace dashboard) and outputs
a compact status line for the Claude Code terminal status bar.

Data sources:
  - presence/myia-*.json : Machine online/offline status
  - dashboards/workspace-roo-extensions.md : Active claims & team stages

Receives session context via stdin JSON from Claude Code, outputs
formatted status text to stdout.

.PARAMETER Preset
Output detail level: minimal, normal (default), verbose

.EXAMPLE
echo '{"model":"glm-5.1","cwd":"c:/dev/roo-extensions"}' | powershell -File roosync-statusline.ps1 -Preset normal
#>

param(
    [ValidateSet('minimal', 'normal', 'verbose')]
    [string]$Preset = 'normal'
)

$ErrorActionPreference = 'SilentlyContinue'

# --- Resolve shared state path ---
$sharedPath = $env:ROOSYNC_SHARED_PATH
if (-not $sharedPath -or -not (Test-Path $sharedPath)) {
    $sharedPath = 'G:\Mon Drive\Synchronisation\RooSync\.shared-state'
}
if (-not (Test-Path $sharedPath)) {
    $sharedPath = 'D:\Mon Drive\Synchronisation\RooSync\.shared-state'
}
if (-not (Test-Path $sharedPath)) {
    Write-Output "RooSync: NO_SHARED_PATH"
    exit 0
}

# --- Parse stdin JSON for session context ---
$sessionId = ''
$model = ''
$cwd = ''
$branch = ''

try {
    $stdin = [Console]::In.ReadToEnd()
    if ($stdin) {
        $ctx = $stdin | ConvertFrom-Json
        $model = if ($ctx.model) { $ctx.model } else { '' }
        $cwd = if ($ctx.cwd) { $ctx.cwd } else { '' }

        if ($cwd -and (Test-Path $cwd)) {
            Push-Location $cwd
            $branch = git branch --show-current 2>$null
            Pop-Location
        }
    }
} catch {
    # Stdin parsing is optional
}

# --- Read machine status from presence/ directory ---
$presenceDir = Join-Path $sharedPath 'presence'
$onlineCount = 0
$offlineCount = 0
$warningCount = 0
$totalCount = 0
$offlineMachines = @()

if (Test-Path $presenceDir) {
    $pFiles = Get-ChildItem $presenceDir -Filter 'myia-*.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^myia-[a-z0-9-]+\.json$' }
    $totalCount = @($pFiles).Count

    foreach ($f in $pFiles) {
        try {
            $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.UTF8Encoding]::new($false))
            $p = $raw | ConvertFrom-Json

            # Consider stale (>30min) as warning
            $lastSeen = [DateTime]::MinValue
            if ($p.lastSeen) {
                [DateTime]::TryParse($p.lastSeen, [ref]$lastSeen) | Out-Null
            }
            $staleMinutes = if ($lastSeen -gt [DateTime]::MinValue) {
                ((Get-Date) - $lastSeen).TotalMinutes
            } else { 999 }

            switch ($p.status) {
                'offline'  { $offlineCount++; $offlineMachines += $p.id }
                'warning'  { $warningCount++ }
                default {
                    if ($staleMinutes -gt 30) {
                        $warningCount++
                    } else {
                        $onlineCount++
                    }
                }
            }
        } catch {
            $offlineCount++
        }
    }
}

# Fallback to heartbeats/ if presence/ has no data
if ($totalCount -eq 0) {
    $heartbeatsDir = Join-Path $sharedPath 'heartbeats'
    if (Test-Path $heartbeatsDir) {
        $hbFiles = Get-ChildItem $heartbeatsDir -Filter 'myia-*.json' -ErrorAction SilentlyContinue
        $totalCount = @($hbFiles).Count

        foreach ($f in $hbFiles) {
            try {
                $hb = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                switch ($hb.status) {
                    'offline'  { $offlineCount++; $offlineMachines += $hb.machineId }
                    'warning'  { $warningCount++ }
                    default    { $onlineCount++ }
                }
            } catch {
                $offlineCount++
            }
        }
    }
    if ($totalCount -eq 0) { $totalCount = 6 }
}

# --- Parse workspace dashboard for claims and stages ---
$claimsCount = 0
$claimsList = @()
$activeStage = ''

$dashboardsDir = Join-Path $sharedPath 'dashboards'
$wsDashboard = Get-ChildItem $dashboardsDir -Filter 'workspace-roo-extensions.md' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($wsDashboard) {
    try {
        $wsContent = [System.IO.File]::ReadAllText($wsDashboard.FullName, [System.Text.UTF8Encoding]::new($false))

        # Extract active claims: patterns like "CLAIMED" or "[CLAIMED]" followed by issue numbers
        $claimMatches = [regex]::Matches($wsContent, '\[#?(\d+)\][^\n]*CLAIMED|CLAIMED[^\n]*\[#?(\d+)\]|#(\d+)[^\n]*CLAIMED')
        $claimIssues = @{}
        foreach ($m in $claimMatches) {
            foreach ($g in $m.Groups) {
                if ($g.Value -match '^\d+$' -and $g.Value -ne '0') {
                    $claimIssues[$g.Value] = $true
                }
            }
        }
        $claimsCount = $claimIssues.Count
        $claimsList = $claimIssues.Keys | Sort-Object

        # Extract active team stage from "En cours" section
        if ($wsContent -match '### En cours\s*\n((?:-.*\n?)+)') {
            $enCours = $Matches[1]
            if ($enCours -match '#(\d+).*Phase\s+([A-Z0-9]+)') {
                $activeStage = "Phase $($Matches[2])"
            } elseif ($enCours -match 'team-(\w+)') {
                $activeStage = "team-$($Matches[1])"
            } elseif ($enCours -match '#(\d+)') {
                $activeStage = "#$($Matches[1])"
            }
        }
    } catch {
        # Dashboard parsing is optional
    }
}

# --- Determine overall status ---
$status = 'OK'
if ($offlineCount -gt 0) {
    $status = 'CRIT'
} elseif ($warningCount -gt 0) {
    $status = 'WARN'
}

# --- Build output ---
switch ($Preset) {
    'minimal' {
        # Stage + machines
        $stagePart = if ($activeStage) { " $activeStage" } else { '' }
        Write-Output "$status$stagePart $onlineCount/$totalCount"
    }

    'normal' {
        $parts = @("$status $onlineCount/$totalCount")

        # Active claims
        if ($claimsCount -gt 0) {
            $parts += "${claimsCount} claim$(if ($claimsCount -gt 1) { 's' })"
        }

        # Active stage
        if ($activeStage) {
            $parts += $activeStage
        }

        # Branch info
        if ($branch) {
            $shortBranch = if ($branch.Length -gt 25) {
                $branch.Substring(0, 22) + '...'
            } else {
                $branch
            }
            $parts += $shortBranch
        }

        Write-Output ($parts -join ' | ')
    }

    'verbose' {
        $parts = @("$status $onlineCount/$totalCount machines")

        if ($offlineMachines.Count -gt 0) {
            $parts += "OFFLINE: $($offlineMachines -join ', ')"
        }

        if ($claimsCount -gt 0) {
            $parts += "${claimsCount} claims: $($claimsList -join ',')"
        }

        if ($activeStage) {
            $parts += "Stage: $activeStage"
        }

        # Dashboard count
        $cutoff = (Get-Date).AddHours(-24)
        $dashFiles = Get-ChildItem $dashboardsDir -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^machine-|^global|^workspace' -and $_.LastWriteTime -gt $cutoff }
        $parts += "$(@($dashFiles).Count) dashboards"

        if ($branch) { $parts += $branch }

        if ($model) {
            $shortModel = $model -replace '.*glm-', 'g' -replace '.*claude-', 'c'
            $parts += $shortModel
        }

        Write-Output ($parts -join ' | ')
    }
}
