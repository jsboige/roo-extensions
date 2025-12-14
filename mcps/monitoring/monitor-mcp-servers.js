/**
 * Système de surveillance des serveurs MCP
 * Ce script vérifie l'état des serveurs MCP et enregistre les résultats
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const { exec } = require('child_process');
const os = require('os');

// Configuration des serveurs MCP à surveiller
const MCP_SERVERS = [
  {
    name: 'Jupyter MCP',
    processName: 'python',
    processArgs: 'papermill_mcp.main',
    port: 3005, // Port par défaut, à ajuster si nécessaire
    endpoint: 'http://localhost:3005/',
    startScript: path.join(__dirname, '../internal/servers/jupyter-papermill-mcp-server/scripts/start-jupyter-mcp.bat')
  },
  {
    name: 'JinaNavigator MCP',
    processName: 'node',
    processArgs: 'jinavigator-server/dist/index.js',
    port: 3006, // Port par défaut, à ajuster si nécessaire
    endpoint: 'http://localhost:3006/',
    startScript: path.join(__dirname, '../mcp-servers/scripts/mcp-starters/start-jinavigator-mcp.bat')
  },
  {
    name: 'QuickFiles MCP',
    processName: 'node',
    processArgs: 'quickfiles-server/build/index.js',
    port: 3007, // Port par défaut, à ajuster si nécessaire
    endpoint: 'http://localhost:3007/',
    startScript: path.join(__dirname, '../mcp-servers/scripts/mcp-starters/start-quickfiles-mcp.bat')
  },
  {
    name: 'SearxNG MCP',
    processName: 'node',
    processArgs: 'searxng-server/dist/index.js',
    port: 3008, // Port par défaut, à ajuster si nécessaire
    endpoint: 'http://localhost:3008/',
    startScript: path.join(__dirname, '../mcp-servers/scripts/mcp-starters/start-searxng-mcp.bat')
  },
  {
    name: 'Win-CLI MCP',
    processName: 'node',
    processArgs: '@simonb97/server-win-cli',
    port: 3009, // Port par défaut, à ajuster si nécessaire
    endpoint: 'http://localhost:3009/',
    startScript: null // À compléter si un script de démarrage existe
  }
];

// Configuration des chemins pour les logs et alertes
const LOG_DIR = path.join(__dirname, 'logs');
const ALERT_DIR = path.join(__dirname, 'alerts');
const LOG_FILE = path.join(LOG_DIR, `mcp-monitor-${new Date().toISOString().split('T')[0]}.log`);
const ALERT_FILE = path.join(ALERT_DIR, `mcp-alerts-${new Date().toISOString().split('T')[0]}.log`);

// Créer les répertoires de logs et d'alertes s'ils n'existent pas
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

if (!fs.existsSync(ALERT_DIR)) {
  fs.mkdirSync(ALERT_DIR, { recursive: true });
}

/**
 * Écrit un message dans le fichier de log
 * @param {string} message - Message à enregistrer
 * @param {boolean} isAlert - Indique si c'est une alerte
 */
function logMessage(message, isAlert = false) {
  const timestamp = new Date().toISOString();
  const logEntry = `[${timestamp}] ${message}${os.EOL}`;
  
  console.log(message);
  
  // Écrire dans le fichier de log
  fs.appendFileSync(LOG_FILE, logEntry);
  
  // Si c'est une alerte, écrire également dans le fichier d'alertes
  if (isAlert) {
    fs.appendFileSync(ALERT_FILE, logEntry);
  }
}

/**
 * Vérifie si un processus est en cours d'exécution
 * @param {Object} server - Configuration du serveur à vérifier
 * @returns {Promise<boolean>} - True si le processus est en cours d'exécution
 */
function checkProcessRunning(server) {
  return new Promise((resolve) => {
    const isWindows = process.platform === 'win32';
    let command;
    
    if (isWindows) {
      // Commande pour Windows
      command = `tasklist /FI "IMAGENAME eq ${server.processName}.exe" /FI "WINDOWTITLE eq *${server.processArgs}*" /FO CSV /NH`;
    } else {
      // Commande pour Linux/macOS
      command = `ps aux | grep "${server.processArgs}" | grep -v grep`;
    }
    
    exec(command, (error, stdout) => {
      if (error && error.code !== 1) {
        logMessage(`Erreur lors de la vérification du processus ${server.name}: ${error}`, true);
        resolve(false);
        return;
      }
      
      const isRunning = stdout.trim().length > 0;
      resolve(isRunning);
    });
  });
}

