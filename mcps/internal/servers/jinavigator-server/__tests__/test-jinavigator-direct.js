/**
 * Script de test direct pour le serveur jinavigator
 * Ce script teste les fonctionnalités du serveur jinavigator en communiquant directement avec lui
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
      stdout += data.toString();
    });

    // Capturer la sortie d'erreur
    process.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // Gérer la fin du processus
    process.on('close', (code) => {
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
      method: 'mcp.callTool',
      params: {
        name: 'convert_web_to_markdown',
        arguments: {
          url: 'https://en.wikipedia.org/wiki/Markdown'
        }
      },
      id: 1
    };
    
    // Exécuter la requête
    const result = await executeCommand('node', ['servers/jinavigator-server/dist/index.js'], JSON.stringify(request));
    
    // Analyser la réponse
    console.log('Réponse du serveur:');
    console.log(result.stdout);
    
    return result.stdout;
  } catch (error) {
    console.error('Erreur lors du test de convert_web_to_markdown:', error);
    return null;
  }
}

// Fonction pour tester l'outil access_jina_resource
async function testAccessJinaResource() {
  console.log('\n=== Test de l\'outil access_jina_resource ===');
  
  try {
    // Préparer la requête MCP
    const request = {
      jsonrpc: '2.0',
      method: 'mcp.callTool',
      params: {
        name: 'access_jina_resource',
        arguments: {
          uri: 'jina://https://en.wikipedia.org/wiki/Markdown'
        }
      },
      id: 2
    };
    
    // Exécuter la requête
    const result = await executeCommand('node', ['servers/jinavigator-server/dist/index.js'], JSON.stringify(request));
    
    // Analyser la réponse
    console.log('Réponse du serveur:');
    console.log(result.stdout);
    
    return result.stdout;
  } catch (error) {
    console.error('Erreur lors du test de access_jina_resource:', error);
    return null;
  }
}

// Fonction pour tester l'outil multi_convert
async function testMultiConvert() {
  console.log('\n=== Test de l\'outil multi_convert ===');
  
  try {
    // Préparer la requête MCP
    const request = {
      jsonrpc: '2.0',
      method: 'mcp.callTool',
      params: {
        name: 'multi_convert',
        arguments: {
          urls: [
            { url: 'https://en.wikipedia.org/wiki/JavaScript', start_line: 5, end_line: 15 },
            { url: 'https://en.wikipedia.org/wiki/TypeScript', start_line: 20, end_line: 30 }
          ]
        }
      },
      id: 3
    };
    
    // Exécuter la requête
    const result = await executeCommand('node', ['servers/jinavigator-server/dist/index.js'], JSON.stringify(request));
    
    // Analyser la réponse
    console.log('Réponse du serveur:');
    console.log(result.stdout);
    
    return result.stdout;
  } catch (error) {
    console.error('Erreur lors du test de multi_convert:', error);
    return null;
  }
}

// Fonction principale pour exécuter tous les tests
async function runAllTests() {
  try {
    // Tester l'outil convert_web_to_markdown
    const convertResult = await testConvertWebToMarkdown();
    
    // Tester l'outil access_jina_resource
    const accessResult = await testAccessJinaResource();
    
    // Tester l'outil multi_convert
    const multiResult = await testMultiConvert();
    
    // Afficher le résumé des tests
    console.log('\n=== Résumé des tests ===');
    console.log('convert_web_to_markdown:', convertResult ? 'Succès' : 'Échec');
    console.log('access_jina_resource:', accessResult ? 'Succès' : 'Échec');
    console.log('multi_convert:', multiResult ? 'Succès' : 'Échec');
  } catch (error) {
    console.error('Erreur lors de l\'exécution des tests:', error);
  }
}

// Exécuter tous les tests
runAllTests();