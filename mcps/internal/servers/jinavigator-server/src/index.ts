/**
 * @fileoverview Serveur MCP JinaNavigator
 *
 * Ce module implémente un serveur MCP (Model Context Protocol) qui utilise l'API Jina
 * pour convertir des pages web en Markdown. Le serveur expose trois outils principaux :
 * - convert_web_to_markdown : Convertit une page web en Markdown
 * - access_jina_resource : Accède au contenu Markdown via un URI au format jina://{url}
 * - multi_convert : Convertit plusieurs pages web en parallèle
 *
 * @author JinaNavigator Team
 * @version 1.0.0
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';

/**
 * Interface générique pour les entrées d'outils
 * Permet de typer les paramètres d'entrée des outils MCP
 *
 * @interface ToolInput
 */
interface ToolInput {
  [key: string]: any;
}

/**
 * Interface pour les sorties d'outils
 * Définit la structure de retour des outils MCP
 *
 * @interface ToolOutput
 * @property {any} [result] - Résultat de l'opération en cas de succès
 * @property {Object} [error] - Informations d'erreur en cas d'échec
 * @property {string} error.message - Message d'erreur
 * @property {any} [error.details] - Détails supplémentaires sur l'erreur
 */
interface ToolOutput {
  result?: any;
  error?: {
    message: string;
    details?: any;
  };
}

/**
 * Interface pour les outils JinaNavigator
 * Étend l'interface Tool du SDK MCP avec une méthode d'exécution
 *
 * @interface JinaTool
 * @extends Tool
 * @property {Function} execute - Fonction d'exécution de l'outil
 */
interface JinaTool extends Tool {
  execute: (input: ToolInput) => Promise<ToolOutput>;
}

/**
 * Serveur MCP JinaNavigator
 *
 * Ce serveur MCP utilise l'API Jina pour convertir des pages web en Markdown.
 * L'API Jina fonctionne en ajoutant l'URL cible comme suffixe à l'URL de base "https://r.jina.ai/".
 */

/**
 * Schéma d'entrée pour l'outil convert_web_to_markdown
 * Définit la structure des paramètres attendus pour la conversion d'une page web en Markdown
 *
 * @constant {Object} convertWebToMarkdownSchema
 * @property {string} url - URL de la page web à convertir en Markdown
 * @property {number} [start_line] - Ligne de début pour extraire une partie spécifique du contenu
 * @property {number} [end_line] - Ligne de fin pour extraire une partie spécifique du contenu
 */
const convertWebToMarkdownSchema = {
  type: "object" as const,
  properties: {
    url: {
      type: "string",
      description: 'URL de la page web à convertir en Markdown'
    },
    start_line: {
      type: "number",
      description: 'Ligne de début pour extraire une partie spécifique du contenu (optionnel)'
    },
    end_line: {
      type: "number",
      description: 'Ligne de fin pour extraire une partie spécifique du contenu (optionnel)'
    }
  },
  required: ['url']
};

/**
 * Schéma d'entrée pour l'outil multi_convert
 * Définit la structure des paramètres attendus pour la conversion de plusieurs pages web en Markdown
 *
 * @constant {Object} convertMultipleWebsToMarkdownSchema
 * @property {Array<Object>} urls - Liste des URLs à convertir avec leurs paramètres
 * @property {string} urls[].url - URL de la page web à convertir
 * @property {number} [urls[].start_line] - Ligne de début pour l'extrait
 * @property {number} [urls[].end_line] - Ligne de fin pour l'extrait
 */
const convertMultipleWebsToMarkdownSchema = {
  type: "object" as const,
  properties: {
    urls: {
      type: "array",
      items: {
        type: "object",
        properties: {
          url: {
            type: "string",
            description: 'URL de la page web à convertir en Markdown'
          },
          start_line: {
            type: "number",
            description: 'Ligne de début pour extraire une partie spécifique du contenu (optionnel)'
          },
          end_line: {
            type: "number",
            description: 'Ligne de fin pour extraire une partie spécifique du contenu (optionnel)'
          }
        },
        required: ['url']
      },
      description: 'Liste des URLs à convertir en Markdown avec leurs paramètres de bornage'
    }
  },
  required: ['urls']
};

