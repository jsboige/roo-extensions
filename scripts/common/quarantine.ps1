<#
.SYNOPSIS
    Quarantine helpers — move files aside with a SHA-256 manifest, never delete.
.DESCRIPTION
    Convention audit 27/09 (dispatch ai-01 16:05Z) : un script de purge ne supprime
    jamais directement. Les fichiers sont DEPLACES vers un repertoire de quarantaine
    horodate, chaque fichier etant empreinte (SHA-256) dans manifest.json AVANT le
    deplacement. La suppression definitive reste un geste manuel, posterieur a la
    verification du manifeste.

    Usage:
      . "$PSScriptRoot\..\common\quarantine.ps1"
      $q = New-QuarantineDir -Root $QuarantineRoot
      $manifest = [System.Collections.Generic.List[object]]::new()
      Move-FileToQuarantine -LiteralPath $file -QuarantineDir $q -RelativeBase $base -Manifest $manifest
      Write-QuarantineManifest -QuarantineDir $q -Manifest $manifest
#>

function New-QuarantineDir {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)
    $dir = Join-Path $Root (Get-Date -Format 'yyyyMMdd-HHmmss')
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Move-FileToQuarantine {
    # Deplace UN fichier vers la quarantaine en preservant sa structure relative.
    # Retourne $true si deplace, $false si le fichier est reste en place (echec de
    # hash ou de deplacement — fail-safe : rien n'est jamais a moietie suivi).
    # Sans -Force : une collision de destination echoue au lieu d'ecraser.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][string]$QuarantineDir,
        [Parameter(Mandatory)][string]$RelativeBase,
        # Pas de Mandatory : une liste VIDE est legale (premier fichier d'une
        # quarantaine neuve) — Mandatory + collection vide = erreur de binding.
        [Parameter()][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Manifest = [System.Collections.Generic.List[object]]::new()
    )
    try {
        $hash = (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256 -ErrorAction Stop).Hash
        $item = Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
        $fullPath = [IO.Path]::GetFullPath($LiteralPath)
        $fullBase = [IO.Path]::GetFullPath($RelativeBase).TrimEnd('\', '/')
        $rel = $fullPath.Substring($fullBase.Length).TrimStart('\', '/')
        $dest = Join-Path $QuarantineDir $rel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Move-Item -LiteralPath $LiteralPath -Destination $dest -ErrorAction Stop
        $Manifest.Add([pscustomobject]@{
            original    = $fullPath
            quarantined = $dest
            sha256      = $hash
            bytes       = $item.Length
        })
        return $true
    }
    catch {
        Write-Warning "QUARANTINE FAILED (file left in place): $LiteralPath — $($_.Exception.Message)"
        return $false
    }
}

function Write-QuarantineManifest {
    # UTF-8 sans BOM : les parseurs avalent le BOM mal (regle globale).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$QuarantineDir,
        [Parameter()][AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Manifest = [System.Collections.Generic.List[object]]::new()
    )
    $payload = [pscustomobject]@{
        written_at = (Get-Date).ToString('o')
        host       = $env:COMPUTERNAME
        entries    = @($Manifest)
    }
    $json = $payload | ConvertTo-Json -Depth 4
    [IO.File]::WriteAllText((Join-Path $QuarantineDir 'manifest.json'), $json, [Text.UTF8Encoding]::new($false))
}
