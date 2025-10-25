# Script de test de compilation roo-state-manager
# Vérifie que toutes les corrections TypeScript sont valides

$projectPath = "mcps/internal/servers/roo-state-manager"
$buildLog = "build-test-results.txt"

Write-Host "`n🏗️ Test de compilation roo-state-manager" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Nettoyer le build précédent
Write-Host "`n🧹 Nettoyage du build précédent..." -ForegroundColor Yellow
if (Test-Path "$projectPath/build") {
    Remove-Item "$projectPath/build" -Recurse -Force
    Write-Host "✅ Répertoire build supprimé" -ForegroundColor Green
}

# Aller dans le répertoire du projet
Push-Location $projectPath

try {
    Write-Host "`n📦 Installation des dépendances..." -ForegroundColor Yellow
    npm install 2>&1 | Out-Null
    
    Write-Host "`n🔨 Compilation TypeScript..." -ForegroundColor Yellow
    $buildOutput = npm run build 2>&1 | Out-String
    
    # Sauvegarder la sortie complète
    $buildOutput | Out-File -FilePath "../../$buildLog" -Encoding UTF8
    
    # Analyser les résultats
    if ($buildOutput -match "error TS\d+:") {
        Write-Host "`n❌ ÉCHEC DE COMPILATION" -ForegroundColor Red
        Write-Host "=" * 60 -ForegroundColor Gray
        
        # Extraire et afficher les erreurs
        $errors = $buildOutput | Select-String "error TS\d+:" -AllMatches
        Write-Host "`n📋 Erreurs détectées:" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  • $($err.Line)" -ForegroundColor Red
        }
        
        Write-Host "`n📄 Log complet sauvegardé: $buildLog" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
    else {
        Write-Host "`n✅ COMPILATION RÉUSSIE" -ForegroundColor Green
        Write-Host "=" * 60 -ForegroundColor Gray
        
        # Vérifier que les fichiers JS ont été générés
        $jsFiles = Get-ChildItem -Path "build" -Filter "*.js" -Recurse
        $jsCount = $jsFiles.Count
        
        Write-Host "`n📊 Statistiques de compilation:" -ForegroundColor Cyan
        Write-Host "  • Fichiers JavaScript générés: $jsCount" -ForegroundColor White
        Write-Host "  • Répertoire de sortie: build/" -ForegroundColor White
        
        if ($jsCount -gt 0) {
            Write-Host "`n✨ Build prêt pour déploiement" -ForegroundColor Green
        }
        
        Pop-Location
        exit 0
    }
}
catch {
    Write-Host "`n❌ ERREUR INATTENDUE" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Pop-Location
    exit 1
}