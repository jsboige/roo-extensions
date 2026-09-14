#Requires -Version 5.1
<#
.SYNOPSIS
    Shared alwaysAllow primitives for the two MCP-settings sync scripts (#3639).

.DESCRIPTION
    `scripts/mcp/sync-alwaysallow.ps1` and `roo-config/scripts/Sync-AlwaysAllow.ps1`
    both diff a reference tool list against a live `mcp_settings.json`, and both now
    have to re-read what they wrote on the ACTIVE extension's file (#3639 point 5).

    Their write policies legitimately differ (one replaces the list, the other merges
    unless -Force), so those stay in the callers. What must NOT differ is what a
    "delta" is and what "applied" means -- the two copies of that arithmetic had
    already drifted apart. Diverging copies is a cost this repo has paid before
    (see the deploy-global-config note in .github/workflows/ci.yml, two copies that
    drifted for three months while the amputated one reported success).

    Neither function here writes anything.

.NOTES
    Issue #3639
#>

function Get-AlwaysAllowDelta {
    <#
    .SYNOPSIS
        Classifies a live tool list against a reference tool list.

    .DESCRIPTION
        Comparison is by SET, not by order: what matters is which tools are
        auto-approved, not the sequence they are written in (the two callers write
        in different orders on purpose).

    .PARAMETER ReferenceTools
        The tool list the reference file demands.

    .PARAMETER CurrentTools
        The tool list currently present in the target settings.

    .OUTPUTS
        PSCustomObject with Added (demanded but absent) and Removed (present but
        no longer demanded). Both are always arrays, never $null.
    #>
    [CmdletBinding()]
    param(
        [string[]]$ReferenceTools = @(),
        [string[]]$CurrentTools = @()
    )

    $reference = @($ReferenceTools | Where-Object { $_ -ne $null -and $_ -ne '' })
    $current   = @($CurrentTools   | Where-Object { $_ -ne $null -and $_ -ne '' })

    [pscustomobject]@{
        Added   = @($reference | Where-Object { $current -notcontains $_ })
        Removed = @($current   | Where-Object { $reference -notcontains $_ })
    }
}

function Test-AlwaysAllowApplied {
    <#
    .SYNOPSIS
        Re-reads a written settings file from DISK and checks the expected tool lists.

    .DESCRIPTION
        The point is to verify what was actually persisted, not what was intended:
        the caller's in-memory object proves nothing about the file (BOM, encoding,
        JSON shape, wrong path -- #664 was exactly that class of defect).

    .PARAMETER SettingsPath
        Path of the file to re-read. Callers pass the ACTIVE extension's path
        (#3639), never a hardcoded one.

    .PARAMETER Expected
        Hashtable of serverName -> expected tool array. Callers record the list
        they actually applied, so a merge-mode caller is checked against its merge
        result and not against the raw reference.

    .OUTPUTS
        PSCustomObject with Ok (bool), Checked (servers re-read) and Mismatches
        (one human-readable line per divergent server).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SettingsPath,
        [Parameter(Mandatory = $true)][hashtable]$Expected
    )

    $mismatches = New-Object System.Collections.Generic.List[string]

    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        $mismatches.Add("settings file absent after write: $SettingsPath")
        return [pscustomobject]@{ Ok = $false; Checked = 0; Mismatches = @($mismatches) }
    }

    try {
        $persisted = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    } catch {
        $mismatches.Add("settings file unreadable after write: $($_.Exception.Message)")
        return [pscustomobject]@{ Ok = $false; Checked = 0; Mismatches = @($mismatches) }
    }

    $checked = 0
    foreach ($serverName in @($Expected.Keys)) {
        $checked++
        $onDisk = @()
        if ($persisted.mcpServers) {
            $server = $persisted.mcpServers.$serverName
            if ($server) {
                $onDisk = @($server.alwaysAllow | Where-Object { $_ -ne $null })
            }
        }

        $delta = Get-AlwaysAllowDelta -ReferenceTools @($Expected[$serverName]) -CurrentTools $onDisk
        if ($delta.Added.Count -gt 0 -or $delta.Removed.Count -gt 0) {
            $mismatches.Add("$serverName : missing=[$($delta.Added -join ',')] extra=[$($delta.Removed -join ',')]")
        }
    }

    [pscustomobject]@{
        Ok         = ($mismatches.Count -eq 0)
        Checked    = $checked
        Mismatches = @($mismatches)
    }
}
