import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs/promises';

// Couleurs pour la console
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  underscore: '\x1b[4m',
  blink: '\x1b[5m',
  reverse: '\x1b[7m',
  hidden: '\x1b[8m',
  
  black: '\x1b[30m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
};

// Fonction pour exécuter une commande et capturer la sortie
async function executeCommand(command, args, input = null) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args);
    
    let stdout = '';
    let stderr = '';
    
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stderr.on('data', (data) => {
      stderr += data.toString();
      console.log(`${colors.red}[Serveur stderr]: ${data.toString().trim()}${colors.reset}`);
    });
    
    child.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(new Error(`La commande a échoué avec le code ${code}`));
      }
    });
    
    if (input) {
      child.stdin.write(input);
      child.stdin.end();
    }
  });
}

// Fonction pour démarrer le serveur MCP
async function startMcpServer() {
  const serverProcess = spawn('node', ['servers/quickfiles-server/build/index.js']);
  
  serverProcess.stderr.on('data', (data) => {
    console.log(`${colors.red}[Serveur stderr]: ${data.toString().trim()}${colors.reset}`);
  });
  
  serverProcess.stdout.on('data', (data) => {
    console.log(`${colors.blue}[Serveur stdout]: ${data.toString().trim()}${colors.reset}`);
  });
  
  // Attendre un peu pour que le serveur démarre
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  return serverProcess;
}

// Fonction pour envoyer une requête au serveur MCP
async function sendMcpRequest(request) {
  console.log(`${colors.magenta}[Client requête]: ${JSON.stringify(request, null, 2)}${colors.reset}`);
  
  try {
    const { stdout } = await executeCommand('node', ['servers/quickfiles-server/build/index.js'], JSON.stringify(request) + '\n');
    
    try {
      const response = JSON.parse(stdout);
      console.log(`${colors.green}[Client réponse]: ${JSON.stringify(response, null, 2)}${colors.reset}`);
      return response;
    } catch (error) {
      console.log(`${colors.red}Erreur lors de l'analyse de la réponse: ${error.message}${colors.reset}`);
      console.log(`${colors.yellow}Réponse brute: ${stdout}${colors.reset}`);
      throw error;
    }
  } catch (error) {
    console.log(`${colors.red}Erreur lors de l'envoi de la requête: ${error.message}${colors.reset}`);
    throw error;
  }
}

