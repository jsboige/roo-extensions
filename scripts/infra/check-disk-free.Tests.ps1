# Pester 5 tests for check-disk-free.ps1 (#3900).
#
# The TARGET always runs as a child `powershell.exe` (5.1) process -- the engine
# the fleet invokes this script with. The test HOST is pwsh 7 (Pester 5 is not
# shipped with Windows PowerShell 5.1).
#
# No drive state is mocked: thresholds are forced to impossible values (101/102)
# so the real machine drives exercise both branches deterministically -- the
# positive-control pattern (a guard must be PROVEN to fire, never assumed).
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/infra/check-disk-free.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'check-disk-free.ps1'

    function Invoke-Target {
        param([string[]]$TargetArgs)
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $target @TargetArgs 2>&1 | Out-String
        return [pscustomobject]@{ Output = $out; Exit = $LASTEXITCODE }
    }
}

Describe 'check-disk-free.ps1 (#3900)' {
    It 'nominal run (thresholds 0) exits 0 with at least one [OK] drive line' {
        $r = Invoke-Target @('-WarnPercent', '0', '-BlockPercent', '0')
        $r.Exit | Should -Be 0
        $r.Output | Should -Match '\[OK\] [A-Z]: '
    }

    It 'forced WARN threshold (101%) exits 2 with a [WARN] line and deletes nothing' {
        $r = Invoke-Target @('-WarnPercent', '101', '-BlockPercent', '0')
        $r.Exit | Should -Be 2
        $r.Output | Should -Match '\[WARN\] [A-Z]: '
        $r.Output | Should -Match '\[check-disk-free\] WARN'
    }

    It 'forced BLOCK threshold (101%) exits 3 with a [BLOCK] line (block wins over warn)' {
        $r = Invoke-Target @('-WarnPercent', '101', '-BlockPercent', '101')
        $r.Exit | Should -Be 3
        $r.Output | Should -Match '\[BLOCK\] [A-Z]: '
        $r.Output | Should -Match '\[check-disk-free\] BLOCK'
    }

    It 'unreadable drive letter exits 1 with a warning (never silent)' {
        $r = Invoke-Target @('-Drive', 'X:')
        $r.Exit | Should -Be 1
        $r.Output | Should -Match 'unreadable or zero-sized'
    }

    It 'default drive list excludes G: (DriveFS reports Drive quota, #3893)' {
        $r = Invoke-Target @('-WarnPercent', '0', '-BlockPercent', '0')
        $r.Output | Should -Not -Match '(?m)^\[(OK|WARN|BLOCK)\] G:'
    }

    It '-Drive C: measures exactly C: and nothing else' {
        $r = Invoke-Target @('-Drive', 'C:', '-WarnPercent', '0', '-BlockPercent', '0')
        $r.Exit | Should -BeIn (0, 2, 3)
        (@([regex]::Matches($r.Output, '(?m)^\[(OK|WARN|BLOCK)\] [A-Z]:')) | Measure-Object).Count | Should -Be 1
        $r.Output | Should -Match '(?m)^\[(OK|WARN|BLOCK)\] C:'
    }
}
