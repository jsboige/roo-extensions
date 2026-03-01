#Requires -Version 5.1

<#
.SYNOPSIS
    Synchronize alwaysAllow configuration from reference file to Roo MCP settings

.DESCRIPTION
    Reads the reference-alwaysallow.json file and synchronizes the alwaysAllow
    configuration to the Roo mcp_settings.json file located in:
    %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json

    This ensures that all MCP tools listed in the reference are auto-approved by Roo
    without requiring manual prompts.

.PARAMETER ReferenceFile
    Path to reference-alwaysallow.json. Default: roo-config/mcp/reference-alwaysallow.json

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Force
    Overwrite existing alwaysAllow entries even if they conflict

.PARAMETER Backup
    Create a backup of mcp_settings.json before modifying (default: true)

.EXAMPLE
    .\Sync-AlwaysAllow.ps1
    Synchronize alwaysAllow from reference file to Roo settings

.EXAMPLE
    .\Sync-AlwaysAllow.ps1 -DryRun
    Preview changes without modifying files

.EXAMPLE
    .\Sync-AlwaysAllow.ps1 -Force
    Overwrite existing alwaysAllow entries

#>

param(
    [string]$ReferenceFile = "",
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Backup = $true
)

$ErrorActionPreference = "Stop"

# Resolve paths
$repoRoot = (Get-Item "$PSScriptRoot\..\.." -ErrorAction SilentlyContinue).FullName
if (-not $repoRoot) {
    $repoRoot = (Get-Item "$PSScriptRoot\.." -ErrorAction SilentlyContinue).FullName
}

if (-not $ReferenceFile) {
    $ReferenceFile = Join-Path $repoRoot "roo-config\mcp\reference-alwaysallow.json"
}

$rooMcpSettingsPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"

Write-Host "Sync AlwaysAllow Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Repository root: $repoRoot"
Write-Host "Reference file: $ReferenceFile"
Write-Host "Roo settings: $rooMcpSettingsPath"
Write-Host ""

# Validate reference file exists
if (-not (Test-Path $ReferenceFile)) {
    Write-Host "ERROR: Reference file not found: $ReferenceFile" -ForegroundColor Red
    exit 1
}

# Read reference configuration
try {
    $referenceConfig = Get-Content $ReferenceFile -Raw | ConvertFrom-Json
    Write-Host "✓ Reference file loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to parse reference file: $_" -ForegroundColor Red
    exit 1
}

# Check if Roo settings exist
if (-not (Test-Path $rooMcpSettingsPath)) {
    Write-Host "INFO: Roo mcp_settings.json does not exist yet. Will create it." -ForegroundColor Yellow
    $rooSettings = @{
        mcpServers = @{}
    }
} else {
    # Read existing Roo settings
    try {
        $jsonObject = Get-Content $rooMcpSettingsPath -Raw | ConvertFrom-Json
        # Convert PSObject to hashtable for PowerShell 5.1 compatibility
        $rooSettings = @{}
        foreach ($prop in $jsonObject.PSObject.Properties) {
            if ($prop.Name -eq "mcpServers") {
                $rooSettings.mcpServers = @{}
                foreach ($server in $jsonObject.mcpServers.PSObject.Properties) {
                    $rooSettings.mcpServers[$server.Name] = @{}
                    foreach ($serverProp in $server.Value.PSObject.Properties) {
                        $rooSettings.mcpServers[$server.Name][$serverProp.Name] = $serverProp.Value
                    }
                }
            } else {
                $rooSettings[$prop.Name] = $prop.Value
            }
        }
        Write-Host "✓ Roo settings loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to parse Roo mcp_settings.json: $_" -ForegroundColor Red
        exit 1
    }
}

# Ensure mcpServers key exists
if (-not $rooSettings.mcpServers) {
    $rooSettings.mcpServers = @{}
}

# Track changes
$changes = @()

