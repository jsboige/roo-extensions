<#
.SYNOPSIS
    Cleanup orphaned MCP server node processes (#1281)
.DESCRIPTION
    Identifies and kills MCP server node processes that no longer have a parent
    Claude Code session (orphaned). Each Claude Code session spawns MCP servers
    via stdio; if the session exits without cleanup, the node processes persist.

    Performance: Single WMI query fetches ALL processes, then parent chains are
    resolved in-memory via hashtable lookup. O(N) instead of O(N*depth) WMI calls.

    Known MCP server patterns:
    - mcp-searxng (mcp-searxng/dist/index.js)
    - roo-state-manager (roo-state-manager/build/index.js, mcp-wrapper.cjs)
    - playwright (@playwright/mcp/cli.js)
    - win-cli (win-cli/server/dist/index.js)

.PARAMETER DryRun
    Show what would be killed without actually terminating processes
.PARAMETER VerboseOutput
    Show detailed process information including parent chain
.EXAMPLE
    .\cleanup-mcp-orphans.ps1
    .\cleanup-mcp-orphans.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Continue"

# MCP server command-line patterns (substrings to match)
$McpPatterns = @(
    'mcp-searxng\dist\index.js'
    'roo-state-manager\build\index.js'
    'roo-state-manager\mcp-wrapper.cjs'
    '@playwright\mcp\cli.js'
    'win-cli\server\dist\index.js'
    'mcp-searxng'             # npx wrapper
    '@playwright/mcp'         # npx wrapper
)

# Claude Code process patterns (parent chain target)
$ClaudePatterns = @(
    'claude'
    'Code.exe'
    'claud'
)

function Test-IsMcpServer {
    param([string]$CmdLine)
    foreach ($pattern in $McpPatterns) {
        if ($CmdLine -like "*$pattern*") { return $true }
    }
    return $false
}

function Test-IsClaudeProcess {
    param([string]$CmdLine, [string]$ProcessName)
    if ($ProcessName -like '*Code*') { return $true }
    foreach ($pattern in $ClaudePatterns) {
        if ($CmdLine -like "*$pattern*") { return $true }
    }
    return $false
}

Write-Host "`n=== MCP Server Orphan Cleanup ===" -ForegroundColor Cyan
Write-Host "Machine: $env:COMPUTERNAME | DryRun: $DryRun`n" -ForegroundColor Gray

# Single WMI query: fetch ALL processes into a hashtable (PID -> process object)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$allProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
$sw.Stop()

if (-not $allProcs) {
    Write-Host "WMI query: $($sw.ElapsedMilliseconds)ms — no results (WMI failure?)" -ForegroundColor DarkGray
    Write-Host "No processes found via WMI." -ForegroundColor Yellow
    exit 0
}

Write-Host "WMI query: $($sw.ElapsedMilliseconds)ms ($($allProcs.Count) processes)" -ForegroundColor DarkGray

# Build PID -> process hashtable and PID -> ParentPID map
$procById = @{}
foreach ($proc in $allProcs) {
    $procById[$proc.ProcessId] = $proc
}

# Get all node processes from the hashtable
$allNodeProcs = @($allProcs | Where-Object { $_.Name -eq 'node.exe' })
if ($allNodeProcs.Count -eq 0) {
    Write-Host "No node.exe processes found." -ForegroundColor Yellow
    exit 0
}

# Separate MCP server processes from other node processes
$mcpProcs = @($allNodeProcs | Where-Object { Test-IsMcpServer -CmdLine $_.CommandLine })
$otherProcs = @($allNodeProcs | Where-Object { -not (Test-IsMcpServer -CmdLine $_.CommandLine) })

Write-Host "Node processes: $($allNodeProcs.Count) total" -ForegroundColor White
Write-Host "MCP server processes: $($mcpProcs.Count)" -ForegroundColor White
Write-Host "Other node processes: $($otherProcs.Count)`n" -ForegroundColor White

if ($mcpProcs.Count -eq 0) {
    Write-Host "No MCP server processes found." -ForegroundColor Green
    exit 0
}

# Identify Claude Code processes (active sessions) from hashtable
$claudeProcs = @($allProcs | Where-Object { Test-IsClaudeProcess -CmdLine $_.CommandLine -ProcessName $_.Name })
$codeProcs = Get-Process -Name 'Code' -ErrorAction SilentlyContinue
$totalClaude = $claudeProcs.Count + ($codeProcs | Measure-Object).Count

Write-Host "Active Claude/VS Code processes: $totalClaude`n" -ForegroundColor White

# Pre-compute which PIDs are Claude/VS Code ancestors (BFS from all Claude PIDs upward)
$claudeAncestorPids = @{}
foreach ($cp in $claudeProcs) {
    $claudeAncestorPids[$cp.ProcessId] = $true
}
foreach ($cp in $codeProcs) {
    $claudeAncestorPids[$cp.Id] = $true
}

# Walk parent chains in-memory using the hashtable (no WMI calls)
function Test-HasClaudeParent {
    param([int]$ProcessId)
    $visited = @{}
    $currentPid = $ProcessId
    while ($currentPid -and $currentPid -ne 0 -and $currentPid -ne 4 -and -not $visited[$currentPid]) {
        $visited[$currentPid] = $true
        if ($claudeAncestorPids[$currentPid]) { return $true }
        $proc = $procById[$currentPid]
        if (-not $proc) { return $false }
        if (Test-IsClaudeProcess -CmdLine $proc.CommandLine -ProcessName $proc.Name) { return $true }
        if ($proc.Name -eq 'Code.exe') { return $true }
        $currentPid = $proc.ParentProcessId
    }
    return $false
}

function Get-ParentChainInMemory {
    param([int]$ProcessId)
    $chain = @()
    $visited = @{}
    $currentPid = $ProcessId
    while ($currentPid -and $currentPid -ne 0 -and $currentPid -ne 4 -and -not $visited[$currentPid]) {
        $visited[$currentPid] = $true
        $proc = $procById[$currentPid]
        if (-not $proc) { break }
        $chain += $proc
        $currentPid = $proc.ParentProcessId
    }
    return $chain
}

# Classify MCP processes: orphaned vs active (all in-memory)
$orphans = @()
$active = @()

foreach ($mcp in $mcpProcs) {
    if (Test-HasClaudeParent -ProcessId $mcp.ProcessId) {
        $active += $mcp
    } else {
        $orphans += $mcp
    }
}

# Display results
if ($orphans.Count -gt 0) {
    Write-Host "ORPHANED MCP servers ($($orphans.Count)):" -ForegroundColor Red
    foreach ($proc in $orphans) {
        $memMB = [math]::Round($proc.WorkingSetSize / 1MB, 1)
        $cmdShort = if ($proc.CommandLine.Length -gt 80) { $proc.CommandLine.Substring(0, 80) + '...' } else { $proc.CommandLine }
        Write-Host "  PID: $($proc.ProcessId) | Mem: ${memMB}MB | $cmdShort" -ForegroundColor Yellow

        if ($VerboseOutput) {
            $parentChain = Get-ParentChainInMemory -ProcessId $proc.ProcessId
            foreach ($p in $parentChain) {
                Write-Host "    -> PID:$($p.ProcessId) $($p.Name)" -ForegroundColor DarkGray
            }
        }
    }
} else {
    Write-Host "No orphaned MCP servers found." -ForegroundColor Green
}

if ($active.Count -gt 0) {
    Write-Host "`nACTIVE MCP servers ($($active.Count)):" -ForegroundColor Green
    foreach ($proc in $active) {
        $memMB = [math]::Round($proc.WorkingSetSize / 1MB, 1)
        $cmdShort = if ($proc.CommandLine.Length -gt 80) { $proc.CommandLine.Substring(0, 80) + '...' } else { $proc.CommandLine }
        Write-Host "  PID: $($proc.ProcessId) | Mem: ${memMB}MB | $cmdShort" -ForegroundColor Gray
    }
}

# Cleanup orphans
if ($orphans.Count -gt 0) {
    Write-Host ""
    if ($DryRun) {
        Write-Host "DRY RUN - Would kill $($orphans.Count) orphaned process(es):" -ForegroundColor Yellow
        foreach ($proc in $orphans) {
            Write-Host "  Stop-Process -Id $($proc.ProcessId) -Force" -ForegroundColor Yellow
        }
    } else {
        $killed = 0
        $failed = 0
        foreach ($proc in $orphans) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                $killed++
                Write-Host "  Killed PID $($proc.ProcessId)" -ForegroundColor Green
            } catch {
                $failed++
                Write-Host "  FAILED PID $($proc.ProcessId): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host "`nResult: $killed killed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
    }
} else {
    Write-Host "`nNothing to clean up." -ForegroundColor Green
}

Write-Host ""
