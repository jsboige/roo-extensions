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
