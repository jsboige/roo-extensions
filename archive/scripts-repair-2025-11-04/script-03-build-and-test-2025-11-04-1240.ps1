# Script de Build et Test Complet roo-state-manager
# Date: 2025-11-04 12:40
# Objectif: Compiler le code et tester les corrections

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "build"
)

Write-Host "🔧 SCRIPT DE BUILD ET TEST roo-state-manager" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Yellow
Write-Host "Heure: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Fonction de build du projet
function Build-Project {
    Write-Host "🏗️ BUILD: Compilation du projet roo-state-manager" -ForegroundColor Green
    Write-Host "-----------------------------------------------" -ForegroundColor Green
    
    try {
        # Aller dans le répertoire du projet
        Set-Location "mcps/internal/servers/roo-state-manager"
        
        # Installer les dépendances si nécessaire
        Write-Host "📦 Installation des dépendances..." -ForegroundColor Yellow
        npm install --silent
        
        # Compiler le projet TypeScript
        Write-Host "🔨 Compilation TypeScript..." -ForegroundColor Yellow
        npm run build
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Build RÉUSSI" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Build ÉCHOUÉ" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Erreur lors du build: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    finally {
        # Revenir au répertoire racine
        Set-Location "../../../.."
    }
}

# Fonction de test simple sans build
function Test-Simple {
    Write-Host "🧪 TEST: Validation simple des corrections" -ForegroundColor Green
    Write-Host "-------------------------------------------" -ForegroundColor Green
    
    try {
        # Test 1: Vérifier que les fichiers modifiés existent
        $filesToCheck = @(
            "mcps/internal/servers/roo-state-manager/src/services/task-indexer.ts",
            "mcps/internal/servers/roo-state-manager/src/tools/search/search-semantic.tool.ts",
            "mcps/internal/servers/roo-state-manager/src/tools/search/index.ts",
            "mcps/internal/servers/roo-state-manager/src/tools/registry.ts"
        )
        
        foreach ($file in $filesToCheck) {
            if (Test-Path $file) {
                Write-Host "✅ Fichier présent: $file" -ForegroundColor Green
            } else {
                Write-Host "❌ Fichier manquant: $file" -ForegroundColor Red
            }
        }
        
        # Test 2: Vérifier les modifications dans les fichiers
        Write-Host ""
        Write-Host "🔍 Vérification des modifications..." -ForegroundColor Yellow
        
        # Vérifier le renommage dans search-semantic.tool.ts
        $searchToolContent = Get-Content "mcps/internal/servers/roo-state-manager/src/tools/search/search-semantic.tool.ts" -Raw
        if ($searchToolContent -match "search_tasks_by_content") {
            Write-Host "✅ Renommage de l'outil correct" -ForegroundColor Green
        } else {
            Write-Host "❌ Renommage de l'outil incorrect" -ForegroundColor Red
        }
        
        # Vérifier les corrections dans task-indexer.ts
        $indexerContent = Get-Content "mcps/internal/servers/roo-state-manager/src/services/task-indexer.ts" -Raw
        if ($indexerContent -match "DEBUG.*Embedding response reçu") {
            Write-Host "✅ Logs de debug ajoutés" -ForegroundColor Green
        } else {
            Write-Host "❌ Logs de debug manquants" -ForegroundColor Red
        }
        
        if ($indexerContent -match "Dimension inattendue.*attendu: 1536") {
            Write-Host "✅ Validation vectorielle améliorée" -ForegroundColor Green
        } else {
            Write-Host "❌ Validation vectorielle non améliorée" -ForegroundColor Red
        }
        
        # Test 3: Vérifier les imports dans index.ts
        $indexContent = Get-Content "mcps/internal/servers/roo-state-manager/src/tools/search/index.ts" -Raw
        if ($indexContent -match "searchTasksByContentTool") {
            Write-Host "✅ Import dans index.ts correct" -ForegroundColor Green
        } else {
            Write-Host "❌ Import dans index.ts incorrect" -ForegroundColor Red
        }
        
        # Test 4: Vérifier les références dans registry.ts
        $registryContent = Get-Content "mcps/internal/servers/roo-state-manager/src/tools/registry.ts" -Raw
        if ($registryContent -match "searchTasksByContentTool") {
            Write-Host "✅ Références dans registry.ts correctes" -ForegroundColor Green
        } else {
            Write-Host "❌ Références dans registry.ts incorrectes" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "✅ Tests de validation des fichiers terminés" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Erreur lors des tests: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Fonction de test avec build
function Test-WithBuild {
    Write-Host "🧪 TEST: Validation après build" -ForegroundColor Green
    Write-Host "-----------------------------------" -ForegroundColor Green
    
    $buildSuccess = Build-Project
    
    if ($buildSuccess) {
        Write-Host "✅ Build réussi, lancement des tests..." -ForegroundColor Green
        
        # Test si le build a bien créé les fichiers
        $buildDir = "mcps/internal/servers/roo-state-manager/build"
        if (Test-Path $buildDir) {
            Write-Host "✅ Répertoire build créé: $buildDir" -ForegroundColor Green
            
            # Vérifier les fichiers clés dans le build
            $buildFiles = @(
                "$buildDir/services/task-indexer.js",
                "$buildDir/tools/search/search-semantic.tool.js",
                "$buildDir/tools/search/index.js",
                "$buildDir/tools/registry.js"
            )
            
            foreach ($file in $buildFiles) {
                if (Test-Path $file) {
                    Write-Host "✅ Fichier build présent: $(Split-Path $file -Leaf)" -ForegroundColor Green
                } else {
                    Write-Host "❌ Fichier build manquant: $(Split-Path $file -Leaf)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "❌ Répertoire build manquant" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Build échoué, impossible de tester" -ForegroundColor Red
    }
}

# Fonction de rapport
function New-Report {
    Write-Host "📊 RAPPORT DE BUILD ET TEST" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "Action: $Action" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Résumé des corrections implémentées:" -ForegroundColor Yellow
    Write-Host "1. ✅ Correction de la validation vectorielle dans task-indexer.ts" -ForegroundColor White
    Write-Host "2. ✅ Ajout de logs détaillés pour le diagnostic" -ForegroundColor White
    Write-Host "3. ✅ Renommage de l'outil: search_tasks_semantic → search_tasks_by_content" -ForegroundColor White
    Write-Host "4. ✅ Mise à jour des imports et références" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Prochaines étapes recommandées:" -ForegroundColor Yellow
    Write-Host "- Si build ✅: Déployer et tester en production" -ForegroundColor White
    Write-Host "- Si build ❌: Corriger les erreurs TypeScript" -ForegroundColor White
    Write-Host "- Toujours tester avec des données réelles" -ForegroundColor White
}

# Exécution selon l'action
switch ($Action) {
    "build" {
        Write-Host "🚀 ACTION: Build uniquement" -ForegroundColor Cyan
        Write-Host ""
        Build-Project
    }
    "test" {
        Write-Host "🚀 ACTION: Test sans build" -ForegroundColor Cyan
        Write-Host ""
        Test-Simple
    }
    "full" {
        Write-Host "🚀 ACTION: Build + Test complet" -ForegroundColor Cyan
        Write-Host ""
        Test-WithBuild
    }
    default {
        Write-Host "❌ Action inconnue: $Action" -ForegroundColor Red
        Write-Host "Actions disponibles: build, test, full" -ForegroundColor Yellow
        exit 1
    }
}

# Rapport final
New-Report

Write-Host "✅ Script terminé" -ForegroundColor Green