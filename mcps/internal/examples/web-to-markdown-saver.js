#!/usr/bin/env node
// Script qui utilise jinavigator pour convertir plusieurs pages web en Markdown
// et quickfiles pour les enregistrer dans des fichiers

import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs/promises';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemins vers les serveurs MCP
const JINAVIGATOR_SCRIPT_PATH = path.join(__dirname, '..', 'servers', 'jinavigator-server', 'run-node-fixed.bat');
const JINAVIGATOR_INDEX_PATH = path.join(__dirname, '..', 'servers', 'jinavigator-server', 'dist', 'index.js');
const QUICKFILES_SCRIPT_PATH = path.join(__dirname, '..', 'servers', 'quickfiles-server', 'run-node-fixed.bat');
const QUICKFILES_INDEX_PATH = path.join(__dirname, '..', 'servers', 'quickfiles-server', 'build', 'index.js');

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

// Liste des URLs à convertir
const URLS_TO_CONVERT = [
  {
    url: "https://en.wikipedia.org/wiki/Model_Context_Protocol",
    outputFile: "output/model-context-protocol.md"
  },
  {
    url: "https://en.wikipedia.org/wiki/JavaScript",
    outputFile: "output/javascript.md"
  },
  {
    url: "https://en.wikipedia.org/wiki/Node.js",
    outputFile: "output/nodejs.md"
  }
];

// Fonction pour créer un client MCP
async function createMcpClient(scriptPath, indexPath) {
  console.log(`${COLORS.cyan}Démarrage du serveur MCP...${COLORS.reset}`);
  
  // Lancement du serveur MCP
  const serverProcess = spawn('cmd', ['/c', scriptPath, indexPath], {
    stdio: ['pipe', 'pipe', process.stderr]
  });
  
  // Attendre un peu pour que le serveur démarre
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Création du transport pour communiquer avec le serveur
  const transport = new StdioClientTransport({
    command: 'cmd',
    args: ['/c', scriptPath, indexPath]
  });
  
  // Création du client MCP
  const client = new Client({
    name: "web-to-markdown-saver",
    version: "1.0.0"
  });
  
  // Connexion au serveur
  await client.connect(transport);
  
  console.log(`${COLORS.green}Connexion réussie !${COLORS.reset}`);
  console.log(`${COLORS.green}Informations sur le serveur : ${client.serverInfo.name} v${client.serverInfo.version}${COLORS.reset}`);
  
  return { client, serverProcess, transport };
}

// Fonction principale
async function main() {
  console.log(`${COLORS.cyan}=== Web to Markdown Saver ===${COLORS.reset}`);
  
  // Créer le répertoire de sortie s'il n'existe pas
  await fs.mkdir(path.join(__dirname, '..', 'output'), { recursive: true });
  
  // Connexion au serveur jinavigator
  console.log(`${COLORS.cyan}Connexion au serveur jinavigator...${COLORS.reset}`);
  const { client: jinavigatorClient, serverProcess: jinavigatorProcess, transport: jinavigatorTransport } = 
    await createMcpClient(JINAVIGATOR_SCRIPT_PATH, JINAVIGATOR_INDEX_PATH);
  
  // Connexion au serveur quickfiles
  console.log(`${COLORS.cyan}Connexion au serveur quickfiles...${COLORS.reset}`);
  const { client: quickfilesClient, serverProcess: quickfilesProcess, transport: quickfilesTransport } = 
    await createMcpClient(QUICKFILES_SCRIPT_PATH, QUICKFILES_INDEX_PATH);
  
  try {
    // Convertir les URLs en Markdown avec jinavigator
    console.log(`${COLORS.cyan}Conversion des URLs en Markdown...${COLORS.reset}`);
    
    const urlsForMultiConvert = URLS_TO_CONVERT.map(item => ({ url: item.url }));
    
    const conversionResult = await jinavigatorClient.callTool('multi_convert', {
      urls: urlsForMultiConvert
    });
    
    console.log(`${COLORS.green}Conversion réussie pour ${conversionResult.length} URLs${COLORS.reset}`);
    
    // Préparer les données pour l'écriture des fichiers
    const filesToWrite = [];
    
    for (let i = 0; i < conversionResult.length; i++) {
      const result = conversionResult[i];
      const outputFile = URLS_TO_CONVERT[i].outputFile;
      
      if (result.success) {
        filesToWrite.push({
          path: outputFile,
          content: result.content
        });
        
        console.log(`${COLORS.green}✓ ${result.url} -> ${outputFile}${COLORS.reset}`);
      } else {
        console.log(`${COLORS.red}✗ Échec pour ${result.url}: ${result.error}${COLORS.reset}`);
      }
    }
    
    // Écrire les fichiers avec quickfiles
    if (filesToWrite.length > 0) {
      console.log(`${COLORS.cyan}Écriture des fichiers Markdown...${COLORS.reset}`);
      
      // Utiliser edit_multiple_files pour écrire les fichiers
      // (Nous utilisons des diffs qui remplacent tout le contenu)
      const editResult = await quickfilesClient.callTool('edit_multiple_files', {
        files: filesToWrite.map(file => ({
          path: file.path,
          diffs: [{
            search: ".*", // Regex qui correspond à tout le contenu
            replace: file.content
          }]
        }))
      });
      
      console.log(`${COLORS.green}Écriture réussie pour ${editResult.success_count} fichiers${COLORS.reset}`);
      
      if (editResult.failures && editResult.failures.length > 0) {
        console.log(`${COLORS.red}Échecs d'écriture: ${editResult.failures.length}${COLORS.reset}`);
        for (const failure of editResult.failures) {
          console.log(`${COLORS.red}- ${failure.path}: ${failure.error}${COLORS.reset}`);
        }
      }
    }
    
    console.log(`${COLORS.cyan}=== Traitement terminé ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors du traitement: ${error.message}${COLORS.reset}`);
  } finally {
    // Fermeture des clients
    console.log(`${COLORS.cyan}Fermeture des connexions...${COLORS.reset}`);
    
    jinavigatorProcess.kill();
    await jinavigatorTransport.close().catch(console.error);
    
    quickfilesProcess.kill();
    await quickfilesTransport.close().catch(console.error);
  }
}

// Exécuter le script
main().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
  process.exit(1);
});