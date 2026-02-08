# Script 016: Vérification Finale Complète du Déploiement
# Vérifie toute la chaîne: Source → Staging → Extension → Contenu

Write-Host "`n=== VÉRIFICATION FINALE COMPLÈTE ===" -ForegroundColor Cyan

# Configuration
$projectRoot = "c:/dev/roo-code"
$stagingDir = "c:/dev/roo-extensions/roo-code/dist"
$searchText = "Context Condensation Provider"

# === 1. VÉRIFICATION SOURCE ===
Write-Host "`n[1] SOURCE COMPILÉE" -ForegroundColor Yellow
$sourceBuild = "$projectRoot/src/webview-ui/build"
$sourceAssets = "$sourceBuild/assets"

if (Test-Path $sourceAssets) {
    $sourceFiles = Get-ChildItem $sourceAssets -File -Recurse
    $sourceIndexJs = Get-ChildItem "$sourceAssets/index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    Write-Host "  ✅ Build source existe" -ForegroundColor Green
    Write-Host "  Fichiers: $($sourceFiles.Count)" -ForegroundColor Cyan
    
    if ($sourceIndexJs) {
        $sourceSize = [math]::Round($sourceIndexJs.Length / 1KB, 2)
        Write-Host "  index-*.js: $sourceSize KB" -ForegroundColor Cyan
        Write-Host "  Date: $($sourceIndexJs.LastWriteTime)" -ForegroundColor Cyan
        
        # Vérifier contenu
        $sourceHasComponent = (Select-String -Path $sourceIndexJs.FullName -Pattern $searchText -SimpleMatch -ErrorAction SilentlyContinue) -ne $null
        if ($sourceHasComponent) {
            Write-Host "  ✅ Composant présent dans source" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Composant ABSENT de la source!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ❌ Build source n'existe pas!" -ForegroundColor Red
}

# === 2. VÉRIFICATION STAGING ===
Write-Host "`n[2] STAGING" -ForegroundColor Yellow
$stagingWebview = "$stagingDir/webview-ui/build"
$stagingAssets = "$stagingWebview/assets"

if (Test-Path $stagingAssets) {
    $stagingFiles = Get-ChildItem $stagingAssets -File -Recurse
    Write-Host "  ✅ Staging webview-ui/build/ existe" -ForegroundColor Green
    Write-Host "  Fichiers: $($stagingFiles.Count)" -ForegroundColor Cyan
} else {
    Write-Host "  ❌ Staging webview-ui/build/ n'existe pas!" -ForegroundColor Red
    Write-Host "  Structure incorrecte - le script de déploiement a un problème!" -ForegroundColor Red
}

# === 3. VÉRIFICATION EXTENSION ===
Write-Host "`n[3] EXTENSION ACTIVE" -ForegroundColor Yellow
$extPath = (Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Filter "rooveterinaryinc.roo-cline-*" | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1).FullName
$extName = Split-Path $extPath -Leaf

Write-Host "  Extension: $extName" -ForegroundColor Cyan

# Vérifier structure correcte
$extWebviewBuild = "$extPath/dist/webview-ui/build"
$extAssets = "$extWebviewBuild/assets"

if (Test-Path $extAssets) {
    $extFiles = Get-ChildItem $extAssets -File -Recurse
    $extIndexJs = Get-ChildItem "$extAssets/index*.js" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    Write-Host "  ✅ Structure correcte: webview-ui/build/assets/" -ForegroundColor Green
    Write-Host "  Fichiers: $($extFiles.Count)" -ForegroundColor Cyan
    
    if ($extIndexJs) {
        $extSize = [math]::Round($extIndexJs.Length / 1KB, 2)
        Write-Host "  index-*.js: $extSize KB" -ForegroundColor Cyan
        Write-Host "  Date: $($extIndexJs.LastWriteTime)" -ForegroundColor Cyan
        
        # Vérifier contenu
        $extHasComponent = (Select-String -Path $extIndexJs.FullName -Pattern $searchText -SimpleMatch -ErrorAction SilentlyContinue) -ne $null
        if ($extHasComponent) {
            Write-Host "  ✅ Composant présent dans extension" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Composant ABSENT de l'extension!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ❌ Structure INCORRECTE!" -ForegroundColor Red
    
    # Vérifier si la mauvaise structure existe
    $wrongPath = "$extPath/dist/webview-ui/assets"
    if (Test-Path $wrongPath) {
        Write-Host "  ⚠️  PROBLÈME: fichiers dans webview-ui/assets/ au lieu de webview-ui/build/assets/" -ForegroundColor Yellow
        Write-Host "  → Le script deploy-standalone.ps1 a la mauvaise configuration!" -ForegroundColor Yellow
    }
}

# === 4. VÉRIFICATION COHERENCE ===
Write-Host "`n[4] COHÉRENCE" -ForegroundColor Yellow

if ($sourceIndexJs -and $extIndexJs) {
    $sameSize = $sourceIndexJs.Length -eq $extIndexJs.Length
    $sameDate = $sourceIndexJs.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -eq $extIndexJs.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    if ($sameSize -and $sameDate) {
        Write-Host "  ✅ Source et Extension IDENTIQUES" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Source et Extension DIFFÉRENTS" -ForegroundColor Yellow
        Write-Host "  Source: $($sourceIndexJs.Length) bytes, $($sourceIndexJs.LastWriteTime)" -ForegroundColor Gray
        Write-Host "  Extension: $($extIndexJs.Length) bytes, $($extIndexJs.LastWriteTime)" -ForegroundColor Gray
    }
}

# === 5. DIAGNOSTIC FINAL ===
Write-Host "`n=== DIAGNOSTIC FINAL ===" -ForegroundColor Cyan

$allGood = (Test-Path $sourceAssets) -and 
           (Test-Path $stagingAssets) -and 
           (Test-Path $extAssets) -and
           $sourceHasComponent -and 
           $extHasComponent

if ($allGood) {
    Write-Host "✅ SUCCÈS COMPLET - Tout est correct!" -ForegroundColor Green
    Write-Host "   Source → Staging → Extension: Chaîne complète OK" -ForegroundColor Green
    Write-Host "   Composant présent dans tous les fichiers" -ForegroundColor Green
    Write-Host "`n   ⚠️  REDÉMARREZ VSCODE pour voir les changements!" -ForegroundColor Yellow
} else {
    Write-Host "❌ PROBLÈMES DÉTECTÉS" -ForegroundColor Red
    
    if (-not (Test-Path $extAssets)) {
        Write-Host "   → Structure de déploiement incorrecte" -ForegroundColor Red
        Write-Host "   → Vérifiez deploy-standalone.ps1 ligne 64" -ForegroundColor Red
    }
    
    if (-not $sourceHasComponent) {
        Write-Host "   → Recompiler le webview-ui: cd webview-ui && npm run build" -ForegroundColor Red
    }
    
    if (-not $extHasComponent -and $sourceHasComponent) {
        Write-Host "   → Redéployer: cd ../roo-extensions/roo-code-customization && powershell -File ./deploy-standalone.ps1" -ForegroundColor Red
    }
}

Write-Host "`n=== FIN VÉRIFICATION ===" -ForegroundColor Cyan