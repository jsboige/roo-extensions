/**
 * Test de la fonctionnalité d'extraction des plans de titres markdown
 *
 * Ce script teste l'outil extract_markdown_outline du serveur JinaNavigator
 * en utilisant directement le script start-jinavigator-mcp.js pour démarrer le serveur,
 * puis en utilisant l'outil MCP via le client MCP intégré à Roo.
 */

import { execSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel en ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le script de démarrage du serveur MCP
const startScriptPath = path.join(__dirname, '../../../start-jinavigator-mcp.js');

// Fonction pour exécuter une commande et récupérer le résultat
function executeCommand(command) {
  try {
    console.log(`Exécution de la commande: ${command}`);
    const result = execSync(command, { encoding: 'utf8' });
    return result;
  } catch (error) {
    console.error(`Erreur lors de l'exécution de la commande: ${error.message}`);
    return null;
  }
}

// Fonction principale
async function main() {
  console.log('===== Test de l\'outil extract_markdown_outline =====');
  
  // Vérifier que le script de démarrage existe
  if (!fs.existsSync(startScriptPath)) {
    console.error(`Le script de démarrage n'existe pas au chemin: ${startScriptPath}`);
    process.exit(1);
  }
  
  console.log(`Script de démarrage trouvé: ${startScriptPath}`);
  
  // Créer un fichier de test pour l'outil extract_markdown_outline
  const testFilePath = path.join(__dirname, 'test-outline-data.json');
  const testData = {
    urls: [
      { url: 'https://github.com/jsboige/mcp-servers' },
      { url: 'https://en.wikipedia.org/wiki/Markdown' },
      { url: 'https://docs.github.com/en/get-started' }
    ],
    max_depth: 3
  };
  
  fs.writeFileSync(testFilePath, JSON.stringify(testData, null, 2));
  console.log(`Fichier de test créé: ${testFilePath}`);
  
  // Afficher les instructions pour tester manuellement l'outil
  console.log('\n===== Instructions pour tester l\'outil extract_markdown_outline =====');
  console.log('1. Démarrer le serveur MCP JinaNavigator avec la commande:');
  console.log(`   node ${startScriptPath}`);
  console.log('2. Dans Roo, utiliser l\'outil use_mcp_tool avec les paramètres suivants:');
  console.log('   server_name: jinavigator');
  console.log('   tool_name: extract_markdown_outline');
  console.log('   arguments: (contenu du fichier test-outline-data.json)');
  console.log('\nLe fichier test-outline-data.json contient:');
  console.log(JSON.stringify(testData, null, 2));
  
  console.log('\n===== Tests terminés =====');
}

// Exécuter la fonction principale
main().catch(error => {
  console.error('Erreur lors de l\'exécution des tests:', error);
  process.exit(1);
});