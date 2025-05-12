/**
 * Script de test du système de verrouillage de famille
 * 
 * Ce script teste le système de verrouillage de famille pour vérifier
 * qu'il empêche correctement le basculement inapproprié des modes
 * simples/complexes vers les modes standard.
 */

const fs = require('fs');
const path = require('path');
const { validateModeTransition } = require('./validate-mode-transitions');

// Configuration
const TEST_RESULTS_DIR = path.join(__dirname, '..', 'test-results');
const CONFIG_PATH = path.join(__dirname, '..', 'configs', 'standard-modes.json');

// Créer le répertoire de résultats de test s'il n'existe pas
if (!fs.existsSync(TEST_RESULTS_DIR)) {
  fs.mkdirSync(TEST_RESULTS_DIR, { recursive: true });
}

/**
 * Charge la configuration des modes
 * @returns {Object} Configuration des modes
 */
function loadModesConfig() {
  try {
    const configContent = fs.readFileSync(CONFIG_PATH, 'utf8');
    return JSON.parse(configContent);
  } catch (error) {
    console.error(`Erreur lors du chargement de la configuration: ${error.message}`);
    return null;
  }
}

/**
 * Définit les scénarios de test
 * @param {Object} modesConfig Configuration des modes
 * @returns {Array<Object>} Scénarios de test
 */
function defineTestScenarios(modesConfig) {
  // Récupérer les modes par famille
  const simpleModes = modesConfig.customModes
    .filter(mode => mode.family === 'simple')
    .map(mode => mode.slug);
  
  const complexModes = modesConfig.customModes
    .filter(mode => mode.family === 'complex')
    .map(mode => mode.slug);
  
  const standardModes = modesConfig.customModes
    .filter(mode => !mode.family || mode.family === 'standard')
    .filter(mode => mode.slug !== 'mode-family-validator')
    .map(mode => mode.slug);
  
  // Définir les scénarios de test
  const scenarios = [];
  
  // Scénario 1: Transitions valides au sein de la famille simple
  for (const sourceMode of simpleModes) {
    for (const targetMode of simpleModes) {
      if (sourceMode !== targetMode) {
        scenarios.push({
          name: `Transition valide: ${sourceMode} -> ${targetMode}`,
          sourceMode,
          targetMode,
          expectedResult: true
        });
      }
    }
  }
  
  // Scénario 2: Transitions valides au sein de la famille complex
  for (const sourceMode of complexModes) {
    for (const targetMode of complexModes) {
      if (sourceMode !== targetMode) {
        scenarios.push({
          name: `Transition valide: ${sourceMode} -> ${targetMode}`,
          sourceMode,
          targetMode,
          expectedResult: true
        });
      }
    }
  }
  
  // Scénario 3: Transitions invalides de simple vers complex
  for (const sourceMode of simpleModes) {
    for (const targetMode of complexModes) {
      scenarios.push({
        name: `Transition invalide: ${sourceMode} -> ${targetMode}`,
        sourceMode,
        targetMode,
        expectedResult: false
      });
    }
  }
  
  // Scénario 4: Transitions invalides de complex vers simple
  for (const sourceMode of complexModes) {
    for (const targetMode of simpleModes) {
      scenarios.push({
        name: `Transition invalide: ${sourceMode} -> ${targetMode}`,
        sourceMode,
        targetMode,
        expectedResult: false
      });
    }
  }
  
  // Scénario 5: Transitions invalides de simple vers standard
  for (const sourceMode of simpleModes) {
    for (const targetMode of standardModes) {
      scenarios.push({
        name: `Transition invalide: ${sourceMode} -> ${targetMode}`,
        sourceMode,
        targetMode,
        expectedResult: false
      });
    }
  }
  
  // Scénario 6: Transitions invalides de complex vers standard
  for (const sourceMode of complexModes) {
    for (const targetMode of standardModes) {
      scenarios.push({
        name: `Transition invalide: ${sourceMode} -> ${targetMode}`,
        sourceMode,
        targetMode,
        expectedResult: false
      });
    }
  }
  
  return scenarios;
}

/**
 * Exécute les scénarios de test
 * @param {Array<Object>} scenarios Scénarios de test
 * @returns {Object} Résultats des tests
 */
function runTestScenarios(scenarios) {
  const results = {
    timestamp: new Date().toISOString(),
    total: scenarios.length,
    passed: 0,
    failed: 0,
    scenarios: []
  };
  
  for (const scenario of scenarios) {
    const validationResult = validateModeTransition(scenario.sourceMode, scenario.targetMode);
    const passed = validationResult.valid === scenario.expectedResult;
    
    const scenarioResult = {
      name: scenario.name,
      sourceMode: scenario.sourceMode,
      targetMode: scenario.targetMode,
      expectedResult: scenario.expectedResult,
      actualResult: validationResult.valid,
      reason: validationResult.reason || '',
      passed
    };
    
    results.scenarios.push(scenarioResult);
    
    if (passed) {
      results.passed++;
    } else {
      results.failed++;
      console.error(`❌ ${scenario.name}: Attendu ${scenario.expectedResult}, obtenu ${validationResult.valid}`);
      if (validationResult.reason) {
        console.error(`   Raison: ${validationResult.reason}`);
      }
    }
  }
  
  return results;
}

/**
 * Exécute les tests du système de verrouillage de famille
 * @returns {boolean} Indique si tous les tests ont réussi
 */
function runTests() {
  console.log('Exécution des tests du système de verrouillage de famille...');
  
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    console.error('Impossible de charger la configuration des modes. Tests annulés.');
    return false;
  }
  
  // Définir les scénarios de test
  const scenarios = defineTestScenarios(modesConfig);
  console.log(`${scenarios.length} scénarios de test définis.`);
  
  // Exécuter les scénarios de test
  const results = runTestScenarios(scenarios);
  
  // Afficher les résultats
  console.log('\nRésultats des tests:');
  console.log(`Total: ${results.total} tests`);
  console.log(`Réussis: ${results.passed} tests`);
  console.log(`Échoués: ${results.failed} tests`);
  
  // Sauvegarder les résultats
  const resultsPath = path.join(TEST_RESULTS_DIR, `family-lock-test-results-${new Date().toISOString().replace(/:/g, '-')}.json`);
  fs.writeFileSync(resultsPath, JSON.stringify(results, null, 2));
  console.log(`\nRésultats sauvegardés dans: ${resultsPath}`);
  
  return results.failed === 0;
}

// Si le script est exécuté directement, exécuter les tests
if (require.main === module) {
  const success = runTests();
  process.exit(success ? 0 : 1);
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  runTests
};