# Deploy-RooSettings.ps1
# Wrapper for roo-settings-manager.py to deploy Roo settings across machines
#
# Usage:
#   .\Deploy-RooSettings.ps1 -Action extract [-Output settings.json] [-Full]
#   .\Deploy-RooSettings.ps1 -Action inject -Input settings.json [-DryRun] [-Keys "key1,key2"]
#   .\Deploy-RooSettings.ps1 -Action get -Key "autoCondenseContextPercent"
#   .\Deploy-RooSettings.ps1 -Action set -Key "autoCondenseContextPercent" -Value "80" [-DryRun]
#   .\Deploy-RooSettings.ps1 -Action diff -Reference baseline.json
#   .\Deploy-RooSettings.ps1 -Action publish [-Version "1.0.0"] [-Description "desc"]
#   .\Deploy-RooSettings.ps1 -Action apply [-Version "latest"] [-DryRun]
#
# Issue: #509

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("extract", "inject", "get", "set", "diff", "publish", "apply", "status")]
    [string]$Action,

    [string]$Output,
    [string]$Input,
    [string]$Key,
    [string]$Value,
    [string]$Reference,
    [string]$Keys,
    [string]$Version = "latest",
    [string]$Description,
    [switch]$Full,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "roo-settings-manager.py"
$RepoRoot = (Get-Item $ScriptDir).Parent.Parent.FullName

# Shared state path for publish/apply
$SharedPath = $env:ROOSYNC_SHARED_PATH
if (-not $SharedPath) {
    $SharedPath = "G:\Mon Drive\Synchronisation\RooSync\.shared-state"
}
$SettingsSharedDir = Join-Path $SharedPath "settings"
$MachineId = $env:COMPUTERNAME.ToLower()

function Test-Python {
    try {
        $null = python --version 2>&1
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-Python)) {
    Write-Error "Python is required but not found in PATH"
    exit 1
}

if (-not (Test-Path $PythonScript)) {
    Write-Error "roo-settings-manager.py not found at: $PythonScript"
    exit 1
}

switch ($Action) {
    "extract" {
        $args = @("extract")
        if ($Output) { $args += @("-o", $Output) }
        if ($Full) { $args += "--full" }
        & python $PythonScript @args
    }

    "inject" {
        if (-not $Input) { Write-Error "-Input is required for inject"; exit 1 }
        $args = @("inject", "-i", $Input)
        if ($DryRun) { $args += "--dry-run" }
        if ($Keys) { $args += @("--keys", $Keys) }
        & python $PythonScript @args
    }

    "get" {
        if (-not $Key) { Write-Error "-Key is required for get"; exit 1 }
        & python $PythonScript get $Key
    }

    "set" {
        if (-not $Key) { Write-Error "-Key is required for set"; exit 1 }
        if (-not $Value) { Write-Error "-Value is required for set"; exit 1 }
        $args = @("set", $Key, $Value)
        if ($DryRun) { $args += "--dry-run" }
        & python $PythonScript @args
    }

    "diff" {
        if (-not $Reference) { Write-Error "-Reference is required for diff"; exit 1 }
        & python $PythonScript diff -r $Reference
    }

    "publish" {
        # Extract settings and publish to shared GDrive
        Write-Host "[PUBLISH] Extracting settings from $MachineId..." -ForegroundColor Cyan

        $machineDir = Join-Path $SettingsSharedDir $MachineId
        if (-not (Test-Path $machineDir)) {
            New-Item -ItemType Directory -Path $machineDir -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $outputFile = Join-Path $machineDir "roo-settings_${timestamp}.json"

        & python $PythonScript extract -o $outputFile
        if ($LASTEXITCODE -ne 0) { Write-Error "Extract failed"; exit 1 }

        # Also create a 'latest' symlink/copy
        $latestFile = Join-Path $machineDir "roo-settings_latest.json"
        Copy-Item $outputFile $latestFile -Force

        Write-Host "[PUBLISH] Settings published to: $outputFile" -ForegroundColor Green
        Write-Host "[PUBLISH] Latest: $latestFile" -ForegroundColor Green
    }

    "apply" {
        # Apply settings from shared GDrive (from another machine's export)
        $sourceDir = Join-Path $SettingsSharedDir $MachineId

        if ($Version -eq "latest") {
            $sourceFile = Join-Path $sourceDir "roo-settings_latest.json"
        } else {
            # Look for version-specific file
            $sourceFile = Get-ChildItem $sourceDir -Filter "*${Version}*" | Select-Object -First 1 -ExpandProperty FullName
        }

        if (-not $sourceFile -or -not (Test-Path $sourceFile)) {
            Write-Error "No settings file found at: $sourceFile"
            Write-Host "Available machines:" -ForegroundColor Yellow
            if (Test-Path $SettingsSharedDir) {
                Get-ChildItem $SettingsSharedDir -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
            }
            exit 1
        }

        Write-Host "[APPLY] Applying settings from: $sourceFile" -ForegroundColor Cyan

        $args = @("inject", "-i", $sourceFile)
        if ($DryRun) { $args += "--dry-run" }
        & python $PythonScript @args
    }

    "status" {
        # Show current condensation settings
        Write-Host "=== Roo Settings Status ($MachineId) ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Condensation:" -ForegroundColor Yellow
        $condense = & python $PythonScript get autoCondenseContext 2>&1
        $percent = & python $PythonScript get autoCondenseContextPercent 2>&1
        Write-Host "  autoCondenseContext: $condense"
        Write-Host "  autoCondenseContextPercent: $percent"
        Write-Host ""
        Write-Host "Model:" -ForegroundColor Yellow
        $provider = & python $PythonScript get apiProvider 2>&1
        $model = & python $PythonScript get openAiModelId 2>&1
        $mode = & python $PythonScript get mode 2>&1
        Write-Host "  apiProvider: $provider"
        Write-Host "  openAiModelId: $model"
        Write-Host "  mode: $mode"

        # Check shared state
        Write-Host ""
        Write-Host "Shared State:" -ForegroundColor Yellow
        if (Test-Path $SettingsSharedDir) {
            $machines = Get-ChildItem $SettingsSharedDir -Directory
            foreach ($m in $machines) {
                $latest = Join-Path $m.FullName "roo-settings_latest.json"
                if (Test-Path $latest) {
                    $info = Get-Item $latest
                    Write-Host "  $($m.Name): latest=$($info.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
                } else {
                    Write-Host "  $($m.Name): no latest file"
                }
            }
        } else {
            Write-Host "  Shared directory not found: $SettingsSharedDir"
        }
    }
}
