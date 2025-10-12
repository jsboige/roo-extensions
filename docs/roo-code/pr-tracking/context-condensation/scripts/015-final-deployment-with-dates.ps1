# ============================================
# REBUILD COMPLET ET DÉPLOIEMENT FINAL
# Date: 12/10/2025 02:37
# ============================================

Write-Host "`n=== REBUILD COMPLET AVEC VÉRIFICATION DES DATES ===" -ForegroundColor Cyan

# ============================================
# CONTEXTE CRITIQUE
# ============================================
Write-Host "`n[PROBLÈME IDENTIFIÉ]" -ForegroundColor Yellow
Write-Host "Les assets dans l'extension 3.28.16 dataient du 10/10/2025"
Write-Host "alors que nous avions compilé ce matin (12/10/2025)."
Write-Host "Les nouveaux assets n'avaient jamais été déployés!"

# ============================================
# ÉTAPE 1: NETTOYAGE BUILD
# ============================================
Write-Host "`n[1/7] Nettoyage du répertoire build webview-ui..." -ForegroundColor Green
$buildPath = "c:/dev/roo-code/webview-ui/build"
if (Test-Path $buildPath) {
    Remove-Item $buildPath -Recurse -Force
    Write-Host "✓ Build supprimé" -ForegroundColor Green
} else {
    Write-Host "✓ Pas de build existant" -ForegroundColor Green
}

# ============================================
# ÉTAPE 2: COMPILATION WEBVIEW-UI
# ============================================
Write-Host "`n[2/7] Compilation webview-ui depuis zéro..." -ForegroundColor Green
Set-Location "c:/dev/roo-code/webview-ui"
npm run build
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Webview-ui compilé avec succès" -ForegroundColor Green
} else {
    Write-Host "✗ Erreur lors de la compilation webview-ui" -ForegroundColor Red
    exit 1
}

# ============================================
# ÉTAPE 3: VÉRIFICATION DATES BUILD
# ============================================
Write-Host "`n[3/7] Vérification des dates des assets générés..." -ForegroundColor Green
$assetsPath = "c:/dev/roo-code/src/webview-ui/build/assets"
$buildAssets = Get-ChildItem "$assetsPath/*.js" | Select-Object -First 3
Write-Host "`nAssets générés:" -ForegroundColor Cyan
$buildAssets | ForEach-Object {
    $date = $_.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
    Write-Host "  - $($_.Name): $date" -ForegroundColor White
}

# Vérifier que les fichiers datent d'aujourd'hui
$today = (Get-Date).Date
$allToday = $buildAssets | Where-Object { $_.LastWriteTime.Date -eq $today }
if ($allToday.Count -eq $buildAssets.Count) {
    Write-Host "✓ Tous les assets datent d'aujourd'hui (12/10/2025)" -ForegroundColor Green
} else {
    Write-Host "✗ ATTENTION: Certains assets ne datent pas d'aujourd'hui!" -ForegroundColor Red
    exit 1
}

# ============================================
# ÉTAPE 4: COMPILATION BACKEND
# ============================================
Write-Host "`n[4/7] Compilation du backend..." -ForegroundColor Green
Set-Location "c:/dev/roo-code/src"
pnpm run bundle
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Backend compilé avec succès" -ForegroundColor Green
} else {
    Write-Host "✗ Erreur lors de la compilation backend" -ForegroundColor Red
    exit 1
}

# ============================================
# ÉTAPE 5: DÉPLOIEMENT
# ============================================
Write-Host "`n[5/7] Déploiement vers l'extension..." -ForegroundColor Green
Set-Location "c:/dev/roo-extensions/roo-code-customization"
& .\deploy-standalone.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Déploiement réussi" -ForegroundColor Green
} else {
    Write-Host "✗ Erreur lors du déploiement" -ForegroundColor Red
    exit 1
}

# ============================================
# ÉTAPE 6: VÉRIFICATION DATES DÉPLOYÉES
# ============================================
Write-Host "`n[6/7] Vérification des dates dans l'extension déployée..." -ForegroundColor Green
$extensionPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16\dist\webview-ui\assets"
$deployedAssets = Get-ChildItem "$extensionPath/*.js" | Select-Object -First 3
Write-Host "`nAssets déployés:" -ForegroundColor Cyan
$deployedAssets | ForEach-Object {
    $date = $_.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
    Write-Host "  - $($_.Name): $date" -ForegroundColor White
}

# Vérifier que les fichiers déployés datent d'aujourd'hui
$allDeployedToday = $deployedAssets | Where-Object { $_.LastWriteTime.Date -eq $today }
if ($allDeployedToday.Count -eq $deployedAssets.Count) {
    Write-Host "✓ Tous les assets déployés datent d'aujourd'hui (12/10/2025)" -ForegroundColor Green
} else {
    Write-Host "✗ ATTENTION: Certains assets déployés ne datent pas d'aujourd'hui!" -ForegroundColor Red
    exit 1
}

# ============================================
# ÉTAPE 7: RÉSUMÉ FINAL
# ============================================
Write-Host "`n[7/7] Résumé du déploiement..." -ForegroundColor Green

Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            DÉPLOIEMENT RÉUSSI                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nÉtapes accomplies:" -ForegroundColor White
Write-Host "  ✓ Nettoyage complet du build" -ForegroundColor Green
Write-Host "  ✓ Recompilation webview-ui depuis zéro" -ForegroundColor Green
Write-Host "  ✓ Vérification dates assets générés (12/10/2025)" -ForegroundColor Green
Write-Host "  ✓ Recompilation backend" -ForegroundColor Green
Write-Host "  ✓ Déploiement vers extension 3.28.16" -ForegroundColor Green
Write-Host "  ✓ Vérification dates assets déployés (12/10/2025)" -ForegroundColor Green

Write-Host "`nExtension déployée:" -ForegroundColor White
Write-Host "  C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.16" -ForegroundColor Cyan

Write-Host "`n⚠️  ACTION REQUISE:" -ForegroundColor Yellow
Write-Host "  → REDÉMARREZ VSCODE pour appliquer les changements" -ForegroundColor Yellow

Write-Host "`n✓ Les nouveaux assets sont maintenant correctement déployés!" -ForegroundColor Green
Write-Host ""