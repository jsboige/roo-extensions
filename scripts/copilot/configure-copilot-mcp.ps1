<#
.SYNOPSIS
    Configure GitHub Copilot MCP config to include roo-state-manager.

.DESCRIPTION
    Creates or updates %APPDATA%\Code\User\mcp.json with an entry for
    roo-state-manager using the local wrapper in this repository.

    This script is idempotent and preserves existing server entries.
    Uses the official VS Code MCP configuration location.

.PARAMETER RepoRoot
    Absolute path to roo-extensions root.

.PARAMETER SharedPath
    Optional RooSync shared path. If provided, injected as ROOSYNC_SHARED_PATH.

.PARAMETER DryRun
    Show resulting JSON without writing.

.EXAMPLE
    .\scripts\copilot\configure-copilot-mcp.ps1 -RepoRoot "D:\dev\roo-extensions"
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = "D:\dev\roo-extensions",
    [string]$SharedPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function ConvertFrom-JsonToDictionary {
    <#
    .SYNOPSIS
        Engine-portable JSON -> IDictionary. Works on BOTH Windows PowerShell 5.1 and PowerShell 7+.
    .DESCRIPTION
        MEASURED 2026-09-08 on both engines (ai-01) — the two available mechanisms are
        MUTUALLY EXCLUSIVE, so neither one alone is portable:

          ConvertFrom-Json -AsHashtable : PS 7.6.5 OK (OrderedHashtable)
                                          PS 5.1   FAILS ("parametre ... AsHashtable" introuvable)
          JavaScriptSerializer          : PS 5.1   OK (Dictionary[string,object])
                                          PS 7.6.5 FAILS ("Could not load type
                                          'System.Web.UI.WebResourceAttribute'" — System.Web.Extensions
                                          is .NET Framework only, absent from .NET Core)

        Picking either one hard-codes a dependency on one engine and silently degrades on the
        other, which is exactly the bug this helper exists to end (#2368).

        CALLER CONTRACT: the two shapes are different .NET types. Test membership with
        `-is [System.Collections.IDictionary]` (true for BOTH); `-is [hashtable]` is true only
        for the PS 7 shape and silently drops data under 5.1.
    #>
    param([Parameter(Mandatory = $true)][string]$Json)

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        return $Json | ConvertFrom-Json -AsHashtable
    }

    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = [int]::MaxValue
    return $serializer.DeserializeObject($Json)
}

$userMcpConfigPath = Join-Path $env:APPDATA "Code\User\mcp.json"
$wrapperPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs"

if (-not (Test-Path $wrapperPath)) {
    throw "roo-state-manager wrapper not found: $wrapperPath"
}

# Read existing config or initialize empty
$config = @{}
if (Test-Path $userMcpConfigPath) {
    $raw = Get-Content -Path $userMcpConfigPath -Raw
    if ($raw.Trim().Length -gt 0) {
        $config = ConvertFrom-JsonToDictionary $raw
    }
}

# Ensure servers object exists
if (-not $config.ContainsKey("servers")) {
    $config["servers"] = @{}
}

# Create/update server definition  
$server = @{
    type = "stdio"
    command = "node"
    args = @($wrapperPath)
}

if ($SharedPath -and $SharedPath.Trim().Length -gt 0) {
    $server["env"] = @{ ROOSYNC_SHARED_PATH = $SharedPath }
}

# Upsert roo-state-manager into servers map (preserves others)
$config["servers"]["roo-state-manager"] = $server

# Convert to JSON and display/write
$json = $config | ConvertTo-Json -Depth 20

if ($DryRun) {
    Write-Host "[DRY-RUN] Would write: $userMcpConfigPath" -ForegroundColor Yellow
    Write-Host $json
    return
}

# Write with UTF-8 no-BOM encoding (critical for VS Code)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($userMcpConfigPath, $json, $utf8NoBom)

Write-Host "[OK] VS Code MCP config updated: $userMcpConfigPath" -ForegroundColor Green
Write-Host "[OK] Upserted server: roo-state-manager -> $wrapperPath" -ForegroundColor Green
