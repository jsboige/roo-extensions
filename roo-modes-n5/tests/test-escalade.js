/**
 * Test des mécanismes d'escalade pour l'architecture d'orchestration à 5 niveaux
 * 
 * Ce script teste les mécanismes d'escalade entre les différents niveaux de complexité
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

// Fonction pour valider les seuils d'escalade
function validateEscalationThresholds(config) {
    const results = {
        level: config.complexityLevel.level,
        name: config.complexityLevel.name,
        slug: config.complexityLevel.slug,
        thresholds: config.complexityLevel.escalationThresholds,
        valid: true,
        errors: []
    };

    // Vérification de la présence des seuils d'escalade
    if (!config.complexityLevel.escalationThresholds) {
        results.valid = false;
        results.errors.push('Seuils d\'escalade manquants');
        return results;
    }

    // Vérification des seuils spécifiques selon le niveau
    const thresholds = config.complexityLevel.escalationThresholds;
    
    // Vérification de la cohérence des seuils entre les niveaux
    if (config.complexityLevel.level < 5) { // Pas de vérification pour le niveau ORACLE
        const nextLevel = config.complexityLevel.nextLevel;
        if (!nextLevel) {
            results.valid = false;
            results.errors.push('Niveau suivant non défini');
        }
        
        // Vérification que le niveau suivant existe
        const nextLevelConfig = loadConfig(nextLevel);
        if (!nextLevelConfig) {
            results.valid = false;
            results.errors.push(`Configuration du niveau suivant (${nextLevel}) non trouvée`);
        } else {
            // Vérification que les seuils sont cohérents avec le niveau suivant
            const nextThresholds = nextLevelConfig.complexityLevel.escalationThresholds;
            
            if (thresholds.codeComplexity && nextThresholds.codeComplexity && 
                thresholds.codeComplexity >= nextThresholds.codeComplexity) {
                results.valid = false;
                results.errors.push(`Seuil de complexité de code incohérent avec le niveau suivant : ${thresholds.codeComplexity} >= ${nextThresholds.codeComplexity}`);
            }
            
            if (thresholds.conversationSize && nextThresholds.conversationSize && 
                thresholds.conversationSize >= nextThresholds.conversationSize) {
                results.valid = false;
                results.errors.push(`Seuil de taille de conversation incohérent avec le niveau suivant : ${thresholds.conversationSize} >= ${nextThresholds.conversationSize}`);
            }
            
            if (thresholds.tokenCount && nextThresholds.tokenCount && 
                thresholds.tokenCount >= nextThresholds.tokenCount) {
                results.valid = false;
                results.errors.push(`Seuil de nombre de tokens incohérent avec le niveau suivant : ${thresholds.tokenCount} >= ${nextThresholds.tokenCount}`);
            }
        }
    }

    return results;
}

// Fonction pour valider les mécanismes d'escalade dans les instructions personnalisées
function validateEscalationMechanisms(config) {
    const results = {
        level: config.complexityLevel.level,
        name: config.complexityLevel.name,
        slug: config.complexityLevel.slug,
        valid: true,
        errors: [],
        warnings: []
    };

    // Vérification pour chaque mode personnalisé
    for (const mode of config.customModes || []) {
        const instructions = mode.customInstructions || '';
        
        // Vérification de la présence des mécanismes d'escalade
        if (!instructions.includes('MÉCANISME D\'ESCALADE') &&
            !instructions.includes('MÉCANISME D\'ESCALADE')) {
            results.valid = false;
            results.errors.push(`Mode ${mode.slug} : Mécanisme d'escalade manquant`);
        }
        
        // Vérification des formats d'escalade
        const hasEscaladeParBranchement = instructions.includes('[ESCALADE PAR BRANCHEMENT]');
        const hasEscaladeNiveau = instructions.includes('[ESCALADE NIVEAU');
        const hasEscaladeParTerminaison = instructions.includes('[ESCALADE PAR TERMINAISON]');
        
        if (!hasEscaladeParBranchement && !hasEscaladeNiveau && !hasEscaladeParTerminaison) {
            results.valid = false;
            results.errors.push(`Mode ${mode.slug} : Formats d'escalade manquants`);
        }
        
        // Vérification de la présence des critères d'escalade
        if (!instructions.includes('Critères spécifiques') || 
            !instructions.includes('évaluer la nécessité d\'escalade')) {
            results.warnings.push(`Mode ${mode.slug} : Critères d'escalade potentiellement manquants ou mal formatés`);
        }
        
        // Vérification de la présence du processus d'évaluation continue
        if (!instructions.includes('Processus d\'évaluation continue') &&
            !instructions.includes('Processus d\'évaluation continue')) {
            results.warnings.push(`Mode ${mode.slug} : Processus d'évaluation continue potentiellement manquant`);
        }
    }

    return results;
}

// Fonction pour simuler des scénarios d'escalade
function simulateEscalationScenarios(config) {
    const results = {
        level: config.complexityLevel.level,
        name: config.complexityLevel.name,
        slug: config.complexityLevel.slug,
        scenarios: [],
        valid: true
    };

    // Définition des scénarios de test selon le niveau
    const scenarios = [];
    
    // Scénario 1 : Escalade basée sur la complexité du code
    if (config.complexityLevel.escalationThresholds.codeComplexity) {
        const threshold = config.complexityLevel.escalationThresholds.codeComplexity;
        scenarios.push({
            name: 'Escalade par complexité de code',
            input: {
                codeComplexity: threshold + 10,
                conversationSize: 5,
                tokenCount: 10000
            },
            expectedEscalation: true
        });
    }
    
    // Scénario 2 : Escalade basée sur la taille de la conversation
    if (config.complexityLevel.escalationThresholds.conversationSize) {
        const threshold = config.complexityLevel.escalationThresholds.conversationSize;
        scenarios.push({
            name: 'Escalade par taille de conversation',
            input: {
                codeComplexity: 50,
                conversationSize: threshold + 2,
                tokenCount: 10000
            },
            expectedEscalation: true
        });
    }
    
    // Scénario 3 : Escalade basée sur le nombre de tokens
    if (config.complexityLevel.escalationThresholds.tokenCount) {
        const threshold = config.complexityLevel.escalationThresholds.tokenCount;
        scenarios.push({
            name: 'Escalade par nombre de tokens',
            input: {
                codeComplexity: 50,
                conversationSize: 5,
                tokenCount: threshold + 5000
            },
            expectedEscalation: true
        });
    }
    
    // Scénario 4 : Pas d'escalade (sous les seuils)
    scenarios.push({
        name: 'Pas d\'escalade (sous les seuils)',
        input: {
            codeComplexity: 10,
            conversationSize: 3,
            tokenCount: 5000
        },
        expectedEscalation: false
    });

    // Exécution des scénarios
    for (const scenario of scenarios) {
        const shouldEscalate = evaluateEscalation(config, scenario.input);
        const scenarioResult = {
            name: scenario.name,
            input: scenario.input,
            expectedEscalation: scenario.expectedEscalation,
            actualEscalation: shouldEscalate,
            passed: shouldEscalate === scenario.expectedEscalation
        };
        
        results.scenarios.push(scenarioResult);
        
        if (!scenarioResult.passed) {
            results.valid = false;
        }
    }

    return results;
}

// Fonction pour évaluer si une escalade est nécessaire
function evaluateEscalation(config, input) {
    const thresholds = config.complexityLevel.escalationThresholds;
    
    // Vérification des seuils
    if (thresholds.codeComplexity && input.codeComplexity > thresholds.codeComplexity) {
        return true;
    }
    
    if (thresholds.conversationSize && input.conversationSize > thresholds.conversationSize) {
        return true;
    }
    
    if (thresholds.tokenCount && input.tokenCount > thresholds.tokenCount) {
        return true;
    }
    
    return false;
}

// Fonction principale de test
function runTests() {
    console.log('Démarrage des tests des mécanismes d\'escalade...');
    
    const results = {
        timestamp: new Date().toISOString(),
        thresholds: {},
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
        
        // Test des seuils d'escalade
        console.log(`- Test des seuils d'escalade...`);
        const thresholdResults = validateEscalationThresholds(config);
        results.thresholds[level] = thresholdResults;
        
        if (thresholdResults.valid) {
            console.log(`  ✅ Seuils d'escalade valides`);
            results.summary.passed++;
        } else {
            console.log(`  ❌ Seuils d'escalade invalides :`);
            for (const error of thresholdResults.errors) {
                console.log(`    - ${error}`);
            }
            results.summary.failed++;
        }
        
        // Test des mécanismes d'escalade
        console.log(`- Test des mécanismes d'escalade...`);
        const mechanismResults = validateEscalationMechanisms(config);
        results.mechanisms[level] = mechanismResults;
        
        if (mechanismResults.valid) {
            console.log(`  ✅ Mécanismes d'escalade valides`);
            results.summary.passed++;
        } else {
            console.log(`  ❌ Mécanismes d'escalade invalides :`);
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
        
        // Test des scénarios d'escalade
        console.log(`- Test des scénarios d'escalade...`);
        const scenarioResults = simulateEscalationScenarios(config);
        results.scenarios[level] = scenarioResults;
        
        let scenariosPassed = 0;
        let scenariosFailed = 0;
        
        for (const scenario of scenarioResults.scenarios) {
            if (scenario.passed) {
                console.log(`  ✅ Scénario "${scenario.name}" : Réussi`);
                scenariosPassed++;
            } else {
                console.log(`  ❌ Scénario "${scenario.name}" : Échec (Attendu: ${scenario.expectedEscalation}, Obtenu: ${scenario.actualEscalation})`);
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
    const resultsPath = path.join(TEST_RESULTS_DIR, `escalation-test-results-${new Date().toISOString().replace(/:/g, '-')}.json`);
    fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
    console.log(`\nRésultats sauvegardés dans : ${resultsPath}`);
    
    return results.summary.failed === 0;
}

// Exécution des tests
const success = runTests();
process.exit(success ? 0 : 1);