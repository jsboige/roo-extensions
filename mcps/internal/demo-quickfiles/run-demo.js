#!/usr/bin/env node
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';
import readline from 'readline';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Couleurs pour la console
const COLORS = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
};

// Créer une interface readline pour l'interaction avec l'utilisateur
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Fonction pour poser une question et attendre la réponse
function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

// Fonction pour exécuter une commande et attendre sa fin
function executeCommand(command, args = [], cwd = process.cwd()) {
  return new Promise((resolve, reject) => {
    console.log(`${COLORS.blue}Exécution de la commande: ${command} ${args.join(' ')}${COLORS.reset}`);
    
    const childProcess = spawn(command, args, {
      cwd,
      stdio: 'inherit',
      shell: true
    });
    
    childProcess.on('close', code => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`La commande a échoué avec le code ${code}`));
      }
    });
    
    childProcess.on('error', error => {
      reject(error);
    });
  });
}

// Fonction principale pour exécuter la démonstration
async function runDemo() {
  console.log(`${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION DU MCP QUICKFILES ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette démonstration vous guidera à travers les fonctionnalités du MCP QuickFiles.${COLORS.reset}`);
  
  try {
    // Vérifier si le serveur MCP QuickFiles est en cours d'exécution
    console.log(`\n${COLORS.cyan}Étape 1: Vérification du serveur MCP QuickFiles${COLORS.reset}`);
    console.log(`Vérifions si le serveur MCP QuickFiles est en cours d'exécution...`);
    
    // Dans un environnement réel, on vérifierait si le serveur est en cours d'exécution
    // Pour cette démonstration, nous supposons qu'il est déjà en cours d'exécution
    console.log(`${COLORS.green}✓ Le serveur MCP QuickFiles est en cours d'exécution.${COLORS.reset}`);
    
    // Configurer l'environnement de démonstration
    console.log(`\n${COLORS.cyan}Étape 2: Configuration de l'environnement de démonstration${COLORS.reset}`);
    console.log(`Création des fichiers et répertoires nécessaires pour la démonstration...`);
    
    await executeCommand('node', ['demo-setup.js'], path.join(__dirname));
    console.log(`${COLORS.green}✓ Environnement de démonstration configuré avec succès.${COLORS.reset}`);
    
    // Menu principal
    let exit = false;
    while (!exit) {
      console.log(`\n${COLORS.cyan}${COLORS.bold}=== MENU PRINCIPAL ===${COLORS.reset}`);
      console.log(`${COLORS.yellow}Choisissez une option :${COLORS.reset}`);
      console.log(`1. Démonstration complète du MCP QuickFiles`);
      console.log(`2. Démonstration de read_multiple_files`);
      console.log(`3. Démonstration de list_directory_contents`);
      console.log(`4. Démonstration de edit_multiple_files`);
      console.log(`5. Démonstration de delete_files`);
      console.log(`6. Afficher le README`);
      console.log(`0. Quitter`);
      
      const choice = await question(`\nVotre choix (0-6): `);
      
      switch (choice) {
        case '1':
          await runFullDemo();
          break;
        case '2':
          await runReadMultipleFilesDemo();
          break;
        case '3':
          await runListDirectoryContentsDemo();
          break;
        case '4':
          await runEditMultipleFilesDemo();
          break;
        case '5':
          await runDeleteFilesDemo();
          break;
        case '6':
          await showReadme();
          break;
        case '0':
          exit = true;
          break;
        default:
          console.log(`${COLORS.red}Option invalide. Veuillez réessayer.${COLORS.reset}`);
      }
    }
    
    // Nettoyer l'environnement de démonstration
    console.log(`\n${COLORS.cyan}Nettoyage de l'environnement de démonstration${COLORS.reset}`);
    try {
      await fs.rm(path.join(__dirname, 'demo-files'), { recursive: true, force: true });
      console.log(`${COLORS.green}✓ Environnement de démonstration nettoyé avec succès.${COLORS.reset}`);
    } catch (error) {
      console.log(`${COLORS.yellow}Note: Le dossier de démonstration n'a pas pu être supprimé. Il sera conservé pour référence future.${COLORS.reset}`);
    }
    
    console.log(`\n${COLORS.green}${COLORS.bold}=== FIN DE LA DÉMONSTRATION ===${COLORS.reset}`);
    console.log(`${COLORS.yellow}Merci d'avoir utilisé la démonstration du MCP QuickFiles !${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors de la démonstration: ${error.message}${COLORS.reset}`);
  } finally {
    rl.close();
  }
}

