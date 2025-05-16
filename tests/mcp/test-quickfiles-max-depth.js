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

// Fonction pour envoyer une requête au serveur MCP
async function sendMcpRequest(request) {
  console.log(`${colors.magenta}[Client requête]: ${JSON.stringify(request, null, 2)}${colors.reset}`);
  
  try {
    // Utiliser le chemin absolu pour éviter les problèmes de chemin relatif
    const serverPath = path.join(process.cwd(), 'servers', 'quickfiles-server', 'build', 'index.js');
    const { stdout } = await executeCommand('node', [serverPath], JSON.stringify(request) + '\n');
    
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

// Fonction pour extraire et analyser les niveaux de profondeur dans la réponse
function analyzeDepthLevels(responseText) {
  // Extraire le contenu formaté de la réponse
  if (!responseText || !responseText.result || !responseText.result.content || !responseText.result.content[0]) {
    console.log(`${colors.red}Réponse invalide ou vide${colors.reset}`);
    return { content: "", levels: {}, maxLevelFound: 0 };
  }
  
  const content = responseText.result.content[0].text;
  
  // Compter les occurrences de chaque niveau de profondeur
  const levels = {};
  const lines = content.split('\n');
  
  for (const line of lines) {
    // Compter les espaces d'indentation pour déterminer le niveau
    if (line.includes('📁') || line.includes('📄')) {
      const match = line.match(/^(\s*)/);
      const indentation = match ? match[1].length : 0;
      const level = indentation / 2; // Chaque niveau est indenté de 2 espaces
      
      levels[level] = (levels[level] || 0) + 1;
    }
  }
  
  return {
    content,
    levels,
    maxLevelFound: Math.max(...Object.keys(levels).map(Number))
  };
}

// Fonction principale pour exécuter les tests
async function runTests() {
  console.log(`${colors.cyan}=== Démarrage des tests du paramètre max_depth du serveur MCP quickfiles ===${colors.reset}`);
  
  // Chemin vers le répertoire de test avec une structure profonde
  const testDir = path.resolve(process.cwd(), 'test-dirs', 'deep');
  console.log(`${colors.yellow}Chemin du répertoire de test: ${testDir}${colors.reset}`);
  
  try {
    // Test 1: Sans limitation de profondeur (comportement par défaut)
    console.log(`\n${colors.cyan}Test 1: Sans limitation de profondeur (comportement par défaut)${colors.reset}`);
    const response1 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true
              // Pas de max_depth spécifié, devrait explorer tous les niveaux
            }
          ]
        }
      }
    });
    
    const analysis1 = analyzeDepthLevels(response1.result);
    console.log(`${colors.yellow}Analyse de la profondeur - Sans limitation:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis1.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis1.maxLevelFound}`);
    
    // Test 2: Avec max_depth = 1 (seulement le premier niveau)
    console.log(`\n${colors.cyan}Test 2: Avec max_depth = 1 (seulement le premier niveau)${colors.reset}`);
    const response2 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              max_depth: 1
            }
          ]
        }
      }
    });
    
    const analysis2 = analyzeDepthLevels(response2.result);
    console.log(`${colors.yellow}Analyse de la profondeur - max_depth = 1:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis2.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis2.maxLevelFound}`);
    
    // Test 3: Avec max_depth = 2
    console.log(`\n${colors.cyan}Test 3: Avec max_depth = 2${colors.reset}`);
    const response3 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              max_depth: 2
            }
          ]
        }
      }
    });
    
    const analysis3 = analyzeDepthLevels(response3.result);
    console.log(`${colors.yellow}Analyse de la profondeur - max_depth = 2:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis3.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis3.maxLevelFound}`);
    
    // Test 4: Avec max_depth = 3
    console.log(`\n${colors.cyan}Test 4: Avec max_depth = 3${colors.reset}`);
    const response4 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 4,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              max_depth: 3
            }
          ]
        }
      }
    });
    
    const analysis4 = analyzeDepthLevels(response4.result);
    console.log(`${colors.yellow}Analyse de la profondeur - max_depth = 3:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis4.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis4.maxLevelFound}`);
    
    // Test 5: Paramètre max_depth global
    console.log(`\n${colors.cyan}Test 5: Paramètre max_depth global${colors.reset}`);
    const response5 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 5,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true
              // Pas de max_depth spécifique au répertoire
            }
          ],
          max_depth: 2 // max_depth global
        }
      }
    });
    
    const analysis5 = analyzeDepthLevels(response5.result);
    console.log(`${colors.yellow}Analyse de la profondeur - max_depth global = 2:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis5.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis5.maxLevelFound}`);
    
    // Test 6: Priorité du max_depth spécifique sur le max_depth global
    console.log(`\n${colors.cyan}Test 6: Priorité du max_depth spécifique sur le max_depth global${colors.reset}`);
    const response6 = await sendMcpRequest({
      jsonrpc: '2.0',
      id: 6,
      method: 'tools/call',
      params: {
        name: 'list_directory_contents',
        arguments: {
          paths: [
            {
              path: testDir,
              recursive: true,
              max_depth: 3 // max_depth spécifique au répertoire
            }
          ],
          max_depth: 1 // max_depth global (devrait être ignoré)
        }
      }
    });
    
    const analysis6 = analyzeDepthLevels(response6.result);
    console.log(`${colors.yellow}Analyse de la profondeur - max_depth spécifique = 3, max_depth global = 1:${colors.reset}`);
    console.log(`Niveaux trouvés: ${JSON.stringify(analysis6.levels)}`);
    console.log(`Niveau maximum trouvé: ${analysis6.maxLevelFound}`);
    
    // Vérification des résultats
    console.log(`\n${colors.cyan}=== Vérification des résultats ===${colors.reset}`);
    
    // Vérifier que les limitations de profondeur ont été respectées
    const success = (
      analysis1.maxLevelFound >= 4 && // Sans limitation, devrait explorer tous les niveaux (au moins 4)
      analysis2.maxLevelFound <= 1 && // max_depth = 1
      analysis3.maxLevelFound <= 2 && // max_depth = 2
      analysis4.maxLevelFound <= 3 && // max_depth = 3
      analysis5.maxLevelFound <= 2 && // max_depth global = 2
      analysis6.maxLevelFound <= 3    // max_depth spécifique = 3 (prioritaire sur global = 1)
    );
    
    if (success) {
      console.log(`${colors.green}✓ Tous les tests du paramètre max_depth ont réussi !${colors.reset}`);
      console.log(`${colors.green}✓ Le paramètre max_depth fonctionne correctement pour limiter la profondeur d'exploration des répertoires.${colors.reset}`);
    } else {
      console.log(`${colors.red}✗ Certains tests ont échoué. Le paramètre max_depth ne fonctionne pas comme prévu.${colors.reset}`);
    }
    
  } catch (error) {
    console.log(`${colors.red}Erreur lors des tests: ${error.message}${colors.reset}`);
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error(`${colors.red}Erreur non gérée: ${error.message}${colors.reset}`);
  process.exit(1);
});