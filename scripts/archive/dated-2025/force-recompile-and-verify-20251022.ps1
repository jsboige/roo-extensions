# Force recompilation et vérification du déploiement
# Date: 2025-10-22

$ErrorActionPreference = "Stop"
$mcpDir = "mcps\internal\servers\roo-state-manager"

Write-Host "`n=== FORCE RECOMPILATION ROO-STATE-MANAGER ===" -ForegroundColor Cyan

# ÉTAPE 1: Vérifier la date du source vs build
Write-Host "`n[1] Vérification des dates de modification..." -ForegroundColor Yellow

$sourceFile = "$mcpDir\src\tools\cache\build-skeleton-cache.tool.ts"
$buildFile = "$mcpDir\build\index.js"

if (Test-Path $sourceFile) {
    $source = Get-Item $sourceFile
    Write-Host "   Source: $($source.LastWriteTime)" -ForegroundColor Gray
}
else {
    Write-Host "   ❌ Fichier source introuvable !" -ForegroundColor Red
    exit 1
}

if (Test-Path $buildFile) {
    $build = Get-Item $buildFile
    Write-Host "   Build:  $($build.LastWriteTime)" -ForegroundColor Gray
    
    if ($build.LastWriteTime -lt $source.LastWriteTime) {
        Write-Host "   ⚠️ BUILD OBSOLÈTE (plus ancien que le source)" -ForegroundColor Red
    }
    else {
        Write-Host "   ✅ Build à jour" -ForegroundColor Green
    }
}
else {
    Write-Host "   ❌ Fichier build introuvable !" -ForegroundColor Red
}

# ÉTAPE 2: Nettoyer les anciens builds
Write-Host "`n[2] Nettoyage des anciens builds..." -ForegroundColor Yellow

if (Test-Path "$mcpDir\build") {
    Remove-Item "$mcpDir\build" -Recurse -Force
    Write-Host "   ✅ Répertoire build supprimé" -ForegroundColor Green
}

if (Test-Path "$mcpDir\node_modules") {
    Write-Host "   ℹ️ node_modules présent (conservé)" -ForegroundColor Gray
}
else {
    Write-Host "   ⚠️ node_modules absent, npm install sera nécessaire" -ForegroundColor Yellow
}

# ÉTAPE 3: Installation des dépendances si nécessaire
Write-Host "`n[3] Vérification des dépendances..." -ForegroundColor Yellow

Push-Location $mcpDir

try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "   Installation des dépendances npm..." -ForegroundColor Cyan
        npm install 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ npm install réussi" -ForegroundColor Green
        }
        else {
            Write-Host "   ❌ npm install échoué" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "   ✅ Dépendances déjà installées" -ForegroundColor Green
    }
    
    # ÉTAPE 4: Compilation
    Write-Host "`n[4] Compilation TypeScript..." -ForegroundColor Yellow
    
    npm run build 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Compilation réussie" -ForegroundColor Green
    }
    else {
        Write-Host "   ❌ Compilation échouée" -ForegroundColor Red
        Write-Host "   Tentative avec output visible..." -ForegroundColor Yellow
        npm run build
        exit 1
    }
    
    # ÉTAPE 5: Vérification du résultat
    Write-Host "`n[5] Vérification du build..." -ForegroundColor Yellow
    
    if (Test-Path "build\index.js") {
        $newBuild = Get-Item "build\index.js"
        Write-Host "   ✅ build\index.js créé" -ForegroundColor Green
        Write-Host "   Taille: $([math]::Round($newBuild.Length/1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "   Modifié: $($newBuild.LastWriteTime)" -ForegroundColor Gray
        
        # Vérifier que le fix est présent dans le build
        $buildContent = Get-Content "build\index.js" -Raw
        
        Write-Host "`n   Vérification du contenu du build..." -ForegroundColor Cyan
        
        # Recherche de patterns spécifiques
        if ($buildContent -match "tasks.*\.skeletons") {
            Write-Host "   ✅ Pattern 'tasks\.skeletons' trouvé dans le build" -ForegroundColor Green
        }
        else {
            Write-Host "   ⚠️ Pattern 'tasks\.skeletons' NON trouvé" -ForegroundColor Yellow
        }
        
        # Compter les occurrences de '.skeletons'
        $skeletonsCount = ([regex]::Matches($buildContent, "\.skeletons")).Count
        Write-Host "   Occurrences de '.skeletons': $skeletonsCount" -ForegroundColor Gray
    }
    else {
        Write-Host "   ❌ build\index.js NON créé !" -ForegroundColor Red
        exit 1
    }
}
finally {
    Pop-Location
}

# ÉTAPE 6: Instructions pour restart MCP
Write-Host "`n[6] Redémarrage du serveur MCP..." -ForegroundColor Yellow
Write-Host "   Le serveur MCP doit être redémarré pour charger le nouveau build." -ForegroundColor White
Write-Host "   Options:" -ForegroundColor Cyan
Write-Host "   A. Restart VSCode (méthode sûre)" -ForegroundColor Gray
Write-Host "   B. Touch mcp_settings.json pour forcer reload" -ForegroundColor Gray
Write-Host "   C. Utiliser rebuild_and_restart_mcp MCP tool" -ForegroundColor Gray

Write-Host "`n=== SUCCÈS ===" -ForegroundColor Green
Write-Host "Build recompilé avec succès." -ForegroundColor White
Write-Host "Redémarrez le serveur MCP pour appliquer les changements." -ForegroundColor White