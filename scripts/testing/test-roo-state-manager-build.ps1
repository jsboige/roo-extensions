# Script de test de compilation roo-state-manager
# Vérifie que toutes les corrections TypeScript sont valides

$projectPath = "mcps/internal/servers/roo-state-manager"
$buildLog = "build-test-results.txt"

Write-Host "`n🏗️ Test de compilation roo-state-manager" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Nettoyer le build précédent
Write-Host "`n🧹 Nettoyage du build précédent..." -ForegroundColor Yellow
if (Test-Path "$projectPath/build") {
    # #3712 : backup pre-destruction via le garde deploy (meme doctrine que
    # rebuild-roo-state-manager.ps1 — le build/ est regenerable mais snapshotne).
    $guardScript = Join-Path $PSScriptRoot '..\mcp\deploy-preop-guard.ps1'
    if (Test-Path -LiteralPath $guardScript) {
        # Le garde pose $ErrorActionPreference='Stop' au dot-source : restaurer
        # apres, le reste du script vit en Continue (npm 2>&1 sous Stop est piegeux).
        $guardPrevEap = $ErrorActionPreference
        . $guardScript
        $repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null | Out-String).Trim()
        $guardResult = Invoke-DeployPreOpGuard -Operation "Remove-Item build (test build)" -LiteralPath "$projectPath/build" -Mode Backup -RepoRoot $repoRoot
        $ErrorActionPreference = $guardPrevEap
        Write-Host "  [guard] Action=$($guardResult.Action) BackupDir=$($guardResult.BackupDir)" -ForegroundColor DarkGray
        if ($guardResult.Action -eq 'Blocked') {
            Write-Host "  ABORT: pre-op guard refuse la suppression de $projectPath/build" -ForegroundColor Red
            exit 3
        }
    }
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