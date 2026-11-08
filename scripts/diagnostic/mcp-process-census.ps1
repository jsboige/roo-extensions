# mcp-process-census.ps1 - tree-attributed MCP process census (#4149 instrument, v2)
#
# WHY v2 (web1 measurement 08/11, c.771): per-server-NAME classification does
# not measure what an MCP server COSTS. For ONE claude.exe session the v1 line
# "sk-agent" counted 2 processes / 309 MB while the real tree is 16 processes /
# 1059 MB:
#   - the cmd/powershell wrappers around `python sk_agent.py` matched no rule
#     (`run-sk-agent.ps1` is hyphenated, the v1 rule looked for `sk_agent`);
#   - the children an MCP server spawns itself (npx mcp-searxng,
#     npx @playwright/mcp, markitdown-mcp.exe + its venv pythons) were
#     attributed to the CHILD's server name regardless of who owns them;
#   - the markitdown chain appeared in NO line (it had no rule at all).
#
# Attribution model (v2):
#   1. IDENTITY: each process is tagged by the FIRST rule its OWN command line
#      matches (first-match-wins, same as v1; rule ORDER matters - rsm-wrapper
#      before rsm-server, because a wrapper command line also contains the
#      build path of the child it spawned).
#   2. TREE: a chain root is an own-matching process whose parent does NOT
#      own-match (the parent is the host: claude.exe, Code.exe, or a dead PID).
#      The root's tag propagates to EVERY descendant (conhost.exe excepted) -
#      the real per-server cost is the whole tree, wrappers and children
#      included.
#   3. Three views:
#        servers     - by TREE OWNER (the real cost; what BEFORE/AFTER compares)
#        sub_servers - by IDENTITY (which servers are actually mounted,
#                      including sub-MCPs spawned by other servers)
#        trees       - one row per chain root (host attribution: which parent
#                      process mounted each chain - e.g. Code.exe vs claude.exe)
#
# Known limit: PPID reuse - if a parent dies and its PID is reused by an
# unrelated process, the walk can mis-attribute. Accepted for a census organ.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File mcp-process-census.ps1 [-JsonPath <file>]
# Read-only. No elevation. Windows only for the live census (Win32_Process).
# PS 5.1 compatible. Dot-source-safe: the live census only runs when invoked
# as a script (`$MyInvocation.InvocationName -ne '.'`); the Pester suite
# dot-sources Get-McpProcessCensus and feeds it a measured fixture.

param(
    [string]$JsonPath = ""   # optional: also write the census as JSON
)

$ErrorActionPreference = "Stop"

# First-match-wins on the process's OWN command line - rule ORDER matters:
#   rsm-wrapper before rsm-server (a wrapper command line also contains the
#   roo-state-manager path of the child it spawned).
# sk-agent matches BOTH spellings: the python entry point (`sk_agent.py`,
# underscore) and the wrapper (`run-sk-agent.ps1`, hyphen).
$script:CensusRules = @(
    @{ Tag = 'rsm-wrapper'; Pattern = 'mcp-wrapper\.cjs' },
    @{ Tag = 'rsm-server';  Pattern = 'roo-state-manager[\\/]build' },
    @{ Tag = 'playwright';  Pattern = 'playwright[\\/]mcp|playwright-mcp|@playwright' },
    @{ Tag = 'searxng';     Pattern = 'mcp-searxng' },
    @{ Tag = 'sk-agent';    Pattern = 'sk_agent|run-sk-agent\.ps1' },
    @{ Tag = 'papermill';   Pattern = 'papermill' },
    @{ Tag = 'markitdown';  Pattern = 'markitdown' }
)

