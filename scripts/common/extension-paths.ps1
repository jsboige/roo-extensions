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

function Test-ExtensionInstalled {
    <#
    .SYNOPSIS
        Tests whether an extension is installed on this host (directory probe).
    .DESCRIPTION
        Installed = the extension's globalStorage directory exists, OR its
        extension directory under ~/.vscode/extensions does (an installed but
        never-activated extension has no globalStorage yet).

        Deliberately a DIFFERENT question than Get-ActiveExtension: that probe
        asks which extension carries the live config (settings/mcp_settings.json
        file, #3135); this one asks which extension is installed. The modes
        deploy (#595 phase 3, review point 1) resolves Zoo as soon as Zoo is
        installed because Roo recreates its mcp_settings.json at every startup
        and migrate-roo-to-zoo.ps1 COPIES it to Zoo instead of moving it -- on a
        migrated or dual host the file probe answers Roo while Zoo is the
        extension that runs, and modes deployed to Roo stay invisible.
    .OUTPUTS
        $true when the extension is installed on this host.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("RooCode", "ZooCode")]
        [string]$Extension
    )

    $id = if ($Extension -eq "ZooCode") { $ZooExtensionId } else { $RooExtensionId }
    $storage = Get-GlobalStoragePath -Extension $Extension
    if (Test-Path -LiteralPath $storage) { return $true }
    # Extension dir probe: ~/.vscode/extensions/<marketplace-id>-<version>.
    # PS 5.1 has no $IsWindows -- $env:OS is the 5.1-safe platform test.
    $homeDir = if ($env:OS -eq "Windows_NT") { $env:USERPROFILE } else { $env:HOME }
    if (-not $homeDir) { return $false }
    $extRoot = Join-Path $homeDir ".vscode\extensions"
    if (Test-Path -LiteralPath $extRoot) {
        $match = Get-ChildItem -LiteralPath $extRoot -Directory -Filter "$id-*" -ErrorAction SilentlyContinue
        if ($match) { return $true }
    }
    return $false
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
