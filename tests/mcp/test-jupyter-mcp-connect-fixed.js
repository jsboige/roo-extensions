/**
 * Script de test pour vérifier le changement de configuration à chaud du MCP Jupyter
 * Version corrigée avec les bons chemins de configuration
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import readline from 'readline';
import http from 'http';
import https from 'https';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration avec les bons chemins
const config = {
  mcpServerPath: path.join(__dirname, '..', '..', 'mcps', 'mcp-servers', 'servers', 'jupyter-mcp-server'),
  mcpServerCommand: 'node',
  mcpServerArgs: ['dist/index.js'],  // Sans l'option --offline car nous voulons tester la connexion
  configPath: path.join(__dirname, '..', '..', 'mcps', 'mcp-servers', 'servers', 'jupyter-mcp-server', 'config.json'),
  startupTimeout: 5000, // Temps d'attente pour le démarrage du serveur (5 secondes)
  connectionTimeout: 10000, // Temps d'attente pour la connexion (10 secondes)
  defaultJupyterUrl: 'http://localhost:8890',  // Mis à jour pour utiliser le port 8890
};

// Fonction pour démarrer un processus et capturer sa sortie
function startProcess(command, args, options = {}) {
  console.log(`Démarrage de la commande: ${command} ${args.join(' ')}`);
  
  const proc = spawn(command, args, {
    ...options,
    stdio: 'pipe',
    shell: true
  });
  
  proc.stdout.on('data', (data) => {
    console.log(`[MCP] ${data.toString().trim()}`);
  });
  
  proc.stderr.on('data', (data) => {
    console.error(`[MCP ERROR] ${data.toString().trim()}`);
  });
  
  proc.on('error', (err) => {
    console.error('Erreur lors du démarrage du processus:', err);
  });
  
  return proc;
}

// Fonction pour vérifier si un serveur est accessible
function checkServer(url) {
  return new Promise((resolve) => {
    const client = url.startsWith('https') ? https : http;
    
    client.get(url, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          data,
          success: res.statusCode === 200
        });
      });
    }).on('error', (err) => {
      resolve({
        statusCode: null,
        data: null,
        success: false,
        error: err.message
      });
    });
  });
}

// Fonction pour lire la configuration actuelle
function readConfig() {
  try {
    if (fs.existsSync(config.configPath)) {
      return JSON.parse(fs.readFileSync(config.configPath, 'utf8'));
    }
  } catch (err) {
    console.error('Erreur lors de la lecture de la configuration:', err);
  }
  
  return {
    jupyterServer: {
      baseUrl: config.defaultJupyterUrl,
      token: ''
    }
  };
}

// Fonction pour tester la connexion au serveur Jupyter
async function testJupyterConnection(baseUrl, token) {
  const url = `${baseUrl}/api/kernels?token=${token}`;
  console.log(`Test de connexion à ${url}...`);
  
  const result = await checkServer(url);
  
  if (result.success) {
    console.log('✅ Connexion réussie au serveur Jupyter');
    try {
      const response = JSON.parse(result.data);
      if (Array.isArray(response)) {
        console.log(`✅ Le serveur a retourné une liste de ${response.length} kernels`);
        return true;
      }
    } catch (e) {
      console.error('Erreur lors de l\'analyse de la réponse JSON:', e);
    }
  } else {
    console.log(`❌ Échec de la connexion au serveur Jupyter: ${result.error || `Code ${result.statusCode}`}`);
  }
  
  return false;
}

// Fonction principale
async function main() {
  console.log('=== Test de connexion du MCP Jupyter au serveur Jupyter ===');
  
  // Vérifier si le serveur MCP Jupyter est compilé
  const mcpServerJsPath = path.join(config.mcpServerPath, 'dist', 'index.js');
  if (!fs.existsSync(mcpServerJsPath)) {
    console.error(`Le fichier ${mcpServerJsPath} n'existe pas.`);
    console.error('Veuillez compiler le serveur MCP Jupyter avant de lancer ce test.');
    console.error('Exécutez: cd mcps/mcp-servers/servers/jupyter-mcp-server && npm run build');
    process.exit(1);
  }
  
  // Lire la configuration actuelle
  const currentConfig = readConfig();
  console.log('Configuration actuelle:');
  console.log(JSON.stringify(currentConfig, null, 2));
  
  // Démarrer le serveur MCP Jupyter
  console.log('Démarrage du serveur MCP Jupyter...');
  const mcpProcess = startProcess(
    config.mcpServerCommand,
    config.mcpServerArgs,
    { cwd: config.mcpServerPath }
  );
  
  // Attendre que le serveur soit prêt
  console.log(`Attente de ${config.startupTimeout / 1000} secondes pour le démarrage du serveur...`);
  await new Promise(resolve => setTimeout(resolve, config.startupTimeout));
  
  // Tester la connexion au serveur Jupyter
  console.log('\n=== Test de connexion au serveur Jupyter ===');
  const connectionResult = await testJupyterConnection(
    currentConfig.jupyterServer.baseUrl,
    currentConfig.jupyterServer.token
  );
  
  // Afficher les résultats
  console.log('\n=== Résultats du test ===');
  
  if (connectionResult) {
    console.log('✅ Le test est un succès!');
    console.log('✅ Le serveur MCP Jupyter est connecté au serveur Jupyter');
  } else {
    console.log('❌ Le test a échoué');
    console.log('❌ Le serveur MCP Jupyter n\'a pas pu se connecter au serveur Jupyter');
  }
  
  // Arrêter le serveur MCP Jupyter
  console.log('\nArrêt du serveur MCP Jupyter...');
  mcpProcess.kill();
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  process.exit(1);
});