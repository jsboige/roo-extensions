# Pester 5 tests: the GDriveFS-Watchdog installer must FAIL LOUDLY (#3711).
#
# Defect these tests pin: on Server 2019, the fast-poll companion trigger was
# built with -RepetitionDuration ([TimeSpan]::MaxValue), which the scheduler
# rejects with 0x80041318 -- and that Register-ScheduledTask error is
# NON-TERMINATING, so the installer printed "Installed companion task",
# exited 0, and the fleet believed the trigger was live (reported web1 c.471,
# verified firsthand po-203). The trap is the false success, not the error.
#
# Fix under test: MaxValue is gone (Duration nulled explicitly = indefinite,
# the #967 path already used by scripts/scheduling/setup-scheduler.ps1), and
# two guards close the silent holes: -ErrorAction Stop + try/catch on every
# registration, and a post-registration readback asserting the repetition is
# ON THE REGISTERED TASK before any success line is printed.
#
# Design notes (what makes the assertions discriminating):
# * The installer runs as a CHILD PROCESS of the same engine that runs this
#   suite (pwsh on the CI ubuntu runner, Windows PowerShell 5.1 locally),
#   against a TEMPORARY copy of the script: the production checkout is never
#   executed nor touched.
# * The PSScheduledTask cmdlets are faked by PREPENDING a temp module dir to
#   the child's PSModulePath: command auto-loading resolves the fake module
#   before any real one (Linux CI has none; on Windows the fake dir sorts
#   first). The fakes model the Windows PowerShell 5.1 / Server 2019
#   semantics that produced the defect:
#     - -RepetitionInterval without -RepetitionDuration leaves Duration at
#       the 'P1D' default, so an installer that forgets the explicit null-out
#       registers a 1-day-bounded repeat (the readback guard rejects it);
#     - FAKE_REGISTER_FAIL_ON=<task> makes Register-ScheduledTask emit a
#       NON-TERMINATING Write-Error (the 0x80041318 class) via a
#       CmdletBinding'd function: -ErrorAction Stop promotes it (guard
#       catches), a stripped guard lets the script carry on (defect).
#     - FAKE_REGISTER_DROP_REPETITION=<task> registers the task but stores
#       its triggers WITHOUT the repetition (silent drop at the scheduler).
# * Record-first: every fake logs its invocation before doing anything, so
#   "attempted then failed" still leaves a record while "never attempted"
#   leaves none.
# * Positive control: a mutated copy with the guards stripped reproduces the
#   original false success (exit 0 + "Installed companion task") under the
#   same failure injection -- if the harness ever breaks, the control goes
#   red instead of the invariants passing vacuously.

Describe 'GDriveFS-Watchdog installer fail-loud invariants (#3711)' {

    BeforeAll {
        $script:productionScript = Join-Path $PSScriptRoot '../../gdrivefs-watchdog/install-gdrivefs-watchdog-schtask.ps1'
        $script:fixedText = Get-Content -LiteralPath $script:productionScript -Raw
        $script:utf8Bom = [System.Text.UTF8Encoding]::new($true)

        $script:origModulePath = $env:PSModulePath
        $script:origFakeLog = $env:FAKE_SCHTASK_LOG
        $script:origFailOn = $env:FAKE_REGISTER_FAIL_ON
        $script:origDropRep = $env:FAKE_REGISTER_DROP_REPETITION
        $script:harnessRoots = @()

        # Engine that runs the installer child: the SAME binary running this
        # suite (pwsh on CI; powershell.exe when the suite runs under 5.1).
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $script:engine = Join-Path $PSHOME 'pwsh'
        } else {
            $script:engine = Join-Path $PSHOME 'powershell.exe'
        }

        $script:fakeModuleText = @'
# Fake PSScheduledTask surface for the #3711 fail-loud tests. Auto-loaded by
# the installer child process via PSModulePath precedence. Models the Windows
# PowerShell 5.1 / Server 2019 semantics that produced the defect (see the
# test file header). Every fake records its invocation FIRST.

$script:RegisteredTasks = @{}

function Write-TaskRecord {
    param([string]$Line)
    if ($env:FAKE_SCHTASK_LOG) {
        Add-Content -Path $env:FAKE_SCHTASK_LOG -Value $Line
    }
}

function ConvertTo-FakeIsoDuration {
    param([timespan]$Span)
    $totalMinutes = [int][Math]::Floor($Span.TotalMinutes + 0.001)
    $days = [Math]::Floor($totalMinutes / 1440)
    $rem = $totalMinutes % 1440
    $hours = [Math]::Floor($rem / 60)
    $mins = $rem % 60
    $datePart = ''
    if ($days -gt 0) { $datePart = "${days}D" }
    $timePart = ''
    if ($hours -gt 0) { $timePart += "${hours}H" }
    if ($mins -gt 0 -or ($days -eq 0 -and $hours -eq 0)) { $timePart += "${mins}M" }
    if ($timePart) { return "P${datePart}T$timePart" }
    return "P${datePart}"
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
        [int]$RestartCount,
        [timespan]$RestartInterval,
        [timespan]$ExecutionTimeLimit,
        [string]$MultipleInstances
    )
    return [pscustomobject]@{ PSTypeName = 'FakeTaskSettings' }
}

