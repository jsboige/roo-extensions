/**
 * Script de test pour vérifier l'état de la connexion au serveur Jupyter
 * Ce script teste différentes méthodes d'authentification et fournit des informations détaillées
 * sur l'état de la connexion au serveur Jupyter.
 */

import axios from 'axios';
import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import net from 'net';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Couleurs pour la console
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m'
};

// Configuration par défaut
let config = {
  jupyterServer: {
    baseUrl: 'http://localhost:8888',
    token: 'mcp-jupyter-token'
  }
};

/**
 * Charge la configuration depuis le fichier config.json
 */
function loadConfig() {
  try {
    const configPath = path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json');
    if (fs.existsSync(configPath)) {
      config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      console.log(`${colors.green}✓${colors.reset} Configuration chargée depuis ${configPath}`);
    } else {
      console.log(`${colors.yellow}⚠${colors.reset} Fichier de configuration non trouvé, utilisation des valeurs par défaut`);
    }
  } catch (error) {
    console.error(`${colors.red}✗${colors.reset} Erreur lors du chargement de la configuration:`, error.message);
  }
}

/**
 * Vérifie si le serveur est en écoute sur un port spécifique
 * @param {number} port Port à vérifier
 * @returns {Promise<boolean>} True si le port est ouvert, false sinon
 */
function checkPort(port) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    
    const timeout = setTimeout(() => {
      socket.destroy();
      resolve(false);
    }, 1000);
    
    socket.connect(port, '127.0.0.1', () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve(true);
    });
    
    socket.on('error', () => {
      clearTimeout(timeout);
      resolve(false);
    });
  });
}

/**
 * Teste la connexion au serveur Jupyter avec différentes méthodes d'authentification
 * @param {string} baseUrl URL de base du serveur Jupyter
 * @param {string} token Token d'authentification
 */
