#Requires -Version 5.1

<#
.SYNOPSIS
    Synchronize alwaysAllow configuration from reference file to the ACTIVE extension's MCP settings

.DESCRIPTION
    Reads the reference-alwaysallow.json file and synchronizes the alwaysAllow
    configuration to the mcp_settings.json of the extension that is actually
    installed, resolved at runtime through Get-ActiveMcpSettingsPath (#3135):

      Roo  : %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
      Zoo  : %APPDATA%\Code\User\globalStorage\zoocodeorganization.zoo-code\settings\mcp_settings.json

    This ensures that all MCP tools listed in the reference are auto-approved by the
    active extension without requiring manual prompts.

    #3639: the target used to be the Roo path unconditionally. On a migrated host
    (Zoo active, roo-cline globalStorage surviving as an empty shell) the sync then
    succeeded against an inactive copy and never touched the configuration the
    active extension actually loads.

.PARAMETER ReferenceFile
    Path to reference-alwaysallow.json. Default: roo-config/mcp/reference-alwaysallow.json

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Force
    Overwrite existing alwaysAllow entries even if they conflict
    (without it, extra tools already present are kept -- merge mode)

.PARAMETER Backup
    Create a backup of mcp_settings.json before modifying (default: true)

.EXAMPLE
    .\Sync-AlwaysAllow.ps1
    Synchronize alwaysAllow from reference file to the active extension's settings

.EXAMPLE
    .\Sync-AlwaysAllow.ps1 -DryRun
    Preview changes without modifying files

.EXAMPLE
    .\Sync-AlwaysAllow.ps1 -Force
    Overwrite existing alwaysAllow entries

.NOTES
    Issue #3639: active-extension resolution + post-write verification
    Exit codes:
      0 = success (or dry-run)
      1 = reference/settings unreadable, or write failure
      2 = active extension could not be determined (explicit refusal, nothing written)
      3 = post-write verification failed on the ACTIVE configuration
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
    $ReferenceFile = Join-Path $repoRoot "roo-config/mcp/reference-alwaysallow.json"
}

