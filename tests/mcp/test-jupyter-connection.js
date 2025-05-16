/**
 * Script de test pour vérifier la connexion au serveur MCP Jupyter
 */

import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Fonction pour exécuter une commande et capturer sa sortie
function executeCommand(command, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, { shell: true });
    let stdout = '';
    let stderr = '';
    
    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    
    proc.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
    
    proc.on('error', (err) => {
      reject(err);
    });
  });
}

// Fonction pour tester la connexion au serveur Jupyter avec le token
async function testJupyterConnection() {
  try {
    // Lire la configuration
    const configPath = path.join(__dirname, '..', 'servers', 'jupyter-mcp-server', 'config.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    
    // Construire l'URL avec le token
    const url = `${config.jupyterServer.baseUrl}/api/kernels?token=${config.jupyterServer.token}`;
    
    console.log(`Tentative de connexion à ${url}...`);
    
    // Tester la connexion avec curl
    const result = await executeCommand('curl', ['-s', url]);
    console.log('Résultat de la requête:');
    console.log(result.stdout);
    
    // Vérifier si la réponse est un tableau JSON valide
    try {
      const response = JSON.parse(result.stdout);
      return Array.isArray(response);
    } catch (e) {
      console.error('Erreur lors de l\'analyse de la réponse JSON:', e);
      return false;
    }
  } catch (error) {
    console.error('Erreur lors du test de connexion:', error);
    return false;
  }
}

// Fonction principale
async function main() {
  console.log('=== Test de connexion au serveur Jupyter avec token ===');
  
  const success = await testJupyterConnection();
  
  if (success) {
    console.log('✅ Connexion réussie au serveur Jupyter avec le token');
  } else {
    console.log('❌ Échec de la connexion au serveur Jupyter avec le token');
  }
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(console.error);