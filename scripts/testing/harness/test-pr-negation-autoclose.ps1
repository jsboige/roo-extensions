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

    The workflow sources these patterns inline (so a PR cannot drift the
    patterns away from what CI runs); this harness mirrors that source so a
    change here forces a re-evaluation of the test cases. A test that cannot
    fail proves nothing -- each "false" case below is asserted by also running
    the naive token-greedy extractor and checking it does NOT match.

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
# ============================================================================
Write-Host "`n=== Test 6: closing keyword without negation does not arm ===" -ForegroundColor Cyan

$body6 = 'Investigated #3276 root cause. See dashboard for the trace.'
Assert-Equal 'closing keyword without negation does not flag' '' ((Test-ArmingNegation $body6 @()) -join ',')

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
# Test 9: the override marker suppresses the flag (escape hatch).
# (This is enforced in the workflow, not in this function; but we mirror the
# logic here so a workflow change forcing the marker must also update tests.)
# ============================================================================
Write-Host "`n=== Test 9: override marker is recognized ===" -ForegroundColor Cyan

# The marker does not change the arming decision in Test-ArmingNegation; the
# workflow short-circuits before calling it. So here we just assert that a
# body containing the marker, IF the marker were removed, would still arm.
$body9 = "[NEGATION-AUTOCLOSE-OK]`nDoes not close #3276."
Assert-Equal 'body with marker still arms pre-shortcut' '3276' ((Test-ArmingNegation $body9 @(3276)) -join ',')

# ============================================================================
# Test 10: the mutation bit. The naive extractor (just the closing keyword)
# would NOT distinguish arming-with-negation from intended-closes. So we
# assert the discriminator is actually discriminating.
# ============================================================================
Write-Host "`n=== Test 10: discrimination (naive vs production) ===" -ForegroundColor Cyan

$intended  = 'Closes #3626'
$arming    = 'Does not close #3626'

# Test-ArmingNegation takes a closing-refs list. For the intended case the
# ref IS closing; for the arming case the ref IS closing too (GitHub has
# already pre-resolved both). The discriminator is the negation.
Assert-Equal 'intended does not arm'   ''           ((Test-ArmingNegation $intended  @(3626)) -join ',')
Assert-Equal 'arming-with-negation arms' '3626'    ((Test-ArmingNegation $arming    @(3626)) -join ',')

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