// Fonction pour créer un environnement de test
async function setupTestEnvironment() {
  console.log(`${colors.cyan}=== Préparation de l'environnement de test ===${colors.reset}`);
  
  // Créer un dossier de test
  const testDir = path.join(process.cwd(), 'test-sort');
  
  try {
    await fs.access(testDir);
    // Si le dossier existe, le supprimer
    await fs.rm(testDir, { recursive: true, force: true });
  } catch (error) {
    // Le dossier n'existe pas, c'est OK
  }
  
  await fs.mkdir(testDir, { recursive: true });
  console.log(`${colors.green}✓ Dossier de test créé: ${testDir}${colors.reset}`);
  
  // Créer des fichiers avec différentes tailles et dates
  const now = Date.now();
  
  // Créer des fichiers avec différentes tailles
  await fs.writeFile(path.join(testDir, 'small.txt'), 'Petit fichier');
  await fs.writeFile(path.join(testDir, 'medium.txt'), 'a'.repeat(1024 * 10)); // 10 KB
  await fs.writeFile(path.join(testDir, 'large.txt'), 'a'.repeat(1024 * 100)); // 100 KB
  
  // Créer des fichiers avec différentes extensions pour tester le filtrage
  await fs.writeFile(path.join(testDir, 'config.json'), '{"test": true}');
  await fs.writeFile(path.join(testDir, 'script.js'), 'console.log("Hello");');
  await fs.writeFile(path.join(testDir, 'module.ts'), 'export const test = true;');
  await fs.writeFile(path.join(testDir, 'styles.css'), 'body { color: red; }');
  await fs.writeFile(path.join(testDir, 'data1.csv'), 'id,name\n1,test');
  await fs.writeFile(path.join(testDir, 'data2.csv'), 'id,value\n1,100');
  
  // Modifier les dates de modification
  const yesterday = new Date(now - 24 * 60 * 60 * 1000);
  const lastWeek = new Date(now - 7 * 24 * 60 * 60 * 1000);
  const lastMonth = new Date(now - 30 * 24 * 60 * 60 * 1000);
  
  await fs.utimes(path.join(testDir, 'small.txt'), yesterday, yesterday);
  await fs.utimes(path.join(testDir, 'medium.txt'), lastWeek, lastWeek);
  await fs.utimes(path.join(testDir, 'large.txt'), lastMonth, lastMonth);
  
  // Créer des sous-répertoires
  await fs.mkdir(path.join(testDir, 'dir1'), { recursive: true });
  await fs.mkdir(path.join(testDir, 'dir2'), { recursive: true });
  await fs.mkdir(path.join(testDir, 'dir3'), { recursive: true });
  await fs.mkdir(path.join(testDir, 'src'), { recursive: true });
  await fs.mkdir(path.join(testDir, 'docs'), { recursive: true });
  
  // Créer des fichiers dans les sous-répertoires
  await fs.writeFile(path.join(testDir, 'dir1', 'file1.txt'), 'Fichier 1');
  await fs.writeFile(path.join(testDir, 'dir2', 'file2.txt'), 'Fichier 2');
  await fs.writeFile(path.join(testDir, 'dir3', 'file3.txt'), 'Fichier 3');
  
  // Créer des fichiers dans src/ pour tester le filtrage
  await fs.writeFile(path.join(testDir, 'src', 'main.js'), 'console.log("Main");');
  await fs.writeFile(path.join(testDir, 'src', 'utils.js'), 'export function test() {}');
  await fs.writeFile(path.join(testDir, 'src', 'types.ts'), 'export interface Test {}');
  await fs.writeFile(path.join(testDir, 'src', 'index.ts'), 'import "./main";');
  
  // Créer des fichiers dans docs/ pour tester le filtrage
  await fs.writeFile(path.join(testDir, 'docs', 'readme.md'), '# Documentation');
  await fs.writeFile(path.join(testDir, 'docs', 'guide.md'), '## Guide');
  await fs.writeFile(path.join(testDir, 'docs', 'example.html'), '<html></html>');
  
  console.log(`${colors.green}✓ Fichiers et répertoires de test créés${colors.reset}`);
  
  return testDir;
}

// Fonction pour nettoyer l'environnement de test
async function cleanupTestEnvironment(testDir) {
  console.log(`${colors.cyan}=== Nettoyage de l'environnement de test ===${colors.reset}`);
  
  try {
    await fs.rm(testDir, { recursive: true, force: true });
    console.log(`${colors.green}✓ Dossier de test supprimé${colors.reset}`);
  } catch (error) {
    console.log(`${colors.red}Erreur lors de la suppression du dossier de test: ${error.message}${colors.reset}`);
  }
}

