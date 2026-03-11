cd mcps/internal/servers/roo-state-manager
npx vitest run 2>&1 | Tee-Object -FilePath test-output.txt | Select-Object -Last 100
Write-Host "Tests completed. Output saved to test-output.txt"
