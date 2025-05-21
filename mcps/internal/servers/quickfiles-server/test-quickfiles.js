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

// Fonction pour créer un client MCP qui communique avec le serveur via stdio
class McpClient {
  constructor(serverProcess) {
    this.serverProcess = serverProcess;
    this.requestId = 1;
    this.pendingRequests = new Map();

    // Écouter les données du serveur
    this.serverProcess.stdout.on('data', (data) => {
      const rawData = data.toString();
      console.log(`${COLORS.blue}[Serveur stdout raw]: ${rawData}${COLORS.reset}`);
      
      const messages = rawData.split('\n').filter(Boolean);
      for (const message of messages) {
        try {
          console.log(`${COLORS.blue}[Serveur message]: ${message}${COLORS.reset}`);
          const response = JSON.parse(message);
          console.log(`${COLORS.blue}[Serveur parsed]: ${JSON.stringify(response, null, 2)}${COLORS.reset}`);
          
          if (response.id && this.pendingRequests.has(response.id)) {
            const { resolve, reject } = this.pendingRequests.get(response.id);
            this.pendingRequests.delete(response.id);
            
            if (response.error) {
              console.log(`${COLORS.red}[Erreur serveur]: ${JSON.stringify(response.error, null, 2)}${COLORS.reset}`);
              reject(new Error(response.error.message));
            } else {
              resolve(response.result);
            }
          }
        } catch (error) {
          console.error(`${COLORS.red}Erreur lors du parsing de la réponse: ${error.message}${COLORS.reset}`);
        }
      }
    });

    // Gérer les erreurs du processus serveur
    this.serverProcess.stderr.on('data', (data) => {
      console.error(`[Serveur stderr]: ${data.toString()}`);
    });

    this.serverProcess.on('close', (code) => {
      console.log(`Le processus serveur s'est terminé avec le code ${code}`);
    });
  }

  // Envoyer une requête au serveur
  async sendRequest(method, params) {
    return new Promise((resolve, reject) => {
      const id = this.requestId++;
      const request = {
        jsonrpc: '2.0',
        id,
        method,
        params,
      };

      console.log(`${COLORS.magenta}[Client requête]: ${JSON.stringify(request, null, 2)}${COLORS.reset}`);
      this.pendingRequests.set(id, { resolve, reject });
      this.serverProcess.stdin.write(JSON.stringify(request) + '\n');
    });
  }

  // Essayer différentes méthodes pour trouver celle qui fonctionne
  async tryMethods() {
    const methods = [
      'tools/list',  // Méthode correcte selon le standard MCP
      'list_tools',
      'mcp.list_tools',
      'mcp.listTools',
      'listTools',
      'ListTools',
      'list-tools',
      'tools.list'
    ];
    
    for (const method of methods) {
      console.log(`${COLORS.cyan}Essai de la méthode: ${method}${COLORS.reset}`);
      try {
        const result = await this.sendRequest(method, {});
        console.log(`${COLORS.green}✓ Méthode ${method} a fonctionné!${COLORS.reset}`);
        return result;
      } catch (error) {
        console.log(`${COLORS.red}✗ Méthode ${method} a échoué: ${error.message}${COLORS.reset}`);
      }
    }
    
    throw new Error("Aucune méthode n'a fonctionné");
  }

  // Lister les outils disponibles (utilise la méthode qui fonctionne)
  async listTools() {
    return this.tryMethods();
  }

  // Appeler un outil
  async callTool(name, args) {
    const methods = [
      'tools/call',  // Méthode correcte selon le standard MCP
      'call_tool',
      'mcp.call_tool',
      'mcp.callTool',
      'callTool',
      'CallTool',
      'call-tool',
      'tools.call'
    ];
    
    for (const method of methods) {
      console.log(`${COLORS.cyan}Essai de la méthode: ${method}${COLORS.reset}`);
      try {
        const result = await this.sendRequest(method, {
          name,
          arguments: args,
        });
        console.log(`${COLORS.green}✓ Méthode ${method} a fonctionné!${COLORS.reset}`);
        return result;
      } catch (error) {
        console.log(`${COLORS.red}✗ Méthode ${method} a échoué: ${error.message}${COLORS.reset}`);
      }
    }
    
    throw new Error("Aucune méthode n'a fonctionné pour appeler l'outil");
  }

  // Fermer le client
  close() {
    this.serverProcess.stdin.end();
  }
}

