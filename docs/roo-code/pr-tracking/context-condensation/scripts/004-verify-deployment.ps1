# Script de vérification du déploiement webview-ui
# Date: 2025-10-08
# Vérifie que les fichiers source et extension sont identiques

Write-Host "`n=== VERIFICATION DEPLOIEMENT WEBVIEW-UI ===" -ForegroundColor Cyan

$srcPath = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$extPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15\webview-ui\assets\index.js"

# Vérifier existence
if (-not (Test-Path $srcPath)) {
    Write-Host "[ERREUR] Fichier source introuvable: $srcPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $extPath)) {
    Write-Host "[ERREUR] Fichier extension introuvable: $extPath" -ForegroundColor Red
    exit 1
}

# Comparer hash
$srcHash = (Get-FileHash $srcPath).Hash
$extHash = (Get-FileHash $extPath).Hash

Write-Host "`nSource:"
Write-Host "  Path: $srcPath" -ForegroundColor Gray
Write-Host "  Hash: $srcHash" -ForegroundColor Gray
Write-Host "  Date: $((Get-Item $srcPath).LastWriteTime)" -ForegroundColor Gray

Write-Host "`nExtension:"
Write-Host "  Path: $extPath" -ForegroundColor Gray
Write-Host "  Hash: $extHash" -ForegroundColor Gray
Write-Host "  Date: $((Get-Item $extPath).LastWriteTime)" -ForegroundColor Gray

Write-Host "`n=== RESULTAT ===" -ForegroundColor Cyan
if ($srcHash -eq $extHash) {
    Write-Host "[OK] Fichiers IDENTIQUES - Deploiement reussi!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[ERREUR] Fichiers DIFFERENTS - Deploiement a echoue!" -ForegroundColor Red
    Write-Host "`nLe script deploy-standalone.ps1 n'a pas copie correctement les fichiers." -ForegroundColor Yellow
    Write-Host "Cause probable: Bug dans la copie du webview-ui" -ForegroundColor Yellow
    exit 1
}