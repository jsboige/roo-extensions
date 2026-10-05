<#
.SYNOPSIS
    Static harness for the mcp-proxy template's TBXark hop timeout (#1357 AC#1).
.DESCRIPTION
    docker/mcp-proxy/config.template.json carries the TBXark upstream hop
    timeout for roo-state-manager as a JSON NUMBER:

        "timeout": 780000000000

    That form is not cosmetic. The deployed TBXark image (2026-02-28) decodes
    the field into a Go time.Duration, i.e. a NUMBER OF NANOSECONDS. A JSON
    STRING instead makes the proxy crash-loop at load:

        json: cannot unmarshal string into Go struct field
        MCPClientConfigV2.mcpServers.timeout of type time.Duration

    #3083 shipped the template with "5m" (a string). It looked harmless and
    was invisible for months -- until the template was copied to a live config
    -- and #3839 fixed it to the numeric 780000000000 (13 min). Nothing in CI
    pinned the numeric form, so the very next edit could reintroduce the
    string and nobody would notice until a proxy died at start-up.

    This harness reads the REAL template, parses it, and validates it against
    a single predicate that is ALSO run against mutated copies (string form,
    too-small, missing, unparsable). A guard that only ever sees the good file
    proves nothing -- the mutation cases are what show the predicate can fail.

    It also pins the ladder invariant the 2026-09-24 decision established: the
    TBXark hop must OUTLAST the innermost guard, the roosync_dashboard tool
    budget (720 s, mcps/internal/.../tools/registry.ts), so a slow call is cut
    by the inner layer with its own message and never masked by the outer one.

    Static (JSON in, verdict out), so ubuntu-latest is fine.
#>

$ErrorActionPreference = 'Stop'

$TemplateRel = 'docker/mcp-proxy/config.template.json'
$TemplatePath = Join-Path $PSScriptRoot "../../../$TemplateRel"
$InnerBudgetNs = 720000000000   # roosync_dashboard 720 s (registry.ts), the innermost guard

$TestsPassed = 0
$TestsFailed = 0

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        Write-Host "  PASS: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName (expected=$Expected, got=$Actual)" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ============================================================================
# The predicate under test: read a template file, return a verdict string.
# OK | MISSING | NOT-A-NUMBER | NOT-POSITIVE | BELOW-INNER-BUDGET | PARSE-ERROR
# ============================================================================
function Get-TimeoutVerdict {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 'PARSE-ERROR' }
    $raw = [System.IO.File]::ReadAllText((Resolve-Path $Path))
    $obj = $null
    try { $obj = $raw | ConvertFrom-Json } catch { return 'PARSE-ERROR' }
    if ($null -eq $obj.mcpServers) { return 'PARSE-ERROR' }
    $entry = $obj.mcpServers.'roo-state-manager'
    if ($null -eq $entry) { return 'MISSING' }

    # ConvertFrom-Json maps a JSON number to Int64/Double/Decimal and a JSON
    # string to String -- so the type IS the check the Go decoder makes.
    $v = $entry.timeout
    if ($null -eq $v) { return 'MISSING' }
    if ($v -is [string] -or $v -is [bool] -or -not ($v -is [long] -or $v -is [int] -or $v -is [double] -or $v -is [decimal])) {
        return 'NOT-A-NUMBER'
    }
    if ($v -le 0) { return 'NOT-POSITIVE' }
    if ($v -lt $InnerBudgetNs) { return 'BELOW-INNER-BUDGET' }
    return 'OK'
}

# ============================================================================
# Test 1: the real template is valid
# ============================================================================
Write-Host "=== Test 1: the shipped template ($TemplateRel) ===" -ForegroundColor Cyan

if (-not (Test-Path $TemplatePath)) {
    Write-Host "  FAIL: template not found at $TemplatePath -- moved or renamed?" -ForegroundColor Red
    exit 1
}
Assert-Equal 'shipped template verdict' 'OK' (Get-TimeoutVerdict $TemplatePath)

# Report the live value so a legitimate ladder change is visible in the log.
# Guarded: on a defective template the field is a string, and an unguarded
# [math]::Round would throw and abort before the mutation cases below run.
$live = (Get-Content $TemplatePath -Raw | ConvertFrom-Json).mcpServers.'roo-state-manager'.timeout
if ($live -is [long] -or $live -is [int] -or $live -is [double] -or $live -is [decimal]) {
    Write-Host "  info: roo-state-manager timeout = $live ns ($([math]::Round([double]$live / 1e9, 1)) s)"
} else {
    Write-Host "  info: roo-state-manager timeout = '$live' (non-numeric -- the #3083 defect)" -ForegroundColor Yellow
}

# ============================================================================
# Test 2: the predicate discriminates (mutation cases)
# Each case writes a mutated copy and asserts the SAME predicate reacts.
# ============================================================================
Write-Host "`n=== Test 2: mutation cases (the predicate must fail these) ===" -ForegroundColor Cyan

$tmpDir = [System.IO.Path]::GetTempPath()

# Mutations are built from a canonical GOOD snippet, not from the live file:
# if the live file were already broken, mutations derived from it would be
# meaningless and Test 2 would fail for the wrong reason. Test 1 judges the
# real file; Test 2 judges the predicate -- the two stay independent.
$canonical = @'
{
  "mcpServers": {
    "roo-state-manager": {
      "url": "http://host.docker.internal:9091/roo-state-manager/mcp",
      "timeout": 780000000000
    }
  }
}
'@

# Build the "field removed" mutant by re-serializing, so no dangling comma is
# left behind (a string-replace would produce invalid JSON -- PARSE-ERROR, not
# the MISSING verdict this case is meant to exercise).
$noField = $canonical | ConvertFrom-Json
$noField.mcpServers.'roo-state-manager'.PSObject.Properties.Remove('timeout')
$noFieldDoc = $noField | ConvertTo-Json -Depth 10

$cases = @(
    @{ Name = 'string form "5m"  (#3083 defect)';   Verdict = 'NOT-A-NUMBER'; Doc = $canonical.Replace('780000000000', '"5m"') },
    @{ Name = 'string form "13m" (#3839 symptom)';  Verdict = 'NOT-A-NUMBER'; Doc = $canonical.Replace('780000000000', '"13m"') },
    @{ Name = 'zero';                               Verdict = 'NOT-POSITIVE'; Doc = $canonical.Replace('780000000000', '0') },
    @{ Name = 'below inner 720 s budget';           Verdict = 'BELOW-INNER-BUDGET'; Doc = $canonical.Replace('780000000000', '600000000000') },
    @{ Name = 'field removed';                      Verdict = 'MISSING';      Doc = $noFieldDoc },
    @{ Name = 'truncated JSON';                     Verdict = 'PARSE-ERROR';  Doc = $canonical.Substring(0, [math]::Floor($canonical.Length / 2)) }
)

$mutPath = Join-Path $tmpDir 'mcp-proxy-template-timeout.mutant.json'
foreach ($c in $cases) {
    [System.IO.File]::WriteAllText($mutPath, $c.Doc, [System.Text.UTF8Encoding]::new($false))
    Assert-Equal $c.Name $c.Verdict (Get-TimeoutVerdict $mutPath)
}
[System.IO.File]::Delete($mutPath)

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
