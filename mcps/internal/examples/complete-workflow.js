#!/usr/bin/env node
// Script qui démontre l'utilisation des MCPs dans un workflow complet
// (collecte d'informations, traitement, stockage)

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

// Configuration du workflow
const WORKFLOW_CONFIG = {
  // Étape 1: Collecte d'informations
  sources: [
    {
      name: "JavaScript",
      url: "https://en.wikipedia.org/wiki/JavaScript",
      keywords: ["ECMAScript", "browser", "function", "prototype"]
    },
    {
      name: "TypeScript",
      url: "https://en.wikipedia.org/wiki/TypeScript",
      keywords: ["Microsoft", "type", "interface", "compiler"]
    },
    {
      name: "Node.js",
      url: "https://en.wikipedia.org/wiki/Node.js",
      keywords: ["server", "JavaScript", "npm", "module"]
    }
  ],
  
  // Étape 2: Traitement
  processing: {
    extractSections: ["History", "Features", "Usage"],
    generateSummary: true,
    countKeywords: true
  },
  
  // Étape 3: Stockage
  storage: {
    rawDataDir: "workflow/raw",
    processedDataDir: "workflow/processed",
    reportsDir: "workflow/reports"
  }
};

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
    name: "complete-workflow",
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

// Fonction pour compter les occurrences d'un mot-clé dans un texte
function countKeywordOccurrences(text, keyword) {
  const regex = new RegExp(`\\b${keyword}\\b`, 'gi');
  const matches = text.match(regex);
  return matches ? matches.length : 0;
}

// Fonction pour générer un résumé simple (premiers paragraphes)
function generateSimpleSummary(markdownContent) {
  const paragraphs = markdownContent.split('\n\n');
  // Prendre les 2 premiers paragraphes non vides qui ne commencent pas par #
  const summary = paragraphs
    .filter(p => p.trim() && !p.trim().startsWith('#'))
    .slice(0, 2)
    .join('\n\n');
  
  return summary || "Aucun résumé disponible.";
}

