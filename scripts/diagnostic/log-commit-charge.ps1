# log-commit-charge.ps1 — commit-charge logger for #2992 (read-only)
#
# What ai-01 asked for (issue #2992, 22/09 22:00Z): "the cheapest step is a
# counter logger for CommittedBytes/CommitLimit every 10 s, started before the
# next vLLM restart" — the peak commit during vLLM loading has never been
# measured, and nothing on the host logs these counters continuously.
#
# Locale-proof BY CONSTRUCTION (#2992 known defect): the archived original
# (scripts/_archive/cleanup-3323-2026-08-31/) read perf counters by English
# name and silently skipped them on FR locales — the MissingCommit columns
# never populated on ai-01. This logger uses only WMI/CIM classes whose
# property names are English on every locale:
#   - Win32_PerfFormattedData_PerfOS_Memory : CommittedBytes, CommitLimit,
#     PoolPagedBytes, PoolNonpagedBytes
#   - Win32_OperatingSystem                : FreeVirtualMemory (KB) — the
#     source of the original issue measurement, kept so each sample
#     self-validates the identity  FreeVirtualMemory ~ CommitLimit-Committed
#   - Win32_PageFileUsage                  : AllocatedBaseSize (MB) — ai-01
#     proved the CommitLimit follows the pagefile, so the pagefile size is
#     logged with it
#   - Get-Process                          : sum of PagedMemorySize64 (private
#     commit), same accounting as ai-01's 22/09 comment
#
# Output: one JSON line per sample in <OutputDir>\samples.jsonl plus a
# <OutputDir>\_summary.json written on exit (Ctrl+C included — finally block).
# UTF-8 without BOM (#3398). PS 5.1 compatible (no ?? / ternary).
#
# Usage (ai-01 runbook):
#   powershell -ExecutionPolicy Bypass -File scripts\diagnostic\log-commit-charge.ps1 `
#       -OutputDir C:\temp\memdiag\peak -IntervalSec 10
#   # ...then, in another terminal: docker start myia_vllm-medium-qwen36-moe
#   # stop with Ctrl+C once the model is loaded; post samples.jsonl to #2992.
#
# Read-only: no service is touched, nothing is written outside OutputDir.

[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $env:TEMP ("commit-charge-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [int]$IntervalSec = 10,
    # 0 = run until Ctrl+C (the runbook case: start the logger first, then
    # trigger the vLLM restart, then stop it).
    [int]$DurationSec = 0
)

$ErrorActionPreference = 'Stop'

if ($IntervalSec -lt 1) { throw "IntervalSec must be >= 1 (got $IntervalSec)" }
if ($DurationSec -lt 0) { throw "DurationSec must be >= 0 (got $DurationSec)" }

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$samplesPath = Join-Path $OutputDir 'samples.jsonl'
$summaryPath = Join-Path $OutputDir '_summary.json'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$startUtc = (Get-Date).ToUniversalTime()
$first = $null
$last = $null
$peakCommitted = [long]-1
$peakUnattributed = [long]-1
$count = 0

function Get-CommitSample {
    # One sample = one JSON-ready ordered hashtable. Every CIM read is a
    # separate query: they land a few ms apart, which is why the identity
    # check (FreeVirtualMemoryKB vs CommitLimit-CommittedBytes) is asserted
    # with a tolerance, not for equality.
    $mem = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $pagefiles = @(Get-CimInstance -ClassName Win32_PageFileUsage)
    $sumProcessCommit = [long]0
    foreach ($p in (Get-Process)) { $sumProcessCommit += [long]$p.PagedMemorySize64 }

    $committed = [long]$mem.CommittedBytes
    $limit = [long]$mem.CommitLimit
    $poolPaged = [long]$mem.PoolPagedBytes
    $poolNonpaged = [long]$mem.PoolNonpagedBytes
    # Same unattributed definition as ai-01's 22/09 comment: commit charge not
    # accounted to any process's private commit nor to the kernel pools. Page
    # tables, driver-locked and pagefile-backed sections live here.
    $unattributed = $committed - $sumProcessCommit - $poolPaged - $poolNonpaged

    return [ordered]@{
        t                       = (Get-Date).ToUniversalTime().ToString('o')
        CommittedBytes          = $committed
        CommitLimitBytes        = $limit
        FreeVirtualMemoryBytes  = [long]($os.FreeVirtualMemory * 1KB)
        PagefileAllocatedBytes  = [long](($pagefiles | Measure-Object -Property AllocatedBaseSize -Sum).Sum * 1MB)
        PoolPagedBytes          = $poolPaged
        PoolNonpagedBytes       = $poolNonpaged
        SumProcessCommitBytes   = $sumProcessCommit
        UnattributedBytes       = $unattributed
    }
}

try {
    $modeText = if ($DurationSec -gt 0) { "duration ${DurationSec}s" } else { 'until Ctrl+C' }
    Write-Host "[log-commit-charge] writing $samplesPath (interval ${IntervalSec}s, $modeText)"
    while ($true) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $s = Get-CommitSample
        [System.IO.File]::AppendAllText($samplesPath, (ConvertTo-Json -InputObject $s -Compress) + "`n", $utf8NoBom)
        $count++
        if ($null -eq $first) { $first = $s }
        $last = $s
        if ($s.CommittedBytes -gt $peakCommitted) { $peakCommitted = $s.CommittedBytes }
        if ($s.UnattributedBytes -gt $peakUnattributed) { $peakUnattributed = $s.UnattributedBytes }

        if ($DurationSec -gt 0 -and ((Get-Date).ToUniversalTime() - $startUtc).TotalSeconds -ge $DurationSec) { break }
        $sleepMs = [int](($IntervalSec - $sw.Elapsed.TotalSeconds) * 1000)
        if ($sleepMs -gt 0) { Start-Sleep -Milliseconds $sleepMs }
    }
}
finally {
    $summary = [ordered]@{
        startedUtc        = $startUtc.ToString('o')
        endedUtc          = (Get-Date).ToUniversalTime().ToString('o')
        samples           = $count
        intervalSec       = $IntervalSec
        firstCommitted    = if ($first) { $first.CommittedBytes } else { $null }
        lastCommitted     = if ($last) { $last.CommittedBytes } else { $null }
        peakCommitted     = if ($peakCommitted -ge 0) { $peakCommitted } else { $null }
        peakUnattributed  = if ($peakUnattributed -ge 0) { $peakUnattributed } else { $null }
        machine           = $env:COMPUTERNAME
    }
    [System.IO.File]::WriteAllText($summaryPath, (ConvertTo-Json -InputObject $summary), $utf8NoBom)
    Write-Host "[log-commit-charge] $count sample(s) -> $samplesPath"
    Write-Host "[log-commit-charge] summary -> $summaryPath"
}
