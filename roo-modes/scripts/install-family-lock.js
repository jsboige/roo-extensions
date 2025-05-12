/**
 * Script d'installation du système de verrouillage de famille
 * 
 * Ce script installe et configure le système de verrouillage de famille
 * pour empêcher le basculement inapproprié des modes simples/complexes
 * vers les modes standard.
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { updateAllModeInstructions } = require('./update-mode-instructions');

// Configuration
const CONFIG_DIR = path.join(__dirname, '..', 'configs');
const SCRIPTS_DIR = path.join(__dirname);
const LOG_DIR = path.join(__dirname, '..', 'logs');

/**
 * Vérifie si les prérequis sont installés
 * @returns {Promise<boolean>} Indique si les prérequis sont installés
 */
async function checkPrerequisites() {
  console.log('Vérification des prérequis...');
  
  // Vérifier si Node.js est installé
  try {
    const nodeVersion = await executeCommand('node', ['--version']);
    console.log(`Node.js version: ${nodeVersion.trim()}`);
  } catch (error) {
    console.error('Node.js n\'est pas installé ou n\'est pas accessible.');
    return false;
  }
  
  // Vérifier si les répertoires nécessaires existent
  if (!fs.existsSync(CONFIG_DIR)) {
    console.error(`Le répertoire de configuration n'existe pas: ${CONFIG_DIR}`);
    return false;
  }
  
  // Créer le répertoire de logs s'il n'existe pas
  if (!fs.existsSync(LOG_DIR)) {
    console.log(`Création du répertoire de logs: ${LOG_DIR}`);
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }
  
  return true;
}

/**
 * Exécute une commande système
 * @param {string} command Commande à exécuter
 * @param {Array<string>} args Arguments de la commande
 * @returns {Promise<string>} Sortie de la commande
 */
function executeCommand(command, args = []) {
  return new Promise((resolve, reject) => {
    const process = spawn(command, args);
    let output = '';
    
    process.stdout.on('data', (data) => {
      output += data.toString();
    });
    
    process.stderr.on('data', (data) => {
      console.error(`Erreur: ${data.toString()}`);
    });
    
    process.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`La commande a échoué avec le code ${code}`));
      }
    });
  });
}

/**
 * Installe le système de verrouillage de famille
 * @returns {Promise<boolean>} Indique si l'installation a réussi
 */
async function installFamilyLock() {
  console.log('Installation du système de verrouillage de famille...');
  
  try {
    // Vérifier les prérequis
    const prerequisitesOk = await checkPrerequisites();
    if (!prerequisitesOk) {
      console.error('Les prérequis ne sont pas satisfaits. Installation annulée.');
      return false;
    }
    
    // Mettre à jour les instructions personnalisées des modes
    console.log('Mise à jour des instructions personnalisées des modes...');
    const updateSuccess = updateAllModeInstructions();
    if (!updateSuccess) {
      console.error('Échec de la mise à jour des instructions personnalisées.');
      return false;
    }
    
    // Créer un fichier de configuration pour le système de verrouillage
    const lockConfig = {
      enabled: true,
      version: '1.0.0',
      timestamp: new Date().toISOString(),
      families: {
        simple: ['code-simple', 'debug-simple', 'architect-simple', 'ask-simple', 'orchestrator-simple'],
        complex: ['code-complex', 'debug-complex', 'architect-complex', 'ask-complex', 'orchestrator-complex', 'manager']
      }
    };
    
    const lockConfigPath = path.join(CONFIG_DIR, 'family-lock.json');
    fs.writeFileSync(lockConfigPath, JSON.stringify(lockConfig, null, 2));
    console.log(`Configuration du verrouillage de famille créée: ${lockConfigPath}`);
    
    // Créer un fichier README pour expliquer le système
    const readmePath = path.join(SCRIPTS_DIR, 'FAMILY-LOCK-README.md');
    const readmeContent = `# Système de verrouillage de famille pour les modes Roo

Ce système empêche le basculement inapproprié des modes simples/complexes vers les modes standard.

## Composants

1. **validate-mode-transitions.js**: Valide les transitions entre modes pour garantir qu'elles restent dans la même famille.
2. **mode-transition-interceptor.js**: Intercepte les demandes de transition de mode et applique la validation.
3. **update-mode-instructions.js**: Met à jour les instructions personnalisées des modes pour y intégrer les mécanismes de verrouillage.

## Configuration

La configuration du système se trouve dans le fichier \`family-lock.json\`.

## Utilisation

Le système est automatiquement activé lors de l'utilisation de l'outil \`switch_mode\`.

## Journalisation

Les transitions de mode sont journalisées dans le répertoire \`logs\`.

## Dépannage

En cas de problème, vérifiez les journaux dans le répertoire \`logs\`.
`;
    
    fs.writeFileSync(readmePath, readmeContent);
    console.log(`README créé: ${readmePath}`);
    
    console.log('Installation terminée avec succès!');
    return true;
  } catch (error) {
    console.error(`Erreur lors de l'installation: ${error.message}`);
    return false;
  }
}

// Si le script est exécuté directement, installer le système de verrouillage de famille
if (require.main === module) {
  installFamilyLock()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error(`Erreur non gérée: ${error.message}`);
      process.exit(1);
    });
}

// Exporter les fonctions pour utilisation dans d'autres scripts
module.exports = {
  installFamilyLock
};