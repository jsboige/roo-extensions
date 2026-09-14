<#
.SYNOPSIS
    Static harness for the PR negation auto-close guard (#3626).
.DESCRIPTION
    GitHub's auto-close parser is token-based: it matches a closing keyword
    (close, closes, closed, fix, fixes, fixed, resolve, resolves, resolved)
    followed by '#N'. A negation keyword adjacent to that pairing does NOT
    disarm the auto-close -- per the official docs (verbatim):

      "A negation keyword is not supported for closing issues. The keyword
       'not' cannot be used ... to negate a closing keyword. For example,
       'Closes NOT #...' will still close the issue."

    This harness exercises the same logic that the workflow at
    .github/workflows/pr-negation-autoclose.yml applies: scan a window of 200
    chars around each `#NNNN` for the co-occurrence of a negation pattern and
    a closing keyword. If both are present, the pair is flagged.

    It also mirrors the workflow's override-marker semantics: the marker
    [NEGATION-AUTOCLOSE-OK] disarms the guard ONLY when it sits alone on its
    own line of the body (code spans stripped first). An inline citation --
    which is what any body documenting the escape hatch produces -- must NOT
    disarm it.

    The workflow sources these patterns inline (so a PR cannot drift the
    patterns away from what CI runs); this harness mirrors that source so a
    change here forces a re-evaluation of the test cases. A test that cannot
    fail proves nothing: every "does not flag" case below passes a non-empty
    closing-refs list so the reference loop actually runs (an empty list
    short-circuits to a no-op -- the vacuous-test defect an earlier cut of
    this file shipped with).

    Finally, the harness compiles the workflow's embedded github-script block
    with node (AsyncFunction -- the same constructor actions/github-script
    uses). The workflow's first cut shipped a SyntaxError nobody caught
    because nothing compiled the block; this guard is red on that class.

    Placed in scripts/testing/harness/ alongside the other static guards
    (test-listener-issue-refs.ps1, test-schtask-result-filter.ps1, ...). Wired
    into the scheduling-harness job so a change landing on main re-runs it.
#>

$ErrorActionPreference = 'Stop'

# Mirror the patterns in .github/workflows/pr-negation-autoclose.yml.
# If you change one, change the other.
$negationPatterns = @(
    '\bnot\b',
    '\bno\s+longer\b',
    '\bdoes\s+not\b',
    '\bdo\s+not\b',
    "\bdoesn'?t\b",
    "\bdon'?t\b",
    '\bstays?\s+open\b',
    '\bremains?\s+open\b',
    '\b(study|draft|proposal|investigation)\s+is\s+the\s+deliverable\b'
)
$closingKeywords = @(
    '\bclose[sd]?\b',
    '\bfix(?:e[sd])?\b',
    '\bresolv(?:e[sd])?\b'
)

# === Reference pattern: #NNNN, 4-digit floor (both live repos number in 4+).
$refRe = '#(\d{4,})\b'

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ($Expected -eq $Actual) {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# Strip fenced code blocks and inline code (the GitHub parser also ignores
# those). Mirrors the workflow logic so the test is in lockstep.
function Remove-CodeSpans([string]$s) {
    $s = [regex]::Replace($s, '```[\s\S]*?```', '')
    $s = [regex]::Replace($s, '`[^`\n]*`', '')
    return $s
}

function Test-ArmingNegation {
    param([string]$Body, [int[]]$ClosingRefs)
    $hits = @()
    foreach ($m in [regex]::Matches($Body, $refRe)) {
        $n = [int]$m.Groups[1].Value
        if (-not $ClosingRefs -or ($ClosingRefs -notcontains $n)) { continue }
        $start = [Math]::Max(0, $m.Index - 200)
        $end   = [Math]::Min($Body.Length, $m.Index + $m.Length + 200)
        $window = Remove-CodeSpans $Body.Substring($start, $end - $start)
        $hasNeg  = $false
        foreach ($p in $negationPatterns) { if ($window -match $p) { $hasNeg  = $true; break } }
        $hasClos = $false
        foreach ($p in $closingKeywords) { if ($window -match $p) { $hasClos = $true; break } }
        if ($hasNeg -and $hasClos) { $hits += $n }
    }
    return $hits
}

# Mirror of the workflow's override-marker check: the marker counts ONLY when
# alone on its own line, after code spans are stripped. An inline citation
# (prose or code) must return $false -- the self-bypass regression this
# guard exists for.
function Test-MarkerOverride {
    param([string]$Body)
    $s = Remove-CodeSpans $Body
    return [regex]::IsMatch($s, '(?m)^\s*\[NEGATION-AUTOCLOSE-OK\]\s*$')
}

# ============================================================================
# Test 1: the original defect -- "Does not close #NNNN" arms auto-close.
# Pre-fix behavior: GitHub would close #3276 at merge.
# ============================================================================
Write-Host "=== Test 1: negation prose ARMS the auto-close ===" -ForegroundColor Cyan

$body1 = @'
## Summary

Some fix here.

## Scope

Instrumentation only. Does not close #3276 - the runtime root cause stays open; this is a robustness fix in the detector that exists to measure it.

Refs #3276
'@
$hits1 = Test-ArmingNegation $body1 @(3276)
Assert-Equal 'negation prose arms the auto-close (3276 in hits)' $true ($hits1 -contains 3276)

# ============================================================================
# Test 2: the previous production precedent (#3232 / #3156).
# ============================================================================
Write-Host "`n=== Test 2: 'Does NOT close' (study deliverable phrasing) ===" -ForegroundColor Cyan

$body2 = 'Does NOT close #3156 - the study is the deliverable; implementation decision remains with the user.'
Assert-Equal 'study-deliverable phrasing arms #3156' '3156' ((Test-ArmingNegation $body2 @(3156)) -join ',')

# ============================================================================
# Test 3: a clean Closes (no negation) does NOT arm -- it is the intended use.
# ============================================================================
Write-Host "`n=== Test 3: intended Closes is not a false positive ===" -ForegroundColor Cyan

$body3 = @'
## Summary
Real fix.
Closes #3626
'@
Assert-Equal 'intended Closes does not flag' '' ((Test-ArmingNegation $body3 @(3626)) -join ',')

# ============================================================================
# Test 4: Refs alone does not arm.
# ============================================================================
Write-Host "`n=== Test 4: Refs without Closes does not arm ===" -ForegroundColor Cyan

$body4 = 'Instrumentation only. Refs #3276.'
Assert-Equal 'Refs alone does not flag' '' ((Test-ArmingNegation $body4 @(3276)) -join ',')

# ============================================================================
# Test 5: negation keyword without closing keyword does not arm.
# ============================================================================
Write-Host "`n=== Test 5: negation without closing keyword does not arm ===" -ForegroundColor Cyan

$body5 = 'We did not touch #3276 in this change.'
Assert-Equal 'negation without closing keyword does not flag' '' ((Test-ArmingNegation $body5 @(3276)) -join ',')

# ============================================================================
# Test 6: closing keyword without negation does not arm (counter-direction).
# The closing-refs list MUST be non-empty: with @() the guard
# `if (-not $ClosingRefs ...) { continue }` skips every reference and the
# assertion passes against a no-op (the vacuous form this test shipped with).
# ============================================================================
Write-Host "`n=== Test 6: closing keyword without negation does not arm ===" -ForegroundColor Cyan

$body6 = 'Fixes #3276 in a companion PR, intended closure.'
Assert-Equal 'closing keyword without negation does not flag' '' ((Test-ArmingNegation $body6 @(3276)) -join ',')

# ============================================================================
# Test 7: code spans are excluded (the GitHub parser also ignores them).
# A negation inside a code block must not arm.
# ============================================================================
Write-Host "`n=== Test 7: negation inside code spans is excluded ===" -ForegroundColor Cyan

$body7 = @'
Documentation note: `Does not close #3276` -- pattern reference only.
'@
Assert-Equal 'inline code span excludes negation' '' ((Test-ArmingNegation $body7 @(3276)) -join ',')

$body7b = @'
```text
Does not close #3276
```
'@
Assert-Equal 'fenced code block excludes negation' '' ((Test-ArmingNegation $body7b @(3276)) -join ',')

# ============================================================================
# Test 8: window boundary. Negation > 200 chars away must not arm.
# The actual defect places the negation on the same line, but the window has
# to be wide enough to catch typical author prose.
# ============================================================================
Write-Host "`n=== Test 8: window boundary ===" -ForegroundColor Cyan

# Negation 250 chars before the ref. With a 200-char window it MUST NOT match.
$pad = 'x' * 250
$body8 = "Does not close. $pad #3276"
Assert-Equal 'negation beyond window does not arm' '' ((Test-ArmingNegation $body8 @(3276)) -join ',')

# Negation 50 chars before the ref. With a 200-char window it MUST match.
$body8b = "Does not close. $($pad.Substring(0,150)) #3276"
Assert-Equal 'negation within window arms' '3276' ((Test-ArmingNegation $body8b @(3276)) -join ',')

# ============================================================================
# Test 9: the override marker (escape hatch). Two halves:
#   9a. The marker does not change the arming decision in Test-ArmingNegation
#       (the workflow short-circuits before that function).
#   9b. The override semantics themselves: the marker disarms ONLY when alone
#       on its own line. An inline citation -- prose or code, exactly what a
#       body documenting the escape hatch produces -- must NOT disarm. This
#       is the self-bypass regression: the guard's introducing PR cited the
#       marker three times inline while a raw substring check would have
#       swallowed all three.
# ============================================================================
Write-Host "`n=== Test 9: override marker is recognized ===" -ForegroundColor Cyan

# 9a: a body containing the marker would still arm if the marker were removed.
$body9 = "[NEGATION-AUTOCLOSE-OK]`nDoes not close #3276."
Assert-Equal 'body with marker still arms pre-shortcut' '3276' ((Test-ArmingNegation $body9 @(3276)) -join ',')

# 9b: the override discriminator. Here-strings (single-quoted) keep the
# backticks literal -- in a double-quoted PS string they are escape chars and
# would silently vanish from the fixture.
$body9b = @'
Some prose.
[NEGATION-AUTOCLOSE-OK]
Does not close #3276.
'@
Assert-Equal 'marker alone on its own line overrides' $true (Test-MarkerOverride $body9b)

$body9c = @'
The marker [NEGATION-AUTOCLOSE-OK] cited inline mid-sentence, as prose documentation does.
'@
Assert-Equal 'marker cited inline in prose does NOT override' $false (Test-MarkerOverride $body9c)

$body9d = @'
The override marker `[NEGATION-AUTOCLOSE-OK]` is documented inside code spans.
'@
Assert-Equal 'marker inside an inline code span does NOT override' $false (Test-MarkerOverride $body9d)

$body9e = @'
Example fence:
```
[NEGATION-AUTOCLOSE-OK]
```
End.
'@
Assert-Equal 'marker alone inside a fenced block does NOT override' $false (Test-MarkerOverride $body9e)

# ============================================================================
# Test 10: the mutation bit. A keyword-only pass would NOT distinguish
# arming-with-negation from intended-closes. So we assert the discriminator
# is actually discriminating.
# ============================================================================
Write-Host "`n=== Test 10: discrimination (arming vs intended) ===" -ForegroundColor Cyan

$intended  = 'Closes #3626'
$arming    = 'Does not close #3626'

# Test-ArmingNegation takes a closing-refs list. For the intended case the
# ref IS closing; for the arming case the ref IS closing too (GitHub has
# already pre-resolved both). The discriminator is the negation.
Assert-Equal 'intended does not arm'   ''           ((Test-ArmingNegation $intended  @(3626)) -join ',')
Assert-Equal 'arming-with-negation arms' '3626'    ((Test-ArmingNegation $arming    @(3626)) -join ',')

# ============================================================================
# Test 11: compile guard. Extract the github-script block from the workflow
# YAML and compile it with node's AsyncFunction -- the same constructor
# actions/github-script uses. The workflow's first cut shipped a quoting
# SyntaxError that CI never saw because nothing compiled the block; this
# guard is red on that whole defect class.
# ============================================================================
Write-Host "`n=== Test 11: workflow script block compiles (AsyncFunction) ===" -ForegroundColor Cyan

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$wfPath = Join-Path $repoRoot '.github/workflows/pr-negation-autoclose.yml'

$wfLines = Get-Content $wfPath
$scriptIdx = -1
for ($i = 0; $i -lt $wfLines.Count; $i++) {
    if ($wfLines[$i] -match '^\s*script:\s*\|\s*$') { $scriptIdx = $i; break }
}
if ($scriptIdx -lt 0) {
    Write-Host "  FAIL: no 'script: |' block found in $wfPath" -ForegroundColor Red
    $TestsFailed++
} elseif (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "  FAIL: node not found on PATH -- cannot compile-check the workflow script" -ForegroundColor Red
    $TestsFailed++
} else {
    $keyIndent = $wfLines[$scriptIdx].Length - $wfLines[$scriptIdx].TrimStart(' ').Length
    $block = New-Object System.Collections.Generic.List[string]
    for ($i = $scriptIdx + 1; $i -lt $wfLines.Count; $i++) {
        $line = $wfLines[$i]
        if ($line.Trim() -eq '') { $block.Add(''); continue }
        if ($line -notmatch ('^\s{' + ($keyIndent + 1) + '}')) { break }
        $block.Add($line)
    }
    $n = 0
    foreach ($l in $block) { if ($l.Trim() -ne '') { $n = $l.Length - $l.TrimStart(' ').Length; break } }
    $js = ($block | ForEach-Object { $_.Substring([Math]::Min($n, $_.Length)) }) -join "`n"

    # Both the checker and the payload go through temp FILES: PowerShell 5.1
    # mangles embedded double quotes when passing -e payloads to native node
    # (measured: require("fs") arrived as require(fs)), and a path argument
    # survives unchanged on every shell.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $tmpJs = [System.IO.Path]::GetTempFileName()
    $tmpCheck = [System.IO.Path]::GetTempFileName() + '.js'
    [System.IO.File]::WriteAllText($tmpJs, $js, $utf8)
    [System.IO.File]::WriteAllText($tmpCheck,
        "const fs = require('fs');`n" +
        "const s = fs.readFileSync(process.argv[2], 'utf8');`n" +
        "const AF = Object.getPrototypeOf(async function(){}).constructor;`n" +
        "new AF(s);`n" +
        "console.log('COMPILES_OK');`n", $utf8)
    $null = & node $tmpCheck $tmpJs
    Assert-Equal 'workflow github-script block compiles (AsyncFunction)' 0 $LASTEXITCODE
    Remove-Item $tmpJs, $tmpCheck -ErrorAction SilentlyContinue
}

# ============================================================================
# Test 12: the permissions mapping regression (#3636). createComment on a PR
# posts to /issues/N/comments, but the resource behind a PR number is a pull
# request and the server authorizes against pull_requests, not issues. The
# original cut granted issues: write + pull-requests: read: every guidance
# comment died with 403 "Resource not accessible by integration" while the
# runner's setup log displayed "Issues: write" (run 34795588618, reproduced
# on PR #3637). Assert the workflow grants pull-requests: write.
# ============================================================================
Write-Host "`n=== Test 12: permissions grant pull-requests: write (#3636) ===" -ForegroundColor Cyan

$permGrantOk = $false
$inPermissions = $false
foreach ($l in (Get-Content $wfPath)) {
    if ($l -match '^permissions:\s*$') { $inPermissions = $true; continue }
    if ($inPermissions -and $l -match '^[^\s#]') { break }   # next top-level key
    if ($inPermissions -and $l -match '^\s+pull-requests:\s*write') { $permGrantOk = $true; break }
}
Assert-Equal 'workflow grants pull-requests: write' $true $permGrantOk

# ============================================================================
# Test 13: createComment is guarded (#3636). The guidance comment is the
# guard's main path in its nominal usage scenario; an unhandled HttpError
# there kills the run BEFORE core.setFailed, so the author gets a bare 403
# stack trace instead of the remediation. Assert the call sits inside a
# try/catch (raw-text check -- Test 11 already proves the block compiles).
# ============================================================================
Write-Host "`n=== Test 13: createComment wrapped in try/catch (#3636) ===" -ForegroundColor Cyan

$wfRaw = Get-Content $wfPath -Raw
Assert-Equal 'createComment preceded by try and followed by catch' $true `
    ([bool]($wfRaw -match '(?s)try\s*\{[\s\S]{0,2000}createComment[\s\S]{0,2000}\}\s*catch'))

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
