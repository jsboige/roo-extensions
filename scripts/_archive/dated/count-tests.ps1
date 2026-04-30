cd d:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager
$content = Get-Content test-output.log -Raw
# Supprimer les codes ANSI
$cleanContent = $content -replace '\x1b\[[0-9;]*[mK]', ''

# Compter les tests passés (lignes avec ✓ et nombre de tests)
$passedMatches = [regex]::Matches($cleanContent, '✓.*?\((\d+) tests\)')
$passedCount = 0
foreach ($m in $passedMatches) {
    $passedCount += [int]$m.Groups[1].Value
}

# Compter les tests échoués
$failedMatches = [regex]::Matches($cleanContent, '❯.*?\((\d+) tests.*?\|.*?(\d+) failed\)')
$failedCount = 0
foreach ($m in $failedMatches) {
    $failedCount += [int]$m.Groups[2].Value
}

# Compter les tests skipés
$skippedMatches = [regex]::Matches($cleanContent, '\((\d+) tests\s*\|\s*(\d+) skipped\)')
$skippedCount = 0
foreach ($m in $skippedMatches) {
    $skippedCount += [int]$m.Groups[2].Value
}

Write-Host "=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total: $($passedCount + $failedCount)" -ForegroundColor White
Write-Host "Passed: $passedCount" -ForegroundColor Green
Write-Host "Failed: $failedCount" -ForegroundColor Red
Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow
