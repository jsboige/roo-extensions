#!/usr/bin/env node
import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, 'test-temp');
const SERVER_PROCESS_PATH = path.join(__dirname, 'build', 'index.js');

// Couleurs pour la console
const COLORS = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

// Fonction pour exécuter les tests
async function runTests() {
  console.log(`${COLORS.cyan}=== Test direct de read_multiple_files ===${COLORS.reset}`);
  
  // Créer le dossier de test s'il n'existe pas
  try {
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`${COLORS.green}✓ Dossier de test créé: ${TEST_DIR}${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la création du dossier de test: ${error.message}${COLORS.reset}`);
    process.exit(1);
  }

  try {
    // Créer des fichiers de test
    const testFile1 = path.join(TEST_DIR, 'test-file1.txt');
    const testFile2 = path.join(TEST_DIR, 'test-file2.txt');
    
    await fs.writeFile(testFile1, 'Fichier 1, Ligne 1\nFichier 1, Ligne 2\nFichier 1, Ligne 3\n');
    await fs.writeFile(testFile2, 'Fichier 2, Ligne 1\nFichier 2, Ligne 2\nFichier 2, Ligne 3\n');
    
    console.log(`${COLORS.green}✓ Fichiers de test créés${COLORS.reset}`);

    // Démarrer le serveur MCP
    console.log(`${COLORS.cyan}Démarrage du serveur MCP...${COLORS.reset}`);
    const serverProcess = spawn('node', [SERVER_PROCESS_PATH], {
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    // Écouter les erreurs du serveur
    serverProcess.stderr.on('data', (data) => {
      console.log(`${COLORS.blue}[Serveur stderr]: ${data.toString()}${COLORS.reset}`);
    });

    // Attendre un peu pour que le serveur démarre
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Essayer d'appeler directement read_multiple_files
    console.log(`${COLORS.cyan}Appel direct de read_multiple_files...${COLORS.reset}`);
    
    // Méthodes à essayer pour appeler read_multiple_files
    const methods = [
      'tools/call',
      // Anciennes méthodes pour compatibilité avec les tests existants
      'call_tool',
      'mcp.call_tool',
      'callTool',
      'mcp.callTool'
    ];
    
    let success = false;
    
    for (const method of methods) {
      console.log(`${COLORS.yellow}Essai avec la méthode: ${method}${COLORS.reset}`);
      
      const request = {
        jsonrpc: '2.0',
        id: 1,
        method: method,
        params: {
          name: 'read_multiple_files',
          arguments: {
            paths: [testFile1, testFile2],
            show_line_numbers: true
          }
        }
      };
      
      console.log(`${COLORS.magenta}[Client requête]: ${JSON.stringify(request, null, 2)}${COLORS.reset}`);
      serverProcess.stdin.write(JSON.stringify(request) + '\n');
      
      // Attendre la réponse
      const response = await new Promise((resolve) => {
        serverProcess.stdout.once('data', (data) => {
          const responseStr = data.toString().trim();
          console.log(`${COLORS.blue}[Serveur réponse]: ${responseStr}${COLORS.reset}`);
          try {
            resolve(JSON.parse(responseStr));
          } catch (error) {
            console.error(`${COLORS.red}Erreur lors du parsing de la réponse: ${error.message}${COLORS.reset}`);
            resolve(null);
          }
        });
      });
      
      if (response && !response.error) {
        console.log(`${COLORS.green}✓ La méthode ${method} a fonctionné!${COLORS.reset}`);
        console.log(`${COLORS.green}✓ Contenu de la réponse: ${JSON.stringify(response.result, null, 2)}${COLORS.reset}`);
        success = true;
        break;
      } else if (response && response.error) {
        console.log(`${COLORS.red}✗ Erreur avec la méthode ${method}: ${response.error.message}${COLORS.reset}`);
      }
    }
    
    if (!success) {
      console.log(`${COLORS.red}✗ Toutes les méthodes ont échoué${COLORS.reset}`);
    }

    // Fermer le serveur
    serverProcess.stdin.end();
    serverProcess.kill();
    
    console.log(`${COLORS.green}=== Test terminé ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors du test: ${error.message}${COLORS.reset}`);
  } finally {
    // Supprimer le dossier de test
    try {
      await fs.rm(TEST_DIR, { recursive: true, force: true });
      console.log(`${COLORS.green}✓ Dossier de test supprimé${COLORS.reset}`);
    } catch (error) {
      console.error(`${COLORS.red}✗ Erreur lors de la suppression du dossier de test: ${error.message}${COLORS.reset}`);
    }
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
  process.exit(1);
});