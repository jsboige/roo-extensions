/**
 * Script de mise à jour des instructions personnalisées des modes
 * 
 * Ce script met à jour les instructions personnalisées des modes pour y intégrer
 * les mécanismes de verrouillage de famille et renforcer l'identité des modes.
 */

const fs = require('fs');
const path = require('path');
const { generateFamilyLockInstructions, getFamilyInfo } = require('./validate-mode-transitions');

// Configuration
const CONFIG_PATH = path.join(__dirname, '..', 'configs', 'standard-modes.json');
const BACKUP_DIR = path.join(__dirname, '..', 'backups');

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
 * Sauvegarde la configuration des modes
 * @param {Object} config Configuration des modes
 * @returns {boolean} Indique si la sauvegarde a réussi
 */
function saveModesConfig(config) {
  try {
    // Créer le répertoire de sauvegarde s'il n'existe pas
    if (!fs.existsSync(BACKUP_DIR)) {
      fs.mkdirSync(BACKUP_DIR, { recursive: true });
    }
    
    // Créer une sauvegarde de la configuration actuelle
    const timestamp = new Date().toISOString().replace(/:/g, '-');
    const backupPath = path.join(BACKUP_DIR, `modes_backup_${timestamp}.json`);
    fs.copyFileSync(CONFIG_PATH, backupPath);
    
    // Sauvegarder la nouvelle configuration
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    
    console.log(`Configuration sauvegardée avec succès (backup: ${backupPath})`);
    return true;
  } catch (error) {
    console.error(`Erreur lors de la sauvegarde de la configuration: ${error.message}`);
    return false;
  }
}

/**
 * Met à jour les instructions personnalisées d'un mode pour y intégrer les mécanismes de verrouillage de famille
 * @param {Object} modeConfig Configuration du mode
 * @returns {Object} Configuration du mode mise à jour
 */
function updateModeInstructions(modeConfig) {
  const mode = modeConfig.slug;
  const family = modeConfig.family || 'standard';
  
  // Générer les instructions de verrouillage de famille
  const familyLockInstructions = generateFamilyLockInstructions(mode);
  
  // Mettre à jour les instructions personnalisées
  let customInstructions = modeConfig.customInstructions || '';
  
  // Vérifier si les instructions contiennent déjà une section d'identité de mode
  if (customInstructions.includes('/* IDENTITÉ DE MODE ET FAMILLE */')) {
    // Remplacer la section existante
    customInstructions = customInstructions.replace(
      /\/\* IDENTITÉ DE MODE ET FAMILLE \*\/[\s\S]*?Si une tâche nécessite des capacités[\s\S]*?même famille\./,
      familyLockInstructions
    );
  } else {
    // Ajouter la section au début des instructions
    customInstructions = `${familyLockInstructions}\n\n${customInstructions}`;
  }
  
  // Mettre à jour les mécanismes d'escalade/désescalade
  if (family === 'simple') {
    // Mettre à jour le mécanisme d'escalade pour les modes simples
    customInstructions = updateEscalationMechanism(customInstructions, mode);
  } else if (family === 'complex') {
    // Mettre à jour le mécanisme de désescalade pour les modes complexes
    customInstructions = updateDeescalationMechanism(customInstructions, mode);
  }
  
  // Retourner la configuration mise à jour
  return {
    ...modeConfig,
    customInstructions
  };
}

/**
 * Met à jour le mécanisme d'escalade dans les instructions personnalisées
 * @param {string} instructions Instructions personnalisées
 * @param {string} mode Slug du mode
 * @returns {string} Instructions personnalisées mises à jour
 */
function updateEscalationMechanism(instructions, mode) {
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    return instructions;
  }
  
  // Récupérer les informations sur les familles
  const familyInfo = getFamilyInfo(modesConfig);
  const simpleModes = familyInfo.simple || [];
  
  // Créer le texte de mise à jour
  const escalationUpdate = `IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode ${mode} qui appartient à la famille "simple", vous ne pouvez escalader que vers les modes suivants: ${simpleModes.join(', ')}.`;
  
  // Vérifier si les instructions contiennent déjà un mécanisme d'escalade
  if (instructions.includes('/* MÉCANISME D\'ESCALADE */') || instructions.includes('/* MÉCANISME D\'ESCALADE */')) {
    // Ajouter le texte de mise à jour après la section d'escalade
    const escalationRegex = /L'escalade n'est PAS optionnelle pour ces types de tâches[\s\S]*?"[RAISON]"/;
    if (escalationRegex.test(instructions)) {
      return instructions.replace(
        escalationRegex,
        match => `${match}\n\n${escalationUpdate}`
      );
    }
  }
  
  return instructions;
}

/**
 * Met à jour le mécanisme de désescalade dans les instructions personnalisées
 * @param {string} instructions Instructions personnalisées
 * @param {string} mode Slug du mode
 * @returns {string} Instructions personnalisées mises à jour
 */
function updateDeescalationMechanism(instructions, mode) {
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    return instructions;
  }
  
  // Récupérer les informations sur les familles
  const familyInfo = getFamilyInfo(modesConfig);
  const complexModes = familyInfo.complex || [];
  
  // Créer le texte de mise à jour
  const deescalationUpdate = `IMPORTANT: Lors de l'utilisation de l'outil switch_mode, vous DEVEZ UNIQUEMENT spécifier un mode_slug appartenant à la même famille que votre mode actuel. Pour le mode ${mode} qui appartient à la famille "complex", vous ne pouvez désescalader que vers les modes suivants: ${complexModes.join(', ')}.`;
  
  // Vérifier si les instructions contiennent déjà un mécanisme de désescalade
  if (instructions.includes('/* MÉCANISME DE DÉSESCALADE */') || instructions.includes('/* MÉCANISME DE DÉSESCALADE */')) {
    // Ajouter le texte de mise à jour après la section de désescalade
    const deescalationRegex = /IMPORTANT: Vous DEVEZ rétrograder systématiquement[\s\S]*?"[RAISON]"/;
    if (deescalationRegex.test(instructions)) {
      return instructions.replace(
        deescalationRegex,
        match => `${match}\n\n${deescalationUpdate}`
      );
    }
  }
  
  return instructions;
}

/**
 * Met à jour les instructions personnalisées de tous les modes
 * @returns {boolean} Indique si la mise à jour a réussi
 */
function updateAllModeInstructions() {
  // Charger la configuration des modes
  const modesConfig = loadModesConfig();
  if (!modesConfig) {
    return false;
  }
  
  // Mettre à jour les instructions personnalisées de chaque mode
  const updatedModes = modesConfig.customModes.map(mode => {
    // Ignorer le validateur de famille
    if (mode.slug === 'mode-family-validator') {
      return mode;
    }
    
    console.log(`Mise à jour des instructions pour le mode ${mode.slug}...`);
    return updateModeInstructions(mode);
  });
  
  // Mettre à jour la configuration
  const updatedConfig = {
    ...modesConfig,
    customModes: updatedModes
  };
  
  // Sauvegarder la configuration mise à jour
  return saveModesConfig(updatedConfig);
}

// Si le script est exécuté directement, mettre à jour les instructions de tous les modes
if (require.main === module) {
  console.log('Mise à jour des instructions personnalisées des modes...');
  const success = updateAllModeInstructions();
  console.log(success ? 'Mise à jour réussie!' : 'Échec de la mise à jour.');
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  updateModeInstructions,
  updateAllModeInstructions
};