// Fonction principale
async function main() {
  console.log(`${COLORS.cyan}=== Workflow Complet avec MCPs ===${COLORS.reset}`);
  
  // Créer les répertoires de stockage s'ils n'existent pas
  await fs.mkdir(path.join(__dirname, '..', WORKFLOW_CONFIG.storage.rawDataDir), { recursive: true });
  await fs.mkdir(path.join(__dirname, '..', WORKFLOW_CONFIG.storage.processedDataDir), { recursive: true });
  await fs.mkdir(path.join(__dirname, '..', WORKFLOW_CONFIG.storage.reportsDir), { recursive: true });
  
  // Connexion au serveur jinavigator
  console.log(`${COLORS.cyan}Connexion au serveur jinavigator...${COLORS.reset}`);
  const { client: jinavigatorClient, serverProcess: jinavigatorProcess, transport: jinavigatorTransport } = 
    await createMcpClient(JINAVIGATOR_SCRIPT_PATH, JINAVIGATOR_INDEX_PATH);
  
  // Connexion au serveur quickfiles
  console.log(`${COLORS.cyan}Connexion au serveur quickfiles...${COLORS.reset}`);
  const { client: quickfilesClient, serverProcess: quickfilesProcess, transport: quickfilesTransport } = 
    await createMcpClient(QUICKFILES_SCRIPT_PATH, QUICKFILES_INDEX_PATH);
  
  try {
    // ÉTAPE 1: COLLECTE D'INFORMATIONS
    console.log(`${COLORS.cyan}\n=== ÉTAPE 1: COLLECTE D'INFORMATIONS ===${COLORS.reset}`);
    
    // Convertir les URLs en Markdown avec jinavigator
    const urlsForMultiConvert = WORKFLOW_CONFIG.sources.map(source => ({ url: source.url }));
    
    console.log(`${COLORS.cyan}Récupération des données depuis ${urlsForMultiConvert.length} sources...${COLORS.reset}`);
    const webContentsResult = await jinavigatorClient.callTool('multi_convert', {
      urls: urlsForMultiConvert
    });
    
    console.log(`${COLORS.green}Récupération réussie pour ${webContentsResult.filter(r => r.success).length}/${webContentsResult.length} sources${COLORS.reset}`);
    
    // Stocker les données brutes
    console.log(`${COLORS.cyan}Stockage des données brutes...${COLORS.reset}`);
    
    const rawDataFiles = [];
    for (let i = 0; i < webContentsResult.length; i++) {
      const result = webContentsResult[i];
      const source = WORKFLOW_CONFIG.sources[i];
      
      if (result.success) {
        const rawFilePath = `${WORKFLOW_CONFIG.storage.rawDataDir}/${source.name.toLowerCase()}-raw.md`;
        
        rawDataFiles.push({
          path: rawFilePath,
          content: result.content,
          source: source
        });
        
        console.log(`${COLORS.green}✓ ${source.name}: données brutes stockées${COLORS.reset}`);
      } else {
        console.log(`${COLORS.red}✗ ${source.name}: échec de récupération - ${result.error}${COLORS.reset}`);
      }
    }
    
    // Écrire les fichiers de données brutes avec quickfiles
    await quickfilesClient.callTool('edit_multiple_files', {
      files: rawDataFiles.map(file => ({
        path: file.path,
        diffs: [{
          search: ".*",
          replace: file.content
        }]
      }))
    });
    
    // ÉTAPE 2: TRAITEMENT DES DONNÉES
    console.log(`${COLORS.cyan}\n=== ÉTAPE 2: TRAITEMENT DES DONNÉES ===${COLORS.reset}`);
    
    // Traiter chaque source
    const processedData = [];
    
    for (const rawFile of rawDataFiles) {
      const source = rawFile.source;
      console.log(`${COLORS.cyan}Traitement des données pour ${source.name}...${COLORS.reset}`);
      
      // Extraire les sections demandées
      const extractedSections = {};
      for (const sectionName of WORKFLOW_CONFIG.processing.extractSections) {
        const sectionContent = extractSection(rawFile.content, sectionName);
        if (sectionContent) {
          extractedSections[sectionName] = sectionContent;
          console.log(`${COLORS.green}✓ ${source.name}: section "${sectionName}" extraite (${sectionContent.length} caractères)${COLORS.reset}`);
        } else {
          console.log(`${COLORS.yellow}! ${source.name}: section "${sectionName}" non trouvée${COLORS.reset}`);
        }
      }
      
      // Générer un résumé si demandé
      let summary = null;
      if (WORKFLOW_CONFIG.processing.generateSummary) {
        summary = generateSimpleSummary(rawFile.content);
        console.log(`${COLORS.green}✓ ${source.name}: résumé généré (${summary.length} caractères)${COLORS.reset}`);
      }
      
      // Compter les occurrences des mots-clés si demandé
      let keywordCounts = null;
      if (WORKFLOW_CONFIG.processing.countKeywords) {
        keywordCounts = {};
        for (const keyword of source.keywords) {
          keywordCounts[keyword] = countKeywordOccurrences(rawFile.content, keyword);
        }
        console.log(`${COLORS.green}✓ ${source.name}: occurrences des mots-clés comptées${COLORS.reset}`);
      }
      
      // Stocker les données traitées
      processedData.push({
        name: source.name,
        url: source.url,
        extractedSections,
        summary,
        keywordCounts
      });
    }
    
    // Générer les fichiers de données traitées
    for (const data of processedData) {
      const processedFilePath = `${WORKFLOW_CONFIG.storage.processedDataDir}/${data.name.toLowerCase()}-processed.md`;
      
      let processedContent = `# ${data.name} - Données traitées\n\n`;
      processedContent += `Source: ${data.url}\n\n`;
      
      if (data.summary) {
        processedContent += `## Résumé\n\n${data.summary}\n\n`;
      }
      
      if (data.keywordCounts) {
        processedContent += `## Occurrences des mots-clés\n\n`;
        for (const [keyword, count] of Object.entries(data.keywordCounts)) {
          processedContent += `- "${keyword}": ${count} occurrences\n`;
        }
        processedContent += '\n';
      }
      
      if (data.extractedSections) {
        for (const [sectionName, content] of Object.entries(data.extractedSections)) {
          processedContent += `${content}\n\n`;
        }
      }
      
      // Écrire le fichier de données traitées avec quickfiles
      await quickfilesClient.callTool('edit_multiple_files', {
        files: [{
          path: processedFilePath,
          diffs: [{
            search: ".*",
            replace: processedContent
          }]
        }]
      });
      
      console.log(`${COLORS.green}✓ ${data.name}: données traitées stockées${COLORS.reset}`);
    }
    
    // ÉTAPE 3: GÉNÉRATION DE RAPPORTS
    console.log(`${COLORS.cyan}\n=== ÉTAPE 3: GÉNÉRATION DE RAPPORTS ===${COLORS.reset}`);
    
    // Générer un rapport de synthèse
    console.log(`${COLORS.cyan}Génération du rapport de synthèse...${COLORS.reset}`);
    
    let summaryReportContent = `# Rapport de synthèse\n\n`;
    summaryReportContent += `Date de génération: ${new Date().toLocaleString()}\n\n`;
    summaryReportContent += `## Sources analysées\n\n`;
    
    for (const data of processedData) {
      summaryReportContent += `### ${data.name}\n\n`;
      summaryReportContent += `- URL: ${data.url}\n`;
      
      if (data.summary) {
        summaryReportContent += `- Résumé: ${data.summary.split('\n').join(' ').substring(0, 200)}...\n`;
      }
      
      if (data.keywordCounts) {
        summaryReportContent += `- Mots-clés principaux:\n`;
        const sortedKeywords = Object.entries(data.keywordCounts)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3);
        
        for (const [keyword, count] of sortedKeywords) {
          summaryReportContent += `  - "${keyword}": ${count} occurrences\n`;
        }
      }
      
      summaryReportContent += `- Sections extraites: ${Object.keys(data.extractedSections).join(', ')}\n\n`;
    }
    
    // Écrire le rapport de synthèse avec quickfiles
    await quickfilesClient.callTool('edit_multiple_files', {
      files: [{
        path: `${WORKFLOW_CONFIG.storage.reportsDir}/rapport-synthese.md`,
        diffs: [{
          search: ".*",
          replace: summaryReportContent
        }]
      }]
    });
    
    console.log(`${COLORS.green}✓ Rapport de synthèse généré${COLORS.reset}`);
    
    // Générer un rapport comparatif
    console.log(`${COLORS.cyan}Génération du rapport comparatif...${COLORS.reset}`);
    
    let comparativeReportContent = `# Rapport comparatif\n\n`;
    comparativeReportContent += `Date de génération: ${new Date().toLocaleString()}\n\n`;
    
    // Comparer les occurrences de mots-clés
    comparativeReportContent += `## Comparaison des occurrences de mots-clés\n\n`;
    comparativeReportContent += `| Source | ${processedData[0].keywords.join(' | ')} |\n`;
    comparativeReportContent += `| --- | ${processedData[0].keywords.map(() => '---').join(' | ')} |\n`;
    
    for (const data of processedData) {
      const keywordValues = data.keywords.map(keyword => 
        data.keywordCounts && data.keywordCounts[keyword] !== undefined 
          ? data.keywordCounts[keyword] 
          : 'N/A'
      );
      
      comparativeReportContent += `| ${data.name} | ${keywordValues.join(' | ')} |\n`;
    }
    
    // Écrire le rapport comparatif avec quickfiles
    await quickfilesClient.callTool('edit_multiple_files', {
      files: [{
        path: `${WORKFLOW_CONFIG.storage.reportsDir}/rapport-comparatif.md`,
        diffs: [{
          search: ".*",
          replace: comparativeReportContent
        }]
      }]
    });
    
    console.log(`${COLORS.green}✓ Rapport comparatif généré${COLORS.reset}`);
    
    // Générer un index des rapports
    console.log(`${COLORS.cyan}Génération de l'index des rapports...${COLORS.reset}`);
    
    let indexContent = `# Index des rapports\n\n`;
    indexContent += `Date de génération: ${new Date().toLocaleString()}\n\n`;
    indexContent += `## Rapports disponibles\n\n`;
    indexContent += `- [Rapport de synthèse](rapport-synthese.md)\n`;
    indexContent += `- [Rapport comparatif](rapport-comparatif.md)\n\n`;
    indexContent += `## Données traitées\n\n`;
    
    for (const data of processedData) {
      indexContent += `- [${data.name}](../processed/${data.name.toLowerCase()}-processed.md)\n`;
    }
    
    indexContent += `\n## Données brutes\n\n`;
    
    for (const data of processedData) {
      indexContent += `- [${data.name}](../raw/${data.name.toLowerCase()}-raw.md)\n`;
    }
    
    // Écrire l'index avec quickfiles
    await quickfilesClient.callTool('edit_multiple_files', {
      files: [{
        path: `${WORKFLOW_CONFIG.storage.reportsDir}/index.md`,
        diffs: [{
          search: ".*",
          replace: indexContent
        }]
      }]
    });
    
    console.log(`${COLORS.green}✓ Index des rapports généré${COLORS.reset}`);
    
    console.log(`${COLORS.cyan}\n=== WORKFLOW TERMINÉ ===${COLORS.reset}`);
    console.log(`${COLORS.green}Tous les rapports ont été générés dans le répertoire ${WORKFLOW_CONFIG.storage.reportsDir}${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors du workflow: ${error.message}${COLORS.reset}`);
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