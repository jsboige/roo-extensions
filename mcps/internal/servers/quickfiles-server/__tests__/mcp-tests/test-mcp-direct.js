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
  console.log(`${COLORS.cyan}=== Démarrage du test direct du serveur MCP quickfiles ===${COLORS.reset}`);
  
  // Créer le dossier de test s'il n'existe pas
  try {
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`${COLORS.green}✓ Dossier de test créé: ${TEST_DIR}${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la création du dossier de test: ${error.message}${COLORS.reset}`);
    process.exit(1);
  }

  try {
    // Créer un fichier de test
    const testFilePath = path.join(TEST_DIR, 'test-file.txt');
    await fs.writeFile(testFilePath, 'Ligne 1\nLigne 2\nLigne 3\nLigne 4\nLigne 5\n');
    console.log(`${COLORS.green}✓ Fichier de test créé: ${testFilePath}${COLORS.reset}`);

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

    // Envoyer une requête pour lister les outils
    console.log(`${COLORS.cyan}Envoi d'une requête pour lister les outils...${COLORS.reset}`);
    const listToolsRequest = {
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/list',
      params: {}
    };
    
    console.log(`${COLORS.magenta}[Client requête]: ${JSON.stringify(listToolsRequest, null, 2)}${COLORS.reset}`);
    serverProcess.stdin.write(JSON.stringify(listToolsRequest) + '\n');

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

    // Analyser la réponse
    if (response) {
      if (response.error) {
        console.log(`${COLORS.red}✗ Erreur lors de la requête: ${response.error.message}${COLORS.reset}`);
        
        // Essayer une autre méthode (pour compatibilité avec d'anciens tests)
        console.log(`${COLORS.cyan}Essai avec la méthode 'tools/list' (sans paramètres)...${COLORS.reset}`);
        const listToolsRequest2 = {
          jsonrpc: '2.0',
          id: 2,
          method: 'tools/list'
        };
        
        console.log(`${COLORS.magenta}[Client requête]: ${JSON.stringify(listToolsRequest2, null, 2)}${COLORS.reset}`);
        serverProcess.stdin.write(JSON.stringify(listToolsRequest2) + '\n');
        
        // Attendre la réponse
        const response2 = await new Promise((resolve) => {
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
        
        if (response2 && response2.result) {
          console.log(`${COLORS.green}✓ Outils disponibles: ${JSON.stringify(response2.result.tools)}${COLORS.reset}`);
        } else if (response2 && response2.error) {
          console.log(`${COLORS.red}✗ Erreur lors de la requête: ${response2.error.message}${COLORS.reset}`);
        }
      } else if (response.result) {
        console.log(`${COLORS.green}✓ Outils disponibles: ${JSON.stringify(response.result.tools)}${COLORS.reset}`);
      }
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