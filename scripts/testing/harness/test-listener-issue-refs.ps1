<#
.SYNOPSIS
    Static harness for the listener's issue-reference extractor (R11 filter).
.DESCRIPTION
    dashboard-listener.ps1 skips any WAKE whose instruction line references a
    CLOSED GitHub issue -- and when every actionable message is skipped it also
    advances lastAck, so a wrongly-skipped message is never retried. A false
    positive therefore DESTROYS an instruction. That makes the extraction
    pattern a guard worth testing, not a detail.

    It failed on 2026-08-16. The pattern was '#(\d+)' with no left boundary, so
    "AC#4" -- ordinary acceptance-criterion notation -- was read as issue #4.
    Issue #4 is closed and unrelated, and a real WAKE addressed to ai-01 was
    dropped:

      [WARN] Skipping message from myia-po-2023: references CLOSED issue(s) #4.
      [INFO] All actionable messages reference closed issues. Advancing lastAck.

    HOW THIS TESTS THE REAL THING
    Test-ReferencedClosedIssues cannot be dot-sourced: dashboard-listener.ps1
    runs its polling loop on load. So this harness reads the production file,
    EXTRACTS the regex literal out of that function, and then EXERCISES it
    against a table of strings. It is not a text-presence check -- restoring
    '#(\d+)' makes the extracted pattern fail the AC#4 cases below.

    Placed in scripts/testing/harness/ rather than scripts/testing/unit/, where
    eleven Pester files execute nowhere in CI. Wired into the scheduling-harness
    job, and scripts/dashboard-scheduler/** is in ci.yml's push paths so a change
    landing on main re-runs this guard.
#>

$ErrorActionPreference = 'Stop'
$listener = Join-Path $PSScriptRoot '..\..\dashboard-scheduler\dashboard-listener.ps1'

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

# ============================================================================
# Extraction: pull the live pattern out of Test-ReferencedClosedIssues.
# Line-scoped on purpose -- a multiline regex over the whole file would happily
# match a '#(\d+)' literal sitting in some other function, or in a comment.
# ============================================================================
Write-Host "=== Extracting the production pattern ===" -ForegroundColor Cyan

if (-not (Test-Path $listener)) {
    Write-Host "  FAIL: listener not found at $listener" -ForegroundColor Red
    exit 1
}

$lines = [System.IO.File]::ReadAllLines((Resolve-Path $listener))
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^function\s+Test-ReferencedClosedIssues\b') { $start = $i; break }
}
if ($start -lt 0) {
    Write-Host "  FAIL: function Test-ReferencedClosedIssues not found -- renamed? This harness must be updated with it." -ForegroundColor Red
    exit 1
}

$pattern = $null
for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($i -gt $start -and $lines[$i] -match '^\}') { break }   # end of function body
    if ($lines[$i] -match "\[regex\]::Matches\([^,]+,\s*'([^']+)'\s*\)") { $pattern = $Matches[1]; break }
}
if ([string]::IsNullOrEmpty($pattern)) {
    Write-Host "  FAIL: no [regex]::Matches(...) literal inside Test-ReferencedClosedIssues." -ForegroundColor Red
    Write-Host "        The extractor found the function but not the pattern -- silence here would be a green" -ForegroundColor Red
    Write-Host "        harness testing nothing, so this is a hard failure." -ForegroundColor Red
    exit 1
}
Write-Host "  Extracted: $pattern"

function Get-Refs([string]$text) {
    return @([regex]::Matches($text, $pattern) | ForEach-Object { $_.Groups[1].Value })
}

# ============================================================================
# Test 1: tokens ending in #N are NOT issue references
# The whole reason this file exists.
# ============================================================================
Write-Host "`n=== Test 1: suffix notation must not be read as a reference ===" -ForegroundColor Cyan

$mustNotMatch = @(
    @{ Name = 'AC#4 (the 2026-08-16 defect)'; Text = 'AC#4' },
    @{ Name = 'AC#1-3 range';                 Text = 'AC#1-3 remain satisfied' },
    @{ Name = 'PR#3083 (deliberate under-match)'; Text = 'see PR#3083' },
    @{ Name = 'version suffix v#2';           Text = 'schema v#2' },
    @{ Name = 'underscore-joined ref_#9';     Text = 'ref_#9' }
)
foreach ($c in $mustNotMatch) {
    Assert-Equal $c.Name 0 (Get-Refs $c.Text).Count
}

# ============================================================================
# Test 2: genuine references are still found
# A guard that under-matches everything would pass Test 1 and be useless.
# ============================================================================
Write-Host "`n=== Test 2: real references must still be extracted ===" -ForegroundColor Cyan

Assert-Equal 'bare ref at start of string'   '1357' ((Get-Refs '#1357 needs work') -join ',')
Assert-Equal 'ref after whitespace'          '1357' ((Get-Refs 'traiter #1357') -join ',')
Assert-Equal 'ref in parentheses'            '974'  ((Get-Refs 'fixed (#974)') -join ',')
Assert-Equal 'ref after newline'             '3131' ((Get-Refs "line one`n#3131") -join ',')
Assert-Equal 'two refs in one line'          '1496,2431' ((Get-Refs 'traiter #1496 et #2431') -join ',')
Assert-Equal 'markdown heading is not a ref' 0 (Get-Refs '## [WAKE-CLAUDE] myia-ai-01').Count

# ============================================================================
# Test 3: the exact WAKE line that was destroyed
# Kept ASCII-only (the live line had accents) so CI encoding cannot soften it.
# ============================================================================
Write-Host "`n=== Test 3: the message the listener actually dropped ===" -ForegroundColor Cyan

$droppedWake = '## [WAKE-CLAUDE] myia-ai-01 - #1357 AC#4 : probe E2E (~5 min) a executer sur TOI (bearer host)'
Assert-Equal 'only #1357 is a reference' '1357' ((Get-Refs $droppedWake) -join ',')

# ============================================================================
# Test 4: the mutation bit
# c.226 lesson: a counter-check that cannot fail proves nothing. Assert the OLD
# pattern really does mis-extract, otherwise Tests 1 and 3 would pass even
# against a listener that had never been fixed.
# ============================================================================
Write-Host "`n=== Test 4: discrimination (the naive pattern must fail these) ===" -ForegroundColor Cyan

$naive = '#(\d+)'
Assert-Equal 'naive pattern differs from production' $true ($naive -ne $pattern)
$naiveRefs = @([regex]::Matches($droppedWake, $naive) | ForEach-Object { $_.Groups[1].Value })
Assert-Equal 'naive pattern extracts the phantom #4' '1357,4' ($naiveRefs -join ',')

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
