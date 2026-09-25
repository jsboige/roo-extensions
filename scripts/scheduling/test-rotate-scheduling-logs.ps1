<#
.SYNOPSIS
    Tests de rotate-scheduling-logs.ps1 (#3323, #3834) sur bac a sable $TEMP.

.DESCRIPTION
    Valide, sans toucher aux vrais logs :
    - classification par bucket (iter vs worker, meta, env, lock, unknown)
    - retention par bucket (ages limites respectes)
    - Unknown/Env/Lock JAMAIS archives ni supprimes, meme tres anciens (#3834)
    - REPORT-ONLY par defaut (0 suppression sans -Execute)
    - -Execute sans -ArchiveTo REFUSE (decision user 13/09, #3834) — exit 2
    - -ArchiveTo sans -Execute : preview, rien n'est ecrit
    - mode archive-puis-retrait nominal (4 etapes, artefacts, retrait)
    - fichier modifie entre le hachage et le retrait => SAUTE (garde par hash)
    - archive corrompue => ARRET AVANT LE RETRAIT, exit 3, rien supprime
    - 7z explicitement fourni mais introuvable => refus, exit 2
    - idempotence : 2e passage le meme jour => suffixe -HHmmss, pas d'ecrasement
    - pas de recursion (sous-repertoire intact)

    Le script sous test est invoque comme PROCESS (powershell -File), jamais
    dot-source : il a des effets de bord par conception.

    Prerequis machine : 7z resolvable par le script (PATH ou chemins connus
    de la flotte) pour les tests d'archivage.

.NOTES
    Issue : #3323, #3834
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
$ArchiveRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-arch-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

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

$Machine = $env:COMPUTERNAME.ToLower()
$DateStamp = (Get-Date).ToString('yyyy-MM-dd')
$DestDir = Join-Path (Join-Path $ArchiveRoot $Machine) $DateStamp

try {
    New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
    $SubDir = Join-Path $Sandbox 'subdir'
    New-Item -ItemType Directory -Path $SubDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $SubDir 'inner-worker-20200101-000000.log') -Value 'nested'

    # --- Fixtures : 15 fichiers racine ---
    # Eligibles attendus (WorkerIter/Regular/Meta seulement) : 7 fichiers.
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
    New-TestFile 'env-snapshot.env'                   40   # Env, JAMAIS touche (#3834)
    New-TestFile 'worker.lock'                        40   # Lock orphelin, JAMAIS touche (#3834)
    New-TestFile 'coordinator.lock'                   1    # Lock frais, garde
    New-TestFile 'listener-myia.lastrun'              40   # Lock, JAMAIS touche (#3834)
    New-TestFile 'mystery-trace.bin'                  300  # Unknown, JAMAIS supprime

    Write-Host "=== Test 1: REPORT-ONLY par defaut ===" -ForegroundColor Cyan
    $r1 = Invoke-Rotator
    Assert-Equal "code sortie report = 0" 0 $r1.ExitCode
    Assert-True  "sortie contient [REPORT-ONLY]" ($r1.Output -match '\[REPORT-ONLY\]')
    Assert-True  "sortie annonce 7 eligibles" ($r1.Output -match '\[REPORT-ONLY\] 7 fichier\(s\) eligibles')
    Assert-True  "sortie mentionne le refus de suppression nue" ($r1.Output -match '-Execute exige -ArchiveTo')
    Assert-True  "sortie affiche PSVersion (compat 5.1)" ($r1.Output -match 'PowerShell : 5\.')
    $rootCountAfterReport = @(Get-ChildItem -LiteralPath $Sandbox -File).Count
    Assert-Equal "aucun fichier supprime en report-only (15 restants)" 15 $rootCountAfterReport

    Write-Host ""
    Write-Host "=== Test 2: -Execute sans -ArchiveTo => REFUS (decision 13/09) ===" -ForegroundColor Cyan
    $r2 = Invoke-Rotator @('-Execute')
    Assert-Equal "code sortie = 2 (refus)" 2 $r2.ExitCode
    Assert-True  "sortie contient [REFUS]" ($r2.Output -match '\[REFUS\]')
    Assert-True  "sortie cite la decision 13/09" ($r2.Output -match '13/09')
    $rootCountAfterRefusal = @(Get-ChildItem -LiteralPath $Sandbox -File).Count
    Assert-Equal "aucun fichier supprime malgre -Execute (15 restants)" 15 $rootCountAfterRefusal

    Write-Host ""
    Write-Host "=== Test 3: -ArchiveTo sans -Execute => preview, rien d'ecrit ===" -ForegroundColor Cyan
    $r3 = Invoke-Rotator @('-ArchiveTo', $ArchiveRoot)
    Assert-Equal "code sortie preview = 0" 0 $r3.ExitCode
    Assert-True  "sortie contient [PREVIEW]" ($r3.Output -match '\[PREVIEW\]')
    Assert-True  "preview n'ecrit rien sous ArchiveTo" (-not (Test-Path -LiteralPath $ArchiveRoot))
    Assert-Equal "15 fichiers toujours presents" 15 (@(Get-ChildItem -LiteralPath $Sandbox -File).Count)

    Write-Host ""
    Write-Host "=== Test 4: -SevenZip fourni mais introuvable => refus exit 2 ===" -ForegroundColor Cyan
    $r4 = Invoke-Rotator @('-ArchiveTo', $ArchiveRoot, '-SevenZip', 'C:\nowhere\7z.exe')
    Assert-Equal "code sortie = 2 (7z introuvable)" 2 $r4.ExitCode
    Assert-True  "sortie refuse explicitement" ($r4.Output -match '\[REFUS\].*7z introuvable')
    Assert-Equal "15 fichiers toujours presents" 15 (@(Get-ChildItem -LiteralPath $Sandbox -File).Count)

    Write-Host ""
    Write-Host "=== Test 5: ARCHIVE-PUIS-RETRAIT nominal (4 etapes) ===" -ForegroundColor Cyan
    $r5 = Invoke-Rotator @('-ArchiveTo', $ArchiveRoot, '-Execute')
    Assert-Equal "code sortie = 0" 0 $r5.ExitCode
    Assert-True  "etape 1 presente" ($r5.Output -match '\[ETAPE 1/4\]')
    Assert-True  "etape 2 presente (empaquetage)" ($r5.Output -match '\[ETAPE 2/4\] Empaquetage : 7 fichier\(s\)')
    Assert-True  "etape 3 : 7 concordants, 0 discordant/manquant/en trop" ($r5.Output -match '\[ETAPE 3/4\] Extraction : 7 concordant\(s\), 0 discordant\(s\), 0 manquant\(s\), 0 en trop')
    Assert-True  "etape 3 : relecture destination OK" ($r5.Output -match 'Relecture destination OK')
    Assert-True  "etape 4 : 7 supprimes, 0 sautes" ($r5.Output -match '\[ETAPE 4/4\] Retrait : 7 supprime\(s\).*, 0 saute\(s\), 0 echec\(s\)')
    $survivors = @(Get-ChildItem -LiteralPath $Sandbox -File | ForEach-Object { $_.Name }) | Sort-Object
    # Survivants attendus exactement : retenus par retention (worker-iter 2j, worker 2j,
    # meta 2j, lock frais) + jamais touches (mystery, env, worker.lock, lastrun) = 8.
    Assert-Equal "exactement 8 survivants racine" 8 $survivors.Count
    Assert-True  "worker-iter frais garde" ($survivors -contains 'worker-iter-20260910-101010-1.log')
    Assert-True  "worker frais garde" ($survivors -contains 'worker-20260910-101010.log')
    Assert-True  "meta frais garde" ($survivors -contains 'meta-audit-20260910-101010.log')
    Assert-True  "lock frais garde" ($survivors -contains 'coordinator.lock')
    Assert-True  "Unknown JAMAIS supprime (300j)" ($survivors -contains 'mystery-trace.bin')
    Assert-True  "Env JAMAIS supprime (40j, #3834)" ($survivors -contains 'env-snapshot.env')
    Assert-True  "Lock orphelin JAMAIS supprime (40j, #3834)" ($survivors -contains 'worker.lock')
    Assert-True  "lastrun JAMAIS supprime (40j, #3834)" ($survivors -contains 'listener-myia.lastrun')
    Assert-True  "sous-repertoire intact (pas de recursion)" (Test-Path -LiteralPath (Join-Path $SubDir 'inner-worker-20200101-000000.log'))
    # Artefacts dans <ArchiveTo>\<machine>\<date>\ — nommes par archive (#3834)
    $archName = "scheduling-logs-$Machine-$DateStamp.7z"
    $archBase = "scheduling-logs-$Machine-$DateStamp"
    Assert-True  "archive .7z presente" (Test-Path -LiteralPath (Join-Path $DestDir $archName))
    Assert-True  "sidecar .7z.sha256 present" (Test-Path -LiteralPath (Join-Path $DestDir "$archName.sha256"))
    Assert-True  "MANIFEST par archive present" (Test-Path -LiteralPath (Join-Path $DestDir "$archBase.MANIFEST.sha256"))
    Assert-True  "INVENTORY par archive present" (Test-Path -LiteralPath (Join-Path $DestDir "$archBase.INVENTORY.txt"))
    $manifestLines = @([System.IO.File]::ReadAllLines((Join-Path $DestDir "$archBase.MANIFEST.sha256")))
    Assert-Equal "MANIFEST = 7 lignes" 7 $manifestLines.Count
    Assert-True  "ligne de manifeste = sha256  taille  nom" (($manifestLines[0] -split '  ', 3).Count -eq 3)
    $inventoryLines = @([System.IO.File]::ReadAllLines((Join-Path $DestDir "$archBase.INVENTORY.txt")))
    Assert-Equal "INVENTORY = 7 lignes" 7 $inventoryLines.Count
    Assert-True  "ligne d'inventaire commence par un bucket connu" ($inventoryLines[0] -match '^(WorkerIter|Regular|Meta)\t')

    Write-Host ""
    Write-Host "=== Test 6: idempotence — 2e passage meme jour, suffixe sans ecrasement ===" -ForegroundColor Cyan
    $FirstArchive = Join-Path $DestDir $archName
    $FirstHash = (Get-FileHash -LiteralPath $FirstArchive -Algorithm SHA256).Hash
    New-TestFile 'worker-20260101-101010.log' 100   # redevient eligible
    $r6 = Invoke-Rotator @('-ArchiveTo', $ArchiveRoot, '-Execute')
    Assert-Equal "code sortie 2e passage = 0" 0 $r6.ExitCode
    Assert-True  "suffixe -HHmmss annonce/pose" ($r6.Output -match 'suffixe pose, sans ecrasement')
    Assert-True  "archive d'origine INTACTE (hash inchange)" ((Get-FileHash -LiteralPath $FirstArchive -Algorithm SHA256).Hash -eq $FirstHash)
    $archives = @(Get-ChildItem -LiteralPath $DestDir -Filter '*.7z' -File)
    Assert-Equal "2 archives dans la journee (originale + suffixee)" 2 $archives.Count
    Assert-True  "le nouveau fichier eligible a bien ete archive puis retire" (-not (Test-Path -LiteralPath (Join-Path $Sandbox 'worker-20260101-101010.log')))
    # Les artefacts etant nommes par archive, le manifeste de la 1re archive decrit
    # toujours ses 7 fichiers, et celui de la suffixee decrit le delta (1 fichier).
    $manifestFirst = @([System.IO.File]::ReadAllLines((Join-Path $DestDir "$archBase.MANIFEST.sha256")))
    Assert-Equal "manifeste de la 1re archive intact (7 lignes)" 7 $manifestFirst.Count
    $suffixed = @($archives | Where-Object { $_.Name -ne $archName })
    $suffixedBase = [System.IO.Path]::GetFileNameWithoutExtension($suffixed[0].Name)
    $manifestSecond = @([System.IO.File]::ReadAllLines((Join-Path $DestDir "$suffixedBase.MANIFEST.sha256")))
    Assert-Equal "manifeste de l'archive suffixee = 1 ligne (delta seul)" 1 $manifestSecond.Count

    Write-Host ""
    Write-Host "=== Test 7: fichier modifie entre hachage et retrait => SAUTE ===" -ForegroundColor Cyan
    $Sandbox7 = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-t7-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $ArchiveRoot7 = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-a7-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        New-Item -ItemType Directory -Path $Sandbox7 -Force | Out-Null
        foreach ($n in @('worker-20260801-101010.log', 'executor-20260801-101010.log')) {
            $p = Join-Path $Sandbox7 $n
            Set-Content -LiteralPath $p -Value 'contenu-original'
            (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-40)
        }
        $allArgs7 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptUnderTest, '-LogDir', $Sandbox7, '-ArchiveTo', $ArchiveRoot7, '-Execute', '-TestHook', 'mutate:worker-20260801-101010.log')
        $out7 = & powershell.exe @allArgs7 2>&1 | Out-String
        $rc7 = $LASTEXITCODE
        Assert-Equal "code sortie = 0 (saut = comportement attendu, pas un echec)" 0 $rc7
        Assert-True  "sortie annonce le saut pour hash divergent" ($out7 -match 'Saut \(hash divergent')
        Assert-True  "1 supprime, 1 saute" ($out7 -match '1 supprime\(s\).*, 1 saute\(s\)')
        Assert-True  "fichier modifie TOUJOURS PRESENT" (Test-Path -LiteralPath (Join-Path $Sandbox7 'worker-20260801-101010.log'))
        Assert-True  "fichier non modifie supprime" (-not (Test-Path -LiteralPath (Join-Path $Sandbox7 'executor-20260801-101010.log')))
        Assert-True  "contenu du fichier saute = contenu mute" ((Get-Content -LiteralPath (Join-Path $Sandbox7 'worker-20260801-101010.log') -Raw) -match 'mutated-after-packing')
    } finally {
        if (Test-Path -LiteralPath $Sandbox7) { Remove-Item -LiteralPath $Sandbox7 -Recurse -Force }
        if (Test-Path -LiteralPath $ArchiveRoot7) { Remove-Item -LiteralPath $ArchiveRoot7 -Recurse -Force }
    }

    Write-Host ""
    Write-Host "=== Test 8: archive corrompue => ARRET AVANT LE RETRAIT, exit 3 ===" -ForegroundColor Cyan
    $Sandbox8 = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-t8-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $ArchiveRoot8 = Join-Path ([System.IO.Path]::GetTempPath()) ("rotate-logs-a8-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        New-Item -ItemType Directory -Path $Sandbox8 -Force | Out-Null
        foreach ($n in @('worker-20260801-101010.log', 'meta-audit-20260901-101010.log')) {
            $p = Join-Path $Sandbox8 $n
            Set-Content -LiteralPath $p -Value 'contenu-original'
            (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-40)
        }
        $allArgs8 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptUnderTest, '-LogDir', $Sandbox8, '-ArchiveTo', $ArchiveRoot8, '-Execute', '-TestHook', 'corrupt-archive')
        $out8 = & powershell.exe @allArgs8 2>&1 | Out-String
        $rc8 = $LASTEXITCODE
        Assert-Equal "code sortie = 3 (divergence integrite)" 3 $rc8
        Assert-True  "arret annonce AVANT le retrait" ($out8 -match 'ARRET AVANT LE RETRAIT, aucun fichier supprime')
        # La branche qui detecte la corruption depend du build 7z : certains
        # tolerent les octets ajoutes en fin d'archive (7z t/extraction passent)
        # et c'est alors la RELECTURE DESTINATION (hash vs sidecar) qui arrete.
        Assert-True  "detecte comme divergence d'integrite (t/extraction/relecture)" ($out8 -match 'archive corrompue|extraction 7z echouee|relecture destination')
        Assert-True  "message DIVERGENCE present" ($out8 -match 'DIVERGENCE')
        Assert-True  "AUCUN fichier supprime (les 2 restent)" ((@(Get-ChildItem -LiteralPath $Sandbox8 -File).Count) -eq 2)
        Assert-True  "aucune etape 4 dans la sortie" ($out8 -notmatch '\[ETAPE 4/4\]')
    } finally {
        if (Test-Path -LiteralPath $Sandbox8) { Remove-Item -LiteralPath $Sandbox8 -Recurse -Force }
        if (Test-Path -LiteralPath $ArchiveRoot8) { Remove-Item -LiteralPath $ArchiveRoot8 -Recurse -Force }
    }

    Write-Host ""
    Write-Host "=== Test 9: post-purge — plus rien d'eligible ===" -ForegroundColor Cyan
    $r9 = Invoke-Rotator
    Assert-Equal "code sortie report post-purge = 0" 0 $r9.ExitCode
    Assert-True  "0 eligible post-purge" ($r9.Output -match '\[REPORT-ONLY\] 0 fichier\(s\) eligibles')

    Write-Host ""
    Write-Host "=== Test 10: LogDir inexistant — sortie propre ===" -ForegroundColor Cyan
    $r10 = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptUnderTest -LogDir (Join-Path $Sandbox 'nexiste-pas') 2>&1 | Out-String
    Assert-Equal "code sortie LogDir absent = 0" 0 $LASTEXITCODE
    Assert-True  "message LogDir absent" ($r10 -match 'LogDir absent')
}
finally {
    if (Test-Path -LiteralPath $Sandbox) {
        Remove-Item -LiteralPath $Sandbox -Recurse -Force
    }
    if (Test-Path -LiteralPath $ArchiveRoot) {
        Remove-Item -LiteralPath $ArchiveRoot -Recurse -Force
    }
}

Write-Host ""
Write-Host ("RESULT: {0} passed, {1} failed" -f $TestsPassed, $TestsFailed) -ForegroundColor $(if ($TestsFailed -eq 0) { 'Green' } else { 'Red' })
if ($TestsFailed -gt 0) { exit 1 }
exit 0
