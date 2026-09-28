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

    It 'accepts one comma-separated -Drive string (arrays cannot cross -File)' {
        $r = Invoke-Target @('-Drive', 'C:,D:', '-WarnPercent', '0', '-BlockPercent', '0')
        $r.Exit | Should -BeIn (0, 2, 3)
        $letters = @([regex]::Matches($r.Output, '(?m)^\[(OK|WARN|BLOCK)\] ([A-Z]):') | ForEach-Object { $_.Groups[2].Value })
        $letters | Should -Be @('C', 'D')
    }

    It 'decides on the RAW free percent, never the rounded display (boundary)' {
        # #3900 review nit: calibrate a threshold strictly between round(raw,1)
        # and raw on a live drive -- under a rounded comparison the verdict flips.
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $raw = ([double]$disk.FreeSpace / [double]$disk.Size) * 100
        $rounded = [math]::Round($raw, 1)
        if ($raw -eq $rounded) { Set-ItResult -Skipped -Because 'live C: sits exactly on a tenth of a percent'; return }
        $t = $rounded + ($raw - $rounded) / 2
        $r = Invoke-Target @('-Drive', 'C:', '-WarnPercent', '0', '-BlockPercent', "$t")
        # Exclude the race where free space crossed the threshold mid-run.
        $disk2 = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $raw2 = ([double]$disk2.FreeSpace / [double]$disk2.Size) * 100
        if (($raw -lt $t) -ne ($raw2 -lt $t)) { Set-ItResult -Skipped -Because 'free space moved across the threshold during the run'; return }
        if ($raw -gt $t) {
            $r.Exit | Should -Be 0    # raw above: OK, though rounded < t would BLOCK
            $r.Output | Should -Match '(?m)^\[OK\] C:'
        } else {
            $r.Exit | Should -Be 3    # raw below: BLOCK, though rounded >= t would pass
            $r.Output | Should -Match '(?m)^\[BLOCK\] C:'
        }
    }
}
