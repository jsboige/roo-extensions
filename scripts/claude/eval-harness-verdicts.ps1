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

    SECOND false-green, measured 2026-10-24: a scenario whose rubric FAILED still prints the
    vitest pass marker, because the golden eval tests assert presence only while computing
    their exploitability checks into `[<tool>] verdict=...`. The kept log said
    `[codebase_search] verdict=FAIL` (snippet 54 chars < 80) four days straight while every
    summary read PASS. The per-file tool verdict line is therefore read too, and a FAIL is
    never downgraded by the marker.

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

    # ---- Pass 1: attribute each in-test marker to the file named by the nearest
    # preceding vitest stream header. Attribution matters: a run-level "some scenario was
    # inconclusive" would mislabel every healthy scenario as unmeasured.
    #
    # Three marker shapes are read, all under that header:
    #   [INCONCLUSIVE] ...                       (storm guard short-circuit)
    #   [<tool>] verdict=PASS|FAIL latency=..    (the test's own rubric verdict)
    #   [<tool>] INCONCLUSIVE: ...               (test-declared environment state)
    #
    # WHY the tool verdict line matters (measured 2026-10-24 on ai-01): the eval tests
    # COMPUTE their rubric checks and log `verdict=FAIL`, but only assert presence
    # (no-throw, status=success, results>0). Vitest therefore prints the pass marker for a
    # scenario whose exploitability rubric failed -- and a classifier reading the marker
    # alone published "7 PASS / 0 FAIL" while the kept log said
    # `[codebase_search] verdict=FAIL` four days straight (snippet 54 chars < 80), and
    # `[conversation_browser] verdict=FAIL` (0 conversations). That is the same false-green
    # class as the storm guard this module already guards (#637: green tests, engine OFF).
    $inconclusiveByFile = @{}
    $toolVerdictByFile = @{}
    $ctxFile = $null
    foreach ($ln in $LogLines) {
        if ($ln -match '^(?:stdout|stderr) \|\s*tests/eval-harness/tools/([^\s>]+)') {
            $ctxFile = $Matches[1]
        }
        elseif ($null -eq $ctxFile) {
            continue
        }
        elseif ($ln -match '^\[INCONCLUSIVE\]\s*(.*)$') {
            if (-not $inconclusiveByFile.ContainsKey($ctxFile)) {
                $inconclusiveByFile[$ctxFile] = $Matches[1].Trim()
            }
        }
        elseif ($ln -match '^\[[^\]]+\]\s+(?:target=\S+ \(\d+ msgs\) )?verdict=(PASS|FAIL|INCONCLUSIVE)\b') {
            # Precedence inside the file: a FAIL is never downgraded by a later PASS.
            $v = $Matches[1]
            if ($v -eq 'INCONCLUSIVE') {
                if (-not $inconclusiveByFile.ContainsKey($ctxFile)) { $inconclusiveByFile[$ctxFile] = 'tool reported INCONCLUSIVE' }
            }
            elseif ($v -eq 'FAIL' -or -not $toolVerdictByFile.ContainsKey($ctxFile)) {
                $toolVerdictByFile[$ctxFile] = $v
            }
        }
        elseif ($ln -match '^\[[^\]]+\]\s+INCONCLUSIVE:\s*(.*)$') {
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
            # The tool's own rubric verdict is authoritative when it is stricter than the
            # vitest marker (a green test that logged verdict=FAIL is a result failure, not
            # a pass), and supplies the verdict when the marker is absent.
            if ($toolVerdictByFile.ContainsKey($file)) {
                $tv = $toolVerdictByFile[$file]
                if ($tv -eq 'FAIL' -or $verdict -eq 'MISSING') { $verdict = $tv }
                if ($tv -eq 'FAIL') { $detail = 'tool rubric verdict=FAIL (see the [FAIL] checks in the log)' }
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
