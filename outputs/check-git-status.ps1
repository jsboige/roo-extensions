#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

Write-Host "=== ÉTAT ACTUEL APRÈS COUPURE ===" -ForegroundColor Cyan

Write-Host "`n1. État dépôt principal:" -ForegroundColor Yellow
git status --short

Write-Host "`n2. Derniers commits locaux:" -ForegroundColor Yellow
git log --oneline -3

Write-Host "`n3. Comparaison avec remote:" -ForegroundColor Yellow
git fetch origin 2>$null
$behind = git rev-list --count HEAD..origin/main
$ahead = git rev-list --count origin/main..HEAD
Write-Host "En retard: $behind | En avance: $ahead"

Write-Host "`n4. État sous-module mcps/internal:" -ForegroundColor Yellow
Push-Location "mcps/internal"
git status --short
Write-Host "`nDerniers commits sous-module:" -ForegroundColor Yellow
git log --oneline -3
Pop-Location

Write-Host "`n5. Fichiers non trackés:" -ForegroundColor Yellow
git ls-files --others --exclude-standard