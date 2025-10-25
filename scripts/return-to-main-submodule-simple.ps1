# Script simple pour PHASE 2: Opération sous-module
Write-Host "=== PHASE 2: OPÉRATION SOUS-MODULE ===" -ForegroundColor Green

# Navigation vers le sous-module
Set-Location "mcps/internal"
Write-Host "Navigation vers mcps/internal" -ForegroundColor Yellow

# État actuel
Write-Host "État actuel:" -ForegroundColor Cyan
git branch --show-current
git status --porcelain

# Checkout main
Write-Host "Checkout main..." -ForegroundColor Yellow
git checkout main

# Fetch origin
Write-Host "Fetch origin..." -ForegroundColor Yellow
git fetch origin

# Merge origin/main (MERGE SAFE)
Write-Host "Merge origin/main (MERGE SAFE)..." -ForegroundColor Yellow
git merge origin/main

# Validation
Write-Host "Validation post-merge:" -ForegroundColor Cyan
git log --oneline -5
git status --porcelain

# Compilation TypeScript si package.json existe
if (Test-Path "package.json") {
    Write-Host "Installation dépendances..." -ForegroundColor Yellow
    npm install --silent
    
    $packageJson = Get-Content "package.json" | ConvertFrom-Json
    if ($packageJson.scripts.PSObject.Properties.Name -contains "build") {
        Write-Host "Compilation TypeScript..." -ForegroundColor Yellow
        npm run build
        Write-Host "✅ Compilation réussie" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Pas de script build trouvé" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ package.json non trouvé" -ForegroundColor Yellow
}

# Retour au répertoire principal
Set-Location "../.."
Write-Host "=== PHASE 2 TERMINÉE ===" -ForegroundColor Green