// Fonction principale pour exécuter les tests
async function runTests() {
  console.log(`${colors.cyan}=== Démarrage des tests de tri du serveur MCP quickfiles ===${colors.reset}`);
  
  // Préparer l'environnement de test
  const testDir = await setupTestEnvironment();
  
  try {
    // Test 1: Tri par nom (ascendant)
    console.log(`\n${colors.cyan}Test 1: Tri par nom (ascendant)${colors.reset}`);
    const response1 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 1,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'name',
              sort_order: 'asc'
            }
          ]
        }
      }
    });
    
    // Test 2: Tri par nom (descendant)
    console.log(`\n${colors.cyan}Test 2: Tri par nom (descendant)${colors.reset}`);
    const response2 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 2,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'name',
              sort_order: 'desc'
            }
          ]
        }
      }
    });
    
    // Test 3: Tri par taille (ascendant)
    console.log(`\n${colors.cyan}Test 3: Tri par taille (ascendant)${colors.reset}`);
    const response3 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 3,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'size',
              sort_order: 'asc'
            }
          ]
        }
      }
    });
    
    // Test 4: Tri par taille (descendant)
    console.log(`\n${colors.cyan}Test 4: Tri par taille (descendant)${colors.reset}`);
    const response4 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 4,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'size',
              sort_order: 'desc'
            }
          ]
        }
      }
    });
    
    // Test 5: Tri par date de modification (ascendant)
    console.log(`\n${colors.cyan}Test 5: Tri par date de modification (ascendant)${colors.reset}`);
    const response5 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 5,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'modified',
              sort_order: 'asc'
            }
          ]
        }
      }
    });
    
    // Test 6: Tri par date de modification (descendant)
    console.log(`\n${colors.cyan}Test 6: Tri par date de modification (descendant)${colors.reset}`);
    const response6 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 6,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'modified',
              sort_order: 'desc'
            }
          ]
        }
      }
    });
    
    // Test 7: Tri par type (ascendant)
    console.log(`\n${colors.cyan}Test 7: Tri par type (ascendant)${colors.reset}`);
    const response7 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 7,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'type',
              sort_order: 'asc'
            }
          ]
        }
      }
    });
    
    // Test 8: Tri par type (descendant)
    console.log(`\n${colors.cyan}Test 8: Tri par type (descendant)${colors.reset}`);
    const response8 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 8,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              sort_by: 'type',
              sort_order: 'desc'
            }
          ]
        }
      }
    });
    
    // Test 9: Filtrage par motif glob (*.js)
    console.log(`\n${colors.cyan}Test 9: Filtrage par motif glob (*.js)${colors.reset}`);
    const response9 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 9,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              file_pattern: '*.js'  // Ne lister que les fichiers JavaScript
            }
          ]
        }
      }
    });
    
    // Test 10: Filtrage par motif glob (*.{js,ts})
    console.log(`\n${colors.cyan}Test 10: Filtrage par motif glob (*.{js,ts})${colors.reset}`);
    const response10 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 10,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              file_pattern: '*.{js,ts}'  // Ne lister que les fichiers JavaScript et TypeScript
            }
          ]
        }
      }
    });
    
    // Test 11: Filtrage par motif glob (data?.csv)
    console.log(`\n${colors.cyan}Test 11: Filtrage par motif glob (data?.csv)${colors.reset}`);
    const response11 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 11,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              file_pattern: 'data?.csv'  // Ne lister que les fichiers data1.csv, data2.csv, etc.
            }
          ]
        }
      }
    });
    
    // Test 12: Combinaison de filtrage et tri
    console.log(`\n${colors.cyan}Test 12: Combinaison de filtrage et tri (*.{js,ts} trié par taille)${colors.reset}`);
    const response12 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 12,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              file_pattern: '*.{js,ts}',  // Ne lister que les fichiers JavaScript et TypeScript
              sort_by: 'size',            // Trier par taille
              sort_order: 'desc'          // Du plus grand au plus petit
            }
          ]
        }
      }
    });
    
    // Test 13: Filtrage par répertoire spécifique avec motif glob
    console.log(`\n${colors.cyan}Test 13: Filtrage par répertoire spécifique avec motif glob (src/*.ts)${colors.reset}`);
    const response13 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 13,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: path.join(testDir, 'src'),
              recursive: false,
              file_pattern: '*.ts'  // Ne lister que les fichiers TypeScript dans src/
            }
          ]
        }
      }
    });
    
    // Test 14: Filtrage global sur plusieurs répertoires
    console.log(`\n${colors.cyan}Test 14: Filtrage global sur plusieurs répertoires (*.md)${colors.reset}`);
    const response14 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 14,
      method: 'call_tool',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            { path: path.join(testDir, 'docs') },
            { path: path.join(testDir, 'src') }
          ],
          file_pattern: '*.md',  // Ne lister que les fichiers Markdown dans tous les répertoires
          sort_by: 'name'
        }
      }
    });
    
    console.log(`\n${colors.green}=== Tous les tests de tri et filtrage sont terminés avec succès ===${colors.reset}`);
  } catch (error) {
    console.log(`${colors.red}Erreur lors des tests: ${error.message}${colors.reset}`);
  } finally {
    // Nettoyer l'environnement de test
    await cleanupTestEnvironment(testDir);
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error(`${colors.red}Erreur non gérée: ${error.message}${colors.reset}`);
  process.exit(1);
});