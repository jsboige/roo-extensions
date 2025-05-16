/**
 * Script de diagnostic pour le MCP Jupyter
 * 
 * Ce script vérifie:
 * 1. Si le MCP Jupyter est en cours d'exécution
 * 2. Teste la connexion au MCP Jupyter
 * 3. Affiche des informations détaillées sur l'état du MCP
 * 4. Identifie les problèmes potentiels de "Connection closed"
 */

import { spawn, exec } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import http from 'http';
import https from 'https';
import net from 'net';
import os from 'os';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  mcpServerPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server'),
  mcpConfigPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json'),
  rooConfigPath: path.join(os.homedir(), 'AppData', 'Roaming', 'Code', 'User', 'globalStorage', 'rooveterinaryinc.roo-cline', 'settings', 'mcp_settings.json'),
  jupyterDefaultUrl: 'http://localhost:8888',
  connectionTimeout: 5000,
  requestTimeout: 5000,
};

// Couleurs pour la console
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  bold: '\x1b[1m',
};

/**
 * Affiche un message formaté dans la console
 */
function log(message, type = 'info') {
  const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
  let prefix = '';
  
  switch (type) {
    case 'error':
      prefix = `${colors.red}[ERREUR]${colors.reset}`;
      break;
    case 'warning':
      prefix = `${colors.yellow}[AVERT]${colors.reset}`;
      break;
    case 'success':
      prefix = `${colors.green}[SUCCÈS]${colors.reset}`;
      break;
    case 'info':
      prefix = `${colors.blue}[INFO]${colors.reset}`;
      break;
    case 'debug':
      prefix = `${colors.magenta}[DEBUG]${colors.reset}`;
      break;
    case 'header':
      console.log(`\n${colors.cyan}${colors.bold}=== ${message} ===${colors.reset}\n`);
      return;
    default:
      prefix = `[${type.toUpperCase()}]`;
  }
  
  console.log(`${prefix} ${timestamp} - ${message}`);
}

/**
 * Vérifie si un processus est en cours d'exécution
 */
function checkProcessRunning(processName) {
  return new Promise((resolve) => {
    const platform = process.platform;
    let command = '';
    
    if (platform === 'win32') {
      command = `tasklist /FI "IMAGENAME eq ${processName}"`;
    } else {
      command = `ps aux | grep ${processName} | grep -v grep`;
    }
    
    exec(command, (error, stdout, stderr) => {
      if (error) {
        resolve({ running: false, error: error.message });
        return;
      }
      
      if (platform === 'win32') {
        resolve({ 
          running: stdout.toLowerCase().includes(processName.toLowerCase()),
          output: stdout
        });
      } else {
        resolve({ 
          running: stdout.trim() !== '',
          output: stdout
        });
      }
    });
  });
}

/**
 * Vérifie si le port est en écoute
 */
function checkPortListening(port) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    
    socket.setTimeout(1000);
    
    socket.on('connect', () => {
      socket.destroy();
      resolve({ listening: true });
    });
    
    socket.on('timeout', () => {
      socket.destroy();
      resolve({ listening: false, reason: 'timeout' });
    });
    
    socket.on('error', (error) => {
      resolve({ listening: false, reason: error.code });
    });
    
    socket.connect(port, 'localhost');
  });
}

/**
 * Lit un fichier de configuration JSON
 */
function readJsonConfig(filePath) {
  try {
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    log(`Erreur lors de la lecture du fichier ${filePath}: ${error.message}`, 'error');
  }
  
  return null;
}

/**
 * Teste la connexion au serveur Jupyter
 */
