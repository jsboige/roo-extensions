#!/usr/bin/env node
import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de démonstration
const DEMO_DIR = path.join(__dirname, 'demo-files');

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

// Classe client MCP pour communiquer avec le serveur QuickFiles
class McpClient {
  constructor() {
    this.requestId = 1;
    this.pendingRequests = new Map();
  }

  // Méthode pour appeler un outil MCP via l'API MCP
  async callMcpTool(toolName, args) {
    console.log(`${COLORS.cyan}=== Appel de l'outil MCP: ${toolName} ===${COLORS.reset}`);
    console.log(`${COLORS.yellow}Arguments:${COLORS.reset}`);
    console.log(JSON.stringify(args, null, 2));
    
    try {
      const result = await this.useMcpTool('quickfiles', toolName, args);
      console.log(`${COLORS.green}✓ Résultat obtenu${COLORS.reset}`);
      return result;
    } catch (error) {
      console.error(`${COLORS.red}✗ Erreur lors de l'appel à ${toolName}: ${error.message}${COLORS.reset}`);
      throw error;
    }
  }

  // Simulation de l'appel à use_mcp_tool (dans un environnement réel, ceci utiliserait l'API MCP)
  async useMcpTool(serverName, toolName, args) {
    // Dans un environnement réel, cette méthode ferait un appel à l'API MCP
    // Ici, nous simulons l'appel en utilisant directement le serveur QuickFiles
    
    return new Promise((resolve, reject) => {
      const id = this.requestId++;
      
      // Créer la requête JSON-RPC
      const request = {
        jsonrpc: '2.0',
        id,
        method: 'tools/call',
        params: {
          name: toolName,
          arguments: args
        }
      };
      
      // Afficher la requête
      console.log(`${COLORS.magenta}Requête JSON-RPC:${COLORS.reset}`);
      console.log(JSON.stringify(request, null, 2));
      
      // Dans un environnement réel, cette requête serait envoyée au serveur MCP
      // et la réponse serait traitée ici
      
      // Pour cette démonstration, nous allons utiliser le module use_mcp_tool
      // qui est disponible dans l'environnement Roo
      
      // Simuler une réponse pour la démonstration
      setTimeout(() => {
        console.log(`${COLORS.blue}[Note: Dans un environnement réel, la réponse viendrait du serveur MCP]${COLORS.reset}`);
        resolve({
          content: [
            {
              text: `Résultat simulé de l'appel à ${toolName} avec les arguments: ${JSON.stringify(args)}`
            }
          ]
        });
      }, 500);
    });
  }
}

