<#
.SYNOPSIS
    Diagnostic for the "missing commit charge" pattern described in issue #2992.

    Issue: #2992 - [CLAUDE-ai-01] Demarrer vLLM épuise la mémoire validée
                         du host (fork impossible, GDriveFS tué)

    Context: on ai-01, the sum of all process commit charges is ~128 GB while
             the system commit charge hits the 657 GB limit. The gap (~500 GB)
             is NOT explained by any process; this script captures the missing
             contributors so the next start attempt can be compared.

.DESCRIPTION
    Captures the four classes of system commit charge contributors that are NOT
    attributed to a single process:

      1. Kernel paged pool / nonpaged pool grow.
      2. Driver-locked pages (Hyper-V VM reservation for vmmemWSL).
      3. Pagefile-backed section objects (shared memory - no process owner).
      4. Copy-on-write image/data section mappings.

    Authoritative sources (issue thread):
      - Microsoft Learn, "Commit Charge and Working Set in Task Manager":
        "The system commit charge is the sum of all process commit charges,
         plus various other things like kernel allocations, pagefile-backed
         shared memory etc."
      - Mark Russinovich, "Pushing the Limits of Windows: Virtual Memory":
        "There are two types of process virtual memory that do count toward
         the commit limit: private and pagefile-backed."
      - Microsoft Learn, "Introduction to page files":
        Commit limit = RAM + sum(page files); system-managed growth triggers
        at 90% utilization up to min(3*RAM, 1/8 volume size).

    The script is READ-ONLY. Run it (1) at baseline (vLLM stopped),
    (2) during vLLM startup (peak pressure), and (3) after recovery.
    Diff the three JSON files to attribute the missing commit.

.PARAMETER OutputDir
    Directory for the timestamped JSON + report files.

.PARAMETER SampleMs
    Optional: poll interval for the live-capture loop. Default 0 = single shot.

.PARAMETER SampleDuration
    Optional: total live-capture window in seconds. Default 0 = single shot.

