# Script de verification post-deploiement
# Tache 022 - Verification que les modifications UI ont bien ete deployees

Write-Host "`n=== VERIFICATION POST-DEPLOIEMENT ===" -ForegroundColor Cyan

# 1. Trouver l'extension
$ext = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (-not $ext) {
    Write-Host "Extension Roo non trouvee" -ForegroundColor Red
    exit 1
}

Write-Host "`nExtension trouvee:" -ForegroundColor Yellow
Write-Host "   $($ext.FullName)"

# 2. Verifier le fichier deploye
$deployedFile = Get-Item "$($ext.FullName)\dist\webview-ui\assets\index.js"
Write-Host "`nFichier deploye:" -ForegroundColor Yellow
Write-Host "   Path: $($deployedFile.FullName)"
Write-Host "   Date: $($deployedFile.LastWriteTime)"
Write-Host "   Taille: $([Math]::Round($deployedFile.Length / 1MB, 2)) MB"

$deployedHash = (Get-FileHash $deployedFile.FullName).Hash
Write-Host "   Hash: $deployedHash"

# 3. Verifier le fichier source
$sourceFile = Get-Item "c:\dev\roo-code\src\webview-ui\build\assets\index.js"
Write-Host "`nFichier source:" -ForegroundColor Yellow
Write-Host "   Path: $($sourceFile.FullName)"
Write-Host "   Date: $($sourceFile.LastWriteTime)"
Write-Host "   Taille: $([Math]::Round($sourceFile.Length / 1MB, 2)) MB"

$sourceHash = (Get-FileHash $sourceFile.FullName).Hash
Write-Host "   Hash: $sourceHash"

# 4. Comparaison
Write-Host "`nComparaison des hash:" -ForegroundColor Yellow
if ($deployedHash -eq $sourceHash) {
    Write-Host "   IDENTIQUES - Le deploiement est correct" -ForegroundColor Green
    $result = "SUCCESS"
} else {
    Write-Host "   DIFFERENTS - Probleme de deploiement" -ForegroundColor Red
    $result = "FAILED"
}

# 5. Verifier le commit
Write-Host "`nCommit Git:" -ForegroundColor Yellow
Set-Location "c:\dev\roo-code"
$commitInfo = git log -1 --oneline
Write-Host "   $commitInfo"

# 6. Resume final
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "RESULTAT: $result" -ForegroundColor $(if ($result -eq "SUCCESS") { "Green" } else { "Red" })
Write-Host "============================================================" -ForegroundColor Cyan

if ($result -eq "SUCCESS") {
    Write-Host "`nIMPORTANT: Redemarrez VSCode pour voir les changements" -ForegroundColor Yellow
    exit 0
} else {
    exit 1
}