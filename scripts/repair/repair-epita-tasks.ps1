# Script de réparation simple pour les tâches "2025-Epita-Intelligence-Symbolique"
param(
    [switch]$WhatIf = $false
)

# Configuration
$oldPath = "c:/dev/2025-Epita-Intelligence-Symbolique"
$newPath = "d:/dev/2025-Epita-Intelligence-Symbolique"
$searchPattern = "*2025-Epita-Intelligence-Symbolique*"

Write-Host "=== Script de Réparation des Tâches Epita ===" -ForegroundColor Cyan
Write-Host "Ancien chemin: $oldPath" -ForegroundColor Yellow
Write-Host "Nouveau chemin: $newPath" -ForegroundColor Green
Write-Host "Mode simulation: $WhatIf" -ForegroundColor Magenta
Write-Host ""
# Localiser le répertoire de stockage Roo
$rooStorageLocations = @(
    "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks",
    "$env:APPDATA\Roo-Code\.tasks",
    "$env:LOCALAPPDATA\Roo-Code\.tasks",
    "$env:USERPROFILE\.roo-code\.tasks"
)

$storageDir = $null
foreach ($location in $rooStorageLocations) {
    if (Test-Path $location) {
        $storageDir = $location
        break
    }
}

if (-not $storageDir) {
    Write-Error "Aucun répertoire de stockage Roo trouvé dans les emplacements: $($rooStorageLocations -join ', ')"
    exit 1
}

Write-Host "Répertoire de stockage Roo: $storageDir" -ForegroundColor Green

# Chercher les tâches avec des références à l'ancien chemin
$taskDirs = Get-ChildItem -Path $storageDir -Directory | Where-Object {
    $_.Name -match "^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$"
}

$repairedCount = 0
$errorCount = 0

foreach ($taskDir in $taskDirs) {
    $apiHistoryFile = Join-Path $taskDir.FullName "api_conversation_history.json"
    
    if (-not (Test-Path $apiHistoryFile)) {
        continue
    }
    
    try {
        # Lire le fichier JSON
        $jsonContent = Get-Content -Path $apiHistoryFile -Raw -Encoding UTF8
        
        # Vérifier si le fichier contient l'ancien chemin
        if ($jsonContent -match [regex]::Escape($oldPath)) {
            Write-Host "Tâche trouvée: $($taskDir.Name)" -ForegroundColor Yellow
            
            # Remplacer l'ancien chemin par le nouveau
            $updatedContent = $jsonContent -replace [regex]::Escape($oldPath), $newPath
            
            if ($WhatIf) {
                Write-Host "  [SIMULATION] Remplacerait '$oldPath' par '$newPath'" -ForegroundColor Cyan
            } else {
                # Créer une sauvegarde
                $backupFile = "$apiHistoryFile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $apiHistoryFile $backupFile
                
                # Écrire le contenu mis à jour
                Set-Content -Path $apiHistoryFile -Value $updatedContent -Encoding UTF8
                Write-Host "  [RÉPARÉ] Chemin mis à jour (sauvegarde: $(Split-Path -Leaf $backupFile))" -ForegroundColor Green
            }
            
            $repairedCount++
        }
    }
    catch {
        Write-Warning "Erreur lors du traitement de $($taskDir.Name): $($_.Exception.Message)"
        $errorCount++
    }
}

Write-Host ""
Write-Host "=== Résumé ===" -ForegroundColor Cyan
Write-Host "Tâches réparées: $repairedCount" -ForegroundColor Green
Write-Host "Erreurs: $errorCount" -ForegroundColor Red
Write-Host "Mode: $(if ($WhatIf) { 'SIMULATION' } else { 'RÉPARATION RÉELLE' })" -ForegroundColor Magenta

if ($repairedCount -gt 0 -and -not $WhatIf) {
    Write-Host ""
    Write-Host "✅ Les tâches ont été réparées. Redémarrez VS Code pour voir les changements." -ForegroundColor Green
}