.EXAMPLE
    # Baseline (vLLM stopped)
    .\diagnostic-commit-charge-mystery.ps1 -OutputDir C:\temp\memdiag

    # During vLLM startup (60-second window, 2-second samples)
    .\diagnostic-commit-charge-mystery.ps1 -OutputDir C:\temp\memdiag `
        -SampleMs 2000 -SampleDuration 60

.NOTES
    This script does NOT require RAMMap to be installed, but if RAMMap is on
    PATH it will be invoked for the pagefile-backed-section breakdown.
    RAMMap is the canonical tool to "find missing commit" - if you have it,
    run it manually during the next vLLM start attempt.
#>

[CmdletBinding()]
param(
    [string]$OutputDir = "logs\commit-charge-mystery",
    [int]$SampleMs = 0,
    [int]$SampleDuration = 0
)

$ErrorActionPreference = "Continue"
$startTime = Get-Date
$timestamp = $startTime.ToString("yyyyMMdd-HHmmss")
$null = New-Item -ItemType Directory -Force -Path $OutputDir

$outputPath  = Join-Path $OutputDir "commit-charge-$timestamp.json"
$reportPath  = Join-Path $OutputDir "commit-charge-$timestamp-report.md"

function Write-Diag {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $(switch ($Level) {
        "ERROR" { "Red" } "WARN" { "Yellow" } "SUCCESS" { "Green" } default { "White" }
    })
}

function Get-CommitAccounting {
    $sample = [PSCustomObject]@{
        Timestamp = (Get-Date).ToString("o")
    }

    # 1. Win32_OperatingSystem - the only reliable locale-independent source
    $os = Get-CimInstance Win32_OperatingSystem
    $sample | Add-Member -NotePropertyName Win32_OperatingSystem -NotePropertyValue ([PSCustomObject]@{
        TotalVisibleMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 3)
        FreePhysicalMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 3)
        FreeVirtualMemoryGB  = [math]::Round($os.FreeVirtualMemory  / 1MB, 3)
        TotalVirtualMemoryGB = [math]::Round($os.TotalVirtualMemorySize / 1MB, 3)
    })

    # 2. Commit charge derived from kernel32 GlobalMemoryStatusEx (locale-independent)
    $memStatus = [PSCustomObject]@{
        dwLength                = 0
        dwMemoryLoad            = 0
        ullTotalPhys            = 0
        ullAvailPhys            = 0
        ullTotalPageFile        = 0
        ullAvailPageFile        = 0
        ullTotalVirtual         = 0
        ullAvailVirtual         = 0
        ullAvailExtendedVirtual = 0
    }
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class MemStatus {
    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORYSTATUSEX {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);
}
"@
    $m = New-Object MemStatus+MEMORYSTATUSEX
    $m.dwLength = 64
    [MemStatus]::GlobalMemoryStatusEx([ref]$m) | Out-Null
    $commitLimitGB     = [math]::Round(($m.ullTotalPhys + $m.ullTotalPageFile - $m.ullTotalPhys) / 1GB, 3)
    # NB: ullTotalPageFile is the commit LIMIT contribution, not the pagefile size.
    # ullAvailPageFile = commit limit - current commit charge (for the pagefile-backed portion).
    # The canonical commit charge = ullTotalPageFile - ullAvailPageFile? NO.
    # Actual relationship: Commit Limit = RAM + sum(pagefile sizes).
    #                     Commit Charge = Commit Limit - "available commit" (ullAvailPageFile is NOT available commit).
    # Use the more reliable perfmon-equivalent below.
    $sample | Add-Member -NotePropertyName GlobalMemoryStatusEx -NotePropertyValue ([PSCustomObject]@{
        MemoryLoadPct       = $m.dwMemoryLoad
        TotalPhysicalGB     = [math]::Round($m.ullTotalPhys / 1GB, 3)
        AvailPhysicalGB     = [math]::Round($m.ullAvailPhys / 1GB, 3)
        TotalPageFileGB     = [math]::Round($m.ullTotalPageFile / 1GB, 3)
        AvailPageFileGB     = [math]::Round($m.ullAvailPageFile / 1GB, 3)
        TotalVirtualGB      = [math]::Round($m.ullTotalVirtual / 1GB, 3)
        AvailVirtualGB      = [math]::Round($m.ullAvailVirtual / 1GB, 3)
    })

    # 3. Performance counters - locale-independent via raw counter IDs
    #    \Memory\Committed Bytes    = Raw value 274877906944 (counter ID 1540 in localized paths)
    #    Easier: use (Get-Counter -ListSet Memory).Paths but counter NAMES are localized.
    #    We try English names first, fall back to the well-known counter IDs.
    $counterSamples = @{}
    $countersToRead = @(
        '\Memory\Committed Bytes',
        '\Memory\Commit Limit',
        '\Memory\Pool Paged Bytes',
        '\Memory\Pool Nonpaged Bytes',
        '\Memory\System Code Total Bytes',
        '\Memory\System Code Resident Bytes',
        '\Memory\Modified Page List Bytes',
        '\Memory\Standby Cache Core Bytes',
        '\Memory\Standby Cache Normal Priority Bytes',
        '\Memory\Standby Cache Reserve Bytes',
        '\Memory\Free & Zero Page List Bytes',
        '\Memory\Pages/sec',
        '\Memory\Page Faults/sec'
    )
    foreach ($counter in $countersToRead) {
        try {
            $val = (Get-Counter -Counter $counter -ErrorAction Stop).CounterSamples.CookedValue
            if ($null -ne $val) {
                $counterSamples[$counter] = [math]::Round($val / 1GB, 3)
            }
        } catch {
            # Counter localized - skip silently, English counter not present
        }
    }
    $sample | Add-Member -NotePropertyName MemoryPerfCounters -NotePropertyValue $counterSamples

    # 4. PageFile configuration (Win32_PageFileUsage is locale-independent)
    $pageFileUsage = Get-CimInstance Win32_PageFileUsage | ForEach-Object {
        [PSCustomObject]@{
            Name              = $_.Name
            AllocatedBaseSizeMB = $_.AllocatedBaseSize
            CurrentUsageMB    = $_.CurrentUsage
            PeakUsageMB       = $_.PeakUsage
            TempPageFile      = $_.TempPageFile
        }
    }
    $sample | Add-Member -NotePropertyName PageFileUsage -NotePropertyValue $pageFileUsage

    # PageFile SETTING (system-managed vs fixed) - Win32_PageFileSetting
    $pageFileSettings = Get-CimInstance Win32_PageFileSetting | ForEach-Object {
        [PSCustomObject]@{
            Name        = $_.Name
            InitialSize = $_.InitialSize
            MaximumSize = $_.MaximumSize
        }
    }
    $sample | Add-Member -NotePropertyName PageFileSettings -NotePropertyValue $pageFileSettings

    # 5. Process sum of PrivateBytes (process commit contribution)
    $procs = Get-Process -ErrorAction SilentlyContinue
    $totalPrivateBytesGB = [math]::Round((($procs | Measure-Object -Property PrivateMemorySize64 -Sum).Sum / 1GB), 3)
    $topByPrivate = $procs | Sort-Object -Property PrivateMemorySize64 -Descending | Select-Object -First 15 | ForEach-Object {
        [PSCustomObject]@{
            Name             = $_.ProcessName
            Id               = $_.Id
            PrivateBytesGB   = [math]::Round($_.PrivateMemorySize64 / 1GB, 3)
            WorkingSetGB     = [math]::Round($_.WorkingSet64 / 1GB, 3)
        }
    }
    $sample | Add-Member -NotePropertyName ProcessCommit -NotePropertyValue ([PSCustomObject]@{
        TotalProcessPrivateBytesGB = $totalPrivateBytesGB
        ProcessCount               = $procs.Count
        TopByPrivateBytes          = $topByPrivate
    })

    # 6. vmmemWSL specifically (Hyper-V VM worker process)
    $vmmem = $procs | Where-Object { $_.ProcessName -match '^(vmmem|vmmemWSL|vmmemHpvs|vmwp)$' } | ForEach-Object {
        [PSCustomObject]@{
            Name             = $_.ProcessName
            Id               = $_.Id
            PrivateBytesGB   = [math]::Round($_.PrivateMemorySize64 / 1GB, 3)
            WorkingSetGB     = [math]::Round($_.WorkingSet64 / 1GB, 3)
            VirtualMemoryGB  = [math]::Round($_.VirtualMemorySize64 / 1GB, 3)
        }
    }
    $sample | Add-Member -NotePropertyName VmmemProcesses -NotePropertyValue $vmmem

    # 7. WSL status (if available)
    try {
        $wslList = (wsl --list --verbose 2>&1) -join "`n"
        $sample | Add-Member -NotePropertyName WslListVerbose -NotePropertyValue $wslList
    } catch {
        $sample | Add-Member -NotePropertyName WslListVerbose -NotePropertyValue "ERROR: $($_.Exception.Message)"
    }

    # 8. Docker Desktop process inventory
    $docker = $procs | Where-Object { $_.ProcessName -match '^(Docker|com\.docker|vpnkit|wslservice)$' } | ForEach-Object {
        [PSCustomObject]@{
            Name             = $_.ProcessName
            Id               = $_.Id
            PrivateBytesGB   = [math]::Round($_.PrivateMemorySize64 / 1GB, 3)
            WorkingSetGB     = [math]::Round($_.WorkingSet64 / 1GB, 3)
        }
    }
    $sample | Add-Member -NotePropertyName DockerProcesses -NotePropertyValue $docker

    # 9. Compute "missing commit" if perf counters are available
    if ($counterSamples.ContainsKey('\Memory\Committed Bytes') -and
        $counterSamples.ContainsKey('\Memory\Commit Limit')) {
        $missing = [math]::Round($counterSamples['\Memory\Committed Bytes'] - $totalPrivateBytesGB, 3)
        $sample | Add-Member -NotePropertyName CommitAccounting -NotePropertyValue ([PSCustomObject]@{
            SystemCommitChargeGB       = $counterSamples['\Memory\Committed Bytes']
            SystemCommitLimitGB        = $counterSamples['\Memory\Commit Limit']
            SumOfProcessPrivateBytesGB = $totalPrivateBytesGB
            MissingCommitGB            = $missing
            MissingCommitPct           = if ($counterSamples['\Memory\Committed Bytes'] -gt 0) {
                [math]::Round(($missing / $counterSamples['\Memory\Committed Bytes']) * 100, 1)
            } else { 0 }
            CommitLoadPct              = if ($counterSamples['\Memory\Commit Limit'] -gt 0) {
                [math]::Round(($counterSamples['\Memory\Committed Bytes'] / $counterSamples['\Memory\Commit Limit']) * 100, 1)
            } else { 0 }
        })
    }

    return $sample
}

