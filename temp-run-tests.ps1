Set-Location "mcps/internal/servers/roo-state-manager"
$output = npx vitest run 2>&1
$output | Out-File "test-output.txt"
$output | Select-Object -Last 50
