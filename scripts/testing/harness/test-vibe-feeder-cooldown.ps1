<#
.SYNOPSIS
    Behavioral guard for the gisement cooldown in vibe-feeder.ps1 (mandat coordinateur 11/10).
.DESCRIPTION
    Measured case (11/10, 05:11->05:55Z): g1-residu-petits-domaines dispatched
    4 times in 44 minutes, every run finding the SAME 10 findings (NOOP work,
    not merged -- the organ re-seeds the gisement at each re-measure). 4 paid
    runs for 0 new finding.

    The fix adds a feeder-side rotation memory (outputs/vibe/feeder-cooldown.json):
    a gisement relaunched $CooldownAfterN times (default 2) WITHOUT findings
    progress -- same fingerprint of target files, exactly what
    refresh-vibe-queue.py reads back via payload_paths() -- leaves the
    rotation for $CooldownHours (default 24), then returns to the pool.

    This guard EXECUTES the real feeder (real mode: dispatch path exercised
    with a stub worker, staged self-origin runtime, no network, no Mistral)
    and replays the measured sequence:

      run 1: first dispatch               -> state 1 relance, no cooldown
      run 2: second dispatch, same grain  -> COOLDOWN armed (+24 h)
      run 3: re-seed, same fingerprint    -> SKIP cooldown, NO dispatch
      run 4: re-seed, same fingerprint    -> still SKIP (the measured
              launches 3 and 4 are the ones this guard saves)
      run 5: re-seed, CHANGED fingerprint (one file left the target set:
              its findings were fixed) -> progress: counter reset, dispatch
              happens even with an armed cooldown -- the cooldown never
              withholds materially new work
      run 6: cooldown served in full (state pre-set: dispatches outside the
              memory horizon + expired cooldownUntil) -> grain back in the
              pool, dispatch happens

    Asserts on the feeder's own LOG FILE (dispatch counts per grain), the
    cooldown STATE FILE (dispatches, cooldownUntil) and the queue FILE (a
    cooled grain STAYS queued -- only EVICTION removes grains). A pre-fix
    feeder dispatches all four replays and writes no state file at all.

    The static half pins the wiring: params with the mandated defaults, the
    fingerprint parser mirroring payload_paths() boundaries, the cooldown
    skip BEFORE every side effect (eviction, recalage, worktree), the state
    write BEFORE the budget exit, and the fail-open read.

    Wired into the scheduling-harness job beside its siblings
    (test-vibe-feeder-eviction, test-vibe-feeder-stale-sweep).
#>

$ErrorActionPreference = 'Stop'

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

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$srcPath = Join-Path $repoRoot 'scripts/scheduling/vibe-feeder.ps1'
$src = Get-Content $srcPath -Raw

# ============================================================================
# Test 1: static wiring
# ============================================================================
Write-Host "`n=== Test 1: cooldown wiring (static) ===" -ForegroundColor Cyan

Assert-Equal 'param CooldownAfterN default 2 (mandate)' $true ($src -match '\[int\]\$CooldownAfterN\s*=\s*2')
Assert-Equal 'param CooldownHours default 24 (bounded)' $true ($src -match '\[int\]\$CooldownHours\s*=\s*24')
Assert-Equal 'fingerprint function defined'            $true ($src -match 'function Get-GrainFingerprint')
# The fingerprint parser MUST mirror payload_paths() (refresh-vibe-queue.py):
# enter on the targetPath line, stop at worktree:/branch:, collect '- ' bullets.
$fpIdx = $src.IndexOf('function Get-GrainFingerprint')
$fpBlock = ''
if ($fpIdx -ge 0) {
    $fpEnd = $src.IndexOf('function ', $fpIdx + 10)
    if ($fpEnd -lt 0) { $fpEnd = $src.Length }
    $fpBlock = $src.Substring($fpIdx, $fpEnd - $fpIdx)
}
Assert-Equal 'fingerprint reads the targetPath block'  $true ($fpBlock -match "targetPath\*")
Assert-Equal 'fingerprint stops at worktree:/branch:'  $true ($fpBlock -match "worktree:\*" -and $fpBlock -match "branch:\*")
Assert-Equal 'fingerprint collects the file bullets'   $true ($fpBlock -match "StartsWith\('- '\)")
# The cooldown skip sits BEFORE every side effect of the loop body -- the
# eviction check is the first of them, so the skip must precede the EVICT log
# marker in the source (same index technique as the eviction harness).
$skipIdx = $src.IndexOf('cooldown actif')
$evictIdx = $src.IndexOf('EVICT ')
Assert-Equal 'cooldown skip precedes the eviction guard' $true ($skipIdx -gt 0 -and $evictIdx -gt $skipIdx)
# The state write happens BEFORE the budget exit can cut the tick short.
$writeIdx = $src.IndexOf('Write-CooldownState -State')
$budgetIdx = $src.IndexOf('$dispatched -ge $Budget')
Assert-Equal 'state written before the budget exit'    $true ($writeIdx -gt 0 -and $budgetIdx -gt $writeIdx)
Assert-Equal 'state file is feeder-cooldown.json'      $true ($src -match 'feeder-cooldown\.json')
# Fail-open: a broken state file must never stop the dispatch (budget
# optimization, not a safety guard).
Assert-Equal 'read is fail-open'                       $true ($src -match 'cooldown ignore ce tick')