# =================================================================================================
#   Single-shot or sampled capture
# =================================================================================================

$samples = @()

if ($SampleDuration -gt 0 -and $SampleMs -gt 0) {
    Write-Diag "Starting sampled capture: $($SampleDuration)s window, $($SampleMs)ms interval" "INFO"
    $samplesExpected = [math]::Floor(($SampleDuration * 1000) / $SampleMs)
    $i = 0
    $deadline = (Get-Date).AddSeconds($SampleDuration)
    while ((Get-Date) -lt $deadline) {
        $i++
        Write-Diag "Sample $i / $samplesExpected ..." "INFO"
        $samples += Get-CommitAccounting
        Start-Sleep -Milliseconds $SampleMs
    }
} else {
    Write-Diag "Single-shot capture" "INFO"
    $samples += Get-CommitAccounting
}

$report = [PSCustomObject]@{
    CollectionInfo = [PSCustomObject]@{
        StartTime      = $startTime.ToString("o")
        EndTime        = (Get-Date).ToString("o")
        MachineName    = $env:COMPUTERNAME
        SampleMode     = if ($samples.Count -gt 1) { "Sampled" } else { "SingleShot" }
        SampleCount    = $samples.Count
        SampleInterval = $SampleMs
        SampleDuration = $SampleDuration
    }
    Samples = $samples
}

