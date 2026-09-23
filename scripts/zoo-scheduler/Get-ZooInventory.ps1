<#
.SYNOPSIS
    Read-only Zoo/Roo inventory of this machine, printed as markdown for
    jsboige-mcp-servers#490 (vague 7, item 1).

.DESCRIPTION
    Measures the seven points of the mcp#490 format in one run, so each lane
    pastes the output instead of rebuilding the measurement by hand:
      1. installed extensions (Zoo, Roo, and the scheduler extension that runs
         schedules.json) and the active one
      2. .roo/ and .zoo/ schedules.json of every workspace folder VS Code has
         opened; `active` only means something if a scheduler extension is
         installed, so the section says so when none is
      3. task activity (total, last 7 days, last 30 days per workspace/profile)
      4. model profiles: autoImportSettingsPath (a path) and profile NAMES
      5. modes and rules per workspace
      6. MCP servers configured for the extension (names + disabled flag)
      7. meeting points with Claude (roo-state-manager, win-cli)

    Names only: no env values, no args, no keys are ever printed. Nothing is
    written anywhere. Works under Windows PowerShell 5.1 and pwsh 7.

.PARAMETER Machine
    Machine name for the heading. Default: $env:COMPUTERNAME, lowercased.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\zoo-scheduler\Get-ZooInventory.ps1
#>
[CmdletBinding()]
param(
    [string]$Machine = $env:COMPUTERNAME.ToLower()
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\common\extension-paths.ps1"

$out = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$Text) { $out.Add($Text) }
# pwsh 7 turns ISO strings into [datetime] on ConvertFrom-Json, 5.1 keeps strings: print both alike.
function Format-When($Value) {
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + 'Z' }
    $d = [datetimeoffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetimeoffset]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) {
        return $d.UtcDateTime.ToString('yyyy-MM-dd HH:mm') + 'Z'
    }
    return [string]$Value
}

$now = (Get-Date).ToUniversalTime()
Add-Line "## Zoo inventory: $Machine (Get-ZooInventory.ps1, $($now.ToString('yyyy-MM-dd HH:mm'))Z)"
Add-Line ""
Add-Line "Names only, never key values."
Add-Line ""

# --- 1. Installed -----------------------------------------------------------
Add-Line "**1. Installed?**"
$extRoot = Join-Path $env:USERPROFILE ".vscode\extensions"
# extensions.json is VS Code's list of what is installed; a version folder can outlive its uninstall.
$registry = $null
$regPath = Join-Path $extRoot "extensions.json"
if (Test-Path $regPath) { try { $registry = Get-Content -LiteralPath $regPath -Raw | ConvertFrom-Json } catch { $registry = $null } }
# Zoo Code has no scheduler of its own: .roo/.zoo schedules.json run only through one of these.
$schedulerIds = @('jsboige.zoo-scheduler', 'kylehoskins.roo-scheduler')
$installedSchedulers = @()
foreach ($id in @($ZooExtensionId, $RooExtensionId) + $schedulerIds) {
    if ($null -ne $registry) {
        $versions = @($registry | Where-Object { $_.identifier.id -eq $id } | ForEach-Object { $_.version })
    } else {
        $dirs = @()
        if (Test-Path $extRoot) { $dirs = @(Get-ChildItem $extRoot -Directory -Filter "$id-*" -ErrorAction SilentlyContinue) }
        $versions = @($dirs | ForEach-Object { $_.Name.Substring($id.Length + 1) })
    }
    $v = if ($versions.Count) { $versions -join ', ' } else { 'not installed' }
    if ($schedulerIds -contains $id) {
        if ($versions.Count) { $installedSchedulers += $id }
        $gs = Test-Path (Join-Path $env:APPDATA "Code\User\globalStorage\$id")
        Add-Line "- ``$id`` (scheduler): $v; globalStorage present: $gs"
        continue
    }
    $gs = Test-Path (Get-GlobalStoragePath -Extension $(if ($id -eq $ZooExtensionId) { 'ZooCode' } else { 'RooCode' }))
    Add-Line "- ``$id``: $v; globalStorage present: $gs"
}
$active = Get-ActiveExtension
Add-Line "- Active extension (probe on mcp_settings.json): **$active**"
Add-Line ""

