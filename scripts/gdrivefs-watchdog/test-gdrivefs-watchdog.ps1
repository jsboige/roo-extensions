param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'gdrivefs-watchdog.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw
# Extract the whole C1 section (Invoke-BoundedMountProbe + Test-GDriveFSMountLive):
# Test-GDriveFSMountLive calls the helper, so both must be defined for the harness.
$match = [regex]::Match(
    $source,
    '(?s)# ---------- C1:.*?(?=\r?\n# ---------- C2:)'
)
if (-not $match.Success) {
    throw 'Could not locate the C1 probe section in watchdog script.'
}

Invoke-Expression $match.Value

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

# Extract the GitHub survivor-channel alert section (#3678) — Send-GitHubAlert
# is a pure function (state in, result out) so it drives standalone; $script:GhExe
# is the injection point for the mock below.
$ghMatch = [regex]::Match(
    $source,
    '(?s)# ---------- GitHub alert.*?(?=\r?\n# ---------- state file)'
)
if (-not $ghMatch.Success) {
    throw 'Could not locate the GitHub alert section in watchdog script.'
}
Invoke-Expression $ghMatch.Value

# Extract the fast-poll window section (#3678) — Test-FastPollWindowActive is
# pure; Set-WatchdogFastPollTask is thin schtask glue (not exercised here).
$fpMatch = [regex]::Match(
    $source,
    '(?s)# ---------- fast-poll window.*?(?=\r?\n# ---------- startup grace)'
)
if (-not $fpMatch.Success) {
    throw 'Could not locate the fast-poll section in watchdog script.'
}
Invoke-Expression $fpMatch.Value

# Mock gh: records each invocation's argv, captures the --body-file content at
# call time, fakes $LASTEXITCODE, returns a deterministic issue URL. Defined as
# a function so Get-Command/'& gh' resolve the mock over any real gh.exe.
$script:mockGhCalls     = @()
$script:mockGhExitCode  = 0
$script:mockBodyContent = ''
function gh {
    $script:mockGhCalls = @($script:mockGhCalls + ,@($args))
    $bodyFile = $null
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '--body-file' -and ($i + 1) -lt $args.Count) { $bodyFile = $args[$i + 1] }
    }
    if ($bodyFile -and (Test-Path -LiteralPath $bodyFile)) {
        $script:mockBodyContent = Get-Content -LiteralPath $bodyFile -Raw
    }
    $global:LASTEXITCODE = $script:mockGhExitCode
    if ($script:mockGhExitCode -eq 0) {
        'https://github.com/jsboige/roo-extensions/issues/99999'
    }
}

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
    Assert-Probe 'healthy idle mount succeeds' ($healthy.Live -and $healthy.Reason -eq 'mount-stat+enum-ok') $healthy.Reason

    $emptyDir = Join-Path $tempDir 'empty-mount'
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    $empty = Test-GDriveFSMountLive -Path $emptyDir -TimeoutSeconds 5
    Assert-Probe 'empty mount (0 items) still succeeds' ($empty.Live -and $empty.Reason -eq 'mount-stat+enum-ok') $empty.Reason

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

# ---------- #3678 survivor-channel alert (Send-GitHubAlert) ----------
$alertRepo = 'jsboige/roo-extensions'
$alertNow  = [datetime]'2026-09-16T21:00:00'

# Dedupe: an alert sent 1 h ago blocks a new one (interval 6 h) — the ceiling
# of ~4 issues / 24 h under a continuous outage depends on this branch.
$r1 = Send-GitHubAlert -Reason 'cooldown-escalation' -Detail 'd' -Repo $alertRepo -MinIntervalHours 6 -LastAlertAt $alertNow.AddHours(-1).ToString('o') -Now $alertNow
Assert-Probe 'alert: dedupe blocks within MinIntervalHours' (-not $r1.Sent -and $r1.SkipReason -like 'alert-cooldown*' -and -not $r1.NewLastAlertAt) $r1.SkipReason

