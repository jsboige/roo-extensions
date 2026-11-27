# Pester 5 tests: the metered-link watch must never be installed with Task
# Scheduler's battery defaults (defect measured on myia-po-2027, 2026-11-25).
#
# Defect these tests pin: the install recipe documented in metered-link-watch.ps1
# was a bare `schtasks /create`. Task Scheduler then yields
# DisallowStartIfOnBatteries=True / StopIfGoingOnBatteries=True /
# StartWhenAvailable=False (measured on a witness task, then on the seat's own
# watch). The watch exists to catch a billed phone hotspot -- what a seat runs on
# away from mains power -- so at those defaults it is blind exactly when it
# matters. Exposure on that seat: 38 AC-to-battery transitions in 7 days.
#
# Design notes (what makes the assertions discriminating):
# * Everything asserted is pure logic from metered-link-watch-task.lib.ps1. The
#   ubuntu unit-pester runner has no PSScheduledTask module, and no test here
#   may touch a real task.
# * Create path and repair path are pinned separately: they fail separately (no
#   switch -> hostile defaults at creation; no plan -> an older install keeps
#   its values).
# * The installer itself is NOT executed: its wiring is guarded by the last
#   block, by text. That block proves only where the two cmdlets sit in the
#   file -- it is not a behavioural test of the installer.

BeforeAll {
    $script:lib = Join-Path $PSScriptRoot '../../monitoring/metered-link-watch-task.lib.ps1'
    $script:installer = Join-Path $PSScriptRoot '../../monitoring/install-metered-link-watch-schtask.ps1'
    . $script:lib
}

Describe 'Metered-link watch task - settings requested at creation' {
    It 'asks for all three switches New-ScheduledTaskSettingsSet needs to stay off the defaults' {
        $switches = Get-MeteredWatchCreateSettingsSwitches

        $switches['AllowStartIfOnBatteries']    | Should -BeTrue
        $switches['DontStopIfGoingOnBatteries'] | Should -BeTrue
        $switches['StartWhenAvailable']         | Should -BeTrue
    }

    It 'asks for exactly one switch per settings field -- creation and repair cannot disagree' {
        $switches = Get-MeteredWatchCreateSettingsSwitches
        $fields = @(Get-MeteredWatchBatteryFields)

        $switches.Count | Should -Be $fields.Count
        foreach ($field in $fields) {
            $switches.ContainsKey($field.Switch) | Should -BeTrue
        }
    }
}

Describe 'Metered-link watch task - repair plan on an existing task' {
    It 'plans exactly the three fields on a task carrying the Task Scheduler defaults' {
        $current = [pscustomobject]@{
            DisallowStartIfOnBatteries = $true
            StopIfGoingOnBatteries     = $true
            StartWhenAvailable         = $false
        }

        $plan = @(Get-MeteredWatchBatteryPlan -Current $current)

        $plan.Count | Should -Be 3
        ($plan | Where-Object Property -EQ 'DisallowStartIfOnBatteries').After | Should -BeFalse
        ($plan | Where-Object Property -EQ 'StopIfGoingOnBatteries').After     | Should -BeFalse
        ($plan | Where-Object Property -EQ 'StartWhenAvailable').After         | Should -BeTrue
        ($plan | Where-Object Property -EQ 'StopIfGoingOnBatteries').Before    | Should -BeTrue
    }

    It 'plans nothing on a task that is already correct -- the installer then writes nothing' {
        $current = [pscustomobject]@{
            DisallowStartIfOnBatteries = $false
            StopIfGoingOnBatteries     = $false
            StartWhenAvailable         = $true
        }

        @(Get-MeteredWatchBatteryPlan -Current $current).Count | Should -Be 0
    }

    It 'plans only the field that differs (a partial state left by an older install)' {
        $current = [pscustomobject]@{
            DisallowStartIfOnBatteries = $false
            StopIfGoingOnBatteries     = $true
            StartWhenAvailable         = $true
        }

        $plan = @(Get-MeteredWatchBatteryPlan -Current $current)

        $plan.Count | Should -Be 1
        $plan[0].Property | Should -Be 'StopIfGoingOnBatteries'
    }

    It 'accepts a real settings object shape (hashtable keys) -- no property-name mismatch' {
        $current = @{
            DisallowStartIfOnBatteries = $true
            StopIfGoingOnBatteries     = $true
            StartWhenAvailable         = $false
            ExecutionTimeLimit         = 'PT72H'
        }

        $plan = @(Get-MeteredWatchBatteryPlan -Current $current)

        @($plan.Property | Sort-Object) | Should -Be @('DisallowStartIfOnBatteries', 'StartWhenAvailable', 'StopIfGoingOnBatteries')
    }
}

