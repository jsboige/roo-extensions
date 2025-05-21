import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import dotenv from 'dotenv';
import { setupTools } from './tools';
import { setupResources } from './resources';
import { setupErrorHandlers } from './utils/errorHandlers';

// Charger les variables d'environnement
dotenv.config();

/**
 * Classe principale du serveur GitHub Projects MCP
 */
class GitHubProjectsServer {
  /** Instance du serveur MCP */
  private server: Server;

  /**
   * Crée une instance du serveur GitHub Projects MCP
   */
  constructor() {
    this.server = new Server(
      {
        name: 'github-projects',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    // Configurer les outils et les ressources
    setupTools(this.server);
    setupResources(this.server);
    
    // Configurer les gestionnaires d'erreurs
    setupErrorHandlers(this.server);
    
    // Gestion des erreurs
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  /**
   * Démarre le serveur
   */
  async run() {
    try {
      console.log('Démarrage du serveur MCP Gestionnaire de Projet...');
      const transport = new StdioServerTransport();
      await this.server.connect(transport);
      console.log('Serveur MCP Gestionnaire de Projet démarré sur stdio');
    } catch (error) {
      console.error('Erreur lors du démarrage du serveur MCP:', error);
      process.exit(1);
    }
  }
}

// Créer et démarrer le serveur
const server = new GitHubProjectsServer();
server.run();