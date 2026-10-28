# configure-sk-agent-http-client.ps1 - point the seat's Claude Code at the shared daemon (#4149 F2)
#
# Flips the sk-agent entry in ~/.claude.json from a per-session stdio command
# to the shared streamable-http daemon started by start-sk-agent-daemon.ps1:
#   { "type": "http", "url": "http://127.0.0.1:8100/mcp",
#     "headers": { "Authorization": "Bearer <key from $KeyFile>" } }
#
# Safety: timestamped .bak-<stamp> backup before every mutation, round-trip
# verification (entry shape + top-level key count) with automatic restore on
# mismatch, idempotent no-op when already configured. The key is written to
# the config but NEVER printed (user-profile file, same vault as other MCP
# secrets). Use -Restore to roll back to the newest backup (stdio comes back).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\configure-sk-agent-http-client.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\configure-sk-agent-http-client.ps1 -Restore
# Exit codes: 0 = configured (or already was / restored), 1 = failure (restored if mid-flight).

[CmdletBinding()]
param(
    [string]$ConfigPath = "$env:USERPROFILE\.claude.json",
    [int]$Port = 8100,
    [string]$BindHost = '127.0.0.1',
    [string]$KeyFile = "$env:USERPROFILE\.sk-agent\daemon-api.key",
    [string]$ServerName = 'sk-agent',
    [switch]$Restore,
    # Explicit rollback source; wins over the automatic pick.
    [string]$RestorePath = ''
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ConfigPath)) { Write-Output "[FAIL] config not found: $ConfigPath"; exit 1 }

function Read-Config([string]$Path) {
    # NB: NEVER `Get-Content -Raw` here. Under PS 5.1 it decodes a UTF-8 file
    # WITHOUT BOM using the ANSI code page: every non-ASCII character (·, —, █,
    # accented text) comes back mojibake, and the UTF-8 write then persists the
    # double encoding. Measured on the real ~/.claude.json (2026-10-28): 16
    # mangled strings across cached feature-flag text. File.ReadAllText
    # defaults to UTF-8 (BOM-aware) and keeps the content byte-faithful.
    ([System.IO.File]::ReadAllText($Path)) | ConvertFrom-Json
}

