<#
.SYNOPSIS
    Regression coverage for the #3761 exit-99 crash: a null dashboard path killed the listener.

.DESCRIPTION
    po-2027 reported (07/10 00:43:15Z) an uncaught parameter-binding error
    ("Cannot bind argument to parameter 'Path' because it is null") raised from the
    fallback polling loop. The wrapper logged "exit code 99" and restarted after 60s,
    re-running the startup sweep over every unresolved workspace each time.

    The defect is not a wrong value but a missing guard: the loop built the path and
    probed it inline, so any null reached Test-Path and terminated the process.
    Get-DashboardFileLWT now owns both steps and returns $null instead of throwing, so
    a transient hiccup costs one skipped tick - never a process death.

    Behaviour kept: an absent file stays silent, exactly as before. A null/empty path is
    an anomaly and warns, throttled, so a persistent one cannot become a hot WARN loop
    (#3761 remedy 2).

    Extraction pattern: dashboard-listener-definitive-skip.Tests.ps1 (AST function
    extraction - the listener runs a single-instance mutex and a main loop, so it cannot
    be dot-sourced).

    Excluded from CI? No - unit suite, pure temp-dir file effects, no subprocess.
#>

Describe 'Listener dashboard read guard (#3761 exit-99)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $listenerPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/dashboard-listener.ps1'

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $listenerPath, [ref]$tokens, [ref]$parseErrors)
        @($parseErrors) | Should -BeNullOrEmpty

        $script:ListenerText = [System.IO.File]::ReadAllText($listenerPath)

        $definition = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        ) | Where-Object Name -EQ 'Get-DashboardFileLWT' | Select-Object -First 1
        if (-not $definition) { throw "Get-DashboardFileLWT not found in $listenerPath" }

        # The extracted function runs in THIS scope, so its two dependencies must exist
        # here: Write-Log (stubbed and captured for assertions) and the throttle stamp.
        $script:LogLines = New-Object System.Collections.ArrayList
        function Write-Log { param($level, $msg) [void]$script:LogLines.Add("$level|$msg") }

        Invoke-Expression $definition.Extent.Text

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t3761poll-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    BeforeEach {
        $script:LogLines.Clear()
        $script:lastPollPathWarnAt = [DateTime]::MinValue
    }

    Context 'The crash po-2027 measured - a null path must not kill the process' {
        It 'does not throw when the dashboard directory is null' {
            { Get-DashboardFileLWT $null 'CoursIA' } | Should -Not -Throw
        }

        It 'returns $null for a null dashboard directory' {
            Get-DashboardFileLWT $null 'CoursIA' | Should -BeNullOrEmpty
        }

        It 'does not throw when the dashboard directory is an empty string' {
            { Get-DashboardFileLWT '' 'CoursIA' } | Should -Not -Throw
        }

        It 'returns $null for an empty dashboard directory' {
            Get-DashboardFileLWT '' 'CoursIA' | Should -BeNullOrEmpty
        }

        It 'warns once on a null path, then throttles within the window' {
            $null = Get-DashboardFileLWT $null 'CoursIA'
            $null = Get-DashboardFileLWT $null 'CoursIA'
            $null = Get-DashboardFileLWT $null 'CoursIA-2'
            @($script:LogLines | Where-Object { $_ -like 'WARN|*' }).Count | Should -Be 1
        }

        It 'the WARN names the issue so the anomaly is traceable in the log' {
            $null = Get-DashboardFileLWT $null 'CoursIA'
            ($script:LogLines -join ' ') | Should -Match '#3761'
        }
    }

    Context 'Normal behaviour preserved' {
        It 'returns $null and logs nothing for an absent workspace file' {
            Get-DashboardFileLWT $script:Tmp 'Absent' | Should -BeNullOrEmpty
            @($script:LogLines).Count | Should -Be 0
        }

        It 'returns the LastWriteTimeUtc of an existing workspace file' {
            $f = Join-Path $script:Tmp 'workspace-Present.md'
            [System.IO.File]::WriteAllText($f, 'x')
            $expected = (Get-Item $f).LastWriteTimeUtc
            Get-DashboardFileLWT $script:Tmp 'Present' | Should -Be $expected
        }
    }

    Context 'Static composition - the guard is the only path builder' {
        It 'builds the dashboard path in exactly one place' {
            [regex]::Matches($script:ListenerText, 'Join-Path \$DashboardDir "workspace-').Count | Should -Be 1
        }

        It 'no longer builds the path inline in the polling paths' {
            $script:ListenerText | Should -Not -Match '\$f = Join-Path \$dashboardDir "workspace-'
        }

        It 'the polling block no longer probes the filesystem inline' {
            # Scoped to the fallback-polling block: Get-LastAck / Get-LastSpawn still read
            # lock files inline ($LockDir base, out of scope - untouched by this fix).
            $start = $script:ListenerText.IndexOf('# Fallback polling: check LastWriteTime')
            $end = $script:ListenerText.IndexOf('Start-Sleep -Seconds 1', $start)
            $start | Should -BeGreaterThan -1
            $end | Should -BeGreaterThan $start
            $pollBlock = $script:ListenerText.Substring($start, $end - $start)
            $pollBlock | Should -Not -Match 'Test-Path'
            $pollBlock | Should -Not -Match 'Get-Item'
        }

        It 'both polling call sites route through the guard' {
            [regex]::Matches($script:ListenerText, 'Get-DashboardFileLWT \$dashboardDir \$ws').Count | Should -Be 2
        }
    }
}
