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

    It 'the legacy bare "repaired at Start-Process" append exists ONLY under the SkipWriteVerify kill-switch' {
        # Exactly one bare append, and it sits inside the legacy branch: the
        # default path must never emit repaired without the write verdict.
        ([regex]::Matches($script:mainText, '\$script:repairs \+= ''gdrivefs-relaunch''')).Count | Should -Be 1
        $script:mainText | Should -Match '(?s)if \(\$SkipWriteVerify\).{0,600}\$script:repairs \+= ''gdrivefs-relaunch'''
    }

    It 'the default path appends a write-VERIFIED repair string instead' {
        $script:mainText | Should -Match ([regex]::Escape("gdrivefs-relaunch (write-verified)"))
    }
}
