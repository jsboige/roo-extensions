#!/usr/bin/env node
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

/**
 * Démonstration pratique du MCP QuickFiles
 * 
 * Ce script montre comment utiliser les fonctionnalités du MCP QuickFiles
 * en utilisant l'API MCP de Roo.
 */
async function runDemo() {
  console.log(`${COLORS.cyan}=== DÉMONSTRATION DU MCP QUICKFILES AVEC ROO ===${COLORS.reset}`);
  
  try {
    // Vérifier si le dossier de démonstration existe
    try {
      await fs.access(DEMO_DIR);
    } catch {
      console.log(`${COLORS.yellow}Le dossier de démonstration n'existe pas. Exécutez d'abord demo-setup.js.${COLORS.reset}`);
      process.exit(1);
    }

    // 1. Démonstration de read_multiple_files
    console.log(`\n${COLORS.cyan}=== 1. DÉMONSTRATION DE READ_MULTIPLE_FILES ===${COLORS.reset}`);
    
    // 1.1 Lecture simple de plusieurs fichiers
    console.log(`\n${COLORS.yellow}1.1 Lecture simple de plusieurs fichiers${COLORS.reset}`);
    console.log(`Lecture des fichiers: document.txt et tasks.txt`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const readResult1 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "read_multiple_files",
      arguments: {
        paths: [
          path.join(DEMO_DIR, 'document.txt'),
          path.join(DEMO_DIR, 'tasks.txt')
        ],
        show_line_numbers: true
      }
    });
    console.log(readResult1.content[0].text);
    */
    
    // 1.2 Lecture avec limitation du nombre de lignes
    console.log(`\n${COLORS.yellow}1.2 Lecture avec limitation du nombre de lignes${COLORS.reset}`);
    console.log(`Lecture du fichier long-file.txt avec limitation à 10 lignes`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const readResult2 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "read_multiple_files",
      arguments: {
        paths: [
          path.join(DEMO_DIR, 'long-file.txt')
        ],
        max_lines_per_file: 10,
        show_line_numbers: true
      }
    });
    console.log(readResult2.content[0].text);
    */
    
    // 1.3 Lecture d'extraits spécifiques
    console.log(`\n${COLORS.yellow}1.3 Lecture d'extraits spécifiques${COLORS.reset}`);
    console.log(`Lecture d'extraits spécifiques du fichier long-file.txt (lignes 50-55 et 100-105)`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const readResult3 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "read_multiple_files",
      arguments: {
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
      }
    });
    console.log(readResult3.content[0].text);
    */
    
    // 2. Démonstration de list_directory_contents
    console.log(`\n${COLORS.cyan}=== 2. DÉMONSTRATION DE LIST_DIRECTORY_CONTENTS ===${COLORS.reset}`);
    
    // 2.1 Listage simple d'un répertoire
    console.log(`\n${COLORS.yellow}2.1 Listage simple d'un répertoire${COLORS.reset}`);
    console.log(`Listage non récursif du dossier de démonstration`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const listResult1 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "list_directory_contents",
      arguments: {
        paths: [
          { path: DEMO_DIR, recursive: false }
        ]
      }
    });
    console.log(listResult1.content[0].text);
    */
    
    // 2.2 Listage récursif
    console.log(`\n${COLORS.yellow}2.2 Listage récursif${COLORS.reset}`);
    console.log(`Listage récursif du dossier de démonstration`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const listResult2 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "list_directory_contents",
      arguments: {
        paths: [
          { path: DEMO_DIR, recursive: true }
        ]
      }
    });
    console.log(listResult2.content[0].text);
    */
    
    // 2.3 Listage avec filtrage par motif
    console.log(`\n${COLORS.yellow}2.3 Listage avec filtrage par motif${COLORS.reset}`);
    console.log(`Listage récursif filtré par *.txt`);
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const listResult3 = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "list_directory_contents",
      arguments: {
        paths: [
          { path: DEMO_DIR, recursive: true, file_pattern: "*.txt" }
        ]
      }
    });
    console.log(listResult3.content[0].text);
    */
    
    // 3. Démonstration de edit_multiple_files
    console.log(`\n${COLORS.cyan}=== 3. DÉMONSTRATION DE EDIT_MULTIPLE_FILES ===${COLORS.reset}`);
    
    // 3.1 Édition de fichiers multiples
    console.log(`\n${COLORS.yellow}3.1 Édition de fichiers multiples${COLORS.reset}`);
    console.log(`Modification de edit-file1.txt et edit-file2.txt`);
    
    // Afficher le contenu avant modification
    console.log(`${COLORS.blue}Contenu avant modification:${COLORS.reset}`);
    try {
      const beforeEdit1 = await fs.readFile(path.join(DEMO_DIR, 'edit-file1.txt'), 'utf-8');
      const beforeEdit2 = await fs.readFile(path.join(DEMO_DIR, 'edit-file2.txt'), 'utf-8');
      console.log(`edit-file1.txt:\n${beforeEdit1}\n`);
      console.log(`edit-file2.txt:\n${beforeEdit2}\n`);
    } catch (error) {
      console.log(`${COLORS.red}Erreur lors de la lecture des fichiers: ${error.message}${COLORS.reset}`);
    }
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const editResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "edit_multiple_files",
      arguments: {
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
      }
    });
    */
    
    // 4. Démonstration de delete_files
    console.log(`\n${COLORS.cyan}=== 4. DÉMONSTRATION DE DELETE_FILES ===${COLORS.reset}`);
    
    // 4.1 Suppression de fichiers
    console.log(`\n${COLORS.yellow}4.1 Suppression de fichiers${COLORS.reset}`);
    console.log(`Suppression de to-delete1.tmp et to-delete2.tmp`);
    
    // Vérifier l'existence des fichiers avant suppression
    try {
      const fileExists1 = await fileExists(path.join(DEMO_DIR, 'to-delete1.tmp'));
      const fileExists2 = await fileExists(path.join(DEMO_DIR, 'to-delete2.tmp'));
      console.log(`${COLORS.blue}Avant suppression:${COLORS.reset}`);
      console.log(`to-delete1.tmp existe: ${fileExists1}`);
      console.log(`to-delete2.tmp existe: ${fileExists2}`);
    } catch (error) {
      console.log(`${COLORS.red}Erreur lors de la vérification des fichiers: ${error.message}${COLORS.reset}`);
    }
    
    // Dans un environnement Roo, on utiliserait:
    /*
    const deleteResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "delete_files",
      arguments: {
        paths: [
          path.join(DEMO_DIR, 'to-delete1.tmp'),
          path.join(DEMO_DIR, 'to-delete2.tmp')
        ]
      }
    });
    */
    
    console.log(`\n${COLORS.green}=== DÉMONSTRATION TERMINÉE ===\n${COLORS.reset}`);
    console.log(`${COLORS.yellow}Note: Ce script est conçu pour être exécuté dans l'environnement Roo.${COLORS.reset}`);
    console.log(`${COLORS.yellow}Les appels réels à l'API MCP sont commentés dans le code source.${COLORS.reset}`);
    console.log(`${COLORS.yellow}Pour une démonstration complète, utilisez le script demo-quickfiles-mcp.js${COLORS.reset}`);
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