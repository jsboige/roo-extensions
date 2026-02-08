/**
 * Test des mécanismes de désescalade pour l'architecture d'orchestration à 5 niveaux
 * 
 * Ce script teste les mécanismes de désescalade entre les différents niveaux de complexité
 * pour s'assurer qu'ils fonctionnent correctement selon les critères définis.
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Configuration
const CONFIG_DIR = path.join(__dirname, '..', 'configs');
const TEST_RESULTS_DIR = path.join(__dirname, '..', 'test-results');
const LEVELS = ['micro', 'mini', 'medium', 'large', 'oracle'];

// Création du répertoire de résultats de test s'il n'existe pas
if (!fs.existsSync(TEST_RESULTS_DIR)) {
    fs.mkdirSync(TEST_RESULTS_DIR, { recursive: true });
}

// Fonction pour charger une configuration
function loadConfig(level) {
    const configPath = path.join(CONFIG_DIR, `${level}-modes.json`);
    if (!fs.existsSync(configPath)) {
        console.error(`Configuration non trouvée : ${configPath}`);
        return null;
    }
    try {
        return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (error) {
        console.error(`Erreur lors du chargement de la configuration ${level} :`, error);
        return null;
    }
}

// Fonction pour valider les mécanismes de désescalade dans les instructions personnalisées
function validateDeescalationMechanisms(config) {
    const results = {
        level: config.complexityLevel.level,
        name: config.complexityLevel.name,
        slug: config.complexityLevel.slug,
        valid: true,
        errors: [],
        warnings: []
    };

    // Pas de désescalade pour le niveau MICRO
    if (config.complexityLevel.level === 1) {
        results.valid = true;
        results.warnings.push('Niveau MICRO : pas de désescalade possible (niveau le plus bas)');
        return results;
    }

    // Vérification pour chaque mode personnalisé
    for (const mode of config.customModes || []) {
        const instructions = mode.customInstructions || '';
        
        // Vérification de la présence des mécanismes de désescalade
        if (!instructions.includes('MÉCANISME DE DÉSESCALADE')) {
            results.valid = false;
            results.errors.push(`Mode ${mode.slug} : Mécanisme de désescalade manquant`);
        }
        
        // Vérification du format de désescalade
        const hasDesescaladeSuggeree = instructions.includes('[DÉSESCALADE SUGGÉRÉE]');
        
        if (!hasDesescaladeSuggeree) {
            results.valid = false;
            results.errors.push(`Mode ${mode.slug} : Format de désescalade manquant`);
        }
        
        // Vérification de la présence des critères de désescalade
        if (!instructions.includes('Critères spécifiques') || 
            !instructions.includes('évaluer la simplicité')) {
            results.warnings.push(`Mode ${mode.slug} : Critères de désescalade potentiellement manquants ou mal formatés`);
        }
        
        // Vérification de la présence du processus d'évaluation continue
        if (!instructions.includes('Processus d\'évaluation continue')) {
            results.warnings.push(`Mode ${mode.slug} : Processus d'évaluation continue potentiellement manquant`);
        }
        
        // Vérification de la référence au niveau précédent
        const previousLevel = config.complexityLevel.previousLevel;
        if (!previousLevel) {
            results.valid = false;
            results.errors.push(`Mode ${mode.slug} : Niveau précédent non défini`);
        } else if (!instructions.includes(previousLevel.toUpperCase())) {
            results.warnings.push(`Mode ${mode.slug} : Référence au niveau précédent (${previousLevel.toUpperCase()}) potentiellement manquante`);
        }
    }

    return results;
}

// Fonction pour simuler des scénarios de désescalade
function simulateDeescalationScenarios(config) {
    const results = {
        level: config.complexityLevel.level,
        name: config.complexityLevel.name,
        slug: config.complexityLevel.slug,
        scenarios: [],
        valid: true
    };

    // Pas de désescalade pour le niveau MICRO
    if (config.complexityLevel.level === 1) {
        results.scenarios.push({
            name: 'Pas de désescalade (niveau le plus bas)',
            input: {
                codeComplexity: 10,
                conversationSize: 3,
                tokenCount: 5000
            },
            expectedDeescalation: false,
            actualDeescalation: false,
            passed: true
        });
        
        return results;
    }

    // Définition des scénarios de test selon le niveau
    const scenarios = [];
    
    // Extraction des seuils du niveau précédent
    const previousLevel = config.complexityLevel.previousLevel;
    const previousConfig = loadConfig(previousLevel);
    
    if (!previousConfig) {
        results.valid = false;
        results.scenarios.push({
            name: 'Impossible de charger la configuration du niveau précédent',
            passed: false
        });
        return results;
    }
    
    const previousMetrics = previousConfig.complexityLevel.metrics;
    
    // Scénario 1 : Désescalade basée sur la complexité du code
    if (previousMetrics.codeLines && previousMetrics.codeLines.max) {
        const threshold = previousMetrics.codeLines.max - 10;
        scenarios.push({
            name: 'Désescalade par complexité de code',
            input: {
                codeComplexity: threshold,
                conversationSize: 20,
                tokenCount: 50000
            },
            expectedDeescalation: true
        });
    }
    
    // Scénario 2 : Désescalade basée sur la taille de la conversation
    if (previousMetrics.conversationSize && previousMetrics.conversationSize.messages && previousMetrics.conversationSize.messages.max) {
        const threshold = previousMetrics.conversationSize.messages.max - 2;
        scenarios.push({
            name: 'Désescalade par taille de conversation',
            input: {
                codeComplexity: 300,
                conversationSize: threshold,
                tokenCount: 50000
            },
            expectedDeescalation: true
        });
    }
    
    // Scénario 3 : Désescalade basée sur le nombre de tokens
    if (previousMetrics.conversationSize && previousMetrics.conversationSize.tokens && previousMetrics.conversationSize.tokens.max) {
        const threshold = previousMetrics.conversationSize.tokens.max - 5000;
        scenarios.push({
            name: 'Désescalade par nombre de tokens',
            input: {
                codeComplexity: 300,
                conversationSize: 20,
                tokenCount: threshold
            },
            expectedDeescalation: true
        });
    }
    
    // Scénario 4 : Pas de désescalade (au-dessus des seuils)
    scenarios.push({
        name: 'Pas de désescalade (au-dessus des seuils)',
        input: {
            codeComplexity: 1000,
            conversationSize: 30,
            tokenCount: 100000
        },
        expectedDeescalation: false
    });

    // Exécution des scénarios
    for (const scenario of scenarios) {
        const shouldDeescalate = evaluateDeescalation(config, previousConfig, scenario.input);
        const scenarioResult = {
            name: scenario.name,
            input: scenario.input,
            expectedDeescalation: scenario.expectedDeescalation,
            actualDeescalation: shouldDeescalate,
            passed: shouldDeescalate === scenario.expectedDeescalation
        };
        
        results.scenarios.push(scenarioResult);
        
        if (!scenarioResult.passed) {
            results.valid = false;
        }
    }

    return results;
}

// Fonction pour évaluer si une désescalade est possible
function evaluateDeescalation(config, previousConfig, input) {
    // Pas de désescalade pour le niveau MICRO
    if (config.complexityLevel.level === 1) {
        return false;
    }
    
    const currentMetrics = config.complexityLevel.metrics;
    const previousMetrics = previousConfig.complexityLevel.metrics;
    
    // Vérification des seuils
    if (previousMetrics.codeLines && previousMetrics.codeLines.max && 
        input.codeComplexity <= previousMetrics.codeLines.max) {
        return true;
    }
    
    if (previousMetrics.conversationSize && previousMetrics.conversationSize.messages && 
        previousMetrics.conversationSize.messages.max && 
        input.conversationSize <= previousMetrics.conversationSize.messages.max) {
        return true;
    }
    
    if (previousMetrics.conversationSize && previousMetrics.conversationSize.tokens && 
        previousMetrics.conversationSize.tokens.max && 
        input.tokenCount <= previousMetrics.conversationSize.tokens.max) {
        return true;
    }
    
    return false;
}

// Fonction principale de test
function runTests() {
    console.log('Démarrage des tests des mécanismes de désescalade...');
    
    const results = {
        timestamp: new Date().toISOString(),
        mechanisms: {},
        scenarios: {},
        summary: {
            total: 0,
            passed: 0,
            failed: 0,
            warnings: 0
        }
    };
    
    // Test pour chaque niveau
    for (const level of LEVELS) {
        console.log(`\nTest du niveau ${level.toUpperCase()}...`);
        
        const config = loadConfig(level);
        if (!config) {
            console.log(`Impossible de tester le niveau ${level.toUpperCase()} : configuration non trouvée`);
            continue;
        }
        
        // Test des mécanismes de désescalade
        console.log(`- Test des mécanismes de désescalade...`);
        const mechanismResults = validateDeescalationMechanisms(config);
        results.mechanisms[level] = mechanismResults;
        
        if (mechanismResults.valid) {
            console.log(`  ✅ Mécanismes de désescalade valides`);
            results.summary.passed++;
        } else {
            console.log(`  ❌ Mécanismes de désescalade invalides :`);
            for (const error of mechanismResults.errors) {
                console.log(`    - ${error}`);
            }
            results.summary.failed++;
        }
        
        if (mechanismResults.warnings.length > 0) {
            console.log(`  ⚠️ Avertissements :`);
            for (const warning of mechanismResults.warnings) {
                console.log(`    - ${warning}`);
            }
            results.summary.warnings += mechanismResults.warnings.length;
        }
        
        // Test des scénarios de désescalade
        console.log(`- Test des scénarios de désescalade...`);
        const scenarioResults = simulateDeescalationScenarios(config);
        results.scenarios[level] = scenarioResults;
        
        let scenariosPassed = 0;
        let scenariosFailed = 0;
        
        for (const scenario of scenarioResults.scenarios) {
            if (scenario.passed) {
                console.log(`  ✅ Scénario "${scenario.name}" : Réussi`);
                scenariosPassed++;
            } else {
                console.log(`  ❌ Scénario "${scenario.name}" : Échec (Attendu: ${scenario.expectedDeescalation}, Obtenu: ${scenario.actualDeescalation})`);
                scenariosFailed++;
            }
        }
        
        console.log(`  Scénarios : ${scenariosPassed} réussis, ${scenariosFailed} échoués`);
        
        results.summary.passed += scenariosPassed;
        results.summary.failed += scenariosFailed;
        results.summary.total += scenariosPassed + scenariosFailed;
    }
    
    // Résumé des tests
    console.log('\nRésumé des tests :');
    console.log(`- Total : ${results.summary.total} tests`);
    console.log(`- Réussis : ${results.summary.passed} tests`);
    console.log(`- Échoués : ${results.summary.failed} tests`);
    console.log(`- Avertissements : ${results.summary.warnings}`);
    
    // Sauvegarde des résultats
    const resultsPath = path.join(TEST_RESULTS_DIR, `deescalation-test-results-${new Date().toISOString().replace(/:/g, '-')}.json`);
    fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
    console.log(`\nRésultats sauvegardés dans : ${resultsPath}`);
    
    return results.summary.failed === 0;
}

// Exécution des tests
const success = runTests();
process.exit(success ? 0 : 1);