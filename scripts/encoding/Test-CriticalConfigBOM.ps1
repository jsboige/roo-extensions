<#
.SYNOPSIS
    Pre-flight BOM check for critical Roo configuration files

.DESCRIPTION
    Validates that critical Roo config files do NOT contain UTF-8 BOM.
    Fails fast with clear error messages and correction instructions if BOM detected.
    Called by scheduler pre-flight to prevent roo-state-manager startup failures.

.PARAMETER FailFast
    Exit immediately with error code 1 if BOM detected (default: true)

.PARAMETER Detailed
    Show detailed output including BOM byte inspection

.EXAMPLE
    .\Test-CriticalConfigBOM.ps1
    Returns exit code 1 if any critical file has BOM, 0 if all clean

.EXAMPLE
    .\Test-CriticalConfigBOM.ps1 -Detailed
    Shows detailed BOM inspection results for all critical files

.NOTES
    Issue #664: BOM UTF-8 récurrent dans mcp_settings.json
    BOM bytes: 0xEF 0xBB 0xBF (appears as Unicode U+FEFF)
#>

[CmdletBinding()]
param(
    [bool]$FailFast = $true,
    [switch]$Detailed = $false
)

$ErrorActionPreference = "Stop"

# Critical config files to check
$criticalConfigs = @(
    @{
        Path = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
        Name = "mcp_settings.json"
        Critical = $true
    },
    @{
        Path = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\custom_modes.yaml"
        Name = "custom_modes.yaml"
        Critical = $true
    },
    @{
        Path = "$PSScriptRoot\..\..\.roo\schedules.json"
        Name = "schedules.json"
        Critical = $false
    },
    @{
        Path = "$PSScriptRoot\..\.env"
        Name = ".env"
        Critical = $true
    }
)

$hasBOM = $false
$results = @()

Write-Host "=== Roo Critical Config BOM Check (Issue #664) ===" -ForegroundColor Cyan
Write-Host ""

foreach ($config in $criticalConfigs) {
    $filePath = $config.Path -replace "\.\.\.", $PSScriptRoot

    if (-not (Test-Path $filePath)) {
        if ($config.Critical) {
            Write-Host "[$($config.Name)]" -ForegroundColor Yellow -NoNewline
            Write-Host " FILE NOT FOUND: $filePath" -ForegroundColor DarkGray
            $results += @{
                File = $config.Name
                Status = "NOT_FOUND"
                Path = $filePath
            }
        } else {
            Write-Host "[$($config.Name)]" -ForegroundColor Gray -NoNewline
            Write-Host " Skipping (optional, not found)" -ForegroundColor DarkGray
        }
        continue
    }

    # Read first 3 bytes to check for BOM
    $fileStream = [System.IO.File]::OpenRead($filePath)
    try {
        $byte1 = $fileStream.ReadByte()
        $byte2 = $fileStream.ReadByte()
        $byte3 = $fileStream.ReadByte()

        $bomPresent = ($byte1 -eq 0xEF) -and ($byte2 -eq 0xBB) -and ($byte3 -eq 0xBF)

        if ($bomPresent) {
            $hasBOM = $true
            Write-Host "[$($config.Name)]" -ForegroundColor Red -NoNewline
            Write-Host " BOM DETECTED!" -ForegroundColor Red
            Write-Host "  Path: $filePath" -ForegroundColor DarkGray

            if ($Detailed) {
                Write-Host "  First 3 bytes:" -ForegroundColor Gray -NoNewline
                Write-Host " 0x$($byte1.ToString('X2')) 0x$($byte2.ToString('X2')) 0x$($byte3.ToString('X2'))" -ForegroundColor Red
                Write-Host "  Expected BOM pattern: 0xEF 0xBB 0xBF (UTF-8)" -ForegroundColor Gray
            }

            Write-Host ""
            Write-Host "  >> CORRECTION REQUIRED:" -ForegroundColor Yellow
            Write-Host "     1. Remove BOM:" -ForegroundColor White
            Write-Host "        .\scripts\encoding\Remove-UTF8BOM.ps1 `"$filePath`"" -ForegroundColor Cyan
            Write-Host "     2. Or fix with fix-file-encoding:" -ForegroundColor White
            Write-Host "        .\scripts\encoding\fix-file-encoding.ps1 `"$filePath`"" -ForegroundColor Cyan
            Write-Host ""

            $results += @{
                File = $config.Name
                Status = "BOM_DETECTED"
                Path = $filePath
                Bytes = "0x$($byte1.ToString('X2')) 0x$($byte2.ToString('X2')) 0x$($byte3.ToString('X2'))"
            }
        } else {
            Write-Host "[$($config.Name)]" -ForegroundColor Green -NoNewline
            Write-Host " OK (no BOM)" -ForegroundColor Green

            if ($Detailed) {
                Write-Host "  First 3 bytes:" -ForegroundColor Gray -NoNewline
                Write-Host " 0x$($byte1.ToString('X2')) 0x$($byte2.ToString('X2')) 0x$($byte3.ToString('X2'))" -ForegroundColor Green
            }

            $results += @{
                File = $config.Name
                Status = "OK"
                Path = $filePath
                Bytes = "0x$($byte1.ToString('X2')) 0x$($byte2.ToString('X2')) 0x$($byte3.ToString('X2'))"
            }
        }
    } finally {
        $fileStream.Close()
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($hasBOM) {
    Write-Host "STATUS: BOM DETECTED in critical config files!" -ForegroundColor Red
    Write-Host ""
    Write-Host "IMPACT:" -ForegroundColor Yellow
    Write-Host "  - roo-state-manager MCP will FAIL to start" -ForegroundColor Red
    Write-Host "  - Roo scheduler will be NON-FUNCTIONAL" -ForegroundColor Red
    Write-Host "  - Machine will appear SILENT in RooSync" -ForegroundColor Red
    Write-Host ""
    Write-Host "CORRECTION:" -ForegroundColor Yellow
    Write-Host "  Run Remove-UTF8BOM.ps1 on affected files (see above)" -ForegroundColor White
    Write-Host "  Prevent recurrence: Fix #664 - sync-alwaysallow.ps1 line 134" -ForegroundColor White
    Write-Host ""

    if ($FailFast) {
        Write-Host "Exiting with error code 1 (FailFast enabled)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "STATUS: All critical configs are BOM-free" -ForegroundColor Green
    Write-Host ""
    Write-Host "Files checked: $($results.Count)" -ForegroundColor Gray
    $okCount = ($results | Where-Object { $_.Status -eq "OK" }).Count
    Write-Host "OK: $okCount, Issues: 0" -ForegroundColor Green
    Write-Host ""

    exit 0
}
