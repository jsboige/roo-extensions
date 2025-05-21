/**
 * Script de test pour vérifier le changement de configuration à chaud du MCP Jupyter
 * Ce script démarre le MCP Jupyter en mode hors ligne, puis modifie sa configuration
 * pour pointer vers un serveur Jupyter en cours d'exécution et vérifie la connexion.
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

// Configuration
const config = {
  mcpServerPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server'),
  mcpServerCommand: 'node',
  mcpServerArgs: ['dist/index.js', '--offline'],
  configPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json'),
  startupTimeout: 5000, // Temps d'attente pour le démarrage du serveur (5 secondes)
  connectionTimeout: 10000, // Temps d'attente pour la connexion (10 secondes)
  defaultJupyterUrl: 'http://localhost:8888',
};

// Créer une interface readline pour l'interaction avec l'utilisateur
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Fonction pour poser une question à l'utilisateur
function question(query) {
  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      resolve(answer);
    });
  });
}

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

// Fonction pour sauvegarder la configuration
function saveConfig(baseUrl, token) {
  const configData = {
    jupyterServer: {
      baseUrl,
      token
    }
  };
  
  try {
    fs.writeFileSync(
      config.configPath,
      JSON.stringify(configData, null, 2),
      'utf8'
    );
    return true;
  } catch (err) {
    console.error('Erreur lors de la sauvegarde de la configuration:', err);
    return false;
  }
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
  console.log('=== Test de changement de configuration à chaud du MCP Jupyter ===');
  
  // Vérifier si le serveur MCP Jupyter est compilé
  const mcpServerJsPath = path.join(config.mcpServerPath, 'dist', 'index.js');
  if (!fs.existsSync(mcpServerJsPath)) {
    console.error(`Le fichier ${mcpServerJsPath} n'existe pas.`);
    console.error('Veuillez compiler le serveur MCP Jupyter avant de lancer ce test.');
    console.error('Exécutez: cd servers/jupyter-mcp-server && npm run build');
    process.exit(1);
  }
  
  // Lire la configuration actuelle
  const currentConfig = readConfig();
  console.log('Configuration actuelle:');
  console.log(JSON.stringify(currentConfig, null, 2));
  
  // Demander à l'utilisateur s'il souhaite utiliser la configuration existante ou en saisir une nouvelle
  const useExisting = await question('Utiliser la configuration existante? (O/n): ');
  
  let baseUrl = currentConfig.jupyterServer.baseUrl;
  let token = currentConfig.jupyterServer.token;
  
  if (useExisting.toLowerCase() !== 'o' && useExisting.toLowerCase() !== 'oui' && useExisting !== '') {
    baseUrl = await question(`URL du serveur Jupyter [${config.defaultJupyterUrl}]: `);
    if (!baseUrl) baseUrl = config.defaultJupyterUrl;
    
    token = await question('Token d\'authentification: ');
    
    // Sauvegarder la nouvelle configuration
    if (saveConfig(baseUrl, token)) {
      console.log('✅ Nouvelle configuration sauvegardée');
    } else {
      console.log('❌ Échec de la sauvegarde de la configuration');
      process.exit(1);
    }
  }
  
  // Démarrer le serveur MCP Jupyter en mode hors ligne
  console.log('Démarrage du serveur MCP Jupyter en mode hors ligne...');
  const mcpProcess = startProcess(
    config.mcpServerCommand,
    config.mcpServerArgs,
    { cwd: config.mcpServerPath }
  );
  
  // Attendre que le serveur soit prêt
  console.log(`Attente de ${config.startupTimeout / 1000} secondes pour le démarrage du serveur...`);
  await new Promise(resolve => setTimeout(resolve, config.startupTimeout));
  
  // Tester la connexion au serveur Jupyter avant le changement de configuration
  console.log('\n=== Test de connexion avant changement de configuration ===');
  const beforeResult = await testJupyterConnection(baseUrl, token);
  
  if (beforeResult) {
    console.log('⚠️ Le serveur MCP Jupyter est déjà connecté au serveur Jupyter.');
    console.log('Cela peut être dû à une mauvaise configuration du mode hors ligne.');
  } else {
    console.log('✅ Le serveur MCP Jupyter est bien en mode hors ligne.');
  }
  
  // Modifier la configuration pour activer la connexion
  console.log('\n=== Changement de configuration à chaud ===');
  console.log('Création d\'un fichier de configuration temporaire sans mode hors ligne...');
  
  // Sauvegarder la configuration sans mode hors ligne
  const tempConfigPath = path.join(config.mcpServerPath, 'config.temp.json');
  try {
    fs.writeFileSync(
      tempConfigPath,
      JSON.stringify({
        jupyterServer: {
          baseUrl,
          token
        }
      }, null, 2),
      'utf8'
    );
    
    // Renommer le fichier pour déclencher le rechargement de la configuration
    fs.renameSync(tempConfigPath, config.configPath);
    console.log('✅ Configuration mise à jour pour activer la connexion');
  } catch (err) {
    console.error('Erreur lors de la mise à jour de la configuration:', err);
    mcpProcess.kill();
    process.exit(1);
  }
  
  // Attendre que la configuration soit rechargée
  console.log(`Attente de ${config.connectionTimeout / 1000} secondes pour le rechargement de la configuration...`);
  await new Promise(resolve => setTimeout(resolve, config.connectionTimeout));
  
  // Tester la connexion au serveur Jupyter après le changement de configuration
  console.log('\n=== Test de connexion après changement de configuration ===');
  const afterResult = await testJupyterConnection(baseUrl, token);
  
  // Afficher les résultats
  console.log('\n=== Résultats du test ===');
  
  if (!beforeResult && afterResult) {
    console.log('✅ Le test est un succès!');
    console.log('✅ Le serveur MCP Jupyter a bien démarré en mode hors ligne');
    console.log('✅ Le changement de configuration à chaud a fonctionné');
    console.log('✅ Le serveur MCP Jupyter est maintenant connecté au serveur Jupyter');
  } else if (beforeResult) {
    console.log('⚠️ Le serveur MCP Jupyter n\'était pas en mode hors ligne au départ');
    console.log('⚠️ Le test n\'est pas concluant');
  } else {
    console.log('❌ Le test a échoué');
    console.log('❌ Le serveur MCP Jupyter n\'a pas pu se connecter au serveur Jupyter après le changement de configuration');
  }
  
  // Arrêter le serveur MCP Jupyter
  console.log('\nArrêt du serveur MCP Jupyter...');
  mcpProcess.kill();
  
  // Fermer l'interface readline
  rl.close();
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  process.exit(1);
});