async function testJupyterConnection(baseUrl, token) {
  try {
    log(`Test de connexion à ${baseUrl} avec token: ${token ? '✓' : '✗'}`, 'info');
    
    // Créer une URL pour l'API Jupyter
    const apiUrl = `${baseUrl}/api/kernels`;
    const url = token ? `${apiUrl}?token=${token}` : apiUrl;
    
    return new Promise((resolve) => {
      // Déterminer le module HTTP à utiliser (http ou https)
      const httpModule = baseUrl.startsWith('https') ? https : http;
      
      // Configurer les options de requête
      const options = {
        timeout: config.requestTimeout,
        headers: {}
      };
      
      // Ajouter le token dans l'en-tête si disponible
      if (token) {
        options.headers['Authorization'] = `token ${token}`;
      }
      
      const req = httpModule.get(url, options, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
          data += chunk;
        });
        
        res.on('end', () => {
          if (res.statusCode === 200) {
            log(`Connexion réussie au serveur Jupyter (${res.statusCode})`, 'success');
            
            let jsonData = null;
            try {
              jsonData = JSON.parse(data);
            } catch (e) {
              log(`Erreur lors de l'analyse de la réponse JSON: ${e.message}`, 'warning');
            }
            
            resolve({ 
              success: true, 
              status: res.statusCode,
              data: jsonData
            });
          } else {
            log(`Échec de la connexion au serveur Jupyter: Code ${res.statusCode}`, 'error');
            resolve({ 
              success: false, 
              status: res.statusCode,
              error: res.statusMessage,
              data
            });
          }
        });
      });
      
      req.on('error', (error) => {
        log(`Erreur lors du test de connexion: ${error.message}`, 'error');
        resolve({ 
          success: false, 
          error: error.message,
          code: error.code
        });
      });
      
      req.on('timeout', () => {
        req.destroy();
        log('Délai d\'attente dépassé lors de la tentative de connexion', 'error');
        resolve({ 
          success: false, 
          error: 'Timeout',
          code: 'ETIMEDOUT'
        });
      });
      
      req.end();
    });
  } catch (error) {
    log(`Erreur lors du test de connexion: ${error.message}`, 'error');
    
    // Analyser l'erreur pour fournir plus d'informations
    let detailedError = '';
    if (error.code === 'ECONNREFUSED') {
      detailedError = 'Le serveur Jupyter n\'est pas en cours d\'exécution ou n\'écoute pas sur le port spécifié';
    } else if (error.code === 'ECONNRESET' || error.message.includes('socket hang up')) {
      detailedError = 'La connexion a été réinitialisée par le serveur (Connection reset/closed)';
    } else if (error.code === 'ETIMEDOUT') {
      detailedError = 'Délai d\'attente dépassé lors de la tentative de connexion';
    }
    
    return { 
      success: false, 
      error: error.message,
      code: error.code,
      detailedError
    };
  }
}

/**
 * Vérifie la configuration du MCP Jupyter dans Roo
 */
function checkRooMcpConfig() {
  const rooConfig = readJsonConfig(config.rooConfigPath);
  
  if (!rooConfig) {
    log(`Impossible de lire la configuration Roo: ${config.rooConfigPath}`, 'error');
    return null;
  }
  
  if (!rooConfig.mcpServers || !rooConfig.mcpServers.jupyter) {
    log('Configuration MCP Jupyter non trouvée dans Roo', 'error');
    return null;
  }
  
  const jupyterConfig = rooConfig.mcpServers.jupyter;
  
  log('Configuration MCP Jupyter dans Roo:', 'info');
  log(`- Command: ${jupyterConfig.command || 'Non défini'}`, 'debug');
  log(`- Args: ${jupyterConfig.args ? jupyterConfig.args.join(' ') : 'Non défini'}`, 'debug');
  log(`- Transport Type: ${jupyterConfig.transportType || 'Non défini'}`, 'debug');
  log(`- Disabled: ${jupyterConfig.disabled ? 'Oui' : 'Non'}`, 'debug');
  
  if (jupyterConfig.config) {
    log('- Configuration interne:', 'debug');
    log(`  - Mode hors ligne: ${jupyterConfig.config.offlineMode ? 'Activé' : 'Désactivé'}`, 'debug');
    if (jupyterConfig.config.jupyterServer) {
      log(`  - URL du serveur: ${jupyterConfig.config.jupyterServer.baseUrl || 'Non défini'}`, 'debug');
      log(`  - Token: ${jupyterConfig.config.jupyterServer.token ? '✓' : '✗'}`, 'debug');
    }
  }
  
  return jupyterConfig;
}

/**
 * Vérifie la configuration du serveur MCP Jupyter
 */
function checkMcpServerConfig() {
  const mcpConfig = readJsonConfig(config.mcpConfigPath);
  
  if (!mcpConfig) {
    log(`Impossible de lire la configuration du serveur MCP: ${config.mcpConfigPath}`, 'error');
    return null;
  }
  
  log('Configuration du serveur MCP Jupyter:', 'info');
  
  if (mcpConfig.jupyterServer) {
    const js = mcpConfig.jupyterServer;
    log(`- URL du serveur: ${js.baseUrl || 'Non défini'}`, 'debug');
    log(`- Token: ${js.token ? '✓' : '✗'}`, 'debug');
    log(`- Mode hors ligne: ${js.offline ? 'Activé' : 'Désactivé'}`, 'debug');
  } else {
    log('- Configuration du serveur Jupyter non trouvée', 'warning');
  }
  
  return mcpConfig;
}

/**
 * Vérifie les processus liés à Jupyter et au MCP
 */