# Workspace folders VS Code has opened (workspaceStorage/*/workspace.json).
$folders = @{}
$skipped = 0   # WSL, containers, other remotes, missing folders, multi-root .code-workspace
$wsRoot = Join-Path $env:APPDATA "Code\User\workspaceStorage"
if (Test-Path $wsRoot) {
    foreach ($f in Get-ChildItem $wsRoot -Directory -ErrorAction SilentlyContinue) {
        $wj = Join-Path $f.FullName "workspace.json"
        if (-not (Test-Path $wj)) { continue }
        try { $uri = (Get-Content -LiteralPath $wj -Raw | ConvertFrom-Json).folder } catch { $skipped++; continue }
        if (-not $uri -or $uri -notlike 'file:///*') { $skipped++; continue }
        # [uri]::LocalPath keeps "/d:/x" for "file:///d%3A/x": decode by hand.
        $path = [uri]::UnescapeDataString($uri.Substring(8)).Replace('/', [IO.Path]::DirectorySeparatorChar)
        if (-not (Test-Path -LiteralPath $path)) { $skipped++; continue }
        if (-not $folders.ContainsKey($path.ToLower())) { $folders[$path.ToLower()] = $path }
    }
}
$workspaces = @($folders.Values | Sort-Object)

# --- 2. Schedules -----------------------------------------------------------
Add-Line "**2. Schedules** (``.roo/`` and ``.zoo/`` ``schedules.json`` in the $($workspaces.Count) local workspace folders VS Code has opened; $skipped entries not scanned: WSL, containers, remotes, multi-root or deleted folders)"
if (-not $installedSchedulers.Count) {
    $names = ($schedulerIds | ForEach-Object { '`' + $_ + '`' }) -join ', '
    Add-Line "- **No scheduler extension installed** ($names): nothing runs the schedules below on this machine, whatever their ``active`` flag says."
}
$found = 0
foreach ($ws in $workspaces) {
    foreach ($dir in @('.roo', '.zoo')) {
        $sj = Join-Path $ws "$dir\schedules.json"
        if (-not (Test-Path -LiteralPath $sj)) { continue }
        $found++
        try { $sched = @((Get-Content -LiteralPath $sj -Raw | ConvertFrom-Json).schedules) } catch { Add-Line "- ``$ws`` ``$dir``: unreadable ($($_.Exception.Message))"; continue }
        foreach ($s in $sched) {
            Add-Line "- ``$ws`` ``$dir``: **$($s.name)**, active=$($s.active), mode=$($s.mode), every $($s.timeInterval) $($s.timeUnit), last=$(Format-When $s.lastExecutionTime), next=$(Format-When $s.nextExecutionTime)"
        }
    }
}
if (-not $found) { Add-Line "- No ``schedules.json`` in ``.roo/`` or ``.zoo/`` of any opened workspace." }
Add-Line ""

# --- 3. Activity ------------------------------------------------------------
$tasksDir = Join-Path (Get-GlobalStoragePath -Extension $active) "tasks"
Add-Line "**3. Activity** (``$active`` tasks)"
$allTasks = @()
# ".skeletons" and other dot-dirs are roo-state-manager caches, not tasks.
if (Test-Path $tasksDir) { $allTasks = @(Get-ChildItem $tasksDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '.*' }) }
$recent = @($allTasks | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) })
$last7 = @($recent | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) })
$newest = $allTasks | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$newestText = if ($newest) { $newest.LastWriteTime.ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + 'Z' } else { 'none' }
Add-Line "- $($allTasks.Count) task dirs; $($last7.Count) touched in the last 7 days; most recent: $newestText"
$byWs = @{}; $byProfile = @{}
foreach ($t in $recent) {
    $hi = Join-Path $t.FullName "history_item.json"
    if (-not (Test-Path $hi)) { continue }
    try { $h = Get-Content $hi -Raw | ConvertFrom-Json } catch { continue }
    $w = if ($h.workspace) { $h.workspace } else { '(none)' }
    $p = if ($h.apiConfigName) { "$($h.apiConfigName) / $($h.mode)" } else { "(none) / $($h.mode)" }
    $byWs[$w] = 1 + [int]$byWs[$w]; $byProfile[$p] = 1 + [int]$byProfile[$p]
}
if ($byWs.Count) {
    Add-Line ("- Last 30 days by workspace: " + (($byWs.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "``$($_.Key)`` $($_.Value)" }) -join ', '))
    Add-Line ("- Last 30 days by profile / mode: " + (($byProfile.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', '))
}
Add-Line ""

