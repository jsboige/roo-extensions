# Pester 5 tests: the approval-stall-detector installer must reject a bad -Python
# at INSTALL time (#4306).
#
# Defect these tests pin: -Python (#4278) is passed through to the VBS launcher
# unvalidated. A path that does not resolve to a file -- or the very
# \WindowsApps\ Microsoft Store stub the parameter exists to bypass -- installs
# cleanly, and the task then fails at every 2-hour tick. The error belongs to
# the install, not to the fleet's schedule.
#
# Design notes (what makes the assertions discriminating):
# * The installer runs as a CHILD PROCESS of the same engine that runs this
#   suite (pwsh on the ubuntu CI runner, powershell.exe under a 5.1 suite),
#   against a TEMPORARY copy: the production checkout is never executed.
# * The PSScheduledTask cmdlets the -DryRun plan build exercises are faked by
#   PREPENDING a temp module dir to the child's PSModulePath (Linux CI has no
#   real one; on Windows the fake dir sorts first) -- same mechanism as the
#   gdrivefs-watchdog suite (#3711).
# * LOCALAPPDATA is redirected to the harness root for the child: the VBS path
#   is Join-Path'd from it, and on Linux it is unset (Join-Path $null throws).
# * The guard throws must land BEFORE the plan print and before any write: a
#   bad -Python fails even under -DryRun, and the register fake never fires.
# * Case (d) pins the byte-compat promise: no -Python -> the printed VBS
#   carries no -Python at all, so seats relying on PATH are untouched.

Describe 'Approval-stall-detector installer -Python guard (#4306)' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../diagnostic/install-approval-stall-detector-task.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)

        $script:origModulePath = $env:PSModulePath
        $script:origLad = $env:LOCALAPPDATA
        $script:origFakeLog = $env:FAKE_STALLTASK_LOG
        $script:harnessRoots = @()

        # Engine that runs the installer child: the SAME binary running this
        # suite (pwsh on CI; powershell.exe when the suite runs under 5.1).
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        $script:fakeModuleText = @'
# Fake PSScheduledTask surface for the #4306 -Python guard tests. Auto-loaded
# by the installer child process via PSModulePath precedence. Only what the
# -DryRun plan build touches, plus Register-ScheduledTask as a record-first
# tripwire proving no registration ever happens in these tests.

function Write-TaskRecord {
    param([string]$Line)
    if ($env:FAKE_STALLTASK_LOG) {
        Add-Content -Path $env:FAKE_STALLTASK_LOG -Value $Line
    }
}

function New-ScheduledTaskAction {
    [CmdletBinding()]
    param([string]$Execute, [string]$Argument)
    return [pscustomobject]@{ Execute = $Execute; Argument = $Argument }
}

function New-ScheduledTaskPrincipal {
    [CmdletBinding()]
    param([string]$UserId, [string]$RunLevel, [string]$LogonType)
    return [pscustomobject]@{ UserId = $UserId; RunLevel = $RunLevel; LogonType = $LogonType }
}

function New-ScheduledTaskSettingsSet {
    [CmdletBinding()]
    param(
        [switch]$AllowStartIfOnBatteries,
        [switch]$DontStopIfGoingOnBatteries,
        [switch]$StartWhenAvailable,
        [timespan]$ExecutionTimeLimit,
        [string]$MultipleInstances
    )
    return [pscustomobject]@{ PSTypeName = 'FakeTaskSettings' }
}

function New-ScheduledTaskTrigger {
    [CmdletBinding()]
    param(
        [switch]$Once,
        [datetime]$At,
        [timespan]$RepetitionInterval,
        [timespan]$RepetitionDuration
    )
    $startBoundary = $null
    if ($At) { $startBoundary = $At.ToString('o') }
    $interval = $null
    if ($RepetitionInterval) { $interval = $RepetitionInterval.ToString() }
    return [pscustomobject]@{
        PSTypeName = 'FakeTaskTrigger'
        StartBoundary = $startBoundary
        Repetition = [pscustomobject]@{ Interval = $interval; Duration = $null }
    }
}

function New-ScheduledTask {
    [CmdletBinding()]
    param($Action, $Trigger, $Settings, $Principal, [string]$Description)
    return [pscustomobject]@{
        Actions = @($Action); Triggers = @($Trigger)
        Settings = $Settings; Principal = $Principal; Description = $Description
    }
}

function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName)
    return $null
}

function Register-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName, $InputObject, [switch]$Force)
    Write-TaskRecord "register :: $TaskName"
    return [pscustomobject]@{ TaskName = $TaskName; State = 'Ready' }
}

