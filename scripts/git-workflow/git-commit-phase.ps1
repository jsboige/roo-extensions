# git-commit-phase.ps1
# Script pour commiter et pusher automatiquement les changements d'une phase
param(
    [Parameter(Mandatory=$true)]
    [string]$Phase,
    
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [string]$WorkingDir = "d:/roo-extensions"
)

Set-Location $WorkingDir

Write-Host "=== Git Commit Phase ===" -ForegroundColor Cyan
Write-Host "Phase: $Phase" -ForegroundColor Yellow
Write-Host "Working Directory: $WorkingDir" -ForegroundColor Yellow
Write-Host ""

# Vérifier l'état Git
Write-Host "1. Vérification de l'état Git..." -ForegroundColor Green
git status --short

Write-Host ""
Write-Host "2. Ajout des fichiers..." -ForegroundColor Green
git add -A

Write-Host ""
Write-Host "3. Commit des changements..." -ForegroundColor Green
git commit -m $Message

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "4. Push vers origin/main..." -ForegroundColor Green
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Phase $Phase commitée et pushée avec succès !" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️ Erreur lors du push" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Erreur lors du commit (ou rien à commiter)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Fin Git Commit Phase ===" -ForegroundColor Cyan