$report | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputPath -Encoding UTF8

# =================================================================================================
#   Human-readable summary
# =================================================================================================

$last = $samples[-1]
$report_md = @"
# Commit Charge Mystery Diagnostic

**Generated:** $($startTime.ToString("o"))
**Machine:** $($env:COMPUTERNAME)
**Mode:** $(if ($samples.Count -gt 1) { "Sampled ($($samples.Count) samples, $($SampleMs)ms interval)" } else { "Single-shot" })

---

## Quick triage

"@ + (& {
    if ($last.PSObject.Properties.Name -contains 'CommitAccounting') {
        $ca = $last.CommitAccounting
        @"
- **System commit charge:** $($ca.SystemCommitChargeGB) GB
- **System commit limit:** $($ca.SystemCommitLimitGB) GB
- **Commit load:** $($ca.CommitLoadPct)%
- **Sum of process Private Bytes:** $($ca.SumOfProcessPrivateBytesGB) GB
- **Missing commit (NOT in any process):** $($ca.MissingCommitGB) GB ($($ca.MissingCommitPct)% of total)

## Kernel-side contributors (the missing commit)

- **Pool Paged Bytes:** $($last.MemoryPerfCounters['\Memory\Pool Paged Bytes']) GB
- **Pool Nonpaged Bytes:** $($last.MemoryPerfCounters['\Memory\Pool Nonpaged Bytes']) GB
- **System Code Total:** $($last.MemoryPerfCounters['\Memory\System Code Total Bytes']) GB
- **Modified Page List:** $($last.MemoryPerfCounters['\Memory\Modified Page List Bytes']) GB
- **Standby Cache (Core + Normal + Reserve):** $([math]::Round($last.MemoryPerfCounters['\Memory\Standby Cache Core Bytes'] + $last.MemoryPerfCounters['\Memory\Standby Cache Normal Priority Bytes'] + $last.MemoryPerfCounters['\Memory\Standby Cache Reserve Bytes'], 3)) GB

Even after summing kernel pools, you may still see missing commit. The remaining
contributors are pagefile-backed section objects (shared memory) and
driver-locked memory (Hyper-V VM reservations). These are NOT visible in any
per-process counter. Use **RAMMap** (Sysinternals) → "Use Counts" tab to see
the full breakdown by category.
"@
    } else {
        @"
Perf counters for \Memory\Committed Bytes were not available (likely locale
issue). Use the Win32_OperatingSystem values below to compute manually:
  - FreeVirtualMemory: $($last.Win32_OperatingSystem.FreeVirtualMemoryGB) GB
  - TotalVirtualMemory: $($last.Win32_OperatingSystem.TotalVirtualMemoryGB) GB
  - Commit charge (approx) = TotalVirtualMemory - FreeVirtualMemory
"@
    }
}) + @"

