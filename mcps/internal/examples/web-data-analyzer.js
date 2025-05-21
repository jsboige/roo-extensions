#!/usr/bin/env node
// Script qui utilise jinavigator pour extraire des informations de plusieurs sites web
// et quickfiles pour les analyser (compter les lignes, rechercher des motifs)

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

// Liste des URLs à analyser avec les motifs à rechercher
const URLS_TO_ANALYZE = [
  {
    url: "https://en.wikipedia.org/wiki/JavaScript",
    tempFile: "temp/javascript.md",
    patterns: [
      { name: "ECMAScript mentions", regex: "ECMAScript" },
      { name: "Browser mentions", regex: "browser" },
      { name: "Function mentions", regex: "function" }
    ]
  },
  {
    url: "https://en.wikipedia.org/wiki/TypeScript",
    tempFile: "temp/typescript.md",
    patterns: [
      { name: "Microsoft mentions", regex: "Microsoft" },
      { name: "Type mentions", regex: "type" },
      { name: "Interface mentions", regex: "interface" }
    ]
  },
  {
    url: "https://en.wikipedia.org/wiki/Node.js",
    tempFile: "temp/nodejs.md",
    patterns: [
      { name: "Server mentions", regex: "server" },
      { name: "JavaScript mentions", regex: "JavaScript" },
      { name: "NPM mentions", regex: "npm" }
    ]
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
    name: "web-data-analyzer",
    version: "1.0.0"
  });
  
  // Connexion au serveur
  await client.connect(transport);
  
  console.log(`${COLORS.green}Connexion réussie !${COLORS.reset}`);
  console.log(`${COLORS.green}Informations sur le serveur : ${client.serverInfo.name} v${client.serverInfo.version}${COLORS.reset}`);
  
  return { client, serverProcess, transport };
}

// Fonction pour compter les occurrences d'un motif dans un texte
function countOccurrences(text, pattern) {
  const regex = new RegExp(pattern, 'gi');
  const matches = text.match(regex);
  return matches ? matches.length : 0;
}

// Fonction principale
async function main() {
  console.log(`${COLORS.cyan}=== Web Data Analyzer ===${COLORS.reset}`);
  
  // Créer le répertoire temporaire s'il n'existe pas
  await fs.mkdir(path.join(__dirname, '..', 'temp'), { recursive: true });
  
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
    console.log(`${COLORS.cyan}Extraction des données des sites web...${COLORS.reset}`);
    
    const urlsForMultiConvert = URLS_TO_ANALYZE.map(item => ({ url: item.url }));
    
    const conversionResult = await jinavigatorClient.callTool('multi_convert', {
      urls: urlsForMultiConvert
    });
    
    console.log(`${COLORS.green}Extraction réussie pour ${conversionResult.length} URLs${COLORS.reset}`);
    
    // Préparer les données pour l'écriture des fichiers temporaires
    const filesToWrite = [];
    
    for (let i = 0; i < conversionResult.length; i++) {
      const result = conversionResult[i];
      const tempFile = URLS_TO_ANALYZE[i].tempFile;
      
      if (result.success) {
        filesToWrite.push({
          path: tempFile,
          content: result.content
        });
        
        console.log(`${COLORS.green}✓ ${result.url} -> ${tempFile}${COLORS.reset}`);
      } else {
        console.log(`${COLORS.red}✗ Échec pour ${result.url}: ${result.error}${COLORS.reset}`);
      }
    }
    
    // Écrire les fichiers temporaires avec quickfiles
    if (filesToWrite.length > 0) {
      console.log(`${COLORS.cyan}Écriture des fichiers temporaires...${COLORS.reset}`);
      
      // Utiliser edit_multiple_files pour écrire les fichiers
      await quickfilesClient.callTool('edit_multiple_files', {
        files: filesToWrite.map(file => ({
          path: file.path,
          diffs: [{
            search: ".*", // Regex qui correspond à tout le contenu
            replace: file.content
          }]
        }))
      });
    }
    
    // Analyser les fichiers avec quickfiles
    console.log(`${COLORS.cyan}Analyse des fichiers...${COLORS.reset}`);
    
    // Lire les fichiers temporaires
    const readFilesResult = await quickfilesClient.callTool('read_multiple_files', {
      paths: URLS_TO_ANALYZE.map(item => item.tempFile)
    });
    
    // Analyser chaque fichier
    const analysisResults = [];
    
    for (let i = 0; i < readFilesResult.content.length; i++) {
      const fileContent = readFilesResult.content[i].text;
      const urlInfo = URLS_TO_ANALYZE[i];
      
      // Compter les lignes
      const lineCount = fileContent.split('\n').length;
      
      // Rechercher les motifs
      const patternResults = urlInfo.patterns.map(pattern => ({
        name: pattern.name,
        regex: pattern.regex,
        occurrences: countOccurrences(fileContent, pattern.regex)
      }));
      
      analysisResults.push({
        url: urlInfo.url,
        file: urlInfo.tempFile,
        lineCount,
        patternResults
      });
    }
    
    // Afficher les résultats de l'analyse
    console.log(`${COLORS.cyan}\n=== Résultats de l'analyse ===${COLORS.reset}`);
    
    for (const result of analysisResults) {
      console.log(`\n${COLORS.yellow}URL: ${result.url}${COLORS.reset}`);
      console.log(`${COLORS.yellow}Fichier: ${result.file}${COLORS.reset}`);
      console.log(`${COLORS.yellow}Nombre de lignes: ${result.lineCount}${COLORS.reset}`);
      
      console.log(`${COLORS.yellow}Motifs trouvés:${COLORS.reset}`);
      for (const pattern of result.patternResults) {
        console.log(`  - ${pattern.name}: ${pattern.occurrences} occurrences`);
      }
    }
    
    // Générer un rapport de synthèse
    const reportContent = `# Rapport d'analyse des sites web\n\n` +
      analysisResults.map(result => {
        return `## ${result.url}\n\n` +
          `- Fichier: ${result.file}\n` +
          `- Nombre de lignes: ${result.lineCount}\n\n` +
          `### Motifs trouvés\n\n` +
          result.patternResults.map(pattern => 
            `- ${pattern.name}: ${pattern.occurrences} occurrences`
          ).join('\n');
      }).join('\n\n');
    
    // Écrire le rapport avec quickfiles
    console.log(`${COLORS.cyan}\nGénération du rapport d'analyse...${COLORS.reset}`);
    
    await quickfilesClient.callTool('edit_multiple_files', {
      files: [{
        path: "temp/analysis-report.md",
        diffs: [{
          search: ".*",
          replace: reportContent
        }]
      }]
    });
    
    console.log(`${COLORS.green}Rapport généré: temp/analysis-report.md${COLORS.reset}`);
    console.log(`${COLORS.cyan}=== Analyse terminée ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors de l'analyse: ${error.message}${COLORS.reset}`);
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