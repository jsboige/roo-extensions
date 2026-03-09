#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy simple/complex mode pairs to Roo Code

.DESCRIPTION
    Deploys the generated modes file to the workspace root (.roomodes)
    or to the VS Code global settings (custom_modes.yaml for Roo 3.51.1+).
    For global deployment, regenerates from source using --format yaml to avoid
    the YAML empty-array bug ([] becomes null in naive JSON-to-YAML conversion).
    Run 'node roo-config/scripts/generate-modes.js' first to regenerate from templates.

.PARAMETER DeploymentType
    'local' = workspace .roomodes (default, JSON format)
    'global' = VS Code global custom_modes.yaml (YAML format, Roo 3.51.1+)

.PARAMETER Source
    Source .roomodes file. Default: roo-config/modes/generated/simple-complex.roomodes

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\Deploy-Modes.ps1
    Deploy to local workspace (.roomodes, JSON)

.EXAMPLE
    .\Deploy-Modes.ps1 -DeploymentType global
    Deploy to VS Code global settings (custom_modes.yaml, YAML)

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
    $Source = Join-Path $repoRoot "roo-config\modes\generated\simple-complex.roomodes"
}

if (-not (Test-Path $Source)) {
    Write-Host "ERROR: Source file not found: $Source" -ForegroundColor Red
    Write-Host "Run 'node roo-config/scripts/generate-modes.js' first." -ForegroundColor Yellow
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

# For global deployment, regenerate as YAML using generate-modes.js --format yaml
# This avoids the YAML empty-array bug where [] becomes null
$globalYamlContent = $null
if ($DeploymentType -eq "global") {
    Write-Host "`nRegenerating as YAML for global deployment..." -ForegroundColor Cyan
    $generateScript = Join-Path $repoRoot "roo-config\scripts\generate-modes.js"
    $tempYamlPath = Join-Path $repoRoot "roo-config\modes\generated\simple-complex.yaml"

    $genArgs = @("$generateScript", "--output", "$tempYamlPath", "--format", "yaml")
    $genResult = & node @genArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: YAML generation failed: $genResult" -ForegroundColor Red
        exit 1
    }

    Write-Host ($genResult | Out-String) -ForegroundColor Gray
    $globalYamlContent = [System.IO.File]::ReadAllText($tempYamlPath, $utf8NoBom)
    Write-Host "YAML generated: $($globalYamlContent.Length) bytes" -ForegroundColor Green
}

# Display modes
$modeNames = @()
foreach ($mode in $parsed.customModes) {
    $modeNames += $mode.slug
}

Write-Host "`nModes to deploy:" -ForegroundColor Cyan
foreach ($name in $modeNames) {
    $suffix = if ($name -match '-simple$') { " (economique)" } elseif ($name -match '-complex$') { " (puissant)" } else { "" }
    Write-Host "  - $name$suffix" -ForegroundColor White
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
    $destination = Join-Path $globalDir "custom_modes.yaml"
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
if ($DeploymentType -eq "global" -and $globalYamlContent) {
    [System.IO.File]::WriteAllText($destination, $globalYamlContent, $utf8NoBom)
} else {
    [System.IO.File]::WriteAllText($destination, $sourceContent, $utf8NoBom)
}

# Verify deployment
$deployedContent = [System.IO.File]::ReadAllText($destination, $utf8NoBom)
if ($DeploymentType -eq "global") {
    # YAML verification: check that groups is truly null (not followed by list items)
    # Valid YAML: "groups: \n      - read" (multi-line list) or "groups: []" (inline empty)
    # Invalid YAML: "groups: \n  - slug:" (null groups, next line is a new mode)
    $lines = $deployedContent -split "`n"
    $nullGroupsCount = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s+groups:\s*$') {
            # Check if the next non-empty line is an indented list item (valid) or something else (null)
            $nextIdx = $i + 1
            while ($nextIdx -lt $lines.Count -and $lines[$nextIdx] -match '^\s*$') { $nextIdx++ }
            if ($nextIdx -lt $lines.Count -and $lines[$nextIdx] -notmatch '^\s+- ') {
                $nullGroupsCount++
            }
        }
    }
    if ($nullGroupsCount -gt 0) {
        Write-Host "`nERROR: YAML contains $nullGroupsCount truly null groups!" -ForegroundColor Red
        Write-Host "Check generate-modes.js YAML serializer." -ForegroundColor Red
        exit 1
    }
    # Count modes by slug occurrences
    $deployedModeCount = ([regex]::Matches($deployedContent, '^\s*- slug:', 'Multiline')).Count
    if ($deployedModeCount -eq $modeCount) {
        Write-Host "`nDEPLOYED SUCCESSFULLY (YAML)" -ForegroundColor Green
        Write-Host "  $deployedModeCount modes deployed to $DeploymentType (custom_modes.yaml)" -ForegroundColor Green
    } else {
        Write-Host "`nWARNING: Mode count mismatch (source=$modeCount, deployed=$deployedModeCount)" -ForegroundColor Yellow
    }
} else {
    try {
        $deployedParsed = $deployedContent | ConvertFrom-Json
        $deployedModeCount = $deployedParsed.customModes.Count

        if ($deployedModeCount -eq $modeCount) {
            Write-Host "`nDEPLOYED SUCCESSFULLY" -ForegroundColor Green
            Write-Host "  $deployedModeCount modes deployed to $DeploymentType" -ForegroundColor Green
        } else {
            Write-Host "`nWARNING: Mode count mismatch (source=$modeCount, deployed=$deployedModeCount)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "`nERROR: Deployed file has invalid JSON!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Reload VS Code (Ctrl+Shift+P > Reload Window)" -ForegroundColor White
Write-Host "  2. Open mode selector to verify modes appear" -ForegroundColor White
Write-Host "  3. Check model routing in roo-config/model-configs.json" -ForegroundColor White
