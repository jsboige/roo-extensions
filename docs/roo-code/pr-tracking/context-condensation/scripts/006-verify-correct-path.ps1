# Vérification du BON chemin (celui utilisé par ClineProvider)
# Date: 2025-10-08

Write-Host "`n=== VERIFICATION CHEMIN CORRECT ===" -ForegroundColor Cyan

$srcPath = "C:\dev\roo-code\src\webview-ui\build\assets\index.js"
$extPath = "C:\Users\jsboi\.vscode\extensions\rooveterinaryinc.roo-cline-3.28.15\webview-ui\build\assets\index.js"

Write-Host "`nClineProvider.ts utilise: webview-ui/build/assets/" -ForegroundColor Yellow

if (-not (Test-Path $extPath)) {
    Write-Host "[ERREUR] Fichier introuvable: $extPath" -ForegroundColor Red
    exit 1
}

$srcHash = (Get-FileHash $srcPath).Hash
$extHash = (Get-FileHash $extPath).Hash

Write-Host "`nSource Hash:    $srcHash"
Write-Host "Extension Hash: $extHash"

if ($srcHash -eq $extHash) {
    Write-Host "`n[OK] FICHIERS IDENTIQUES!" -ForegroundColor Green
    Write-Host "Le deploiement a reussi pour webview-ui/build/" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERREUR] FICHIERS DIFFERENTS!" -ForegroundColor Red
    Write-Host "Le deploiement n'a pas copie webview-ui/build/ correctement" -ForegroundColor Yellow
    
    # Dates
    $srcDate = (Get-Item $srcPath).LastWriteTime
    $extDate = (Get-Item $extPath).LastWriteTime
    Write-Host "`nSource: $srcDate"
    Write-Host "Extension: $extDate"
    Write-Host "Difference: $([int]($srcDate - $extDate).TotalHours) heures"
    
    exit 1
}