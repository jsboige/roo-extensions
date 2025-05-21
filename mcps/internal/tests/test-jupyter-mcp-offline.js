/**
 * Script de test pour vérifier le démarrage du MCP Jupyter en mode hors ligne
 * Ce script vérifie que le MCP Jupyter démarre correctement en mode hors ligne
 * et qu'aucune tentative de connexion au serveur Jupyter n'est effectuée.
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  mcpServerPath: path.join(__dirname, '..', 'servers', 'jupyter-mcp-server'),
  mcpServerCommand: 'node',
  mcpServerArgs: ['dist/index.js', '--offline'],
  testDuration: 10000, // Durée du test en millisecondes
};

// Fonction pour démarrer un processus et capturer sa sortie
function startProcess(command, args, options = {}) {
  return new Promise((resolve) => {
    console.log(`Démarrage de la commande: ${command} ${args.join(' ')}`);
    
    const proc = spawn(command, args, {
      ...options,
      stdio: 'pipe',
      shell: true
    });
    
    let stdout = '';
    let stderr = '';
    let connectionAttempts = 0;
    
    proc.stdout.on('data', (data) => {
      const output = data.toString().trim();
      stdout += output + '\n';
      console.log(`[STDOUT] ${output}`);
      
      // Vérifier si une tentative de connexion est détectée
      if (output.includes('connexion') && output.includes('Jupyter')) {
        connectionAttempts++;
      }
    });
    
    proc.stderr.on('data', (data) => {
      const output = data.toString().trim();
      stderr += output + '\n';
      console.error(`[STDERR] ${output}`);
      
      // Vérifier si une erreur de connexion est détectée
      if (output.includes('Erreur') && output.includes('connexion') && output.includes('Jupyter')) {
        connectionAttempts++;
      }
    });
    
    // Arrêter le processus après la durée de test
    setTimeout(() => {
      console.log(`Test terminé après ${config.testDuration}ms. Arrêt du processus...`);
      proc.kill();
      
      resolve({
        stdout,
        stderr,
        connectionAttempts,
        success: !stderr.includes('Erreur lors de la vérification de la version de l\'API Jupyter')
      });
    }, config.testDuration);
  });
}

// Fonction principale
async function main() {
  console.log('=== Test de démarrage du MCP Jupyter en mode hors ligne ===');
  
  // Vérifier si le serveur MCP Jupyter est compilé
  const mcpServerJsPath = path.join(config.mcpServerPath, 'dist', 'index.js');
  if (!fs.existsSync(mcpServerJsPath)) {
    console.error(`Le fichier ${mcpServerJsPath} n'existe pas.`);
    console.error('Veuillez compiler le serveur MCP Jupyter avant de lancer ce test.');
    console.error('Exécutez: cd servers/jupyter-mcp-server && npm run build');
    process.exit(1);
  }
  
  console.log('Démarrage du serveur MCP Jupyter en mode hors ligne...');
  
  // Démarrer le serveur MCP Jupyter en mode hors ligne
  const result = await startProcess(
    config.mcpServerCommand,
    config.mcpServerArgs,
    { cwd: config.mcpServerPath }
  );
  
  // Analyser les résultats
  console.log('\n=== Résultats du test ===');
  
  if (result.success) {
    console.log('✅ Le serveur MCP Jupyter a démarré avec succès en mode hors ligne');
  } else {
    console.log('❌ Le serveur MCP Jupyter a rencontré des erreurs au démarrage');
  }
  
  if (result.connectionAttempts === 0) {
    console.log('✅ Aucune tentative de connexion au serveur Jupyter n\'a été détectée');
  } else {
    console.log(`❌ ${result.connectionAttempts} tentative(s) de connexion au serveur Jupyter ont été détectées`);
  }
  
  if (result.stderr.includes('Erreur lors de la vérification de la version de l\'API Jupyter')) {
    console.log('❌ Des erreurs de connexion au serveur Jupyter ont été détectées');
  } else {
    console.log('✅ Aucune erreur de connexion au serveur Jupyter n\'a été détectée');
  }
  
  // Vérifier si le mode hors ligne est mentionné dans la sortie
  if (result.stdout.includes('Mode hors ligne activé') || result.stdout.includes('offline mode')) {
    console.log('✅ Le mode hors ligne est explicitement mentionné dans la sortie');
  } else {
    console.log('❓ Le mode hors ligne n\'est pas explicitement mentionné dans la sortie');
  }
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  process.exit(1);
});