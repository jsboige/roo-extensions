#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy simple/complex mode pairs to Roo Code

.DESCRIPTION
    Deploys the pilot-simple-complex.roomodes file to the workspace root (.roomodes)
    or to the VS Code global settings. Preserves UTF-8 encoding and validates JSON.

.PARAMETER DeploymentType
    'local' = workspace .roomodes (default)
    'global' = VS Code global custom_modes.json

.PARAMETER Source
    Source .roomodes file. Default: roo-config/modes/pilot-simple-complex.roomodes

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\Deploy-Modes.ps1
    Deploy to local workspace

.EXAMPLE
    .\Deploy-Modes.ps1 -DeploymentType global
    Deploy to VS Code global settings

.EXAMPLE
    .\Deploy-Modes.ps1 -DryRun
    Preview deployment without changes
#>

param(
    [ValidateSet("local", "global")]
    [string]$DeploymentType = "local",

    [string]$Source = "",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Resolve paths
$repoRoot = (Get-Item "$PSScriptRoot\..\.." -ErrorAction SilentlyContinue).FullName
if (-not $repoRoot) {
    $repoRoot = (Get-Item "$PSScriptRoot\.." -ErrorAction SilentlyContinue).FullName
}

if (-not $Source) {
    $Source = Join-Path $repoRoot "roo-config\modes\pilot-simple-complex.roomodes"
}

if (-not (Test-Path $Source)) {
    Write-Host "ERROR: Source file not found: $Source" -ForegroundColor Red
    exit 1
}

# Read source file as raw text (preserves UTF-8 encoding, emojis, etc.)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$sourceContent = [System.IO.File]::ReadAllText($Source, $utf8NoBom)

# Validate JSON
try {
    $parsed = $sourceContent | ConvertFrom-Json
    $modeCount = $parsed.customModes.Count
    Write-Host "Source validated: $modeCount modes found" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Invalid JSON in source file: $_" -ForegroundColor Red
    exit 1
}

# Validate structure
$hasFamilyValidator = $false
$modeNames = @()
foreach ($mode in $parsed.customModes) {
    if ($mode.slug -eq "mode-family-validator") {
        $hasFamilyValidator = $true
        continue
    }
    $modeNames += $mode.slug
    if (-not $mode.model) {
        Write-Host "WARNING: Mode '$($mode.slug)' has no model specified" -ForegroundColor Yellow
    }
}

Write-Host "`nModes to deploy:" -ForegroundColor Cyan
foreach ($name in $modeNames) {
    $suffix = if ($name -match '-simple$') { " (cheap model)" } elseif ($name -match '-complex$') { " (powerful model)" } else { "" }
    Write-Host "  - $name$suffix" -ForegroundColor White
}

if ($hasFamilyValidator) {
    Write-Host "  + mode-family-validator (transition control)" -ForegroundColor Gray
}

# Determine destination
if ($DeploymentType -eq "local") {
    $destination = Join-Path $repoRoot ".roomodes"
} else {
    $globalDir = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
    if (-not (Test-Path $globalDir)) {
        Write-Host "WARNING: VS Code Roo extension settings dir not found: $globalDir" -ForegroundColor Yellow
        Write-Host "Creating directory..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path $globalDir -Force | Out-Null
    }
    $destination = Join-Path $globalDir "custom_modes.json"
}

Write-Host "`nDeployment:" -ForegroundColor Cyan
Write-Host "  Source:      $Source" -ForegroundColor White
Write-Host "  Destination: $destination" -ForegroundColor White
Write-Host "  Type:        $DeploymentType" -ForegroundColor White

if ($DryRun) {
    Write-Host "`nDRY RUN - No changes made." -ForegroundColor Yellow
    exit 0
}

# Backup existing file
if (Test-Path $destination) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = "$destination.backup-$timestamp"
    Copy-Item $destination $backupPath
    Write-Host "`nBackup: $backupPath" -ForegroundColor Gray
}

# Write file preserving UTF-8 encoding
[System.IO.File]::WriteAllText($destination, $sourceContent, $utf8NoBom)

# Verify deployment
$deployedContent = [System.IO.File]::ReadAllText($destination, $utf8NoBom)
try {
    $deployedParsed = $deployedContent | ConvertFrom-Json
    $deployedModeCount = $deployedParsed.customModes.Count

    if ($deployedModeCount -eq $modeCount) {
        Write-Host "`nDEPLOYED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "  $deployedModeCount modes deployed to $DeploymentType" -ForegroundColor Green
    } else {
        Write-Host "`nWARNING: Mode count mismatch (source=$modeCount, deployed=$deployedModeCount)" -ForegroundColor Yellow
    }

    # Check familyDefinitions preserved
    $validatorMode = $deployedParsed.customModes | Where-Object { $_.slug -eq "mode-family-validator" }
    if ($validatorMode -and $validatorMode.familyDefinitions) {
        Write-Host "  familyDefinitions: PRESERVED" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: familyDefinitions may be missing" -ForegroundColor Yellow
    }

} catch {
    Write-Host "`nERROR: Deployed file has invalid JSON!" -ForegroundColor Red
    exit 1
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Reload VS Code (Ctrl+Shift+P > Reload Window)" -ForegroundColor White
Write-Host "  2. Open mode selector (Ctrl+Shift+P > Roo: Switch Mode)" -ForegroundColor White
Write-Host "  3. Verify simple/complex modes appear" -ForegroundColor White
Write-Host "  4. Test escalation: start in code-simple, trigger escalation criteria" -ForegroundColor White
