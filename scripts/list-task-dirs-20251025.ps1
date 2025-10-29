# Script pour lister les tâches récentes et analyser le format des IDs
$tasksPath = Join-Path $env:APPDATA "Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"

Write-Host "=== ANALYSE DES TÂCHES ===" -ForegroundColor Cyan
Write-Host "Répertoire de stockage:" -ForegroundColor Yellow
Write-Host $tasksPath -ForegroundColor White
Write-Host ""

if (-not (Test-Path $tasksPath)) {
    Write-Host "ERREUR: Le répertoire des tâches n'existe pas!" -ForegroundColor Red
    exit 1
}

Write-Host "Recherche de tâches du 25 octobre 2025 (format YYYYMMDD)..." -ForegroundColor Cyan
$tasks2025 = Get-ChildItem -Path $tasksPath -Directory | Where-Object { $_.Name -like "20251025*" }

if ($tasks2025.Count -eq 0) {
    Write-Host "Aucune tâche avec format YYYYMMDD trouvée pour le 25/10/2025" -ForegroundColor Yellow
} else {
    Write-Host "Tâches trouvées (format YYYYMMDD):" -ForegroundColor Green
    $tasks2025 | Sort-Object CreationTime -Descending | Format-Table Name, CreationTime, LastWriteTime -AutoSize
}

Write-Host ""
Write-Host "=== 20 DERNIÈRES TÂCHES (TOUS FORMATS) ===" -ForegroundColor Cyan
$allTasks = Get-ChildItem -Path $tasksPath -Directory | Sort-Object CreationTime -Descending | Select-Object -First 20

$counter = 1
foreach ($task in $allTasks) {
    Write-Host ("{0,2}. " -f $counter) -NoNewline -ForegroundColor Gray
    Write-Host $task.Name -NoNewline -ForegroundColor White
    Write-Host " | Créé: " -NoNewline -ForegroundColor Gray
    Write-Host $task.CreationTime.ToString("yyyy-MM-dd HH:mm:ss") -NoNewline -ForegroundColor Cyan
    Write-Host " | Modifié: " -NoNewline -ForegroundColor Gray
    Write-Host $task.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor Yellow
    $counter++
}

Write-Host ""
Write-Host "=== STATISTIQUES ===" -ForegroundColor Cyan
Write-Host "Total de tâches: $($allTasks.Count)" -ForegroundColor White