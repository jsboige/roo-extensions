# Script pour exécuter les tests vitest en arrière-plan
cd mcps/internal/servers/roo-state-manager

# Exécuter les tests et capturer le résultat
$output = npx vitest run --maxWorkers=1 2>&1
$output | Out-File -FilePath C:\temp\vitest-result.txt -Encoding utf8

# Extraire le résumé (dernières lignes)
$lastLines = $output | Select-Object -Last 50
$lastLines | Out-File -FilePath C:\temp\vitest-summary.txt -Encoding utf8

# Afficher le statut de sortie
if ($LASTEXITCODE -eq 0) {
    "TESTS: PASS" | Out-File -FilePath C:\temp\vitest-status.txt -Encoding utf8
} else {
    "TESTS: FAIL" | Out-File -FilePath C:\temp\vitest-status.txt -Encoding utf8
}