async function testAuthentication(baseUrl, token) {
  console.log(`\n${colors.cyan}=== Test des méthodes d'authentification ===${colors.reset}`);
  
  // Normaliser l'URL de base
  baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
  
  // Tableau pour stocker les résultats des tests
  const results = [];
  
  // Test 1: Sans authentification
  try {
    console.log(`\n${colors.magenta}Méthode 1:${colors.reset} Sans authentification`);
    const response = await axios.get(`${baseUrl}/api`, { timeout: 3000 });
    console.log(`${colors.green}✓${colors.reset} Succès! Code: ${response.status}`);
    console.log(`  Réponse: ${JSON.stringify(response.data).substring(0, 100)}...`);
    results.push({ method: 'Sans authentification', endpoint: '/api', success: true });
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Échec: ${error.message}`);
    results.push({ method: 'Sans authentification', endpoint: '/api', success: false, error: error.message });
  }
  
  // Test 2: Token dans l'URL
  try {
    console.log(`\n${colors.magenta}Méthode 2:${colors.reset} Token dans l'URL`);
    const response = await axios.get(`${baseUrl}/api/kernels?token=${token}`, { timeout: 3000 });
    console.log(`${colors.green}✓${colors.reset} Succès! Code: ${response.status}`);
    console.log(`  Nombre de kernels: ${response.data.length}`);
    results.push({ method: 'Token dans l\'URL', endpoint: '/api/kernels', success: true });
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Échec: ${error.message}`);
    results.push({ method: 'Token dans l\'URL', endpoint: '/api/kernels', success: false, error: error.message });
  }
  
  // Test 3: En-tête d'autorisation
  try {
    console.log(`\n${colors.magenta}Méthode 3:${colors.reset} En-tête d'autorisation`);
    const response = await axios.get(`${baseUrl}/api/kernels`, {
      headers: { Authorization: `token ${token}` },
      timeout: 3000
    });
    console.log(`${colors.green}✓${colors.reset} Succès! Code: ${response.status}`);
    console.log(`  Nombre de kernels: ${response.data.length}`);
    results.push({ method: 'En-tête d\'autorisation', endpoint: '/api/kernels', success: true });
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Échec: ${error.message}`);
    results.push({ method: 'En-tête d\'autorisation', endpoint: '/api/kernels', success: false, error: error.message });
  }
  
  // Test 4: Token dans l'URL et en-tête
  try {
    console.log(`\n${colors.magenta}Méthode 4:${colors.reset} Token dans l'URL et en-tête`);
    const response = await axios.get(`${baseUrl}/api/kernels?token=${token}`, {
      headers: { Authorization: `token ${token}` },
      timeout: 3000
    });
    console.log(`${colors.green}✓${colors.reset} Succès! Code: ${response.status}`);
    console.log(`  Nombre de kernels: ${response.data.length}`);
    results.push({ method: 'Token dans l\'URL et en-tête', endpoint: '/api/kernels', success: true });
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Échec: ${error.message}`);
    results.push({ method: 'Token dans l\'URL et en-tête', endpoint: '/api/kernels', success: false, error: error.message });
  }
  
  // Test 5: Sessions API
  try {
    console.log(`\n${colors.magenta}Méthode 5:${colors.reset} Sessions API avec token dans l'URL`);
    const response = await axios.get(`${baseUrl}/api/sessions?token=${token}`, { timeout: 3000 });
    console.log(`${colors.green}✓${colors.reset} Succès! Code: ${response.status}`);
    console.log(`  Nombre de sessions: ${response.data.length}`);
    results.push({ method: 'Sessions API', endpoint: '/api/sessions', success: true });
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Échec: ${error.message}`);
    results.push({ method: 'Sessions API', endpoint: '/api/sessions', success: false, error: error.message });
  }
  
  return results;
}

/**
 * Teste la version de l'API Jupyter
 * @param {string} baseUrl URL de base du serveur Jupyter
 * @param {string} token Token d'authentification
 */
async function checkJupyterVersion(baseUrl, token) {
  console.log(`\n${colors.cyan}=== Vérification de la version de l'API Jupyter ===${colors.reset}`);
  
  try {
    const response = await axios.get(`${baseUrl}/api?token=${token}`, { timeout: 3000 });
    console.log(`${colors.green}✓${colors.reset} Version de l'API Jupyter: ${response.data.version || 'Non spécifiée'}`);
    return response.data.version;
  } catch (error) {
    console.log(`${colors.red}✗${colors.reset} Erreur lors de la vérification de la version: ${error.message}`);
    return null;
  }
}

/**
 * Génère des recommandations basées sur les résultats des tests
 * @param {Array} results Résultats des tests d'authentification
 * @param {string} version Version de l'API Jupyter
 */
function generateRecommendations(results, version) {
  console.log(`\n${colors.cyan}=== Recommandations ===${colors.reset}`);
  
  // Compter les méthodes qui ont réussi
  const successfulMethods = results.filter(r => r.success);
  
  if (successfulMethods.length === 0) {
    console.log(`${colors.red}✗${colors.reset} Aucune méthode d'authentification n'a fonctionné.`);
    console.log(`  Recommandations:`);
    console.log(`  1. Vérifiez que le serveur Jupyter est bien en cours d'exécution.`);
    console.log(`  2. Vérifiez que le token configuré est correct.`);
    console.log(`  3. Essayez de redémarrer le serveur Jupyter avec l'option --NotebookApp.token=mcp-jupyter-token.`);
    console.log(`  4. Vérifiez les logs du serveur Jupyter pour plus d'informations sur les erreurs.`);
  } else {
    console.log(`${colors.green}✓${colors.reset} ${successfulMethods.length} méthode(s) d'authentification ont fonctionné.`);
    console.log(`  Méthodes qui ont fonctionné:`);
    successfulMethods.forEach(method => {
      console.log(`  - ${method.method} (${method.endpoint})`);
    });
    
    // Recommandation de la meilleure méthode
    if (successfulMethods.some(m => m.method === 'Token dans l\'URL et en-tête')) {
      console.log(`\n  Recommandation: Utilisez la méthode "Token dans l'URL et en-tête" pour une sécurité maximale.`);
    } else if (successfulMethods.some(m => m.method === 'En-tête d\'autorisation')) {
      console.log(`\n  Recommandation: Utilisez la méthode "En-tête d'autorisation" pour une meilleure sécurité.`);
    } else if (successfulMethods.some(m => m.method === 'Token dans l\'URL')) {
      console.log(`\n  Recommandation: Utilisez la méthode "Token dans l'URL" qui a fonctionné.`);
    }
  }
  
  // Recommandations spécifiques pour les sessions
  const sessionsTest = results.find(r => r.endpoint === '/api/sessions');
  if (sessionsTest && !sessionsTest.success) {
    console.log(`\n${colors.yellow}⚠${colors.reset} L'API Sessions n'est pas accessible, ce qui peut causer des erreurs 403.`);
    console.log(`  Recommandations pour l'API Sessions:`);
    console.log(`  1. Modifiez la fonction testConnection() dans jupyter.ts pour utiliser la méthode d'authentification qui a fonctionné.`);
    console.log(`  2. Implémentez une logique de retry avec différentes méthodes d'authentification.`);
  }
  
  // Recommandations basées sur la version
  if (version) {
    console.log(`\n  Recommandations basées sur la version ${version}:`);
    console.log(`  - Assurez-vous que la bibliothèque @jupyterlab/services est compatible avec cette version.`);
  }
}

/**
 * Fonction principale
 */
async function main() {
  console.log(`${colors.cyan}=== Test de l'état de la connexion au serveur Jupyter ===${colors.reset}`);
  console.log(`Date: ${new Date().toLocaleString()}\n`);
  
  // Charger la configuration
  loadConfig();
  
  const baseUrl = config.jupyterServer.baseUrl;
  const token = config.jupyterServer.token;
  
  console.log(`URL de base: ${baseUrl}`);
  console.log(`Token: ${token}`);
  
  // Vérifier si le port est ouvert
  const port = new URL(baseUrl).port || (baseUrl.startsWith('https') ? 443 : 80);
  const portOpen = await checkPort(port);
  
  if (!portOpen) {
    console.log(`\n${colors.red}✗${colors.reset} Le port ${port} n'est pas ouvert. Le serveur Jupyter n'est probablement pas en cours d'exécution.`);
    console.log(`  Recommandation: Démarrez le serveur Jupyter avec la commande:`);
    console.log(`  python -m notebook --NotebookApp.token=${token} --no-browser`);
    return;
  }
  
  console.log(`\n${colors.green}✓${colors.reset} Le port ${port} est ouvert. Le serveur est en cours d'exécution.`);
  
  // Tester les différentes méthodes d'authentification
  const results = await testAuthentication(baseUrl, token);
  
  // Vérifier la version de l'API Jupyter
  const version = await checkJupyterVersion(baseUrl, token);
  
  // Générer des recommandations
  generateRecommendations(results, version);
  
  console.log(`\n${colors.cyan}=== Test terminé ===${colors.reset}`);
}

// Exécuter la fonction principale
main().catch(error => {
  console.error(`${colors.red}Erreur non gérée:${colors.reset}`, error);
});