# --- 4. Model profiles ------------------------------------------------------
Add-Line "**4. Model profiles** (profile values live in VS Code secret storage and are not read)"
$userSettings = Join-Path $env:APPDATA "Code\User\settings.json"
if (Test-Path $userSettings) {
    $raw = Get-Content $userSettings -Raw
    foreach ($key in @('zoo-code.autoImportSettingsPath', 'roo-cline.autoImportSettingsPath')) {
        $m = [regex]::Match($raw, '"' + [regex]::Escape($key) + '"\s*:\s*"([^"]*)"')
        if ($m.Success) {
            $target = $m.Groups[1].Value -replace '\\\\', '\'
            $expanded = [Environment]::ExpandEnvironmentVariables($target)
            Add-Line "- ``$key`` = ``$target``; target exists here: $(Test-Path $expanded)"
        } else { Add-Line "- ``$key``: not set" }
    }
}
Add-Line ""

# --- 5. Modes and rules -----------------------------------------------------
Add-Line "**5. Modes and rules**"
$cm = Join-Path (Get-GlobalStoragePath -Extension $active) "settings\custom_modes.yaml"
if (Test-Path $cm) { Add-Line "- Global ``custom_modes.yaml``: $(@(Select-String -Path $cm -Pattern '^\s*-\s*slug:').Count) modes" }
foreach ($ws in $workspaces) {
    $rm = Join-Path $ws ".roomodes"
    $rulesDirs = @(Get-ChildItem -LiteralPath $ws -Directory -Filter ".roo" -Force -ErrorAction SilentlyContinue | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -Filter "rules*" -ErrorAction SilentlyContinue })
    if (-not (Test-Path -LiteralPath $rm) -and -not $rulesDirs.Count) { continue }
    $modes = if (Test-Path -LiteralPath $rm) { @(Select-String -LiteralPath $rm -Pattern '"slug"\s*:|^\s*-\s*slug:').Count } else { 0 }
    $cfg = if (Test-Path -LiteralPath $rm) { @(Select-String -LiteralPath $rm -Pattern 'apiConfigId').Count } else { 0 }
    $rules = @($rulesDirs | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Recurse -ErrorAction SilentlyContinue }).Count
    Add-Line "- ``$ws``: .roomodes $(if (Test-Path -LiteralPath $rm) { "$modes modes, $cfg apiConfigId" } else { 'absent' }); .roo/rules* $rules files"
}
Add-Line ""

# --- 6. Tools ---------------------------------------------------------------
$mcpPath = Get-McpSettingsPath -Extension $(if ($active -eq 'ZooCode') { 'ZooCode' } else { 'RooCode' })
Add-Line "**6. Tools** (``$active`` ``mcp_settings.json``)"
$serverNames = @()
if (Test-Path $mcpPath) {
    try {
        $servers = (Get-Content $mcpPath -Raw | ConvertFrom-Json).mcpServers
        foreach ($p in @($servers.PSObject.Properties)) {
            $serverNames += $p.Name
            Add-Line "- ``$($p.Name)`` disabled=$([bool]$p.Value.disabled)"
        }
        if (-not $serverNames.Count) { Add-Line "- No MCP server configured." }
    } catch { Add-Line "- unreadable ($($_.Exception.Message))" }
} else { Add-Line "- ``mcp_settings.json`` absent." }
Add-Line ""

# --- 7. Meeting points with Claude ------------------------------------------
Add-Line "**7. Meeting points with Claude**"
Add-Line "- roo-state-manager (dashboards, RooSync) reachable from $active`: $($serverNames -contains 'roo-state-manager')"
Add-Line "- win-cli (terminal for -simple/-complex modes): $(@($serverNames | Where-Object { $_ -like 'win-cli*' }).Count -gt 0)"
Add-Line "- Claims, INTERCOM and escalations: add by hand if any."

$out -join [Environment]::NewLine
