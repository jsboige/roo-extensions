# Script pour exécuter les tests unitaires en arrière-plan
cd c:/dev/roo-extensions/mcps/internal/servers/roo-state-manager

$outputFile = "test-output.txt"
$startTime = Get-Date

Write-Host "Début des tests à $startTime"

# Exécuter les tests avec redirection vers fichier
npx vitest run --maxWorkers=1 2>&1 | Out-File -FilePath $outputFile -Encoding utf8

$endTime = Get-Date
$duration = New-TimeSpan -Start $startTime -End $endTime

Write-Host "Tests terminés à $endTime"
Write-Host "Durée : $duration"
Write-Host "Résultats dans $outputFile"
