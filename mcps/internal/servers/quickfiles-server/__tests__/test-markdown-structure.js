/**
 * Test des fonctionnalités d'extraction de structure markdown
 * 
 * Ce script teste les nouvelles fonctionnalités d'extraction de structure markdown
 * ajoutées au MCP Quickfiles.
 */

const { McpClient } = require('@modelcontextprotocol/sdk/client');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;

// Chemin vers le serveur MCP Quickfiles
const serverPath = path.join(__dirname, '..', 'src', 'index.ts');

// Créer un fichier markdown de test
async function createTestMarkdownFile() {
  const testDir = path.join(__dirname, 'test-markdown');
  const testFile = path.join(testDir, 'test.md');
  
  // Créer le répertoire de test s'il n'existe pas
  try {
    await fs.mkdir(testDir, { recursive: true });
  } catch (error) {
    console.error(`Erreur lors de la création du répertoire de test: ${error.message}`);
  }
  
  // Contenu du fichier markdown de test
  const content = `# Titre principal

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
`;
  
  // Écrire le contenu dans le fichier
  await fs.writeFile(testFile, content, 'utf-8');
  
  return { testDir, testFile };
}

// Fonction principale de test
async function runTests() {
  console.log('Démarrage des tests des fonctionnalités d\'extraction de structure markdown...');
  
  // Créer le fichier markdown de test
  const { testDir, testFile } = await createTestMarkdownFile();
  console.log(`Fichier markdown de test créé: ${testFile}`);
  
  // Démarrer le serveur MCP Quickfiles
  const server = spawn('ts-node', [serverPath], {
    stdio: ['pipe', 'pipe', process.stderr]
  });
  
  // Attendre que le serveur soit prêt
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Créer un client MCP
  const transport = new StdioClientTransport(server.stdin, server.stdout);
  const client = new McpClient();
  await client.connect(transport);
  
  try {
    // Test 1: Extraction de la structure markdown
    console.log('\nTest 1: Extraction de la structure markdown');
    const extractResult = await client.callTool('extract_markdown_structure', {
      paths: [testFile],
      max_depth: 6,
      include_context: true,
      context_lines: 2
    });
    
    console.log('Résultat de l\'extraction de structure markdown:');
    console.log(extractResult.content[0].text);
    
    // Test 2: Liste des répertoires avec informations sur la structure markdown
    console.log('\nTest 2: Liste des répertoires avec informations sur la structure markdown');
    const listResult = await client.callTool('list_directory_contents', {
      paths: [testDir],
      max_lines: 100
    });
    
    console.log('Résultat du listage de répertoire avec informations sur la structure markdown:');
    console.log(listResult.content[0].text);
    
    console.log('\nTous les tests ont été exécutés avec succès!');
  } catch (error) {
    console.error(`Erreur lors de l'exécution des tests: ${error.message}`);
  } finally {
    // Fermer la connexion et arrêter le serveur
    await client.close();
    server.kill();
    
    // Nettoyer les fichiers de test
    try {
      await fs.unlink(testFile);
      await fs.rmdir(testDir);
      console.log('Fichiers de test nettoyés');
    } catch (error) {
      console.error(`Erreur lors du nettoyage des fichiers de test: ${error.message}`);
    }
  }
}

// Exécuter les tests
runTests().catch(console.error);