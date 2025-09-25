Write-Host "--- Forcing compilation for roo-state-manager ---"
Push-Location mcps/internal/servers/roo-state-manager
npm run build
Pop-Location
Write-Host "--- Compilation finished ---"