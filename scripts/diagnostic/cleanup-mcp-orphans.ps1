<#
.SYNOPSIS
    Cleanup orphaned MCP server node processes (#1281)
.DESCRIPTION
    Identifies and kills MCP server node processes that no longer have a parent
    Claude Code session (orphaned). Each Claude Code session spawns MCP servers
    via stdio; if the session exits without cleanup, the node processes persist.

    Known MCP server patterns:
    - mcp-searxng (mcp-searxng/dist/index.js)
    - roo-state-manager (roo-state-manager/build/index.js, mcp-wrapper.cjs)
    - playwright (@playwright/mcp/cli.js)
    - win-cli (win-cli/server/dist/index.js)

    Orphan detection: process whose parent PID chain does NOT lead to a running
    Claude Code process (claude.exe or node process with "claude" in cmdline).

.PARAMETER DryRun
    Show what would be killed without actually terminating processes
.PARAMETER Verbose
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

function Get-ParentChain {
    param([int]$ProcessId, [int]$Depth = 0)
    if ($Depth -gt 20) { return @() }
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
        if (-not $proc) { return @() }
        if ($proc.ParentProcessId -eq 0 -or $proc.ParentProcessId -eq 4) { return @($proc) }
        return @($proc) + (Get-ParentChain -ProcessId $proc.ParentProcessId -Depth ($Depth + 1))
    }
    catch { return @() }
}

Write-Host "`n=== MCP Server Orphan Cleanup ===" -ForegroundColor Cyan
Write-Host "Machine: $env:COMPUTERNAME | DryRun: $DryRun`n" -ForegroundColor Gray

# Get all node processes
$allNodeProcs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue
if (-not $allNodeProcs) {
    Write-Host "No node.exe processes found." -ForegroundColor Yellow
    exit 0
}

# Separate MCP server processes from other node processes
$mcpProcs = @()
$otherProcs = @()

foreach ($proc in $allNodeProcs) {
    if (Test-IsMcpServer -CmdLine $proc.CommandLine) {
        $mcpProcs += $proc
    } else {
        $otherProcs += $proc
    }
}

Write-Host "Node processes: $($allNodeProcs.Count) total" -ForegroundColor White
Write-Host "MCP server processes: $($mcpProcs.Count)" -ForegroundColor White
Write-Host "Other node processes: $($otherProcs.Count)`n" -ForegroundColor White

if ($mcpProcs.Count -eq 0) {
    Write-Host "No MCP server processes found." -ForegroundColor Green
    exit 0
}

# Identify Claude Code processes (active sessions)
$claudeProcs = @()
foreach ($proc in $allNodeProcs) {
    if (Test-IsClaudeProcess -CmdLine $proc.CommandLine -ProcessName $proc.Name) {
        $claudeProcs += $proc
    }
}
$codeProcs = Get-Process -Name 'Code' -ErrorAction SilentlyContinue
$totalClaude = $claudeProcs.Count + ($codeProcs | Measure-Object).Count

Write-Host "Active Claude/VS Code processes: $totalClaude`n" -ForegroundColor White

# Classify MCP processes: orphaned vs active
$orphans = @()
$active = @()

foreach ($mcp in $mcpProcs) {
    $parentChain = Get-ParentChain -ProcessId $mcp.ProcessId
    $hasClaudeParent = $false

    foreach ($parent in $parentChain) {
        if (Test-IsClaudeProcess -CmdLine $parent.CommandLine -ProcessName $parent.Name) {
            $hasClaudeParent = $true
            break
        }
        # Also check if parent is Code.exe
        if ($parent.Name -eq 'Code.exe') {
            $hasClaudeParent = $true
            break
        }
    }

    if ($hasClaudeParent) {
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
            $parentChain = Get-ParentChain -ProcessId $proc.ProcessId
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
        Write-Host "DRY RUN — Would kill $($orphans.Count) orphaned process(es):" -ForegroundColor Yellow
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
