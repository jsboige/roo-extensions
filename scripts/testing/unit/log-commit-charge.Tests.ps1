# log-commit-charge.Tests.ps1 — guards scripts/diagnostic/log-commit-charge.ps1 (#2992)
#
# Two layers:
#   - static (every platform, runs in unit-pester on ubuntu): the script
#     parses, its param contract holds, and it is locale-proof BY
#     CONSTRUCTION — it must read commit counters through CIM classes whose
#     property names are English on every locale, and must NOT call
#     Get-Counter (the known defect of the archived original
#     scripts/_archive/cleanup-3323-2026-08-31/: English counter names,
#     silently skipped on FR locales, so the MissingCommit columns never
#     populated on ai-01).
#   - live (Windows only): a 3-second micro-run produces >= 2 samples, every
#     sample is valid JSON with the required keys, committed <= limit, the
#     FreeVirtualMemory identity holds within tolerance, and the summary
#     lands even though the run ends via DurationSec (same finally block a
#     Ctrl+C takes).
#
# The identity check is the issue's own open question (« la mesure repose sur
# Win32_OperatingSystem.FreeVirtualMemory, dont la sémantique mériterait
# d'être confirmée par une seconde source »): FreeVirtualMemory must track
# CommitLimit - CommittedBytes. Tolerance 2% of the limit because the two CIM
# reads land a few ms apart on a live machine.

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\..\diagnostic\log-commit-charge.ps1'
    $onWindows = ($env:OS -eq 'Windows_NT')

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $scriptPath).Path, [ref]$tokens, [ref]$parseErrors)
    $scriptText = Get-Content -Raw -Path $scriptPath
}

Describe 'log-commit-charge.ps1 — static contract (all platforms)' {
    It 'parses without error' {
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'exposes OutputDir / IntervalSec / DurationSec parameters' {
        $paramNames = $ast.ParamBlock.Parameters.Name.VariablePath.UserPath
        $paramNames | Should -Contain 'OutputDir'
        $paramNames | Should -Contain 'IntervalSec'
        $paramNames | Should -Contain 'DurationSec'
    }

    It 'rejects non-positive intervals (param guard present in the body)' {
        $scriptText | Should -Match 'IntervalSec must be >= 1'
        $scriptText | Should -Match 'DurationSec must be >= 0'
    }

    It 'is locale-proof: reads commit counters via CIM, never Get-Counter' {
        # English counter NAMES through Get-Counter are the archived original's
        # defect (empty catch on FR locale): forbid the whole mechanism.
        $scriptText | Should -Not -Match 'Get-Counter'
        $scriptText | Should -Match 'Win32_PerfFormattedData_PerfOS_Memory'
        $scriptText | Should -Match 'CommittedBytes'
        $scriptText | Should -Match 'CommitLimit'
    }

    It 'logs the cross-check sources next to the commit counters' {
        # FreeVirtualMemory (the original issue measurement) and the pagefile
        # size (ai-01 proved the CommitLimit follows it) must land in the same
        # sample so each line self-validates.
        $scriptText | Should -Match 'Win32_OperatingSystem'
        $scriptText | Should -Match 'FreeVirtualMemory'
        $scriptText | Should -Match 'Win32_PageFileUsage'
    }

    It 'writes the summary from a finally block (Ctrl+C-safe)' {
        $scriptText | Should -Match 'finally'
        $scriptText | Should -Match '_summary\.json'
    }
}

Describe 'log-commit-charge.ps1 — live micro-run (Windows only)' {
    BeforeAll {
        if ($onWindows) {
            $runDir = Join-Path ([System.IO.Path]::GetTempPath()) (
                "lcc-test-" + [System.Guid]::NewGuid().ToString('N'))
            # Absolute path (Resolve-Path): a `..`-segmented path passed through
            # powershell.exe -File is fragile across hosts — resolve it here.
            $childLog = Join-Path $runDir 'child.log'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $resolvedScript = (Resolve-Path $scriptPath).Path
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $resolvedScript `
                -OutputDir $runDir -IntervalSec 1 -DurationSec 3 2>&1 |
                ForEach-Object { $_.ToString() } | Set-Content -Path $childLog
            $childExit = $LASTEXITCODE
            $samplesPath = Join-Path $runDir 'samples.jsonl'
            $summaryPath = Join-Path $runDir '_summary.json'
            $lines = if (Test-Path $samplesPath) {
                @(Get-Content -Path $samplesPath | Where-Object { $_ -ne '' })
            } else { @() }
            $samples = @($lines | ForEach-Object { $_ | ConvertFrom-Json })
            $summary = if (Test-Path $summaryPath) {
                Get-Content -Raw -Path $summaryPath | ConvertFrom-Json
            } else { $null }
        }
    }

    AfterAll {
        if ($onWindows -and (Test-Path $runDir)) {
            Remove-Item -Recurse -Force $runDir
        }
    }

    It 'the logger child process itself succeeded (exit 0, non-empty output)' -Skip:($env:OS -ne 'Windows_NT') {
        # Fail loudly if the invocation breaks, so the per-sample Its below can
        # never pass vacuously over zero samples.
        $childExit | Should -Be 0 -Because "logger child must succeed; its output was: $(if ($childLog -and (Test-Path $childLog)) { (Get-Content $childLog) -join ' | ' } else { 'no log' })"
        $samples.Count | Should -BeGreaterThan 0
    }

    It 'produces at least 2 samples in 3 seconds at 1s interval' -Skip:($env:OS -ne 'Windows_NT') {
        $samples.Count | Should -BeGreaterThan 1
    }

    It 'every sample carries the required keys' -Skip:($env:OS -ne 'Windows_NT') {
        $samples.Count | Should -BeGreaterThan 0
        $required = @('t', 'CommittedBytes', 'CommitLimitBytes', 'FreeVirtualMemoryBytes',
                      'PagefileAllocatedBytes', 'SumProcessCommitBytes', 'UnattributedBytes')
        foreach ($s in $samples) {
            foreach ($k in $required) {
                $s.PSObject.Properties.Name | Should -Contain $k
            }
        }
    }

    It 'committed never exceeds the limit' -Skip:($env:OS -ne 'Windows_NT') {
        foreach ($s in $samples) {
            $s.CommittedBytes | Should -BeLessThan ($s.CommitLimitBytes + 1)
        }
    }

    It 'FreeVirtualMemory tracks CommitLimit - CommittedBytes (semantic cross-check, 2% tolerance)' -Skip:($env:OS -ne 'Windows_NT') {
        foreach ($s in $samples) {
            $expected = $s.CommitLimitBytes - $s.CommittedBytes
            $diff = [Math]::Abs($s.FreeVirtualMemoryBytes - $expected)
            $diff | Should -BeLessThan ([Math]::Abs($s.CommitLimitBytes) * 0.02 + 1)
        }
    }

    It 'unattributed commit is non-negative (commit >= processes + pools)' -Skip:($env:OS -ne 'Windows_NT') {
        foreach ($s in $samples) {
            $s.UnattributedBytes | Should -BeGreaterThan -1
        }
    }

    It 'writes _summary.json with the sample count' -Skip:($env:OS -ne 'Windows_NT') {
        $summary | Should -Not -BeNullOrEmpty
        $summary.samples | Should -BeGreaterThan 1
        $summary.peakCommitted | Should -BeGreaterThan 0
    }
}