Export-ModuleMember -Function @(
    'New-ScheduledTaskAction', 'New-ScheduledTaskPrincipal',
    'New-ScheduledTaskSettingsSet', 'New-ScheduledTaskTrigger',
    'New-ScheduledTask', 'Get-ScheduledTask', 'Register-ScheduledTask'
)
'@

        function New-InstallerHarness {
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("stall-4306-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root

            # Temporary copy of the installer, same relative layout ($PSScriptRoot
            # feeds the launcher path); a stub launcher sits next to it.
            $scriptDir = Join-Path (Join-Path $root 'repo') 'scripts/diagnostic'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            $scriptCopy = Join-Path $scriptDir 'install-approval-stall-detector-task.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $script:fixedText, $script:utf8Bom)
            $launcherCopy = Join-Path $scriptDir 'run-approval-stall-detector.ps1'
            [System.IO.File]::WriteAllText($launcherCopy, "param()`nexit 0`n", $script:utf8Bom)

            $moduleDir = Join-Path (Join-Path $root 'mod') 'PesterFakeStallSchtask'
            New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $moduleDir 'PesterFakeStallSchtask.psm1'), $script:fakeModuleText, $script:utf8Bom)

            # A realistic -BotEnvFile: bearer present, value never asserted.
            $envFile = Join-Path $root 'stall-detector.env'
            [System.IO.File]::WriteAllText($envFile, "MCP_PROXY_BEARER=dummy-not-a-secret`n", $script:utf8Bom)

            # Python fixtures: the Store stub (dir named WindowsApps -- matches the
            # guard on both separator styles) and a healthy interpreter file.
            $fxRoot = Join-Path $root 'fx'
            $stubDir = Join-Path $fxRoot 'WindowsApps'
            New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
            $stubExe = Join-Path $stubDir 'python.exe'
            [System.IO.File]::WriteAllText($stubExe, "stub`n", $script:utf8Bom)
            $goodDir = Join-Path $fxRoot 'python-real'
            New-Item -ItemType Directory -Path $goodDir -Force | Out-Null
            $goodExe = Join-Path $goodDir 'python.exe'
            [System.IO.File]::WriteAllText($goodExe, "real`n", $script:utf8Bom)
            $missingExe = Join-Path (Join-Path $fxRoot 'no-such-dir') 'python.exe'

            return @{
                Root = $root
                Script = $scriptCopy
                ModuleDir = (Split-Path -Parent $moduleDir)
                Log = Join-Path $root 'schtask-invocations.log'
                EnvFile = $envFile
                StubExe = $stubExe
                GoodExe = $goodExe
                MissingExe = $missingExe
            }
        }

        function Invoke-Installer {
            param(
                [hashtable]$Harness,
                [string]$Python = ''
            )

            $env:PSModulePath = $Harness.ModuleDir + [System.IO.Path]::PathSeparator + $script:origModulePath
            $env:LOCALAPPDATA = $Harness.Root
            $env:FAKE_STALLTASK_LOG = $Harness.Log

            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @('-File', $Harness.Script, '-DryRun', '-BotEnvFile', $Harness.EnvFile)
            if ($Python) { $engineArgs += @('-Python', $Python) }

            # EAP scoped to Continue around the child call: on pwsh 7.2+ a child
            # stderr line captured via 2>&1 under EAP Stop would throw in the
            # TEST process instead of being captured as the guard's message.
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $output = & $script:engine @engineArgs 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap
                $env:PSModulePath = $script:origModulePath
                $env:LOCALAPPDATA = $script:origLad
                $env:FAKE_STALLTASK_LOG = $script:origFakeLog
            }
            return @{
                ExitCode = $exitCode
                Output = ((@($output) | ForEach-Object { [string]$_ }) -join "`n")
            }
        }
    }

    BeforeEach {
        $script:harness = New-InstallerHarness
    }

    AfterEach {
        if ($script:harness -and (Test-Path -LiteralPath $script:harness.Root)) {
            Remove-Item -LiteralPath $script:harness.Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    AfterAll {
        foreach ($root in $script:harnessRoots) {
            if ($root -and (Test-Path -LiteralPath $root)) {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'non-existent -Python: throws naming the path and "not found", BEFORE the plan (fails -DryRun too), registers nothing' {
        $result = Invoke-Installer -Harness $script:harness -Python $script:harness.MissingExe

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'not found'
        $result.Output | Should -Match ([regex]::Escape($script:harness.MissingExe))
        # The throw lands before the plan print and before the dry-run return.
        $result.Output | Should -Not -Match 'DRY-RUN'
        $result.Output | Should -Not -Match '(?m)^task\s+:'
        $logLines = @(Get-Content -LiteralPath $script:harness.Log -ErrorAction SilentlyContinue)
        (@($logLines | Where-Object { $_ -like 'register ::*' })).Count | Should -Be 0
    }

    It 'existing file under a WindowsApps dir: throws naming "WindowsApps", BEFORE the plan, registers nothing' {
        $result = Invoke-Installer -Harness $script:harness -Python $script:harness.StubExe

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'WindowsApps'
        $result.Output | Should -Match ([regex]::Escape($script:harness.StubExe))
        $result.Output | Should -Not -Match 'DRY-RUN'
        $result.Output | Should -Not -Match '(?m)^task\s+:'
        $logLines = @(Get-Content -LiteralPath $script:harness.Log -ErrorAction SilentlyContinue)
        (@($logLines | Where-Object { $_ -like 'register ::*' })).Count | Should -Be 0
    }

    It 'existing real -Python: -DryRun succeeds and the printed VBS passes the path through' {
        $result = Invoke-Installer -Harness $script:harness -Python $script:harness.GoodExe

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'DRY-RUN: nothing written'
        # Exact VBS literal (doubled quotes), not a regex: the path must land
        # verbatim in the launcher's -Python argument.
        $result.Output.Contains(' -Python ""' + $script:harness.GoodExe + '""') | Should -BeTrue
        $logLines = @(Get-Content -LiteralPath $script:harness.Log -ErrorAction SilentlyContinue)
        (@($logLines | Where-Object { $_ -like 'register ::*' })).Count | Should -Be 0
    }

    It 'no -Python: -DryRun succeeds and the printed VBS carries NO -Python (PATH seats untouched)' {
        $result = Invoke-Installer -Harness $script:harness

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'DRY-RUN: nothing written'
        $result.Output.Contains('-Python') | Should -BeFalse
        $logLines = @(Get-Content -LiteralPath $script:harness.Log -ErrorAction SilentlyContinue)
        (@($logLines | Where-Object { $_ -like 'register ::*' })).Count | Should -Be 0
    }
}