# ============================================================================
# Test 2: behavioral -- the measured case, replayed against the real feeder
# ============================================================================
Write-Host "`n=== Test 2: the real feeder arms, holds, resets and releases ===" -ForegroundColor Cyan

$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-cd-" + [guid]::NewGuid().ToString('N').Substring(0,8))
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # Stage the feeder under its own scripts tree (repoRoot derives from the
    # script's own path: state file, organ stub, worker stub, logs all live
    # in the staging area).
    $stage = Join-Path $root 'stage'
    New-Item -ItemType Directory -Path (Join-Path $stage 'scripts/scheduling') -Force | Out-Null
    Copy-Item $srcPath (Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1') -Force
    Set-Content -Path (Join-Path $stage 'scripts/scheduling/refresh-vibe-queue.py') -Value "import sys`nsys.exit(0)`n"
    Set-Content -Path (Join-Path $stage 'scripts/scheduling/start-vibe-worker.ps1') -Value "exit 0`n"

    # Self-origin runtime repo: one commit on main, origin = itself.
    $rt = Join-Path $root 'rt'
    & git init -q --initial-branch=main $rt
    & git -C $rt config user.email 't@t'
    & git -C $rt config user.name 't'
    Set-Content -Path (Join-Path $rt 'f.txt') -Value 'base0'
    & git -C $rt add f.txt
    & git -C $rt commit -qm base0
    $base0 = (& git -C $rt rev-parse HEAD).Trim()
    & git -C $rt remote add origin $rt
    & git -C $rt fetch -q origin main

    # The grain of the measured case, with a REAL payload shape: the
    # fingerprint reads the targetPath block, bounded by worktree:/branch:.
    $wtC = (Join-Path $root 'wtC') -replace '\\', '/'
    $payloadFiles = @(
        'MyIA.AI.Notebooks/GenAI/3D/3D-01-NeRF-From-Scratch.ipynb',
        'MyIA.AI.Notebooks/GenAI/3D/3D-02-NeRF-Critic.ipynb',
        'MyIA.AI.Notebooks/GenAI/Texte/11_Quantization.ipynb'
    )
    function New-QueueFile {
        param([string[]]$Files)
        $tp = ($Files | ForEach-Object { "- $_" }) -join "`n"
        $payload = ("[WAKE-VIBE] g-C (sweep #16472, fournee dimensionnee sur re-scan frais)`n" +
            "baseSha: $base0`n" +
            "targetPath:`n$tp`n" +
            "worktree: $wtC`n" +
            "branch: wt/vibe-gC`n`n" +
            "Mission : faire passer CHAQUE fichier de targetPath a 0 finding.")
        $queue = [ordered]@{
            _comment = 'cooldown behavioral stage'
            grains = @(
                [ordered]@{ id = 'g-C'; issue = 16472; baseSha = $base0; branch = 'wt/vibe-gC'; worktree = $wtC; wtHead = $base0; payload = $payload }
            )
        }
        [System.IO.File]::WriteAllText($queuePath, ($queue | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding $false))
    }
    $queuePath = Join-Path $root 'queue.json'
    $statePath = Join-Path $stage 'outputs/vibe/feeder-cooldown.json'
    $logFile = Join-Path $stage ("outputs/scheduling/logs/vibe-feeder-{0}.log" -f (Get-Date -Format yyyyMMdd))

    function Invoke-StagedFeeder {
        $childPs = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        if (-not $childPs) { $childPs = 'powershell' }
        $stagedFeeder = Join-Path $stage 'scripts/scheduling/vibe-feeder.ps1'
        $null = & $childPs -NoProfile -ExecutionPolicy Bypass -File $stagedFeeder -QueuePath $queuePath -RuntimeDir $rt 2>&1
        return $LASTEXITCODE
    }
    function Get-DispatchCount {
        if (-not (Test-Path $logFile)) { return 0 }
        return @((Get-Content $logFile -Encoding utf8) | Where-Object { $_ -match 'DETACHE lance sur grain g-C' }).Count
    }
    function Read-State {
        if (-not (Test-Path $statePath)) { return $null }
        return (Get-Content $statePath -Raw -Encoding utf8 | ConvertFrom-Json).grains.'g-C'
    }

    # ---- run 1: first dispatch (the 05:11 of the measured case) ----
    New-QueueFile -Files $payloadFiles
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 1 exits 0'                    0 $rc
    Assert-Equal 'run 1 dispatched once'            1 (Get-DispatchCount)
    $st = Read-State
    Assert-Equal 'state file created by run 1'      $true ($null -ne $st)
    Assert-Equal 'run 1: one recorded relance'      1 @($st.dispatches).Count
    Assert-Equal 'run 1: no cooldown armed yet'     $true ($null -eq $st.cooldownUntil)

    # ---- run 2: re-seed, same grain, second dispatch (the 05:33) ----
    New-QueueFile -Files $payloadFiles
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 2 exits 0'                    0 $rc
    $log = Get-Content $logFile -Raw -Encoding utf8
    Assert-Equal 'run 2 arms the cooldown'          $true ($log -match 'COOLDOWN g-C: 2 relance\(s\) sans progres')
    $st = Read-State
    Assert-Equal 'run 2: two recorded relances'     2 @($st.dispatches).Count
    Assert-Equal 'run 2: cooldownUntil set (+24 h)' $true ($null -ne $st.cooldownUntil)

    # ---- run 3: re-seed, same fingerprint -> SKIP, no paid run ----
    New-QueueFile -Files $payloadFiles
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 3 exits 0'                    0 $rc
    $log = Get-Content $logFile -Raw -Encoding utf8
    Assert-Equal 'run 3 logs the cooldown SKIP'     $true ($log -match 'SKIP g-C: cooldown actif')
    Assert-Equal 'run 3: no dispatch (held)'        2 (Get-DispatchCount)
    $q3 = Get-Content $queuePath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-Equal 'run 3: grain STAYS queued'        'g-C' ((@($q3.grains) | ForEach-Object { $_.id }) -join ',')

    # ---- run 4: the measured 4th launch, still held ----
    New-QueueFile -Files $payloadFiles
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 4 exits 0'                    0 $rc
    Assert-Equal 'run 4: still no dispatch'         2 (Get-DispatchCount)

    # ---- run 5: progress -- one file left the target set (fixed upstream) ----
    New-QueueFile -Files @($payloadFiles[0], $payloadFiles[2])
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 5 exits 0'                    0 $rc
    $log = Get-Content $logFile -Raw -Encoding utf8
    Assert-Equal 'run 5 detects the changed fingerprint' $true ($log -match 'COOLDOWN g-C: empreinte changee')
    Assert-Equal 'run 5 dispatches the new work'    3 (Get-DispatchCount)
    $st = Read-State
    Assert-Equal 'run 5: counter reset'             1 @($st.dispatches).Count
    Assert-Equal 'run 5: cooldown cleared'          $true ($null -eq $st.cooldownUntil)

    # ---- run 6: penalty served in full -- dispatches aged past the horizon,
    # cooldownUntil expired -> the gisement returns to the pool.
    New-QueueFile -Files @($payloadFiles[0], $payloadFiles[2])
    $aged = @{
        _comment = 'staged: penalty served'
        grains = @{
            'g-C' = [pscustomobject]@{
                fingerprint    = $st.fingerprint
                dispatches     = @(((Get-Date).ToUniversalTime().AddHours(-25)).ToString('o'))
                cooldownUntil  = ((Get-Date).ToUniversalTime().AddHours(-2)).ToString('o')
            }
        }
    }
    [System.IO.File]::WriteAllText($statePath, ($aged | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
    $rc = Invoke-StagedFeeder
    Assert-Equal 'run 6 exits 0'                    0 $rc
    Assert-Equal 'run 6: back in the pool, dispatched' 4 (Get-DispatchCount)
    $st = Read-State
    Assert-Equal 'run 6: aged relance pruned, fresh count' 1 @($st.dispatches).Count
}
finally {
    $ErrorActionPreference = $savedEap
    # Failure forensics: the staged log explains which guard spoke. Printed
    # BEFORE the cleanup deletes the staging area.
    if ($TestsFailed -gt 0 -and (Test-Path $logFile)) {
        Write-Host "`n--- feeder log tail (failure forensics) ---" -ForegroundColor Yellow
        Get-Content $logFile -Tail 30 -Encoding utf8 | ForEach-Object { Write-Host "  $_" }
    }
    if (Test-Path $root) {
        # Release the grain worktree registered in the staged runtime before
        # the recursive cleanup (same idiom as the stale-sweep harness).
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'wtC' } |
            ForEach-Object { & git -C $rt worktree remove --force $_.FullName 2>$null }
        Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
    }
}

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
exit 0