/**
 * Schéma d'entrée pour l'outil extract_markdown_outline
 * Définit la structure des paramètres attendus pour extraire le plan des titres markdown
 * à partir d'une liste d'URLs
 *
 * @constant {Object} extractMarkdownOutlineSchema
 * @property {Array<Object>} urls - Liste des URLs à analyser
 * @property {string} urls[].url - URL de la page web à analyser
 * @property {number} [max_depth=3] - Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)
 */
const extractMarkdownOutlineSchema = {
  type: "object" as const,
  properties: {
    urls: {
      type: "array",
      items: {
        type: "object",
        properties: {
          url: {
            type: "string",
            description: 'URL de la page web dont on veut extraire le plan des titres'
          }
        },
        required: ['url']
      },
      description: 'Liste des URLs à analyser pour extraire le plan des titres'
    },
    max_depth: {
      type: "number",
      description: 'Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)',
      default: 3
    }
  },
  required: ['urls']
};

/**
 * Création du serveur MCP JinaNavigator
 *
 * @constant {Server} server
 */
const server = new Server(
  {
    name: 'jinavigator',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

/**
 * Outil de conversion de pages web en Markdown
 * Cet outil permet de convertir n'importe quelle page web en format Markdown
 * en utilisant l'API Jina, avec possibilité de filtrer le contenu par numéros de ligne
 *
 * @constant {JinaTool} convertWebToMarkdownTool
 */
const convertWebToMarkdownTool: JinaTool = {
  name: 'convert_web_to_markdown',
  description: 'Convertit une page web en Markdown en utilisant l\'API Jina',
  inputSchema: convertWebToMarkdownSchema,
  execute: async (input: ToolInput): Promise<ToolOutput> => {
    try {
      const { url, start_line, end_line } = input as {
        url: string;
        start_line?: number;
        end_line?: number;
      };
      
      // Construction de l'URL Jina
      const jinaUrl = `https://r.jina.ai/${url}`;
      
      // Appel à l'API Jina
      const response = await axios.get(jinaUrl);
      
      // Récupération du contenu Markdown
      let markdownContent = response.data;
      
      // Filtrage du contenu si des bornes sont spécifiées
      if (start_line !== undefined || end_line !== undefined) {
        const lines = markdownContent.split('\n');
        const startIndex = start_line !== undefined ? Math.max(0, start_line - 1) : 0;
        const endIndex = end_line !== undefined ? Math.min(lines.length, end_line) : lines.length;
        
        markdownContent = lines.slice(startIndex, endIndex).join('\n');
      }
      
      // Retourne le contenu Markdown filtré
      return {
        result: markdownContent
      };
    } catch (error) {
      // Gestion des erreurs
      if (axios.isAxiosError(error)) {
        return {
          error: {
            message: `Erreur lors de la conversion: ${error.message}`,
            details: error.response?.data || 'Pas de détails disponibles'
          }
        };
      }
      
      return {
        error: {
          message: `Erreur inattendue: ${(error as Error).message}`
        }
      };
    }
  }
};

/**
 * Fonction utilitaire pour convertir une URL en Markdown via l'API Jina
 * Cette fonction est utilisée par les différents outils du serveur pour
 * effectuer la conversion et le filtrage du contenu
 *
 * @async
 * @function convertUrlToMarkdown
 * @param {string} url - URL de la page web à convertir
 * @param {number} [startLine] - Ligne de début pour filtrer le contenu (optionnel)
 * @param {number} [endLine] - Ligne de fin pour filtrer le contenu (optionnel)
 * @returns {Promise<string>} Contenu Markdown de la page web, éventuellement filtré
 * @throws {Error} En cas d'erreur lors de la conversion
 */
async function convertUrlToMarkdown(url: string, startLine?: number, endLine?: number): Promise<string> {
  try {
    // Construction de l'URL Jina
    const jinaUrl = `https://r.jina.ai/${url}`;
    
    // Appel à l'API Jina
    const response = await axios.get(jinaUrl);
    
    // Récupération du contenu Markdown
    let markdownContent = response.data;
    
    // Filtrage du contenu si des bornes sont spécifiées
    if (startLine !== undefined || endLine !== undefined) {
      const lines = markdownContent.split('\n');
      const startIndex = startLine !== undefined ? Math.max(0, startLine - 1) : 0;
      const endIndex = endLine !== undefined ? Math.min(lines.length, endLine) : lines.length;
      
      markdownContent = lines.slice(startIndex, endIndex).join('\n');
    }
    
    return markdownContent;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      throw new Error(`Erreur lors de la conversion: ${error.message}`);
    }
    throw new Error(`Erreur inattendue: ${(error as Error).message}`);
  }
}

/**
 * Interface pour représenter un titre dans le plan
 *
 * @interface HeadingNode
 * @property {number} level - Niveau du titre (1 pour H1, 2 pour H2, etc.)
 * @property {string} text - Texte du titre
 * @property {number} line - Numéro de ligne où se trouve le titre
 * @property {HeadingNode[]} [children] - Sous-titres (enfants) de ce titre
 */
interface HeadingNode {
  level: number;
  text: string;
  line: number;
  children?: HeadingNode[];
}

/**
 * Fonction utilitaire pour extraire le plan des titres d'un contenu Markdown
 * Cette fonction analyse le contenu ligne par ligne pour identifier les titres
 * et leur niveau, en enregistrant également leur numéro de ligne
 *
 * @function extractMarkdownOutline
 * @param {string} markdownContent - Contenu Markdown à analyser
 * @param {number} [maxDepth=3] - Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)
 * @returns {Array<HeadingNode>} Structure hiérarchique des titres avec leur niveau, texte et numéro de ligne
 */
function extractMarkdownOutline(markdownContent: string, maxDepth: number = 3): Array<HeadingNode> {
  const lines = markdownContent.split('\n');
  const flatHeadings: Array<HeadingNode> = [];
  
  // Expression régulière pour détecter les titres markdown (# Titre)
  const headingRegex = /^(#{1,6})\s+(.+)$/;
  
  // Première passe : extraire tous les titres jusqu'au niveau maxDepth
  lines.forEach((line, index) => {
    const match = line.match(headingRegex);
    if (match) {
      const level = match[1].length; // Nombre de # = niveau du titre
      const text = match[2].trim();  // Texte du titre sans les # et espaces
      
      // Ne garder que les titres jusqu'au niveau maxDepth
      if (level <= maxDepth) {
        flatHeadings.push({
          level,
          text,
          line: index + 1 // Les numéros de ligne commencent à 1
        });
      }
    }
  });
  
  // Deuxième passe : construire la structure hiérarchique
  const rootHeadings: Array<HeadingNode> = [];
  const headingStack: Array<HeadingNode> = [];
  
  flatHeadings.forEach(heading => {
    // Vider la pile jusqu'à trouver un parent approprié
    while (
      headingStack.length > 0 &&
      headingStack[headingStack.length - 1].level >= heading.level
    ) {
      headingStack.pop();
    }
    
    // Si la pile est vide, c'est un titre racine
    if (headingStack.length === 0) {
      rootHeadings.push(heading);
    } else {
      // Sinon, c'est un enfant du dernier titre dans la pile
      const parent = headingStack[headingStack.length - 1];
      if (!parent.children) {
        parent.children = [];
      }
      parent.children.push(heading);
    }
    
    // Ajouter le titre courant à la pile
    headingStack.push(heading);
  });
  
  return rootHeadings;
}

/**
 * Schéma d'entrée pour l'outil access_jina_resource
 * Définit la structure des paramètres attendus pour accéder au contenu
 * d'une page web via un URI au format jina://{url}
 *
 * @constant {Object} accessJinaResourceSchema
 * @property {string} uri - URI au format jina://{url}
 * @property {number} [start_line] - Ligne de début pour l'extrait (optionnel)
 * @property {number} [end_line] - Ligne de fin pour l'extrait (optionnel)
 */
const accessJinaResourceSchema = {
  type: "object" as const,
  properties: {
    uri: {
      type: "string",
      description: 'URI au format jina://{url} pour accéder au contenu Markdown d\'une page web'
    },
    start_line: {
      type: "number",
      description: 'Ligne de début pour extraire une partie spécifique du contenu (optionnel)'
    },
    end_line: {
      type: "number",
      description: 'Ligne de fin pour extraire une partie spécifique du contenu (optionnel)'
    }
  },
  required: ['uri']
};

/**
 * Outil d'accès aux ressources via URI Jina
 * Cet outil permet d'accéder au contenu Markdown d'une page web
 * via un URI standardisé au format jina://{url}
 *
 * @constant {JinaTool} accessJinaResourceTool
 */
const accessJinaResourceTool: JinaTool = {
  name: 'access_jina_resource',
  description: 'Accède au contenu Markdown d\'une page web via un URI au format jina://{url}',
  inputSchema: accessJinaResourceSchema,
  execute: async (input: ToolInput): Promise<ToolOutput> => {
    try {
      const { uri, start_line, end_line } = input as {
        uri: string;
        start_line?: number;
        end_line?: number;
      };
      
      // Extraction de l'URL à partir de l'URI
      const match = uri.match(/^jina:\/\/(.+)$/);
      if (!match) {
        return {
          error: {
            message: 'URI invalide. L\'URI doit être au format jina://{url}'
          }
        };
      }
      
      const url = match[1];
      
      // Conversion de l'URL en Markdown
      const markdownContent = await convertUrlToMarkdown(url, start_line, end_line);
      
      return {
        result: {
          content: markdownContent,
          contentType: 'text/markdown'
        }
      };
    } catch (error) {
      return {
        error: {
          message: `Erreur lors de l'accès à la ressource: ${(error as Error).message}`
        }
      };
    }
  }
};

/**
 * Outil de conversion multiple de pages web en Markdown
 * Cet outil permet de convertir plusieurs pages web en Markdown
 * en une seule requête, avec traitement parallèle des URLs
 *
 * @constant {JinaTool} convertMultipleWebsToMarkdownTool
 */
const convertMultipleWebsToMarkdownTool: JinaTool = {
  name: 'multi_convert',
  description: 'Convertit plusieurs pages web en Markdown en une seule requête',
  inputSchema: convertMultipleWebsToMarkdownSchema,
  execute: async (input: ToolInput): Promise<ToolOutput> => {
    try {
      const { urls } = input as {
        urls: Array<{
          url: string;
          start_line?: number;
          end_line?: number;
        }>;
      };
      
      // Traitement de chaque URL en parallèle
      const results = await Promise.all(
        urls.map(async ({ url, start_line, end_line }) => {
          try {
            const markdown = await convertUrlToMarkdown(url, start_line, end_line);
            return {
              url,
              success: true,
              content: markdown
            };
          } catch (error) {
            return {
              url,
              success: false,
              error: (error as Error).message
            };
          }
        })
      );
      
      return {
        result: results
      };
    } catch (error) {
      return {
        error: {
          message: `Erreur lors de la conversion multiple: ${(error as Error).message}`
        }
      };
    }
  }
};

/**
 * Outil d'extraction du plan des titres Markdown
 * Cet outil permet d'extraire le plan des titres (headings) d'une ou plusieurs pages web
 * avec leurs numéros de ligne, en utilisant l'API Jina pour la conversion en Markdown.
 *
 * L'outil retourne une structure hiérarchique des titres, où chaque titre peut contenir
 * des sous-titres (enfants) de niveau inférieur, permettant ainsi de visualiser la structure
 * complète du document.
 *
 * @constant {JinaTool} extractMarkdownOutlineTool
 */
const extractMarkdownOutlineTool: JinaTool = {
  name: 'extract_markdown_outline',
  description: 'Extrait le plan hiérarchique des titres markdown avec numéros de ligne à partir d\'une liste d\'URLs',
  inputSchema: extractMarkdownOutlineSchema,
  execute: async (input: ToolInput): Promise<ToolOutput> => {
    try {
      const { urls, max_depth = 3 } = input as {
        urls: Array<{ url: string }>;
        max_depth?: number;
      };
      
      // Validation de la profondeur maximale
      const validatedMaxDepth = Math.min(Math.max(1, max_depth), 6); // Entre 1 et 6
      
      // Traitement de chaque URL en parallèle
      const results = await Promise.all(
        urls.map(async ({ url }) => {
          try {
            // Conversion de l'URL en Markdown
            const markdown = await convertUrlToMarkdown(url);
            
            // Extraction du plan hiérarchique des titres
            const outline = extractMarkdownOutline(markdown, validatedMaxDepth);
            
            return {
              url,
              success: true,
              max_depth: validatedMaxDepth,
              outline
            };
          } catch (error) {
            return {
              url,
              success: false,
              error: (error as Error).message
            };
          }
        })
      );
      
      return {
        result: results
      };
    } catch (error) {
      return {
        error: {
          message: `Erreur lors de l'extraction du plan des titres: ${(error as Error).message}`
        }
      };
    }
  }
};

/**
 * Configuration du gestionnaire de liste d'outils
 * Cette fonction répond aux requêtes de liste des outils disponibles
 * en renvoyant les métadonnées des quatre outils du serveur
 *
 * @function setRequestHandler
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
  const tools = [
    {
      name: convertWebToMarkdownTool.name,
      description: convertWebToMarkdownTool.description,
      inputSchema: convertWebToMarkdownTool.inputSchema
    },
    {
      name: accessJinaResourceTool.name,
      description: accessJinaResourceTool.description,
      inputSchema: accessJinaResourceTool.inputSchema
    },
    {
      name: convertMultipleWebsToMarkdownTool.name,
      description: convertMultipleWebsToMarkdownTool.description,
      inputSchema: convertMultipleWebsToMarkdownTool.inputSchema
    },
    {
      name: extractMarkdownOutlineTool.name,
      description: extractMarkdownOutlineTool.description,
      inputSchema: extractMarkdownOutlineTool.inputSchema
    }
  ];
  
  return { tools };
});

/**
 * Gestionnaire des appels d'outils
 * Cette fonction traite les requêtes d'exécution d'outils,
 * trouve l'outil correspondant, l'exécute et formate la réponse
 * selon les attentes du SDK MCP
 *
 * @function setRequestHandler
 * @param {Object} request - Requête d'appel d'outil
 * @param {Object} extra - Informations supplémentaires sur la requête
 * @throws {McpError} Si l'outil demandé n'existe pas ou si une erreur survient
 */
server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {
  const toolName = request.params.name;
  const args = request.params.arguments || {};
  
  // Trouver l'outil correspondant
  const allTools = [convertWebToMarkdownTool, accessJinaResourceTool, convertMultipleWebsToMarkdownTool, extractMarkdownOutlineTool];
  const tool = allTools.find(t => t.name === toolName) as JinaTool;
  
  if (!tool) {
    throw new McpError(
      ErrorCode.MethodNotFound,
      `Outil inconnu: ${toolName}`
    );
  }
  
  try {
    // Exécuter le handler de l'outil
    const result = await tool.execute(args as ToolInput);
    
    // Formater correctement la réponse selon les attentes du SDK MCP
    // Le champ "content" doit être un tableau d'objets avec une structure spécifique
    let formattedContent;
    
    if (toolName === 'convert_web_to_markdown') {
      // Pour l'outil convert_web_to_markdown, on crée un objet avec le contenu Markdown
      formattedContent = [{
        type: 'text',
        text: result.result || '',
        mime: 'text/markdown'
      }];
    } else if (toolName === 'access_jina_resource') {
      // Pour l'outil access_jina_resource, on utilise le contenu et le type de contenu
      formattedContent = [{
        type: 'text',
        text: result.result?.content || '',
        mime: result.result?.contentType || 'text/markdown'
      }];
    } else if (toolName === 'multi_convert') {
      // Pour l'outil multi_convert, on crée un objet JSON formaté
      const resultsText = JSON.stringify(result.result, null, 2);
      formattedContent = [{
        type: 'text',
        text: resultsText,
        mime: 'application/json'
      }];
    } else if (toolName === 'extract_markdown_outline') {
      // Pour l'outil extract_markdown_outline, on crée un objet JSON formaté
      const resultsText = JSON.stringify(result.result, null, 2);
      formattedContent = [{
        type: 'text',
        text: resultsText,
        mime: 'application/json'
      }];
    } else {
      // Par défaut, on crée un tableau avec un élément texte vide
      formattedContent = [{
        type: 'text',
        text: '',
        mime: 'text/plain'
      }];
    }
    
    return {
      result: result.result,
      content: formattedContent
    };
  } catch (error: any) {
    console.error(`Erreur lors de l'exécution de l'outil ${toolName}:`, error);
    throw new McpError(
      ErrorCode.InternalError,
      `Erreur lors de l'exécution de l'outil: ${error.message}`
    );
  }
});

/**
 * Configuration de la gestion des erreurs
 * Enregistre les erreurs dans la console et gère l'arrêt propre du serveur
 */
server.onerror = (error) => console.error('[MCP Error]', error);
process.on('SIGINT', async () => {
  await server.close();
  process.exit(0);
});

/**
 * Fonction de démarrage du serveur
 * Initialise le transport stdio et connecte le serveur
 *
 * @async
 * @function run
 * @returns {Promise<void>}
 */
async function run() {
  try {
    console.log('Initialisation du serveur MCP Jinavigator...');
    
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.log('Serveur MCP Jinavigator démarré avec succès sur stdio');
  } catch (error) {
    console.error('Erreur lors du démarrage du serveur MCP Jinavigator:', error);
    process.exit(1);
  }
}

run().catch(console.error);