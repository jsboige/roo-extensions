/**
 * Mode Transition Interceptor
 * 
 * Ce script intercepte les demandes de transition de mode (switch_mode)
 * et applique la validation des transitions pour garantir que les modes
 * restent dans leur famille respective.
 */

const path = require('path');
const fs = require('fs');
const { validateModeTransition } = require('./validate-mode-transitions');

// Configuration
const LOG_DIR = path.join(__dirname, '..', 'logs');
const LOG_FILE = path.join(LOG_DIR, 'mode-transitions.log');

// Créer le répertoire de logs s'il n'existe pas
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

/**
 * Journalise une transition de mode
 * @param {string} currentMode Mode actuel
 * @param {string} targetMode Mode cible
 * @param {boolean} allowed Indique si la transition est autorisée
 * @param {string} reason Raison du refus si la transition n'est pas autorisée
 */
function logTransition(currentMode, targetMode, allowed, reason = '') {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    currentMode,
    targetMode,
    allowed,
    reason
  };
  
  // Ajouter l'entrée au fichier de log
  fs.appendFileSync(LOG_FILE, JSON.stringify(logEntry) + '\n');
  
  // Afficher l'entrée dans la console
  console.log(`[${timestamp}] Transition ${currentMode} -> ${targetMode}: ${allowed ? 'AUTORISÉE' : 'REFUSÉE'} ${reason ? `(${reason})` : ''}`);
}

/**
 * Intercepte une demande de transition de mode
 * @param {string} currentMode Mode actuel
 * @param {string} targetMode Mode cible
 * @param {string} reason Raison de la transition
 * @returns {Object} Résultat de l'interception
 */
function interceptModeTransition(currentMode, targetMode, reason = '') {
  // Valider la transition
  const validationResult = validateModeTransition(currentMode, targetMode);
  
  // Journaliser la transition
  logTransition(
    currentMode,
    targetMode,
    validationResult.valid,
    validationResult.valid ? '' : validationResult.reason
  );
  
  if (!validationResult.valid) {
    return {
      allowed: false,
      reason: validationResult.reason,
      suggestedModes: validationResult.availableModes || []
    };
  }
  
  return {
    allowed: true,
    currentFamily: validationResult.currentFamily,
    targetFamily: validationResult.targetFamily
  };
}

/**
 * Génère un message d'erreur pour une transition non autorisée
 * @param {string} currentMode Mode actuel
 * @param {string} targetMode Mode cible
 * @param {string} reason Raison du refus
 * @param {Array<string>} suggestedModes Modes suggérés
 * @returns {string} Message d'erreur
 */
function generateErrorMessage(currentMode, targetMode, reason, suggestedModes = []) {
  let message = `[ERREUR DE TRANSITION] La transition de ${currentMode} vers ${targetMode} n'est pas autorisée: ${reason}`;
  
  if (suggestedModes.length > 0) {
    message += `\n\nModes disponibles dans la même famille:\n${suggestedModes.map(mode => `- ${mode}`).join('\n')}`;
  }
  
  return message;
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  interceptModeTransition,
  generateErrorMessage
};

// Si le script est exécuté directement, afficher les informations d'utilisation
if (require.main === module) {
  console.log('Mode Transition Interceptor');
  console.log('Usage: node mode-transition-interceptor.js <currentMode> <targetMode> [reason]');
  
  if (process.argv.length >= 4) {
    const currentMode = process.argv[2];
    const targetMode = process.argv[3];
    const reason = process.argv[4] || '';
    
    const result = interceptModeTransition(currentMode, targetMode, reason);
    console.log('\nRésultat de l\'interception:');
    console.log(JSON.stringify(result, null, 2));
    
    if (!result.allowed) {
      console.log('\nMessage d\'erreur:');
      console.log(generateErrorMessage(currentMode, targetMode, result.reason, result.suggestedModes));
    }
  }
}