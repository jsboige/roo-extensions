/**
 * Script de test intégré pour les nouvelles fonctionnalités du MCP Quickfiles
 * 
 * Ce script teste l'ensemble des nouvelles fonctionnalités qui ont été implémentées:
 * 1. Extraction de structure markdown
 * 2. Opérations de fichiers avancées
 * 3. Recherche et remplacement avancés
 */

import { McpClient } from '@modelcontextprotocol/sdk/client';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio';
import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs/promises';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le serveur MCP Quickfiles
const serverPath = path.join(__dirname, 'src', 'index.ts');

// Chemin vers le dossier de test
const TEST_DIR = path.join(__dirname, 'test-integration');
const SOURCE_DIR = path.join(TEST_DIR, 'source');
const DEST_DIR = path.join(TEST_DIR, 'destination');
const MARKDOWN_DIR = path.join(TEST_DIR, 'markdown');

// Fonction pour créer les fichiers de test
async function createTestFiles() {
  console.log('Création des fichiers de test...');
  
  // Créer les répertoires de test
  await fs.mkdir(SOURCE_DIR, { recursive: true });
  await fs.mkdir(DEST_DIR, { recursive: true });
  await fs.mkdir(MARKDOWN_DIR, { recursive: true });
  
  // Créer des fichiers texte pour les tests de recherche et remplacement
  await fs.writeFile(path.join(SOURCE_DIR, 'file1.txt'), 
    'Ceci est un exemple de texte.\nIl contient plusieurs lignes.\nCertaines lignes contiennent le mot exemple.');
  await fs.writeFile(path.join(SOURCE_DIR, 'file2.txt'), 
    'Un autre fichier texte.\nSans le mot recherché.');
  
  // Créer des fichiers pour les tests d'opérations de fichiers
  await fs.writeFile(path.join(SOURCE_DIR, 'copy-test.txt'), 'Contenu à copier');
  await fs.writeFile(path.join(SOURCE_DIR, 'move-test.txt'), 'Contenu à déplacer');
  
  // Créer un fichier markdown pour les tests d'extraction de structure
  await fs.writeFile(path.join(MARKDOWN_DIR, 'document.md'), 
    `# Titre principal

Ce document est un test pour l'extraction de structure markdown.

## Section 1

Contenu de la section 1.

### Sous-section 1.1

Contenu de la sous-section 1.1.

## Section 2

Contenu de la section 2.

### Sous-section 2.1

Contenu de la sous-section 2.1.

#### Sous-sous-section 2.1.1

Contenu de la sous-sous-section 2.1.1.

## Section 3

Contenu de la section 3.
`);

  console.log('Fichiers de test créés avec succès.');
}

