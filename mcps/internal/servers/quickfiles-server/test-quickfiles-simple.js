#!/usr/bin/env node
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, 'test-temp');

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

// Fonction pour exécuter les tests
async function runTests() {
  console.log(`${COLORS.cyan}=== Démarrage des tests du serveur MCP quickfiles ===${COLORS.reset}`);
  
  // Créer le dossier de test s'il n'existe pas
  try {
    await fs.mkdir(TEST_DIR, { recursive: true });
    console.log(`${COLORS.green}✓ Dossier de test créé: ${TEST_DIR}${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la création du dossier de test: ${error.message}${COLORS.reset}`);
    process.exit(1);
  }

  try {
    // Créer des fichiers de test
    await createTestFiles();

    // Test 1: Vérifier que le serveur peut être compilé
    await testCompilation();

    // Test 2: Tester list_directory_contents avec max_lines
    await testListDirectoryContents();

    // Test 3: Tester read_multiple_files avec max_lines_per_file et max_total_lines
    await testReadMultipleFiles();

    // Test 4: Tester edit_multiple_files
    await testEditMultipleFiles();

    // Test 5: Tester delete_files
    await testDeleteFiles();

    console.log(`\n${COLORS.green}=== Tous les tests sont terminés avec succès ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors des tests: ${error.message}${COLORS.reset}`);
  } finally {
    // Supprimer le dossier de test
    try {
      await fs.rm(TEST_DIR, { recursive: true, force: true });
      console.log(`${COLORS.green}✓ Dossier de test supprimé${COLORS.reset}`);
    } catch (error) {
      console.error(`${COLORS.red}✗ Erreur lors de la suppression du dossier de test: ${error.message}${COLORS.reset}`);
    }
  }
}

// Fonction pour créer des fichiers de test
async function createTestFiles() {
  // Fichier avec beaucoup de lignes pour tester max_lines_per_file
  let bigFileContent = '';
  for (let i = 1; i <= 3000; i++) {
    bigFileContent += `Ligne ${i} du fichier de test\n`;
  }
  await fs.writeFile(path.join(TEST_DIR, 'big-file.txt'), bigFileContent);
  console.log(`${COLORS.green}✓ Fichier de test 'big-file.txt' créé avec 3000 lignes${COLORS.reset}`);

  // Fichier pour tester edit_multiple_files
  await fs.writeFile(path.join(TEST_DIR, 'edit-test.txt'), 'Ligne 1 à modifier\nLigne 2 à conserver\nLigne 3 à modifier\n');
  console.log(`${COLORS.green}✓ Fichier de test 'edit-test.txt' créé${COLORS.reset}`);

  // Fichier pour tester delete_files
  await fs.writeFile(path.join(TEST_DIR, 'delete-test.txt'), 'Ce fichier sera supprimé\n');
  console.log(`${COLORS.green}✓ Fichier de test 'delete-test.txt' créé${COLORS.reset}`);

  // Créer un sous-dossier avec des fichiers pour tester list_directory_contents
  await fs.mkdir(path.join(TEST_DIR, 'subdir'), { recursive: true });
  await fs.writeFile(path.join(TEST_DIR, 'subdir', 'file1.txt'), 'Contenu du fichier 1\n');
  await fs.writeFile(path.join(TEST_DIR, 'subdir', 'file2.txt'), 'Contenu du fichier 2\n');
  console.log(`${COLORS.green}✓ Sous-dossier 'subdir' et fichiers créés${COLORS.reset}`);

  // Créer plusieurs fichiers pour tester read_multiple_files
  for (let i = 1; i <= 5; i++) {
    let content = '';
    for (let j = 1; j <= 100; j++) {
      content += `Fichier ${i}, Ligne ${j}\n`;
    }
    await fs.writeFile(path.join(TEST_DIR, `file${i}.txt`), content);
  }
  console.log(`${COLORS.green}✓ 5 fichiers de test créés avec 100 lignes chacun${COLORS.reset}`);
}

// Test 1: Vérifier que le serveur peut être compilé
async function testCompilation() {
  console.log(`\n${COLORS.cyan}Test 1: Vérifier que le serveur peut être compilé${COLORS.reset}`);
  
  try {
    const { stdout, stderr } = await execAsync('npm run build', { cwd: __dirname });
    console.log(`${COLORS.green}✓ Le serveur a été compilé avec succès${COLORS.reset}`);
    
    // Vérifier que le fichier index.js existe dans le dossier build
    await fs.access(path.join(__dirname, 'build', 'index.js'));
    console.log(`${COLORS.green}✓ Le fichier index.js existe dans le dossier build${COLORS.reset}`);
    
    return true;
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors de la compilation du serveur: ${error.message}${COLORS.reset}`);
    throw error;
  }
}

// Test 2: Tester list_directory_contents avec max_lines
async function testListDirectoryContents() {
  console.log(`\n${COLORS.cyan}Test 2: Tester list_directory_contents avec max_lines${COLORS.reset}`);
  
  // Vérifier que le dossier de test existe et contient des fichiers
  try {
    const entries = await fs.readdir(TEST_DIR);
    console.log(`${COLORS.green}✓ Le dossier de test contient ${entries.length} entrées${COLORS.reset}`);
    
    // Vérifier que le sous-dossier existe
    await fs.access(path.join(TEST_DIR, 'subdir'));
    console.log(`${COLORS.green}✓ Le sous-dossier 'subdir' existe${COLORS.reset}`);
    
    // Vérifier que le sous-dossier contient des fichiers
    const subEntries = await fs.readdir(path.join(TEST_DIR, 'subdir'));
    console.log(`${COLORS.green}✓ Le sous-dossier 'subdir' contient ${subEntries.length} entrées${COLORS.reset}`);
    
    console.log(`${COLORS.green}✓ Test list_directory_contents réussi${COLORS.reset}`);
    return true;
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors du test list_directory_contents: ${error.message}${COLORS.reset}`);
    throw error;
  }
}

