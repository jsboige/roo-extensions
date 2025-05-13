/**
 * Script de test des transitions pour l'architecture à 5 niveaux compatible avec Roo-Code
 * Ce script vérifie que les transitions entre modes sont correctement configurées
 */

const fs = require('fs');
const path = require('path');

// Constantes
const CONFIG_FILE = path.join(__dirname, '..', 'configs', 'n5-modes-roo-compatible.json');

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

// Fonction pour charger la configuration
function loadConfig() {
  try {
    const configContent = fs.readFileSync(CONFIG_FILE, 'utf8');
    return JSON.parse(configContent);
  } catch (error) {
    log(`Erreur lors du chargement de la configuration: ${error.message}`, 'red');
    process.exit(1);
  }
}

// Fonction pour extraire les définitions de famille
function extractFamilyDefinitions(config) {
  const familyValidator = config.customModes.find(mode => mode.slug === 'mode-family-validator');
  if (!familyValidator) {
    log('Erreur: Mode family-validator non trouvé dans la configuration', 'red');
    return null;
  }
  
  return familyValidator.familyDefinitions;
}

// Fonction pour extraire les modes par famille
function extractModesByFamily(config, familyDefinitions) {
  const modesByFamily = {};
  
  // Initialiser les familles
  for (const family in familyDefinitions) {
    modesByFamily[family] = [];
  }
  
  // Remplir les modes par famille
  for (const mode of config.customModes) {
    if (mode.slug !== 'mode-family-validator' && mode.family) {
      if (!modesByFamily[mode.family]) {
        modesByFamily[mode.family] = [];
      }
      modesByFamily[mode.family].push(mode);
    }
  }
  
  return modesByFamily;
}

// Fonction pour vérifier les transitions entre modes
function checkTransitions(config, modesByFamily) {
  log('Vérification des transitions entre modes...', 'cyan');
  
  let allValid = true;
  const testedTransitions = [];
  
  // Pour chaque mode
  for (const mode of config.customModes) {
    if (mode.slug === 'mode-family-validator') continue;
    
    log(`\nVérification des transitions pour le mode: ${mode.slug}`, 'blue');
    
    // Vérifier que le mode a une famille
    if (!mode.family) {
      log(`  Erreur: Le mode ${mode.slug} n'a pas de famille définie`, 'red');
      allValid = false;
      continue;
    }
    
    // Vérifier que le mode a des transitions autorisées
    if (!Array.isArray(mode.allowedFamilyTransitions)) {
      log(`  Erreur: Le mode ${mode.slug} n'a pas de transitions autorisées définies`, 'red');
      allValid = false;
      continue;
    }
    
    // Vérifier que les transitions autorisées sont valides
    for (const targetFamily of mode.allowedFamilyTransitions) {
      if (!modesByFamily[targetFamily]) {
        log(`  Erreur: Le mode ${mode.slug} a une transition vers une famille inexistante: ${targetFamily}`, 'red');
        allValid = false;
        continue;
      }
      
      // Vérifier les transitions vers chaque mode de la famille cible
      for (const targetMode of modesByFamily[targetFamily]) {
        const transition = `${mode.slug} -> ${targetMode.slug}`;
        
        // Éviter de tester la même transition plusieurs fois
        if (testedTransitions.includes(transition)) continue;
        testedTransitions.push(transition);
        
        // Vérifier si la transition est valide
        const isValid = mode.family === targetMode.family || mode.allowedFamilyTransitions.includes(targetMode.family);
        
        if (isValid) {
          log(`  ✓ Transition valide: ${transition}`, 'green');
        } else {
          log(`  ✗ Transition invalide: ${transition}`, 'red');
          allValid = false;
        }
      }
    }
  }
  
  return allValid;
}

// Fonction pour vérifier les niveaux de complexité
function checkComplexityLevels(config) {
  log('\nVérification des niveaux de complexité...', 'cyan');
  
  // Définir les niveaux attendus
  const expectedLevels = {
    'micro': 1,
    'mini': 2,
    'medium': 3,
    'large': 4,
    'oracle': 5
  };
  
  let allValid = true;
  
  // Pour chaque mode
  for (const mode of config.customModes) {
    if (mode.slug === 'mode-family-validator') continue;
    
    // Extraire le niveau du slug
    let level = null;
    for (const levelName in expectedLevels) {
      if (mode.slug.includes(levelName)) {
        level = levelName;
        break;
      }
    }
    
    if (!level) {
      log(`  Avertissement: Impossible de déterminer le niveau pour le mode ${mode.slug}`, 'yellow');
      continue;
    }
    
    // Vérifier que les instructions personnalisées contiennent le niveau
    if (!mode.customInstructions.includes(`Niveau actuel: ${level.toUpperCase()}`)) {
      log(`  Erreur: Les instructions personnalisées du mode ${mode.slug} ne contiennent pas le niveau ${level.toUpperCase()}`, 'red');
      allValid = false;
    } else {
      log(`  ✓ Niveau correctement défini pour le mode ${mode.slug}: ${level.toUpperCase()}`, 'green');
    }
  }
  
  return allValid;
}

