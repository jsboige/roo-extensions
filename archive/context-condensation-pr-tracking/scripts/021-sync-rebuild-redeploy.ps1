# Script de Synchronisation, Rebuild et Redéploiement Complet
# Usage: .\021-sync-rebuild-redeploy.ps1

param(
    [switch]$SkipStash,
    [switch]$SkipBuild,
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"
$repoPath = "C:\dev\roo-code"
$deployScript = "C:\dev\roo-extensions\roo-code-customization\deploy-standalone.ps1"
$extensionPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16"

Write-Host "`n=== SYNC UPSTREAM ET REDÉPLOIEMENT ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# Étape 1: Sauvegarder l'état actuel
if (-not $SkipStash) {
    Write-Host "[1/6] Sauvegarde de l'état actuel..." -ForegroundColor Yellow
    Push-Location $repoPath
    
    $status = git status --porcelain
    if ($status) {
        Write-Host "  Changements détectés, création du stash..." -ForegroundColor Gray
        git stash push -m "WIP: avant sync upstream $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        if ($LASTEXITCODE -ne 0) { throw "Échec du stash" }
        Write-Host "  ✅ Stash créé" -ForegroundColor Green
    } else {
        Write-Host "  ✅ Aucun changement à sauvegarder" -ForegroundColor Green
    }
    
    Pop-Location
} else {
    Write-Host "[1/6] Stash ignoré (--SkipStash)" -ForegroundColor Gray
}

# Étape 2: Fetch upstream
Write-Host "`n[2/6] Récupération des commits upstream..." -ForegroundColor Yellow
Push-Location $repoPath

git fetch upstream
if ($LASTEXITCODE -ne 0) { throw "Échec du fetch upstream" }

$behindCount = (git rev-list --count HEAD..upstream/main)
Write-Host "  📊 $behindCount commits en retard" -ForegroundColor Gray

Pop-Location
Write-Host "  ✅ Fetch terminé" -ForegroundColor Green

# Étape 3: Merge upstream/main
Write-Host "`n[3/6] Merge de upstream/main..." -ForegroundColor Yellow
Push-Location $repoPath

git merge upstream/main --no-edit
if ($LASTEXITCODE -ne 0) { 
    Write-Host "  ⚠️  Conflits détectés!" -ForegroundColor Red
    Write-Host "  Résolvez les conflits puis relancez avec --SkipStash" -ForegroundColor Yellow
    Pop-Location
    exit 1
}

$mergeResult = git log -1 --oneline
Write-Host "  📝 $mergeResult" -ForegroundColor Gray
Write-Host "  ✅ Merge réussi sans conflits" -ForegroundColor Green

Pop-Location

# Étape 4: Rebuild complet
if (-not $SkipBuild) {
    Write-Host "`n[4/6] Rebuild complet..." -ForegroundColor Yellow
    Push-Location $repoPath
    
    # Install dependencies
    Write-Host "  📦 Installation des dépendances..." -ForegroundColor Gray
    pnpm install
    if ($LASTEXITCODE -ne 0) { throw "Échec de pnpm install" }
    
    # Build backend
    Write-Host "  🔨 Build backend..." -ForegroundColor Gray
    Push-Location "$repoPath\src"
    npm run bundle
    if ($LASTEXITCODE -ne 0) { throw "Échec du build backend" }
    Pop-Location
    
    # Build webview-ui
    Write-Host "  🎨 Build webview-ui..." -ForegroundColor Gray
    Push-Location "$repoPath\webview-ui"
    pnpm run build
    if ($LASTEXITCODE -ne 0) { throw "Échec du build webview-ui" }
    Pop-Location
    
    Pop-Location
    Write-Host "  ✅ Rebuild terminé" -ForegroundColor Green
} else {
    Write-Host "`n[4/6] Build ignoré (--SkipBuild)" -ForegroundColor Gray
}

# Étape 5: Redéploiement
if (-not $SkipDeploy) {
    Write-Host "`n[5/6] Redéploiement..." -ForegroundColor Yellow
    
    powershell.exe -ExecutionPolicy Bypass -File $deployScript
    if ($LASTEXITCODE -ne 0) { throw "Échec du déploiement" }
    
    Write-Host "  ✅ Déploiement terminé" -ForegroundColor Green
} else {
    Write-Host "`n[5/6] Déploiement ignoré (--SkipDeploy)" -ForegroundColor Gray
}

# Étape 6: Vérification
Write-Host "`n[6/6] Vérification..." -ForegroundColor Yellow

$indexHtml = "$extensionPath\dist\webview-ui\build\index.html"
$indexJs = "$extensionPath\dist\webview-ui\build\assets\index.js"

if (Test-Path $indexHtml) {
    Write-Host "  ✅ index.html présent" -ForegroundColor Green
} else {
    Write-Host "  ❌ index.html manquant" -ForegroundColor Red
}

if (Test-Path $indexJs) {
    $lastWrite = (Get-Item $indexJs).LastWriteTime
    $age = (Get-Date) - $lastWrite
    
    if ($age.TotalMinutes -lt 5) {
        Write-Host "  ✅ index.js mis à jour ($('{0:N0}' -f $age.TotalSeconds)s)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  index.js ancien ($($lastWrite.ToString('yyyy-MM-dd HH:mm:ss')))" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ index.js manquant" -ForegroundColor Red
}

$distFiles = (Get-ChildItem "$extensionPath\dist" -Recurse -File).Count
Write-Host "  📊 $distFiles fichiers dans dist/" -ForegroundColor Gray

# Résumé
Write-Host "`n=== SUCCÈS ===" -ForegroundColor Green
Write-Host "✅ Synchronisation avec upstream/main réussie"
Write-Host "✅ Rebuild complet terminé" 
Write-Host "✅ Redéploiement effectué"
Write-Host "`n⚠️  REDÉMARREZ VSCODE pour appliquer les changements" -ForegroundColor Yellow