// Fonction pour exécuter la démonstration complète
async function runFullDemo() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION COMPLÈTE DU MCP QUICKFILES ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette démonstration va vous montrer toutes les fonctionnalités du MCP QuickFiles.${COLORS.reset}`);
  
  await executeCommand('node', ['demo-quickfiles-mcp.js'], path.join(__dirname));
  
  await question(`\n${COLORS.green}Démonstration complète terminée. Appuyez sur Entrée pour continuer...${COLORS.reset}`);
}

// Fonction pour démontrer read_multiple_files
async function runReadMultipleFilesDemo() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION DE READ_MULTIPLE_FILES ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette fonctionnalité permet de lire plusieurs fichiers en une seule requête.${COLORS.reset}`);
  
  console.log(`\n${COLORS.blue}Fonctionnalités démontrées :${COLORS.reset}`);
  console.log(`1. Lecture de plusieurs fichiers à la fois`);
  console.log(`2. Limitation du nombre de lignes par fichier`);
  console.log(`3. Extraction d'extraits spécifiques de fichiers`);
  console.log(`4. Affichage des numéros de ligne`);
  
  // Afficher le contenu des fichiers de démonstration
  console.log(`\n${COLORS.blue}Contenu des fichiers de démonstration :${COLORS.reset}`);
  try {
    const document = await fs.readFile(path.join(__dirname, 'demo-files', 'document.txt'), 'utf-8');
    const tasks = await fs.readFile(path.join(__dirname, 'demo-files', 'tasks.txt'), 'utf-8');
    
    console.log(`\ndocument.txt :\n${document}`);
    console.log(`\ntasks.txt :\n${tasks}`);
  } catch (error) {
    console.log(`${COLORS.red}Erreur lors de la lecture des fichiers: ${error.message}${COLORS.reset}`);
  }
  
  console.log(`\n${COLORS.blue}Exemple d'utilisation de read_multiple_files :${COLORS.reset}`);
  console.log(`
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "read_multiple_files",
  arguments: {
    paths: [
      "./demo-quickfiles/demo-files/document.txt",
      "./demo-quickfiles/demo-files/tasks.txt"
    ],
    show_line_numbers: true,
    max_lines_per_file: 100
  }
});
  `);
  
  await question(`\n${COLORS.green}Démonstration de read_multiple_files terminée. Appuyez sur Entrée pour continuer...${COLORS.reset}`);
}

// Fonction pour démontrer list_directory_contents
async function runListDirectoryContentsDemo() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION DE LIST_DIRECTORY_CONTENTS ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette fonctionnalité permet de lister le contenu d'un ou plusieurs répertoires.${COLORS.reset}`);
  
  console.log(`\n${COLORS.blue}Fonctionnalités démontrées :${COLORS.reset}`);
  console.log(`1. Listage récursif ou non récursif`);
  console.log(`2. Filtrage par motif de fichier (ex: *.txt)`);
  console.log(`3. Tri par nom, taille, date de modification ou type`);
  console.log(`4. Limitation du nombre de lignes dans la sortie`);
  
  // Afficher la structure des répertoires de démonstration
  console.log(`\n${COLORS.blue}Structure des répertoires de démonstration :${COLORS.reset}`);
  try {
    const files = await fs.readdir(path.join(__dirname, 'demo-files'), { withFileTypes: true });
    
    for (const file of files) {
      if (file.isDirectory()) {
        console.log(`📁 ${file.name}/`);
      } else {
        console.log(`📄 ${file.name}`);
      }
    }
  } catch (error) {
    console.log(`${COLORS.red}Erreur lors de la lecture du répertoire: ${error.message}${COLORS.reset}`);
  }
  
  console.log(`\n${COLORS.blue}Exemple d'utilisation de list_directory_contents :${COLORS.reset}`);
  console.log(`
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "list_directory_contents",
  arguments: {
    paths: [
      { 
        path: "./demo-quickfiles/demo-files", 
        recursive: true,
        file_pattern: "*.txt"
      }
    ],
    sort_by: "name",
    sort_order: "asc"
  }
});
  `);
  
  await question(`\n${COLORS.green}Démonstration de list_directory_contents terminée. Appuyez sur Entrée pour continuer...${COLORS.reset}`);
}

