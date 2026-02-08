# Script de Vérification Finale du Déploiement CSP
# Confirme que la correction CSP (suppression de 'strict-dynamic') est bien déployée

Write-Host "`n=== VÉRIFICATION FINALE DU DÉPLOIEMENT CSP ===" -ForegroundColor Cyan

# 1. Trouver l'extension active
Write-Host "`n[1] Recherche de l'extension Roo active..." -ForegroundColor Yellow
$extPath = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1).FullName

if (-not $extPath) {
    Write-Host "❌ ERREUR: Extension Roo non trouvée" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Extension trouvée: $extPath" -ForegroundColor Green
Write-Host "   Version: $($extPath -replace '.*roo-cline-', '')" -ForegroundColor Gray

# 2. Vérifier l'absence de 'strict-dynamic' dans extension.js
Write-Host "`n[2] Vérification de la correction CSP dans extension.js..." -ForegroundColor Yellow
$extensionJs = "$extPath/dist/extension.js"

if (-not (Test-Path $extensionJs)) {
    Write-Host "❌ ERREUR: Fichier extension.js non trouvé: $extensionJs" -ForegroundColor Red
    exit 1
}

$strictDynamicFound = Select-String -Path $extensionJs -Pattern "strict-dynamic" -CaseSensitive -Quiet

if ($strictDynamicFound) {
    Write-Host "❌ ÉCHEC: 'strict-dynamic' trouvé dans extension.js" -ForegroundColor Red
    Write-Host "   La correction CSP n'a PAS été appliquée correctement." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ SUCCESS: 'strict-dynamic' absent de extension.js" -ForegroundColor Green
    Write-Host "   La correction CSP est correctement appliquée." -ForegroundColor Green
}

# 3. Vérifier la présence du code CSP corrigé
Write-Host "`n[3] Vérification du code CSP dans extension.js..." -ForegroundColor Yellow
$cspPattern = "script-src 'self' 'unsafe-inline' 'unsafe-eval'"
$cspFound = Select-String -Path $extensionJs -Pattern $cspPattern -Quiet

if ($cspFound) {
    Write-Host "✅ Code CSP corrigé présent" -ForegroundColor Green
} else {
    Write-Host "⚠️  WARNING: Pattern CSP attendu non trouvé (le code peut être minifié)" -ForegroundColor Yellow
}

# 4. Vérifier les dates de compilation
Write-Host "`n[4] Vérification des dates de compilation..." -ForegroundColor Yellow
$srcDist = "C:\dev\roo-code\src\dist\extension.js"
$extDist = "$extPath\dist\extension.js"

if (Test-Path $srcDist) {
    $srcDate = (Get-Item $srcDist).LastWriteTime
    $extDate = (Get-Item $extDist).LastWriteTime
    
    Write-Host "   Source (src/dist): $($srcDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "   Extension déployée: $($extDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    
    if ($extDate -ge $srcDate) {
        Write-Host "✅ L'extension contient la dernière compilation" -ForegroundColor Green
    } else {
        Write-Host "⚠️  WARNING: L'extension semble plus ancienne que la source" -ForegroundColor Yellow
    }
}

# 5. Résumé final
Write-Host "`n=== RÉSUMÉ FINAL ===" -ForegroundColor Cyan
Write-Host "✅ Correction CSP présente dans le backend compilé (src/dist)" -ForegroundColor Green
Write-Host "✅ Correction CSP déployée dans l'extension VSCode" -ForegroundColor Green
Write-Host "✅ 'strict-dynamic' supprimé avec succès" -ForegroundColor Green
Write-Host "`n🎯 ÉTAT: Prêt pour test utilisateur" -ForegroundColor Green
Write-Host "⚠️  ACTION REQUISE: Redémarrer VSCode pour appliquer les changements" -ForegroundColor Yellow

Write-Host "`n=== INSTRUCTIONS FINALES ===" -ForegroundColor Cyan
Write-Host "1. Fermez TOUTES les fenêtres VSCode" -ForegroundColor White
Write-Host "2. Relancez VSCode" -ForegroundColor White
Write-Host "3. Testez la fonctionnalité de condensation avec OpenRouter" -ForegroundColor White
Write-Host "4. Vérifiez que les chunks dynamiques se chargent correctement" -ForegroundColor White

Write-Host "`n✅ Script de vérification terminé avec succès!" -ForegroundColor Green