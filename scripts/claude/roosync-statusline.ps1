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
echo '{"model":"glm-5.1","cwd":"c:/dev/roo-extensions"}' | pwsh -File roosync-statusline.ps1 -Preset normal
#>

param(
    [ValidateSet('minimal', 'normal', 'verbose')]
    [string]$Preset = 'normal'
)

$ErrorActionPreference = 'SilentlyContinue'

# Known machines in the cluster
$knownMachines = @('myia-ai-01', 'myia-po-2023', 'myia-po-2024', 'myia-po-2025', 'myia-po-2026', 'myia-web1')

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
$offlineMachines = @()

foreach ($machineId in $knownMachines) {
    $pFile = Join-Path $presenceDir "$machineId.json"
    if (Test-Path $pFile) {
        try {
            $raw = [System.IO.File]::ReadAllText($pFile, [System.Text.UTF8Encoding]::new($false))
            $p = $raw | ConvertFrom-Json

            $lastSeen = [DateTime]::MinValue
            if ($p.lastSeen) {
                [DateTime]::TryParse($p.lastSeen, [ref]$lastSeen) | Out-Null
            }
            $staleMinutes = if ($lastSeen -gt [DateTime]::MinValue) {
                ((Get-Date) - $lastSeen).TotalMinutes
            } else { 999 }

            switch ($p.status) {
                'offline'  { $offlineCount++; $offlineMachines += $machineId }
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
            $offlineCount++; $offlineMachines += $machineId
        }
    } else {
        $offlineCount++; $offlineMachines += $machineId
    }
}

$totalCount = $knownMachines.Count

# --- Parse workspace dashboard for claims and stages ---
$claimsCount = 0
$claimsList = @()
$activeStage = ''
$inboxUrgent = 0

$dashboardsDir = Join-Path $sharedPath 'dashboards'
$wsDashboard = Get-ChildItem $dashboardsDir -Filter 'workspace-roo-extensions.md' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($wsDashboard) {
    try {
        $wsContent = [System.IO.File]::ReadAllText($wsDashboard.FullName, [System.Text.UTF8Encoding]::new($false))

        # Extract active claims from intercom messages (last 50KB for performance)
        $recentContent = if ($wsContent.Length -gt 51200) {
            $wsContent.Substring($wsContent.Length - 51200)
        } else { $wsContent }

        $claimMatches = [regex]::Matches($recentContent, '\[#?(\d+)\][^\n]*CLAIMED|CLAIMED[^\n]*\[#?(\d+)\]|#(\d+)[^\n]*CLAIMED')
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

        # Extract active team stage from recent [PROGRESS] or [CLAIMED] messages
        $progressMatches = [regex]::Matches($recentContent, '\[PROGRESS\][^\n]*team-(\w+)')
        if ($progressMatches.Count -gt 0) {
            $activeStage = "team-$($progressMatches[$progressMatches.Count - 1].Groups[1].Value)"
        } else {
            # Fallback: extract issue number from [CLAIMED]
            $claimedMatch = [regex]::Match($recentContent, '\[CLAIMED\][^\n]*#(\d+)')
            if ($claimedMatch.Success) {
                $activeStage = "#$($claimedMatch.Groups[1].Value)"
            }
        }

        # Count urgent inbox messages
        $inboxUrgent = ([regex]::Matches($recentContent, '\[URGENT\]')).Count

    } catch {
        # Dashboard parsing is optional
    }
}

# --- Determine overall status ---
$status = 'OK'
if ($offlineCount -gt 2) {
    $status = 'CRIT'
} elseif ($offlineCount -gt 0) {
    $status = 'WARN'
} elseif ($warningCount -gt 0) {
    $status = 'DEGRADED'
}

# --- Build output ---
switch ($Preset) {
    'minimal' {
        $stagePart = if ($activeStage) { " $activeStage" } else { '' }
        Write-Output "$status $onlineCount/$totalCount$stagePart"
    }

    'normal' {
        $parts = @("$onlineCount/$totalCount")

        if ($claimsCount -gt 0) {
            $parts += "${claimsCount}clm"
        }

        if ($activeStage) {
            $parts += $activeStage
        }

        if ($branch -and $branch -ne 'main') {
            $shortBranch = if ($branch.Length -gt 20) {
                $branch.Substring(0, 17) + '...'
            } else {
                $branch
            }
            $parts += $shortBranch
        }

        # Urgent flag
        if ($inboxUrgent -gt 0) {
            $parts += "U=$inboxUrgent"
        }

        Write-Output ($parts -join ' | ')
    }

    'verbose' {
        $parts = @("$status $onlineCount/$totalCount machines")

        if ($offlineMachines.Count -gt 0) {
            $shortNames = $offlineMachines | ForEach-Object { ($_ -split '-')[1..2] -join '-' }
            $parts += "OFF: $($shortNames -join ',')"
        }

        if ($claimsCount -gt 0) {
            $parts += "${claimsCount} claims: $($claimsList -join ',')"
        }

        if ($activeStage) {
            $parts += "Stage: $activeStage"
        }

        # Dashboard count (last 24h)
        $cutoff = (Get-Date).AddHours(-24)
        $dashFiles = Get-ChildItem $dashboardsDir -Filter '*.md' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^machine-|^global|^workspace' -and $_.LastWriteTime -gt $cutoff }
        $parts += "$(@($dashFiles).Count) dash"

        if ($branch) { $parts += $branch }

        if ($model) {
            $shortModel = $model -replace '.*glm-', 'glm' -replace '.*claude-', 'cl'
            $parts += $shortModel
        }

        Write-Output ($parts -join ' | ')
    }
}
