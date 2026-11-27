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

    It also pins the relay transportType: both relay entries (sk-agent,
    roo-state-manager) must declare "streamable-http" exactly like the live
    config does (#1357 gap -- without it, a deploy from the template alone
    silently falls back to the default transport). The comparison is
    case-strict (-cne: PowerShell -ne ignores case), and a relay entry that
    is absent outright reports SERVER-MISSING rather than a misleading
    PARSE-ERROR (review follow-up on #4743).

    The timeout predicate is applied to BOTH relay entries. #4718 gave
    sk-agent its own 900 s timeout and, until this change, nothing pinned it:
    a second field no guard reads is a value the next edit can delete in
    silence (point 3 of the review of #4718). Each entry carries its own
    floor -- roo-state-manager must outlast the 720 s inner budget, sk-agent
    must honour #1357's 5 min chain budget -- and a relay entry that is
    absent outright reports SERVER-MISSING, like the transport predicate.

    Static (JSON in, verdict out), so ubuntu-latest is fine.
#>

$ErrorActionPreference = 'Stop'

$TemplateRel = 'docker/mcp-proxy/config.template.json'
$TemplatePath = Join-Path $PSScriptRoot "../../../$TemplateRel"
$InnerBudgetNs = 720000000000   # roosync_dashboard 720 s (registry.ts), the innermost guard
$ChainBudgetNs = 300000000000   # #1357: 5 min across the chain (default, not a hard cap)
# Every relay entry MUST declare a timeout, and must clear its own floor.
$RelayTimeoutFloors = @{ 'roo-state-manager' = $InnerBudgetNs; 'sk-agent' = $ChainBudgetNs }
$RelayTimeoutServers = [string[]]@('sk-agent', 'roo-state-manager')

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
# OK | SERVER-MISSING | MISSING | NOT-A-NUMBER | NOT-POSITIVE | BELOW-BUDGET
# | PARSE-ERROR
# ============================================================================
function Get-TimeoutVerdict {
    param([string]$Path, [string]$ServerName)
    if (-not (Test-Path $Path)) { return 'PARSE-ERROR' }
    $raw = [System.IO.File]::ReadAllText((Resolve-Path $Path))
    $obj = $null
    try { $obj = $raw | ConvertFrom-Json } catch { return 'PARSE-ERROR' }
    if ($null -eq $obj.mcpServers) { return 'PARSE-ERROR' }
    # An absent entry is not a parse failure -- same verdict as the transport
    # predicate, so a deleted relay is never reported as a malformed file.
    $entry = $obj.mcpServers.$ServerName
    if ($null -eq $entry) { return 'SERVER-MISSING' }

    # ConvertFrom-Json maps a JSON number to Int64/Double/Decimal and a JSON
    # string to String -- so the type IS the check the Go decoder makes.
    $v = $entry.timeout
    if ($null -eq $v) { return 'MISSING' }
    if ($v -is [string] -or $v -is [bool] -or -not ($v -is [long] -or $v -is [int] -or $v -is [double] -or $v -is [decimal])) {
        return 'NOT-A-NUMBER'
    }
    if ($v -le 0) { return 'NOT-POSITIVE' }
    $floor = $script:RelayTimeoutFloors[$ServerName]
    if ($null -ne $floor -and $v -lt $floor) { return 'BELOW-BUDGET' }
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
foreach ($relay in $RelayTimeoutServers) {
    Assert-Equal "shipped template timeout [$relay]" 'OK' (Get-TimeoutVerdict $TemplatePath $relay)
}

# Report the live values so a legitimate ladder change is visible in the log.
# Guarded: on a defective template the field is a string, and an unguarded
# [math]::Round would throw and abort before the mutation cases below run.
$parsed = Get-Content $TemplatePath -Raw | ConvertFrom-Json
foreach ($relay in $RelayTimeoutServers) {
    $live = $parsed.mcpServers.$relay.timeout
    if ($live -is [long] -or $live -is [int] -or $live -is [double] -or $live -is [decimal]) {
        Write-Host ("  info: {0} timeout = {1} ns ({2} s, floor {3} s)" -f `
            $relay, $live, [math]::Round([double]$live / 1e9, 1), [math]::Round([double]$RelayTimeoutFloors[$relay] / 1e9, 0))
    } else {
        Write-Host "  info: $relay timeout = '$live' (non-numeric -- the #3083 defect)" -ForegroundColor Yellow
    }
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
    "searxng": { "command": "npx", "args": ["-y", "searxng-mcp"] },
    "sk-agent": {
      "url": "http://host.docker.internal:8100/mcp",
      "transportType": "streamable-http",
      "timeout": 900000000000
    },
    "roo-state-manager": {
      "url": "http://host.docker.internal:9091/roo-state-manager/mcp",
      "transportType": "streamable-http",
      "timeout": 780000000000
    }
  }
}
'@

# Mutants are built by re-serialization, so no dangling comma can turn a
# semantic case into PARSE-ERROR (the #4743 review lesson). -Value keeps its
# PowerShell type: passing 0 (int) and '15m' (string) exercises two different
# verdicts, which is the point of the table.
function New-MutantDoc {
    param(
        [Parameter(Mandatory = $true)][string]$ServerName,
        [string]$Prop,
        $Value,
        [switch]$RemoveProp,
        [switch]$RemoveEntry
    )
    $doc = $canonical | ConvertFrom-Json
    if ($RemoveEntry) {
        $doc.mcpServers.PSObject.Properties.Remove($ServerName)
    } elseif ($RemoveProp) {
        $doc.mcpServers.$ServerName.PSObject.Properties.Remove($Prop)
    } else {
        $doc.mcpServers.$ServerName.$Prop = $Value
    }
    return ($doc | ConvertTo-Json -Depth 10)
}

$cases = @(
    @{ Name = 'sk-agent timeout "15m" (#4718 follow-up)'; Server = 'sk-agent'; Verdict = 'NOT-A-NUMBER';   Doc = (New-MutantDoc -ServerName 'sk-agent' -Prop 'timeout' -Value '15m') },
    @{ Name = 'sk-agent timeout 0';                       Server = 'sk-agent'; Verdict = 'NOT-POSITIVE';   Doc = (New-MutantDoc -ServerName 'sk-agent' -Prop 'timeout' -Value 0) },
    @{ Name = 'sk-agent timeout 240 s (< 5 min chain)';   Server = 'sk-agent'; Verdict = 'BELOW-BUDGET';   Doc = (New-MutantDoc -ServerName 'sk-agent' -Prop 'timeout' -Value 240000000000) },
    @{ Name = 'sk-agent timeout removed';                 Server = 'sk-agent'; Verdict = 'MISSING';        Doc = (New-MutantDoc -ServerName 'sk-agent' -Prop 'timeout' -RemoveProp) },
    @{ Name = 'sk-agent entry removed';                   Server = 'sk-agent'; Verdict = 'SERVER-MISSING'; Doc = (New-MutantDoc -ServerName 'sk-agent' -RemoveEntry) },
    @{ Name = 'rsm timeout "5m" (#3083 defect)';          Server = 'roo-state-manager'; Verdict = 'NOT-A-NUMBER';   Doc = (New-MutantDoc -ServerName 'roo-state-manager' -Prop 'timeout' -Value '5m') },
    @{ Name = 'rsm timeout "13m" (#3839 symptom)';        Server = 'roo-state-manager'; Verdict = 'NOT-A-NUMBER';   Doc = (New-MutantDoc -ServerName 'roo-state-manager' -Prop 'timeout' -Value '13m') },
    @{ Name = 'rsm timeout 0';                            Server = 'roo-state-manager'; Verdict = 'NOT-POSITIVE';   Doc = (New-MutantDoc -ServerName 'roo-state-manager' -Prop 'timeout' -Value 0) },
    @{ Name = 'rsm timeout 600 s (< 720 s inner)';        Server = 'roo-state-manager'; Verdict = 'BELOW-BUDGET';   Doc = (New-MutantDoc -ServerName 'roo-state-manager' -Prop 'timeout' -Value 600000000000) },
    @{ Name = 'rsm timeout removed';                      Server = 'roo-state-manager'; Verdict = 'MISSING';        Doc = (New-MutantDoc -ServerName 'roo-state-manager' -Prop 'timeout' -RemoveProp) },
    @{ Name = 'rsm entry removed';                        Server = 'roo-state-manager'; Verdict = 'SERVER-MISSING'; Doc = (New-MutantDoc -ServerName 'roo-state-manager' -RemoveEntry) },
    @{ Name = 'truncated JSON';                           Server = 'roo-state-manager'; Verdict = 'PARSE-ERROR';    Doc = $canonical.Substring(0, [math]::Floor($canonical.Length / 2)) }
)

$mutPath = Join-Path $tmpDir 'mcp-proxy-template-timeout.mutant.json'
foreach ($c in $cases) {
    [System.IO.File]::WriteAllText($mutPath, $c.Doc, [System.Text.UTF8Encoding]::new($false))
    Assert-Equal ("{0} [{1}]" -f $c.Name, $c.Server) $c.Verdict (Get-TimeoutVerdict $mutPath $c.Server)
}
[System.IO.File]::Delete($mutPath)

# ============================================================================
# Test 2b: the predicate must react to a mutation of the SHIPPED template, not
# only to mutants written from a canonical snippet. Deleting sk-agent's
# timeout from the real file is exactly the regression this guard exists for,
# and until this change the guard reported 16/16 PASS on that mutant. The
# template on disk is only READ here (its mtime is printed as the witness).
# ============================================================================
Write-Host "`n=== Test 2b: mutation of the shipped template itself ===" -ForegroundColor Cyan

$shippedNoSk = Get-Content $TemplatePath -Raw | ConvertFrom-Json
$shippedNoSk.mcpServers.'sk-agent'.PSObject.Properties.Remove('timeout')
[System.IO.File]::WriteAllText($mutPath, ($shippedNoSk | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
Assert-Equal 'shipped template minus sk-agent timeout [sk-agent]' 'MISSING' (Get-TimeoutVerdict $mutPath 'sk-agent')

$shippedNoRsm = Get-Content $TemplatePath -Raw | ConvertFrom-Json
$shippedNoRsm.mcpServers.'roo-state-manager'.PSObject.Properties.Remove('timeout')
[System.IO.File]::WriteAllText($mutPath, ($shippedNoRsm | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
Assert-Equal 'shipped template minus rsm timeout [roo-state-manager]' 'MISSING' (Get-TimeoutVerdict $mutPath 'roo-state-manager')
[System.IO.File]::Delete($mutPath)

Write-Host ("  info: shipped template untouched on disk (LastWriteTimeUtc {0:o})" -f (Get-Item $TemplatePath).LastWriteTimeUtc)

# ============================================================================
# Test 3: both relay entries declare transportType "streamable-http"
# (#1357 gap flagged in the issue state block: the live config carries the
# field on both relays, the template on neither -- a deploy from the template
# alone would silently fall back to the default transport.)
# ============================================================================
Write-Host "`n=== Test 3: relay transportType on the shipped template ===" -ForegroundColor Cyan

function Get-TransportVerdict {
    param([string]$Path, [string]$ServerName)
    if (-not (Test-Path $Path)) { return 'PARSE-ERROR' }
    $raw = [System.IO.File]::ReadAllText((Resolve-Path $Path))
    $obj = $null
    try { $obj = $raw | ConvertFrom-Json } catch { return 'PARSE-ERROR' }
    if ($null -eq $obj.mcpServers) { return 'PARSE-ERROR' }
    # An absent relay entry is not a parse failure -- it deserves its own
    # verdict instead of the misleading PARSE-ERROR (review of #4743).
    $entry = $obj.mcpServers.$ServerName
    if ($null -eq $entry) { return 'SERVER-MISSING' }
    $v = $entry.transportType
    if ($null -eq $v) { return 'MISSING' }
    if (-not ($v -is [string])) { return 'NOT-A-STRING' }
    # -cne, not -ne: PowerShell comparisons are case-INsensitive by default,
    # so 'STREAMABLE-HTTP' would sail through -ne (review of #4743).
    if ($v -cne 'streamable-http') { return 'WRONG-VALUE' }
    return 'OK'
}

foreach ($relay in @('sk-agent', 'roo-state-manager')) {
    Assert-Equal "shipped template transportType [$relay]" 'OK' (Get-TransportVerdict $TemplatePath $relay)
}

# ============================================================================
# Test 4: transport predicate mutation cases (same discipline as Test 2)
# ============================================================================
Write-Host "`n=== Test 4: transportType mutation cases ===" -ForegroundColor Cyan

$ttCanonical = @'
{
  "mcpServers": {
    "sk-agent": {
      "url": "http://host.docker.internal:8100/mcp",
      "transportType": "streamable-http"
    },
    "roo-state-manager": {
      "url": "http://host.docker.internal:9091/roo-state-manager/mcp",
      "transportType": "streamable-http"
    }
  }
}
'@

# "field removed" mutant via re-serialization (no dangling comma -- same
# pattern as the timeout cases).
$ttNoField = $ttCanonical | ConvertFrom-Json
$ttNoField.mcpServers.'sk-agent'.PSObject.Properties.Remove('transportType')
$ttNoFieldDoc = $ttNoField | ConvertTo-Json -Depth 10

$ttCases = @(
    @{ Name = 'transportType missing (#1357 gap)';    Verdict = 'MISSING';      Doc = $ttNoFieldDoc },
    @{ Name = 'transportType "sse" (legacy)';         Verdict = 'WRONG-VALUE';  Doc = $ttCanonical.Replace('"streamable-http"', '"sse"') },
    @{ Name = 'transportType "stdio"';                Verdict = 'WRONG-VALUE';  Doc = $ttCanonical.Replace('"streamable-http"', '"stdio"') },
    @{ Name = 'transportType numeric';                Verdict = 'NOT-A-STRING'; Doc = $ttCanonical.Replace('"transportType": "streamable-http"', '"transportType": 1') },
    @{ Name = 'transportType "STREAMABLE-HTTP" (case)'; Verdict = 'WRONG-VALUE'; Doc = $ttCanonical.Replace('"streamable-http"', '"STREAMABLE-HTTP"') }
)

$ttMutPath = Join-Path $tmpDir 'mcp-proxy-template-transport.mutant.json'
foreach ($c in $ttCases) {
    [System.IO.File]::WriteAllText($ttMutPath, $c.Doc, [System.Text.UTF8Encoding]::new($false))
    Assert-Equal $c.Name $c.Verdict (Get-TransportVerdict $ttMutPath 'sk-agent')
}

# Review of #4743: Test 4 only ever mutated sk-agent, and a relay entry
# absent outright must read SERVER-MISSING, not the misleading PARSE-ERROR.
$ttNoServer = $ttCanonical | ConvertFrom-Json
$ttNoServer.mcpServers.PSObject.Properties.Remove('roo-state-manager')
$ttNoServerDoc = $ttNoServer | ConvertTo-Json -Depth 10

$ttNoFieldRsm = $ttCanonical | ConvertFrom-Json
$ttNoFieldRsm.mcpServers.'roo-state-manager'.PSObject.Properties.Remove('transportType')
$ttNoFieldRsmDoc = $ttNoFieldRsm | ConvertTo-Json -Depth 10

foreach ($pair in @(
    @{ Name = 'relay entry removed [roo-state-manager]';   Verdict = 'SERVER-MISSING'; Doc = $ttNoServerDoc },
    @{ Name = 'transportType missing [roo-state-manager]'; Verdict = 'MISSING';        Doc = $ttNoFieldRsmDoc }
)) {
    [System.IO.File]::WriteAllText($ttMutPath, $pair.Doc, [System.Text.UTF8Encoding]::new($false))
    Assert-Equal $pair.Name $pair.Verdict (Get-TransportVerdict $ttMutPath 'roo-state-manager')
}
[System.IO.File]::Delete($ttMutPath)

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