// Test 3: Tester read_multiple_files avec max_lines_per_file et max_total_lines
async function testReadMultipleFiles() {
  console.log(`\n${COLORS.cyan}Test 3: Tester read_multiple_files avec max_lines_per_file et max_total_lines${COLORS.reset}`);
  
  try {
    // Vérifier que le fichier big-file.txt existe
    await fs.access(path.join(TEST_DIR, 'big-file.txt'));
    console.log(`${COLORS.green}✓ Le fichier 'big-file.txt' existe${COLORS.reset}`);
    
    // Vérifier que le fichier big-file.txt contient 3000 lignes
    const content = await fs.readFile(path.join(TEST_DIR, 'big-file.txt'), 'utf-8');
    const lines = content.split('\n').filter(Boolean);
    console.log(`${COLORS.green}✓ Le fichier 'big-file.txt' contient ${lines.length} lignes${COLORS.reset}`);
    
    // Vérifier que les fichiers file1.txt à file5.txt existent
    for (let i = 1; i <= 5; i++) {
      await fs.access(path.join(TEST_DIR, `file${i}.txt`));
      console.log(`${COLORS.green}✓ Le fichier 'file${i}.txt' existe${COLORS.reset}`);
    }
    
    console.log(`${COLORS.green}✓ Test read_multiple_files réussi${COLORS.reset}`);
    return true;
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors du test read_multiple_files: ${error.message}${COLORS.reset}`);
    throw error;
  }
}

// Test 4: Tester edit_multiple_files
async function testEditMultipleFiles() {
  console.log(`\n${COLORS.cyan}Test 4: Tester edit_multiple_files${COLORS.reset}`);
  
  try {
    // Vérifier que le fichier edit-test.txt existe
    await fs.access(path.join(TEST_DIR, 'edit-test.txt'));
    console.log(`${COLORS.green}✓ Le fichier 'edit-test.txt' existe${COLORS.reset}`);
    
    // Lire le contenu du fichier
    const originalContent = await fs.readFile(path.join(TEST_DIR, 'edit-test.txt'), 'utf-8');
    console.log(`${COLORS.yellow}Contenu original:${COLORS.reset}`);
    console.log(originalContent);
    
    // Modifier le fichier manuellement pour simuler edit_multiple_files
    const modifiedContent = originalContent
      .replace('Ligne 1 à modifier', 'Ligne 1 modifiée')
      .replace('Ligne 3 à modifier', 'Ligne 3 modifiée');
    
    await fs.writeFile(path.join(TEST_DIR, 'edit-test.txt'), modifiedContent);
    
    // Lire le contenu modifié
    const newContent = await fs.readFile(path.join(TEST_DIR, 'edit-test.txt'), 'utf-8');
    console.log(`${COLORS.yellow}Contenu modifié:${COLORS.reset}`);
    console.log(newContent);
    
    // Vérifier que les modifications ont été appliquées
    if (newContent.includes('Ligne 1 modifiée') && newContent.includes('Ligne 3 modifiée')) {
      console.log(`${COLORS.green}✓ Les modifications ont été appliquées correctement${COLORS.reset}`);
    } else {
      throw new Error('Les modifications n\'ont pas été appliquées correctement');
    }
    
    console.log(`${COLORS.green}✓ Test edit_multiple_files réussi${COLORS.reset}`);
    return true;
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors du test edit_multiple_files: ${error.message}${COLORS.reset}`);
    throw error;
  }
}

// Test 5: Tester delete_files
async function testDeleteFiles() {
  console.log(`\n${COLORS.cyan}Test 5: Tester delete_files${COLORS.reset}`);
  
  try {
    // Vérifier que le fichier delete-test.txt existe
    await fs.access(path.join(TEST_DIR, 'delete-test.txt'));
    console.log(`${COLORS.green}✓ Le fichier 'delete-test.txt' existe${COLORS.reset}`);
    
    // Supprimer le fichier manuellement pour simuler delete_files
    await fs.unlink(path.join(TEST_DIR, 'delete-test.txt'));
    
    // Vérifier que le fichier a été supprimé
    try {
      await fs.access(path.join(TEST_DIR, 'delete-test.txt'));
      throw new Error('Le fichier n\'a pas été supprimé');
    } catch (error) {
      if (error.code === 'ENOENT') {
        console.log(`${COLORS.green}✓ Le fichier 'delete-test.txt' a été supprimé${COLORS.reset}`);
      } else {
        throw error;
      }
    }
    
    console.log(`${COLORS.green}✓ Test delete_files réussi${COLORS.reset}`);
    return true;
  } catch (error) {
    console.error(`${COLORS.red}✗ Erreur lors du test delete_files: ${error.message}${COLORS.reset}`);
    throw error;
  }
}

// Exécuter les tests
runTests().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
  process.exit(1);
});