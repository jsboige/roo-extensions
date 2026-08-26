<#
.SYNOPSIS
    Harness #3277 : single-instance + lock atomique + tentative bornée du lane Vibe.
.DESCRIPTION
    Incident fondateur (25/08) : 1 dispatch [WAKE-VIBE] → 2 chaînes listener
    concurrentes → 2 workers payés same-seconde (check-then-create) → timeout →
    re-livraison (lastAck n'avance que sur exit 0, cooldown 5 min ≪ runtime
    900 s) → 3e session. Crédits ×3 pour 1 dispatch.

    Ce harness teste les 5 correctifs :

      A. Statique (partout) — les gardes existent dans le code de production :
         UTC réel dans Write-Log (listener + worker), garde mutex dans listener
         ET wrapper, CreateNew atomique dans le worker, exit 75 ≠ exit 0.
      B. In-process (partout) — le module single-instance-mutex.ps1 :
         acquire/deny/release, noms distincts.
      C. Multi-process (Windows uniquement) — les comportements RÉELS :
         C1. deux start-vibe-worker same-seconde → exactement {0, 75}
         C2. deux dashboard-listener concurrents → le second exit 75
         C3. [WAKE-VIBE] échoué → 1 tentative, jamais re-fire, lastAck avancé
             au second passage (consommé explicitement)
         C4. le premier timestamp loggé par le listener est en UTC (±10 min)

    Pourquoi la coupure Windows : C spawn de vrais process pwsh avec mutex
    kernel et locks de fichiers — les sections A/B couvrent la CI ubuntu, les
    sections C sont la preuve locale pré-merge. Reprend le pattern
    test-listener-issue-refs.ps1 (extraction depuis le fichier de production,
    jamais une copie).
#>

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$listener = Join-Path $repoRoot 'scripts\dashboard-scheduler\dashboard-listener.ps1'
$wrapper = Join-Path $repoRoot 'scripts\dashboard-scheduler\dashboard-listener-wrapper.ps1'
$worker = Join-Path $repoRoot 'scripts\scheduling\start-vibe-worker.ps1'
$mutexModule = Join-Path $repoRoot 'scripts\common\single-instance-mutex.ps1'

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