function New-ScheduledTaskTrigger {
    [CmdletBinding()]
    param(
        [switch]$Once,
        [switch]$AtLogOn,
        [switch]$AtStartup,
        [datetime]$At,
        [timespan]$RepetitionInterval,
        [timespan]$RepetitionDuration,
        [string]$User
    )
    $repetition = $null
    if ($PSBoundParameters.ContainsKey('RepetitionInterval')) {
        # PS 5.1 semantics: interval alone leaves a 1-day default Duration.
        $duration = 'P1D'
        if ($PSBoundParameters.ContainsKey('RepetitionDuration')) {
            $duration = ConvertTo-FakeIsoDuration -Span $RepetitionDuration
        }
        $repetition = [pscustomobject]@{
            Interval = (ConvertTo-FakeIsoDuration -Span $RepetitionInterval)
            Duration = $duration
            StopAtDurationEnd = $false
        }
    }
    $startBoundary = $null
    if ($PSBoundParameters.ContainsKey('At')) { $startBoundary = $At.ToString('o') }
    return [pscustomobject]@{
        PSTypeName = 'FakeTaskTrigger'
        StartBoundary = $startBoundary
        Delay = $null
        Repetition = $repetition
    }
}

function Register-ScheduledTask {
    [CmdletBinding()]
    param(
        [string]$TaskName,
        $Action,
        $Trigger,
        $Principal,
        $Settings,
        [string]$Description
    )
    Write-TaskRecord "register :: $TaskName"
    if ($env:FAKE_REGISTER_FAIL_ON -and $env:FAKE_REGISTER_FAIL_ON -eq $TaskName) {
        # Server 2019 class of failure: NON-terminating unless the caller
        # bound -ErrorAction Stop (CmdletBinding then promotes it).
        Write-Error "The task XML contains a value which is incorrectly formatted or out of range. (0x80041318) [fake injection on '$TaskName']"
        return
    }
    $storedTriggers = @($Trigger)
    if ($env:FAKE_REGISTER_DROP_REPETITION -and $env:FAKE_REGISTER_DROP_REPETITION -eq $TaskName) {
        $storedTriggers = @($Trigger | ForEach-Object {
            $copy = $_.PSObject.Copy()
            $copy.Repetition = $null
            $copy
        })
    }
    $script:RegisteredTasks[$TaskName] = [pscustomobject]@{
        TaskName = $TaskName
        Triggers = $storedTriggers
        State = 'Ready'
    }
    $shape = (@($storedTriggers) |
        Where-Object { $_.Repetition -and $_.Repetition.Interval } |
        ForEach-Object { "Interval=$($_.Repetition.Interval);Duration=$($_.Repetition.Duration)" }) -join '|'
    Write-TaskRecord "register-repetition :: $TaskName :: $shape"
}

function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName)
    Write-TaskRecord "get :: $TaskName"
    return $script:RegisteredTasks[$TaskName]
}

function Disable-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName)
    Write-TaskRecord "disable :: $TaskName"
    if ($script:RegisteredTasks.ContainsKey($TaskName)) {
        $script:RegisteredTasks[$TaskName].State = 'Disabled'
    }
}

function Unregister-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName, [switch]$Confirm)
    Write-TaskRecord "unregister :: $TaskName"
    $script:RegisteredTasks.Remove($TaskName)
}

