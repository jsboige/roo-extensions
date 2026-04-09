# Script pour exécuter les tests vitest en arrière-plan sur myia-web1
# Utilise un timeout plus long et capture le résultat dans un fichier

$startTime = Get-Date
$outputFile = "mcps/internal/servers/roo-state-manager/vitest-results.txt"

# Exécuter les tests avec redirection vers fichier
Set-Location "mcps/internal/servers/roo-state-manager"
npx vitest run --maxWorkers=1 > $outputFile 2>&1
$exitCode = $LASTEXITCODE

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# Afficher le résultat et les dernières lignes
Write-Host "=== TESTS COMPLETED ===" -ForegroundColor Cyan
Write-Host "Exit Code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
Write-Host "Duration: $duration seconds" -ForegroundColor Yellow
Write-Host "Output file: $outputFile" -ForegroundColor Gray
Write-Host ""
Write-Host "=== LAST 30 LINES ===" -ForegroundColor Cyan
Get-Content $outputFile -Tail 30

# Retourner le statut
exit $exitCode