Describe 'Metered-link watch task - installer wiring (text guard)' {
    BeforeAll {
        $script:text = Get-Content -LiteralPath $script:installer -Raw
    }

    It 'repairs through Set-ScheduledTask and registers only on the missing-task path, after it' {
        $setText = 'Set-ScheduledTask -TaskName'
        $registerText = 'Register-ScheduledTask -TaskName'

        $text.Contains($setText) | Should -BeTrue
        $text.Contains($registerText) | Should -BeTrue
        # The repair branch returns before the register call can be reached: the
        # repair must never re-register (it would drop a locally hardened action).
        $text.IndexOf($setText) | Should -BeLessThan $text.IndexOf($registerText)
    }

    It 'feeds the create settings from the lib switch table, not from hand-written switches' {
        $text.Contains('New-ScheduledTaskSettingsSet @switches') | Should -BeTrue
    }

    It 'lib and installer are ASCII-only (PS 5.1 parses a BOM-less .ps1 only then)' {
        $libText = Get-Content -LiteralPath $script:lib -Raw
        foreach ($chunk in @($script:text, $libText)) {
            @($chunk.ToCharArray() | Where-Object { [int]$_ -gt 127 }).Count | Should -Be 0
        }
    }
}

Describe 'Metered-link watch task - ambiguous task name (#4927)' {
    # A scheduled-task NAME is not unique: the same name can live in two folders,
    # and Get-ScheduledTask -TaskName then returns an ARRAY. Reading .Settings off
    # it yields nothing usable -- the repair plan would invent a Before value and
    # Set-ScheduledTask would receive the whole collection. The installer must
    # refuse instead of guessing which task the operator meant.
    It 'refuses two matches and names both folders' {
        $two = @(
            [pscustomobject]@{ TaskName = 'RooMeteredLinkWatch'; TaskPath = '\' },
            [pscustomobject]@{ TaskName = 'RooMeteredLinkWatch'; TaskPath = '\Personal\' }
        )

        { Select-MeteredWatchTask -Candidate $two } | Should -Throw -ExpectedMessage '*ambiguous*'

        $message = $null
        try { Select-MeteredWatchTask -Candidate $two } catch { $message = $_.Exception.Message }
        $message | Should -BeLike '*\Personal\*'
    }

    It 'returns the single match untouched -- the repair keeps targeting that one task' {
        $one = [pscustomobject]@{ TaskName = 'RooMeteredLinkWatch'; TaskPath = '\Personal\' }

        (Select-MeteredWatchTask -Candidate @($one)).TaskPath | Should -Be '\Personal\'
    }

    It 'returns $null on no match -- the create path is unchanged' {
        Select-MeteredWatchTask -Candidate @() | Should -BeNullOrEmpty
    }

    It 'ignores null entries a SilentlyContinue lookup can leave in the pipeline' {
        $one = [pscustomobject]@{ TaskName = 'RooMeteredLinkWatch'; TaskPath = '\' }

        (Select-MeteredWatchTask -Candidate @($null, $one)).TaskPath | Should -Be '\'
    }

    It 'is wired into the installer before any repair write' {
        $text = Get-Content -LiteralPath $script:installer -Raw

        $text.Contains('Select-MeteredWatchTask -Candidate') | Should -BeTrue
        $text.IndexOf('Select-MeteredWatchTask -Candidate') | Should -BeLessThan $text.IndexOf('Set-ScheduledTask -TaskName')
    }

    It 'names the task folder on both the write and the verification read (review ai-01 27/11)' {
        # Without -TaskPath, Set-ScheduledTask resolves the name in the ROOT
        # folder: a single task living in a subfolder would be left untouched and
        # a copy written at the root. The read after the write needs it too, or it
        # compares a task that is not the one just written and reports success.
        $text = Get-Content -LiteralPath $script:installer -Raw

        ([regex]::Matches($text, '-TaskPath \$existing\.TaskPath')).Count | Should -Be 2
        $text.IndexOf('-TaskPath $existing.TaskPath') | Should -BeGreaterThan $text.IndexOf('Set-ScheduledTask -TaskName')
    }
}
