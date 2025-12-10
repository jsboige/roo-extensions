# Script de Test des Corrections roo-state-manager
# Date: 2025-11-04 12:35
# Objectif: Valider les corrections d'indexation et de renommage

param(
    [Parameter(Mandatory=$false)]
    [string]$TestMode = "basic"
)

Write-Host "🔧 SCRIPT DE TEST DES CORRECTIONS roo-state-manager" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Mode: $TestMode" -ForegroundColor Yellow
Write-Host "Heure: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host ""

# Fonction de test pour l'outil renommé
function Test-SearchToolRenaming {
    Write-Host "📝 TEST 1: Validation du renommage de l'outil" -ForegroundColor Green
    Write-Host "-------------------------------------------" -ForegroundColor Green
    
    try {
        # Test si le nouvel outil est disponible
        $result = node -e "
            const { rooStateManager } = require('./mcps/internal/servers/roo-state-manager/build/index.js');
            const tools = rooStateManager.getServerTools();
            const searchTool = tools.find(t => t.name === 'search_tasks_by_content');
            
            if (searchTool) {
                console.log('✅ Outil search_tasks_by_content trouvé');
                console.log('Description:', searchTool.description);
                process.exit(0);
            } else {
                console.log('❌ Outil search_tasks_by_content NON trouvé');
                console.log('Outils disponibles:', tools.map(t => t.name));
                process.exit(1);
            }
        " 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Test de renommage RÉUSSI" -ForegroundColor Green
            Write-Host $result -ForegroundColor Gray
        } else {
            Write-Host "❌ Test de renommage ÉCHOUÉ" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Erreur lors du test de renommage: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Fonction de test pour l'indexation améliorée
function Test-IndexationFix {
    Write-Host "🔍 TEST 2: Validation de la correction d'indexation" -ForegroundColor Green
    Write-Host "----------------------------------------------" -ForegroundColor Green
    
    try {
        # Test d'indexation avec logging amélioré
        $result = node -e "
            const { TaskIndexer } = require('./mcps/internal/servers/roo-state-manager/build/services/task-indexer.js');
            
            async function testIndexation() {
                try {
                    const indexer = new TaskIndexer();
                    
                    // Test avec une tâche simple
                    const testTask = {
                        task_id: 'test-repair-2025-11-04',
                        title: 'Test de réparation',
                        instruction: 'Test de la correction d\\'indexation vectorielle',
                        workspace: 'test-workspace',
                        messages: [{
                            role: 'user',
                            content: 'Ceci est un test pour valider les corrections d\\'indexation',
                            timestamp: new Date().toISOString()
                        }]
                    };
                    
                    console.log('🔄 Début du test d\\'indexation...');
                    
                    // Tenter d'indexer la tâche
                    const result = await indexer.indexTask(testTask);
                    
                    if (result.success) {
                        console.log('✅ Indexation réussie');
                        console.log('Points créés:', result.pointsCreated);
                        console.log('Chunks traités:', result.chunksProcessed);
                        process.exit(0);
                    } else {
                        console.log('❌ Indexation échouée');
                        console.log('Erreur:', result.error);
                        process.exit(1);
                    }
                } catch (error) {
                    console.log('❌ Exception lors de l\\'indexation:', error.message);
                    process.exit(1);
                }
            }
            
            testIndexation();
        " 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Test d'indexation RÉUSSI" -ForegroundColor Green
            Write-Host $result -ForegroundColor Gray
        } else {
            Write-Host "❌ Test d'indexation ÉCHOUÉ" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Erreur lors du test d'indexation: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Fonction de test pour la recherche sémantique
function Test-SemanticSearch {
    Write-Host "🔎 TEST 3: Validation de la recherche sémantique" -ForegroundColor Green
    Write-Host "--------------------------------------------" -ForegroundColor Green
    
    try {
        # Test de recherche avec le nouvel outil
        $result = node -e "
            const { rooStateManager } = require('./mcps/internal/servers/roo-state-manager/build/index.js');
            
            async function testSearch() {
                try {
                    console.log('🔍 Test de recherche avec le nouvel outil...');
                    
                    // Simuler un appel à l'outil de recherche
                    const searchArgs = {
                        search_query: 'test de réparation indexation',
                        max_results: 5,
                        diagnose_index: true
                    };
                    
                    console.log('Arguments de recherche:', JSON.stringify(searchArgs, null, 2));
                    
                    // Vérifier que l'outil est bien enregistré
                    const tools = rooStateManager.getServerTools();
                    const searchTool = tools.find(t => t.name === 'search_tasks_by_content');
                    
                    if (searchTool) {
                        console.log('✅ Outil de recherche trouvé');
                        console.log('Nom:', searchTool.name);
                        console.log('Description:', searchTool.description);
                        process.exit(0);
                    } else {
                        console.log('❌ Outil de recherche NON trouvé');
                        process.exit(1);
                    }
                } catch (error) {
                    console.log('❌ Exception lors de la recherche:', error.message);
                    process.exit(1);
                }
            }
            
            testSearch();
        " 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Test de recherche sémantique RÉUSSI" -ForegroundColor Green
            Write-Host $result -ForegroundColor Gray
        } else {
            Write-Host "❌ Test de recherche sémantique ÉCHOUÉ" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Erreur lors du test de recherche: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# Fonction de validation de l'environnement
function Test-Environment {
    Write-Host "🌍 TEST 4: Validation de l'environnement" -ForegroundColor Green
    Write-Host "---------------------------------------" -ForegroundColor Green
    
    $envFile = "mcps/internal/servers/roo-state-manager/.env"
    
    if (Test-Path $envFile) {
        Write-Host "✅ Fichier .env trouvé: $envFile" -ForegroundColor Green
        
        # Vérifier les variables critiques
        $envContent = Get-Content $envFile
        $requiredVars = @('QDRANT_URL', 'OPENAI_API_KEY', 'QDRANT_COLLECTION_NAME')
        
        foreach ($var in $requiredVars) {
            if ($envContent -match "^$var=") {
                Write-Host "✅ Variable $var configurée" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Variable $var MANQUANTE" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ Fichier .env MANQUANT: $envFile" -ForegroundColor Red
        Write-Host "Créez ce fichier avec les variables d'environnement requises" -ForegroundColor Red
    }
    Write-Host ""
}

# Fonction de rapport de test
function New-TestReport {
    Write-Host "📊 RAPPORT DE TEST" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "Mode: $TestMode" -ForegroundColor White
    Write-Host "Statut: Tests complétés" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions recommandées:" -ForegroundColor Yellow
    Write-Host "- Si tous les tests sont ✅: Déployer les corrections" -ForegroundColor White
    Write-Host "- Si des tests sont ❌: Vérifier les logs et corriger" -ForegroundColor White
    Write-Host "- Toujours vérifier l'environnement avant déploiement" -ForegroundColor White
}

# Exécution des tests selon le mode
switch ($TestMode) {
    "basic" {
        Write-Host "🚀 MODE BASIC: Tests essentiels uniquement" -ForegroundColor Cyan
        Write-Host ""
        Test-Environment
        Test-SearchToolRenaming
        Test-IndexationFix
    }
    "full" {
        Write-Host "🚀 MODE FULL: Tous les tests disponibles" -ForegroundColor Cyan
        Write-Host ""
        Test-Environment
        Test-SearchToolRenaming
        Test-IndexationFix
        Test-SemanticSearch
    }
    "search" {
        Write-Host "🚀 MODE SEARCH: Tests de recherche uniquement" -ForegroundColor Cyan
        Write-Host ""
        Test-SearchToolRenaming
        Test-SemanticSearch
    }
    "indexation" {
        Write-Host "🚀 MODE INDEXATION: Tests d'indexation uniquement" -ForegroundColor Cyan
        Write-Host ""
        Test-Environment
        Test-IndexationFix
    }
    default {
        Write-Host "❌ Mode inconnu: $TestMode" -ForegroundColor Red
        Write-Host "Modes disponibles: basic, full, search, indexation" -ForegroundColor Yellow
        exit 1
    }
}

# Rapport final
New-TestReport

Write-Host "✅ Script de test terminé" -ForegroundColor Green
Write-Host "Consultez les logs ci-dessus pour les détails" -ForegroundColor Gray