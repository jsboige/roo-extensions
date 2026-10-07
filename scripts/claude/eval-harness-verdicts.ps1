<#
.SYNOPSIS
    Verdict classification for the SDDD eval-harness log (Epic #2609 V1 cadence).

.DESCRIPTION
    Pure functions (no I/O) so the classifier can be unit-tested against synthetic logs.

    WHY THIS EXISTS -- measured 2026-10-08 on ai-01. When the storm guard fires, every eval
    test short-circuits with a GREEN assertion (`expect(active).toBe(true); return`), so
    vitest prints a check mark for a scenario that measured NOTHING. Classifying on the
    check mark alone turned a fully storm-guarded run -- embedding backend down, zero
    queries issued -- into "7 PASS / 0 FAIL" with exit 0. That is the exact false-green this
    Epic exists to kill (#637: 68 green tests with Postgres OFF). The `[INCONCLUSIVE]`
    marker is the only in-log witness of the no-measurement state, and the
    `stdout | tests/eval-harness/tools/<file> > ...` header above it names the file.

    ASCII-only on purpose: PowerShell 5.1 decodes a BOM-less .ps1 as cp1252, so a literal
    check mark in the source would not match the UTF-8 log line it is meant to find. The
    marker is built from its code point instead.

    Dot-source from the wrapper:
        . "$PSScriptRoot\eval-harness-verdicts.ps1"
#>

function Get-EvalHarnessScenarioResults {
    <#
    .SYNOPSIS
        Classify every scenario of an eval-harness run from the kept vitest log.

    .DESCRIPTION
        Precedence per scenario: INCONCLUSIVE (storm-guarded, measured nothing) > FAIL >
        PASS > MISSING. INCONCLUSIVE must win over PASS: a storm-guarded test is green in
        vitest, so without this precedence a run that issued no query reads as a pass.

    .PARAMETER LogLines
        The ANSI-stripped log lines, in order. Blank lines are legitimate content (vitest
        separates blocks with them), so both AllowEmptyString and AllowEmptyCollection are
        required — without them PowerShell rejects the whole array on its first '' element.

    .PARAMETER ScenarioMap
        Ordered dictionary: '<file>.eval.test.ts' -> @{ label = '...'; tool = '...' }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][string[]]$LogLines,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ScenarioMap
    )

    $passMarker = [string][char]0x2713

    # ---- Pass 1: attribute each storm-guard marker to the file named by the nearest
    # preceding vitest stream header. Attribution matters: a run-level "some scenario was
    # inconclusive" would mislabel every healthy scenario as unmeasured.
    $inconclusiveByFile = @{}
    $ctxFile = $null
    foreach ($ln in $LogLines) {
        if ($ln -match '^(?:stdout|stderr) \|\s*tests/eval-harness/tools/([^\s>]+)') {
            $ctxFile = $Matches[1]
        }
        elseif ($null -ne $ctxFile -and $ln -match '^\[INCONCLUSIVE\]\s*(.*)$') {
            if (-not $inconclusiveByFile.ContainsKey($ctxFile)) {
                $inconclusiveByFile[$ctxFile] = $Matches[1].Trim()
            }
        }
    }

    # ---- Pass 2: classify each scenario.
    $scenarios = @()
    foreach ($kv in $ScenarioMap.GetEnumerator()) {
        $file = $kv.Key
        $meta = $kv.Value
        $verdict = 'MISSING'
        $detail = $null

        if ($inconclusiveByFile.ContainsKey($file)) {
            $verdict = 'INCONCLUSIVE'
            $detail = $inconclusiveByFile[$file]
        }
        else {
            $escaped = [regex]::Escape($file)
            foreach ($ln in $LogLines) {
                if ($ln -match "^\s*FAIL\s+tests/eval-harness/tools/$escaped(\s|$)") { $verdict = 'FAIL'; break }
                if ($ln -match "^\s*$passMarker\s+tests/eval-harness/tools/$escaped(\s|$)") { $verdict = 'PASS'; break }
            }
        }

        $scenarios += [pscustomobject]@{
            File    = $file
            Label   = $meta.label
            Tool    = $meta.tool
            Verdict = $verdict
            Detail  = $detail
        }
    }

    [pscustomobject]@{
        Scenarios         = $scenarios
        PassCount         = @($scenarios | Where-Object { $_.Verdict -eq 'PASS' }).Count
        FailCount         = @($scenarios | Where-Object { $_.Verdict -eq 'FAIL' }).Count
        InconclusiveCount = @($scenarios | Where-Object { $_.Verdict -eq 'INCONCLUSIVE' }).Count
        MissingCount      = @($scenarios | Where-Object { $_.Verdict -eq 'MISSING' }).Count
    }
}

function Test-EvalHarnessRunSuccess {
    <#
    .SYNOPSIS
        The wrapper's exit policy: is this run a success?

    .DESCRIPTION
        A run that measured nothing is not a success, even though every scenario is green:
        if no scenario PASSed and at least one is INCONCLUSIVE, the engines were never
        queried. A PARTIAL storm stays a success -- the storm guard exists precisely to
        avoid spurious reds while the index is being built.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$PassCount,
        [Parameter(Mandatory)][int]$FailCount,
        [Parameter(Mandatory)][int]$InconclusiveCount,
        [Parameter(Mandatory)][int]$MissingCount,
        [switch]$TimedOut
    )

    if ($TimedOut) { return $false }
    if ($FailCount -gt 0 -or $MissingCount -gt 0) { return $false }
    if ($PassCount -eq 0 -and $InconclusiveCount -gt 0) { return $false }
    return $true
}
