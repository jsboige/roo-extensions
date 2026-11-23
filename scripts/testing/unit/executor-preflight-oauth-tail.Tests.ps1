<#
.SYNOPSIS
    Guards the bounded tail scan used by the executor pre-flight OAuth probe.

.DESCRIPTION
    The pre-flight used to stream every recent JSONL trace end to end for the
    OAuth expiry marker (#3169). Measured po-2028, 2026-11-23: 47 traces /
    5.87 GiB pushed the whole pre-flight to ~35-40 min for a warning that never
    blocks the cycle. The helper reads a bounded tail instead.

    These tests are behavioural, not textual: they dot-source the helper and
    build real files, so the trade is pinned where it lives -- the marker in the
    tail is found, the marker outside the bound is not, and
    EXECUTOR_PREFLIGHT_OAUTH_FULL_SCAN=1 keeps a way back to the full scan.
#>

Describe 'Executor pre-flight OAuth tail scan (bounded read)' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\..\..\scripts\common\jsonl-tail-scan.ps1')

        # Line shapes taken from real web1 traces (session 1356264f, 2026-08-26).
        $realErrorLine = '{"type":"assistant","message":{"id":"d556768b","role":"assistant","content":[{"type":"text","text":"Failed to authenticate: OAuth session expired and could not be refreshed"}]},"isApiErrorMessage":true,"userType":"external","timestamp":"2026-08-26T15:19:25.075Z"}'
        $citationLine = '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"[web1] grep OAuth session expired sur tous les *.jsonl"}]},"timestamp":"2026-08-27T04:20:52Z"}'
        $pattern = 'OAuth session expired.*isApiErrorMessage":true|isApiErrorMessage":true.*OAuth session expired'

        function New-FillerLines {
            param([int]$Count)
            $sb = New-Object System.Text.StringBuilder
            for ($i = 0; $i -lt $Count; $i++) {
                [void]$sb.Append('{"type":"filler","message":{"role":"user","content":"padding line ' + $i + ' for the tail bound"}}')
                [void]$sb.Append("`n")
            }
            return $sb.ToString()
        }
    }

    It 'finds the marker in a small trace' {
        $path = Join-Path $TestDrive 'small-hit.jsonl'
        Set-Content -LiteralPath $path -Value ((New-FillerLines -Count 3) + $realErrorLine) -Encoding UTF8
        Test-JsonlTailForPattern -Path $path -Pattern $pattern | Should -BeTrue
    }

    It 'does not match a quoted citation in a small trace' {
        $path = Join-Path $TestDrive 'small-citation.jsonl'
        Set-Content -LiteralPath $path -Value ((New-FillerLines -Count 3) + $citationLine) -Encoding UTF8
        Test-JsonlTailForPattern -Path $path -Pattern $pattern | Should -BeFalse
    }

    It 'finds a marker near the end of a trace larger than the tail bound' {
        $path = Join-Path $TestDrive 'big-tail-hit.jsonl'
        [System.IO.File]::WriteAllText($path, (New-FillerLines -Count 4000) + $realErrorLine)
        (Get-Item $path).Length | Should -BeGreaterThan 65536
        Test-JsonlTailForPattern -Path $path -Pattern $pattern -MaxBytes 65536 | Should -BeTrue
    }

    It 'does not read past the bound: a marker only at the head is out of scope, and MaxBytes 0 restores the full scan' {
        $path = Join-Path $TestDrive 'big-head-hit.jsonl'
        [System.IO.File]::WriteAllText($path, $realErrorLine + "`n" + (New-FillerLines -Count 4000))
        Test-JsonlTailForPattern -Path $path -Pattern $pattern -MaxBytes 65536 | Should -BeFalse
        Test-JsonlTailForPattern -Path $path -Pattern $pattern -MaxBytes 0 | Should -BeTrue
    }

    It 'drops the line cut at the tail boundary instead of reading half a marker' {
        $marker = '{"isApiErrorMessage":true,"text":"OAuth session expired"}' + "`n"
        $path = Join-Path $TestDrive 'boundary.jsonl'
        [System.IO.File]::WriteAllText($path, (New-FillerLines -Count 2000) + $marker)

        # Tail starts 10 bytes into the marker line, cutting off the leading
        # `isApiErrorMessage` field: the fragment is not evidence, and reading it
        # must not manufacture a verdict either way.
        Test-JsonlTailForPattern -Path $path -Pattern $pattern -MaxBytes ($marker.Length - 10) | Should -BeFalse
        Test-JsonlTailForPattern -Path $path -Pattern $pattern -MaxBytes $marker.Length | Should -BeTrue
    }

    It 'returns false instead of throwing when a trace disappears between enumeration and read' {
        # The probe is a non-blocking advisory inside the executor pre-flight:
        # a session rotating away mid-scan must not turn into a stopped cycle.
        $path = Join-Path $TestDrive 'gone.jsonl'
        { Test-JsonlTailForPattern -Path $path -Pattern $pattern } | Should -Not -Throw
        Test-JsonlTailForPattern -Path $path -Pattern $pattern | Should -BeFalse
    }

    It 'parses the pre-flight and wires the bounded helper into the OAuth probe' {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw

        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0

        $preflight | Should -Match ([regex]::Escape(". (Join-Path `$PSScriptRoot '..\common\jsonl-tail-scan.ps1')"))
        $preflight | Should -Match 'Test-JsonlTailForPattern'
        $preflight | Should -Match 'EXECUTOR_PREFLIGHT_OAUTH_FULL_SCAN'
        # Regression guard: the unbounded whole-file read must not come back.
        $preflight | Should -Not -Match ([regex]::Escape('Select-String -Path $session.FullName'))
    }
}