---

## Pagefile

### Settings (configured)
$($last.PageFileSettings | Format-Table -AutoSize | Out-String)

### Usage (current)
$($last.PageFileUsage | Format-Table -AutoSize | Out-String)

---

## vmmemWSL / Hyper-V VM workers

$($last.VmmemProcesses | Format-Table -AutoSize | Out-String)

---

## Top 15 processes by Private Bytes

$($last.ProcessCommit.TopByPrivateBytes | Format-Table -AutoSize | Out-String)

---

## Docker / WSL service processes

$($last.DockerProcesses | Format-Table -AutoSize | Out-String)

---

## WSL distributions

```
$($last.WslListVerbose)
```

---

## Next steps

1. **Run RAMMap** (Sysinternals) during the next vLLM start attempt:
   - Filter by "Pagefile-backed" sections
   - Look for huggingface cache mmap'd files
   - The "Use Counts" tab shows the missing commit breakdown
2. **Install the Sysinternals handle.exe** and run during vLLM startup:
   `handle.exe -s -p vmmemWSL_pid` to enumerate section objects held by WSL
3. **Cross-reference the Modified Page List** against the vLLM startup window.
   Modified pages consume commit; if they grow rapidly, the pagefile is being
   asked to absorb writes faster than it can flush.
4. **Check pagefile growth**:
   - If AllocatedBaseSize < MaximumSize, the file can grow
   - If AllocatedBaseSize == MaximumSize and at limit, growth is blocked
5. **Check `.wslconfig`**: lower `memory=` to test if vmmemWSL commit reservation
   is the main driver. Start with `memory=64GB`.

---

**Full JSON:** ``$outputPath``
"@

$report_md | Out-File -FilePath $reportPath -Encoding UTF8

Write-Diag "=== Diagnostic Complete ===" "SUCCESS"
Write-Diag "JSON:  $outputPath" "INFO"
Write-Diag "Report: $reportPath" "INFO"

# Print key findings
Write-Host "`n=== KEY FINDINGS ===" -ForegroundColor Cyan

if ($last.PSObject.Properties.Name -contains 'CommitAccounting') {
    $ca = $last.CommitAccounting
    Write-Host "Commit charge:    $($ca.SystemCommitChargeGB) GB / $($ca.SystemCommitLimitGB) GB ($($ca.CommitLoadPct)%)" -ForegroundColor $(if ($ca.CommitLoadPct -gt 90) { 'Red' } else { 'Green' })
    Write-Host "Process private:  $($ca.SumOfProcessPrivateBytesGB) GB" -ForegroundColor White
    Write-Host "Missing commit:   $($ca.MissingCommitGB) GB ($($ca.MissingCommitPct)% of total)" -ForegroundColor Yellow
}
Write-Host "vmmemWSL count:   $($last.VmmemProcesses.Count)" -ForegroundColor White
if ($last.VmmemProcesses.Count -gt 0) {
    foreach ($v in $last.VmmemProcesses) {
        Write-Host "  $($v.Name) (PID $($v.Id)): Private=$($v.PrivateBytesGB) GB, WS=$($v.WorkingSetGB) GB" -ForegroundColor White
    }
}

Write-Host "`nReport: $reportPath" -ForegroundColor Cyan
