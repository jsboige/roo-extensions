# Run Vitest in Background - myia-web1 specific workaround
# Workaround for 180s timeout when running tests via win-cli MCP

$ErrorActionPreference = "Continue"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = "$PSScriptRoot\test-results-web1-$Timestamp.txt"

Write-Host "Starting Vitest in background mode..."
Write-Host "Results will be saved to: $LogFile"

cd $PSScriptRoot\..\mcps\internal\servers\roo-state-manager
npx vitest run --maxWorkers=1 2>&1 | Tee-Object -FilePath $LogFile

Write-Host "Test complete. Results saved to: $LogFile"