Export-ModuleMember -Function @(
    'New-ScheduledTaskAction', 'New-ScheduledTaskPrincipal',
    'New-ScheduledTaskSettingsSet', 'New-ScheduledTaskTrigger',
    'Register-ScheduledTask', 'Get-ScheduledTask',
    'Disable-ScheduledTask', 'Unregister-ScheduledTask'
)
'@

        function New-InstallerHarness {
            param([string]$ScriptText)

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("gdrivefs-3711-" + [guid]::NewGuid().ToString('N'))
            $script:harnessRoots += $root

            $scriptDir = Join-Path (Join-Path $root 'repo') 'scripts'
            $scriptDir = Join-Path $scriptDir 'gdrivefs-watchdog'
            New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
            $scriptCopy = Join-Path $scriptDir 'install-gdrivefs-watchdog-schtask.ps1'
            [System.IO.File]::WriteAllText($scriptCopy, $ScriptText, $script:utf8Bom)

            # The installer requires the watchdog body next to itself.
            $bodyCopy = Join-Path $scriptDir 'gdrivefs-watchdog.ps1'
            [System.IO.File]::WriteAllText($bodyCopy, "param()`nexit 0`n", $script:utf8Bom)

            $moduleDir = Join-Path (Join-Path $root 'mod') 'PesterFakeScheduledTask'
            New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $moduleDir 'PesterFakeScheduledTask.psm1'), $script:fakeModuleText, $script:utf8Bom)

            $mount = Join-Path $root 'mnt'
            New-Item -ItemType Directory -Path $mount -Force | Out-Null

            return @{
                Root = $root
                Script = $scriptCopy
                ModuleDir = (Split-Path -Parent $moduleDir)
                Log = Join-Path $root 'schtask-invocations.log'
                Mount = $mount
            }
        }

        function Invoke-Installer {
            param(
                [hashtable]$Harness,
                [string[]]$ExtraArgs = @(),
                [hashtable]$FakeEnv = @{}
            )

            $env:PSModulePath = $Harness.ModuleDir + [System.IO.Path]::PathSeparator + $script:origModulePath
            $env:FAKE_SCHTASK_LOG = $Harness.Log
            $env:FAKE_REGISTER_FAIL_ON = $null
            $env:FAKE_REGISTER_DROP_REPETITION = $null
            foreach ($k in $FakeEnv.Keys) {
                Set-Item -Path ("Env:" + $k) -Value $FakeEnv[$k]
            }

            $engineArgs = @('-NoProfile')
            if ($env:OS -eq 'Windows_NT') {
                $engineArgs += @('-ExecutionPolicy', 'Bypass')
            }
            $engineArgs += @('-File', $Harness.Script, '-MountPath', $Harness.Mount)
            $engineArgs += $ExtraArgs

            # EAP scoped to Continue around the child call: on pwsh 7.2+ a
            # child stderr line captured via 2>&1 under EAP Stop would throw
            # in the TEST process instead of being captured as diagnostics.
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $output = & $script:engine @engineArgs 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $prevEap
                $env:PSModulePath = $script:origModulePath
                $env:FAKE_SCHTASK_LOG = $script:origFakeLog
                $env:FAKE_REGISTER_FAIL_ON = $script:origFailOn
                $env:FAKE_REGISTER_DROP_REPETITION = $script:origDropRep
            }
            return @{
                ExitCode = $exitCode
                Output = ((@($output) | ForEach-Object { [string]$_ }) -join "`n")
            }
        }
    }

    BeforeEach {
        $script:harness = New-InstallerHarness -ScriptText $script:fixedText
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

    It 'static (AST): no trigger is built with -RepetitionDuration (the Server 2019 0x80041318 source); both repetitions null Duration explicitly' {
        # AST-based, not text-based: the fix's own comments legitimately
        # mention MaxValue, so a raw -Not -Match would false-positive. What
        # must not exist is the PARAMETER on an actual command call.
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($script:fixedText, [ref]$null, [ref]$null)
        $triggerCalls = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'New-ScheduledTaskTrigger'
        }, $true))
        $triggerCalls.Count | Should -BeGreaterThan 0
        $offenders = @($triggerCalls | Where-Object {
            @($_.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandParameterAst] -and
                $node.ParameterName -eq 'RepetitionDuration'
            }, $true)).Count -gt 0
        })
        $offenders.Count | Should -Be 0
        # Two repetition triggers (main 15-min repeat + fast-poll), each
        # nulled explicitly -- the #967 indefinite path. Under the 5.1-semantics
        # fakes below, forgetting either null-out leaves Duration=P1D and the
        # readback guard fails the install.
        ([regex]::Matches($script:fixedText, '\.Repetition\.Duration = \$null')).Count | Should -Be 2
    }

    It 'install (fakes, happy path): exits 0, both repetitions land with EMPTY Duration (indefinite -- neither the P1D 5.1 default nor MaxValue)' {
        $result = Invoke-Installer -Harness $script:harness

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'Installed companion task'
        $lines = @(Get-Content -LiteralPath $script:harness.Log)
        # Exact-line asserts: a Duration=P1D or MaxValue-shaped line must not
        # satisfy them by prefix.
        $lines -contains 'register-repetition :: GDriveFS-Watchdog :: Interval=PT15M;Duration=' | Should -BeTrue
        $lines -contains 'register-repetition :: GDriveFS-Watchdog-FastPoll :: Interval=PT1M;Duration=' | Should -BeTrue
        $lines -contains 'disable :: GDriveFS-Watchdog-FastPoll' | Should -BeTrue
    }

    It 'declared failure: a NON-terminating Register error (the 2019 0x80041318 class) on the fast task -> NON-ZERO exit, visible ERROR including the underlying message, and NO success line' {
        $result = Invoke-Installer -Harness $script:harness -FakeEnv @{ FAKE_REGISTER_FAIL_ON = 'GDriveFS-Watchdog-FastPoll' }

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'ERROR'
        # The underlying scheduler rejection must surface, not be swallowed.
        $result.Output | Should -Match '0x80041318'
        $result.Output | Should -Not -Match 'Installed companion task'
        # Record-first: the registration WAS attempted -- a declared failure
        # is not the absence of an attempt.
        @(Get-Content -LiteralPath $script:harness.Log) -contains 'register :: GDriveFS-Watchdog-FastPoll' | Should -BeTrue
    }

    It 'declared failure: registration succeeds but the repetition is silently dropped -> readback guard exits NON-ZERO BEFORE any success output' {
        $result = Invoke-Installer -Harness $script:harness -FakeEnv @{ FAKE_REGISTER_DROP_REPETITION = 'GDriveFS-Watchdog-FastPoll' }

        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'did NOT land'
        $result.Output | Should -Not -Match 'Installed scheduled task'
        $result.Output | Should -Not -Match 'Installed companion task'
    }

    It '-DryRun non-regression: exits 0, prints the plan, attempts NO registration' {
        $result = Invoke-Installer -Harness $script:harness -ExtraArgs @('-DryRun')

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'DRY-RUN'
        $result.Output | Should -Match 'indefinite duration'
        $logLines = @(Get-Content -LiteralPath $script:harness.Log -ErrorAction SilentlyContinue)
        (@($logLines | Where-Object { $_ -like 'register ::*' })).Count | Should -Be 0
    }

    It 'POSITIVE CONTROL: guards stripped (the pre-#3711 defect) -> the SAME non-terminating failure yields exit 0 + "Installed companion task" (false success reproduced)' {
        # Mutation 1: strip -ErrorAction Stop from the real command calls (the
        # comment mention on the guard-section header is inert).
        $mutated = $script:fixedText -replace '(?m)^(\s+(Register|Disable)-ScheduledTask[^\r\n]*) -ErrorAction Stop', '$1'
        # Mutation 2: strip the readback-guard CALLS (definitions stay, inert).
        $mutated = $mutated -replace '(?m)^\s*Assert-RegisteredRepetition -Name[^\r\n]*\r?\n?', ''

        # Mutation validity: anchor drift must fail LOUDLY here rather than
        # ship a control that proves nothing.
        $mutated | Should -Not -Be $script:fixedText
        $mutated | Should -Not -Match 'Assert-RegisteredRepetition -Name'
        $mutated | Should -Not -Match '(?m)^\s+(Register|Disable)-ScheduledTask[^\r\n]*-ErrorAction Stop'
        ([regex]::Matches($script:fixedText, '\.Repetition\.Duration = \$null')).Count | Should -Be 2

        [System.IO.File]::WriteAllText($script:harness.Script, $mutated, $script:utf8Bom)

        $result = Invoke-Installer -Harness $script:harness -FakeEnv @{ FAKE_REGISTER_FAIL_ON = 'GDriveFS-Watchdog-FastPoll' }

        $result.ExitCode | Should -Be 0
        $result.Output | Should -Match 'Installed companion task'
    }
}
