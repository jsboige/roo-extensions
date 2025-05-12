/**
 * Script de validation des configurations pour l'architecture à 5 niveaux
 * Ce script vérifie que les fichiers de configuration sont valides et cohérents
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

// Fonction pour valider un fichier de configuration
function validateConfigFile(filePath) {
  log(`Validation du fichier: ${filePath}`, 'cyan');
  
  try {
    // Vérifier que le fichier existe
    if (!fs.existsSync(filePath)) {
      log(`Erreur: Le fichier ${filePath} n'existe pas`, 'red');
      return false;
    }
    
    // Lire et parser le fichier JSON
    const configContent = fs.readFileSync(filePath, 'utf8');
    const config = JSON.parse(configContent);
    
    // Valider la structure de base
    if (!config.complexityLevel) {
      log(`Erreur: Le fichier ${filePath} ne contient pas de section complexityLevel`, 'red');
      return false;
    }
    
    if (!Array.isArray(config.customModes)) {
      log(`Erreur: Le fichier ${filePath} ne contient pas de tableau customModes`, 'red');
      return false;
    }
    
    // Valider les métadonnées de famille
    if (!config.complexityLevel.family) {
      log(`Erreur: Le fichier ${filePath} ne contient pas de métadonnée family dans complexityLevel`, 'red');
      return false;
    }
    
    if (!Array.isArray(config.complexityLevel.allowedFamilyTransitions)) {
      log(`Erreur: Le fichier ${filePath} ne contient pas de tableau allowedFamilyTransitions dans complexityLevel`, 'red');
      return false;
    }
    
    // Valider chaque mode personnalisé
    for (const mode of config.customModes) {
      if (!mode.slug) {
        log(`Erreur: Un mode dans ${filePath} n'a pas de slug`, 'red');
        return false;
      }
      
      if (!mode.family) {
        log(`Erreur: Le mode ${mode.slug} dans ${filePath} n'a pas de métadonnée family`, 'red');
        return false;
      }
      
      if (!Array.isArray(mode.allowedFamilyTransitions)) {
        log(`Erreur: Le mode ${mode.slug} dans ${filePath} n'a pas de tableau allowedFamilyTransitions`, 'red');
        return false;
      }
      
      // Vérifier que les instructions personnalisées contiennent des informations sur le verrouillage de famille
      if (mode.customInstructions && !mode.customInstructions.includes('VERROUILLAGE DE FAMILLE')) {
        log(`Avertissement: Le mode ${mode.slug} dans ${filePath} ne contient pas d'instructions sur le verrouillage de famille`, 'yellow');
      }
    }
    
    log(`Validation réussie pour ${filePath}`, 'green');
    return true;
  } catch (error) {
    log(`Erreur lors de la validation de ${filePath}: ${error.message}`, 'red');
    return false;
  }
}

// Fonction pour valider la cohérence entre les niveaux
function validateLevelCoherence() {
  log('Validation de la cohérence entre les niveaux...', 'cyan');
  
  try {
    const configs = {};
    
    // Charger toutes les configurations
    for (const configFile of CONFIG_FILES) {
      const filePath = path.join(CONFIG_DIR, configFile);
      if (fs.existsSync(filePath)) {
        const configContent = fs.readFileSync(filePath, 'utf8');
        configs[configFile] = JSON.parse(configContent);
      } else {
        log(`Erreur: Le fichier ${filePath} n'existe pas`, 'red');
        return false;
      }
    }
    
    // Vérifier la cohérence des niveaux
    const levels = {
      'micro-modes.json': 1,
      'mini-modes.json': 2,
      'medium-modes.json': 3,
      'large-modes.json': 4,
      'oracle-modes.json': 5
    };
    
    for (const [configFile, config] of Object.entries(configs)) {
      const expectedLevel = levels[configFile];
      if (config.complexityLevel.level !== expectedLevel) {
        log(`Erreur: Le niveau de complexité dans ${configFile} est ${config.complexityLevel.level}, mais devrait être ${expectedLevel}`, 'red');
        return false;
      }
    }
    
    // Vérifier la cohérence des références nextLevel et previousLevel
    const levelReferences = {
      'micro-modes.json': { next: 'mini', previous: null },
      'mini-modes.json': { next: 'medium', previous: 'micro' },
      'medium-modes.json': { next: 'large', previous: 'mini' },
      'large-modes.json': { next: 'oracle', previous: 'medium' },
      'oracle-modes.json': { next: null, previous: 'large' }
    };
    
    for (const [configFile, config] of Object.entries(configs)) {
      const expectedReferences = levelReferences[configFile];
      
      if (config.complexityLevel.nextLevel !== expectedReferences.next) {
        log(`Erreur: La référence nextLevel dans ${configFile} est ${config.complexityLevel.nextLevel}, mais devrait être ${expectedReferences.next}`, 'red');
        return false;
      }
      
      if (config.complexityLevel.previousLevel !== expectedReferences.previous) {
        log(`Erreur: La référence previousLevel dans ${configFile} est ${config.complexityLevel.previousLevel}, mais devrait être ${expectedReferences.previous}`, 'red');
        return false;
      }
    }
    
    // Vérifier que tous les modes ont la même famille
    const families = new Set();
    for (const [configFile, config] of Object.entries(configs)) {
      families.add(config.complexityLevel.family);
      
      for (const mode of config.customModes) {
        families.add(mode.family);
      }
    }
    
    if (families.size !== 1) {
      log(`Erreur: Les configurations contiennent plusieurs familles: ${Array.from(families).join(', ')}`, 'red');
      return false;
    }
    
    log('Validation de la cohérence entre les niveaux réussie', 'green');
    return true;
  } catch (error) {
    log(`Erreur lors de la validation de la cohérence: ${error.message}`, 'red');
    return false;
  }
}

// Fonction principale
function main() {
  log('=== Validation des configurations pour l\'architecture à 5 niveaux ===', 'magenta');
  
  let allValid = true;
  
  // Valider chaque fichier de configuration
  for (const configFile of CONFIG_FILES) {
    const filePath = path.join(CONFIG_DIR, configFile);
    const isValid = validateConfigFile(filePath);
    allValid = allValid && isValid;
  }
  
  // Valider la cohérence entre les niveaux
  const coherenceValid = validateLevelCoherence();
  allValid = allValid && coherenceValid;
  
  if (allValid) {
    log('=== Validation réussie ===', 'green');
    process.exit(0);
  } else {
    log('=== Validation échouée ===', 'red');
    process.exit(1);
  }
}

// Exécuter la fonction principale
main();