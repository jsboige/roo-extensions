/**
 * Script de validation des transitions de mode
 * 
 * Ce script implémente un mécanisme de validation des transitions entre modes
 * pour garantir que les modes restent dans leur famille respective (simple/complex).
 */

const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG_PATH = path.join(__dirname, '..', 'configs', 'standard-modes.json');

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
 * Récupère les informations sur les familles de modes
 * @param {Object} modesConfig Configuration des modes
 * @returns {Object} Informations sur les familles de modes
 */
function getFamilyInfo(modesConfig) {
  // Récupérer le validateur de famille s'il existe
  const familyValidator = modesConfig.customModes.find(mode => mode.slug === 'mode-family-validator');
  
  if (familyValidator && familyValidator.familyDefinitions) {
    return familyValidator.familyDefinitions;
  }
  
  // Si le validateur n'existe pas, construire les informations à partir des modes
  const familyInfo = {
    simple: [],
    complex: []
  };
  
  modesConfig.customModes.forEach(mode => {
    if (mode.family === 'simple') {
      familyInfo.simple.push(mode.slug);
    } else if (mode.family === 'complex') {
      familyInfo.complex.push(mode.slug);
    }
  });
  
  return familyInfo;
}

/**
 * Valide une transition de mode
 * @param {string} currentMode Mode actuel
 * @param {string} targetMode Mode cible
 * @returns {Object} Résultat de la validation
 */
function validateModeTransition(currentMode, targetMode) {
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    return {
      valid: false,
      reason: "Impossible de charger la configuration des modes"
    };
  }
  
  // Récupérer les configurations des modes
  const currentModeConfig = modesConfig.customModes.find(mode => mode.slug === currentMode);
  const targetModeConfig = modesConfig.customModes.find(mode => mode.slug === targetMode);
  
  // Vérifier si les configurations existent
  if (!currentModeConfig) {
    return {
      valid: false,
      reason: `Mode actuel '${currentMode}' non trouvé dans la configuration`
    };
  }
  
  if (!targetModeConfig) {
    return {
      valid: false,
      reason: `Mode cible '${targetMode}' non trouvé dans la configuration`
    };
  }
  
  // Vérifier si la transition est autorisée en fonction de la famille
  const currentFamily = currentModeConfig.family || "standard";
  const targetFamily = targetModeConfig.family || "standard";
  const allowedFamilies = currentModeConfig.allowedFamilyTransitions || [currentFamily];
  
  if (!allowedFamilies.includes(targetFamily)) {
    return {
      valid: false,
      reason: `Transition non autorisée: le mode ${currentMode} (famille: ${currentFamily}) ne peut pas basculer vers le mode ${targetMode} (famille: ${targetFamily})`
    };
  }
  
  // Récupérer les informations sur les familles
  const familyInfo = getFamilyInfo(modesConfig);
  
  // Vérifier si le mode cible appartient à la famille autorisée
  if (currentFamily === 'simple' && !familyInfo.simple.includes(targetMode)) {
    return {
      valid: false,
      reason: `Le mode cible '${targetMode}' n'appartient pas à la famille 'simple'`
    };
  }
  
  if (currentFamily === 'complex' && !familyInfo.complex.includes(targetMode)) {
    return {
      valid: false,
      reason: `Le mode cible '${targetMode}' n'appartient pas à la famille 'complex'`
    };
  }
  
  return {
    valid: true,
    currentFamily,
    targetFamily,
    availableModes: familyInfo[currentFamily]
  };
}

/**
 * Génère les instructions de verrouillage de famille pour un mode
 * @param {string} mode Mode pour lequel générer les instructions
 * @returns {string} Instructions de verrouillage de famille
 */
function generateFamilyLockInstructions(mode) {
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    return "/* ERREUR: Impossible de charger la configuration des modes */";
  }
  
  // Récupérer la configuration du mode
  const modeConfig = modesConfig.customModes.find(m => m.slug === mode);
  if (!modeConfig) {
    return `/* ERREUR: Mode '${mode}' non trouvé dans la configuration */`;
  }
  
  // Récupérer les informations sur les familles
  const familyInfo = getFamilyInfo(modesConfig);
  const family = modeConfig.family || "standard";
  const availableModes = familyInfo[family] || [];
  
  // Générer les instructions
  return `/* IDENTITÉ DE MODE ET FAMILLE */
// Cette section définit l'identité du mode et sa famille
// Mode actuel: ${mode}
// Famille: ${family}
// Niveau de complexité: ${family === 'simple' ? 'SIMPLE (niveau 1)' : 'COMPLEX (niveau 2)'}

IMPORTANT: Vous êtes un agent de la famille "${family}". Votre identité est fortement liée à cette famille et vous ne devez JAMAIS basculer vers un mode d'une autre famille. Si une tâche nécessite un changement de mode, vous DEVEZ rester dans la famille "${family}".

Modes disponibles dans votre famille:
${availableModes.map(m => `- ${m}`).join('\n')}

Si une tâche nécessite des capacités que vous ne possédez pas, mais qui sont disponibles dans un autre mode de votre famille, vous pouvez suggérer un changement de mode en utilisant le format approprié d'escalade ou de désescalade.

IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode ${mode} qui appartient à la famille "${family}", vous ne pouvez basculer que vers les modes listés ci-dessus.`;
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  validateModeTransition,
  generateFamilyLockInstructions,
  getFamilyInfo
};

// Si le script est exécuté directement, afficher les informations sur les familles
if (require.main === module) {
  const modesConfig = loadModesConfig();
  if (modesConfig) {
    const familyInfo = getFamilyInfo(modesConfig);
    console.log('Informations sur les familles de modes:');
    console.log(JSON.stringify(familyInfo, null, 2));
    
    // Exemple de validation
    if (process.argv.length >= 4) {
      const currentMode = process.argv[2];
      const targetMode = process.argv[3];
      const validationResult = validateModeTransition(currentMode, targetMode);
      console.log(`\nValidation de la transition ${currentMode} -> ${targetMode}:`);
      console.log(JSON.stringify(validationResult, null, 2));
      
      if (validationResult.valid) {
        console.log('\nInstructions de verrouillage de famille pour le mode actuel:');
        console.log(generateFamilyLockInstructions(currentMode));
      }
    }
  }
}