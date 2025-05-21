/**
 * Test de la fonctionnalité d'extraction du plan des titres markdown
 *
 * Ce script teste le nouvel outil extract_markdown_outline du serveur JinaNavigator
 * en extrayant le plan hiérarchique des titres d'une page web et en vérifiant
 * que la structure retournée est correcte.
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel en ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le serveur compilé
const serverPath = path.join(__dirname, '../dist/index.js');

// Vérifier que le serveur existe
if (!fs.existsSync(serverPath)) {
  console.error(`Le serveur n'existe pas au chemin: ${serverPath}`);
  process.exit(1);
}

// Fonction pour analyser les réponses JSON du serveur
function parseServerResponse(data) {
  try {
    // Diviser les données en lignes et traiter chaque ligne comme un JSON potentiel
    const lines = data.toString().trim().split('\n');
    return lines
      .filter(line => line.trim())
      .map(line => {
        try {
          return JSON.parse(line);
        } catch (e) {
          console.warn(`Impossible de parser la ligne comme JSON: ${line}`);
          return null;
        }
      })
      .filter(json => json !== null);
  } catch (e) {
    console.error('Erreur lors du parsing de la réponse:', e);
    return [];
  }
}

// Fonction pour vérifier la structure du plan des titres
function validateOutlineStructure(outline) {
  if (!Array.isArray(outline)) {
    console.error('Le plan des titres n\'est pas un tableau');
    return false;
  }

  // Vérifier chaque élément du plan
  for (const heading of outline) {
    if (typeof heading.level !== 'number' || heading.level < 1 || heading.level > 6) {
      console.error('Niveau de titre invalide:', heading.level);
      return false;
    }
    
    if (typeof heading.text !== 'string' || !heading.text.trim()) {
      console.error('Texte de titre invalide:', heading.text);
      return false;
    }
    
    if (typeof heading.line !== 'number' || heading.line < 1) {
      console.error('Numéro de ligne invalide:', heading.line);
      return false;
    }
    
    // Vérifier récursivement les enfants si présents
    if (heading.children) {
      if (!validateOutlineStructure(heading.children)) {
        return false;
      }
    }
  }
  
  return true;
}

// Lancer le serveur
const server = spawn('node', [serverPath], {
  stdio: ['pipe', 'pipe', 'pipe']
});

// Stocker les réponses du serveur
let serverResponses = [];

// Gérer les erreurs du serveur
server.stderr.on('data', (data) => {
  console.error(`Erreur du serveur: ${data}`);
});

// Gérer la sortie du serveur
server.stdout.on('data', (data) => {
  console.log(`Sortie du serveur: ${data}`);
  const responses = parseServerResponse(data);
  serverResponses = serverResponses.concat(responses);
});

// Attendre que le serveur soit prêt
setTimeout(() => {
  // Requête pour lister les outils disponibles
  const listToolsRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'mcp.list_tools',
    params: {}
  };

  // Envoyer la requête au serveur
  server.stdin.write(JSON.stringify(listToolsRequest) + '\n');

  // Attendre la réponse
  setTimeout(() => {
    // Vérifier que l'outil extract_markdown_outline est disponible
    const toolsResponse = serverResponses.find(r => r.id === 1);
    if (toolsResponse && toolsResponse.result && toolsResponse.result.tools) {
      const outlineTool = toolsResponse.result.tools.find(t => t.name === 'extract_markdown_outline');
      if (!outlineTool) {
        console.error("L'outil extract_markdown_outline n'est pas disponible");
        server.kill();
        process.exit(1);
      }
      console.log("Outil extract_markdown_outline trouvé, test en cours...");
    }

    // Requête pour utiliser l'outil extract_markdown_outline
    const callToolRequest = {
      jsonrpc: '2.0',
      id: 2,
      method: 'mcp.call_tool',
      params: {
        name: 'extract_markdown_outline',
        arguments: {
          urls: [
            { url: 'https://github.com/jsboige/mcp-servers' }
          ],
          max_depth: 3
        }
      }
    };

    // Envoyer la requête au serveur
    server.stdin.write(JSON.stringify(callToolRequest) + '\n');

    // Attendre la réponse et vérifier les résultats
    setTimeout(() => {
      // Trouver la réponse de l'outil
      const toolResponse = serverResponses.find(r => r.id === 2);
      
      if (!toolResponse) {
        console.error("Aucune réponse reçue pour l'appel à extract_markdown_outline");
        server.kill();
        process.exit(1);
      }
      
      if (toolResponse.error) {
        console.error("Erreur lors de l'appel à extract_markdown_outline:", toolResponse.error);
        server.kill();
        process.exit(1);
      }
      
      // Vérifier que la réponse contient un résultat
      if (!toolResponse.result || !toolResponse.result.result) {
        console.error("La réponse ne contient pas de résultat");
        server.kill();
        process.exit(1);
      }
      
      // Vérifier que le résultat contient au moins une URL avec succès
      const results = toolResponse.result.result;
      if (!Array.isArray(results) || results.length === 0) {
        console.error("Le résultat ne contient aucune URL");
        server.kill();
        process.exit(1);
      }
      
      // Vérifier au moins un résultat avec succès
      const successResult = results.find(r => r.success);
      if (!successResult) {
        console.error("Aucun résultat avec succès");
        server.kill();
        process.exit(1);
      }
      
      // Vérifier la structure du plan des titres
      if (!successResult.outline || !validateOutlineStructure(successResult.outline)) {
        console.error("La structure du plan des titres est invalide");
        server.kill();
        process.exit(1);
      }
      
      console.log("Test réussi! La structure du plan des titres est valide.");
      console.log(`Nombre de titres racine: ${successResult.outline.length}`);
      
      // Afficher un exemple de titre avec ses enfants
      if (successResult.outline.length > 0) {
        const firstHeading = successResult.outline[0];
        console.log(`Premier titre: ${firstHeading.text} (niveau ${firstHeading.level}, ligne ${firstHeading.line})`);
        
        if (firstHeading.children && firstHeading.children.length > 0) {
          console.log(`  Nombre de sous-titres: ${firstHeading.children.length}`);
          console.log(`  Premier sous-titre: ${firstHeading.children[0].text}`);
        }
      }
      
      console.log('Test terminé, arrêt du serveur...');
      server.kill();
      process.exit(0);
    }, 5000);
  }, 1000);
}, 1000);

// Gérer l'arrêt du serveur
process.on('exit', () => {
  if (!server.killed) {
    server.kill();
  }
});