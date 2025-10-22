# Script de diagnostic runtime pour identifier pourquoi le composant ne s'affiche pas

Write-Host "`n=== DIAGNOSTIC RUNTIME - COMPOSANT CONDENSATION ===" -ForegroundColor Cyan
Write-Host "Le composant est déployé correctement mais ne s'affiche pas.`n" -ForegroundColor Yellow

Write-Host "INSTRUCTIONS POUR L'UTILISATEUR:" -ForegroundColor Green
Write-Host "================================`n"

Write-Host "1. Ouvrez VSCode avec l'extension Roo" -ForegroundColor White
Write-Host "2. Allez dans Settings > Context Management" -ForegroundColor White
Write-Host "3. Ouvrez Developer Tools (Help > Toggle Developer Tools)" -ForegroundColor White
Write-Host "4. Dans la Console, tapez ces commandes une par une:`n" -ForegroundColor White

Write-Host "   // Vérifier si le composant est dans le DOM" -ForegroundColor Cyan
Write-Host '   document.querySelector("*[class*=condensation]")' -ForegroundColor Gray
Write-Host ""

Write-Host "   // Vérifier les erreurs React" -ForegroundColor Cyan
Write-Host '   console.log("Check errors above")' -ForegroundColor Gray
Write-Host ""

Write-Host "   // Vérifier l'état de l'application" -ForegroundColor Cyan
Write-Host '   window.postMessage({type: "getCondensationProviders"}, "*")' -ForegroundColor Gray
Write-Host ""

Write-Host "`n5. Recherchez les erreurs en rouge dans la console" -ForegroundColor White
Write-Host "6. Faites un screenshot de la console ET des settings Context Management" -ForegroundColor White

Write-Host "`n=== CAUSES POSSIBLES ===" -ForegroundColor Yellow
Write-Host "1. Erreur JavaScript empêchant le montage du composant"
Write-Host "2. CSS cachant le composant (display: none, opacity: 0, etc.)"
Write-Host "3. Le backend ne répond pas au message getCondensationProviders"
Write-Host "4. Condition React empêchant le rendu"

Write-Host "`n=== VÉRIFICATIONS RAPIDES ===" -ForegroundColor Cyan

# Vérifier que le composant est dans le bundle
$bundlePath = "src/webview-ui/build/assets/index.js"
if (Test-Path $bundlePath) {
    $found = Select-String -Path $bundlePath -Pattern "Context Condensation Provider" -SimpleMatch -Quiet
    if ($found) {
        Write-Host "✅ Composant présent dans le bundle" -ForegroundColor Green
    } else {
        Write-Host "❌ Composant ABSENT du bundle!" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Bundle non trouvé: $bundlePath" -ForegroundColor Red
}

# Vérifier que le handler backend existe
$extensionPath = "src/dist/extension.js"
if (Test-Path $extensionPath) {
    $found = Select-String -Path $extensionPath -Pattern "getCondensationProviders" -SimpleMatch -Quiet
    if ($found) {
        Write-Host "✅ Handler backend présent dans extension.js" -ForegroundColor Green
    } else {
        Write-Host "❌ Handler backend ABSENT!" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Extension compilée non trouvée: $extensionPath" -ForegroundColor Red
}

Write-Host "`n=== PROCHAINES ÉTAPES ===" -ForegroundColor Cyan
Write-Host "1. Exécutez les commandes DevTools ci-dessus"
Write-Host "2. Partagez les résultats (screenshots + messages d'erreur)"
Write-Host "3. Nous identifierons alors la cause exacte du problème`n"