#!/usr/bin/env node
// Script qui utilise quickfiles pour lire plusieurs fichiers et jinavigator
// pour enrichir leur contenu avec des informations web

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

// Configuration des fichiers à enrichir
const FILES_TO_ENRICH = [
  {
    inputFile: "demo-file1.txt",
    outputFile: "enriched/demo-file1-enriched.md",
    webSource: "https://en.wikipedia.org/wiki/JavaScript",
    webSourceSection: "History" // Section à extraire du contenu web
  },
  {
    inputFile: "demo-file2.txt",
    outputFile: "enriched/demo-file2-enriched.md",
    webSource: "https://en.wikipedia.org/wiki/Node.js",
    webSourceSection: "History" // Section à extraire du contenu web
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
    name: "content-enricher",
    version: "1.0.0"
  });
  
  // Connexion au serveur
  await client.connect(transport);
  
  console.log(`${COLORS.green}Connexion réussie !${COLORS.reset}`);
  console.log(`${COLORS.green}Informations sur le serveur : ${client.serverInfo.name} v${client.serverInfo.version}${COLORS.reset}`);
  
  return { client, serverProcess, transport };
}

// Fonction pour extraire une section spécifique d'un contenu Markdown
function extractSection(markdownContent, sectionName) {
  const lines = markdownContent.split('\n');
  let inSection = false;
  let sectionContent = [];
  const sectionRegex = new RegExp(`^#+\\s+${sectionName}`, 'i');
  const nextSectionRegex = /^#+\s+/;
  
  for (const line of lines) {
    if (!inSection && sectionRegex.test(line)) {
      inSection = true;
      sectionContent.push(line);
    } else if (inSection) {
      if (nextSectionRegex.test(line) && !sectionRegex.test(line)) {
        break;
      }
      sectionContent.push(line);
    }
  }
  
  return sectionContent.join('\n');
}

// Fonction principale
async function main() {
  console.log(`${COLORS.cyan}=== Content Enricher ===${COLORS.reset}`);
  
  // Créer le répertoire de sortie s'il n'existe pas
  await fs.mkdir(path.join(__dirname, '..', 'enriched'), { recursive: true });
  
  // Connexion au serveur jinavigator
  console.log(`${COLORS.cyan}Connexion au serveur jinavigator...${COLORS.reset}`);
  const { client: jinavigatorClient, serverProcess: jinavigatorProcess, transport: jinavigatorTransport } = 
    await createMcpClient(JINAVIGATOR_SCRIPT_PATH, JINAVIGATOR_INDEX_PATH);
  
  // Connexion au serveur quickfiles
  console.log(`${COLORS.cyan}Connexion au serveur quickfiles...${COLORS.reset}`);
  const { client: quickfilesClient, serverProcess: quickfilesProcess, transport: quickfilesTransport } = 
    await createMcpClient(QUICKFILES_SCRIPT_PATH, QUICKFILES_INDEX_PATH);
  
  try {
    // Lire les fichiers avec quickfiles
    console.log(`${COLORS.cyan}Lecture des fichiers locaux...${COLORS.reset}`);
    
    const readFilesResult = await quickfilesClient.callTool('read_multiple_files', {
      paths: FILES_TO_ENRICH.map(item => item.inputFile)
    });
    
    console.log(`${COLORS.green}Lecture réussie pour ${readFilesResult.content.length} fichiers${COLORS.reset}`);
    
    // Récupérer les informations web avec jinavigator
    console.log(`${COLORS.cyan}Récupération des informations web...${COLORS.reset}`);
    
    const webSources = FILES_TO_ENRICH.map(item => ({ url: item.webSource }));
    
    const webContentsResult = await jinavigatorClient.callTool('multi_convert', {
      urls: webSources
    });
    
    console.log(`${COLORS.green}Récupération réussie pour ${webContentsResult.length} sources web${COLORS.reset}`);
    
    // Enrichir les fichiers
    console.log(`${COLORS.cyan}Enrichissement des fichiers...${COLORS.reset}`);
    
    const enrichedFiles = [];
    
    for (let i = 0; i < FILES_TO_ENRICH.length; i++) {
      const fileConfig = FILES_TO_ENRICH[i];
      const fileContent = readFilesResult.content[i].text;
      const webResult = webContentsResult[i];
      
      if (webResult.success) {
        // Extraire la section spécifique du contenu web
        const sectionContent = extractSection(webResult.content, fileConfig.webSourceSection);
        
        // Créer le contenu enrichi
        const enrichedContent = `# Fichier enrichi: ${path.basename(fileConfig.inputFile)}\n\n` +
          `## Contenu original\n\n` +
          `\`\`\`\n${fileContent}\n\`\`\`\n\n` +
          `## Informations complémentaires de ${fileConfig.webSource}\n\n` +
          sectionContent;
        
        enrichedFiles.push({
          path: fileConfig.outputFile,
          content: enrichedContent
        });
        
        console.log(`${COLORS.green}✓ ${fileConfig.inputFile} enrichi avec des informations de ${fileConfig.webSource}${COLORS.reset}`);
      } else {
        console.log(`${COLORS.red}✗ Échec pour ${fileConfig.webSource}: ${webResult.error}${COLORS.reset}`);
      }
    }
    
    // Écrire les fichiers enrichis avec quickfiles
    if (enrichedFiles.length > 0) {
      console.log(`${COLORS.cyan}Écriture des fichiers enrichis...${COLORS.reset}`);
      
      // Utiliser edit_multiple_files pour écrire les fichiers
      const editResult = await quickfilesClient.callTool('edit_multiple_files', {
        files: enrichedFiles.map(file => ({
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
    
    console.log(`${COLORS.cyan}=== Enrichissement terminé ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors de l'enrichissement: ${error.message}${COLORS.reset}`);
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