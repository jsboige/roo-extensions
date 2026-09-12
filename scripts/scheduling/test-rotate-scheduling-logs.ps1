<#
.SYNOPSIS
    Tests de rotate-scheduling-logs.ps1 (#3323) sur bac a sable $TEMP.

.DESCRIPTION
    Valide, sans toucher aux vrais logs :
    - classification par bucket (iter vs worker, meta, env, lock, unknown)
    - retention par bucket (ages limites respectes)
    - Unknown JAMAIS supprime, meme tres ancien
    - .lock frais protege, .lock orphelin eligible
    - REPORT-ONLY par defaut (0 suppression sans -Execute)
    - -Execute effectif + code sortie
    - pas de recursion (sous-repertoire intact)

    Le script sous test est invoque comme PROCESS (powershell -File), jamais
    dot-source : il a des effets de bord par conception.

.NOTES
    Issue : #3323
#>

$ErrorActionPreference = 'Stop'
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

$ScriptUnderTest = Join-Path $PSScriptRoot 'rotate-scheduling-logs.ps1'
$Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

function New-TestFile {
    param([string]$Name, [double]$AgeDays)
    $p = Join-Path $Sandbox $Name
    Set-Content -LiteralPath $p -Value 'test'
    (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-$AgeDays)
}

function Invoke-Rotator {
    param([string[]]$ExtraArgs = @())
    $allArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptUnderTest, '-LogDir', $Sandbox) + $ExtraArgs
    $output = & powershell.exe @allArgs 2>&1 | Out-String
    return @{ Output = $output; ExitCode = $LASTEXITCODE }
}

try {
    New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
    $SubDir = Join-Path $Sandbox 'subdir'
    New-Item -ItemType Directory -Path $SubDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $SubDir 'inner-worker-20200101-000000.log') -Value 'nested'

    # --- Fixtures : 15 fichiers racine ---
    New-TestFile 'worker-iter-20260801-101010-1.log'  20   # WorkerIter, eligible (>=14)
    New-TestFile 'worker-iter-20260910-101010-1.log'  2    # WorkerIter, garde
    New-TestFile 'worker-20260801-101010.log'         40   # Regular, eligible
    New-TestFile 'worker-20260910-101010.log'         2    # Regular, garde
    New-TestFile 'executor-20260801-101010.log'       40   # Regular, eligible
    New-TestFile 'coordinator-20260801-101010.log'    40   # Regular, eligible
    New-TestFile 'dashboard-watcher-20260801.log'     40   # Regular, eligible
    New-TestFile 'listener-20260801-101010.log'       40   # Regular, eligible
    New-TestFile 'meta-audit-20260904-101010.log'     8    # Meta, eligible (>=7)
    New-TestFile 'meta-audit-20260910-101010.log'     2    # Meta, garde
    New-TestFile 'env-snapshot.env'                   40   # Env, eligible
    New-TestFile 'worker.lock'                        40   # Lock orphelin, eligible (>=7)
    New-TestFile 'coordinator.lock'                   1    # Lock frais, garde
    New-TestFile 'listener-myia.lastrun'              40   # Lock orphelin, eligible
    New-TestFile 'mystery-trace.bin'                  300  # Unknown, JAMAIS supprime

    Write-Host "=== Test 1: REPORT-ONLY par defaut ===" -ForegroundColor Cyan
    $r1 = Invoke-Rotator
    Assert-Equal "code sortie report = 0" 0 $r1.ExitCode
    Assert-True  "sortie contient [REPORT-ONLY]" ($r1.Output -match '\[REPORT-ONLY\]')
    Assert-True  "sortie annonce 10 eligibles" ($r1.Output -match '\[REPORT-ONLY\] 10 fichier\(s\) eligibles')
    $rootCountAfterReport = @(Get-ChildItem -LiteralPath $Sandbox -File).Count
    Assert-Equal "aucun fichier supprime en report-only (15 restants)" 15 $rootCountAfterReport

    Write-Host ""
    Write-Host "=== Test 2: EXECUTE — suppressions attendues uniquement ===" -ForegroundColor Cyan
    $r2 = Invoke-Rotator @('-Execute')
    Assert-Equal "code sortie execute = 0" 0 $r2.ExitCode
    Assert-True  "sortie confirme 10 supprimes" ($r2.Output -match '10 supprime\(s\), 0 echec\(s\)')
    $survivors = @(Get-ChildItem -LiteralPath $Sandbox -File | ForEach-Object { $_.Name }) | Sort-Object
    # Surviveurs attendus exactement : garde par retention (worker-iter 2j, worker 2j, meta 2j,
    #   lock frais) + Unknown jamais supprime (mystery) = 5 fichiers racine.
    Assert-Equal "exactement 5 survivants racine" 5 $survivors.Count
    Assert-True  "worker-iter frais garde" ($survivors -contains 'worker-iter-20260910-101010-1.log')
    Assert-True  "worker frais garde" ($survivors -contains 'worker-20260910-101010.log')
    Assert-True  "meta frais garde" ($survivors -contains 'meta-audit-20260910-101010.log')
    Assert-True  "lock frais garde" ($survivors -contains 'coordinator.lock')
    Assert-True  "Unknown JAMAIS supprime (300j)" ($survivors -contains 'mystery-trace.bin')
    Assert-True  "sous-repertoire intact (pas de recursion)" (Test-Path -LiteralPath (Join-Path $SubDir 'inner-worker-20200101-000000.log'))

    Write-Host ""
    Write-Host "=== Test 3: post-purge — plus rien d'eligible ===" -ForegroundColor Cyan
    $r3 = Invoke-Rotator
    Assert-Equal "code sortie report post-purge = 0" 0 $r3.ExitCode
    Assert-True  "0 eligible post-purge" ($r3.Output -match '\[REPORT-ONLY\] 0 fichier\(s\) eligibles')

    Write-Host ""
    Write-Host "=== Test 4: LogDir inexistant — sortie propre ===" -ForegroundColor Cyan
    $r4 = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptUnderTest -LogDir (Join-Path $Sandbox 'nexiste-pas') 2>&1 | Out-String
    Assert-Equal "code sortie LogDir absent = 0" 0 $LASTEXITCODE
    Assert-True  "message LogDir absent" ($r4 -match 'LogDir absent')
}
finally {
    if (Test-Path -LiteralPath $Sandbox) {
        Remove-Item -LiteralPath $Sandbox -Recurse -Force
    }
}

Write-Host ""
Write-Host ("RESULT: {0} passed, {1} failed" -f $TestsPassed, $TestsFailed) -ForegroundColor $(if ($TestsFailed -eq 0) { 'Green' } else { 'Red' })
if ($TestsFailed -gt 0) { exit 1 }
exit 0
