# Pester 5 tests for the #4508 watchdog rules: no kill on a single failed
# probe, and "repaired" only once a deep write works.
#
# Defects these tests pin (measured on ai-01, night of 03/11, watchdog log
# outputs/gdrivefs-watchdog/watchdog-20261103.log, local time +01:00):
#
#  1. KILL ON A SINGLE PROBE. At 03:04:30 a single 5 s stat timeout on a LIVE
#     DriveFS (pids 22556,23148) was enough for the watchdog to kill it at
#     03:04:33 ("alive but unhealthy -- killing wedged instance"). Windows
#     automatic maintenance (Defender, Chkdsk ProactiveScan, StorageSense,
#     NGEN -- 02:55:37-02:58:52) makes a busy mount slow, not wedged: the kill
#     turned a slow minute into a 20-minute outage. Nightly writers then hit a
#     G: that stats fine but refuses deep writes (NanoClaw 03/11 05:31Z: write
#     probe refused at 03:23:05, 18 min after the relaunch).
#
#  2. "REPAIRED" BEFORE THE DISK IS USABLE. $script:repairs was appended the
#     moment Start-Process returned (03:04:36), and the event-1000 summary
#     "repaired: gdrivefs-relaunch" was logged at 03:04:38 -- while the log's
#     own next line says the mount does not exist yet ("Aucun lecteur nomme
#     « G » n'existe pas"). A consumer cannot tell "process back" from "disk
#     usable".
#
# Fix under test: gdrivefs-watchdog.lib.ps1 supplies three injectable
# decisions -- Confirm-C1Failure (second, longer probe before any kill),
# Invoke-MountWriteProbe (sentinel write/read/delete in a deep folder),
# Get-RepairEventVerdict ('repaired' | 'write-pending' | 'deferred') -- and
# the main script wires them into the poll. Kill-switches restore the legacy
# behaviour: -ConfirmKillProbeSeconds 0 (single-probe kill) and -SkipWriteVerify
# (repaired at Start-Process time).
#
# CI-portable: every probe that touches a real mount is injected; the only
# real filesystem use is a TEMP folder round-trip (works on ubuntu runners).

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:wdDir = Join-Path $projectRoot "scripts/gdrivefs-watchdog"
    $script:libPath = Join-Path $script:wdDir "gdrivefs-watchdog.lib.ps1"
    . $script:libPath
    $script:mainText = Get-Content -LiteralPath (Join-Path $script:wdDir "gdrivefs-watchdog.ps1") -Raw
    # How many times a fake probe was invoked (script: scope so the fakes can
    # increment it from inside their scriptblock).
    $script:probeCalls = 0
}

Describe 'Confirm-C1Failure (#4508 rule 1: no kill on a single failed probe)' {

    It 'a failed probe followed by a RECOVERING confirm probe gives NO kill (busy, not wedged)' {
        $script:probeCalls = 0
        $r = Confirm-C1Failure -InitialReason 'mount-probe-timeout-5s' -ConfirmSeconds 30 -RunProbe {
            param($Seconds)
            $script:probeCalls = $script:probeCalls + 1
            @{ Live = $true; Reason = 'mount-stat+enum-ok' }
        }
        $r.Confirmed | Should -BeFalse
        $r.Reason   | Should -Be 'busy-recovered'
        $script:probeCalls | Should -Be 1
    }

    It 'a confirm probe that ALSO fails CONFIRMS the kill (genuinely wedged instance)' {
        $r = Confirm-C1Failure -InitialReason 'mount-probe-timeout-5s' -ConfirmSeconds 30 -RunProbe {
            param($Seconds)
            @{ Live = $false; Reason = 'mount-probe-timeout-30s' }
        }
        $r.Confirmed | Should -BeTrue
        $r.Reason   | Should -Match 'confirmed-by-second-probe-30s'
    }

    It 'kill-switch: ConfirmSeconds 0 restores the legacy single-probe kill WITHOUT any second probe' {
        $script:probeCalls = 0
        $r = Confirm-C1Failure -InitialReason 'mount-probe-timeout-5s' -ConfirmSeconds 0 -RunProbe {
            param($Seconds)
            $script:probeCalls = $script:probeCalls + 1
            @{ Live = $true; Reason = 'unreachable-under-legacy' }
        }
        $r.Confirmed | Should -BeTrue
        $r.Reason   | Should -Be 'legacy-single-probe'
        # The kill-switch must short-circuit BEFORE the probe: a legacy restore
        # that still ran a 30 s probe would be a behaviour change, not a restore.
        $script:probeCalls | Should -Be 0
    }

    It 'a confirm probe returning garbage is treated as CONFIRMED, never as recovery (fail-closed)' {
        $r = Confirm-C1Failure -InitialReason 'mount-probe-timeout-5s' -ConfirmSeconds 30 -RunProbe {
            param($Seconds)
            $null
        }
        $r.Confirmed | Should -BeTrue
    }
}

