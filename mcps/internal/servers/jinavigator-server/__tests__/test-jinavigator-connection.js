// Script de test pour vérifier la connexion au serveur MCP Jinavigator

// Importation des modules nécessaires
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel (équivalent à __dirname en CommonJS)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  console.log('Test de connexion au serveur MCP Jinavigator...');
  
  // Chemin vers le script run-node-fixed.bat
  const scriptPath = path.join(__dirname, 'servers', 'jinavigator-server', 'run-node-fixed.bat');
  
  // Chemin vers le fichier index.js
  const indexPath = path.join(__dirname, 'servers', 'jinavigator-server', 'dist', 'index.js');
  
  console.log(`Lancement du serveur avec: cmd /c ${scriptPath} ${indexPath}`);
  
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
  
  try {
    // Création du client MCP avec les informations du client
    const client = new Client({
      name: "test-client",
      version: "1.0.0"
    });
    
    // Connexion au serveur
    await client.connect(transport);
    
    // Récupération des informations sur le serveur
    console.log('Connexion réussie !');
    console.log('Informations sur le serveur :', client.serverInfo);
    
    // Récupération de la liste des outils disponibles
    const toolsResponse = await client.listTools();
    console.log('Outils disponibles :', toolsResponse.tools.map(tool => tool.name));
    
    // Test d'un outil
    console.log('\nTest de l\'outil convert_web_to_markdown...');
    try {
      const result = await client.callTool('convert_web_to_markdown', {
        url: 'https://github.com/jsboige/jsboige-mcp-servers'
      });
      console.log('Résultat (extrait):', result.content[0].text.substring(0, 200) + '...');
    } catch (toolError) {
      console.error('Erreur lors de l\'appel à l\'outil:', toolError);
    }
    
    // Test terminé avec succès
    console.log('Test de connexion réussi !');
  } catch (error) {
    console.error('Erreur lors du test de connexion :', error);
  } finally {
    // Fermeture du serveur
    serverProcess.kill();
    
    // Fermeture du transport
    await transport.close().catch(console.error);
  }
}

main().catch(console.error);