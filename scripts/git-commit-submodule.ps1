# git-commit-submodule.ps1
# Script pour commiter dans un sous-module Git et mettre à jour le dépôt parent
param(
    [Parameter(Mandatory=$true)]
    [string]$SubmodulePath,
    
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [string]$WorkingDir = "d:/roo-extensions"
)

Set-Location $WorkingDir

Write-Host "=== Git Commit Submodule ===" -ForegroundColor Cyan
Write-Host "Submodule: $SubmodulePath" -ForegroundColor Yellow
Write-Host "Working Directory: $WorkingDir" -ForegroundColor Yellow
Write-Host ""

# 1. Naviguer dans le sous-module
$submoduleFullPath = Join-Path $WorkingDir $SubmodulePath
if (-not (Test-Path $submoduleFullPath)) {
    Write-Host "❌ Erreur: Le sous-module $SubmodulePath n'existe pas" -ForegroundColor Red
    exit 1
}

Set-Location $submoduleFullPath

Write-Host "1. État du sous-module..." -ForegroundColor Green
git status --short

Write-Host ""
Write-Host "2. Ajout des fichiers dans le sous-module..." -ForegroundColor Green
git add -A

Write-Host ""
Write-Host "3. Commit dans le sous-module..." -ForegroundColor Green
git commit -m $Message

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "4. Push du sous-module..." -ForegroundColor Green
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "5. Mise à jour de la référence dans le dépôt parent..." -ForegroundColor Green
        Set-Location $WorkingDir
        
        git add $SubmodulePath
        git commit -m "chore: Update submodule $SubmodulePath

$Message"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "6. Push du dépôt parent..." -ForegroundColor Green
            git push origin main
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "✅ Commit et push réussis (sous-module + parent) !" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "⚠️ Erreur lors du push du dépôt parent" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host ""
            Write-Host "⚠️ Erreur lors du commit du dépôt parent" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host ""
        Write-Host "⚠️ Erreur lors du push du sous-module" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Erreur lors du commit du sous-module (ou rien à commiter)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Fin Git Commit Submodule ===" -ForegroundColor Cyan