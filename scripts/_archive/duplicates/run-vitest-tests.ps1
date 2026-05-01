cd mcps/internal/servers/roo-state-manager
npx vitest run --no-coverage 2>&1 | Out-File -FilePath "outputs\test-results.txt" -Encoding utf8
Get-Content "outputs\test-results.txt" | Select-Object -Last 50
