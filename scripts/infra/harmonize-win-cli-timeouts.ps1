<#
.SYNOPSIS
    Verify and fix win-cli timeout configuration (anti-regression #2333)
.DESCRIPTION
    Checks that both win-cli commandTimeout AND Roo transport timeout are >= 600s.
    Can fix drift automatically with -Fix flag.

    Two timeout layers:
    1. Internal: commandTimeout in unrestricted-config.json (or ~/.win-cli-mcp/config.json)
    2. Transport: timeout in Roo mcp_settings.json (per-server)

    Default minimum: 600 seconds (10 minutes).
.PARAMETER Fix
    Automatically restore timeouts to $MinTimeout if drifted
.PARAMETER MinTimeout
    Minimum acceptable timeout in seconds (default 600)
.PARAMETER ConfigPath
    Path to win-cli unrestricted-config.json (auto-detected if omitted)
.PARAMETER RooSettingsPath
    Path to Roo mcp_settings.json (auto-detected if omitted)
.EXAMPLE
    .\harmonize-win-cli-timeouts.ps1           # Check only
    .\harmonize-win-cli-timeouts.ps1 -Fix      # Check and fix
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [int]$MinTimeout = 600,
    [string]$ConfigPath,
    [string]$RooSettingsPath
)

$ErrorCount = 0
$FixCount = 0

# --- Auto-detect paths ---
if (-not $ConfigPath) {
    $candidates = @(
        (Join-Path $env:USERPROFILE '.win-cli-mcp' 'config.json'),
        (Join-Path $PSScriptRoot '..' '..' 'mcps' 'external' 'win-cli' 'unrestricted-config.json')
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $ConfigPath = $c; break }
    }
    if (-not $ConfigPath) {
        # Try repo-relative
        $repoConfig = Join-Path $PSScriptRoot '..' '..' 'mcps' 'external' 'win-cli' 'unrestricted-config.json'
        $repoConfig = [System.IO.Path]::GetFullPath($repoConfig)
        if (Test-Path $repoConfig) { $ConfigPath = $repoConfig }
    }
}

if (-not $RooSettingsPath) {
    $RooSettingsPath = Join-Path $env:APPDATA 'Code' 'User' 'globalStorage' 'rooveterinaryinc.roo-cline' 'settings' 'mcp_settings.json'
}

# --- Layer 1: win-cli internal commandTimeout ---
Write-Host "`n=== Layer 1: win-cli commandTimeout ===" -ForegroundColor Cyan

if ($ConfigPath -and (Test-Path $ConfigPath)) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $currentTimeout = $config.security.commandTimeout

    if ($currentTimeout -lt $MinTimeout) {
        Write-Host "  [WARN] commandTimeout = ${currentTimeout}s (min: ${MinTimeout}s)" -ForegroundColor Yellow
        if ($Fix) {
            $config.security.commandTimeout = $MinTimeout
            [System.IO.File]::WriteAllText($ConfigPath, ($config | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
            Write-Host "  [FIXED] commandTimeout -> ${MinTimeout}s" -ForegroundColor Green
            $FixCount++
        } else {
            Write-Host "  Run with -Fix to restore" -ForegroundColor Gray
            $ErrorCount++
        }
    } else {
        Write-Host "  [OK] commandTimeout = ${currentTimeout}s" -ForegroundColor Green
    }
    Write-Host "  Config: $ConfigPath" -ForegroundColor Gray
} else {
    Write-Host "  [SKIP] No win-cli config found (checked: $ConfigPath)" -ForegroundColor Yellow
}

# --- Layer 2: Roo transport timeout ---
Write-Host "`n=== Layer 2: Roo MCP transport timeout ===" -ForegroundColor Cyan

if (Test-Path $RooSettingsPath) {
    $rooSettings = Get-Content $RooSettingsPath -Raw | ConvertFrom-Json

    # Find win-cli server entry
    $winCliServer = $null
    $winCliKey = $null
    foreach ($prop in $rooSettings.mcpServers.PSObject.Properties) {
        if ($prop.Value.command -match 'win-cli' -or $prop.Name -match 'win-cli' -or
            ($prop.Value.args -and ($prop.Value.args -join ' ') -match 'win-cli')) {
            $winCliServer = $prop.Value
            $winCliKey = $prop.Name
            break
        }
    }

    if ($winCliServer) {
        $transportTimeout = $winCliServer.timeout
        if ($null -eq $transportTimeout) {
            Write-Host "  [WARN] No timeout set (will use default, likely 300s)" -ForegroundColor Yellow
            if ($Fix) {
                $winCliServer | Add-Member -NotePropertyName 'timeout' -NotePropertyValue $MinTimeout -Force
                [System.IO.File]::WriteAllText($RooSettingsPath, ($rooSettings | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
                Write-Host "  [FIXED] timeout -> ${MinTimeout}s" -ForegroundColor Green
                $FixCount++
            } else {
                $ErrorCount++
            }
        } elseif ($transportTimeout -lt $MinTimeout) {
            Write-Host "  [WARN] transport-roo$winCliKey : timeout = ${transportTimeout}s (min: ${MinTimeout}s)" -ForegroundColor Yellow
            if ($Fix) {
                $winCliServer.timeout = $MinTimeout
                [System.IO.File]::WriteAllText($RooSettingsPath, ($rooSettings | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
                Write-Host "  [FIXED] timeout -> ${MinTimeout}s" -ForegroundColor Green
                $FixCount++
            } else {
                Write-Host "  Run with -Fix to restore" -ForegroundColor Gray
                $ErrorCount++
            }
        } else {
            Write-Host "  [OK] timeout = ${transportTimeout}s" -ForegroundColor Green
        }
        Write-Host "  Config: $RooSettingsPath" -ForegroundColor Gray
        Write-Host "  Server key: $winCliKey" -ForegroundColor Gray
    } else {
        Write-Host "  [SKIP] No win-cli server found in mcp_settings.json" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [SKIP] Roo mcp_settings.json not found: $RooSettingsPath" -ForegroundColor Yellow
}

# --- Summary ---
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($Fix) {
    Write-Host "  Fixes applied: $FixCount" -ForegroundColor $(if ($FixCount -gt 0) { 'Green' } else { 'Gray' })
}
if ($ErrorCount -gt 0) {
    Write-Host "  Issues found: $ErrorCount (run with -Fix to resolve)" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "  All timeouts OK (>= ${MinTimeout}s)" -ForegroundColor Green
    exit 0
}