async function checkRelatedProcesses() {
  log('Vérification des processus en cours d\'exécution...', 'info');
  
  // Vérifier si node.js est en cours d'exécution (pour le MCP)
  const nodeProcess = await checkProcessRunning('node.exe');
  if (nodeProcess.running) {
    log('Processus Node.js trouvé en cours d\'exécution', 'success');
  } else {
    log('Aucun processus Node.js trouvé', 'warning');
  }
  
  // Vérifier si jupyter est en cours d'exécution
  const jupyterProcess = await checkProcessRunning('jupyter');
  if (jupyterProcess.running) {
    log('Processus Jupyter trouvé en cours d\'exécution', 'success');
  } else {
    log('Aucun processus Jupyter trouvé', 'warning');
  }
  
  // Vérifier si python est en cours d'exécution (pour Jupyter)
  const pythonProcess = await checkProcessRunning('python.exe');
  if (pythonProcess.running) {
    log('Processus Python trouvé en cours d\'exécution', 'success');
  } else {
    log('Aucun processus Python trouvé', 'warning');
  }
  
  // Vérifier si le port 8888 est en écoute (port par défaut de Jupyter)
  const port8888 = await checkPortListening(8888);
  if (port8888.listening) {
    log('Port 8888 en écoute (Jupyter)', 'success');
  } else {
    log(`Port 8888 non en écoute: ${port8888.reason || 'inconnu'}`, 'warning');
  }
  
  return {
    nodeRunning: nodeProcess.running,
    jupyterRunning: jupyterProcess.running,
    pythonRunning: pythonProcess.running,
    port8888Listening: port8888.listening
  };
}

/**
 * Analyse les problèmes potentiels de "Connection closed"
 */
function analyzeConnectionClosedIssues(testResults) {
  log('Analyse des problèmes potentiels de "Connection closed"...', 'info');
  
  const issues = [];
  
  // Vérifier si le serveur Jupyter est en cours d'exécution
  if (!testResults.processes.jupyterRunning && !testResults.processes.pythonRunning) {
    issues.push({
      severity: 'high',
      message: 'Le serveur Jupyter n\'est pas en cours d\'exécution',
      solution: 'Démarrez le serveur Jupyter avec la commande: jupyter notebook'
    });
  }
  
  // Vérifier si le port est en écoute
  if (!testResults.processes.port8888Listening) {
    issues.push({
      severity: 'high',
      message: 'Le port 8888 n\'est pas en écoute (Jupyter)',
      solution: 'Vérifiez que Jupyter est démarré et écoute sur le port 8888'
    });
  }
  
  // Vérifier la configuration du MCP
  if (testResults.mcpConfig && testResults.mcpConfig.jupyterServer) {
    const js = testResults.mcpConfig.jupyterServer;
    
    // Vérifier le mode hors ligne
    if (js.offline) {
      issues.push({
        severity: 'medium',
        message: 'Le MCP Jupyter est configuré en mode hors ligne',
        solution: 'Modifiez le fichier config.json pour définir "offline": false'
      });
    }
    
    // Vérifier l'URL du serveur
    if (!js.baseUrl) {
      issues.push({
        severity: 'high',
        message: 'L\'URL du serveur Jupyter n\'est pas définie',
        solution: 'Définissez "baseUrl" dans le fichier config.json'
      });
    }
    
    // Vérifier le token
    if (js.baseUrl && !js.token && !js.baseUrl.includes('token=')) {
      issues.push({
        severity: 'high',
        message: 'Le token d\'authentification n\'est pas défini',
        solution: 'Définissez "token" dans le fichier config.json avec le token affiché lors du démarrage de Jupyter'
      });
    }
  }
  
  // Vérifier la configuration de Roo
  if (testResults.rooConfig) {
    if (testResults.rooConfig.disabled) {
      issues.push({
        severity: 'high',
        message: 'Le MCP Jupyter est désactivé dans la configuration de Roo',
        solution: 'Modifiez le fichier mcp_settings.json pour définir "disabled": false'
      });
    }
    
    if (testResults.rooConfig.config && testResults.rooConfig.config.offlineMode) {
      issues.push({
        severity: 'medium',
        message: 'Le MCP Jupyter est configuré en mode hors ligne dans Roo',
        solution: 'Modifiez le fichier mcp_settings.json pour définir "offlineMode": false'
      });
    }
  }
  
  // Vérifier les résultats de connexion
  if (testResults.connectionTest && !testResults.connectionTest.success) {
    if (testResults.connectionTest.code === 'ECONNREFUSED') {
      issues.push({
        severity: 'high',
        message: 'La connexion au serveur Jupyter a été refusée',
        solution: 'Vérifiez que le serveur Jupyter est en cours d\'exécution et que l\'URL est correcte'
      });
    } else if (testResults.connectionTest.code === 'ECONNRESET' || 
               testResults.connectionTest.error && testResults.connectionTest.error.includes('socket hang up')) {
      issues.push({
        severity: 'high',
        message: 'La connexion a été fermée par le serveur (Connection closed/reset)',
        solution: 'Vérifiez que le token est correct et que le serveur Jupyter accepte les connexions externes'
      });
    }
  }
  
  // Afficher les problèmes identifiés
  if (issues.length === 0) {
    log('Aucun problème potentiel identifié', 'success');
  } else {
    log(`${issues.length} problème(s) potentiel(s) identifié(s):`, 'warning');
    
    issues.forEach((issue, index) => {
      const severityColor = issue.severity === 'high' ? colors.red : 
                           (issue.severity === 'medium' ? colors.yellow : colors.blue);
      
      log(`${index + 1}. ${severityColor}[${issue.severity.toUpperCase()}]${colors.reset} ${issue.message}`, 'info');
      log(`   Solution: ${issue.solution}`, 'info');
    });
  }
  
  return issues;
}