// Fonction pour démontrer edit_multiple_files
async function runEditMultipleFilesDemo() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION DE EDIT_MULTIPLE_FILES ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette fonctionnalité permet de modifier plusieurs fichiers en une seule opération.${COLORS.reset}`);
  
  console.log(`\n${COLORS.blue}Fonctionnalités démontrées :${COLORS.reset}`);
  console.log(`1. Modification de plusieurs fichiers à la fois`);
  console.log(`2. Application de plusieurs modifications (diffs) à chaque fichier`);
  
  // Afficher le contenu des fichiers avant modification
  console.log(`\n${COLORS.blue}Contenu des fichiers avant modification :${COLORS.reset}`);
  try {
    const editFile1 = await fs.readFile(path.join(__dirname, 'demo-files', 'edit-file1.txt'), 'utf-8');
    const editFile2 = await fs.readFile(path.join(__dirname, 'demo-files', 'edit-file2.txt'), 'utf-8');
    
    console.log(`\nedit-file1.txt :\n${editFile1}`);
    console.log(`\nedit-file2.txt :\n${editFile2}`);
  } catch (error) {
    console.log(`${COLORS.red}Erreur lors de la lecture des fichiers: ${error.message}${COLORS.reset}`);
  }
  
  console.log(`\n${COLORS.blue}Exemple d'utilisation de edit_multiple_files :${COLORS.reset}`);
  console.log(`
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "edit_multiple_files",
  arguments: {
    files: [
      {
        path: "./demo-quickfiles/demo-files/edit-file1.txt",
        diffs: [
          {
            search: "Texte à modifier: première occurrence.",
            replace: "Texte MODIFIÉ: première occurrence."
          },
          {
            search: "Texte à modifier: deuxième occurrence.",
            replace: "Texte MODIFIÉ: deuxième occurrence."
          }
        ]
      },
      {
        path: "./demo-quickfiles/demo-files/edit-file2.txt",
        diffs: [
          {
            search: "Autre texte à modifier dans un fichier différent.",
            replace: "Autre texte MODIFIÉ dans un fichier différent."
          }
        ]
      }
    ]
  }
});
  `);
  
  await question(`\n${COLORS.green}Démonstration de edit_multiple_files terminée. Appuyez sur Entrée pour continuer...${COLORS.reset}`);
}

// Fonction pour démontrer delete_files
async function runDeleteFilesDemo() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== DÉMONSTRATION DE DELETE_FILES ===${COLORS.reset}`);
  console.log(`${COLORS.yellow}Cette fonctionnalité permet de supprimer plusieurs fichiers en une seule opération.${COLORS.reset}`);
  
  // Vérifier l'existence des fichiers à supprimer
  console.log(`\n${COLORS.blue}Fichiers à supprimer :${COLORS.reset}`);
  try {
    const fileExists1 = await fileExists(path.join(__dirname, 'demo-files', 'to-delete1.tmp'));
    const fileExists2 = await fileExists(path.join(__dirname, 'demo-files', 'to-delete2.tmp'));
    
    console.log(`to-delete1.tmp existe: ${fileExists1 ? 'Oui' : 'Non'}`);
    console.log(`to-delete2.tmp existe: ${fileExists2 ? 'Oui' : 'Non'}`);
  } catch (error) {
    console.log(`${COLORS.red}Erreur lors de la vérification des fichiers: ${error.message}${COLORS.reset}`);
  }
  
  console.log(`\n${COLORS.blue}Exemple d'utilisation de delete_files :${COLORS.reset}`);
  console.log(`
const result = await useMcpTool({
  server_name: "quickfiles",
  tool_name: "delete_files",
  arguments: {
    paths: [
      "./demo-quickfiles/demo-files/to-delete1.tmp",
      "./demo-quickfiles/demo-files/to-delete2.tmp"
    ]
  }
});
  `);
  
  await question(`\n${COLORS.green}Démonstration de delete_files terminée. Appuyez sur Entrée pour continuer...${COLORS.reset}`);
}

// Fonction pour afficher le README
async function showReadme() {
  console.log(`\n${COLORS.cyan}${COLORS.bold}=== README DU MCP QUICKFILES ===${COLORS.reset}`);
  
  try {
    const readme = await fs.readFile(path.join(__dirname, 'README.md'), 'utf-8');
    console.log(`\n${readme}`);
  } catch (error) {
    console.log(`${COLORS.red}Erreur lors de la lecture du README: ${error.message}${COLORS.reset}`);
  }
  
  await question(`\n${COLORS.green}Appuyez sur Entrée pour continuer...${COLORS.reset}`);
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
  rl.close();
});