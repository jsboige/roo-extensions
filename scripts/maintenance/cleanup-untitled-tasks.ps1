# Cleanup Untitled Tasks — Script de nettoyage des entrées "Untitled Task"
# Issue #1173: MINOR: 6 orphaned task entries detected on myia-ai-01
#
# Ce script met en quarantaine les entrees "Untitled Task" (taches orphelines creees
# par erreur) du stockage local des taches Roo Code.
#
# SECURITE (audit 27/09, dispatch ai-01 16:05Z) :
#   - DRY-RUN PAR DEFAUT : sans -Execute, le script liste sans rien toucher.
#   - Avec -Execute : DEPLACEMENT vers la quarantaine (jamais de suppression) —
#     chaque fichier est empreinte SHA-256 dans manifest.json avant le move.
#     Restaurer = copier depuis la quarantaine vers le chemin "original" du manifeste.
#
# Usage : .\scripts\maintenance\cleanup-untitled-tasks.ps1 [-Execute] [-QuarantineRoot <dir>] [-Verbose]

param(
    [switch]$DryRun,
    [switch]$Execute,
    [string]$QuarantineRoot,
    [switch]$Verbose
)

. "$PSScriptRoot\..\common\extension-paths.ps1"
. "$PSScriptRoot\..\common\quarantine.ps1"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "=== Cleanup Untitled Tasks ===" -ForegroundColor Cyan
Write-Host "Issue #1173: MINOR: 6 orphaned task entries detected on myia-ai-01" -ForegroundColor Yellow
Write-Host ""

# Détection du stockage Roo
# Get-GlobalStoragePath uses APPDATA (Roaming); LOCALAPPDATA checked separately
$rooDataPaths = @(
    (Join-Path (Get-GlobalStoragePath -Extension RooCode) "data"),
    (Join-Path (Join-Path $env:LOCALAPPDATA "Code\User\globalStorage\$RooExtensionId") "data")
)

$tasksToDelete = @()

# Recherche des tâches "Untitled Task" dans le répertoire de données
foreach ($dataPath in $rooDataPaths) {
    if (Test-Path $dataPath) {
        Write-Host "Scanning: $dataPath" -ForegroundColor Green
        
        $taskDirs = Get-ChildItem -Path $dataPath -Directory -ErrorAction SilentlyContinue
        
        foreach ($taskDir in $taskDirs) {
            $isUntitled = $false
            
            # Vérifier si le nom du répertoire contient "Untitled"
            if ($taskDir.Name -like "*Untitled*" -or $taskDir.Name -like "*Untitled Task*") {
                $isUntitled = $true
            }
            
            # Vérifier aussi dans le fichier ui_messages.json pour le titre
            if (-not $isUntitled) {
                $uiMessagesFile = Join-Path $taskDir.FullName "ui_messages.json"
                if (Test-Path $uiMessagesFile) {
                    try {
                        $uiContent = Get-Content $uiMessagesFile -Raw -ErrorAction SilentlyContinue
                        if ($uiContent -match '"title"\s*:\s*"Untitled Task"') {
                            $isUntitled = $true
                        }
                    } catch {
                        if ($Verbose) {
                            $errorMsg = $Error[0].Exception.Message
                            Write-Host "  Error reading $($taskDir.FullName): $errorMsg" -ForegroundColor Red
                        }
                    }
                }
            }
            
            if ($isUntitled) {
                $tasksToDelete += $taskDir.FullName
                Write-Host "  Found: $($taskDir.Name)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Tasks to delete: $($tasksToDelete.Count)" -ForegroundColor $(if ($tasksToDelete.Count -gt 0) { "Yellow" } else { "Green" })

if ($tasksToDelete.Count -eq 0) {
    Write-Host "No Untitled Task entries found. Cleanup complete." -ForegroundColor Green
    exit 0
}

Write-Host ""
if (-not $Execute -or $DryRun) {
    if ($Execute -and $DryRun) {
        Write-Host "[DRY RUN] -DryRun wins over -Execute (conservative default)." -ForegroundColor Cyan
    }
    Write-Host "[DRY RUN] Would quarantine the following tasks (dry-run is the default):" -ForegroundColor Cyan
    foreach ($task in $tasksToDelete) {
        Write-Host "  - $task" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "[DRY RUN] No files were touched. Re-run with -Execute to quarantine." -ForegroundColor Cyan
} else {
    if (-not $QuarantineRoot) {
        $QuarantineRoot = Join-Path $env:LOCALAPPDATA "roo-extensions-quarantine\untitled-tasks"
    }
    $qDir = New-QuarantineDir -Root $QuarantineRoot
    $manifest = [System.Collections.Generic.List[object]]::new()

    Write-Host "Quarantining $($tasksToDelete.Count) task(s) to: $qDir" -ForegroundColor Cyan

    foreach ($task in $tasksToDelete) {
        $dataPath = Split-Path -Parent $task
        $files = @(Get-ChildItem -Path $task -Recurse -File -Force -ErrorAction SilentlyContinue)
        $moved = 0
        $failed = 0
        foreach ($file in $files) {
            $ok = Move-FileToQuarantine -LiteralPath $file.FullName -QuarantineDir $qDir `
                -RelativeBase $dataPath -Manifest $manifest
            if ($ok) { $moved++ } else { $failed++ }
        }
        # Coque vide prouvee (0 fichier restant) : retrait autorise ; sinon KEPT.
        # Recomptage a l'instant du geste (follow-up #3907 review ai-01) :
        # l'enum initiale a pu mentir par omission, ou un fichier est ne entre
        # les deux — la coquille ne part que sur enumeration reussie ET vide.
        if ($failed -eq 0) {
            $remaining = -1
            try { $remaining = @(Get-ChildItem -Path $task -Recurse -File -Force -ErrorAction Stop).Count } catch { }
            if ($remaining -ne 0) {
                Write-Host "  PARTIAL ($moved moved, husk not provably empty — $remaining file(s)) : $task — manual review" -ForegroundColor Yellow
            } else {
                Remove-Item -Path $task -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Quarantined ($moved files): $task" -ForegroundColor Green
            }
        } else {
            Write-Host "  PARTIAL ($moved moved, $failed left in place): $task — manual review" -ForegroundColor Yellow
        }
    }

    Write-QuarantineManifest -QuarantineDir $qDir -Manifest $manifest
    Write-Host ""
    Write-Host "Quarantine complete. $($manifest.Count) file(s) moved, manifest: $qDir\manifest.json" -ForegroundColor Green
}

exit 0
