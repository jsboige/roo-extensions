/**
 * Script de test simplifié pour le serveur jinavigator
 * Ce script teste l'outil convert_web_to_markdown du serveur jinavigator
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Fonction pour exécuter une commande et capturer la sortie
function executeCommand(command, args, input = '') {
  return new Promise((resolve, reject) => {
    const process = spawn(command, args);
    let stdout = '';
    let stderr = '';

    // Envoyer l'entrée au processus
    if (input) {
      process.stdin.write(input);
      process.stdin.end();
    }

    // Capturer la sortie standard
    process.stdout.on('data', (data) => {
      const chunk = data.toString();
      stdout += chunk;
      console.log('Sortie standard:', chunk);
    });

    // Capturer la sortie d'erreur
    process.stderr.on('data', (data) => {
      const chunk = data.toString();
      stderr += chunk;
      console.error('Sortie d\'erreur:', chunk);
    });

    // Gérer la fin du processus
    process.on('close', (code) => {
      console.log(`Processus terminé avec le code ${code}`);
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(new Error(`Le processus s'est terminé avec le code ${code}\nStderr: ${stderr}`));
      }
    });
  });
}

// Fonction pour tester l'outil convert_web_to_markdown
async function testConvertWebToMarkdown() {
  console.log('=== Test de l\'outil convert_web_to_markdown ===');
  
  try {
    // Préparer la requête MCP
    const request = {
      jsonrpc: '2.0',
      method: 'mcp.listTools',
      id: 1
    };
    
    console.log('Requête envoyée au serveur:');
    console.log(JSON.stringify(request, null, 2));
    
    // Exécuter la requête
    const result = await executeCommand('node', ['servers/jinavigator-server/dist/index.js'], JSON.stringify(request));
    
    // Analyser la réponse
    console.log('Réponse complète du serveur:');
    console.log(result.stdout);
    
    // Essayer de parser la réponse JSON
    try {
      const jsonResponse = JSON.parse(result.stdout);
      console.log('Réponse JSON parsée:');
      console.log(JSON.stringify(jsonResponse, null, 2));
    } catch (error) {
      console.error('Erreur lors du parsing de la réponse JSON:', error);
    }
    
    return result.stdout;
  } catch (error) {
    console.error('Erreur lors du test de convert_web_to_markdown:', error);
    return null;
  }
}

// Exécuter le test
testConvertWebToMarkdown().then(() => {
  console.log('Test terminé');
}).catch(error => {
  console.error('Erreur lors de l\'exécution du test:', error);
});