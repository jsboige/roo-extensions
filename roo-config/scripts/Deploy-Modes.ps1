#Requires -Version 5.1

<#
.SYNOPSIS
    Deploy simple/complex mode pairs to Roo Code

.DESCRIPTION
    Deploys the generated modes file to the workspace root (.roomodes)
    or to the VS Code global settings (custom_modes.yaml for Roo/Zoo 3.51.1+).
    For global deployment, regenerates from source using --format yaml to avoid
    the YAML empty-array bug ([] becomes null in naive JSON-to-YAML conversion).
    Run 'node roo-config/scripts/generate-modes.js' first to regenerate from templates.

    The GLOBAL target extension is resolved, not hardcoded (#595 phase 3): with
    -TargetExtension Auto (default) the global deploy targets Zoo Code as soon as
    Zoo is installed, Roo Code otherwise. On a migrated or dual host both
    extensions have a settings/mcp_settings.json and a config-file probe answers
    Roo -- leaving the modes where the running extension never reads them, the
    exact defect #595 fixes. Pass -TargetExtension RooCode/ZooCode to pin it
    explicitly.

.PARAMETER DeploymentType
    'local' = workspace .roomodes (default, JSON format)
    'global' = VS Code global custom_modes.yaml (YAML format, Roo 3.51.1+)

.PARAMETER Source
    Source .roomodes file. Default: roo-config/modes/generated/simple-complex.roomodes

.PARAMETER TargetExtension
    Extension whose globalStorage receives the global deploy: Auto (default), RooCode
    or ZooCode. Auto targets Zoo as soon as Zoo is installed (directory probe,
    Test-ExtensionInstalled), Roo otherwise -- see .DESCRIPTION for why it is not the
    mcp_settings.json probe (Get-ActiveExtension, whose contract is unchanged for its
    other callers: Sync-AlwaysAllow, inventories, meta-audit). When NEITHER extension
    is installed, Auto refuses (exit 2) instead of creating a ghost Roo globalStorage;
    pin RooCode/ZooCode to force.

.PARAMETER ApiProfile
    API profile to apply from model-configs.json (e.g., "Production (Qwen 3.6 local + GLM-5.3 cloud)")

.PARAMETER SyncApiConfigs
    Sync API configs from model-configs.json to Roo VS Code settings after deployment

.PARAMETER DryRun
    Show what would be done without making changes -- no file is written and no
    directory is created; the YAML preview is generated into a temp file that is
    deleted after reading (the tracked generated yaml is not touched).

.EXAMPLE
    .\Deploy-Modes.ps1
    Deploy to local workspace (.roomodes, JSON)

.EXAMPLE
    .\Deploy-Modes.ps1 -DeploymentType global
    Deploy to VS Code global settings (custom_modes.yaml, YAML)

.EXAMPLE
    .\Deploy-Modes.ps1 -DeploymentType global -ApiProfile "Production (Qwen 3.6 local + GLM-5.3 cloud)" -SyncApiConfigs
    Deploy modes with profile and sync API configs to Roo settings

.EXAMPLE
    .\Deploy-Modes.ps1 -DeploymentType global -TargetExtension ZooCode
    Deploy explicitly into the Zoo Code globalStorage (skips auto-detection)

.EXAMPLE
    .\Deploy-Modes.ps1 -DryRun
    Preview deployment without changes
#>

param(
    [ValidateSet("local", "global")]
    [string]$DeploymentType = "local",

    [string]$Source = "",

    [ValidateSet("Auto", "RooCode", "ZooCode")]
    [string]$TargetExtension = "Auto",

    [string]$ApiProfile = "",

    [switch]$SyncApiConfigs,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Resolve paths -- IO.Path Combine+GetFullPath keeps resolution portable across
# OSes: backslash concatenation ("$PSScriptRoot\..\..") only resolves on Windows,
# and the CI non-regression suite (#603 phase 4) executes this script on Linux.
$repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', '..'))
if (-not (Test-Path -LiteralPath $repoRoot)) {
    $repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
}

if (-not $Source) {
    $Source = Join-Path $repoRoot 'roo-config/modes/generated/simple-complex.roomodes'
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
    $generateScript = Join-Path $repoRoot 'roo-config/scripts/generate-modes.js'
    # #595 review follow-up (ai-01, 2026-10-10 afternoon queue): the tracked generated
    # file is not a scratchpad. Generating into it on a -DryRun dirtied checkouts with
    # a diff the operator never asked for -- and because the tracked file was stale
    # (+114/-27) vs the generator, EVERY DryRun rewrote it. A DryRun now generates
    # into a temp file it deletes after reading; a real deploy keeps refreshing the
    # tracked artifact, as before.
    $tempYamlPath = if ($DryRun) {
        Join-Path ([System.IO.Path]::GetTempPath()) "deploy-modes-dryrun-$PID.yaml"
    } else {
        Join-Path $repoRoot 'roo-config/modes/generated/simple-complex.yaml'
    }

    $genArgs = @("$generateScript", "--output", "$tempYamlPath", "--format", "yaml")
    if ($ApiProfile) {
        $genArgs += @("--profile", $ApiProfile)
        Write-Host "Using API profile: $ApiProfile" -ForegroundColor Cyan
    }
    $genResult = & node @genArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: YAML generation failed: $genResult" -ForegroundColor Red
        exit 1
    }

    Write-Host ($genResult | Out-String) -ForegroundColor Gray
    $globalYamlContent = [System.IO.File]::ReadAllText($tempYamlPath, $utf8NoBom)
    if ($DryRun) { Remove-Item -LiteralPath $tempYamlPath -Force -ErrorAction SilentlyContinue }
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
$extensionTarget = ""
if ($DeploymentType -eq "local") {
    $destination = Join-Path $repoRoot ".roomodes"
} else {
    . ([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'scripts', 'common', 'extension-paths.ps1'))
    # #595 phase 3, review point 1: for the MODES deploy, Zoo wins as soon as Zoo is
    # INSTALLED (directory probe). Roo recreates its settings/mcp_settings.json at every
    # startup and migrate-roo-to-zoo.ps1 COPIES it to Zoo instead of moving it, so a
    # migrated or dual host has both files and the config-file probe (Get-ActiveExtension,
    # #3135 -- contract unchanged for its other callers) answers Roo while Zoo is the
    # extension that runs: modes deployed to Roo stay invisible, the defect #595 fixes.
    $extensionTarget = if ($TargetExtension -eq "Auto") {
        if (Test-ExtensionInstalled -Extension ZooCode) { "ZooCode" }
        elseif (Test-ExtensionInstalled -Extension RooCode) { "RooCode" }
        else {
            # #595 review follow-up (ai-01, 2026-10-10 afternoon queue): the Roo
            # fallback used to CREATE the Roo globalStorage on hosts with no extension
            # at all -- a directory nothing reads, and one that answers "installed" to
            # every later probe. Refuse instead (#3639 precedent: exit 2). An explicit
            # -TargetExtension bypasses this resolution by design.
            Write-Host "ERROR: neither Roo Code nor Zoo Code is installed on this host." -ForegroundColor Red
            Write-Host "A global deploy would create a globalStorage no extension reads -- and one that answers 'installed' to every later probe." -ForegroundColor Red
            Write-Host "Install one of them first, or pin -TargetExtension explicitly to force." -ForegroundColor Yellow
            exit 2
        }
    } else { $TargetExtension }
    $globalDir = Get-GlobalStoragePath -Extension $extensionTarget | Join-Path -ChildPath "settings"
    $destination = Join-Path $globalDir "custom_modes.yaml"
}

Write-Host "`nDeployment:" -ForegroundColor Cyan
Write-Host "  Source:      $Source" -ForegroundColor White
Write-Host "  Destination: $destination" -ForegroundColor White
Write-Host "  Type:        $DeploymentType" -ForegroundColor White
if ($extensionTarget) {
    $targetHow = if ($TargetExtension -eq "Auto") { "auto-detected" } else { "explicit" }
    Write-Host "  Target:      $extensionTarget ($targetHow)" -ForegroundColor White
}

if ($DryRun) {
    Write-Host "`nDRY RUN - No changes made." -ForegroundColor Yellow
    exit 0
}

# #595 review follow-up (ai-01, 2026-10-10 afternoon queue): moved BELOW the DryRun
# exit -- the New-Item used to run before the $DryRun test, so a DryRun left an empty
# settings/ directory behind (measured on ai-01's seat).
if ($DeploymentType -eq "global" -and -not (Test-Path $globalDir)) {
    Write-Host "WARNING: VS Code $extensionTarget extension settings dir not found: $globalDir" -ForegroundColor Yellow
    Write-Host "Creating directory..." -ForegroundColor Gray
    New-Item -ItemType Directory -Path $globalDir -Force | Out-Null
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

# Sync API configs if requested
if ($SyncApiConfigs) {
    Write-Host "`n" -NoNewline
    Write-Host "Syncing API configs..." -ForegroundColor Cyan

    $syncScript = Join-Path $repoRoot 'roo-config/scripts/Sync-ApiConfigs.ps1'
    if (Test-Path $syncScript) {
        $syncArgs = @($syncScript)
        if ($DryRun) {
            $syncArgs += "-DryRun"
        }

        & @($syncArgs) | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Host "`nWARNING: API config sync failed (exit code $LASTEXITCODE)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nWARNING: Sync-ApiConfigs.ps1 not found at: $syncScript" -ForegroundColor Yellow
    }
}