function Get-McpProcessCensus {
    # Tree-attributed census over a process snapshot (see script header).
    # Pure: everything comes from the parameters, nothing from the live
    # system - the Pester suite feeds it the 08/11 measured fixture.
    param(
        [Parameter(Mandatory = $true)][object[]]$Processes,     # Win32_Process-like: ProcessId, ParentProcessId, Name, CommandLine
        [Parameter(Mandatory = $true)][hashtable]$WorkingSetMB, # PID -> working set (MB, double)
        [Parameter(Mandatory = $true)][int]$Sessions,           # claude.exe host count (denominator)
        [object[]]$Rules = $script:CensusRules
    )

    function Get-Ws([uint32]$Id) {
        if ($WorkingSetMB.ContainsKey($Id)) { return [double]$WorkingSetMB[$Id] }
        return 0.0
    }

    function New-CensusRow([string]$Tag, $Pids) {
        $wsSum = 0.0
        foreach ($m in $Pids) { $wsSum += (Get-Ws $m) }
        [pscustomobject]@{
            server            = $Tag
            processes         = $Pids.Count
            ws_mb_total       = [math]::Round($wsSum, 1)
            ws_mb_avg         = if ($Pids.Count -gt 0) { [math]::Round($wsSum / $Pids.Count, 1) } else { 0 }
            per_session_procs = if ($Sessions -gt 0) { [math]::Round($Pids.Count / $Sessions, 2) } else { $null }
        }
    }

    # conhost.exe children are console plumbing, not MCP chain members.
    $procs = @($Processes | Where-Object { $_.Name -ne 'conhost.exe' })

    $ById = @{}
    foreach ($p in $procs) { $ById[[uint32]$p.ProcessId] = $p }

    # --- 1. identity tag (own command line, first match wins) ---
    $OwnTag = @{}
    foreach ($p in $procs) {
        if (-not $p.CommandLine) { continue }
        foreach ($r in $Rules) {
            if ($p.CommandLine -match $r.Pattern) {
                $OwnTag[[uint32]$p.ProcessId] = $r.Tag
                break
            }
        }
    }

    # --- children index for the downward walk ---
    $Children = @{}
    foreach ($p in $procs) {
        $pp = [uint32]$p.ParentProcessId
        if (-not $Children.ContainsKey($pp)) {
            $Children[$pp] = [System.Collections.Generic.List[uint32]]::new()
        }
        $Children[$pp].Add([uint32]$p.ProcessId)
    }

    # --- 2. chain roots: own-matching process whose parent does NOT own-match
    #        (absent parent = dead PID: the process is its own root) ---
    $Roots = @()
    foreach ($procId in @($OwnTag.Keys)) {
        $p = $ById[$procId]
        if (-not $OwnTag.ContainsKey([uint32]$p.ParentProcessId)) {
            $Roots += $p
        }
    }

    # --- propagate each root's tag down its whole subtree ---
    $TreeTag = @{}      # PID -> owning root's tag
    $TreeMembers = @{}  # root PID -> member PID list
    foreach ($root in $Roots) {
        $rid = [uint32]$root.ProcessId
        $tag = $OwnTag[$rid]
        $members = [System.Collections.Generic.List[uint32]]::new()
        $stack = [System.Collections.Generic.Stack[uint32]]::new()
        $stack.Push($rid)
        while ($stack.Count -gt 0) {
            $cur = $stack.Pop()
            if ($TreeTag.ContainsKey($cur)) { continue }
            $TreeTag[$cur] = $tag
            $members.Add($cur)
            if ($Children.ContainsKey($cur)) {
                foreach ($c in $Children[$cur]) {
                    if (-not $TreeTag.ContainsKey($c)) { $stack.Push($c) }
                }
            }
        }
        $TreeMembers[$rid] = $members
    }

    # --- 3a. servers: by TREE OWNER (real cost) ---
    $byTag = @{}
    foreach ($root in $Roots) {
        $t = $OwnTag[[uint32]$root.ProcessId]
        if (-not $byTag.ContainsKey($t)) { $byTag[$t] = [System.Collections.Generic.List[uint32]]::new() }
        $byTag[$t].AddRange($TreeMembers[[uint32]$root.ProcessId])
    }
    $serverRows = @()
    foreach ($t in ($byTag.Keys | Sort-Object)) { $serverRows += (New-CensusRow $t $byTag[$t]) }

    # --- 3b. sub_servers: by IDENTITY (who is actually mounted) ---
    $subByTag = @{}
    foreach ($k in @($OwnTag.Keys)) {
        $t = $OwnTag[$k]
        if (-not $subByTag.ContainsKey($t)) { $subByTag[$t] = [System.Collections.Generic.List[uint32]]::new() }
        $subByTag[$t].Add($k)
    }
    $subRows = @()
    foreach ($t in ($subByTag.Keys | Sort-Object)) { $subRows += (New-CensusRow $t $subByTag[$t]) }

    # --- 3c. trees: one row per chain root (host attribution) ---
    $treeRows = @()
    foreach ($root in ($Roots | Sort-Object @{ Expression = { $OwnTag[[uint32]$_.ProcessId] } }, @{ Expression = { [uint32]$_.ProcessId } })) {
        $rid = [uint32]$root.ProcessId
        $parentId = [uint32]$root.ParentProcessId
        $parentName = '(dead)'
        if ($ById.ContainsKey($parentId)) { $parentName = $ById[$parentId].Name }
        $members = $TreeMembers[$rid]
        $wsSum = 0.0
        foreach ($m in $members) { $wsSum += (Get-Ws $m) }
        $treeRows += [pscustomobject]@{
            tag         = $OwnTag[$rid]
            root_pid    = $rid
            root_name   = $root.Name
            parent_pid  = $parentId
            parent_name = $parentName
            processes   = $members.Count
            ws_mb_total = [math]::Round($wsSum, 1)
        }
    }

    $totalProcs = 0
    $totalWs = 0.0
    foreach ($r in $serverRows) { $totalProcs += $r.processes; $totalWs += $r.ws_mb_total }

    return [pscustomobject]@{
        servers     = $serverRows
        sub_servers = $subRows
        trees       = $treeRows
        total_procs = $totalProcs
        total_ws_mb = [math]::Round($totalWs, 1)
    }
}

