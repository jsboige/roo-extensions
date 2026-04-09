# Script pour lancer les tests en arrière-plan
cd mcps/internal/servers/roo-state-manager

# Lancer les tests avec redirection de sortie
$npx = Start-Process powershell -ArgumentList "-NoProfile", "-Command", "npx vitest run --maxWorkers=1 --reporter=verbose" -RedirectStandardOutput "C:\tmp\vitest-out.txt" -RedirectStandardError "C:\tmp\vitest-err.txt" -PassThru -Wait

# Attendre la fin des tests
Write-Host "Tests terminés avec le code de sortie: $($npx.ExitCode)"

# Lire les 30 dernières lignes de sortie
Write-Host "=== Dernières lignes de sortie ==="
Get-Content "C:\tmp\vitest-out.txt" -Tail 30

Write-Host "=== Dernières lignes d'erreur ==="
Get-Content "C:\tmp\vitest-err.txt" -Tail 30

# Compter les tests passés et échoués
$output = Get-Content "C:\tmp\vitest-out.txt" -Raw
$passed = ($output | Select-String -Pattern "✓" | Measure-Object).Count
$failed = ($output | Select-String -Pattern "✗" | Measure-Object).Count

Write-Host "=== Résumé ==="
Write-Host "Tests passés: $passed"
Write-Host "Tests échoués: $failed"