Describe 'Invoke-MountWriteProbe (#4508 rule 2: repaired only once a write works)' {

    It 'writes, reads back and DELETES a sentinel in a real temp folder' {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdfs-4508-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $r = Invoke-MountWriteProbe -FolderPath $dir
            $r.WriteOk | Should -BeTrue
            $r.Detail  | Should -Be 'write+read+delete-ok'
            # The sentinel must not survive the probe.
            @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reports WriteOk=false with the underlying error when the folder cannot be created' {
        # An existing FILE where the folder should be: New-Item -ItemType
        # Directory fails, the catch returns the reason. Portable (temp FS).
        $blocker = Join-Path ([System.IO.Path]::GetTempPath()) ("gdfs-4508-blocker-" + [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($blocker, 'x', [System.Text.UTF8Encoding]::new($false))
        try {
            $r = Invoke-MountWriteProbe -FolderPath $blocker
            $r.WriteOk | Should -BeFalse
            $r.Detail  | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item -LiteralPath $blocker -Force -ErrorAction SilentlyContinue
        }
    }

    It 'honors an injected Probe (CI ubuntu: no real mount is ever touched)' {
        $r = Invoke-MountWriteProbe -FolderPath 'Z:\no\such\mount' -Probe {
            param($FolderPath)
            @{ WriteOk = $false; Detail = 'injected-refusal' }
        }
        $r.WriteOk | Should -BeFalse
        $r.Detail  | Should -Be 'injected-refusal'
    }
}

Describe 'Get-RepairEventVerdict (#4508: process back != disk usable)' {

    It 'relaunch with stat OK but the write FAILING gives write-pending, NOT repaired' {
        $r = Get-RepairEventVerdict -ProcessAlive $true -C1Live $true -WriteResult @{ WriteOk = $false; Detail = 'refused' }
        $r | Should -Be 'write-pending'
    }

    It 'relaunch with the write OK gives repaired' {
        $r = Get-RepairEventVerdict -ProcessAlive $true -C1Live $true -WriteResult @{ WriteOk = $true; Detail = 'write+read+delete-ok' }
        $r | Should -Be 'repaired'
    }

    It 'process absent after relaunch stays deferred (the grace window owns the verdict)' {
        $r = Get-RepairEventVerdict -ProcessAlive $false -C1Live $false -WriteResult $null
        $r | Should -Be 'deferred'
    }

    It 'process back but C1 still dead stays deferred' {
        $r = Get-RepairEventVerdict -ProcessAlive $true -C1Live $false -WriteResult $null
        $r | Should -Be 'deferred'
    }
}

Describe 'gdrivefs-watchdog.ps1 wiring (#4508)' {

    It 'dot-sources the lib next to the body' {
        $script:mainText | Should -Match (('\. \(Join-Path \$scriptDir ''') + [regex]::Escape('gdrivefs-watchdog.lib.ps1') + '''\)')
    }

    It 'the C1 failure path routes through the confirm probe' {
        $script:mainText | Should -Match 'Confirm-C1Failure'
    }

    It 'write verification is wired into the poll' {
        $script:mainText | Should -Match 'Invoke-MountWriteProbe'
        $script:mainText | Should -Match 'Get-RepairEventVerdict'
    }

    It 'emits the distinct events relaunch-issued and write-pending' {
        $script:mainText | Should -Match 'relaunch-issued'
        $script:mainText | Should -Match 'write-pending'
        $script:mainText | Should -Match '-EventId 1001'
        $script:mainText | Should -Match '-EventId 1002'
    }

    It 'pins the new defaults: ConfirmKillProbeSeconds 30, SkipWriteVerify switch' {
        $script:mainText | Should -Match '\[int\]\$ConfirmKillProbeSeconds = 30'
        $script:mainText | Should -Match '\[switch\]\$SkipWriteVerify'
    }

    It 'the harness-dot-sourced sanitation span is Linux-CI safe: no Join-Path on $MountPath' {
        # test-gdrivefs-watchdog.ps1 dot-sources this span per case with
        # drive-letter MountPath fixtures, and the CI scheduling-harness job
        # runs on ubuntu: Join-Path validates the drive letter there
        # ("Cannot find drive 'G'") while being drive-blind on Windows. The
        # WriteProbeDir fallback must stay a lexical join.
        $span = [regex]::Match(
            $script:mainText,
            '(?s)# ---------- MountPath sanitation.*?(?=\r?\n# ---------- event log)'
        )
        $span.Success | Should -BeTrue
        $span.Value | Should -Not -Match 'Join-Path \$MountPath'
    }

    It 'the legacy bare "repaired at Start-Process" append exists ONLY under the SkipWriteVerify kill-switch' {
        # Exactly one bare append, and it sits inside the legacy branch: the
        # default path must never emit repaired without the write verdict.
        ([regex]::Matches($script:mainText, '\$script:repairs \+= ''gdrivefs-relaunch''')).Count | Should -Be 1
        $script:mainText | Should -Match '(?s)if \(\$SkipWriteVerify\).{0,600}\$script:repairs \+= ''gdrivefs-relaunch'''
    }

    It 'the default path appends a write-VERIFIED repair string instead' {
        $script:mainText | Should -Match ([regex]::Escape("gdrivefs-relaunch (write-verified)"))
    }

    It 'the env shared-path join is lexical too — no Join-Path on $env:ROOSYNC_SHARED_PATH (item 5)' {
        # ai-01 measure, 03/11: PS 5.1 Join-Path 'Q:\Mon Drive\x' 'y' ->
        # DriveNotFoundException (NOT drive-blind on Windows), pwsh/Linux ->
        # "Cannot find drive". The harness dot-sources this span on ubuntu CI.
        $span = [regex]::Match(
            $script:mainText,
            '(?s)# ---------- MountPath sanitation.*?(?=\r?\n# ---------- event log)'
        )
        $span.Success | Should -BeTrue
        $span.Value | Should -Not -Match 'Join-Path \$env:ROOSYNC_SHARED_PATH'
        $span.Value | Should -Match 'ROOSYNC_SHARED_PATH -replace'
    }
}

# ============================================================================
# ai-01 follow-up suite (03/11, same #4508): bounded write probe, sentinel
# cleanup, write-pending escalation, dry-run emits nothing, lexical env join.
# Red on 7abb3c7d for every item below.
# ============================================================================

Describe 'Invoke-MountWriteProbe - bounded runner (follow-up item 1)' {
    It 'reports a bounded-runner timeout as WriteOk=false with a timeout detail, never hanging the poll' {
        $r = Invoke-MountWriteProbe -FolderPath 'G:\deep\probe' -TimeoutSeconds 45 -RunBounded {
            param($Worker, $Folder, $Timeout)
            @{ TimedOut = $true; Result = $null }
        }
        $r.WriteOk | Should -BeFalse
        $r.Detail  | Should -Be 'write-probe-timeout-45s'
    }

    It 'passes the worker, the folder AND the timeout to the bounded runner (the bound is real)' {
        $r = Invoke-MountWriteProbe -FolderPath 'G:\deep\probe' -TimeoutSeconds 20 -RunBounded {
            param($Worker, $Folder, $Timeout)
            @{ TimedOut = $false; Result = @{ WriteOk = $true; Detail = "observed-timeout=$Timeout;folder=$Folder" } }
        }
        $r.Detail | Should -Be 'observed-timeout=20;folder=G:\deep\probe'
    }

    It 'the default path runs a real round-trip inside a job bounded by TimeoutSeconds' {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdfs-4508f1-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $r = Invoke-MountWriteProbe -FolderPath $dir -TimeoutSeconds 60
            $r.WriteOk | Should -BeTrue
            $r.Detail  | Should -Be 'write+read+delete-ok'
            @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'TimeoutSeconds 0 is the legacy inline kill-switch: no bound, plain round-trip' {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdfs-4508f2-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            $r = Invoke-MountWriteProbe -FolderPath $dir -TimeoutSeconds 0
            $r.WriteOk | Should -BeTrue
            @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'the default bounded runner is the Invoke-BoundedMountProbe job pattern (Start-Job/Wait-Job/finally)' {
        # A blocked write must die at TimeoutSeconds, not at the 5-min
        # ExecutionTimeLimit with IgnoreNew skipping polls (ai-01 measure).
        $libText = Get-Content -LiteralPath $script:libPath -Raw
        $fn = [regex]::Match($libText, '(?s)function Invoke-MountWriteProbe \{.*?\r?\n\}')
        $fn.Success | Should -BeTrue
        $fn.Value | Should -Match 'Start-Job'
        $fn.Value | Should -Match 'Wait-Job'
        ([regex]::Matches($fn.Value, 'Stop-Job')).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-MountWriteProbe - sentinel cleanup (follow-up item 2)' {
    It 'deletes the sentinel even when the read-back THROWS (try/finally, no leak)' {
        # Pester mocks do not cross the job boundary, so the worker runs
        # in-session through an injected bounded runner.
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdfs-4508f3-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        try {
            Mock Get-Content { throw 'read-back exploded' }
            $r = Invoke-MountWriteProbe -FolderPath $dir -TimeoutSeconds 30 -RunBounded {
                param($Worker, $Folder, $Timeout)
                @{ TimedOut = $false; Result = (& $Worker $Folder) }
            }
            $r.WriteOk | Should -BeFalse
            $r.Detail  | Should -Match 'read-back exploded'
            @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-WritePendingEscalation (follow-up item 3)' {
    It 'escalates at and after the threshold' {
        Test-WritePendingEscalation -Consecutive 3 -Threshold 3 | Should -BeTrue
        Test-WritePendingEscalation -Consecutive 7 -Threshold 3 | Should -BeTrue
    }

    It 'does not escalate below the threshold' {
        Test-WritePendingEscalation -Consecutive 2 -Threshold 3 | Should -BeFalse
    }

    It 'threshold 0 is the kill-switch: never escalate' {
        Test-WritePendingEscalation -Consecutive 999 -Threshold 0 | Should -BeFalse
    }
}

Describe 'Write-WatchdogEvent dry-run guard (follow-up item 4)' {
    BeforeAll {
        $m = [regex]::Match(
            $script:mainText,
            '(?s)# ---------- event log.*?(?=\r?\n# ---------- GitHub alert)'
        )
        if (-not $m.Success) { throw 'event log section not found in main script' }
        Invoke-Expression $m.Value
    }

    It 'dry-run writes NOTHING to the event log (a real 1000 was measured during a dry-run)' {
        $Mode = 'dry-run'
        Mock New-EventLog {}
        Mock Write-EventLog {}
        Write-WatchdogEvent -EventId 1000 -EntryType Information -Message 'rehearsal'
        Should -Invoke New-EventLog   -Times 0 -Scope It
        Should -Invoke Write-EventLog -Times 0 -Scope It
    }

    It 'the guard sits at the top of Write-WatchdogEvent, before any EventLog call (wiring)' {
        $fn = [regex]::Match(
            $script:mainText,
            "(?s)function Write-WatchdogEvent \{.*?\r?\n\}"
        )
        $fn.Success | Should -BeTrue
        $guardAt  = $fn.Value.IndexOf("if (`$Mode -eq 'dry-run') { return }")
        $firstEvt = $fn.Value.IndexOf('SourceExists')
        $guardAt  | Should -BeGreaterOrEqual 0
        $guardAt  | Should -BeLessThan $firstEvt
    }
}

Describe 'escalation wiring (follow-up item 3 + item 1 params)' {
    It 'the main script carries the escalation state, threshold param and survivor-channel reason' {
        $script:mainText | Should -Match 'consecutive_write_pending'
        $script:mainText | Should -Match 'Test-WritePendingEscalation'
        $script:mainText | Should -Match 'write-pending-escalation'
        $script:mainText | Should -Match '\[int\]\$WritePendingEscalationPolls = 3'
        $script:mainText | Should -Match '\[int\]\$WriteProbeTimeoutSeconds = 45'
    }

    It 'both probe call sites pass the bounded timeout' {
        ([regex]::Matches(
            $script:mainText,
            'Invoke-MountWriteProbe -FolderPath \$WriteProbeDir -TimeoutSeconds \$WriteProbeTimeoutSeconds'
        )).Count | Should -Be 2
    }

    It 'a write-pending poll persists the counter even when nothing else changed (explicit save)' {
        # The healthy-branch C2 reset only saves when OTHER counters are set;
        # the write-pending counter must not rely on it (ai-01 item 3).
        $script:mainText | Should -Match '(?s)write-pending.{0,900}consecutive_write_pending = \[int\]\$state\.consecutive_write_pending \+ 1'
    }

    It 'repaired and a fresh relaunch both reset the write-pending counter' {
        # Three resets: at the relaunch itself, and in both repaired branches.
        ([regex]::Matches($script:mainText, 'consecutive_write_pending = 0')).Count | Should -Be 3
    }
}
