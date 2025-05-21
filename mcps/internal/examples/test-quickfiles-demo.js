#!/usr/bin/env node
import { spawn } from 'child_process';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le serveur MCP
const SERVER_PROCESS_PATH = path.join(__dirname, 'servers', 'quickfiles-server', 'build', 'index.js');

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

// Classe client MCP
class McpClient {
  constructor(serverProcess) {
    this.serverProcess = serverProcess;
    this.requestId = 1;
    this.pendingRequests = new Map();

    // Écouter les données du serveur
    this.serverProcess.stdout.on('data', (data) => {
      const rawData = data.toString();
      console.log(`${COLORS.blue}[Serveur stdout]: ${rawData}${COLORS.reset}`);
      
      const messages = rawData.split('\n').filter(Boolean);
      for (const message of messages) {
        try {
          const response = JSON.parse(message);
          
          if (response.id && this.pendingRequests.has(response.id)) {
            const { resolve, reject } = this.pendingRequests.get(response.id);
            this.pendingRequests.delete(response.id);
            
            if (response.error) {
              console.log(`${COLORS.red}[Erreur serveur]: ${JSON.stringify(response.error, null, 2)}${COLORS.reset}`);
              reject(new Error(response.error.message));
            } else {
              resolve(response.result);
            }
          }
        } catch (error) {
          console.error(`${COLORS.red}Erreur lors du parsing de la réponse: ${error.message}${COLORS.reset}`);
        }
      }
    });

    // Gérer les erreurs du processus serveur
    this.serverProcess.stderr.on('data', (data) => {
      console.error(`${COLORS.red}[Serveur stderr]: ${data.toString()}${COLORS.reset}`);
    });

    this.serverProcess.on('close', (code) => {
      console.log(`${COLORS.yellow}Le processus serveur s'est terminé avec le code ${code}${COLORS.reset}`);
    });
  }

  // Envoyer une requête au serveur
  async sendRequest(method, params) {
    return new Promise((resolve, reject) => {
      const id = this.requestId++;
      const request = {
        jsonrpc: '2.0',
        id,
        method,
        params,
      };

      console.log(`${COLORS.magenta}[Client requête]: ${JSON.stringify(request, null, 2)}${COLORS.reset}`);
      this.pendingRequests.set(id, { resolve, reject });
      this.serverProcess.stdin.write(JSON.stringify(request) + '\n');
    });
  }

  // Lister les outils disponibles
  async listTools() {
    try {
      return await this.sendRequest('list_tools', {});
    } catch (error) {
      console.error(`${COLORS.red}Erreur lors du listage des outils: ${error.message}${COLORS.reset}`);
      throw error;
    }
  }

  // Appeler un outil
  async callTool(name, args) {
    try {
      return await this.sendRequest('call_tool', {
        name,
        arguments: args,
      });
    } catch (error) {
      console.error(`${COLORS.red}Erreur lors de l'appel de l'outil: ${error.message}${COLORS.reset}`);
      throw error;
    }
  }

  // Fermer le client
  close() {
    this.serverProcess.stdin.end();
  }
}

// Fonction principale
async function main() {
  console.log(`${COLORS.cyan}=== Démonstration du serveur MCP quickfiles ===${COLORS.reset}`);
  
  // Démarrer le serveur MCP
  console.log(`${COLORS.cyan}Démarrage du serveur MCP...${COLORS.reset}`);
  const serverProcess = spawn('node', [SERVER_PROCESS_PATH], {
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  
  // Créer un client MCP
  const client = new McpClient(serverProcess);
  
  try {
    // Attendre un peu pour que le serveur démarre
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Lister les outils disponibles
    console.log(`${COLORS.cyan}Démonstration 1: Lister les outils disponibles${COLORS.reset}`);
    const toolsResponse = await client.listTools();
    console.log(`${COLORS.green}Outils disponibles: ${toolsResponse.tools.map(t => t.name).join(', ')}${COLORS.reset}`);
    
    // Démonstration 1: read_multiple_files
    console.log(`\n${COLORS.cyan}Démonstration 2: Lire plusieurs fichiers avec numérotation de lignes${COLORS.reset}`);
    const readFilesResponse = await client.callTool('read_multiple_files', {
      paths: ['demo-file1.txt', 'demo-file2.txt'],
      show_line_numbers: true
    });
    
    console.log(`${COLORS.yellow}Résultat:${COLORS.reset}`);
    console.log(readFilesResponse.content[0].text);
    
    // Démonstration 2: read_multiple_files avec extraits
    console.log(`\n${COLORS.cyan}Démonstration 3: Lire des extraits spécifiques de fichiers${COLORS.reset}`);
    const readExcerptsResponse = await client.callTool('read_multiple_files', {
      paths: [
        {
          path: 'demo-file2.txt',
          excerpts: [
            { start: 3, end: 6 }
          ]
        }
      ],
      show_line_numbers: true
    });
    
    console.log(`${COLORS.yellow}Résultat:${COLORS.reset}`);
    console.log(readExcerptsResponse.content[0].text);
    
    // Démonstration 3: list_directory_contents
    console.log(`\n${COLORS.cyan}Démonstration 4: Lister le contenu d'un répertoire${COLORS.reset}`);
    const listDirResponse = await client.callTool('list_directory_contents', {
      paths: [{ path: '.', recursive: false }],
      max_lines: 20
    });
    
    console.log(`${COLORS.yellow}Résultat:${COLORS.reset}`);
    console.log(listDirResponse.content[0].text);
    
    console.log(`\n${COLORS.green}=== Démonstration terminée ===${COLORS.reset}`);
  } catch (error) {
    console.error(`${COLORS.red}Erreur lors de la démonstration: ${error.message}${COLORS.reset}`);
  } finally {
    // Fermer le client
    client.close();
  }
}

// Exécuter la démonstration
main().catch(error => {
  console.error(`${COLORS.red}Erreur non gérée: ${error.message}${COLORS.reset}`);
  process.exit(1);
});