/**
 * Vérifie si un serveur répond correctement
 * @param {Object} server - Configuration du serveur à vérifier
 * @returns {Promise<boolean>} - True si le serveur répond correctement
 */
function checkServerResponse(server) {
  return new Promise((resolve) => {
    const request = http.get(server.endpoint, (response) => {
      if (response.statusCode === 200) {
        resolve(true);
      } else {
        logMessage(`Le serveur ${server.name} a répondu avec le code ${response.statusCode}`, true);
        resolve(false);
      }
    });
    
    request.on('error', (error) => {
      logMessage(`Erreur lors de la connexion au serveur ${server.name}: ${error.message}`, true);
      resolve(false);
    });
    
    request.setTimeout(5000, () => {
      request.destroy();
      logMessage(`Délai d'attente dépassé pour le serveur ${server.name}`, true);
      resolve(false);
    });
  });
}

/**
 * Vérifie l'état d'un serveur MCP
 * @param {Object} server - Configuration du serveur à vérifier
 * @returns {Promise<Object>} - Résultat de la vérification
 */
async function checkServer(server) {
  logMessage(`Vérification du serveur ${server.name}...`);
  
  const isProcessRunning = await checkProcessRunning(server);
  let isServerResponding = false;
  
  if (isProcessRunning) {
    logMessage(`Le processus du serveur ${server.name} est en cours d'exécution.`);
    isServerResponding = await checkServerResponse(server);
    
    if (isServerResponding) {
      logMessage(`Le serveur ${server.name} répond correctement.`);
    } else {
      logMessage(`Le serveur ${server.name} ne répond pas correctement bien que le processus soit en cours d'exécution.`, true);
    }
  } else {
    logMessage(`Le processus du serveur ${server.name} n'est pas en cours d'exécution.`, true);
  }
  
  return {
    name: server.name,
    isProcessRunning,
    isServerResponding,
    timestamp: new Date().toISOString()
  };
}

/**
 * Vérifie l'état de tous les serveurs MCP
 * @returns {Promise<Array>} - Résultats de la vérification pour tous les serveurs
 */
async function checkAllServers() {
  logMessage('Début de la vérification des serveurs MCP...');
  
  const results = [];
  
  for (const server of MCP_SERVERS) {
    const result = await checkServer(server);
    results.push(result);
  }
  
  logMessage('Fin de la vérification des serveurs MCP.');
  
  // Enregistrer les résultats dans un fichier JSON
  const resultsFile = path.join(LOG_DIR, `mcp-status-${new Date().toISOString().replace(/:/g, '-')}.json`);
  fs.writeFileSync(resultsFile, JSON.stringify(results, null, 2));
  
  return results;
}

/**
 * Fonction principale
 */
async function main() {
  try {
    logMessage('Démarrage du système de surveillance des serveurs MCP...');
    
    // Vérifier l'état des serveurs
    const results = await checkAllServers();
    
    // Vérifier s'il y a des problèmes
    const problemServers = results.filter(result => !result.isProcessRunning || !result.isServerResponding);
    
    if (problemServers.length > 0) {
      logMessage(`ALERTE: ${problemServers.length} serveur(s) MCP ont des problèmes.`, true);
      
      for (const server of problemServers) {
        logMessage(`Problème avec le serveur ${server.name}:`, true);
        if (!server.isProcessRunning) {
          logMessage(`- Le processus n'est pas en cours d'exécution.`, true);
        }
        if (!server.isServerResponding) {
          logMessage(`- Le serveur ne répond pas correctement.`, true);
        }
      }
    } else {
      logMessage('Tous les serveurs MCP fonctionnent correctement.');
    }
    
  } catch (error) {
    logMessage(`Erreur lors de l'exécution du système de surveillance: ${error.message}`, true);
  }
}

// Si le script est exécuté directement
if (require.main === module) {
  main();
}

// Exporter les fonctions pour les tests et le script PowerShell
module.exports = {
  checkAllServers,
  checkServer,
  MCP_SERVERS,
  logMessage
};