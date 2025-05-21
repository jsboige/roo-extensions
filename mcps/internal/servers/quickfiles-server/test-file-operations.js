/**
 * Script de test pour les opérations de fichiers avancées du serveur QuickFiles
 * 
 * Ce script teste manuellement les fonctionnalités des outils copy_files et move_files
 * en simulant des requêtes MCP.
 */

import { QuickFilesServer } from './build/index.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test
const TEST_DIR = path.join(__dirname, 'test-dirs');
const SOURCE_DIR = path.join(TEST_DIR, 'source');
const DEST_DIR = path.join(TEST_DIR, 'destination');

// Fonction pour créer une requête MCP simulée
const mockRequest = (name, args) => ({
  params: {
    name,
    arguments: args
  }
});

// Fonction pour afficher le résultat d'une requête
const displayResult = (result) => {
  console.log('\nRésultat:');
  if (result.content && result.content.length > 0) {
    console.log(result.content[0].text);
  } else {
    console.log('Pas de contenu dans la réponse');
  }
  
  if (result.isError) {
    console.log('ERREUR:', result.isError);
  }
};

// Fonction principale
async function main() {
  try {
    // Créer les répertoires de test
    await fs.mkdir(SOURCE_DIR, { recursive: true });
    await fs.mkdir(DEST_DIR, { recursive: true });
    
    // Créer quelques fichiers de test
    await fs.writeFile(path.join(SOURCE_DIR, 'file1.txt'), 'Contenu du fichier 1');
    await fs.writeFile(path.join(SOURCE_DIR, 'file2.txt'), 'Contenu du fichier 2');
    await fs.writeFile(path.join(SOURCE_DIR, 'document.md'), '# Titre markdown');
    await fs.writeFile(path.join(DEST_DIR, 'existing.txt'), 'Fichier existant');
    
    // Créer une instance du serveur QuickFiles
    const server = new QuickFilesServer();
    
    console.log('=== Test de copy_files ===');
    
    // Test 1: Copier un fichier simple
    console.log('\nTest 1: Copier un fichier simple');
    const copyRequest1 = mockRequest('copy_files', {
      operations: [{
        source: path.join(SOURCE_DIR, 'file1.txt'),
        destination: path.join(DEST_DIR, 'file1_copy.txt')
      }]
    });
    
    const copyResult1 = await server.handleCopyFiles(copyRequest1);
    displayResult(copyResult1);
    
    // Test 2: Copier avec motif glob
    console.log('\nTest 2: Copier avec motif glob');
    const copyRequest2 = mockRequest('copy_files', {
      operations: [{
        source: path.join(SOURCE_DIR, '*.txt'),
        destination: path.join(DEST_DIR, 'glob/')
      }]
    });
    
    const copyResult2 = await server.handleCopyFiles(copyRequest2);
    displayResult(copyResult2);
    
    // Test 3: Copier avec transformation
    console.log('\nTest 3: Copier avec transformation');
    const copyRequest3 = mockRequest('copy_files', {
      operations: [{
        source: path.join(SOURCE_DIR, '*.txt'),
        destination: path.join(DEST_DIR, 'transform/'),
        transform: {
          pattern: 'file(\\d+)',
          replacement: 'document$1'
        }
      }]
    });
    
    const copyResult3 = await server.handleCopyFiles(copyRequest3);
    displayResult(copyResult3);
    
    // Test 4: Copier avec conflit (overwrite)
    console.log('\nTest 4: Copier avec conflit (overwrite)');
    const copyRequest4 = mockRequest('copy_files', {
      operations: [{
        source: path.join(SOURCE_DIR, 'file1.txt'),
        destination: path.join(DEST_DIR, 'existing.txt'),
        conflict_strategy: 'overwrite'
      }]
    });
    
    const copyResult4 = await server.handleCopyFiles(copyRequest4);
    displayResult(copyResult4);
    
    // Restaurer le fichier existant pour le prochain test
    await fs.writeFile(path.join(DEST_DIR, 'existing.txt'), 'Fichier existant');
    
    // Test 5: Copier avec conflit (rename)
    console.log('\nTest 5: Copier avec conflit (rename)');
    const copyRequest5 = mockRequest('copy_files', {
      operations: [{
        source: path.join(SOURCE_DIR, 'file1.txt'),
        destination: path.join(DEST_DIR, 'existing.txt'),
        conflict_strategy: 'rename'
      }]
    });
    
    const copyResult5 = await server.handleCopyFiles(copyRequest5);
    displayResult(copyResult5);
    
    console.log('\n=== Test de move_files ===');
    
    // Test 6: Déplacer un fichier simple
    console.log('\nTest 6: Déplacer un fichier simple');
    const moveRequest1 = mockRequest('move_files', {
      operations: [{
        source: path.join(SOURCE_DIR, 'document.md'),
        destination: path.join(DEST_DIR, 'document_moved.md')
      }]
    });
    
    const moveResult1 = await server.handleMoveFiles(moveRequest1);
    displayResult(moveResult1);
    
    // Recréer le fichier pour les tests suivants
    await fs.writeFile(path.join(SOURCE_DIR, 'document.md'), '# Titre markdown');
    
    // Test 7: Déplacer avec transformation
    console.log('\nTest 7: Déplacer avec transformation');
    const moveRequest2 = mockRequest('move_files', {
      operations: [{
        source: path.join(SOURCE_DIR, 'document.md'),
        destination: path.join(DEST_DIR, 'transform/'),
        transform: {
          pattern: '(.*)\\.md',
          replacement: '$1.markdown'
        }
      }]
    });
    
    const moveResult2 = await server.handleMoveFiles(moveRequest2);
    displayResult(moveResult2);
    
    console.log('\nTests terminés. Vérifiez les fichiers dans:', DEST_DIR);
    
  } catch (error) {
    console.error('Erreur lors des tests:', error);
  }
}

// Exécuter le script
main().catch(console.error);