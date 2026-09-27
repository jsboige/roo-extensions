<#
.SYNOPSIS
    Purge accumulated artifacts from GDrive .shared-state/ (#2121 Phase 2)
.DESCRIPTION
    One-shot cleanup of 3 artifact categories:
    1. configs/ci-test-machine/     — Full purge (CI test residuals)
    2. configs/test-machine-custom/ — Full purge (integration test residuals)
    3. reports/PHASE3A-ANALYSE-*    — Purge older than 7 days (meta-analyst output)

    Approved by user mandate 2026-05-17 ~21:30Z.

    SECURITE (audit 27/09, dispatch ai-01 16:05Z) :
    - DRY-RUN PAR DEFAUT : sans -Execute, le script liste sans rien toucher.
    - Avec -Execute : DEPLACEMENT vers une quarantaine LOCALE (jamais sur G:, quota
      sature — le deplacement libere le quota contrairement a un _trash sur G:).
      Chaque fichier est empreinte SHA-256 dans manifest.json avant le move.
      Restaurer = copier depuis la quarantaine vers le chemin "original" du manifeste.
    - Si les deux -Execute ET -DryRun sont passes, -DryRun gagne (conservateur).
.PARAMETER DryRun
    Show what would be quarantined without touching anything. Now the default
    behavior; the switch is kept for documented invocations.
.PARAMETER Execute
    Actually quarantine the files (move to local quarantine + SHA-256 manifest).
.PARAMETER QuarantineRoot
    Quarantine root (default: %LOCALAPPDATA%\roo-extensions-quarantine\shared-state-purge).
.PARAMETER SharedStatePath
    Override the shared-state path (default: auto-detected from GDrive sync).
.EXAMPLE
    .\purge-shared-state-artifacts.ps1
    .\purge-shared-state-artifacts.ps1 -DryRun
    .\purge-shared-state-artifacts.ps1 -Execute
#>
param(
    [switch]$DryRun,
    [switch]$Execute,
    [string]$QuarantineRoot,
    [string]$SharedStatePath
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common\quarantine.ps1"

# Auto-detect shared-state path
if (-not $SharedStatePath) {
    $gdrivePaths = @(
        'G:\Mon Drive\Synchronisation\RooSync\.shared-state',
        'D:\Mon Drive\Synchronisation\RooSync\.shared-state'
    )
    foreach ($p in $gdrivePaths) {
        if (Test-Path $p) {
            $SharedStatePath = $p
            break
        }
    }
    if (-not $SharedStatePath) {
        Write-Error "Cannot find GDrive .shared-state/ directory. Pass -SharedStatePath explicitly."
        exit 1
    }
}

if (-not (Test-Path $SharedStatePath)) {
    Write-Error "Shared-state path not found: $SharedStatePath"
    exit 1
}

$totalDeleted = 0
$totalSize = 0
$retentionDays = 7
$cutoffDate = (Get-Date).AddDays(-$retentionDays)
$mode = if ($Execute -and -not $DryRun) { 'EXECUTE (quarantine)' } else { 'DRY-RUN' }
$qDir = $null
$manifest = [System.Collections.Generic.List[object]]::new()

Write-Host "=== GDrive .shared-state/ Purge (#2121 Phase 2) ==="
Write-Host "Path: $SharedStatePath"
Write-Host "Mode: $mode"
Write-Host "Reports retention: $retentionDays days (before $($cutoffDate.ToString('yyyy-MM-dd')))"
Write-Host ""

if ($Execute -and -not $DryRun) {
    if (-not $QuarantineRoot) {
        $QuarantineRoot = Join-Path $env:LOCALAPPDATA "roo-extensions-quarantine\shared-state-purge"
    }
    $qDir = New-QuarantineDir -Root $QuarantineRoot
    Write-Host "Quarantine: $qDir"
    Write-Host ""
}

# Deplace la liste de fichiers DONNEE vers la quarantaine (structure relative
# preservee), puis, sur demande, retire les repertoires devenus PROUVEMENT vides
# (0 fichier restant) — jamais plus large que la racine passee en argument.
function Move-CategoryToQuarantine {
    param(
        [object[]]$Files,
        [string]$RelativeBase,
        [string]$SweepRoot = ''
    )
    $moved = 0
    $failed = 0
    foreach ($file in @($Files)) {
        $ok = Move-FileToQuarantine -LiteralPath $file.FullName -QuarantineDir $qDir `
            -RelativeBase $RelativeBase -Manifest $manifest
        if ($ok) { $moved++ } else { $failed++ }
    }
    if ($SweepRoot -and $failed -eq 0) {
        Get-ChildItem -Path $SweepRoot -Directory -Recurse -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    return @{ Moved = $moved; Failed = $failed }
}

# --- Category 1: configs/ci-test-machine/ (FULL PURGE) ---
$ciTestPath = Join-Path $SharedStatePath 'configs\ci-test-machine'
if (Test-Path $ciTestPath) {
    $items = Get-ChildItem $ciTestPath -Recurse -File -ErrorAction SilentlyContinue
    $count = ($items | Measure-Object).Count
    $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Write-Host "[1/3] configs/ci-test-machine/ — $count files, $([math]::Round($size / 1MB, 2)) MB (FULL PURGE)"

    if ($count -gt 0) {
        if ($Execute -and -not $DryRun) {
            $files = @(Get-ChildItem -Path $ciTestPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'desktop.ini' })
            $r = Move-CategoryToQuarantine -Files $files -RelativeBase $ciTestPath -SweepRoot $ciTestPath
            Write-Host "       QUARANTINED $($r.Moved) files (desktop.ini kept)"
            $totalDeleted += $r.Moved
        } else {
            Write-Host "       DRY-RUN: Would quarantine $count files (desktop.ini kept)"
            $totalDeleted += $count
        }
        $totalSize += $size
    }
} else {
    Write-Host "[1/3] configs/ci-test-machine/ — NOT FOUND (skip)"
}

# --- Category 2: configs/test-machine-custom/ (FULL PURGE) ---
$testCustomPath = Join-Path $SharedStatePath 'configs\test-machine-custom'
if (Test-Path $testCustomPath) {
    $items = Get-ChildItem $testCustomPath -Recurse -File -ErrorAction SilentlyContinue
    $count = ($items | Measure-Object).Count
    $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Write-Host "[2/3] configs/test-machine-custom/ — $count files, $([math]::Round($size / 1MB, 2)) MB (FULL PURGE)"

    if ($count -gt 0) {
        if ($Execute -and -not $DryRun) {
            $files = @(Get-ChildItem -Path $testCustomPath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne 'desktop.ini' -and $_.Name -ne 'latest.json' })
            $r = Move-CategoryToQuarantine -Files $files -RelativeBase $testCustomPath -SweepRoot $testCustomPath
            Write-Host "       QUARANTINED $($r.Moved) files (desktop.ini, latest.json kept)"
            $totalDeleted += $r.Moved
        } else {
            Write-Host "       DRY-RUN: Would quarantine $count files (desktop.ini, latest.json kept)"
            $totalDeleted += $count
        }
        $totalSize += $size
    }
} else {
    Write-Host "[2/3] configs/test-machine-custom/ — NOT FOUND (skip)"
}

# --- Category 3: reports/PHASE3A-ANALYSE-* (7-day retention) ---
$reportsPath = Join-Path $SharedStatePath 'reports'
if (Test-Path $reportsPath) {
    $oldReports = Get-ChildItem $reportsPath -Filter 'PHASE3A-ANALYSE-*.md' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate }

    $count = ($oldReports | Measure-Object).Count
    $size = ($oldReports | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

    $allReports = Get-ChildItem $reportsPath -Filter 'PHASE3A-ANALYSE-*.md' -File -ErrorAction SilentlyContinue
    $totalCount = ($allReports | Measure-Object).Count
    $keepCount = $totalCount - $count

    Write-Host "[3/3] reports/PHASE3A-ANALYSE-* — $totalCount total, $count older than $retentionDays days ($keepCount kept)"

    if ($count -gt 0) {
        if ($Execute -and -not $DryRun) {
            $r = Move-CategoryToQuarantine -Files @($oldReports) -RelativeBase $reportsPath
            Write-Host "       QUARANTINED $($r.Moved) files, kept $keepCount"
            $totalDeleted += $r.Moved
        } else {
            Write-Host "       DRY-RUN: Would quarantine $count files, keep $keepCount"
            $totalDeleted += $count
        }
        $totalSize += $size
    }
} else {
    Write-Host "[3/3] reports/ — NOT FOUND (skip)"
}

# --- Summary ---
if ($qDir) {
    Write-QuarantineManifest -QuarantineDir $qDir -Manifest $manifest
}
Write-Host ""
Write-Host "=== Summary ==="
if ($qDir) {
    Write-Host "Quarantined files: $totalDeleted (manifest: $qDir\manifest.json)"
    Write-Host "Nothing was deleted — purge is a manual gesture AFTER verifying the manifest."
} else {
    Write-Host "Total files would be quarantined: $totalDeleted"
}
Write-Host "Total size freed from shared-state: $([math]::Round($totalSize / 1MB, 2)) MB"
Write-Host "Mode: $mode"
