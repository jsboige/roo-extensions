#Requires -Version 5.1

<#
.SYNOPSIS
    Provider preflight: verify the LLM provider chain BEFORE fanning out sub-agents (#3361).

.DESCRIPTION
    Incident #3361: four Agent(..., model="sonnet") calls failed simultaneously with HTTP 402
    from an unprovisioned Mistral endpoint. The routing bug itself was fixed repo-side
    (sync-claude-settings.ps1 $OnlyIfAbsent, PR #3363), but nothing checked provider health
    BEFORE a fan-out, and the 402 error exposed the provider without naming the config to fix.

    This script makes the pre-fan-out check possible from any machine:

      1. TRACE   - print the resolution chain  alias -> model ID -> endpoint  for each role
                   (opus/sonnet/haiku/fable), without ever printing secrets.
      2. HEALTH  - probe {ANTHROPIC_BASE_URL}/v1/models with the configured token. On 404
                   (endpoint not exposed), fall back to a minimal 1-token /v1/messages call.
      3. DIAGNOSE- on 401/402/403, print an actionable diagnostic naming the config keys and
                   the remediation (Switch-Provider.ps1, hub-side claudish config), instead of
                   a bare provider error. The fleet policy (native Anthropic hard-locked to
                   myia-ai-01) is stated explicitly so nobody "fixes" an executor by going native.
      4. POLICY  - warn (never silently) when a role maps to a claude-* model ID through a
                   non-Anthropic hub: that is the exact signature of #3361. A warning, not a
                   failure - the hub may legitimately route claude-* IDs today.

    Exit codes (stable contract for callers):
        0  healthy (all roles resolved, endpoint answered 200)
        1  config error (settings unreadable, or no BASE_URL and no probeable token)
        2  auth/billing refused (HTTP 401/402/403) - do NOT fan out
        3  endpoint unreachable or server error (5xx/timeout/DNS) - do NOT fan out
        4  endpoint healthy but >= 1 role model ID not in the routable list (incident signature)

.EXAMPLE
    .\provider-preflight.ps1
    Check all four roles against the configured provider.

.EXAMPLE
    .\provider-preflight.ps1 -Model sonnet
    Check only the sonnet role (the alias used by sub-agent fan-outs).

.NOTES
    Issue #3361 (remaining repo-side acceptance criteria: provider health/preflight before
    fan-out + actionable diagnostic on 402/401/403).
    Read-only: GET /v1/models, or a 1-token POST /v1/messages as fallback. No config change.
#>

param(
    [ValidateSet('opus', 'sonnet', 'haiku', 'fable', 'all')]
    [string]$Model = 'all',

    [string]$SettingsPath = (Join-Path $env:USERPROFILE '.claude\settings.json'),

    [int]$TimeoutSec = 30
)

$ErrorActionPreference = 'Stop'

# PS 5.1 TLS gate: the hub is HTTPS-only.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# --- Load settings (secrets never printed) -------------------------------------------
if (-not (Test-Path $SettingsPath)) {
    Write-Host "CONFIG ERROR: settings not found at $SettingsPath" -ForegroundColor Red
    exit 1
}
try {
    $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "CONFIG ERROR: cannot parse $SettingsPath : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$envMap = @{}
if ($settings.env) {
    foreach ($p in $settings.env.PSObject.Properties) { $envMap[$p.Name] = [string]$p.Value }
}

$baseUrl = $envMap['ANTHROPIC_BASE_URL']
if ($baseUrl) { $baseUrl = $baseUrl.TrimEnd('/') }
$token = $envMap['ANTHROPIC_AUTH_TOKEN']
$hasToken = [bool]$token

# Role -> settings key (the mapping Switch-Provider.ps1 owns, protected by $OnlyIfAbsent #3361)
$roleKeys = [ordered]@{
    opus   = 'ANTHROPIC_DEFAULT_OPUS_MODEL'
    sonnet = 'ANTHROPIC_DEFAULT_SONNET_MODEL'
    haiku  = 'ANTHROPIC_DEFAULT_HAIKU_MODEL'
    fable  = 'ANTHROPIC_DEFAULT_FABLE_MODEL'
}

# --- 1. TRACE the resolution chain ---------------------------------------------------
Write-Host '=== Provider preflight (#3361) ===' -ForegroundColor Cyan
$endpoint = if ($baseUrl) { $baseUrl } else { 'https://api.anthropic.com (native - no ANTHROPIC_BASE_URL set)' }
Write-Host "Endpoint : $endpoint"
Write-Host "Token    : $(if ($hasToken) { 'present (never printed)' } else { 'ABSENT from settings' })"
Write-Host ''
Write-Host 'Resolution chain  alias -> model ID -> endpoint:' -ForegroundColor Yellow

$rolesToCheck = if ($Model -eq 'all') { @($roleKeys.Keys) } else { @($Model) }
$roleIds = @{}
foreach ($role in $rolesToCheck) {
    $rawId = $envMap[$roleKeys[$role]]
    if (-not $rawId) {
        Write-Host ("  {0,-7} -> (unset: {1})" -f $role, $roleKeys[$role]) -ForegroundColor DarkYellow
        continue
    }
    # The [1m] suffix is a client-side context-window hint (#context-window.md); the API
    # receives the bare ID. Keep both in the trace so the chain is complete.
    $apiId = $rawId -replace '\[1m\]$', ''
    $roleIds[$role] = $apiId
    Write-Host ("  {0,-7} -> {1}  (API ID: {2})  ->  {3}" -f $role, $rawId, $apiId, $endpoint)

    # Policy visibility (#3361 AC: never fall back SILENTLY to a native Anthropic model).
    # A claude-* ID routed through a non-Anthropic hub is the exact incident signature; the
    # hub may still route it correctly, so this is a loud WARNING, not a failure.
    if ($apiId -like 'claude-*' -and $baseUrl -and $baseUrl -notmatch 'anthropic\.com') {
        Write-Host ("           WARN: '{0}' is a native-Anthropic ID routed via the hub. If unintended on an" -f $rawId) -ForegroundColor Yellow
        Write-Host '           executor machine, re-apply the fleet policy:' -ForegroundColor Yellow
        Write-Host '           powershell scripts/claude/Switch-Provider.ps1 -Provider claudish   (sonnet -> glm-5.1, z.ai)' -ForegroundColor Yellow
    }
}

# --- 2. HEALTH probe -----------------------------------------------------------------
if (-not $baseUrl) {
    if ($hasToken) {
        $baseUrl = 'https://api.anthropic.com'
    } else {
        Write-Host ''
        Write-Host 'SKIP health probe: no ANTHROPIC_BASE_URL and no ANTHROPIC_AUTH_TOKEN in settings' -ForegroundColor DarkGray
        Write-Host '(native Anthropic auth lives outside settings.json - not probeable here).'
        Write-Host 'Preflight result: CONFIG-ONLY (chain traced above).' -ForegroundColor Cyan
        exit 0
    }
}
# Hub reality (verified 2026-09-03 on models.myia.io): /v1/models answers 200 UNAUTHENTICATED,
# and executor machines legitimately carry an empty ANTHROPIC_AUTH_TOKEN while their Claude
# sessions auth through ANTHROPIC_CUSTOM_HEADERS. So an empty token is NOT fatal here: probe
# without auth headers first; only a 401/403 answer makes the missing token the named cause.
$headers = @{}
if ($hasToken) {
    $headers['x-api-key'] = $token
    $headers['anthropic-version'] = '2023-06-01'
}

function Get-HttpProbe {
    # Returns @{ Code = [int]; Body = [string] }. Works on PS 5.1 (HttpWebResponse) and PS 7+.
    param([string]$Uri, [string]$Method = 'Get', [hashtable]$H = $headers, [string]$Body = $null)
    try {
        $args = @{ Uri = $Uri; Method = $Method; TimeoutSec = $TimeoutSec }
        if ($Body) { $args.Body = $Body; $args.ContentType = 'application/json' }
        $resp = Invoke-WebRequest @args -Headers $H -UseBasicParsing
        return @{ Code = [int]$resp.StatusCode; Body = [string]$resp.Content }
    } catch {
        $code = 0
        $bodyText = ''
        if ($_.Exception.Response) {
            try { $code = [int]$_.Exception.Response.StatusCode } catch { }
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                if ($stream) { $bodyText = (New-Object System.IO.StreamReader($stream)).ReadToEnd() }
            } catch { }
        }
        return @{ Code = $code; Body = $bodyText; Error = $_.Exception.Message }
    }
}

function Get-DetailFromJson {
    # Mistral-style error body: {"detail":"Check your subscription on ..."} - the exact #3361 shape.
    param([string]$Json)
    if (-not $Json) { return $null }
    try {
        $o = $Json | ConvertFrom-Json
        if ($o.detail) { return [string]$o.detail }
        if ($o.error -and $o.error.message) { return [string]$o.error.message }
    } catch { }
    return $null
}

Write-Host ''
Write-Host "Health probe: GET $baseUrl/v1/models" -ForegroundColor Yellow
$probe = Get-HttpProbe -Uri "$baseUrl/v1/models"

# Fallback when the hub does not expose /v1/models: a 1-token message with the first role ID.
if ($probe.Code -eq 404 -and $roleIds.Count -gt 0) {
    Write-Host '  /v1/models not exposed (404) - falling back to a 1-token /v1/messages probe' -ForegroundColor DarkGray
    $anyId = $roleIds[$rolesToCheck[0]]
    if (-not $anyId) { $anyId = $roleIds.Values | Select-Object -First 1 }
    $msgBody = @{ model = $anyId; max_tokens = 1; messages = @(@{ role = 'user'; content = 'hi' }) } | ConvertTo-Json -Depth 4
    $probe = Get-HttpProbe -Uri "$baseUrl/v1/messages" -Method Post -Body $msgBody
}

if ($probe.Code -eq 0) {
    Write-Host "  UNREACHABLE: $($probe.Error)" -ForegroundColor Red
    Write-Host '  Do NOT fan out. Check network/DNS, or the hub host (claudish container, see' -ForegroundColor Red
    Write-Host '  docs/deployment/claudish-per-machine.md). Retry once, then consider switching provider.'
    exit 3
}

if ($probe.Code -in 401, 402, 403) {
    $detail = Get-DetailFromJson -Json $probe.Body
    $label = switch ($probe.Code) {
        401 { 'AUTHENTICATION refused (401)' }
        402 { 'BILLING/subscription refused (402) - the #3361 signature' }
        403 { 'AUTHORIZATION refused (403)' }
    }
    Write-Host "  $label" -ForegroundColor Red
    if ($probe.Code -in 401, 403 -and -not $hasToken) {
        Write-Host '  Probable cause: ANTHROPIC_AUTH_TOKEN is empty in settings (unauthenticated probe was refused).' -ForegroundColor Red
    }
    if ($detail) { Write-Host "  Provider said: $detail" -ForegroundColor Red }
    Write-Host ''
    Write-Host '  DIAGNOSTIC - config involved:' -ForegroundColor Cyan
    Write-Host "    - $SettingsPath -> env.ANTHROPIC_BASE_URL = $baseUrl"
    Write-Host "    - $SettingsPath -> env.ANTHROPIC_AUTH_TOKEN (present: $hasToken)"
    Write-Host '    - env.ANTHROPIC_DEFAULT_*_MODEL keys (chain traced above)'
    Write-Host '  Remediation, in order:' -ForegroundColor Cyan
    Write-Host '    1. Re-apply the machine provider policy:'
    Write-Host '       powershell scripts/claude/Switch-Provider.ps1 -Provider claudish   (executor pool: z.ai glm-5.1)'
    Write-Host '    2. If the chain above already matches the policy, the refused provider is hub-side:'
    Write-Host '       check ~/.claudish/config.json on the claudish host (docs/deployment/claudish-per-machine.md).'
    Write-Host '    3. Do NOT switch to -Provider anthropic on executor machines: the fleet policy'
    Write-Host '       hard-locks native Anthropic to myia-ai-01.'
    Write-Host '  Do NOT fan out until this passes.' -ForegroundColor Red
    exit 2
}

if ($probe.Code -ge 500) {
    Write-Host "  SERVER ERROR: HTTP $($probe.Code)" -ForegroundColor Red
    Write-Host '  Do NOT fan out. The hub/provider is failing - retry, or check the claudish host.'
    exit 3
}

if ($probe.Code -ne 200) {
    Write-Host "  UNEXPECTED STATUS: HTTP $($probe.Code) - refusing to declare healthy" -ForegroundColor Red
    exit 3
}

# --- 3. ROUTABILITY check ------------------------------------------------------------
# The #3361 failure mode: the hub accepted the request but had NO routing rule for the model
# ID and silently wildcarded to an unprovisioned provider. If /v1/models answers, an ID that
# is NOT in the list is the smoking-gun signature.
$routable = @()
try {
    $modelsJson = $probe.Body | ConvertFrom-Json
    if ($modelsJson.data) { $routable = @($modelsJson.data | ForEach-Object { $_.id }) }
    elseif ($modelsJson.models) { $routable = @($modelsJson.models | ForEach-Object { $_.id }) }
} catch { }

Write-Host "  HTTP 200 - endpoint healthy ($($routable.Count) routable models listed)" -ForegroundColor Green

if ($routable.Count -eq 0) {
    Write-Host '  (model list empty or not parseable - routability check skipped)' -ForegroundColor DarkGray
    Write-Host 'Preflight result: HEALTHY' -ForegroundColor Green
    exit 0
}

$notRoutable = @()
foreach ($role in $roleIds.Keys) {
    $id = $roleIds[$role]
    # Accept exact match, or a prefix match (some hubs expose namespaced IDs like vendor/model).
    $hit = ($routable -contains $id) -or (@($routable | Where-Object { $_ -like "*/$id" }).Count -gt 0)
    if ($hit) {
        Write-Host "  ROUTED   : $role -> $id" -ForegroundColor Green
    } else {
        Write-Host "  NOT LISTED: $role -> $id (no /v1/models entry - the #3361 wildcard signature)" -ForegroundColor Yellow
        $notRoutable += "$role=$id"
    }
}

if ($notRoutable.Count -gt 0) {
    Write-Host ''
    Write-Host '  DIAGNOSTIC - role model IDs not routable on this endpoint:' -ForegroundColor Cyan
    $notRoutable | ForEach-Object { Write-Host "    - $_" }
    Write-Host '  The hub has no rule for these IDs (incident #3361 wildcard path).' -ForegroundColor Cyan
    Write-Host '  Remediation: re-apply the machine policy so IDs match the hub routing table:'
    Write-Host '    powershell scripts/claude/Switch-Provider.ps1 -Provider claudish'
    Write-Host '  Preflight result: DEGRADED (endpoint healthy, routing mismatch)' -ForegroundColor Yellow
    exit 4
}

Write-Host 'Preflight result: HEALTHY - safe to fan out' -ForegroundColor Green
exit 0