// Fonction principale pour exécuter la démonstration
async function runDemo() {
  console.log(`${COLORS.cyan}=== DÉMONSTRATION DU MCP QUICKFILES ===${COLORS.reset}`);
  
  // Créer une instance du client MCP
  const client = new McpClient();
  
  try {
    // 1. Démonstration de read_multiple_files
    console.log(`\n${COLORS.cyan}=== 1. DÉMONSTRATION DE READ_MULTIPLE_FILES ===${COLORS.reset}`);
    
    // 1.1 Lecture simple de plusieurs fichiers
    console.log(`\n${COLORS.yellow}1.1 Lecture simple de plusieurs fichiers${COLORS.reset}`);
    const readResult1 = await client.callMcpTool('read_multiple_files', {
      paths: [
        path.join(DEMO_DIR, 'document.txt'),
        path.join(DEMO_DIR, 'tasks.txt')
      ],
      show_line_numbers: true
    });
    console.log(`${COLORS.green}Résultat:${COLORS.reset}`);
    console.log(readResult1.content[0].text);
    
    // 1.2 Lecture avec limitation du nombre de lignes
    console.log(`\n${COLORS.yellow}1.2 Lecture avec limitation du nombre de lignes${COLORS.reset}`);
    const readResult2 = await client.callMcpTool('read_multiple_files', {
      paths: [
        path.join(DEMO_DIR, 'long-file.txt')
      ],
      max_lines_per_file: 10,
      show_line_numbers: true
    });
    console.log(`${COLORS.green}Résultat (limité à 10 lignes):${COLORS.reset}`);
    console.log(readResult2.content[0].text);
    
    // 1.3 Lecture d'extraits spécifiques
    console.log(`\n${COLORS.yellow}1.3 Lecture d'extraits spécifiques${COLORS.reset}`);
    const readResult3 = await client.callMcpTool('read_multiple_files', {
      paths: [
        {
          path: path.join(DEMO_DIR, 'long-file.txt'),
          excerpts: [
            { start: 50, end: 55 },
            { start: 100, end: 105 }
          ]
        }
      ],
      show_line_numbers: true
    });
    console.log(`${COLORS.green}Résultat (extraits spécifiques):${COLORS.reset}`);
    console.log(readResult3.content[0].text);
    
    // 2. Démonstration de list_directory_contents
    console.log(`\n${COLORS.cyan}=== 2. DÉMONSTRATION DE LIST_DIRECTORY_CONTENTS ===${COLORS.reset}`);
    
    // 2.1 Listage simple d'un répertoire
    console.log(`\n${COLORS.yellow}2.1 Listage simple d'un répertoire${COLORS.reset}`);
    const listResult1 = await client.callMcpTool('list_directory_contents', {
      paths: [
        { path: DEMO_DIR, recursive: false }
      ]
    });
    console.log(`${COLORS.green}Résultat (non récursif):${COLORS.reset}`);
    console.log(listResult1.content[0].text);
    
    // 2.2 Listage récursif
    console.log(`\n${COLORS.yellow}2.2 Listage récursif${COLORS.reset}`);
    const listResult2 = await client.callMcpTool('list_directory_contents', {
      paths: [
        { path: DEMO_DIR, recursive: true }
      ]
    });
    console.log(`${COLORS.green}Résultat (récursif):${COLORS.reset}`);
    console.log(listResult2.content[0].text);
    
    // 2.3 Listage avec filtrage par motif
    console.log(`\n${COLORS.yellow}2.3 Listage avec filtrage par motif${COLORS.reset}`);
    const listResult3 = await client.callMcpTool('list_directory_contents', {
      paths: [
        { path: DEMO_DIR, recursive: true, file_pattern: "*.txt" }
      ]
    });
    console.log(`${COLORS.green}Résultat (filtré par *.txt):${COLORS.reset}`);
    console.log(listResult3.content[0].text);
    
    // 3. Démonstration de edit_multiple_files
    console.log(`\n${COLORS.cyan}=== 3. DÉMONSTRATION DE EDIT_MULTIPLE_FILES ===${COLORS.reset}`);
    
    // 3.1 Édition de fichiers multiples
    console.log(`\n${COLORS.yellow}3.1 Édition de fichiers multiples${COLORS.reset}`);
    
    // Afficher le contenu avant modification
    console.log(`${COLORS.blue}Contenu avant modification:${COLORS.reset}`);
    const beforeEdit1 = await fs.readFile(path.join(DEMO_DIR, 'edit-file1.txt'), 'utf-8');
    const beforeEdit2 = await fs.readFile(path.join(DEMO_DIR, 'edit-file2.txt'), 'utf-8');
    console.log(`edit-file1.txt:\n${beforeEdit1}\n`);
    console.log(`edit-file2.txt:\n${beforeEdit2}\n`);
    
    // Effectuer les modifications
    const editResult = await client.callMcpTool('edit_multiple_files', {
      files: [
        {
          path: path.join(DEMO_DIR, 'edit-file1.txt'),
          diffs: [
            {
              search: 'Texte à modifier: première occurrence.',
              replace: 'Texte MODIFIÉ: première occurrence.'
            },
            {
              search: 'Texte à modifier: deuxième occurrence.',
              replace: 'Texte MODIFIÉ: deuxième occurrence.'
            }
          ]
        },
        {
          path: path.join(DEMO_DIR, 'edit-file2.txt'),
          diffs: [
            {
              search: 'Autre texte à modifier dans un fichier différent.',
              replace: 'Autre texte MODIFIÉ dans un fichier différent.'
            }
          ]
        }
      ]
    });
    console.log(`${COLORS.green}Résultat de l'édition:${COLORS.reset}`);
    console.log(editResult.content[0].text);
    
    // Afficher le contenu après modification
    console.log(`${COLORS.blue}Contenu après modification:${COLORS.reset}`);
    const afterEdit1 = await fs.readFile(path.join(DEMO_DIR, 'edit-file1.txt'), 'utf-8');
    const afterEdit2 = await fs.readFile(path.join(DEMO_DIR, 'edit-file2.txt'), 'utf-8');
    console.log(`edit-file1.txt:\n${afterEdit1}\n`);
    console.log(`edit-file2.txt:\n${afterEdit2}\n`);
    
    // 4. Démonstration de delete_files
    console.log(`\n${COLORS.cyan}=== 4. DÉMONSTRATION DE DELETE_FILES ===${COLORS.reset}`);
    
    // 4.1 Suppression de fichiers
    console.log(`\n${COLORS.yellow}4.1 Suppression de fichiers${COLORS.reset}`);
    
    // Vérifier l'existence des fichiers avant suppression
    const fileExists1 = await fileExists(path.join(DEMO_DIR, 'to-delete1.tmp'));
    const fileExists2 = await fileExists(path.join(DEMO_DIR, 'to-delete2.tmp'));
    console.log(`${COLORS.blue}Avant suppression:${COLORS.reset}`);
    console.log(`to-delete1.tmp existe: ${fileExists1}`);
    console.log(`to-delete2.tmp existe: ${fileExists2}`);
    
    // Supprimer les fichiers
    const deleteResult = await client.callMcpTool('delete_files', {
      paths: [
        path.join(DEMO_DIR, 'to-delete1.tmp'),
        path.join(DEMO_DIR, 'to-delete2.tmp')
      ]
    });
    console.log(`${COLORS.green}Résultat de la suppression:${COLORS.reset}`);
    console.log(deleteResult.content[0].text);
    
    // Vérifier l'existence des fichiers après suppression
    const fileExistsAfter1 = await fileExists(path.join(DEMO_DIR, 'to-delete1.tmp'));
    const fileExistsAfter2 = await fileExists(path.join(DEMO_DIR, 'to-delete2.tmp'));
    console.log(`${COLORS.blue}Après suppression:${COLORS.reset}`);
    console.log(`to-delete1.tmp existe: ${fileExistsAfter1}`);
    console.log(`to-delete2.tmp existe: ${fileExistsAfter2}`);
    
    console.log(`\n${COLORS.green}=== DÉMONSTRATION TERMINÉE AVEC SUCCÈS ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors de la démonstration: ${error.message}${COLORS.reset}`);
  }
}

// Fonction utilitaire pour vérifier si un fichier existe
async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

// Exécuter la démonstration
runDemo().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
});