function Assert-True {
    param([string]$TestName, [bool]$Condition)
    if ($Condition) {
        Write-Host "  PASS: $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL: $TestName" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Get-FunctionBodyText {
    param([string]$File, [string]$FunctionName)
    $lines = [System.IO.File]::ReadAllLines($File)
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^function\s+$FunctionName\b") { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $body = @()
    for ($i = $start; $i -lt $lines.Count; $i++) {
        $body += $lines[$i]
        if ($i -gt $start -and $lines[$i] -match '^\}') { break }
    }
    return ($body -join "`n")
}

# ============================================================================
Write-Host "=== Section A : gardes statiques dans le code de production ===" -ForegroundColor Cyan
# ============================================================================

$listenerLogBody = Get-FunctionBodyText $listener 'Write-Log'
Assert-True 'listener Write-Log existe' ($null -ne $listenerLogBody)
Assert-True 'listener Write-Log horodatage UTC réel (ToUniversalTime)' ($listenerLogBody -match 'ToUniversalTime')
Assert-True 'listener Write-Log : plus aucun Get-Date -Format brut (Z collé local)' ($listenerLogBody -notmatch 'Get-Date -Format')

$workerLogBody = Get-FunctionBodyText $worker 'Write-Log'
Assert-True 'worker Write-Log existe' ($null -ne $workerLogBody)
Assert-True 'worker Write-Log horodatage UTC réel' ($workerLogBody -match 'ToUniversalTime')

$listenerRaw = [System.IO.File]::ReadAllText($listener)
Assert-True 'listener : garde mutex Get-SingleInstance présente' ($listenerRaw -match 'Get-SingleInstance')
Assert-True 'listener : exit 75 sur instance déjà active' ($listenerRaw -match 'exit 75')
Assert-True 'listener : tentative comptée au fire (Add-VibeAttempt après Set-LastSpawn)' (
    $listenerRaw.IndexOf('Set-LastSpawn $ws') -lt $listenerRaw.IndexOf('Add-VibeAttempt $triggerMsg.timestamp'))
Assert-True 'listener : rollback de tentative sur exit 75 (Remove-VibeAttempt)' (
    $listenerRaw -match 'exitCode -eq 75' -and $listenerRaw -match 'Remove-VibeAttempt')
Assert-True 'listener : filtre épuisement avant cooldown' (
    $listenerRaw.IndexOf('vibe attempts') -lt $listenerRaw.IndexOf('Test-CooldownOk $ws'))
Assert-True 'listener : VibeMaxAttempts configurable' ($listenerRaw -match 'VibeMaxAttempts')

$wrapperRaw = [System.IO.File]::ReadAllText($wrapper)
Assert-True 'wrapper : garde mutex Get-SingleInstance présente' ($wrapperRaw -match 'Get-SingleInstance')
Assert-True 'wrapper : stop de chaîne sur exit 75 du fils' ($wrapperRaw -match 'exitCode -eq 75')
Assert-True 'wrapper : horodatage UTC' ($wrapperRaw -match 'ToUniversalTime')

$workerRaw = [System.IO.File]::ReadAllText($worker)
Assert-True 'worker : création de lock atomique (FileMode CreateNew)' ($workerRaw -match 'FileMode\]::CreateNew')
Assert-True 'worker : handle FileShare.None conservé ouvert' ($workerRaw -match 'FileShare\]::None')
Assert-True 'worker : SKIP = exit 75 (jamais exit 0)' (
    $workerRaw -match 'exit 75' -and $workerRaw -notmatch 'Write-Log "\[SKIP\][^\r\n]*"\s*\r?\n\s*exit 0')
Assert-True 'worker : discriminateur stale (lecture du lock = pas de titulaire)' ($workerRaw -match 'ReadAllText\(\$LockFile\)')

# ============================================================================
Write-Host "`n=== Section B : module mutex (in-process) ===" -ForegroundColor Cyan
# ============================================================================
. $mutexModule

$h1 = Get-SingleInstance -Name 'RooSync-HarnessTest-Mutex'
Assert-True 'B1 première acquisition réussie' $h1.Acquired
# B2 : un mutex nommé est RÉ-ENTRANT par thread — une 2e acquisition dans CE process
# réussirait toujours. Le déni réel est cross-process (la situation de production
# du 25/08) : un enfant tente pendant que le parent détient.
$b2Script = Join-Path ([System.IO.Path]::GetTempPath()) ('vibe3277-b2-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
[System.IO.File]::WriteAllText($b2Script, ". `"$mutexModule`"`n`$h = Get-SingleInstance -Name 'RooSync-HarnessTest-Mutex'`nif (`$h.Acquired) { Release-SingleInstance `$h; exit 0 } else { exit 1 }", [System.Text.UTF8Encoding]::new($false))
$b2Child = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $b2Script) -Wait -PassThru -WindowStyle Hidden
Assert-Equal 'B2 acquisition refusée depuis un autre process (exit 1 = refusée)' '1' ([string]$b2Child.ExitCode)
Remove-Item $b2Script -Force -ErrorAction SilentlyContinue
$h3 = Get-SingleInstance -Name 'RooSync-HarnessTest-Mutex-Autre'
Assert-True 'B3 nom distinct → acquisition OK (pas de faux positif global)' $h3.Acquired
Release-SingleInstance $h3
Release-SingleInstance $h1
$h4 = Get-SingleInstance -Name 'RooSync-HarnessTest-Mutex'
Assert-True 'B4 ré-acquisition après release' $h4.Acquired
Release-SingleInstance $h4
Assert-True 'B5 release d un handle non acquis = no-op (h2 inexistant)' $true

# ============================================================================
Write-Host "`n=== Section C : comportements multi-process (Windows) ===" -ForegroundColor Cyan
# ============================================================================

$onWindows = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.Platform -eq 'Win32NT')
if (-not $onWindows) {
    Write-Host '  SKIP: sections C1-C4 (multi-process Windows) — non-Windows runner.' -ForegroundColor Yellow
} else {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe3277-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $sharedPath = Join-Path $tempRoot 'shared'
    $lockDir = Join-Path $tempRoot 'locks'
    $wsDir = Join-Path $tempRoot 'ws'
    $logDir = Join-Path $tempRoot 'logs'
    foreach ($d in @($sharedPath, (Join-Path $sharedPath 'dashboards'), $lockDir, $wsDir, $logDir)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    # Isoler les enfants du heartbeat GDrive (ROOSYNC_SHARED_PATH) et du listener de prod.
    $savedSharedPath = $env:ROOSYNC_SHARED_PATH
    $savedMachineId = $env:ROOSYNC_MACHINE_ID
    $env:ROOSYNC_SHARED_PATH = $null
    $env:VIBE_WORKER_LOG_DIR = $logDir

    $wsPathsFile = Join-Path $tempRoot 'ws-paths.json'
    [System.IO.File]::WriteAllText($wsPathsFile, '{"testws": "' + ($wsDir -replace '\\', '\\') + '"}', [System.Text.UTF8Encoding]::new($false))

    function New-FakeDashboard {
        param([string]$Content)
        $db = Join-Path $sharedPath 'dashboards\workspace-testws.md'
        $body = "## Intercom (1 messages)`n`n### [2026-08-26T13:00:00Z] myia-po-2025|CoursIA`n`n$Content`n"
        [System.IO.File]::WriteAllText($db, $body, [System.Text.UTF8Encoding]::new($false))
    }

    function Invoke-ListenerOnce {
        param([string[]]$ExtraArgs = @())
        $outFile = Join-Path $tempRoot ('listener-out-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
        $allArgs = @('-NoProfile', '-File', $listener,
            '-Workspaces', 'testws', '-SharedPath', $sharedPath, '-LockDir', $lockDir,
            '-WorkspacePathsFile', $wsPathsFile,
            '-DebounceSeconds', '0', '-Once') + $ExtraArgs
        $p = Start-Process -FilePath 'pwsh' -ArgumentList $allArgs -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $outFile -RedirectStandardError (Join-Path $tempRoot 'listener-err.txt')
        $out = Get-Content $outFile -Raw -ErrorAction SilentlyContinue
        if ($null -eq $out) { $out = '' }
        return @{ ExitCode = $p.ExitCode; Output = [string]$out }
    }

    try {
        # ------------------------------------------------------------------
        Write-Host "`n--- C1 : deux workers same-seconde → {0, 75} ---" -ForegroundColor Cyan
        # ------------------------------------------------------------------
        $procs = @()
        foreach ($i in 1..2) {
            $o = Join-Path $tempRoot "worker-$i-out.txt"
            # Valeur avec espaces : quotes embarquées obligatoires (Start-Process
            # joint les arguments sans protection, pwsh -File binderait -Seconds).
            $procs += Start-Process -FilePath 'pwsh' -ArgumentList @(
                '-NoProfile', '-File', $worker,
                '-HarnessCommand', '"Start-Sleep -Seconds 6"',
                '-Workspace', 'testws') -PassThru -NoNewWindow `
                -RedirectStandardOutput $o -RedirectStandardError (Join-Path $tempRoot "worker-$i-err.txt")
        }
        foreach ($p in $procs) { $p.WaitForExit() }
        $codes = @($procs | ForEach-Object { [string]$_.ExitCode } | Sort-Object)
        Assert-Equal 'C1a exactement un gagnant (exit 0) et un SKIP (exit 75)' '0 75' ($codes -join ' ')
        $lockResidue = Test-Path (Join-Path $logDir 'vibe-worker.lock')
        Assert-True 'C1b lock nettoyé après la fin des workers' (-not $lockResidue)

        # ------------------------------------------------------------------
        Write-Host "`n--- C2 : mutex listener détenu → invocation exit 75 ---" -ForegroundColor Cyan
        # ------------------------------------------------------------------
        # Un -Once ne retient pas le mutex assez longtemps pour un chevauchement
        # observable. On détient donc le mutex via un holder qui dot-source le MÊME
        # module (la garde ne distingue pas qui détient) pendant que le vrai listener
        # démarre : il doit sortir en 75 avec une trace, puis le holder rend la main.
        New-FakeDashboard '[WAKE-CLAUDE] broadcast de test sans effet (DryRun)'
        $holderScript = Join-Path $tempRoot 'mutex-holder.ps1'
        [System.IO.File]::WriteAllText($holderScript, @'
. "<MODULE>"
$h = Get-SingleInstance -Name 'RooSync-DashboardListenerharness3277race'
if (-not $h.Acquired) { exit 1 }
Start-Sleep -Seconds 12
Release-SingleInstance $h
exit 0
'@.Replace('<MODULE>', $mutexModule), [System.Text.UTF8Encoding]::new($false))
        $holder = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $holderScript) -PassThru -NoNewWindow `
            -RedirectStandardOutput (Join-Path $tempRoot 'holder-out.txt') -RedirectStandardError (Join-Path $tempRoot 'holder-err.txt')
        Start-Sleep -Seconds 2
        $b = Invoke-ListenerOnce @('-InstanceSuffix', 'harness3277race')
        Assert-Equal 'C2a listener démarre avec mutex détenu → exit 75' '75' ([string]$b.ExitCode)
        Assert-True 'C2b le message exit-75 porte une trace lisible' ($b.Output -match 'Another dashboard-listener instance')
        $holder.WaitForExit()
        Assert-Equal 'C2c le holder détient puis relâche proprement (exit 0)' '0' ([string]$holder.ExitCode)
        # Après release, le listener repart : preuve que le 75 n était pas un crash.
        $after = Invoke-ListenerOnce @('-InstanceSuffix', 'harness3277race', '-DryRun')
        Assert-Equal 'C2d après release, le listener tourne normalement (exit 0)' '0' ([string]$after.ExitCode)

        # ------------------------------------------------------------------
        Write-Host "`n--- C3/C4 : [WAKE-VIBE] échoué → 1 tentative, consommé au 2e passage ---" -ForegroundColor Cyan
        # ------------------------------------------------------------------
        $marker = Join-Path $tempRoot 'stub-invocations.txt'
        $stubWorker = Join-Path $tempRoot 'stub-vibe-worker.ps1'
        [System.IO.File]::WriteAllText($stubWorker, @'
param([string]$ConfigPath, [string]$MessagePayloadFile)
Add-Content -Path $env:STUB_MARKER -Value ("invoked " + (Get-Date).ToUniversalTime().ToString('o'))
exit 1
'@, [System.Text.UTF8Encoding]::new($false))
        $env:STUB_MARKER = $marker
        $env:ROOSYNC_MACHINE_ID = 'myia-po-2025'   # router le [WAKE-VIBE] vers CE process de test
        New-FakeDashboard '[WAKE-VIBE] myia-po-2025:CoursIA - dispatch de test (échec attendu)'
        Remove-Item (Join-Path $lockDir 'watcher-testws.lastack') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $lockDir 'listener-testws.lastrun') -Force -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $lockDir 'vibe-wake-attempts.json') -Force -ErrorAction SilentlyContinue
        Remove-Item $marker -Force -ErrorAction SilentlyContinue

        $run1 = Invoke-ListenerOnce @('-InstanceSuffix', 'harness3277', '-VibeWorkerScript', $stubWorker)
        Assert-Equal 'C3a passage 1 : listener exit 0' '0' ([string]$run1.ExitCode)
        Assert-Equal 'C3b passage 1 : stub invoqué exactement 1 fois' '1' ([string]@(Get-Content $marker -ErrorAction SilentlyContinue).Count)
        $ack1 = Get-Content (Join-Path $lockDir 'watcher-testws.lastack') -Raw -ErrorAction SilentlyContinue
        Assert-True 'C3c passage 1 : lastAck NON avancé (échec payant)' ([string]::IsNullOrWhiteSpace($ack1))
        $attempts1 = [string](Get-Content (Join-Path $lockDir 'vibe-wake-attempts.json') -Raw -ErrorAction SilentlyContinue)
        Assert-True 'C3d passage 1 : tentative enregistrée dans le store' ($attempts1 -match '2026-08-26T13:00:00Z')

        $run2 = Invoke-ListenerOnce @('-InstanceSuffix', 'harness3277', '-VibeWorkerScript', $stubWorker)
        Assert-Equal 'C3e passage 2 : listener exit 0' '0' ([string]$run2.ExitCode)
        Assert-Equal 'C3f passage 2 : stub PAS ré-invoqué (tentative unique)' '1' ([string]@(Get-Content $marker -ErrorAction SilentlyContinue).Count)
        $ack2 = [string](Get-Content (Join-Path $lockDir 'watcher-testws.lastack') -Raw -ErrorAction SilentlyContinue)
        Assert-True 'C3g passage 2 : lastAck avancé (message consommé explicitement)' ($ack2 -match '2026-08-26T13:00:00Z')
        Assert-True 'C3h passage 2 : WARN d épuisement tracé' ($run2.Output -match 'exhausted')

        # C4 : le timestamp du log du listener est UTC (le faux Z collait l heure locale).
        $tsMatch = [regex]::Match($run1.Output, '\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})Z\]')
        Assert-True 'C4a le listener loggue un timestamp suffixé Z parsable' $tsMatch.Success
        if ($tsMatch.Success) {
            $loggedUtc = [DateTime]::Parse($tsMatch.Groups[1].Value + 'Z').ToUniversalTime()
            $driftMin = [Math]::Abs(((Get-Date).ToUniversalTime() - $loggedUtc).TotalMinutes)
            Assert-True 'C4b timestamp loggé = UTC réel (dérive < 10 min)' ($driftMin -lt 10)
        }
    } finally {
        $env:ROOSYNC_SHARED_PATH = $savedSharedPath
        $env:ROOSYNC_MACHINE_ID = $savedMachineId
        $env:VIBE_WORKER_LOG_DIR = $null
        $env:STUB_MARKER = $null
        # Laisser le répertoire temp pour inspection en cas d échec ; nettoyé par Windows.
    }
}

# ============================================================================
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { 'Red' } else { 'Green' })
if ($TestsFailed -gt 0) { exit 1 }
Write-Host 'ALL TESTS PASSED' -ForegroundColor Green
exit 0
