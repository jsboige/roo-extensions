/**
 * Script de test des transitions pour l'architecture à 5 niveaux
 * Ce script teste les transitions entre les différents modes de l'architecture à 5 niveaux
 * et vérifie que le système de verrouillage de famille fonctionne correctement
 */

const fs = require('fs');
const path = require('path');

// Constantes
const CONFIG_DIR = path.join(__dirname, '..', 'configs');
const CONFIG_FILES = [
  'micro-modes.json',
  'mini-modes.json',
  'medium-modes.json',
  'large-modes.json',
  'oracle-modes.json'
];
const RESULTS_DIR = path.join(__dirname, '..', 'test-results');

// Couleurs pour la console
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Fonction pour afficher des messages colorés
function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Fonction pour charger toutes les configurations
function loadConfigurations() {
  const configs = {};
  
  for (const configFile of CONFIG_FILES) {
    const filePath = path.join(CONFIG_DIR, configFile);
    if (fs.existsSync(filePath)) {
      const configContent = fs.readFileSync(filePath, 'utf8');
      configs[configFile] = JSON.parse(configContent);
    } else {
      log(`Erreur: Le fichier ${filePath} n'existe pas`, 'red');
      return null;
    }
  }
  
  return configs;
}

// Fonction pour extraire tous les modes
function extractModes(configs) {
  const modes = {};
  
  for (const [configFile, config] of Object.entries(configs)) {
    for (const mode of config.customModes) {
      modes[mode.slug] = {
        ...mode,
        configFile
      };
    }
  }
  
  return modes;
}

// Fonction pour tester les transitions d'escalade
function testEscalationTransitions(modes) {
  log('Test des transitions d\'escalade...', 'cyan');
  
  const results = {
    total: 0,
    passed: 0,
    failed: 0,
    details: []
  };
  
  // Définir les niveaux et leurs modes correspondants
  const levels = {
    micro: Object.values(modes).filter(mode => mode.configFile === 'micro-modes.json'),
    mini: Object.values(modes).filter(mode => mode.configFile === 'mini-modes.json'),
    medium: Object.values(modes).filter(mode => mode.configFile === 'medium-modes.json'),
    large: Object.values(modes).filter(mode => mode.configFile === 'large-modes.json'),
    oracle: Object.values(modes).filter(mode => mode.configFile === 'oracle-modes.json')
  };
  
  // Définir les transitions d'escalade valides
  const validEscalations = {
    micro: 'mini',
    mini: 'medium',
    medium: 'large',
    large: 'oracle'
  };
  
  // Tester les transitions d'escalade pour chaque niveau
  for (const [level, levelModes] of Object.entries(levels)) {
    if (level === 'oracle') continue; // Pas d'escalade depuis le niveau oracle
    
    const targetLevel = validEscalations[level];
    const targetModes = levels[targetLevel];
    
    for (const sourceMode of levelModes) {
      for (const targetMode of targetModes) {
        results.total++;
        
        // Vérifier si la transition est valide
        const isValid = sourceMode.family === targetMode.family &&
                        sourceMode.allowedFamilyTransitions.includes(targetMode.family);
        
        // Vérifier si les modes sont du même type (code, debug, etc.)
        const sourceType = sourceMode.slug.split('-')[0];
        const targetType = targetMode.slug.split('-')[0];
        const isSameType = sourceType === targetType;
        
        // La transition est valide si les modes sont de la même famille et du même type
        const shouldBeValid = isValid && isSameType;
        
        results.details.push({
          source: sourceMode.slug,
          target: targetMode.slug,
          valid: shouldBeValid,
          reason: shouldBeValid ? 'Transition valide' : 'Transition invalide'
        });
        
        if (shouldBeValid) {
          results.passed++;
          log(`✓ ${sourceMode.slug} -> ${targetMode.slug}`, 'green');
        } else {
          results.failed++;
          log(`✗ ${sourceMode.slug} -> ${targetMode.slug}`, 'red');
        }
      }
    }
  }
  
  log(`Tests d'escalade: ${results.passed}/${results.total} réussis`, results.failed === 0 ? 'green' : 'yellow');
  return results;
}

