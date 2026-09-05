param()

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'gdrivefs-watchdog.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw
# Extract the whole C1 section (Invoke-BoundedMountProbe + Test-GDriveFSMountLive):
# Test-GDriveFSMountLive calls the helper, so both must be defined for the harness.
$match = [regex]::Match(
    $source,
    '(?s)# ---------- C1:.*?(?=\r?\n# ---------- C2:)'
)
if (-not $match.Success) {
    throw 'Could not locate the C1 probe section in watchdog script.'
}

Invoke-Expression $match.Value

$results = @()
function Assert-Probe {
    param([string]$Name, [bool]$Condition, [string]$Detail)
    $script:results += [pscustomobject]@{ Name = $Name; Passed = $Condition; Detail = $Detail }
    $status = if ($Condition) { 'PASS' } else { 'FAIL' }
    Write-Host "[$status] $Name — $Detail"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gdrivefs-watchdog-test-{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
try {
    $healthy = Test-GDriveFSMountLive -Path $tempDir -TimeoutSeconds 5
    Assert-Probe 'healthy idle mount succeeds' ($healthy.Live -and $healthy.Reason -eq 'mount-stat+enum-ok') $healthy.Reason

    $emptyDir = Join-Path $tempDir 'empty-mount'
    New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
    $empty = Test-GDriveFSMountLive -Path $emptyDir -TimeoutSeconds 5
    Assert-Probe 'empty mount (0 items) still succeeds' ($empty.Live -and $empty.Reason -eq 'mount-stat+enum-ok') $empty.Reason

    $missing = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing') -TimeoutSeconds 5
    Assert-Probe 'missing mount fails' (-not $missing.Live -and $missing.Reason -like 'mount-probe-error:*') $missing.Reason

    $disabled = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing') -TimeoutSeconds 0
    Assert-Probe 'explicitly disabled probe succeeds' ($disabled.Live -and $disabled.Reason -eq 'c1-disabled') $disabled.Reason

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $missingFast = Test-GDriveFSMountLive -Path (Join-Path $tempDir 'missing-fast') -TimeoutSeconds 1
    $watch.Stop()
    Assert-Probe 'probe returns within bound' ($watch.Elapsed.TotalSeconds -lt 5) ("elapsed={0:N2}s reason={1}" -f $watch.Elapsed.TotalSeconds, $missingFast.Reason)
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

$failed = @($results | Where-Object { -not $_.Passed })
Write-Host "`n$($results.Count - $failed.Count)/$($results.Count) tests passed"
if ($failed.Count -gt 0) { exit 1 }
