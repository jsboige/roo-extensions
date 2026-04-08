# Cleanup Untitled Tasks — Script de suppression des entrées "Untitled Task"
# Issue #1173: MINOR: 6 orphaned task entries detected on myia-ai-01
#
# Ce script supprime les entrées "Untitled Task" (tâches orphelines créées par erreur)
# du stockage local des tâches Roo Code.
#
# Usage : .\scripts\maintenance\cleanup-untitled-tasks.ps1 [-DryRun] [-Verbose]

param(
    [switch]$DryRun,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "=== Cleanup Untitled Tasks ===" -ForegroundColor Cyan
Write-Host "Issue #1173: MINOR: 6 orphaned task entries detected on myia-ai-01" -ForegroundColor Yellow
Write-Host ""

# Détection du stockage Roo
$rooDataPaths = @(
    (Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\data"),
    (Join-Path $env:LOCALAPPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\data")
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
if ($DryRun) {
    Write-Host "[DRY RUN] Would delete the following tasks:" -ForegroundColor Cyan
    foreach ($task in $tasksToDelete) {
        Write-Host "  - $task" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "[DRY RUN] No files were actually deleted." -ForegroundColor Cyan
} else {
    Write-Host "Deleting $($tasksToDelete.Count) task(s)..." -ForegroundColor Cyan
    
    foreach ($task in $tasksToDelete) {
        try {
            Remove-Item -Path $task -Recurse -Force -ErrorAction Stop
            Write-Host "  Deleted: $task" -ForegroundColor Green
        } catch {
            $errorMsg = $Error[0].Exception.Message
            $msg = "Error deleting $task"
            $msg = $msg + ": " + $errorMsg
            Write-Host $msg -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Cleanup complete. Deleted $($tasksToDelete.Count) task(s)." -ForegroundColor Green
}

exit 0