// Fonction pour exécuter les tests
async function runTests() {
  console.log(`${COLORS.cyan}=== Démarrage des tests du serveur MCP quickfiles ===${COLORS.reset}`);
  
  // Créer le dossier de test s'il n'existe pas
  try {
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`${COLORS.green}✓ Dossier de test créé: ${TEST_DIR}${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la création du dossier de test: ${error.message}${COLORS.reset}`);
    process.exit(1);
  }

  // Créer des fichiers de test
  try {
    // Fichier avec beaucoup de lignes pour tester max_lines_per_file
    let bigFileContent = '';
    for (let i = 1; i <= 3000; i++) {
      bigFileContent += `Ligne ${i} du fichier de test\n`;
    }
    await fs.writeFile(path.join(TEST_DIR, 'big-file.txt'), bigFileContent);
    console.log(`${COLORS.green}✓ Fichier de test 'big-file.txt' créé avec 3000 lignes${COLORS.reset}`);

    // Fichier pour tester edit_multiple_files
    await fs.writeFile(path.join(TEST_DIR, 'edit-test.txt'), 'Ligne 1 à modifier\nLigne 2 à conserver\nLigne 3 à modifier\n');
    console.log(`${COLORS.green}✓ Fichier de test 'edit-test.txt' créé${COLORS.reset}`);

    // Fichier pour tester delete_files
    await fs.writeFile(path.join(TEST_DIR, 'delete-test.txt'), 'Ce fichier sera supprimé\n');
    console.log(`${COLORS.green}✓ Fichier de test 'delete-test.txt' créé${COLORS.reset}`);

    // Créer un sous-dossier avec des fichiers pour tester list_directory_contents
    await fs.mkdir(path.join(TEST_DIR, 'subdir'), { recursive: true });
    await fs.writeFile(path.join(TEST_DIR, 'subdir', 'file1.txt'), 'Contenu du fichier 1\n');
    await fs.writeFile(path.join(TEST_DIR, 'subdir', 'file2.txt'), 'Contenu du fichier 2\n');
    console.log(`${COLORS.green}✓ Sous-dossier 'subdir' et fichiers créés${COLORS.reset}`);

    // Créer plusieurs fichiers pour tester read_multiple_files
    for (let i = 1; i <= 5; i++) {
      let content = '';
      for (let j = 1; j <= 100; j++) {
        content += `Fichier ${i}, Ligne ${j}\n`;
      }
      await fs.writeFile(path.join(TEST_DIR, `file${i}.txt`), content);
    }
    console.log(`${COLORS.green}✓ 5 fichiers de test créés avec 100 lignes chacun${COLORS.reset}`);

  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la création des fichiers de test: ${error.message}${COLORS.reset}`);
    process.exit(1);
  }

  // Démarrer le serveur MCP
  console.log(`${COLORS.cyan}Démarrage du serveur MCP...${COLORS.reset}`);
  const serverProcess = spawn('node', [SERVER_PROCESS_PATH], {
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  // Créer un client MCP
  const client = new McpClient(serverProcess);

  try {
    // Attendre un peu pour que le serveur démarre
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Lister les outils disponibles
    console.log(`${COLORS.cyan}Test: Lister les outils disponibles${COLORS.reset}`);
    const toolsResponse = await client.listTools();
    console.log(`${COLORS.green}✓ Outils disponibles: ${toolsResponse.tools.map(t => t.name).join(', ')}${COLORS.reset}`);

    // Test 1: list_directory_contents avec max_lines
    console.log(`\n${COLORS.cyan}Test 1: list_directory_contents avec max_lines${COLORS.reset}`);
    const listDirResponse = await client.callTool('list_directory_contents', {
      paths: [{ path: TEST_DIR, recursive: true }],
      max_lines: 10
    });
    
    const listDirContent = listDirResponse.content[0].text;
    console.log(`${COLORS.yellow}Résultat (tronqué):${COLORS.reset}`);
    console.log(listDirContent.substring(0, 200) + '...');
    
    if (listDirContent.includes('lignes supplémentaires non affichées')) {
      console.log(`${COLORS.green}✓ Le paramètre max_lines fonctionne correctement${COLORS.reset}`);
    } else {
      console.log(`${COLORS.red}✗ Le paramètre max_lines ne semble pas fonctionner${COLORS.reset}`);
    }

    // Test 2: read_multiple_files avec max_lines_per_file
    console.log(`\n${COLORS.cyan}Test 2: read_multiple_files avec max_lines_per_file${COLORS.reset}`);
    const readFilesResponse1 = await client.callTool('read_multiple_files', {
      paths: [path.join(TEST_DIR, 'big-file.txt')],
      max_lines_per_file: 50
    });
    
    const readFilesContent1 = readFilesResponse1.content[0].text;
    console.log(`${COLORS.yellow}Résultat (tronqué):${COLORS.reset}`);
    console.log(readFilesContent1.substring(0, 200) + '...');
    
    if (readFilesContent1.includes('lignes supplémentaires non affichées')) {
      console.log(`${COLORS.green}✓ Le paramètre max_lines_per_file fonctionne correctement${COLORS.reset}`);
    } else {
      console.log(`${COLORS.red}✗ Le paramètre max_lines_per_file ne semble pas fonctionner${COLORS.reset}`);
    }

    // Test 3: read_multiple_files avec max_total_lines
    console.log(`\n${COLORS.cyan}Test 3: read_multiple_files avec max_total_lines${COLORS.reset}`);
    const filePaths = [];
    for (let i = 1; i <= 5; i++) {
      filePaths.push(path.join(TEST_DIR, `file${i}.txt`));
    }
    
    const readFilesResponse2 = await client.callTool('read_multiple_files', {
      paths: filePaths,
      max_total_lines: 200
    });
    
    const readFilesContent2 = readFilesResponse2.content[0].text;
    console.log(`${COLORS.yellow}Résultat (tronqué):${COLORS.reset}`);
    console.log(readFilesContent2.substring(0, 200) + '...');
    
    if (readFilesContent2.includes('lignes supplémentaires non affichées') && 
        readFilesContent2.includes('Certains fichiers ont été tronqués')) {
      console.log(`${COLORS.green}✓ Le paramètre max_total_lines fonctionne correctement${COLORS.reset}`);
    } else {
      console.log(`${COLORS.red}✗ Le paramètre max_total_lines ne semble pas fonctionner${COLORS.reset}`);
    }

    // Test 4: edit_multiple_files
    console.log(`\n${COLORS.cyan}Test 4: edit_multiple_files${COLORS.reset}`);
    const editResponse = await client.callTool('edit_multiple_files', {
      files: [
        {
          path: path.join(TEST_DIR, 'edit-test.txt'),
          diffs: [
            {
              search: 'Ligne 1 à modifier',
              replace: 'Ligne 1 modifiée'
            },
            {
              search: 'Ligne 3 à modifier',
              replace: 'Ligne 3 modifiée'
            }
          ]
        }
      ]
    });
    
    console.log(`${COLORS.yellow}Résultat:${COLORS.reset}`);
    console.log(editResponse.content[0].text);
    
    // Vérifier que le fichier a été modifié
    const editedContent = await fs.readFile(path.join(TEST_DIR, 'edit-test.txt'), 'utf-8');
    console.log(`${COLORS.yellow}Contenu du fichier après édition:${COLORS.reset}`);
    console.log(editedContent);
    
    if (editedContent.includes('Ligne 1 modifiée') && editedContent.includes('Ligne 3 modifiée')) {
      console.log(`${COLORS.green}✓ La méthode edit_multiple_files fonctionne correctement${COLORS.reset}`);
    } else {
      console.log(`${COLORS.red}✗ La méthode edit_multiple_files ne fonctionne pas correctement${COLORS.reset}`);
    }

    // Test 5: delete_files
    console.log(`\n${COLORS.cyan}Test 5: delete_files${COLORS.reset}`);
    const deleteResponse = await client.callTool('delete_files', {
      paths: [path.join(TEST_DIR, 'delete-test.txt')]
    });
    
    console.log(`${COLORS.yellow}Résultat:${COLORS.reset}`);
    console.log(deleteResponse.content[0].text);
    
    // Vérifier que le fichier a été supprimé
    try {
      await fs.access(path.join(TEST_DIR, 'delete-test.txt'));
      console.log(`${COLORS.red}✗ Le fichier n'a pas été supprimé${COLORS.reset}`);
    } catch (error) {
      console.log(`${COLORS.green}✓ La méthode delete_files fonctionne correctement${COLORS.reset}`);
    }

    console.log(`\n${COLORS.green}=== Tous les tests sont terminés ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors des tests: ${error.message}${COLORS.reset}`);
  } finally {
    // Fermer le client et nettoyer
    client.close();
    
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