// Fonction principale de test
async function runTests() {
  console.log('=== Test intégré des nouvelles fonctionnalités du MCP Quickfiles ===\n');
  
  try {
    // Créer les fichiers de test
    await createTestFiles();
    
    // Démarrer le serveur MCP Quickfiles
    console.log('Démarrage du serveur MCP Quickfiles...');
    const server = spawn('ts-node', [serverPath], {
      stdio: ['pipe', 'pipe', process.stderr]
    });
    
    // Attendre que le serveur soit prêt
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Créer un client MCP
    const transport = new StdioClientTransport(server.stdin, server.stdout);
    const client = new McpClient();
    await client.connect(transport);
    
    console.log('Connexion au serveur établie.\n');
    
    try {
      // Test 1: Extraction de structure markdown
      console.log('=== Test 1: Extraction de structure markdown ===');
      const extractResult = await client.callTool('extract_markdown_structure', {
        paths: [path.join(MARKDOWN_DIR, 'document.md')],
        max_depth: 6,
        include_context: true,
        context_lines: 2
      });
      
      console.log('Résultat de l\'extraction de structure markdown:');
      console.log(extractResult.content[0].text);
      console.log('\nTest 1 réussi ✅\n');
      
      // Test 2: Liste des répertoires avec informations sur la structure markdown
      console.log('=== Test 2: Liste des répertoires avec informations sur la structure markdown ===');
      const listResult = await client.callTool('list_directory_contents', {
        paths: [MARKDOWN_DIR],
        max_lines: 100
      });
      
      console.log('Résultat du listage de répertoire avec informations sur la structure markdown:');
      console.log(listResult.content[0].text);
      console.log('\nTest 2 réussi ✅\n');
      
      // Test 3: Opérations de fichiers - Copie
      console.log('=== Test 3: Opérations de fichiers - Copie ===');
      const copyResult = await client.callTool('copy_files', {
        operations: [{
          source: path.join(SOURCE_DIR, 'copy-test.txt'),
          destination: path.join(DEST_DIR, 'copy-test-result.txt')
        }]
      });
      
      console.log('Résultat de la copie de fichier:');
      console.log(copyResult.content[0].text);
      
      // Vérifier que le fichier a été copié
      const copyContent = await fs.readFile(path.join(DEST_DIR, 'copy-test-result.txt'), 'utf-8');
      console.log(`Contenu du fichier copié: "${copyContent}"`);
      console.log('\nTest 3 réussi ✅\n');
      
      // Test 4: Opérations de fichiers - Déplacement
      console.log('=== Test 4: Opérations de fichiers - Déplacement ===');
      const moveResult = await client.callTool('move_files', {
        operations: [{
          source: path.join(SOURCE_DIR, 'move-test.txt'),
          destination: path.join(DEST_DIR, 'move-test-result.txt')
        }]
      });
      
      console.log('Résultat du déplacement de fichier:');
      console.log(moveResult.content[0].text);
      
      // Vérifier que le fichier a été déplacé
      const moveContent = await fs.readFile(path.join(DEST_DIR, 'move-test-result.txt'), 'utf-8');
      console.log(`Contenu du fichier déplacé: "${moveContent}"`);
      
      // Vérifier que le fichier source n'existe plus
      let sourceExists = true;
      try {
        await fs.access(path.join(SOURCE_DIR, 'move-test.txt'));
      } catch (error) {
        sourceExists = false;
      }
      console.log(`Fichier source supprimé: ${!sourceExists ? 'Oui' : 'Non'}`);
      console.log('\nTest 4 réussi ✅\n');
      
      // Test 5: Recherche dans les fichiers
      console.log('=== Test 5: Recherche dans les fichiers ===');
      const searchResult = await client.callTool('search_in_files', {
        paths: [SOURCE_DIR],
        pattern: 'exemple',
        use_regex: false,
        case_sensitive: false,
        context_lines: 1
      });
      
      console.log('Résultat de la recherche dans les fichiers:');
      console.log(searchResult.content[0].text);
      console.log('\nTest 5 réussi ✅\n');
      
      // Test 6: Recherche et remplacement
      console.log('=== Test 6: Recherche et remplacement ===');
      const replaceResult = await client.callTool('search_and_replace', {
        paths: [SOURCE_DIR],
        search: 'exemple',
        replace: 'échantillon',
        use_regex: false,
        case_sensitive: false,
        preview: false
      });
      
      console.log('Résultat du remplacement:');
      console.log(replaceResult.content[0].text);
      
      // Vérifier que le remplacement a été effectué
      const replacedContent = await fs.readFile(path.join(SOURCE_DIR, 'file1.txt'), 'utf-8');
      console.log(`Contenu après remplacement: "${replacedContent}"`);
      console.log(`Le mot "échantillon" est présent: ${replacedContent.includes('échantillon') ? 'Oui' : 'Non'}`);
      console.log(`Le mot "exemple" est absent: ${!replacedContent.includes('exemple') ? 'Oui' : 'Non'}`);
      console.log('\nTest 6 réussi ✅\n');
      
      // Test 7: Interactions entre les fonctionnalités
      console.log('=== Test 7: Interactions entre les fonctionnalités ===');
      
      // Créer un fichier markdown avec des termes à remplacer
      await fs.writeFile(path.join(MARKDOWN_DIR, 'interaction-test.md'), 
        `# Test d'interaction
        
Ce document contient le terme exemple qui sera remplacé.

## Section avec exemple

Cette section contient aussi le terme exemple.`);
      
      // Remplacer des termes dans le fichier markdown
      const interactionReplaceResult = await client.callTool('search_and_replace', {
        paths: [MARKDOWN_DIR],
        search: 'exemple',
        replace: 'échantillon',
        use_regex: false,
        case_sensitive: false,
        file_pattern: '*.md'
      });
      
      console.log('Résultat du remplacement dans les fichiers markdown:');
      console.log(interactionReplaceResult.content[0].text);
      
      // Extraire la structure du fichier markdown modifié
      const interactionExtractResult = await client.callTool('extract_markdown_structure', {
        paths: [path.join(MARKDOWN_DIR, 'interaction-test.md')],
        max_depth: 6
      });
      
      console.log('Structure du fichier markdown après remplacement:');
      console.log(interactionExtractResult.content[0].text);
      
      // Vérifier que le contenu a été modifié
      const interactionContent = await fs.readFile(path.join(MARKDOWN_DIR, 'interaction-test.md'), 'utf-8');
      console.log(`Le mot "échantillon" est présent: ${interactionContent.includes('échantillon') ? 'Oui' : 'Non'}`);
      console.log(`Le mot "exemple" est absent: ${!interactionContent.includes('exemple') ? 'Oui' : 'Non'}`);
      console.log('\nTest 7 réussi ✅\n');
      
      console.log('=== Tous les tests ont été exécutés avec succès! ===');
      
    } catch (error) {
      console.error(`Erreur lors de l'exécution des tests: ${error.message}`);
      console.error(error.stack);
    } finally {
      // Fermer la connexion et arrêter le serveur
      await client.close();
      server.kill();
      
      // Nettoyer les fichiers de test
      try {
        await fs.rm(TEST_DIR, { recursive: true, force: true });
        console.log('Fichiers de test nettoyés');
      } catch (error) {
        console.error(`Erreur lors du nettoyage des fichiers de test: ${error.message}`);
      }
    }
  } catch (error) {
    console.error(`Erreur globale: ${error.message}`);
    console.error(error.stack);
  }
}

// Exécuter les tests
runTests().catch(console.error);