# --- live census (only when run as a script, not when dot-sourced) ---
if ($MyInvocation.InvocationName -ne '.') {
    $live = Get-CimInstance Win32_Process -Filter "Name != 'conhost.exe'"
    $ws = @{}
    foreach ($p in Get-Process) { $ws[[uint32]$p.Id] = [math]::Round($p.WorkingSet64 / 1MB, 1) }
    $sessions = @(Get-Process -Name claude -ErrorAction SilentlyContinue).Count

    $census = Get-McpProcessCensus -Processes $live -WorkingSetMB $ws -Sessions $sessions

    $machine = $env:COMPUTERNAME
    $stamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "MCP process census (tree attribution) - $machine $stamp" -ForegroundColor Cyan
    Write-Host "claude.exe hosts (sessions): $sessions" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "== by TREE OWNER (real cost per owning server) ==" -ForegroundColor Yellow
    Write-Host ($census.servers | Format-Table -AutoSize | Out-String -Width 120)
    Write-Host "== by IDENTITY (sub-servers actually mounted, incl. sub-MCPs) ==" -ForegroundColor Yellow
    Write-Host ($census.sub_servers | Format-Table -AutoSize | Out-String -Width 120)
    Write-Host "== chain roots (host attribution) ==" -ForegroundColor Yellow
    Write-Host ($census.trees | Format-Table -AutoSize | Out-String -Width 160)
    Write-Host ("TOTAL (tree view): {0} processes, {1} MB working set" -f $census.total_procs, $census.total_ws_mb) -ForegroundColor Cyan

    if ($JsonPath) {
        # Resolve against the POWERSHELL location (WriteAllText uses the .NET
        # process cwd, which can differ).
        $absJson = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($JsonPath)
        $payload = [pscustomobject]@{
            machine     = $machine
            timestamp   = $stamp
            sessions    = $sessions
            servers     = $census.servers
            sub_servers = $census.sub_servers
            trees       = $census.trees
            total_procs = $census.total_procs
            total_ws_mb = $census.total_ws_mb
        }
        # UTF-8 WITHOUT BOM: Set-Content adds a BOM on PS 5.1 and breaks JSON
        # consumers that do not strip it.
        [System.IO.File]::WriteAllText($absJson, ($payload | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
        Write-Host "[JSON] Written to $absJson" -ForegroundColor Green
    }
}
