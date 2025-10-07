# Script de correction Phase 6 : Rebuild complet et deploiement
# Date: 2025-10-07
# Objectif: Rebuilder webview-ui avec nouveaux composants et redéployer

$ErrorActionPreference = "Stop"

Write-Host "`n=== REBUILD COMPLET WEBVIEW-UI & DEPLOIEMENT ===" -ForegroundColor Magenta
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# ============================================
# ETAPE 1: Nettoyer ancien build webview-ui
# ============================================
Write-Host "`n[ETAPE 1/5] Nettoyage ancien build webview-ui" -ForegroundColor Cyan

$webviewBuildPath = "C:\dev\roo-code\src\webview-ui\build"

if (Test-Path $webviewBuildPath) {
    Write-Host "  Suppression de $webviewBuildPath..." -ForegroundColor Yellow
    Remove-Item -Path $webviewBuildPath -Recurse -Force
    Write-Host "  [OK] Ancien build supprime" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Pas de build existant a supprimer" -ForegroundColor Gray
}

# ============================================
# ETAPE 2: Rebuilder webview-ui
# ============================================
Write-Host "`n[ETAPE 2/5] Build webview-ui (avec nouveaux composants)" -ForegroundColor Cyan

Push-Location "C:\dev\roo-code\webview-ui"

try {
    Write-Host "  Execution de 'npm run build'..." -ForegroundColor Yellow
    
    # Executer npm run build
    $buildOutput = npm run build 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERREUR] Erreur lors du build webview-ui" -ForegroundColor Red
        Write-Host $buildOutput
        Pop-Location
        exit 1
    }
    
    Write-Host "  [OK] Build webview-ui termine" -ForegroundColor Green
    
    # Verifier que les fichiers ont bien ete generes
    if (-not (Test-Path "C:\dev\roo-code\src\webview-ui\build\assets\index.js")) {
        Write-Host "  [ERREUR] index.js n'a pas ete genere !" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    $indexJsSize = (Get-Item "C:\dev\roo-code\src\webview-ui\build\assets\index.js").Length
    Write-Host "  [INFO] index.js genere : $([math]::Round($indexJsSize/1KB, 2)) KB" -ForegroundColor Gray
    
} finally {
    Pop-Location
}

# ============================================
# ETAPE 3: Nettoyer ancien build extension
# ============================================
Write-Host "`n[ETAPE 3/5] Nettoyage ancien build extension" -ForegroundColor Cyan

$srcDistPath = "C:\dev\roo-code\src\dist"

if (Test-Path $srcDistPath) {
    Write-Host "  Suppression de $srcDistPath..." -ForegroundColor Yellow
    Remove-Item -Path $srcDistPath -Recurse -Force
    Write-Host "  [OK] Ancien dist supprime" -ForegroundColor Green
} else {
    Write-Host "  [INFO] Pas de dist existant a supprimer" -ForegroundColor Gray
}

# ============================================
# ETAPE 4: Rebuilder extension
# ============================================
Write-Host "`n[ETAPE 4/5] Build extension" -ForegroundColor Cyan

Push-Location "C:\dev\roo-code\src"

try {
    Write-Host "  Execution de 'pnpm run bundle'..." -ForegroundColor Yellow
    
    # Executer pnpm run bundle
    $bundleOutput = pnpm run bundle 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERREUR] Erreur lors du bundle extension" -ForegroundColor Red
        Write-Host $bundleOutput
        Pop-Location
        exit 1
    }
    
    Write-Host "  [OK] Bundle extension termine" -ForegroundColor Green
    
} finally {
    Pop-Location
}

# ============================================
# ETAPE 5: Redeployer extension
# ============================================
Write-Host "`n[ETAPE 5/5] Deploiement extension" -ForegroundColor Cyan

Push-Location "C:\dev\roo-extensions\roo-code-customization"

try {
    Write-Host "  Execution de './deploy-standalone.ps1'..." -ForegroundColor Yellow
    
    # Executer deploy-standalone.ps1
    & ".\deploy-standalone.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERREUR] Erreur lors du deploiement" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    Write-Host "  [OK] Deploiement termine" -ForegroundColor Green
    
} finally {
    Pop-Location
}

# ============================================
# VERIFICATION FINALE
# ============================================
Write-Host "`n=== VERIFICATION ===" -ForegroundColor Cyan

$sourceFile = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$extPath = "$env:USERPROFILE\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15"
$extFile = "$extPath\webview-ui\build\assets\index.js"

if (Test-Path $extFile) {
    $sourceDate = (Get-Item $sourceFile).LastWriteTime
    $extDate = (Get-Item $extFile).LastWriteTime
    
    Write-Host "`nDates de derniere modification :"
    Write-Host "  Source: $sourceDate" -ForegroundColor Gray
    Write-Host "  Extension: $extDate" -ForegroundColor Gray
    
    $timeDiff = ($extDate - $sourceDate).TotalSeconds
    
    if ([Math]::Abs($timeDiff) -lt 60) {
        Write-Host "`n  [OK] Fichiers synchronises (difference < 1 min)" -ForegroundColor Green
    } else {
        Write-Host "`n  [ATTENTION] Difference de $timeDiff secondes" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n  [ERREUR] Fichier extension non trouve : $extFile" -ForegroundColor Red
    exit 1
}

# ============================================
# INSTRUCTIONS FINALES
# ============================================
Write-Host "`n=== PROCHAINES ETAPES ===" -ForegroundColor Magenta

Write-Host "`n[OK] Build et deploiement termines avec succes !`n"

Write-Host "VEUILLEZ MAINTENANT :" -ForegroundColor Yellow
Write-Host "  1. Redemarrer VSCode COMPLETEMENT (fermer toutes les fenetres)"
Write-Host "  2. Rouvrir votre workspace"
Write-Host "  3. Aller dans Roo Settings -> Onglet 'Context'"
Write-Host "  4. Verifier que vous voyez :"
Write-Host "     - Section 'Context Condensation Provider'"
Write-Host "     - Dropdown avec 4 providers (Smart, Simple, OpenAI, Anthropic)"
Write-Host "     - Presets Smart Provider (si Smart selectionne)"
Write-Host ""
Write-Host "[IMPORTANT] NE PAS continuer sans avoir confirme que l'UI est visible !" -ForegroundColor Red
Write-Host ""

Write-Host "=== FIN SCRIPT ===" -ForegroundColor Magenta