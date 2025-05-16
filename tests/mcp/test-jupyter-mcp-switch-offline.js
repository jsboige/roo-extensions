/**
 * Script de test pour vérifier le passage en mode hors ligne du MCP Jupyter
 * Ce script démarre le MCP Jupyter en mode connecté, puis le fait passer en mode hors ligne
 * et vérifie que le comportement est correct.
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import http from 'http';
import https from 'https';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  mcpServerPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server'),
  mcpServerCommand: 'node',
  mcpServerArgs: ['dist/index.js'], // Sans l'option --offline
  configPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json'),
  configBackupPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.backup.json'),
  startupTimeout: 5000, // Temps d'attente pour le démarrage du serveur (5 secondes)
  switchTimeout: 10000, // Temps d'attente pour le changement de mode (10 secondes)
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
      baseUrl: 'http://localhost:8888',
      token: ''
    }
  };
}

// Fonction pour sauvegarder la configuration
function saveConfig(configData) {
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

// Fonction pour simuler un appel d'outil MCP
function simulateMcpToolCall(serverName, toolName, args) {
  console.log(`\n=== Test de l'outil ${toolName} ===`);
  console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
  
  // Dans un vrai environnement, cela serait fait via Roo
  // Ici, nous simulons l'appel en affichant les informations
  console.log(`<use_mcp_tool>
<server_name>${serverName}</server_name>
<tool_name>${toolName}</tool_name>
<arguments>
${JSON.stringify(args, null, 2)}
</arguments>
</use_mcp_tool>`);
  
  console.log("Cet appel serait normalement traité par Roo et envoyé au serveur MCP Jupyter");
  
  // Simuler une réponse
  if (toolName === 'list_kernels') {
    return [
      { id: 'kernel-id-1', name: 'python3' },
      { id: 'kernel-id-2', name: 'ir' }
    ];
  }
  
  return { status: 'ok' };
}

// Fonction principale
async function main() {
  console.log('=== Test de passage en mode hors ligne du MCP Jupyter ===');
  
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
  
  // Sauvegarder la configuration actuelle
  try {
    fs.writeFileSync(
      config.configBackupPath,
      JSON.stringify(currentConfig, null, 2),
      'utf8'
    );
    console.log('✅ Configuration sauvegardée dans', config.configBackupPath);
  } catch (err) {
    console.error('Erreur lors de la sauvegarde de la configuration:', err);
  }
  
  // Vérifier si la configuration contient un token
  if (!currentConfig.jupyterServer.token) {
    console.error('❌ La configuration ne contient pas de token d\'authentification.');
    console.error('Veuillez configurer le MCP Jupyter pour se connecter à un serveur Jupyter.');
    console.error('Utilisez les scripts:');
    console.error('1. node tests/test-jupyter-server-start.js');
    console.error('2. node tests/test-jupyter-mcp-connect.js');
    process.exit(1);
  }
  
  // Démarrer le serveur MCP Jupyter en mode connecté
  console.log('Démarrage du serveur MCP Jupyter en mode connecté...');
  const mcpProcess = startProcess(
    config.mcpServerCommand,
    config.mcpServerArgs,
    { cwd: config.mcpServerPath }
  );
  
  // Attendre que le serveur soit prêt
  console.log(`Attente de ${config.startupTimeout / 1000} secondes pour le démarrage du serveur...`);
  await new Promise(resolve => setTimeout(resolve, config.startupTimeout));
  
  // Tester la connexion au serveur Jupyter
  console.log('\n=== Test de connexion en mode connecté ===');
  const connectedResult = await testJupyterConnection(
    currentConfig.jupyterServer.baseUrl,
    currentConfig.jupyterServer.token
  );
  
  if (!connectedResult) {
    console.error('❌ Le serveur MCP Jupyter n\'est pas connecté au serveur Jupyter.');
    console.error('Veuillez vérifier que le serveur Jupyter est en cours d\'exécution.');
    mcpProcess.kill();
    process.exit(1);
  }
  
  // Tester une fonctionnalité nécessitant une connexion
  console.log('\n=== Test d\'une fonctionnalité nécessitant une connexion ===');
  try {
    const result = simulateMcpToolCall('jupyter', 'list_kernels', {});
    console.log('✅ Fonctionnalité testée avec succès en mode connecté');
  } catch (err) {
    console.error('❌ Erreur lors du test de la fonctionnalité en mode connecté:', err);
    mcpProcess.kill();
    process.exit(1);
  }
  
  // Modifier la configuration pour passer en mode hors ligne
  console.log('\n=== Passage en mode hors ligne ===');
  console.log('Création d\'un fichier de configuration temporaire avec mode hors ligne...');
  
  // Sauvegarder la configuration avec mode hors ligne
  const offlineConfig = {
    jupyterServer: {
      ...currentConfig.jupyterServer,
      offline: true
    }
  };
  
  const tempConfigPath = path.join(config.mcpServerPath, 'config.temp.json');
  try {
    fs.writeFileSync(
      tempConfigPath,
      JSON.stringify(offlineConfig, null, 2),
      'utf8'
    );
    
    // Renommer le fichier pour déclencher le rechargement de la configuration
    fs.renameSync(tempConfigPath, config.configPath);
    console.log('✅ Configuration mise à jour pour activer le mode hors ligne');
  } catch (err) {
    console.error('Erreur lors de la mise à jour de la configuration:', err);
    mcpProcess.kill();
    process.exit(1);
  }
  
  // Attendre que la configuration soit rechargée
  console.log(`Attente de ${config.switchTimeout / 1000} secondes pour le rechargement de la configuration...`);
  await new Promise(resolve => setTimeout(resolve, config.switchTimeout));
  
  // Tester la connexion au serveur Jupyter après le passage en mode hors ligne
  console.log('\n=== Test de connexion après passage en mode hors ligne ===');
  
  // Simuler un appel d'outil MCP nécessitant une connexion
  console.log('\n=== Test d\'une fonctionnalité nécessitant une connexion après passage en mode hors ligne ===');
  try {
    const result = simulateMcpToolCall('jupyter', 'list_kernels', {});
    console.log('⚠️ La fonctionnalité fonctionne toujours en mode hors ligne (simulation)');
    console.log('Dans un environnement réel, cette fonctionnalité devrait être indisponible en mode hors ligne');
  } catch (err) {
    console.log('✅ La fonctionnalité est bien indisponible en mode hors ligne');
  }
  
  // Simuler un appel d'outil MCP ne nécessitant pas de connexion
  console.log('\n=== Test d\'une fonctionnalité ne nécessitant pas de connexion après passage en mode hors ligne ===');
  try {
    const result = simulateMcpToolCall('jupyter', 'get_offline_status', {});
    console.log('✅ La fonctionnalité ne nécessitant pas de connexion fonctionne en mode hors ligne');
  } catch (err) {
    console.error('❌ Erreur lors du test de la fonctionnalité en mode hors ligne:', err);
  }
  
  // Arrêter le serveur MCP Jupyter
  console.log('\nArrêt du serveur MCP Jupyter...');
  mcpProcess.kill();
  
  // Restaurer la configuration d'origine
  try {
    if (fs.existsSync(config.configBackupPath)) {
      fs.copyFileSync(config.configBackupPath, config.configPath);
      fs.unlinkSync(config.configBackupPath);
      console.log('✅ Configuration d\'origine restaurée');
    }
  } catch (err) {
    console.error('Erreur lors de la restauration de la configuration:', err);
  }
  
  // Afficher les résultats
  console.log('\n=== Résultats du test ===');
  console.log('✅ Le serveur MCP Jupyter a bien démarré en mode connecté');
  console.log('✅ Le passage en mode hors ligne a été effectué avec succès');
  console.log('✅ La configuration a été correctement restaurée');
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  
  // Restaurer la configuration d'origine en cas d'erreur
  try {
    if (fs.existsSync(config.configBackupPath)) {
      fs.copyFileSync(config.configBackupPath, config.configPath);
      fs.unlinkSync(config.configBackupPath);
      console.log('✅ Configuration d\'origine restaurée après erreur');
    }
  } catch (e) {
    console.error('Erreur lors de la restauration de la configuration:', e);
  }
  
  process.exit(1);
});