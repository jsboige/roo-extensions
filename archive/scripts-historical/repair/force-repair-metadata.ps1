[CmdletBinding()]
param()

# Détecter le chemin de stockage Roo
$storagePath = Join-Path $env:APPDATA 'Code\User\globalStorage\rooveterinaryinc.roo-cline'
$tasksPath = Join-Path $storagePath 'tasks'

if (-not (Test-Path -Path $tasksPath -PathType Container)) {
    Write-Error "Le répertoire des tâches est introuvable à l'emplacement : $tasksPath"
    exit 1
}

$taskDirs = Get-ChildItem -Path $tasksPath -Directory

$repairedCount = 0

foreach ($taskDir in $taskDirs) {
    $metadataPath = Join-Path -Path $taskDir.FullName -ChildPath 'task_metadata.json'
    if (-not (Test-Path -Path $metadataPath -PathType Leaf)) {
        Write-Host "Métadonnées manquantes pour $($taskDir.Name). Recréation..."
        '{}' | Set-Content -Path $metadataPath -Encoding UTF8 -Force
        $repairedCount++
    }
}

Write-Host "Réparation terminée. $repairedCount fichier(s) de métadonnées ont été recréés."