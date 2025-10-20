# Analyse rapide des nouveautés de roo-state-manager
Set-Location "mcps/internal/servers/roo-state-manager"

Write-Host "=== ANALYSE RAPIDE ROO-STATE-MANAGER ===" -ForegroundColor Cyan

# Derniers commits
Write-Host "`n=== DERNIERS COMMITS ===" -ForegroundColor Yellow
git log --oneline -5

# Recherche messaging
Write-Host "`n=== RECHERCHE MESSAGING ===" -ForegroundColor Yellow
git log --all --grep="messaging" --oneline --max-count=3

# Recherche agent
Write-Host "`n=== RECHERCHE AGENT ===" -ForegroundColor Yellow
git log --all --grep="agent" --oneline --max-count=3

# Structure
Write-Host "`n=== STRUCTURE ===" -ForegroundColor Yellow
Get-ChildItem -Path . | Where-Object { $_.PSIsContainer } | Select-Object Name

# Fichiers .env
Write-Host "`n=== FICHIERS .ENV ===" -ForegroundColor Yellow
Get-ChildItem -Path . -Recurse -Filter "*.env*" -ErrorAction SilentlyContinue | Select-Object Name

Write-Host "`n=== FIN ===" -ForegroundColor Green