function Compare-Json($A, $B, [string]$Path, $Acc) {
    # Recursive semantic comparison; used as a write gate so a round-trip can
    # never silently corrupt untouched content. $Acc is an ArrayList of paths.
    if ($null -eq $A -and $null -eq $B) { return }
    $aIsObj = ($A -is [pscustomobject]); $bIsObj = ($B -is [pscustomobject])
    if ($aIsObj -ne $bIsObj) { [void]$Acc.Add("${Path}: object/scalar mismatch"); return }
    if ($aIsObj) {
        $pa = @($A.PSObject.Properties.Name) | Sort-Object
        $pb = @($B.PSObject.Properties.Name) | Sort-Object
        foreach ($k in @($pa | Where-Object { $pb -notcontains $_ })) { [void]$Acc.Add("${Path}.${k}: removed") }
        foreach ($k in @($pb | Where-Object { $pa -notcontains $_ })) { [void]$Acc.Add("${Path}.${k}: added") }
        foreach ($k in @($pa | Where-Object { $pb -contains $_ })) { Compare-Json $A.$k $B.$k "${Path}.${k}" $Acc }
        return
    }
    if ($A -is [System.Array] -or $B -is [System.Array]) {
        $aa = @($A); $bb = @($B)
        if ($aa.Count -ne $bb.Count) { [void]$Acc.Add("${Path}: array $($aa.Count)->$($bb.Count)"); return }
        for ($i = 0; $i -lt $aa.Count; $i++) { Compare-Json $aa[$i] $bb[$i] "${Path}[$i]" $Acc }
        return
    }
    if ("$A" -ne "$B") { [void]$Acc.Add("${Path}: value changed") }
}
function Write-ConfigNoBom([string]$Path, $Object) {
    # -Depth 32: .claude.json nests deeper than the PS 5.1 default (2).
    $json = $Object | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

# --- Restore path: newest backup BY TIMESTAMP, never by name ---
if ($Restore) {
    $leaf = Split-Path -Leaf $ConfigPath
    $dir = Split-Path -Parent $ConfigPath
    $bak = $null
    if ($RestorePath) {
        if (-not (Test-Path $RestorePath)) { Write-Output "[FAIL] -RestorePath not found: $RestorePath"; exit 1 }
        $bak = Get-Item $RestorePath
    } else {
        # Only files THIS script named (`<leaf>.bak-YYYYMMDD-HHmmss`), newest by
        # LastWriteTimeUtc. Sorting by Name is wrong: a third party's older
        # `.bak-skagent-YYYYMMDD` sorts above a newer `.bak-YYYYMMDD-HHmmss`
        # ('s' > '2') and silently rolls the seat back weeks (measured
        # 2026-10-28: it picked a 3-week-old file).
        $bak = Get-ChildItem $dir -Filter "$leaf.bak-*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "^$([regex]::Escape($leaf))\.bak-\d{8}-\d{6}$" } |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    }
    if (-not $bak) {
        Write-Output "[FAIL] no backup created by this script ($leaf.bak-<YYYYMMDD-HHmmss>) next to $ConfigPath"
        Write-Output "       name the file explicitly: -Restore -RestorePath <path>"
        Get-ChildItem $dir -Filter "$leaf.bak-*" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            ForEach-Object { Write-Output "       candidate (NOT used): $($_.Name) [$($_.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z]" }
        exit 1
    }
    Copy-Item $bak.FullName $ConfigPath -Force
    $check = Read-Config $ConfigPath
    if (-not $check.mcpServers) { Write-Output "[FAIL] restored file has no mcpServers - aborting"; exit 1 }
    Write-Output "[OK] restored $ConfigPath from $($bak.Name) [$($bak.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z, $($bak.Length) bytes]"
    exit 0
}

if (-not (Test-Path $KeyFile)) {
    Write-Output "[FAIL] key file not found: $KeyFile"
    Write-Output "       start the daemon first: start-sk-agent-daemon.ps1 (it generates the key)"
    exit 1
}
$apiKey = ([System.IO.File]::ReadAllText($KeyFile)).Trim()
if (-not $apiKey) { Write-Output "[FAIL] key file is empty: $KeyFile"; exit 1 }

$targetUrl = "http://${BindHost}:${Port}/mcp"
$before = Read-Config $ConfigPath
$pristine = Read-Config $ConfigPath   # untouched copy: the write gate below needs it
$beforeKeys = @($before.PSObject.Properties.Name)
$entry = $before.mcpServers.$ServerName

# --- Idempotence: same url AND same bearer -> nothing to do ---
if ($entry -and $entry.type -eq 'http' -and $entry.url -eq $targetUrl -and $entry.headers -and $entry.headers.Authorization -eq "Bearer $apiKey") {
    Write-Output "[OK] $ServerName already points at the daemon ($targetUrl) - nothing to do"
    exit 0
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$bakPath = "$ConfigPath.bak-$stamp"
Copy-Item $ConfigPath $bakPath -Force

$beforeShape = '[stdio]'
if ($entry -and $entry.type) { $beforeShape = $entry.type }

$before.mcpServers.$ServerName = [PSCustomObject]@{
    type = 'http'
    url = $targetUrl
    headers = [PSCustomObject]@{ Authorization = "Bearer $apiKey" }
}
Write-ConfigNoBom $ConfigPath $before

# --- Round-trip verification: entry shape, key population, and CONTENT INTEGRITY ---
# The content gate is the one that matters: a decoding bug in the read path
# rewrites every non-ASCII string in the file while leaving the flipped entry
# perfectly correct. Compare everything except the entry we meant to change.
$after = Read-Config $ConfigPath
$verdict = "$($after.mcpServers.$ServerName.type) @ $($after.mcpServers.$ServerName.url)"
if ($after.mcpServers.$ServerName.type -ne 'http' -or $after.mcpServers.$ServerName.url -ne $targetUrl) {
    Copy-Item $bakPath $ConfigPath -Force
    Write-Output "[FAIL] verification failed (entry = $verdict) - backup restored"
    exit 1
}
$missing = @($beforeKeys | Where-Object { @($after.PSObject.Properties.Name) -notcontains $_ })
if ($missing.Count -gt 0) {
    Copy-Item $bakPath $ConfigPath -Force
    Write-Output "[FAIL] top-level keys lost in round-trip ($($missing -join ', ')) - backup restored"
    exit 1
}
$pristine.mcpServers.$ServerName = '<intentionally flipped>'
$after.mcpServers.$ServerName = '<intentionally flipped>'
$diffs = New-Object System.Collections.ArrayList
Compare-Json $pristine $after 'root' $diffs
if ($diffs.Count -gt 0) {
    Copy-Item $bakPath $ConfigPath -Force
    Write-Output "[FAIL] round-trip altered $($diffs.Count) untouched value(s) - backup restored"
    $diffs | Select-Object -First 8 | ForEach-Object { Write-Output "       $_" }
    exit 1
}

Write-Output "[OK] $ServerName : $beforeShape -> http @ $targetUrl (bearer from $KeyFile, never printed)"
Write-Output "     backup: $bakPath ; rollback: configure-sk-agent-http-client.ps1 -Restore"
exit 0