# Paths built with Path.Combine: portable separators on both engines, and Join-Path
# takes exactly 2 positional args under 5.1.
. ([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'scripts', 'common', 'extension-paths.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, '..', '..', 'scripts', 'common', 'alwaysallow-sync.ps1'))

# #3639: the target is the ACTIVE extension's settings, never a hardcoded Roo path.
$activeExtension = Get-ActiveExtension
$activeMcpSettingsPath = Get-ActiveMcpSettingsPath

Write-Host "Sync AlwaysAllow Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Repository root: $repoRoot"
Write-Host "Reference file: $ReferenceFile"
Write-Host "Active extension: $activeExtension"
Write-Host "Active settings: $activeMcpSettingsPath"
Write-Host ""

# Validate reference file exists
if (-not (Test-Path -LiteralPath $ReferenceFile)) {
    Write-Host "ERROR: Reference file not found: $ReferenceFile" -ForegroundColor Red
    exit 1
}

# #3639: refuse rather than guess. Get-ActiveExtension falls back to RooCode when
# neither candidate holds a mcp_settings.json; creating that file would configure an
# extension that is not installed, which is the drift this issue is about.
if (-not (Test-Path -LiteralPath $activeMcpSettingsPath)) {
    Write-Host "REFUSED: active extension could not be determined -- nothing written." -ForegroundColor Red
    Write-Host "  probed Roo: $(Get-McpSettingsPath -Extension RooCode)"
    Write-Host "  probed Zoo: $(Get-McpSettingsPath -Extension ZooCode)"
    Write-Host "  Neither holds a mcp_settings.json."
    exit 2
}

# Read reference configuration
try {
    $referenceConfig = Get-Content -LiteralPath $ReferenceFile -Raw | ConvertFrom-Json
    Write-Host "[OK] Reference file loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to parse reference file: $_" -ForegroundColor Red
    exit 1
}

# Read the ACTIVE extension's settings (converted to a hashtable for PowerShell 5.1)
try {
    $jsonObject = Get-Content -LiteralPath $activeMcpSettingsPath -Raw | ConvertFrom-Json
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
    Write-Host "[OK] $activeExtension settings loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to parse $activeMcpSettingsPath : $_" -ForegroundColor Red
    exit 1
}

# Ensure mcpServers key exists
if (-not $rooSettings.mcpServers) {
    $rooSettings.mcpServers = @{}
}

# Track changes
$changes = @()
# Tool list actually applied per server -- verified against disk after the write.
$expected = @{}

# Synchronize alwaysAllow for each MCP server from reference
foreach ($serverName in $referenceConfig.mcpServers.PSObject.Properties.Name) {
    $referenceServer = $referenceConfig.mcpServers.$serverName
    $referenceTools = @($referenceServer.alwaysAllow | Where-Object { $_ -ne $null })

    # Skip servers not present in mcp_settings.json (#552)
    if (-not $rooSettings.mcpServers.$serverName) {
        Write-Host "[SKIP] $serverName not in mcp_settings.json - skipping (won't create phantom entry)" -ForegroundColor Yellow
        continue
    }

    $existingTools = @($rooSettings.mcpServers.$serverName.alwaysAllow | Where-Object { $_ -ne $null })
    $hasAlwaysAllowKey = $null -ne $rooSettings.mcpServers.$serverName.alwaysAllow

    # Compare tool lists (set semantics, order-insensitive)
    $delta = Get-AlwaysAllowDelta -ReferenceTools $referenceTools -CurrentTools $existingTools
    $missingTools = $delta.Added
    $extraTools = $delta.Removed

    if ($missingTools.Count -gt 0 -or $extraTools.Count -gt 0 -or -not $hasAlwaysAllowKey) {
        $changes += @{
            Server = $serverName
            Missing = $missingTools
            Extra = $extraTools
            CurrentCount = $existingTools.Count
            TargetCount = $referenceTools.Count
        }

        if ($DryRun) {
            # Non-destructive preview of the exact delta that WOULD be applied.
            Write-Host ""
            Write-Host "Would update: $serverName" -ForegroundColor Yellow
            if ($missingTools.Count -gt 0) {
                Write-Host "  Add ($($missingTools.Count)): $($missingTools -join ', ')"
            }
            if ($extraTools.Count -gt 0) {
                if ($Force) {
                    Write-Host "  Remove ($($extraTools.Count)): $($extraTools -join ', ')"
                } else {
                    Write-Host "  Keep ($($extraTools.Count)) [merge mode, use -Force to remove]: $($extraTools -join ', ')"
                }
            }
        } else {
            # Synchronize alwaysAllow - skip if reference tools list is empty (#552)
            if ($referenceTools.Count -eq 0) {
                Write-Host "[SKIP] $serverName has empty reference tools list - skipping" -ForegroundColor Yellow
            } else {
                if ($Force -or -not $hasAlwaysAllowKey) {
                    $appliedTools = [array]$referenceTools
                    $rooSettings.mcpServers.$serverName.alwaysAllow = $appliedTools
                    Write-Host "[OK] Updated $serverName : $($existingTools.Count) -> $($referenceTools.Count) tools" -ForegroundColor Green
                } else {
                    # Merge mode: only add missing tools, don't remove extras
                    $mergedTools = [array](@($existingTools) + @($missingTools) | Select-Object -Unique | Sort-Object)
                    $rooSettings.mcpServers.$serverName.alwaysAllow = $mergedTools
                    Write-Host "[OK] Updated $serverName (merge mode): $($existingTools.Count) -> $($mergedTools.Count) tools" -ForegroundColor Green
                    $appliedTools = $mergedTools
                }
                $expected[$serverName] = @($appliedTools)
            }
        }
    } else {
        Write-Host "[OK] $serverName already in sync ($($existingTools.Count) tools)" -ForegroundColor Green
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry-run complete. Total changes: $($changes.Count) servers" -ForegroundColor Yellow
    if ($changes) {
        Write-Host ""
        Write-Host "Summary:" -ForegroundColor Cyan
        foreach ($change in $changes) {
            Write-Host "  $($change.Server): $($change.CurrentCount) -> $($change.TargetCount) tools"
        }
    }
    exit 0
}

# Create backup if requested
if ($Backup) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$activeMcpSettingsPath.backup.$timestamp"
    Copy-Item -LiteralPath $activeMcpSettingsPath -Destination $backupPath -Force
    Write-Host "[OK] Backup created: $backupPath" -ForegroundColor Green
}

# Cleanup: Remove empty autoApprove fields from all servers (#552)
# The autoApprove field is legacy - alwaysAllow is the canonical field.
# Empty autoApprove arrays cause "Format de paramètres MCP invalide" errors in VS Code.
$cleanedServers = 0
foreach ($sName in @($rooSettings.mcpServers.Keys)) {
    $server = $rooSettings.mcpServers[$sName]
    if ($server.ContainsKey('autoApprove')) {
        $autoApproveValue = $server['autoApprove']
        if ($null -eq $autoApproveValue -or @($autoApproveValue | Where-Object { $_ -ne $null }).Count -eq 0) {
            $server.Remove('autoApprove')
            $cleanedServers++
            Write-Host "  Cleaned empty autoApprove from: $sName" -ForegroundColor DarkYellow
        }
    }
}
if ($cleanedServers -gt 0) {
    Write-Host "[OK] Removed $cleanedServers empty autoApprove field(s)" -ForegroundColor Green
}

# Write updated settings
try {
    # Convert to JSON with proper formatting
    $jsonContent = $rooSettings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText(
        $activeMcpSettingsPath,
        $jsonContent,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "[OK] $activeExtension mcp_settings.json updated successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to write settings: $_" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host ""
Write-Host "Synchronization complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

if ($changes) {
    Write-Host "Updated $($changes.Count) server(s):"
    foreach ($change in $changes) {
        Write-Host "  $($change.Server): $($change.CurrentCount) -> $($change.TargetCount) tools"
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

# #3639 point 5: re-read the configuration that is EFFECTIVELY ACTIVE, from disk.
# The active target is re-resolved first (did it move while we wrote?), then the
# file is read back -- the in-memory hashtable proves nothing about what is loaded.
$activeAfter = Get-ActiveMcpSettingsPath
if (-not [string]::Equals($activeAfter, $activeMcpSettingsPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "ERROR: the active settings path moved during the sync (was $activeMcpSettingsPath, now $activeAfter)" -ForegroundColor Red
    exit 3
}

if ($expected.Count -gt 0) {
    $verification = Test-AlwaysAllowApplied -SettingsPath $activeAfter -Expected $expected
    if (-not $verification.Ok) {
        Write-Host "ERROR: POST-WRITE VERIFICATION FAILED on the ACTIVE configuration ($activeAfter):" -ForegroundColor Red
        foreach ($mismatch in $verification.Mismatches) {
            Write-Host "  $mismatch" -ForegroundColor Red
        }
        exit 3
    }
    Write-Host "POST-WRITE VERIFICATION OK ($($verification.Checked) server(s) re-read from $activeAfter)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart VS Code to reload the active extension with updated MCP settings"
Write-Host "  2. Verify scheduler runs without approval prompts"
Write-Host "  3. Check INTERCOM for any tool-related issues"