// Fonction pour vérifier les mécanismes d'escalade et de désescalade
function checkEscalationMechanisms(config) {
  log('\nVérification des mécanismes d\'escalade et de désescalade...', 'cyan');
  
  let allValid = true;
  
  // Pour chaque mode
  for (const mode of config.customModes) {
    if (mode.slug === 'mode-family-validator') continue;
    
    // Extraire le niveau du slug
    let level = null;
    if (mode.slug.includes('micro')) level = 'micro';
    else if (mode.slug.includes('mini')) level = 'mini';
    else if (mode.slug.includes('medium')) level = 'medium';
    else if (mode.slug.includes('large')) level = 'large';
    else if (mode.slug.includes('oracle')) level = 'oracle';
    
    if (!level) {
      log(`  Avertissement: Impossible de déterminer le niveau pour le mode ${mode.slug}`, 'yellow');
      continue;
    }
    
    // Vérifier les mécanismes d'escalade pour les niveaux inférieurs à oracle
    if (level !== 'oracle') {
      if (!mode.customInstructions.includes('MÉCANISME D\'ESCALADE') && 
          !mode.customInstructions.includes('switch_mode')) {
        log(`  Erreur: Les instructions personnalisées du mode ${mode.slug} ne contiennent pas de mécanisme d'escalade`, 'red');
        allValid = false;
      } else {
        log(`  ✓ Mécanisme d'escalade correctement défini pour le mode ${mode.slug}`, 'green');
      }
    }
    
    // Vérifier les mécanismes de désescalade pour les niveaux supérieurs à micro
    if (level !== 'micro') {
      if (!mode.customInstructions.includes('désescalade') && 
          !mode.customInstructions.includes('switch_mode')) {
        log(`  Erreur: Les instructions personnalisées du mode ${mode.slug} ne contiennent pas de mécanisme de désescalade`, 'red');
        allValid = false;
      } else {
        log(`  ✓ Mécanisme de désescalade correctement défini pour le mode ${mode.slug}`, 'green');
      }
    }
  }
  
  return allValid;
}

// Fonction pour vérifier l'utilisation des MCPs
function checkMCPUsage(config) {
  log('\nVérification de l\'utilisation des MCPs...', 'cyan');
  
  let allValid = true;
  
  // Pour chaque mode
  for (const mode of config.customModes) {
    if (mode.slug === 'mode-family-validator') continue;
    
    // Vérifier que les instructions personnalisées contiennent des informations sur l'utilisation des MCPs
    if (!mode.customInstructions.includes('UTILISATION OPTIMISÉE DES MCPs')) {
      log(`  Erreur: Les instructions personnalisées du mode ${mode.slug} ne contiennent pas d'informations sur l'utilisation des MCPs`, 'red');
      allValid = false;
    } else {
      log(`  ✓ Utilisation des MCPs correctement définie pour le mode ${mode.slug}`, 'green');
    }
    
    // Vérifier que les instructions personnalisées mentionnent les MCPs spécifiques
    const mcps = ['quickfiles', 'jinavigator', 'searxng', 'win-cli'];
    for (const mcp of mcps) {
      if (!mode.customInstructions.includes(mcp)) {
        log(`  Avertissement: Les instructions personnalisées du mode ${mode.slug} ne mentionnent pas le MCP ${mcp}`, 'yellow');
      }
    }
  }
  
  return allValid;
}

// Fonction principale
function main() {
  log('=== Test des transitions pour l\'architecture à 5 niveaux compatible avec Roo-Code ===', 'magenta');
  
  // Charger la configuration
  const config = loadConfig();
  
  // Extraire les définitions de famille
  const familyDefinitions = extractFamilyDefinitions(config);
  if (!familyDefinitions) {
    process.exit(1);
  }
  
  // Extraire les modes par famille
  const modesByFamily = extractModesByFamily(config, familyDefinitions);
  
  // Vérifier les transitions entre modes
  const transitionsValid = checkTransitions(config, modesByFamily);
  
  // Vérifier les niveaux de complexité
  const levelsValid = checkComplexityLevels(config);
  
  // Vérifier les mécanismes d'escalade et de désescalade
  const escalationValid = checkEscalationMechanisms(config);
  
  // Vérifier l'utilisation des MCPs
  const mcpUsageValid = checkMCPUsage(config);
  
  // Afficher le résultat global
  const allValid = transitionsValid && levelsValid && escalationValid && mcpUsageValid;
  
  if (allValid) {
    log('\n=== Tous les tests ont réussi ===', 'green');
    process.exit(0);
  } else {
    log('\n=== Certains tests ont échoué ===', 'red');
    process.exit(1);
  }
}

// Exécuter la fonction principale
main();