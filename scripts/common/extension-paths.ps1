<#
.SYNOPSIS
    Shared extension ID constants and path helpers for Roo/Zoo Code.
.DESCRIPTION
    Centralizes extension IDs and globalStorage path construction.
    Scripts should dot-source this module instead of hardcoding IDs.

    Usage:
      . "$PSScriptRoot\..\common\extension-paths.ps1"
      $settingsPath = Get-GlobalStoragePath -Extension ZooCode | Join-Path -ChildPath "settings"
#>

$RooExtensionId = "rooveterinaryinc.roo-cline"
$ZooExtensionId = "zoocodeorganization.zoo-code"

function Get-GlobalStoragePath {
    <#
    .SYNOPSIS
        Returns the VS Code globalStorage path for a given extension.
    .PARAMETER Extension
        The extension identifier: RooCode (default) or ZooCode.
    .OUTPUTS
        Full path to the extension's globalStorage directory.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("RooCode", "ZooCode")]
        [string]$Extension = "RooCode"
    )

    $id = if ($Extension -eq "ZooCode") { $ZooExtensionId } else { $RooExtensionId }
    $basePath = Join-Path $env:APPDATA "Code\User\globalStorage"
    return Join-Path $basePath $id
}

function Get-McpSettingsPath {
    <#
    .SYNOPSIS
        Returns the path to mcp_settings.json for a given extension.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("RooCode", "ZooCode")]
        [string]$Extension = "RooCode"
    )

    $gsPath = Get-GlobalStoragePath -Extension $Extension
    return Join-Path (Join-Path $gsPath "settings") "mcp_settings.json"
}

function Get-ActiveExtension {
    <#
    .SYNOPSIS
        Probes the filesystem for the installed extension (Roo or Zoo).
    .DESCRIPTION
        PowerShell mirror of the TS probe #2766 S2 + #3006 in
        src/utils/extension-paths.ts. The probe targets the settings/
        mcp_settings.json FILE, not the extension directory: on a migrated
        host the roo-cline globalStorage survives as an empty shell and a
        directory-based probe would pick Roo despite Zoo carrying the live
        config. Preference when both files exist: Roo (back-compat with
        dual-install hosts). Returns "RooCode" when neither exists (default,
        matches the TS fallback).
    .OUTPUTS
        "RooCode" or "ZooCode".
    #>
    [CmdletBinding()]
    param()

    $rooSettings = Get-McpSettingsPath -Extension RooCode
    if (Test-Path $rooSettings) { return "RooCode" }
    $zooSettings = Get-McpSettingsPath -Extension ZooCode
    if (Test-Path $zooSettings) { return "ZooCode" }
    return "RooCode"
}

function Get-ActiveMcpSettingsPath {
    <#
    .SYNOPSIS
        Returns the mcp_settings.json path of the ACTIVE extension (#3135).
    .DESCRIPTION
        Zoo-only hosts (Roo globalStorage absent) must not publish an
        "absent" mcpServers inventory just because the collector hardcoded
        RooCode — compare_config then reports degraded collection instead
        of diffing (#3135 arbitrage 2026-08-20).
    .OUTPUTS
        Full path to the active extension's mcp_settings.json.
    #>
    [CmdletBinding()]
    param()

    return Get-McpSettingsPath -Extension (Get-ActiveExtension)
}
