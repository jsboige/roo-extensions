<#
.SYNOPSIS
    Cleanup orphan MCP stdio zombie processes (node/cmd spawned via npx that outlive their VS Code host).

.DESCRIPTION
    Issue #2675 — On Windows, MCP **stdio** servers are spawned via `npx -y <mcp>`
    (config `~/.claude.json` + Roo `mcp_settings.json`, transportType: stdio). `npx`
    delegates to a `cmd /c` wrapper -> `node`. When the VS Code extension host / a
    scheduler cycle / a worker terminates (restart, crash, end of cycle), these child
    processes are NOT cascade-killed (Windows has no Job Object by default) -> the
    `cmd <-> node` pair keeps each other alive + their `conhost` windows accumulate
    forever (the "phantom terminal windows" symptom). Corollary: orphaned worktrees
    become impossible to `git worktree remove` (`Permission denied`) because the
    zombie processes hold file locks inside the worktree dir.

    This script is the MCP equivalent of cleanup-orphan-worktrees.ps1: it finds MCP
    stdio node/cmd processes whose VS Code (Code.exe) ancestor is gone and that are
    older than a safety threshold, and reports them (dry-run, default) or kills them.

    Matching process:
      1. Enumerate node.exe + cmd.exe with CommandLine + ParentProcessId + CreationDate
      2. Keep those whose CommandLine matches `npx` OR `mcp-` (the MCP stdio signature)
      3. Walk the parent chain; if a LIVE Code.exe ancestor is reached -> SKIP (live session)
      4. If no live Code.exe ancestor AND age > MinAgeHours -> candidate zombie
      5. Dry-run lists; -Execute calls Stop-Process -Force on the candidates

