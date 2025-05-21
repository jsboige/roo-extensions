/**
 * Script de test pour démarrer un serveur Jupyter séparément
 * Ce script démarre un serveur Jupyter Notebook et vérifie qu'il est accessible
 * Il extrait également le token d'authentification pour une utilisation ultérieure
 */

import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import http from 'http';
import https from 'https';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  jupyterCommand: 'jupyter',
  jupyterArgs: ['notebook', '--no-browser'],
  startupTimeout: 15000, // Temps d'attente pour le démarrage du serveur (15 secondes)
  configPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json'),
  defaultPort: 8888,
  maxRetries: 5,
  retryInterval: 1000, // 1 seconde entre les tentatives
};

// Fonction pour extraire l'URL et le token du serveur Jupyter à partir de la sortie
function extractJupyterInfo(output) {
  // Recherche de l'URL avec token dans la sortie
  const urlMatch = output.match(/https?:\/\/[^?]+\?token=([a-zA-Z0-9]+)/);
  if (!urlMatch) return null;
  
  const fullUrl = urlMatch[0];
  const token = urlMatch[1];
  
  // Extraire l'URL de base (sans le token)
  const baseUrlMatch = fullUrl.match(/(https?:\/\/[^?]+)/);
  const baseUrl = baseUrlMatch ? baseUrlMatch[1] : null;
  
  return { baseUrl, token, fullUrl };
}

// Fonction pour vérifier si le serveur Jupyter est accessible
function checkJupyterServer(url) {
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

// Fonction pour sauvegarder la configuration
function saveConfig(baseUrl, token) {
  const config = {
    jupyterServer: {
      baseUrl,
      token
    }
  };
  
  try {
    fs.writeFileSync(
      path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json'),
      JSON.stringify(config, null, 2),
      'utf8'
    );
    return true;
  } catch (err) {
    console.error('Erreur lors de la sauvegarde de la configuration:', err);
    return false;
  }
}

// Fonction pour démarrer le serveur Jupyter
function startJupyterServer() {
  return new Promise((resolve) => {
    console.log(`Démarrage du serveur Jupyter: ${config.jupyterCommand} ${config.jupyterArgs.join(' ')}`);
    
    const proc = spawn(config.jupyterCommand, config.jupyterArgs, {
      stdio: 'pipe',
      shell: true
    });
    
    let stdout = '';
    let stderr = '';
    let jupyterInfo = null;
    
    proc.stdout.on('data', (data) => {
      const output = data.toString();
      stdout += output;
      console.log(`[JUPYTER] ${output.trim()}`);
      
      // Essayer d'extraire les informations du serveur Jupyter
      if (!jupyterInfo) {
        jupyterInfo = extractJupyterInfo(stdout);
        if (jupyterInfo) {
          console.log('\n=== Informations du serveur Jupyter ===');
          console.log(`URL de base: ${jupyterInfo.baseUrl}`);
          console.log(`Token: ${jupyterInfo.token}`);
          console.log(`URL complète: ${jupyterInfo.fullUrl}`);
          console.log('=======================================\n');
        }
      }
    });
    
    proc.stderr.on('data', (data) => {
      const output = data.toString();
      stderr += output;
      console.error(`[JUPYTER ERROR] ${output.trim()}`);
    });
    
    proc.on('error', (err) => {
      console.error('Erreur lors du démarrage du serveur Jupyter:', err);
      resolve({ success: false, error: err, proc: null });
    });
    
    // Attendre que le serveur soit prêt
    setTimeout(async () => {
      if (!jupyterInfo) {
        console.error('Impossible d\'extraire les informations du serveur Jupyter de la sortie.');
        resolve({ success: false, error: 'Informations non trouvées', proc });
        return;
      }
      
      // Vérifier si le serveur est accessible
      let serverAccessible = false;
      let retries = 0;
      
      while (!serverAccessible && retries < config.maxRetries) {
        console.log(`Tentative de connexion au serveur Jupyter (${retries + 1}/${config.maxRetries})...`);
        
        const checkResult = await checkJupyterServer(`${jupyterInfo.baseUrl}/api/kernels?token=${jupyterInfo.token}`);
        
        if (checkResult.success) {
          serverAccessible = true;
          console.log('✅ Le serveur Jupyter est accessible');
        } else {
          console.log(`❌ Le serveur Jupyter n'est pas encore accessible: ${checkResult.error || `Code ${checkResult.statusCode}`}`);
          retries++;
          
          if (retries < config.maxRetries) {
            console.log(`Nouvelle tentative dans ${config.retryInterval / 1000} seconde(s)...`);
            await new Promise(r => setTimeout(r, config.retryInterval));
          }
        }
      }
      
      // Sauvegarder la configuration si le serveur est accessible
      if (serverAccessible) {
        const configSaved = saveConfig(jupyterInfo.baseUrl, jupyterInfo.token);
        if (configSaved) {
          console.log('✅ Configuration sauvegardée avec succès');
        } else {
          console.log('❌ Échec de la sauvegarde de la configuration');
        }
      }
      
      resolve({
        success: serverAccessible,
        jupyterInfo,
        proc,
        stdout,
        stderr
      });
    }, config.startupTimeout);
  });
}

// Fonction principale
async function main() {
  console.log('=== Test de démarrage du serveur Jupyter ===');
  
  // Vérifier si Jupyter est installé
  try {
    const { execSync } = await import('child_process');
    execSync(`${config.jupyterCommand} --version`, { stdio: 'pipe' });
  } catch (err) {
    console.error(`❌ ${config.jupyterCommand} n'est pas installé ou n'est pas dans le PATH.`);
    console.error('Veuillez installer Jupyter avec: pip install jupyter');
    process.exit(1);
  }
  
  // Démarrer le serveur Jupyter
  const result = await startJupyterServer();
  
  if (result.success) {
    console.log('\n=== Résultats du test ===');
    console.log('✅ Le serveur Jupyter a démarré avec succès');
    console.log(`✅ Le serveur est accessible à l'adresse: ${result.jupyterInfo.baseUrl}`);
    console.log(`✅ Token d'authentification: ${result.jupyterInfo.token}`);
    console.log('\nPour arrêter le serveur Jupyter, appuyez sur Ctrl+C dans ce terminal');
    console.log('\nPour connecter le MCP Jupyter à ce serveur, utilisez:');
    console.log('node tests/test-jupyter-mcp-connect.js');
    
    // Garder le processus en vie pour que le serveur continue à fonctionner
    console.log('\nServeur Jupyter en cours d\'exécution...');
    
    // Gérer l'arrêt propre du serveur
    process.on('SIGINT', () => {
      console.log('\nArrêt du serveur Jupyter...');
      if (result.proc) {
        result.proc.kill();
      }
      process.exit(0);
    });
  } else {
    console.log('\n=== Résultats du test ===');
    console.log('❌ Le serveur Jupyter n\'a pas pu démarrer correctement');
    
    if (result.error) {
      console.error('Erreur:', result.error);
    }
    
    process.exit(1);
  }
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  process.exit(1);
});