/**
 * Fonction principale de diagnostic
 */
async function runDiagnostic() {
  log('DIAGNOSTIC DU MCP JUPYTER', 'header');
  
  // Étape 1: Vérifier les processus en cours d'exécution
  log('VÉRIFICATION DES PROCESSUS', 'header');
  const processes = await checkRelatedProcesses();
  
  // Étape 2: Vérifier la configuration
  log('VÉRIFICATION DE LA CONFIGURATION', 'header');
  const rooConfig = checkRooMcpConfig();
  const mcpConfig = checkMcpServerConfig();
  
  // Étape 3: Tester la connexion au serveur Jupyter
  log('TEST DE CONNEXION', 'header');
  let baseUrl = config.jupyterDefaultUrl;
  let token = '';
  
  // Utiliser la configuration du serveur MCP si disponible
  if (mcpConfig && mcpConfig.jupyterServer) {
    baseUrl = mcpConfig.jupyterServer.baseUrl || baseUrl;
    token = mcpConfig.jupyterServer.token || token;
  }
  
  const connectionTest = await testJupyterConnection(baseUrl, token);
  
  // Étape 4: Analyser les problèmes potentiels
  log('ANALYSE DES PROBLÈMES', 'header');
  const issues = analyzeConnectionClosedIssues({
    processes,
    rooConfig,
    mcpConfig,
    connectionTest
  });
  
  // Étape 5: Afficher le résumé
  log('RÉSUMÉ DU DIAGNOSTIC', 'header');
  log(`État des processus: ${processes.nodeRunning && (processes.jupyterRunning || processes.pythonRunning) ? 'OK' : 'Problème détecté'}`, processes.nodeRunning && (processes.jupyterRunning || processes.pythonRunning) ? 'success' : 'error');
  log(`Configuration Roo: ${rooConfig ? 'Trouvée' : 'Non trouvée'}`, rooConfig ? 'success' : 'error');
  log(`Configuration MCP: ${mcpConfig ? 'Trouvée' : 'Non trouvée'}`, mcpConfig ? 'success' : 'error');
  log(`Test de connexion: ${connectionTest.success ? 'Réussi' : 'Échoué'}`, connectionTest.success ? 'success' : 'error');
  log(`Problèmes identifiés: ${issues.length}`, issues.length === 0 ? 'success' : 'warning');
  
  // Étape 6: Proposer des solutions
  if (issues.length > 0) {
    log('SOLUTIONS RECOMMANDÉES', 'header');
    
    // Regrouper les solutions par sévérité
    const highPriorityIssues = issues.filter(issue => issue.severity === 'high');
    const mediumPriorityIssues = issues.filter(issue => issue.severity === 'medium');
    
    if (highPriorityIssues.length > 0) {
      log('Actions prioritaires:', 'error');
      highPriorityIssues.forEach((issue, index) => {
        log(`${index + 1}. ${issue.solution}`, 'info');
      });
    }
    
    if (mediumPriorityIssues.length > 0) {
      log('Actions secondaires:', 'warning');
      mediumPriorityIssues.forEach((issue, index) => {
        log(`${index + 1}. ${issue.solution}`, 'info');
      });
    }
    
    // Proposer une solution complète
    log('SOLUTION COMPLÈTE', 'header');
    log('Pour résoudre le problème "Connection closed":', 'info');
    log('1. Vérifiez que le serveur Jupyter est en cours d\'exécution', 'info');
    log('2. Assurez-vous que la configuration du MCP Jupyter est correcte:', 'info');
    log('   - Mode hors ligne désactivé (offline: false)', 'info');
    log('   - URL du serveur correcte (généralement http://localhost:8888)', 'info');
    log('   - Token d\'authentification correct', 'info');
    log('3. Redémarrez le serveur MCP Jupyter après avoir modifié la configuration', 'info');
    log('4. Si le problème persiste, essayez de redémarrer le serveur Jupyter', 'info');
  } else {
    log('Aucun problème détecté. Le MCP Jupyter semble fonctionner correctement.', 'success');
  }
}

// Exécuter le diagnostic
runDiagnostic().catch(error => {
  log(`Erreur lors du diagnostic: ${error.message}`, 'error');
  console.error(error);
});