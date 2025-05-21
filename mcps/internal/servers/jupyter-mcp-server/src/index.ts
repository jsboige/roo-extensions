import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import * as fs from 'fs';
import * as path from 'path';
import minimist from 'minimist';

// Définir notre propre interface Tool pour le serveur
interface JupyterTool {
  name: string;
  description: string;
  schema?: any;
  handler?: (args: any) => Promise<any>;
  inputSchema?: any;
}

// Interface pour la configuration
interface Config {
  jupyterServer: {
    baseUrl: string;
    token: string;
  };
}

// Interface pour les options de ligne de commande
interface CommandLineOptions {
  url?: string;
  token?: string;
  offline?: boolean;
  skipConnectionCheck?: boolean;
  config?: string;
  help?: boolean;
}
import { initializeJupyterServices } from './services/jupyter.js';
import { notebookTools } from './tools/notebook.js';
import { kernelTools } from './tools/kernel.js';
import { executionTools } from './tools/execution.js';

// Conversion des types
type AllTools = JupyterTool[];

class JupyterMcpServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'jupyter-mcp-server',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    
    // Gestion des erreurs
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  private setupToolHandlers() {
    // Définir les outils disponibles
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools = [
        ...notebookTools.map(tool => ({
          name: tool.name,
          description: tool.description,
          inputSchema: tool.schema
        })),
        ...kernelTools.map(tool => ({
          name: tool.name,
          description: tool.description,
          inputSchema: tool.schema
        })),
        ...executionTools.map(tool => ({
          name: tool.name,
          description: tool.description,
          inputSchema: tool.schema
        }))
      ];
      
      return { tools };
    });

    // Gérer les appels d'outils
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const toolName = request.params.name;
      const args = request.params.arguments;
      
      // Trouver l'outil correspondant
      const allTools = [...notebookTools, ...kernelTools, ...executionTools] as JupyterTool[];
      const tool = allTools.find(t => t.name === toolName) as JupyterTool;
      
      if (!tool) {
        throw new McpError(
          ErrorCode.MethodNotFound,
          `Outil inconnu: ${toolName}`
        );
      }
      
      try {
        // Exécuter le handler de l'outil
        if (!tool.handler) {
          throw new Error(`L'outil ${toolName} n'a pas de handler défini`);
        }
        const result = await tool.handler(args);
        return result;
      } catch (error: any) {
        console.error(`Erreur lors de l'exécution de l'outil ${toolName}:`, error);
        throw new McpError(
          ErrorCode.InternalError,
          `Erreur lors de l'exécution de l'outil: ${error.message}`
        );
      }
    });
  }

  /**
   * Affiche l'aide pour les options de ligne de commande
   */
  private static showHelp() {
    console.log(`
Usage: node dist/index.js [options]

Options:
  --url <url>       URL du serveur Jupyter (ex: http://localhost:8888)
  --token <token>   Token d'authentification du serveur Jupyter
  --offline         Démarrer en mode hors ligne (sans tentatives de connexion)
  --skip-connection-check  Ne pas vérifier la connexion au serveur Jupyter
  --config <path>   Chemin vers un fichier de configuration personnalisé
  --help            Afficher cette aide

Exemples:
  node dist/index.js --url http://localhost:8888 --token abc123
  node dist/index.js --offline
  node dist/index.js --config ./my-config.json

Variables d'environnement:
  JUPYTER_SERVER_URL   URL du serveur Jupyter
  JUPYTER_SERVER_TOKEN Token d'authentification du serveur Jupyter
  JUPYTER_MCP_OFFLINE  Définir à 'true' pour le mode hors ligne
  JUPYTER_SKIP_CONNECTION_CHECK  Définir à 'true' pour éviter les vérifications de connexion
  JUPYTER_MCP_CONFIG   Chemin vers un fichier de configuration personnalisé
`);
    process.exit(0);
  }

  /**
   * Analyse les options de ligne de commande
   */
  private static parseCommandLineOptions(): CommandLineOptions {
    const argv = minimist(process.argv.slice(2), {
      string: ['url', 'token', 'config'],
      boolean: ['offline', 'help', 'skip-connection-check'],
      alias: {
        u: 'url',
        t: 'token',
        o: 'offline',
        s: 'skip-connection-check',
        c: 'config',
        h: 'help'
      }
    });

    return {
      url: argv.url,
      token: argv.token,
      offline: argv.offline,
      skipConnectionCheck: argv['skip-connection-check'],
      config: argv.config,
      help: argv.help
    };
  }

  async run() {
    try {
      console.log('Initialisation du serveur MCP Jupyter...');
      
      // Analyser les options de ligne de commande
      const options = JupyterMcpServer.parseCommandLineOptions();
      
      // Afficher l'aide si demandé
      if (options.help) {
        JupyterMcpServer.showHelp();
        return;
      }
      
      // Valeurs par défaut pour la configuration
      let config: Config = {
        jupyterServer: {
          baseUrl: 'http://localhost:8888',
          token: ''
        }
      };
      
      // Déterminer le chemin du fichier de configuration
      const configPath = options.config ||
                         process.env.JUPYTER_MCP_CONFIG ||
                         path.resolve('./config.json');
      
      // Charger la configuration depuis le fichier si disponible
      try {
        if (fs.existsSync(configPath)) {
          const configData = fs.readFileSync(configPath, 'utf8');
          config = JSON.parse(configData);
          console.log(`Configuration chargée depuis ${configPath}`);
        } else {
          console.log(`Fichier de configuration ${configPath} non trouvé, utilisation des valeurs par défaut`);
        }
      } catch (configError) {
        console.error('Erreur lors du chargement de la configuration:', configError);
        console.log('Utilisation des valeurs par défaut');
      }
      
      // Priorité des paramètres: ligne de commande > variables d'environnement > fichier de configuration
      const baseUrl = options.url ||
                      process.env.JUPYTER_SERVER_URL ||
                      config.jupyterServer.baseUrl;
      
      const token = options.token ||
                    process.env.JUPYTER_SERVER_TOKEN ||
                    config.jupyterServer.token;
      
      // Vérifier si le mode hors ligne est activé
      const skipConnectionCheck = options.offline ||
                                 options.skipConnectionCheck ||
                                 process.env.JUPYTER_MCP_OFFLINE === 'true' ||
                                 process.env.JUPYTER_SKIP_CONNECTION_CHECK === 'true';
      
      if (skipConnectionCheck) {
        console.log('Mode hors ligne activé: aucune tentative de connexion au serveur Jupyter ne sera effectuée');
        console.log('Les fonctionnalités nécessitant un serveur Jupyter ne seront pas disponibles');
      } else {
        console.log(`Tentative de connexion au serveur Jupyter à l'adresse: ${baseUrl}`);
        if (token) {
          console.log('Token d\'authentification fourni');
        } else {
          console.log('Aucun token d\'authentification fourni');
        }
      }
      
      // Initialiser les services Jupyter avec la configuration
      await initializeJupyterServices({
        baseUrl: baseUrl,
        token: token,
        skipConnectionCheck: skipConnectionCheck
      });
      console.log('Services Jupyter initialisés avec succès');
      
      const transport = new StdioServerTransport();
      await this.server.connect(transport);
      console.log('Serveur MCP Jupyter démarré avec succès sur stdio');
    } catch (error) {
      console.error('Erreur lors du démarrage du serveur MCP Jupyter:', error);
      process.exit(1);
    }
  }
}

const server = new JupyterMcpServer();
server.run().catch(console.error);