# Send: interval elapsed -> gh invoked with --label, body captured at call time
# (host + reason present), URL surfaced, NewLastAlertAt stamped.
$script:mockGhCalls     = @()
$script:mockGhExitCode  = 0
$script:mockBodyContent = ''
$r2 = Send-GitHubAlert -Reason 'cooldown-escalation' -Detail 'consecutive_failures=3' -Repo $alertRepo -MinIntervalHours 6 -LastAlertAt $alertNow.AddHours(-7).ToString('o') -Now $alertNow
$argsJoined = if ($script:mockGhCalls.Count -gt 0) { $script:mockGhCalls[0] -join ' ' } else { '' }
$bodyOk = ($script:mockBodyContent -match 'cooldown-escalation') -and ($script:mockBodyContent -match [regex]::Escape($env:COMPUTERNAME))
Assert-Probe 'alert: sends after interval via mocked gh' ($r2.Sent -and $r2.NewLastAlertAt -and $r2.IssueUrl -and $bodyOk -and ($argsJoined -like '*--label*gdrivefs-watchdog-alert*')) ("sent=$($r2.Sent) bodyOk=$bodyOk label=$($argsJoined -like '*gdrivefs-watchdog-alert*')")

# gh unavailable: never-alerted state (null LastAlertAt) passes the dedupe,
# then fails clean with a SkipReason — never throws, never breaks the caller.
$script:GhExe = 'definitely-missing-gh-xYZ-123'
$r3 = Send-GitHubAlert -Reason 'r' -Detail 'd' -Repo $alertRepo -MinIntervalHours 6 -LastAlertAt $null -Now $alertNow
Assert-Probe 'alert: null LastAlertAt passes dedupe; gh-missing skips clean' (-not $r3.Sent -and $r3.SkipReason -eq 'gh-not-found') $r3.SkipReason
$script:GhExe = 'gh'

# gh exits non-zero: reported, not thrown.
$script:mockGhExitCode = 1
$r4 = Send-GitHubAlert -Reason 'r' -Detail 'd' -Repo $alertRepo -MinIntervalHours 6 -LastAlertAt $null -Now $alertNow
Assert-Probe 'alert: gh non-zero exit reported as skip' (-not $r4.Sent -and $r4.SkipReason -eq 'gh-exit-1' -and -not $r4.NewLastAlertAt) $r4.SkipReason

# Empty repo = remote alerting disabled (local sinks remain).
$r5 = Send-GitHubAlert -Reason 'r' -Detail 'd' -Repo '' -MinIntervalHours 6 -LastAlertAt $null -Now $alertNow
Assert-Probe 'alert: empty repo disables remote alerting' (-not $r5.Sent -and $r5.SkipReason -eq 'repo-not-configured') $r5.SkipReason

# Temp body file always cleaned up (finally), including on the failure paths.
$leftover = @(Get-ChildItem -Path ([System.IO.Path]::GetTempPath()) -Filter 'gdrivefs-alert-*.md' -ErrorAction SilentlyContinue)
Assert-Probe 'alert: temp body file cleaned up on all paths' ($leftover.Count -eq 0) "leftover=$($leftover.Count)"

# ---------- #3678 fast-poll window (Test-FastPollWindowActive) ----------
Assert-Probe 'fast-poll: null window inactive'  (-not (Test-FastPollWindowActive -FastPollUntil $null -Now $alertNow)) 'null'
Assert-Probe 'fast-poll: future window active'  (Test-FastPollWindowActive -FastPollUntil $alertNow.AddMinutes(5).ToString('o') -Now $alertNow) 'future'
Assert-Probe 'fast-poll: past window inactive'  (-not (Test-FastPollWindowActive -FastPollUntil $alertNow.AddMinutes(-1).ToString('o') -Now $alertNow)) 'past'
Assert-Probe 'fast-poll: unparsable window inactive (fail-safe)' (-not (Test-FastPollWindowActive -FastPollUntil 'not-a-date' -Now $alertNow)) 'garbage'

$failed = @($results | Where-Object { -not $_.Passed })
Write-Host "`n$($results.Count - $failed.Count)/$($results.Count) tests passed"
if ($failed.Count -gt 0) { exit 1 }
