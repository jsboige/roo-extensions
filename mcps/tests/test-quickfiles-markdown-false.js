#!/usr/bin/env node
/**
 * Script de test pour la fonctionnalité d'extraction de structure markdown du MCP QuickFiles
 * Ce script teste le comportement par défaut quand extract_markdown_structure est false
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, 'temp-quickfiles-markdown-test-false');
// Chemin vers le serveur QuickFiles
const QUICKFILES_DIR = path.join(__dirname, '..', 'mcp-servers', 'servers', 'quickfiles-server');

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
  console.log(`${COLORS.cyan}=== Test du comportement par défaut (extract_markdown_structure=false) ===${COLORS.reset}`);
  
  let serverProcess = null;
  
  try {
    // Créer le dossier de test
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`${COLORS.green}✓ Dossier de test créé: ${TEST_DIR}${COLORS.reset}`);
    
    // Créer une structure de test
    await createTestStructure();
    
    // Démarrer le serveur QuickFiles
    console.log(`\n${COLORS.blue}Démarrage du serveur QuickFiles${COLORS.reset}`);
    serverProcess = await startServer();
    
    if (!serverProcess) {
      console.log(`${COLORS.red}✗ Impossible de démarrer le serveur QuickFiles${COLORS.reset}`);
      return;
    }
    
    console.log(`${COLORS.green}✓ Serveur QuickFiles démarré${COLORS.reset}`);
    
    // Attendre que le serveur soit prêt
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Tester le comportement par défaut (extract_markdown_structure=false)
    console.log(`\n${COLORS.blue}Test du comportement par défaut (extract_markdown_structure=false)${COLORS.reset}`);
    
    // Simuler l'appel à l'outil list_directory_contents avec extract_markdown_structure=false
    const request = {
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [TEST_DIR],
          extract_markdown_structure: false
        }
      }
    };
    
    console.log(`${COLORS.magenta}Envoi de la requête:${COLORS.reset}`);
    console.log(JSON.stringify(request, null, 2));
    
    serverProcess.stdin.write(JSON.stringify(request) + '\n');
    
    // Attendre la réponse
    const response = await new Promise((resolve) => {
      serverProcess.stdout.once('data', (data) => {
        const responseStr = data.toString().trim();
        try {
          resolve(JSON.parse(responseStr));
        } catch (error) {
          console.error(`${COLORS.red}Erreur lors du parsing de la réponse: ${error.message}${COLORS.reset}`);
          resolve(null);
        }
      });
    });
    
    if (response && !response.error) {
      console.log(`${COLORS.green}✓ Réponse reçue avec succès${COLORS.reset}`);
      
      // Vérifier que la réponse contient du markdown
      const content = response.result.content[0].text;
      
      // Sauvegarder la réponse dans un fichier pour inspection
      const outputPath = path.join(TEST_DIR, 'markdown-output-false.md');
      await fs.writeFile(outputPath, content);
      console.log(`${COLORS.green}✓ Résultat sauvegardé dans: ${outputPath}${COLORS.reset}`);
      
      // Vérifier que le contenu contient des informations sur les fichiers et répertoires
      if (content.includes('📁') && content.includes('📄')) {
        console.log(`${COLORS.green}✓ Le contenu contient des informations sur les fichiers et répertoires${COLORS.reset}`);
        
        // Vérifier si les fichiers markdown sont présents
        if (content.includes('.md')) {
          console.log(`${COLORS.green}✓ Des fichiers markdown sont présents dans la structure${COLORS.reset}`);
          
          // Vérifier que les titres des fichiers markdown ne sont PAS extraits
          if (!content.includes('📑') && !content.includes('📌')) {
            console.log(`${COLORS.green}✓ Les titres des fichiers markdown ne sont PAS extraits (comportement attendu)${COLORS.reset}`);
          } else {
            console.log(`${COLORS.red}✗ Les titres des fichiers markdown sont extraits alors qu'ils ne devraient pas l'être${COLORS.reset}`);
          }
        } else {
          console.log(`${COLORS.yellow}⚠ Aucun fichier markdown n'a été trouvé${COLORS.reset}`);
        }
      } else {
        console.log(`${COLORS.red}✗ Le contenu ne contient pas d'informations sur les fichiers et répertoires${COLORS.reset}`);
      }
      
      console.log(`\n${COLORS.yellow}Aperçu du résultat:${COLORS.reset}`);
      console.log(content.substring(0, 500) + (content.length > 500 ? '...' : ''));
    } else if (response && response.error) {
      console.log(`${COLORS.red}✗ Erreur dans la réponse: ${response.error.message}${COLORS.reset}`);
    } else {
      console.log(`${COLORS.red}✗ Aucune réponse reçue${COLORS.reset}`);
    }
    
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors des tests: ${error.message}${COLORS.reset}`);
  } finally {
    // Arrêter le serveur s'il est en cours d'exécution
    if (serverProcess) {
      try {
        process.kill(serverProcess.pid);
        console.log(`${COLORS.green}✓ Serveur QuickFiles arrêté${COLORS.reset}`);
      } catch (error) {
        console.error(`${COLORS.red}✗ Erreur lors de l'arrêt du serveur: ${error.message}${COLORS.reset}`);
      }
    }
    
    // Supprimer le dossier de test
    try {
      await fs.rm(TEST_DIR, { recursive: true, force: true });
      console.log(`${COLORS.green}✓ Dossier de test supprimé${COLORS.reset}`);
    } catch (error) {
      console.error(`${COLORS.red}✗ Erreur lors de la suppression du dossier de test: ${error.message}${COLORS.reset}`);
    }
  }
}

// Fonction pour créer une structure de test
async function createTestStructure() {
  console.log(`${COLORS.blue}Création d'une structure de test${COLORS.reset}`);
  
  // Créer quelques fichiers à la racine
  await fs.writeFile(path.join(TEST_DIR, 'README.md'), '# Test Project\n\nThis is a test project for QuickFiles markdown extraction.');
  await fs.writeFile(path.join(TEST_DIR, 'config.json'), '{\n  "name": "test-project",\n  "version": "1.0.0"\n}');
  
  // Créer un sous-dossier src avec des fichiers
  await fs.mkdir(path.join(TEST_DIR, 'src'), { recursive: true });
  await fs.writeFile(path.join(TEST_DIR, 'src', 'index.js'), 'console.log("Hello, world!");');
  await fs.writeFile(path.join(TEST_DIR, 'src', 'utils.js'), 'function add(a, b) { return a + b; }');
  
  // Créer un sous-dossier docs avec des fichiers markdown
  await fs.mkdir(path.join(TEST_DIR, 'docs'), { recursive: true });
  await fs.writeFile(path.join(TEST_DIR, 'docs', 'guide.md'), '# User Guide\n\nThis is a user guide.');
  await fs.writeFile(path.join(TEST_DIR, 'docs', 'api.md'), '# API Reference\n\nThis is an API reference.');
  
  // Créer un sous-dossier tests avec des fichiers de test
  await fs.mkdir(path.join(TEST_DIR, 'tests'), { recursive: true });
  await fs.writeFile(path.join(TEST_DIR, 'tests', 'index.test.js'), 'test("it works", () => { expect(true).toBe(true); });');
  
  // Créer un sous-dossier imbriqué
  await fs.mkdir(path.join(TEST_DIR, 'src', 'components'), { recursive: true });
  await fs.writeFile(path.join(TEST_DIR, 'src', 'components', 'Button.js'), 'function Button() { return <button>Click me</button>; }');
  await fs.writeFile(path.join(TEST_DIR, 'src', 'components', 'Input.js'), 'function Input() { return <input type="text" />; }');
  
  console.log(`${COLORS.green}✓ Structure de test créée${COLORS.reset}`);
}

// Fonction pour démarrer le serveur QuickFiles
async function startServer() {
  try {
    // Démarrer le serveur
    const serverProcess = spawn('node', [path.join(QUICKFILES_DIR, 'build', 'index.js')], {
      stdio: ['pipe', 'pipe', 'pipe']
    });
    
    // Écouter les erreurs du serveur
    serverProcess.stderr.on('data', (data) => {
      console.log(`${COLORS.yellow}[Serveur stderr]: ${data.toString().trim()}${COLORS.reset}`);
    });
    
    // Attendre que le serveur soit prêt
    return new Promise((resolve) => {
      serverProcess.stdout.on('data', (data) => {
        console.log(`${COLORS.yellow}[Serveur stdout]: ${data.toString().trim()}${COLORS.reset}`);
        if (data.toString().includes('QuickFiles MCP server running')) {
          resolve(serverProcess);
        }
      });
      
      // Résoudre après un délai si le message "Server running" n'est pas détecté
      setTimeout(() => {
        resolve(serverProcess);
      }, 5000);
      
      serverProcess.on('error', (error) => {
        console.error(`${COLORS.red}✗ Erreur lors du démarrage du serveur: ${error.message}${COLORS.reset}`);
        resolve(null);
      });
    });
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors du démarrage du serveur: ${error.message}${COLORS.reset}`);
    return null;
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
  process.exit(1);
});