#Requires -Version 5.1

<#
.SYNOPSIS
    Validate deployed MCP configurations against repository templates to detect drift

.DESCRIPTION
    This script prevents config drift incidents like those on 2026-04-23 (#1634, #1656).
    It compares deployed MCP settings against repository "sources of truth":

    1. Reads deployed configs:
       - %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json (Roo)
       - %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\win_cli_config.json (Roo)

    2. Compares against repository templates:
       - mcps\external\win-cli\unrestricted-config.json (win-cli reference)
       - Repository's expected MCP server list (for deprecated MCP detection)

    3. Reports divergences:
       - Values different from reference
       - Missing keys
       - Presence of deprecated MCPs (desktop-commander, github-projects-mcp, quickfiles)

    4. Exit codes:
       - 0: All checks passed (no drift detected)
       - 1: Drift detected or validation failed

.PARAMETER FixMode
    If specified, outputs suggested fixes instead of just reporting (experimental)

.PARAMETER Detailed
    Show detailed comparison of all values (not just divergences)

.EXAMPLE
    .\validate-mcp-config-cross-machine.ps1
    Basic validation - report any drift found

.EXAMPLE
    .\validate-mcp-config-cross-machine.ps1 -Detailed
    Show full comparison including matching values

.EXAMPLE
    .\validate-mcp-config-cross-machine.ps1 -FixMode
    Output PowerShell commands to fix detected drifts
#>

[CmdletBinding()]
param(
    [switch]$FixMode,
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

# ==================================================================================================
#   CONFIGURATION
# ==================================================================================================

$script:DriftDetected = $false

# Paths to deployed configs (Roo-specific locations)
$rooGlobalStorage = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings"
$deployedMcpSettings = Join-Path $rooGlobalStorage "mcp_settings.json"
$deployedWinCliConfig = Join-Path $rooGlobalStorage "win_cli_config.json"

# Repository reference paths
$repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$refWinCliConfig = Join-Path $repoRoot "mcps\external\win-cli\unrestricted-config.json"

# Deprecated MCPs that should NOT be present
$deprecatedMCPs = @(
    "desktop-commander",
    "github-projects-mcp",
    "quickfiles"
)

# Keys that are allowed to differ between deployed and reference (machine-specific)
$allowedDivergences = @(
    # Add machine-specific paths or settings here if needed
)

# ==================================================================================================
#   UTILITY FUNCTIONS
# ==================================================================================================

function Write-ColorOutput {
    param([string]$Message, [ConsoleColor]$ForegroundColor = "White")
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-Drift {
    param([string]$Message, [string]$FixCommand = $null)

    $script:DriftDetected = $true
    Write-ColorOutput "  [DRIFT] $Message" "Red"

    if ($FixMode -and $FixCommand) {
        Write-ColorOutput "  FIX: $FixCommand" "Yellow"
    }
}

function Write-Ok {
    param([string]$Message)
    if ($Detailed) {
        Write-ColorOutput "  [OK] $Message" "Green"
    }
}

function Test-JsonFile {
    param([string]$Path, [string]$Description)

    Write-ColorOutput "`nChecking: $Description" "Cyan"
    Write-ColorOutput "  Path: $Path" "Gray"

    if (-not (Test-Path $Path)) {
        Write-ColorOutput "  [WARN] File not found (may not be deployed on this machine)" "Yellow"
        return $null
    }

    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        Write-ColorOutput "  [OK] Valid JSON" "Green"
        return $content
    }
    catch {
        Write-ColorOutput "  [ERROR] Invalid JSON: $($_.Exception.Message)" "Red"
        $script:DriftDetected = $true
        return $null
    }
}

function Compare-JsonObjects {
    param(
        [object]$Reference,
        [object]$Deployed,
        [string]$Prefix = ""
    )

    if ($null -eq $Reference -or $null -eq $Deployed) {
        return
    }

    $refProps = $Reference.PSObject.Properties.Name
    $depProps = $Deployed.PSObject.Properties.Name

    # Check for missing keys in deployed
    foreach ($prop in $refProps) {
        if ($prop -notin $depProps) {
            Write-Drift -Message "Missing key: '$Prefix$prop'" -FixCommand "Add '$Prefix$prop' to deployed config"
        }
    }

    # Check for extra keys in deployed (might be OK depending on context)
    foreach ($prop in $depProps) {
        if ($prop -notin $refProps) {
            Write-ColorOutput "  [INFO] Extra key in deployed: '$Prefix$prop' (not in reference)" "DarkYellow"
        }
    }

    # Compare common keys
    foreach ($prop in $refProps) {
        if ($prop -in $depProps) {
            $refValue = $Reference.$prop
            $depValue = $Deployed.$prop

            $fullPath = "$Prefix$prop"

            # Skip if this is an allowed divergence
            if ($fullPath -in $allowedDivergences) {
                $msg = "${fullPath}: Allowed to differ (Ref='$refValue', Dep='$depValue')"
                Write-Ok $msg
                continue
            }

            # Recursively compare nested objects
            if ($refValue -is [PSCustomObject] -and $depValue -is [PSCustomObject]) {
                Compare-JsonObjects -Reference $refValue -Deployed $depValue -Prefix "${fullPath}."
            }
            elseif ($refValue -is [System.Array] -and $depValue -is [System.Array]) {
                # Compare arrays (order-insensitive for simple values)
                $refArray = @($refValue) | Sort-Object
                $depArray = @($depValue) | Sort-Object

                if (-not (Compare-Object $refArray $depArray -SyncWindow 0)) {
                    $msg = "${fullPath}: Arrays match"
                    Write-Ok $msg
                } else {
                    Write-Drift -Message "Array differs: '$fullPath'" `
                        -FixCommand "Update '$fullPath' to match reference: $($refValue -join ', ')"
                }
            }
            else {
                # Compare scalar values
                if ($refValue -ne $depValue) {
                    Write-Drift -Message "Value differs: '$fullPath' (Ref='$refValue', Dep='$depValue')" `
                        -FixCommand "Set '$fullPath' to '$refValue'"
                } else {
                    $msg = "${fullPath}: Matches (Value='$refValue')"
                    Write-Ok $msg
                }
            }
        }
    }
}

function Test-DeprecatedMCPs {
    param([object]$McpSettings)

    if ($null -eq $McpSettings) {
        return
    }

    Write-ColorOutput "`nChecking for deprecated MCP servers..." "Cyan"

    $deprecatedFound = @()

    # Check in different possible structures
    if ($McpSettings.PSObject.Properties.Name -contains "mcpServers") {
        foreach ($deprecated in $deprecatedMCPs) {
            if ($McpSettings.mcpServers.PSObject.Properties.Name -contains $deprecated) {
                $deprecatedFound += $deprecated
            }
        }
    }

    if ($deprecatedFound.Count -gt 0) {
        foreach ($deprecated in $deprecatedFound) {
            Write-Drift -Message "Deprecated MCP found: '$deprecated'" `
                -FixCommand "Remove '$deprecated' from mcp_settings.json (use win-cli MCP instead)"
        }
    } else {
        Write-ColorOutput "  [OK] No deprecated MCPs found" "Green"
    }
}

# ==================================================================================================
#   MAIN EXECUTION
# ==================================================================================================

Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "  MCP Config Cross-Machine Validation" "Cyan"
Write-ColorOutput "  Preventing drift incidents like #1634, #1656" "Cyan"
Write-ColorOutput "==========================================================" "Cyan"
Write-ColorOutput "Repository root: $repoRoot" "Gray"
Write-ColorOutput "Machine: $env:COMPUTERNAME" "Gray"

# Step 1: Load reference win-cli config
$refWinCli = Test-JsonFile -Path $refWinCliConfig -Description "Reference win-cli config (repository)"

# Step 2: Load deployed win-cli config (if exists)
$depWinCli = Test-JsonFile -Path $deployedWinCliConfig -Description "Deployed win-cli config (Roo)"

# Step 3: Compare win-cli configs
if ($null -ne $refWinCli -and $null -ne $depWinCli) {
    Write-ColorOutput "`nComparing win-cli configurations..." "Cyan"
    Compare-JsonObjects -Reference $refWinCli -Deployed $depWinCli -Prefix "win_cli."
}

# Step 4: Check deployed mcp_settings.json for deprecated MCPs
$depMcpSettings = Test-JsonFile -Path $deployedMcpSettings -Description "Deployed MCP settings (Roo)"
Test-DeprecatedMCPs -McpSettings $depMcpSettings

# ==================================================================================================
#   FINAL REPORT
# ==================================================================================================

Write-ColorOutput "`n==========================================================" "Cyan"

if ($script:DriftDetected) {
    Write-ColorOutput "VALIDATION FAILED: Drift detected!" "Red"
    Write-ColorOutput "`nAction required:" "Yellow"
    Write-ColorOutput "  1. Review the drifts reported above" "Yellow"
    Write-ColorOutput "  2. Update deployed configs to match repository references" "Yellow"
    Write-ColorOutput "  3. Re-run this script to confirm fixes" "Yellow"

    if ($FixMode) {
        Write-ColorOutput "`nSuggested fix commands have been provided above." "Yellow"
    }

    Write-ColorOutput "`nTo prevent future drift:" "Cyan"
    Write-ColorOutput "  - Always update configs via deployment scripts, not manual edits" "Gray"
    Write-ColorOutput "  - Run this script after any MCP-related changes" "Gray"
    Write-ColorOutput "  - Run cross-machine checks during coordination cycles" "Gray"

    exit 1
}
else {
    Write-ColorOutput "VALIDATION PASSED: No drift detected!" "Green"
    Write-ColorOutput "  Deployed configs match repository references." "Green"
    exit 0
}
