<#
.SYNOPSIS
RooSync HUD Statusline for Claude Code

.DESCRIPTION
Reads RooSync shared state files and outputs a compact status line
for the Claude Code terminal status bar.

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
    # Last resort: try D: drive (some machines use D:)
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

        # Try to get branch from git context
        if ($cwd -and (Test-Path $cwd)) {
            Push-Location $cwd
            $branch = git branch --show-current 2>$null
            Pop-Location
        }
    }
} catch {
    # Stdin parsing is optional
}

# --- Read heartbeat data from individual machine files ---
$heartbeatsDir = Join-Path $sharedPath 'heartbeats'
$onlineCount = 0
$offlineCount = 0
$warningCount = 0
$totalCount = 0
$offlineMachines = @()
if (Test-Path $heartbeatsDir) {
    $hbFiles = Get-ChildItem $heartbeatsDir -Filter 'myia-*.json' -ErrorAction SilentlyContinue
    $totalCount = @($hbFiles).Count

    foreach ($f in $hbFiles) {
        try {
            $hb = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

            switch ($hb.status) {
                'offline' {
                    $offlineCount++
                    $offlineMachines += $hb.machineId
                }
                'warning' { $warningCount++ }
                default   { $onlineCount++ }
            }
        } catch {
            $offlineCount++
        }
    }
}

# Fallback to root heartbeat.json if no individual files found
if ($totalCount -eq 0) {
    $heartbeatFile = Join-Path $sharedPath 'heartbeat.json'
    if (Test-Path $heartbeatFile) {
        try {
            $hb = Get-Content $heartbeatFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $onlineCount = @($hb.onlineMachines | Where-Object { $_ -match '^myia-' }).Count
            $offlineCount = @($hb.offlineMachines | Where-Object { $_ -match '^myia-' }).Count
            $offlineMachines = @($hb.offlineMachines | Where-Object { $_ -match '^myia-' })
            $totalCount = $onlineCount + $offlineCount
        } catch {
            $totalCount = 6
        }
    } else {
        $totalCount = 6
    }
}

# --- Count active dashboards (modified < 24h) ---
$activeDashboards = 0
$dashboardsDir = Join-Path $sharedPath 'dashboards'
if (Test-Path $dashboardsDir) {
    $cutoff = (Get-Date).AddHours(-24)
    $dashFiles = Get-ChildItem $dashboardsDir -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^machine-|^global|^workspace' -and $_.LastWriteTime -gt $cutoff }
    $activeDashboards = @($dashFiles).Count
}

# --- Determine overall status ---
$status = 'OK'
$statusColor = ''

if ($offlineCount -gt 0) {
    $status = 'CRIT'
} elseif ($warningCount -gt 0) {
    $status = 'WARN'
} else {
    $status = 'OK'
}

# --- Build output ---
switch ($Preset) {
    'minimal' {
        Write-Output "$status $onlineCount/$totalCount"
    }

    'normal' {
        $parts = @("$status $onlineCount/$totalCount")

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

        $parts += "$activeDashboards dashboards"

        if ($branch) {
            $parts += $branch
        }

        # Model shortname
        if ($model) {
            $shortModel = $model -replace '.*glm-', 'g' -replace '.*claude-', 'c'
            $parts += $shortModel
        }

        Write-Output ($parts -join ' | ')
    }
}