.PARAMETER MinAgeHours
    Minimum process age (hours) to consider killing. Default: 18.
    MCP servers belonging to an active session are typically < 18h old; the zombie
    cohorts observed (#2675) were 22h-74h. Raising this is safer; lowering risks
    killing a live server mid-session.

.PARAMETER Execute
    Actually kill the candidate zombies. Without this flag, only reports (dry-run).

.PARAMETER CodeProcessName
    Name of the VS Code editor process used to detect a live host ancestor.
    Default: 'Code.exe'. Set to 'Code - Insiders.exe' for Insiders builds.

.PARAMETER LogPath
    Path for log output. Defaults to outputs/cleanup-mcp-zombies-{timestamp}.log
    relative to the repo root.

.EXAMPLE
    ./cleanup-mcp-stdio-zombies.ps1
    # Dry-run: list all candidate zombies older than 18h without killing

.EXAMPLE
    ./cleanup-mcp-stdio-zombies.ps1 -Execute
    # Kill all candidate zombies older than 18h

.EXAMPLE
    ./cleanup-mcp-stdio-zombies.ps1 -MinAgeHours 48 -Execute
    # Kill only zombies older than 48h (extra-safe)

.NOTES
    Issue #2675 — MCP stdio zombie cleanup (phantom terminal windows + locked worktrees).
    Mirrors scripts/maintenance/cleanup-orphan-worktrees.ps1 (dry-run default pattern).
    Root cause + cross-machine proof: po-2024 c.90, po-2026 c.12 (2026-06-24).
#>

[CmdletBinding()]
param(
    [double]$MinAgeHours = 18,
    [switch]$Execute,
    [string]$CodeProcessName = 'Code.exe',
    [string]$RepoRoot,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Resolve repo root for the default log path (non-fatal if not in a git repo)
if (-not $RepoRoot) {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    $RepoRoot = if ($gitRoot) { $gitRoot.Trim() } else { (Get-Location).Path }
}
if (-not $LogPath) {
    $OutputsDir = "$RepoRoot/outputs"
    if (-not (Test-Path $OutputsDir)) { New-Item -ItemType Directory -Path $OutputsDir -Force | Out-Null }
    $LogPath = "$OutputsDir/cleanup-mcp-zombies-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

Write-Log "=== MCP stdio zombie cleanup (#2675) ==="
Write-Log "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })"
Write-Log "MinAgeHours: $MinAgeHours"
Write-Log "CodeProcessName (live-host ancestor): $CodeProcessName"
Write-Log ""

# Single CIM call: enumerate every process once with the fields we need.
# Indexing by PID lets us walk parent chains without re-querying CIM per hop.
Write-Log "Enumerating processes (single CIM pass)..."
$allProcs = @(Get-CimInstance Win32_Process |
    Select-Object ProcessId, Name, CommandLine, ParentProcessId, CreationDate)
$procIndex = @{}
foreach ($p in $allProcs) { $procIndex[[int]$p.ProcessId] = $p }
Write-Log "  Indexed $($allProcs.Count) processes."
Write-Log ""

# Build the live Code.exe PID set once (cheap membership test for the ancestor walk).
$codePids = @($allProcs | Where-Object { $_.Name -ieq $CodeProcessName } | ForEach-Object { [int]$_.ProcessId })
Write-Log "  Live $CodeProcessName instances: $($codePids.Count)"

# Walk the parent chain from a PID; return $true if a live Code.exe ancestor is reached.
# Cycle-safe (visited set). Returns $false if the chain dead-ends or cycles without Code.exe.
function Test-HasLiveCodeAncestor {
    param([int]$StartPid, [hashtable]$Index, [int[]]$LiveCodePids)
    $visited = @{}
    $current = $StartPid
    $hops = 0
    while ($current -gt 0 -and -not $visited.ContainsKey($current) -and $hops -lt 64) {
        $visited[$current] = $true
        $hops++
        if ($LiveCodePids -contains $current) { return $true }
        if (-not $Index.ContainsKey($current)) { return $false }  # parent gone
        $current = [int]$Index[$current].ParentProcessId
    }
    return $false  # cycle or hit hop cap without finding Code.exe -> treat as orphaned
}

# Candidate MCP stdio processes: node.exe / cmd.exe whose CommandLine matches npx|mcp-
$threshold = (Get-Date).AddHours(-$MinAgeHours)
$candidates = @()
$skippedYoung = @()
$skippedLiveHost = @()
$notMatching = 0

foreach ($p in $allProcs) {
    if ($p.Name -ine 'node.exe' -and $p.Name -ine 'cmd.exe') { continue }
    $cmd = "$($p.CommandLine)"
    if (-not ($cmd -match 'npx' -or $cmd -match 'mcp-')) {
        $notMatching++
        continue
    }
    $created = $p.CreationDate
    if (-not $created) { continue }
    $ageHours = ((Get-Date) - $created).TotalHours
    if ($ageHours -lt $MinAgeHours) {
        $skippedYoung += [PSCustomObject]@{ Pid = $p.ProcessId; Name = $p.Name; AgeHours = [math]::Round($ageHours, 1); CmdShort = ($cmd.Substring(0, [math]::Min(80, $cmd.Length))) }
        continue
    }
    # Old enough -> verify the host ancestor is actually gone before flagging as zombie
    $hasLiveHost = Test-HasLiveCodeAncestor -StartPid ([int]$p.ProcessId) -Index $procIndex -LiveCodePids $codePids
    if ($hasLiveHost) {
        $skippedLiveHost += [PSCustomObject]@{ Pid = $p.ProcessId; Name = $p.Name; AgeHours = [math]::Round($ageHours, 1); CmdShort = ($cmd.Substring(0, [math]::Min(80, $cmd.Length))) }
        continue
    }
    $candidates += [PSCustomObject]@{
        Pid       = [int]$p.ProcessId
        Name      = $p.Name
        AgeHours  = [math]::Round($ageHours, 1)
        ParentPid = [int]$p.ParentProcessId
        CmdShort  = ($cmd.Substring(0, [math]::Min(100, $cmd.Length)))
    }
}

Write-Log "MCP stdio candidates (node/cmd matching npx|mcp-):"
Write-Log "  Killed-on-Execute (zombies, no live host, > ${MinAgeHours}h): $($candidates.Count)"
Write-Log "  Skipped (live Code.exe ancestor):  $($skippedLiveHost.Count)"
Write-Log "  Skipped (< ${MinAgeHours}h, too young):  $($skippedYoung.Count)"
Write-Log "  Not matching (node/cmd without npx|mcp-): $notMatching"
Write-Log ""

if ($skippedLiveHost.Count -gt 0) {
    Write-Log "--- Skipped: live $CodeProcessName ancestor (active session, PROTECTED) ---"
    foreach ($s in $skippedLiveHost | Sort-Object AgeHours -Descending) {
        Write-Log ("  PID {0,-7} {1,-9} {2,6}h  {3}" -f $s.Pid, $s.Name, $s.AgeHours, $s.CmdShort)
    }
    Write-Log ""
}

if ($candidates.Count -eq 0) {
    Write-Log "No MCP stdio zombies older than $MinAgeHours hours found. Nothing to do."
    Write-Log "Log saved to: $LogPath"
    exit 0
}

Write-Log "--- Candidate zombies ($($candidates.Count), > ${MinAgeHours}h, no live host) ---"
foreach ($c in $candidates | Sort-Object AgeHours -Descending) {
    Write-Log ("  PID {0,-7} {1,-9} {2,6}h  ppid={3,-7}  {4}" -f $c.Pid, $c.Name, $c.AgeHours, $c.ParentPid, $c.CmdShort)
}
Write-Log ""

if (-not $Execute) {
    Write-Log "DRY-RUN: No processes killed. Re-run with -Execute to kill the $($candidates.Count) candidates."
    Write-Log "Log saved to: $LogPath"
    exit 0
}

# Execute mode
$killed = 0
$failed = 0
foreach ($c in $candidates) {
    Write-Log "  KILLING PID $($c.Pid) ($($c.Name), $($c.AgeHours)h)"
    try {
        Stop-Process -Id $c.Pid -Force -ErrorAction Stop
        $killed++
    } catch {
        Write-Log "    ERROR killing PID $($c.Pid): $_"
        $failed++
    }
}

Write-Log ""
Write-Log "=== Summary ==="
Write-Log "Killed:  $killed / $($candidates.Count)"
Write-Log "Failed:  $failed"
Write-Log "Log:     $LogPath"
Write-Log "=== Done ==="