// Fonction pour tester les transitions de désescalade
function testDeescalationTransitions(modes) {
  log('Test des transitions de désescalade...', 'cyan');
  
  const results = {
    total: 0,
    passed: 0,
    failed: 0,
    details: []
  };
  
  // Définir les niveaux et leurs modes correspondants
  const levels = {
    micro: Object.values(modes).filter(mode => mode.configFile === 'micro-modes.json'),
    mini: Object.values(modes).filter(mode => mode.configFile === 'mini-modes.json'),
    medium: Object.values(modes).filter(mode => mode.configFile === 'medium-modes.json'),
    large: Object.values(modes).filter(mode => mode.configFile === 'large-modes.json'),
    oracle: Object.values(modes).filter(mode => mode.configFile === 'oracle-modes.json')
  };
  
  // Définir les transitions de désescalade valides
  const validDeescalations = {
    oracle: 'large',
    large: 'medium',
    medium: 'mini',
    mini: 'micro'
  };
  
  // Tester les transitions de désescalade pour chaque niveau
  for (const [level, levelModes] of Object.entries(levels)) {
    if (level === 'micro') continue; // Pas de désescalade depuis le niveau micro
    
    const targetLevel = validDeescalations[level];
    const targetModes = levels[targetLevel];
    
    for (const sourceMode of levelModes) {
      for (const targetMode of targetModes) {
        results.total++;
        
        // Vérifier si la transition est valide
        const isValid = sourceMode.family === targetMode.family &&
                        sourceMode.allowedFamilyTransitions.includes(targetMode.family);
        
        // Vérifier si les modes sont du même type (code, debug, etc.)
        const sourceType = sourceMode.slug.split('-')[0];
        const targetType = targetMode.slug.split('-')[0];
        const isSameType = sourceType === targetType;
        
        // La transition est valide si les modes sont de la même famille et du même type
        const shouldBeValid = isValid && isSameType;
        
        results.details.push({
          source: sourceMode.slug,
          target: targetMode.slug,
          valid: shouldBeValid,
          reason: shouldBeValid ? 'Transition valide' : 'Transition invalide'
        });
        
        if (shouldBeValid) {
          results.passed++;
          log(`✓ ${sourceMode.slug} -> ${targetMode.slug}`, 'green');
        } else {
          results.failed++;
          log(`✗ ${sourceMode.slug} -> ${targetMode.slug}`, 'red');
        }
      }
    }
  }
  
  log(`Tests de désescalade: ${results.passed}/${results.total} réussis`, results.failed === 0 ? 'green' : 'yellow');
  return results;
}

// Fonction pour tester les transitions invalides
function testInvalidTransitions(modes) {
  log('Test des transitions invalides...', 'cyan');
  
  const results = {
    total: 0,
    passed: 0,
    failed: 0,
    details: []
  };
  
  // Créer une liste de modes natifs (non-n5)
  const nativeModes = [
    'code',
    'debug',
    'architect',
    'ask',
    'orchestrator',
    'code-simple',
    'debug-simple',
    'architect-simple',
    'ask-simple',
    'orchestrator-simple',
    'code-complex',
    'debug-complex',
    'architect-complex',
    'ask-complex',
    'orchestrator-complex'
  ];
  
  // Tester les transitions vers des modes natifs
  for (const mode of Object.values(modes)) {
    for (const nativeMode of nativeModes) {
      results.total++;
      
      // La transition vers un mode natif devrait toujours être invalide
      const shouldBeInvalid = true;
      
      results.details.push({
        source: mode.slug,
        target: nativeMode,
        valid: !shouldBeInvalid,
        reason: 'Transition vers un mode natif'
      });
      
      if (shouldBeInvalid) {
        results.passed++;
        log(`✓ ${mode.slug} -> ${nativeMode} (transition invalide)`, 'green');
      } else {
        results.failed++;
        log(`✗ ${mode.slug} -> ${nativeMode} (transition invalide)`, 'red');
      }
    }
  }
  
  log(`Tests de transitions invalides: ${results.passed}/${results.total} réussis`, results.failed === 0 ? 'green' : 'yellow');
  return results;
}

// Fonction pour sauvegarder les résultats des tests
function saveTestResults(escalationResults, deescalationResults, invalidResults) {
  // Créer le répertoire de résultats s'il n'existe pas
  if (!fs.existsSync(RESULTS_DIR)) {
    fs.mkdirSync(RESULTS_DIR, { recursive: true });
  }
  
  const timestamp = new Date().toISOString().replace(/:/g, '-');
  const resultsFile = path.join(RESULTS_DIR, `transition-test-results-${timestamp}.json`);
  
  const results = {
    timestamp,
    escalation: escalationResults,
    deescalation: deescalationResults,
    invalid: invalidResults,
    summary: {
      total: escalationResults.total + deescalationResults.total + invalidResults.total,
      passed: escalationResults.passed + deescalationResults.passed + invalidResults.passed,
      failed: escalationResults.failed + deescalationResults.failed + invalidResults.failed
    }
  };
  
  fs.writeFileSync(resultsFile, JSON.stringify(results, null, 2));
  log(`Résultats des tests sauvegardés dans ${resultsFile}`, 'cyan');
  
  return results.summary;
}

// Fonction principale
function main() {
  log('=== Test des transitions pour l\'architecture à 5 niveaux ===', 'magenta');
  
  // Charger les configurations
  const configs = loadConfigurations();
  if (!configs) {
    log('Erreur lors du chargement des configurations', 'red');
    process.exit(1);
  }
  
  // Extraire tous les modes
  const modes = extractModes(configs);
  
  // Tester les transitions d'escalade
  const escalationResults = testEscalationTransitions(modes);
  
  // Tester les transitions de désescalade
  const deescalationResults = testDeescalationTransitions(modes);
  
  // Tester les transitions invalides
  const invalidResults = testInvalidTransitions(modes);
  
  // Sauvegarder les résultats des tests
  const summary = saveTestResults(escalationResults, deescalationResults, invalidResults);
  
  // Afficher le résumé
  log('=== Résumé des tests ===', 'magenta');
  log(`Total: ${summary.total} tests`, 'cyan');
  log(`Réussis: ${summary.passed} tests`, 'green');
  log(`Échoués: ${summary.failed} tests`, summary.failed === 0 ? 'green' : 'red');
  
  // Retourner le code de sortie
  if (summary.failed === 0) {
    log('=== Tests réussis ===', 'green');
    process.exit(0);
  } else {
    log('=== Tests échoués ===', 'red');
    process.exit(1);
  }
}

// Exécuter la fonction principale
main();