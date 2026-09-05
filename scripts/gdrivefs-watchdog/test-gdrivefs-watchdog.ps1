param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'gdrivefs-watchdog.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw
$match = [regex]::Match(
    $source,
    '(?s)function Test-GDriveFSMountLive \{.*?\r?\n\}\r?\n\r?\n# ---------- C2:'
)
if (-not $match.Success) {
    throw 'Could not locate Test-GDriveFSMountLive in watchdog script.'
}

$functionSource = $match.Value -replace '\r?\n\r?\n# ---------- C2:$', ''
Invoke-Expression $functionSource

# Extract the startup-grace guard (#3466) so the A0.3 positive control can drive it.
$graceMatch = [regex]::Match(
    $source,
    '(?s)function Test-IsInStartupGrace \{.*?\r?\n\}\r?\n\r?\n# ---------- relaunch ----------'
)
if (-not $graceMatch.Success) {
    throw 'Could not locate Test-IsInStartupGrace in watchdog script.'
}
$graceSource = $graceMatch.Value -replace '\r?\n\r?\n# ---------- relaunch ----------$', ''
Invoke-Expression $graceSource

$results = @()
function Assert-Probe {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    $script:results += [pscustomobject]@{ Name = $Name; Passed = $Condition; Detail = $Detail }
    $status = if ($Condition) { 'PASS' } else { 'FAIL' }
    Write-Host "[$status] $Name — $Detail"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdrivefs-watchdog-test-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
try {
    $healthy = Test-GDriveFSMountLive -Path $tempDir -TimeoutSeconds 5
    Assert-Probe 'healthy idle mount succeeds' ($healthy.Live -and $healthy.Reason -eq 'mount-stat-ok') $healthy.Reason

    $missing = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing') -TimeoutSeconds 5
    Assert-Probe 'missing mount fails' (-not $missing.Live -and $missing.Reason -like 'mount-probe-error:*') $missing.Reason

    $disabled = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing') -TimeoutSeconds 0
    Assert-Probe 'explicitly disabled probe succeeds' ($disabled.Live -and $disabled.Reason -eq 'c1-disabled') $disabled.Reason

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $missingFast = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing-fast') -TimeoutSeconds 1
    $watch.Stop()
    Assert-Probe 'probe returns within bound' ($watch.Elapsed.TotalSeconds -lt 5) ("elapsed={0:N2}s reason={1}" -f $watch.Elapsed.TotalSeconds, $missingFast.Reason)
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- A0.3 positive control (#3466) ----------
# Replay the 17:37 -> 18:03 in-init sequence from proof n2. The watchdog launched an
# instance at 17:37:47 (pids 34812,44344) that was STILL initializing when the next
# pair of poll observations hit it: 17:39:25 « failed recovery » and 17:48:30 (11 min
# old) « KILL ». The old code (no grace) kills it every time (2 kills); the grace guard
# must kill it ZERO times. A grace guard validates by its false negatives — write the
# sequence it must prevent and assert it prevents it.
function New-MockProc { param([datetime]$Start) [pscustomobject]@{ StartTime = $Start } }

function Resolve-ShouldRelaunch {
    param([bool]$ProcessPresent, [bool]$ProbeFailed, $Processes, $LastRelaunchAttempt, [datetime]$Now, [int]$GraceSeconds)
    # C0: process absent -> relaunch, nothing young to protect.
    if (-not $ProcessPresent) { return $true }
    # Healthy -> no relaunch.
    if (-not $ProbeFailed) { return $false }
    # Hung but young -> in startup grace, leave it alone.
    if (Test-IsInStartupGrace -Now $Now -Processes $Processes -LastRelaunchAttempt $LastRelaunchAttempt -GraceSeconds $GraceSeconds) {
        return $false
    }
    return $true
}

$tLaunch = [datetime]'2026-09-05T17:37:47'
$grace   = 1200   # 20 min, derived from the measured ~11-20 min init (A0.2)
$procs   = @(New-MockProc -Start $tLaunch)

# The two in-log in-init observations, both with a failing C1 probe.
$replay = @(
    @{ label = '17:39:25 (t+98s,  in init)';   Now = $tLaunch.AddSeconds(98) },
    @{ label = '17:48:30 (t+643s, in init)';   Now = $tLaunch.AddSeconds(643) }
)

$killCountFixed  = 0
$killCountLegacy = 0
foreach ($step in $replay) {
    $should = Resolve-ShouldRelaunch -ProcessPresent $true -ProbeFailed $true -Processes $procs -LastRelaunchAttempt $tLaunch.ToString('o') -Now $step.Now -GraceSeconds $grace
    if ($should) { $killCountFixed++ }
    $shouldLegacy = Resolve-ShouldRelaunch -ProcessPresent $true -ProbeFailed $true -Processes $procs -LastRelaunchAttempt $tLaunch.ToString('o') -Now $step.Now -GraceSeconds 0
    if ($shouldLegacy) { $killCountLegacy++ }
}
Assert-Probe 'A0.3 replay of proof n2 (17:39->17:48) — grace guard kills ZERO' ($killCountFixed -eq 0) ("fixed kills=$killCountFixed")
Assert-Probe 'A0.3 legacy (no grace, grace=0) kills the in-init instance' ($killCountLegacy -eq 2) ("legacy kills=$killCountLegacy")

# The guard must NOT over-protect genuinely-hung instances past the init window.
$staleProcs = @(New-MockProc -Start (Get-Date).AddHours(-3))
$shouldStale = Resolve-ShouldRelaunch -ProcessPresent $true -ProbeFailed $true -Processes $staleProcs -LastRelaunchAttempt $null -Now (Get-Date) -GraceSeconds $grace
Assert-Probe 'guard does NOT suppress a genuine hung instance (age > grace)' ($shouldStale -eq $true) ("shouldRelaunch=$shouldStale")

# Healthy instance is never killed regardless of age.
$shouldHealthy = Resolve-ShouldRelaunch -ProcessPresent $true -ProbeFailed $false -Processes $procs -LastRelaunchAttempt $tLaunch.ToString('o') -Now $tLaunch.AddSeconds(98) -GraceSeconds $grace
Assert-Probe 'healthy instance is never killed' ($shouldHealthy -eq $false) ("shouldRelaunch=$shouldHealthy")

# C0 (process absent) still relaunches even inside what would be a grace window.
$shouldAbsent = Resolve-ShouldRelaunch -ProcessPresent $false -ProbeFailed $true -Processes @() -LastRelaunchAttempt $tLaunch.ToString('o') -Now $tLaunch.AddSeconds(98) -GraceSeconds $grace
Assert-Probe 'C0 process-absent still relaunches (grace applies only to live instances)' ($shouldAbsent -eq $true) ("shouldRelaunch=$shouldAbsent")

$failed = @($results | Where-Object { -not $_.Passed })
Write-Host "`n$($results.Count - $failed.Count)/$($results.Count) tests passed"
if ($failed.Count -gt 0) { exit 1 }