# Synchronize alwaysAllow for each MCP server from reference
foreach ($serverName in $referenceConfig.mcpServers.PSObject.Properties.Name) {
    $referenceServer = $referenceConfig.mcpServers.$serverName
    $referenceTools = @($referenceServer.alwaysAllow)

    if (-not $rooSettings.mcpServers.$serverName) {
        $rooSettings.mcpServers.$serverName = @{}
    }

    $existingTools = @($rooSettings.mcpServers.$serverName.alwaysAllow)

    # Compare tool lists
    $missingTools = $referenceTools | Where-Object { $_ -notin $existingTools }
    $extraTools = $existingTools | Where-Object { $_ -notin $referenceTools }

    if ($missingTools -or $extraTools -or -not $rooSettings.mcpServers.$serverName.alwaysAllow) {
        $changes += @{
            Server = $serverName
            Missing = $missingTools
            Extra = $extraTools
            CurrentCount = $existingTools.Count
            TargetCount = $referenceTools.Count
        }

        if ($DryRun) {
            Write-Host ""
            Write-Host "Would update: $serverName" -ForegroundColor Yellow
            if ($missingTools) {
                Write-Host "  Add ($($missingTools.Count)): $($missingTools -join ', ')"
            }
            if ($extraTools -and $Force) {
                Write-Host "  Remove ($($extraTools.Count)): $($extraTools -join ', ')"
            }
        } else {
            # Synchronize alwaysAllow
            if ($Force -or -not $rooSettings.mcpServers.$serverName.alwaysAllow) {
                $rooSettings.mcpServers.$serverName.alwaysAllow = [array]$referenceTools
                Write-Host "✓ Updated $serverName : $($existingTools.Count) → $($referenceTools.Count) tools" -ForegroundColor Green
            } else {
                # Merge mode: only add missing tools, don't remove extras
                $mergedTools = [array]($existingTools + $missingTools | Select-Object -Unique | Sort-Object)
                $rooSettings.mcpServers.$serverName.alwaysAllow = $mergedTools
                Write-Host "✓ Updated $serverName (merge mode): $($existingTools.Count) → $($mergedTools.Count) tools" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "✓ $serverName already in sync ($($existingTools.Count) tools)" -ForegroundColor Green
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry-run complete. Total changes: $($changes.Count) servers" -ForegroundColor Yellow
    if ($changes) {
        Write-Host ""
        Write-Host "Summary:" -ForegroundColor Cyan
        foreach ($change in $changes) {
            Write-Host "  $($change.Server): $($change.CurrentCount) → $($change.TargetCount) tools"
        }
    }
    exit 0
}

# Create backup if requested
if ($Backup -and (Test-Path $rooMcpSettingsPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$rooMcpSettingsPath.backup.$timestamp"
    Copy-Item $rooMcpSettingsPath $backupPath -Force
    Write-Host "✓ Backup created: $backupPath" -ForegroundColor Green
}

# Write updated Roo settings
try {
    # Convert to JSON with proper formatting
    $jsonContent = $rooSettings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText(
        $rooMcpSettingsPath,
        $jsonContent,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "✓ Roo mcp_settings.json updated successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to write Roo settings: $_" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "Synchronization complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

if ($changes) {
    Write-Host "Updated $($changes.Count) server(s):"
    foreach ($change in $changes) {
        Write-Host "  $($change.Server): $($change.CurrentCount) → $($change.TargetCount) tools"
        if ($change.Missing) {
            Write-Host "    Added: $($change.Missing.Count) tools"
        }
        if ($change.Extra -and $Force) {
            Write-Host "    Removed: $($change.Extra.Count) tools"
        }
    }
} else {
    Write-Host "All MCP servers already synchronized with reference configuration"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VS Code to reload Roo with updated MCP settings"
Write-Host "  2. Verify scheduler runs without approval prompts"
Write-Host "  3. Check INTERCOM for any tool-related issues"
