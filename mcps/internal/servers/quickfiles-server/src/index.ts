#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import * as fs from 'fs/promises';
import * as path from 'path';
import { glob } from 'glob';

/**
 * Interface représentant une plage de lignes pour les extraits de fichiers
 *
 * @interface LineRange
 * @property {number} start - Numéro de la première ligne de l'extrait (commençant à 1)
 * @property {number} end - Numéro de la dernière ligne de l'extrait (incluse)
 */
interface LineRange {
  start: number;
  end: number;
}

/**
 * Interface représentant un fichier avec des extraits spécifiques à lire
 *
 * @interface FileWithExcerpts
 * @property {string} path - Chemin du fichier à lire
 * @property {LineRange[]} [excerpts] - Liste des extraits à lire dans le fichier (optionnel)
 */
interface FileWithExcerpts {
  path: string;
  excerpts?: LineRange[];
}

/**
 * Interface pour les arguments de la méthode read_multiple_files
 *
 * @interface ReadMultipleFilesArgs
 * @property {(string[] | FileWithExcerpts[])} paths - Tableau des chemins de fichiers à lire (format simple ou avec extraits)
 * @property {boolean} [show_line_numbers] - Afficher les numéros de ligne (optionnel, défaut: false)
 * @property {number} [max_lines_per_file] - Nombre maximum de lignes à afficher par fichier (optionnel, défaut: 2000)
 * @property {number} [max_total_lines] - Nombre maximum total de lignes à afficher pour tous les fichiers (optionnel, défaut: 5000)
 */
interface ReadMultipleFilesArgs {
  paths: string[] | FileWithExcerpts[];
  show_line_numbers?: boolean;
  max_lines_per_file?: number;
  max_total_lines?: number;
  max_chars_per_file?: number;
  max_total_chars?: number;
}

/**
 * Interface représentant un répertoire à lister avec des options de filtrage et de tri
 *
 * @interface DirectoryToList
 * @property {string} path - Chemin du répertoire à lister
 * @property {boolean} [recursive] - Lister récursivement les sous-répertoires (optionnel, défaut: true)
 * @property {number} [max_depth] - Profondeur maximale d'exploration des sous-répertoires (optionnel, défaut: pas de limite)
 * @property {string} [file_pattern] - Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts}) (optionnel)
 * @property {string} [sort_by] - Critère de tri ('name': alphabétique, 'size': taille, 'modified': date de modification, 'type': répertoires puis fichiers) (optionnel, défaut: 'name')
 * @property {string} [sort_order] - Ordre de tri ('asc': ascendant, 'desc': descendant) (optionnel, défaut: 'asc')
 */
interface DirectoryToList {
  path: string;
  recursive?: boolean;
  max_depth?: number;
  file_pattern?: string;
  sort_by?: 'name' | 'size' | 'modified' | 'type';
  sort_order?: 'asc' | 'desc';
}

/**
 * Interface pour les arguments de la méthode list_directory_contents
 *
 * @interface ListDirectoryContentsArgs
 * @property {(string[] | DirectoryToList[])} paths - Tableau des chemins de répertoires à lister (format simple ou avec options)
 * @property {number} [max_lines] - Nombre maximum de lignes à afficher dans la sortie (optionnel, défaut: 2000)
 * @property {number} [max_depth] - Profondeur maximale globale d'exploration des sous-répertoires (optionnel, défaut: pas de limite)
 * @property {string} [file_pattern] - Motif glob global pour filtrer les fichiers (ex: *.js, *.{js,ts}) (optionnel)
 * @property {string} [sort_by] - Critère de tri global ('name': alphabétique, 'size': taille, 'modified': date de modification, 'type': répertoires puis fichiers) (optionnel, défaut: 'name')
 * @property {string} [sort_order] - Ordre de tri global ('asc': ascendant, 'desc': descendant) (optionnel, défaut: 'asc')
 */
interface ListDirectoryContentsArgs {
  paths: string[] | DirectoryToList[];
  max_lines?: number;
  max_depth?: number;
  file_pattern?: string;
  sort_by?: 'name' | 'size' | 'modified' | 'type';
  sort_order?: 'asc' | 'desc';
}

/**
 * Interface pour les arguments de la méthode delete_files
 *
 * @interface DeleteFilesArgs
 * @property {string[]} paths - Tableau des chemins de fichiers à supprimer
 */
interface DeleteFilesArgs {
  paths: string[];
}

/**
 * Interface représentant un diff à appliquer à un fichier
 *
 * @interface FileDiff
 * @property {string} search - Texte à rechercher
 * @property {string} replace - Texte de remplacement
 * @property {number} [start_line] - Numéro de ligne où commencer la recherche (optionnel)
 */
interface FileDiff {
  search: string;
  replace: string;
  start_line?: number;
}

/**
 * Interface représentant un fichier à éditer avec ses diffs
 *
 * @interface FileEdit
 * @property {string} path - Chemin du fichier à éditer
 * @property {FileDiff[]} diffs - Liste des diffs à appliquer au fichier
 */
interface FileEdit {
  path: string;
  diffs: FileDiff[];
}

/**
 * Interface pour les arguments de la méthode edit_multiple_files
 *
 * @interface EditMultipleFilesArgs
 * @property {FileEdit[]} files - Tableau des fichiers à éditer avec leurs diffs
 */
interface EditMultipleFilesArgs {
  files: FileEdit[];
}

/**
 * Interface pour les arguments de la méthode extract_markdown_structure
 *
 * @interface ExtractMarkdownStructureArgs
 * @property {string[]} paths - Tableau des chemins de fichiers markdown à analyser
 * @property {number} [max_depth] - Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)
 * @property {boolean} [include_context] - Inclure du contexte autour des titres (optionnel, défaut: false)
 * @property {number} [context_lines] - Nombre de lignes de contexte à inclure avant et après chaque titre (optionnel, défaut: 2)
 */
interface ExtractMarkdownStructureArgs {
  paths: string[];
  max_depth?: number;
  include_context?: boolean;
  context_lines?: number;
}

/**
 * Interface représentant une transformation de nom de fichier
 *
 * @interface FileNameTransformation
 * @property {string} pattern - Motif regex à rechercher dans le nom du fichier
 * @property {string} replacement - Texte de remplacement (peut contenir des références de capture comme $1, $2, etc.)
 */
interface FileNameTransformation {
  pattern: string;
  replacement: string;
}

/**
 * Interface représentant une opération de copie ou déplacement de fichier
 *
 * @interface FileCopyOperation
 * @property {string} source - Chemin source (peut être un motif glob)
 * @property {string} destination - Chemin de destination (répertoire ou fichier)
 * @property {FileNameTransformation} [transform] - Transformation à appliquer aux noms de fichiers
 * @property {'overwrite' | 'ignore' | 'rename'} [conflict_strategy] - Stratégie en cas de conflit (défaut: 'overwrite')
 */
interface FileCopyOperation {
  source: string;
  destination: string;
  transform?: FileNameTransformation;
  conflict_strategy?: 'overwrite' | 'ignore' | 'rename';
}

/**
 * Interface pour les arguments de la méthode copy_files
 *
 * @interface CopyFilesArgs
 * @property {FileCopyOperation[]} operations - Tableau des opérations de copie à effectuer
 */
interface CopyFilesArgs {
  operations: FileCopyOperation[];
}

/**
 * Interface pour les arguments de la méthode move_files
 *
 * @interface MoveFilesArgs
 * @property {FileCopyOperation[]} operations - Tableau des opérations de déplacement à effectuer
 */
interface MoveFilesArgs {
  operations: FileCopyOperation[];
}

/**
 * Interface représentant un titre markdown avec son niveau et son numéro de ligne
 *
 * @interface MarkdownHeading
 * @property {string} text - Texte du titre
 * @property {number} level - Niveau du titre (1=h1, 2=h2, etc.)
 * @property {number} line - Numéro de ligne du titre dans le fichier
 * @property {string[]} [context] - Lignes de contexte autour du titre (optionnel)
 */
interface MarkdownHeading {
  text: string;
  level: number;
  line: number;
  context?: string[];
}

/**
 * Interface pour les arguments de la méthode search_in_files
 *
 * @interface SearchInFilesArgs
 * @property {string[]} paths - Tableau des chemins de fichiers ou répertoires à rechercher
 * @property {string} pattern - Expression régulière à rechercher
 * @property {boolean} [use_regex=true] - Utiliser une expression régulière (défaut: true)
 * @property {boolean} [case_sensitive=false] - Recherche sensible à la casse (défaut: false)
 * @property {string} [file_pattern] - Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})
 * @property {number} [context_lines=2] - Nombre de lignes de contexte à afficher avant et après chaque correspondance
 * @property {number} [max_results_per_file=100] - Nombre maximum de résultats par fichier
 * @property {number} [max_total_results=1000] - Nombre maximum total de résultats
 * @property {boolean} [recursive=true] - Rechercher récursivement dans les sous-répertoires
 */
interface SearchInFilesArgs {
  paths: string[];
  pattern: string;
  use_regex?: boolean;
  case_sensitive?: boolean;
  file_pattern?: string;
  context_lines?: number;
  max_results_per_file?: number;
  max_total_results?: number;
  recursive?: boolean;
}

/**
 * Interface représentant un fichier à rechercher et remplacer avec ses options
 *
 * @interface FileSearchReplace
 * @property {string} path - Chemin du fichier à modifier
 * @property {string} search - Expression à rechercher
 * @property {string} replace - Texte de remplacement
 * @property {boolean} [use_regex=true] - Utiliser une expression régulière (défaut: true)
 * @property {boolean} [case_sensitive=false] - Recherche sensible à la casse (défaut: false)
 * @property {boolean} [preview=false] - Prévisualiser les modifications sans les appliquer (défaut: false)
 */
interface FileSearchReplace {
  path: string;
  search: string;
  replace: string;
  use_regex?: boolean;
  case_sensitive?: boolean;
  preview?: boolean;
}

/**
 * Interface pour les arguments de la méthode search_and_replace
 *
 * @interface SearchAndReplaceArgs
 * @property {FileSearchReplace[]} [files] - Tableau des fichiers à modifier avec leurs options
 * @property {string[]} [paths] - Tableau des chemins de fichiers ou répertoires à traiter
 * @property {string} [search] - Expression à rechercher (globale pour tous les fichiers dans paths)
 * @property {string} [replace] - Texte de remplacement (global pour tous les fichiers dans paths)
 * @property {boolean} [use_regex=true] - Utiliser une expression régulière (défaut: true)
 * @property {boolean} [case_sensitive=false] - Recherche sensible à la casse (défaut: false)
 * @property {string} [file_pattern] - Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})
 * @property {boolean} [recursive=true] - Rechercher récursivement dans les sous-répertoires
 * @property {boolean} [preview=false] - Prévisualiser les modifications sans les appliquer (défaut: false)
 */
interface SearchAndReplaceArgs {
  files?: FileSearchReplace[];
  paths?: string[];
  search?: string;
  replace?: string;
  use_regex?: boolean;
  case_sensitive?: boolean;
  file_pattern?: string;
  recursive?: boolean;
  preview?: boolean;
}

/**
 * Valide les arguments de la méthode read_multiple_files
 *
 * @function isValidReadMultipleFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidReadMultipleFilesArgs = (args: any): args is ReadMultipleFilesArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau paths
  if (!Array.isArray(args.paths)) return false;
  
  // Vérification de chaque élément du tableau paths
  for (const item of args.paths) {
    if (typeof item === 'string') {
      // Format simple: chemin de fichier
      continue;
    } else if (typeof item === 'object' && item !== null) {
      // Format avancé: objet avec path et excerpts
      if (typeof item.path !== 'string') return false;
      
      // Vérification des excerpts si présents
      if (item.excerpts !== undefined) {
        if (!Array.isArray(item.excerpts)) return false;
        
        for (const excerpt of item.excerpts) {
          if (typeof excerpt !== 'object' || excerpt === null) return false;
          if (typeof excerpt.start !== 'number' || typeof excerpt.end !== 'number') return false;
          if (excerpt.start < 1 || excerpt.end < excerpt.start) return false;
        }
      }
    } else {
      return false;
    }
  }
  
  // Vérification des autres paramètres
  if (args.show_line_numbers !== undefined && typeof args.show_line_numbers !== 'boolean') return false;
  if (args.max_lines_per_file !== undefined && typeof args.max_lines_per_file !== 'number') return false;
  if (args.max_total_lines !== undefined && typeof args.max_total_lines !== 'number') return false;
  if (args.max_chars_per_file !== undefined && typeof args.max_chars_per_file !== 'number') return false;
  if (args.max_total_chars !== undefined && typeof args.max_total_chars !== 'number') return false;
  
  return true;
};

/**
 * Valide les arguments de la méthode list_directory_contents
 *
 * @function isValidListDirectoryContentsArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidListDirectoryContentsArgs = (args: any): args is ListDirectoryContentsArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau paths
  if (!Array.isArray(args.paths)) return false;
  
  // Vérification de chaque élément du tableau paths
  for (const item of args.paths) {
    if (typeof item === 'string') {
      // Format simple: chemin de répertoire
      continue;
    } else if (typeof item === 'object' && item !== null) {
      // Format avancé: objet avec path et options
      if (typeof item.path !== 'string') return false;
      if (item.recursive !== undefined && typeof item.recursive !== 'boolean') return false;
      if (item.max_depth !== undefined && (typeof item.max_depth !== 'number' || item.max_depth < 1)) return false;
      if (item.file_pattern !== undefined && typeof item.file_pattern !== 'string') return false;
      if (item.sort_by !== undefined && !['name', 'size', 'modified', 'type'].includes(item.sort_by)) return false;
      if (item.sort_order !== undefined && !['asc', 'desc'].includes(item.sort_order)) return false;
    } else {
      return false;
    }
  }
  
  // Vérification des paramètres globaux
  if (args.max_lines !== undefined && typeof args.max_lines !== 'number') return false;
  if (args.max_depth !== undefined && (typeof args.max_depth !== 'number' || args.max_depth < 1)) return false;
  if (args.file_pattern !== undefined && typeof args.file_pattern !== 'string') return false;
  if (args.sort_by !== undefined && !['name', 'size', 'modified', 'type'].includes(args.sort_by)) return false;
  if (args.sort_order !== undefined && !['asc', 'desc'].includes(args.sort_order)) return false;
  
  return true;
};

/**
 * Valide les arguments de la méthode delete_files
 *
 * @function isValidDeleteFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidDeleteFilesArgs = (args: any): args is DeleteFilesArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau paths
  if (!Array.isArray(args.paths)) return false;
  
  // Vérification que chaque élément est une chaîne
  for (const path of args.paths) {
    if (typeof path !== 'string') return false;
  }
  
  return true;
};

/**
 * Valide les arguments de la méthode edit_multiple_files
 *
 * @function isValidEditMultipleFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidEditMultipleFilesArgs = (args: any): args is EditMultipleFilesArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau files
  if (!Array.isArray(args.files)) return false;
  
  // Vérification de chaque élément du tableau files
  for (const file of args.files) {
    if (typeof file !== 'object' || file === null) return false;
    if (typeof file.path !== 'string') return false;
    
    // Vérification du tableau diffs
    if (!Array.isArray(file.diffs)) return false;
    
    // Vérification de chaque élément du tableau diffs
    for (const diff of file.diffs) {
      if (typeof diff !== 'object' || diff === null) return false;
      if (typeof diff.search !== 'string') return false;
      if (typeof diff.replace !== 'string') return false;
      if (diff.start_line !== undefined && typeof diff.start_line !== 'number') return false;
    }
  }
  
  return true;
};

/**
 * Valide les arguments de la méthode extract_markdown_structure
 *
 * @function isValidExtractMarkdownStructureArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidExtractMarkdownStructureArgs = (args: any): args is ExtractMarkdownStructureArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau paths
  if (!Array.isArray(args.paths)) return false;
  
  // Vérification que chaque élément est une chaîne
  for (const path of args.paths) {
    if (typeof path !== 'string') return false;
  }
  
  // Vérification des paramètres optionnels
  if (args.max_depth !== undefined && typeof args.max_depth !== 'number') return false;
  if (args.include_context !== undefined && typeof args.include_context !== 'boolean') return false;
  if (args.context_lines !== undefined && typeof args.context_lines !== 'number') return false;
  
  return true;
};

/**
 * Valide les arguments de la méthode copy_files
 *
 * @function isValidCopyFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidCopyFilesArgs = (args: any): args is CopyFilesArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification du tableau operations
  if (!Array.isArray(args.operations)) return false;
  
  // Vérification de chaque élément du tableau operations
  for (const operation of args.operations) {
    if (typeof operation !== 'object' || operation === null) return false;
    if (typeof operation.source !== 'string') return false;
    if (typeof operation.destination !== 'string') return false;
    
    // Vérification de transform si présent
    if (operation.transform !== undefined) {
      if (typeof operation.transform !== 'object' || operation.transform === null) return false;
      if (typeof operation.transform.pattern !== 'string') return false;
      if (typeof operation.transform.replacement !== 'string') return false;
    }
    
    // Vérification de conflict_strategy si présent
    if (operation.conflict_strategy !== undefined &&
        !['overwrite', 'ignore', 'rename'].includes(operation.conflict_strategy)) {
      return false;
    }
  }
  
  return true;
};

/**
 * Valide les arguments de la méthode move_files
 *
 * @function isValidMoveFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidMoveFilesArgs = (args: any): args is MoveFilesArgs => {
  // La structure des arguments est identique à celle de copy_files
  return isValidCopyFilesArgs(args);
};

/**
 * Valide les arguments de la méthode search_in_files
 *
 * @function isValidSearchInFilesArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidSearchInFilesArgs = (args: any): args is SearchInFilesArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification des paramètres obligatoires
  if (!Array.isArray(args.paths)) return false;
  if (typeof args.pattern !== 'string') return false;
  
  // Vérification que chaque chemin est une chaîne
  for (const path of args.paths) {
    if (typeof path !== 'string') return false;
  }
  
  // Vérification des paramètres optionnels
  if (args.use_regex !== undefined && typeof args.use_regex !== 'boolean') return false;
  if (args.case_sensitive !== undefined && typeof args.case_sensitive !== 'boolean') return false;
  if (args.file_pattern !== undefined && typeof args.file_pattern !== 'string') return false;
  if (args.context_lines !== undefined && typeof args.context_lines !== 'number') return false;
  if (args.max_results_per_file !== undefined && typeof args.max_results_per_file !== 'number') return false;
  if (args.max_total_results !== undefined && typeof args.max_total_results !== 'number') return false;
  if (args.recursive !== undefined && typeof args.recursive !== 'boolean') return false;
  
  return true;
};

/**
 * Valide les arguments de la méthode search_and_replace
 *
 * @function isValidSearchAndReplaceArgs
 * @param {any} args - Arguments à valider
 * @returns {boolean} - true si les arguments sont valides, false sinon
 */
const isValidSearchAndReplaceArgs = (args: any): args is SearchAndReplaceArgs => {
  if (typeof args !== 'object' || args === null) return false;
  
  // Vérification qu'au moins une des deux options est présente: files ou (paths + search + replace)
  if (!args.files && !(args.paths && args.search && args.replace)) return false;
  
  // Vérification du tableau files s'il est présent
  if (args.files !== undefined) {
    if (!Array.isArray(args.files)) return false;
    
    // Vérification de chaque élément du tableau files
    for (const file of args.files) {
      if (typeof file !== 'object' || file === null) return false;
      if (typeof file.path !== 'string') return false;
      if (typeof file.search !== 'string') return false;
      if (typeof file.replace !== 'string') return false;
      
      // Vérification des paramètres optionnels
      if (file.use_regex !== undefined && typeof file.use_regex !== 'boolean') return false;
      if (file.case_sensitive !== undefined && typeof file.case_sensitive !== 'boolean') return false;
      if (file.preview !== undefined && typeof file.preview !== 'boolean') return false;
    }
  }
  
  // Vérification des paramètres globaux si paths est présent
  if (args.paths !== undefined) {
    if (!Array.isArray(args.paths)) return false;
    
    // Vérification que chaque chemin est une chaîne
    for (const path of args.paths) {
      if (typeof path !== 'string') return false;
    }
    
    // Vérification des paramètres obligatoires pour cette option
    if (typeof args.search !== 'string') return false;
    if (typeof args.replace !== 'string') return false;
  }
  
  // Vérification des paramètres optionnels globaux
  if (args.use_regex !== undefined && typeof args.use_regex !== 'boolean') return false;
  if (args.case_sensitive !== undefined && typeof args.case_sensitive !== 'boolean') return false;
  if (args.file_pattern !== undefined && typeof args.file_pattern !== 'string') return false;
  if (args.recursive !== undefined && typeof args.recursive !== 'boolean') return false;
  if (args.preview !== undefined && typeof args.preview !== 'boolean') return false;
  
  return true;
};

/**
 * Classe principale du serveur QuickFiles
 *
 * Cette classe implémente un serveur MCP qui fournit des méthodes pour lire rapidement
 * le contenu de répertoires et fichiers multiples, ainsi que pour supprimer et éditer des fichiers.
 *
 * @class QuickFilesServer
 */
class QuickFilesServer {
  /** Instance du serveur MCP */
  private server: Server;

  /**
   * Crée une instance du serveur QuickFiles
   *
   * @constructor
   */
  constructor() {
    this.server = new Server(
      {
        name: 'quickfiles-server',
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

  /**
   * Configure les gestionnaires d'outils MCP
   *
   * @private
   * @method setupToolHandlers
   */
  private setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'read_multiple_files',
          description: 'Lit plusieurs fichiers en une seule requête avec numérotation de lignes optionnelle et extraits de fichiers. Tronque automatiquement les contenus volumineux pour éviter les problèmes de mémoire et de performance.',
          inputSchema: {
            type: 'object',
            properties: {
              paths: {
                oneOf: [
                  {
                    type: 'array',
                    items: {
                      type: 'string'
                    },
                    description: 'Tableau des chemins de fichiers à lire',
                  },
                  {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        path: {
                          type: 'string',
                          description: 'Chemin du fichier à lire',
                        },
                        excerpts: {
                          type: 'array',
                          items: {
                            type: 'object',
                            properties: {
                              start: {
                                type: 'number',
                                description: 'Numéro de la première ligne de l\'extrait (commençant à 1)',
                              },
                              end: {
                                type: 'number',
                                description: 'Numéro de la dernière ligne de l\'extrait (incluse)',
                              },
                            },
                            required: ['start', 'end'],
                          },
                          description: 'Liste des extraits à lire dans le fichier',
                        },
                      },
                      required: ['path'],
                    },
                    description: 'Tableau des fichiers avec extraits à lire',
                  },
                ],
                description: 'Chemins des fichiers à lire (format simple ou avec extraits)',
              },
              show_line_numbers: {
                type: 'boolean',
                description: 'Afficher les numéros de ligne',
                default: false,
              },
              max_lines_per_file: {
                type: 'number',
                description: 'Nombre maximum de lignes à afficher par fichier',
                default: 2000,
              },
              max_total_lines: {
                type: 'number',
                description: 'Nombre maximum total de lignes à afficher pour tous les fichiers',
                default: 5000,
              },
              max_chars_per_file: {
                type: 'number',
                description: 'Nombre maximum de caractères à afficher par fichier (évite les problèmes de mémoire avec les gros fichiers)',
                default: 160000,
              },
              max_total_chars: {
                type: 'number',
                description: 'Nombre maximum total de caractères à afficher pour tous les fichiers',
                default: 400000,
              },
            },
            required: ['paths'],
          },
        },
        {
          name: 'list_directory_contents',
          description: 'Liste tous les fichiers et répertoires sous un chemin donné, avec la taille des fichiers et le nombre de lignes. Tronque automatiquement les résultats volumineux pour éviter les problèmes de performance.',
          inputSchema: {
            type: 'object',
            properties: {
              paths: {
                oneOf: [
                  {
                    type: 'array',
                    items: {
                      type: 'string'
                    },
                    description: 'Tableau des chemins de répertoires à lister',
                  },
                  {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        path: {
                          type: 'string',
                          description: 'Chemin du répertoire à lister',
                        },
                        recursive: {
                          type: 'boolean',
                          description: 'Lister récursivement les sous-répertoires',
                          default: true,
                        },
                        max_depth: {
                          type: 'number',
                          description: 'Profondeur maximale d\'exploration des sous-répertoires',
                        },
                        file_pattern: {
                          type: 'string',
                          description: 'Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})',
                        },
                        sort_by: {
                          type: 'string',
                          enum: ['name', 'size', 'modified', 'type'],
                          description: 'Critère de tri des fichiers et répertoires',
                          default: 'name',
                        },
                        sort_order: {
                          type: 'string',
                          enum: ['asc', 'desc'],
                          description: 'Ordre de tri (ascendant ou descendant)',
                          default: 'asc',
                        },
                      },
                      required: ['path'],
                    },
                    description: 'Tableau des répertoires à lister avec options',
                  },
                ],
                description: 'Chemins des répertoires à lister (format simple ou avec options)',
              },
              max_lines: {
                type: 'number',
                description: 'Nombre maximum de lignes à afficher dans la sortie',
                default: 2000,
              },
              max_depth: {
                type: 'number',
                description: 'Profondeur maximale globale d\'exploration des sous-répertoires',
              },
              file_pattern: {
                type: 'string',
                description: 'Motif glob global pour filtrer les fichiers (ex: *.js, *.{js,ts})',
              },
              sort_by: {
                type: 'string',
                enum: ['name', 'size', 'modified', 'type'],
                description: 'Critère de tri global des fichiers et répertoires',
                default: 'name',
              },
              sort_order: {
                type: 'string',
                enum: ['asc', 'desc'],
                description: 'Ordre de tri global (ascendant ou descendant)',
                default: 'asc',
              },
            },
            required: ['paths'],
          },
        },
        {
          name: 'delete_files',
          description: 'Supprime une liste de fichiers en une seule opération',
          inputSchema: {
            type: 'object',
            properties: {
              paths: {
                type: 'array',
                items: {
                  type: 'string'
                },
                description: 'Tableau des chemins de fichiers à supprimer',
              },
            },
            required: ['paths'],
          },
        },
        {
          name: 'extract_markdown_structure',
          description: 'Analyse les fichiers markdown et extrait les titres avec leurs numéros de ligne',
          inputSchema: {
            type: 'object',
            properties: {
              paths: {
                type: 'array',
                items: {
                  type: 'string'
                },
                description: 'Tableau des chemins de fichiers markdown à analyser',
              },
              max_depth: {
                type: 'number',
                description: 'Profondeur maximale des titres à extraire (1=h1, 2=h1+h2, etc.)',
                default: 6,
              },
              include_context: {
                type: 'boolean',
                description: 'Inclure du contexte autour des titres',
                default: false,
              },
              context_lines: {
                type: 'number',
                description: 'Nombre de lignes de contexte à inclure avant et après chaque titre',
                default: 2,
              },
            },
            required: ['paths'],
          },
        },
        {
          name: 'edit_multiple_files',
          description: 'Édite plusieurs fichiers en une seule opération en appliquant des diffs',
          inputSchema: {
            type: 'object',
            properties: {
              files: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    path: {
                      type: 'string',
                      description: 'Chemin du fichier à éditer',
                    },
                    diffs: {
                      type: 'array',
                      items: {
                        type: 'object',
                        properties: {
                          search: {
                            type: 'string',
                            description: 'Texte à rechercher',
                          },
                          replace: {
                            type: 'string',
                            description: 'Texte de remplacement',
                          },
                          start_line: {
                            type: 'number',
                            description: 'Numéro de ligne où commencer la recherche (optionnel)',
                          },
                        },
                        required: ['search', 'replace'],
                      },
                      description: 'Liste des diffs à appliquer au fichier',
                    },
                  },
                  required: ['path', 'diffs'],
                },
                description: 'Tableau des fichiers à éditer avec leurs diffs',
              },
            },
            required: ['files'],
          },
        },
        {
          name: 'search_in_files',
          description: 'Recherche des motifs dans plusieurs fichiers/répertoires avec support des expressions régulières et affichage du contexte autour des correspondances.',
          inputSchema: {
            type: 'object',
            properties: {
              paths: {
                type: 'array',
                items: {
                  type: 'string'
                },
                description: 'Tableau des chemins de fichiers ou répertoires à rechercher',
              },
              pattern: {
                type: 'string',
                description: 'Expression régulière ou texte à rechercher',
              },
              use_regex: {
                type: 'boolean',
                description: 'Utiliser une expression régulière',
                default: true,
              },
              case_sensitive: {
                type: 'boolean',
                description: 'Recherche sensible à la casse',
                default: false,
              },
              file_pattern: {
                type: 'string',
                description: 'Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})',
              },
              context_lines: {
                type: 'number',
                description: 'Nombre de lignes de contexte à afficher avant et après chaque correspondance',
                default: 2,
              },
              max_results_per_file: {
                type: 'number',
                description: 'Nombre maximum de résultats par fichier',
                default: 100,
              },
              max_total_results: {
                type: 'number',
                description: 'Nombre maximum total de résultats',
                default: 1000,
              },
              recursive: {
                type: 'boolean',
                description: 'Rechercher récursivement dans les sous-répertoires',
                default: true,
              },
            },
            required: ['paths', 'pattern'],
          },
        },
        {
          name: 'search_and_replace',
          description: 'Recherche et remplace des motifs dans plusieurs fichiers avec support des expressions régulières et des captures de groupes.',
          inputSchema: {
            type: 'object',
            properties: {
              files: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    path: {
                      type: 'string',
                      description: 'Chemin du fichier à modifier',
                    },
                    search: {
                      type: 'string',
                      description: 'Expression à rechercher',
                    },
                    replace: {
                      type: 'string',
                      description: 'Texte de remplacement',
                    },
                    use_regex: {
                      type: 'boolean',
                      description: 'Utiliser une expression régulière',
                      default: true,
                    },
                    case_sensitive: {
                      type: 'boolean',
                      description: 'Recherche sensible à la casse',
                      default: false,
                    },
                    preview: {
                      type: 'boolean',
                      description: 'Prévisualiser les modifications sans les appliquer',
                      default: false,
                    },
                  },
                  required: ['path', 'search', 'replace'],
                },
                description: 'Tableau des fichiers à modifier avec leurs options',
              },
              paths: {
                type: 'array',
                items: {
                  type: 'string'
                },
                description: 'Tableau des chemins de fichiers ou répertoires à traiter',
              },
              search: {
                type: 'string',
                description: 'Expression à rechercher (globale pour tous les fichiers dans paths)',
              },
              replace: {
                type: 'string',
                description: 'Texte de remplacement (global pour tous les fichiers dans paths)',
              },
              use_regex: {
                type: 'boolean',
                description: 'Utiliser une expression régulière',
                default: true,
              },
              case_sensitive: {
                type: 'boolean',
                description: 'Recherche sensible à la casse',
                default: false,
              },
              file_pattern: {
                type: 'string',
                description: 'Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})',
              },
              recursive: {
                type: 'boolean',
                description: 'Rechercher récursivement dans les sous-répertoires',
                default: true,
              },
              preview: {
                type: 'boolean',
                description: 'Prévisualiser les modifications sans les appliquer',
                default: false,
              },
            },
            oneOf: [
              { required: ['files'] },
              { required: ['paths', 'search', 'replace'] }
            ],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      if (request.params.name === 'read_multiple_files') {
        return this.handleReadMultipleFiles(request);
      } else if (request.params.name === 'list_directory_contents') {
        return this.handleListDirectoryContents(request);
      } else if (request.params.name === 'delete_files') {
        return this.handleDeleteFiles(request);
      } else if (request.params.name === 'edit_multiple_files') {
        return this.handleEditMultipleFiles(request);
      } else if (request.params.name === 'extract_markdown_structure') {
        return this.handleExtractMarkdownStructure(request);
      } else if (request.params.name === 'copy_files') {
        return this.handleCopyFiles(request);
      } else if (request.params.name === 'move_files') {
        return this.handleMoveFiles(request);
      } else if (request.params.name === 'search_in_files') {
        return this.handleSearchInFiles(request);
      } else if (request.params.name === 'search_and_replace') {
        return this.handleSearchAndReplace(request);
      } else {
        throw new McpError(
          ErrorCode.MethodNotFound,
          `Outil inconnu: ${request.params.name}`
        );
      }
    });
  }

  /**
   * Gère les requêtes pour l'outil read_multiple_files
   *
   * @private
   * @method handleReadMultipleFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le contenu des fichiers
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleReadMultipleFiles(request: any) {
    if (!isValidReadMultipleFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour read_multiple_files'
      );
    }

    const {
      paths,
      show_line_numbers = false,
      max_lines_per_file = 2000,
      max_total_lines = 5000,
      max_chars_per_file = 160000, // ~80 caractères par ligne * 2000 lignes
      max_total_chars = 400000 // ~80 caractères par ligne * 5000 lignes
    } = request.params.arguments;

    try {
      const results = await Promise.all(
        paths.map(async (item: string | FileWithExcerpts) => {
          // Déterminer le chemin du fichier et les extraits
          const filePath = typeof item === 'string' ? item : item.path;
          const excerpts = typeof item === 'object' && item.excerpts ? item.excerpts : undefined;
          
          try {
            const content = await fs.readFile(filePath, 'utf-8');
            let lines = content.split('\n');
            let totalChars = content.length;
            let charsTruncated = false;
            
            // Appliquer les extraits si spécifiés
            if (excerpts && excerpts.length > 0) {
              const extractedLines: string[] = [];
              let extractedChars = 0;
              
              for (const excerpt of excerpts) {
                // Ajuster les indices pour correspondre au tableau 0-indexé
                const startIdx = Math.max(0, excerpt.start - 1);
                const endIdx = Math.min(lines.length - 1, excerpt.end - 1);
                
                if (extractedLines.length > 0) {
                  extractedLines.push('...');
                  extractedChars += 3;
                }
                
                const excerptLines = lines.slice(startIdx, endIdx + 1).map((line, idx) => {
                  return show_line_numbers ? `${startIdx + idx + 1} | ${line}` : line;
                });
                
                // Calculer le nombre de caractères dans cet extrait
                const excerptChars = excerptLines.reduce((sum, line) => sum + line.length + 1, 0); // +1 pour le \n
                
                // Vérifier si l'ajout de cet extrait dépasserait la limite de caractères
                if (max_chars_per_file && extractedChars + excerptChars > max_chars_per_file) {
                  // Ajouter autant de lignes que possible sans dépasser la limite
                  let charsAdded = 0;
                  for (const line of excerptLines) {
                    if (extractedChars + charsAdded + line.length + 1 <= max_chars_per_file) {
                      extractedLines.push(line);
                      charsAdded += line.length + 1;
                    } else {
                      charsTruncated = true;
                      break;
                    }
                  }
                  
                  if (charsTruncated) {
                    extractedLines.push(`... (contenu tronqué: limite de ${max_chars_per_file} caractères atteinte)`);
                    break; // Sortir de la boucle des extraits
                  }
                } else {
                  extractedLines.push(...excerptLines);
                  extractedChars += excerptChars;
                }
              }
              
              lines = extractedLines;
            } else {
              // Appliquer la limite de caractères si spécifiée
              if (max_chars_per_file && totalChars > max_chars_per_file) {
                // Trouver combien de lignes on peut inclure sans dépasser la limite de caractères
                let charsCount = 0;
                let i = 0;
                for (; i < lines.length; i++) {
                  charsCount += lines[i].length + 1; // +1 pour le \n
                  if (charsCount > max_chars_per_file) {
                    break;
                  }
                }
                
                lines = lines.slice(0, i);
                lines.push(`... (contenu tronqué: ${totalChars - charsCount} caractères supplémentaires non affichés, taille totale: ${this.formatFileSize(totalChars)})`);
                charsTruncated = true;
              }
              
              // Appliquer la limite de lignes si spécifiée et si la limite de caractères n'a pas déjà tronqué le contenu
              if (!charsTruncated && max_lines_per_file && lines.length > max_lines_per_file) {
                lines = lines.slice(0, max_lines_per_file);
                lines.push(`... (${lines.length - max_lines_per_file} lignes supplémentaires non affichées)`);
              }
              
              // Appliquer la numérotation de lignes si demandée
              if (show_line_numbers) {
                lines = lines.map((line, idx) => `${idx + 1} | ${line}`);
              }
            }
            
            return {
              path: filePath,
              exists: true,
              content: lines.join('\n'),
              error: null,
            };
          } catch (error) {
            return {
              path: filePath,
              exists: false,
              content: null,
              error: `Erreur lors de la lecture du fichier: ${(error as Error).message}`,
            };
          }
        })
      );

      // Compter le nombre total de lignes et de caractères dans tous les fichiers
      let totalLines = 0;
      let totalChars = 0;
      const processedResults = results.map(result => {
        if (result.exists) {
          const lineCount = result.content.split('\n').length;
          const charCount = result.content.length;
          totalLines += lineCount;
          totalChars += charCount;
          return {
            ...result,
            lineCount,
            charCount
          };
        }
        return result;
      });

      // Variables pour suivre si les limites sont dépassées
      let totalLinesExceeded = false;
      let totalCharsExceeded = false;
      
      // Limiter le nombre total de caractères si nécessaire
      if (totalChars > max_total_chars) {
        totalCharsExceeded = true;
        let remainingChars = max_total_chars;
        
        for (let i = 0; i < processedResults.length; i++) {
          const result = processedResults[i];
          if (!result.exists) continue;
          
          const charCount = result.charCount;
          const charsToKeep = Math.min(charCount, remainingChars);
          
          if (charsToKeep < charCount) {
            // Tronquer le contenu pour respecter la limite de caractères
            const content = result.content;
            result.content = content.substring(0, charsToKeep) +
              `\n\n... (contenu tronqué: ${charCount - charsToKeep} caractères supplémentaires non affichés, taille totale: ${this.formatFileSize(charCount)})`;
            
            // Recalculer le nombre de lignes après troncature
            result.lineCount = result.content.split('\n').length;
          }
          
          remainingChars -= charsToKeep;
          if (remainingChars <= 0) break;
        }
      }
      // Limiter le nombre total de lignes si nécessaire (seulement si la limite de caractères n'a pas déjà été appliquée)
      else if (totalLines > max_total_lines) {
        totalLinesExceeded = true;
        let remainingLines = max_total_lines;
        
        for (let i = 0; i < processedResults.length; i++) {
          const result = processedResults[i];
          if (!result.exists) continue;
          
          const lines = result.content.split('\n');
          const linesToKeep = Math.min(lines.length, remainingLines);
          
          if (linesToKeep < lines.length) {
            lines.splice(linesToKeep);
            lines.push(`... (${result.lineCount - linesToKeep} lignes supplémentaires non affichées)`);
            result.content = lines.join('\n');
            
            // Mettre à jour le nombre de caractères après troncature
            result.charCount = result.content.length;
          }
          
          remainingLines -= linesToKeep;
          if (remainingLines <= 0) break;
        }
      }

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = processedResults.map(result => {
        if (result.exists) {
          return `## Fichier: ${result.path}\n\`\`\`\n${result.content}\n\`\`\`\n`;
        } else {
          return `## Fichier: ${result.path}\n**ERREUR**: ${result.error}\n`;
        }
      }).join('\n') +
      (totalCharsExceeded ? `\n\n**Note**: Certains fichiers ont été tronqués car le nombre total de caractères dépasse la limite de ${max_total_chars} (${this.formatFileSize(max_total_chars)}).` :
       totalLinesExceeded ? `\n\n**Note**: Certains fichiers ont été tronqués car le nombre total de lignes dépasse la limite de ${max_total_lines}.` : '');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de la lecture des fichiers: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil list_directory_contents
   *
   * @private
   * @method handleListDirectoryContents
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le contenu des répertoires
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  /**
   * Gère les requêtes pour l'outil list_directory_contents
   *
   * @private
   * @method handleListDirectoryContents
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le contenu des répertoires
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  /**
   * Gère les requêtes pour l'outil list_directory_contents
   *
   * @private
   * @method handleListDirectoryContents
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le contenu des répertoires
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleListDirectoryContents(request: any) {
    if (!isValidListDirectoryContentsArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour list_directory_contents'
      );
    }

    const {
      paths,
      max_lines = 2000,
      max_depth: globalMaxDepth,
      file_pattern: globalFilePattern,
      sort_by: globalSortBy = 'name',
      sort_order: globalSortOrder = 'asc'
    } = request.params.arguments;

    try {
      // Journalisation détaillée des options de tri pour le débogage
      console.error(`[DEBUG] Options de tri globales: critère=${globalSortBy}, ordre=${globalSortOrder}, filtre=${globalFilePattern || 'aucun'}`);
      console.error(`[DEBUG] Nombre de chemins à traiter: ${paths.length}`);
      
      const results = await Promise.all(
        paths.map(async (item: string | DirectoryToList, index: number) => {
          // Déterminer le chemin du répertoire et les options
          const dirPath = typeof item === 'string' ? item : item.path;
          const recursive = typeof item === 'object' && item.recursive !== undefined ? item.recursive : true;
          
          // Utiliser les options spécifiques à ce répertoire ou les options globales
          const maxDepth = typeof item === 'object' && item.max_depth !== undefined
            ? item.max_depth
            : globalMaxDepth;
          
          const filePattern = typeof item === 'object' && item.file_pattern !== undefined
            ? item.file_pattern
            : globalFilePattern;
          
          const sortBy = typeof item === 'object' && item.sort_by !== undefined
            ? item.sort_by
            : globalSortBy;
          
          const sortOrder = typeof item === 'object' && item.sort_order !== undefined
            ? item.sort_order
            : globalSortOrder;
          
          // Journalisation détaillée des options de tri spécifiques pour le débogage
          console.error(`[DEBUG] Répertoire #${index + 1}: ${dirPath}`);
          console.error(`[DEBUG] Options: recursive=${recursive}, max_depth=${maxDepth || 'illimité'}, critère=${sortBy}, ordre=${sortOrder}, filtre=${filePattern || 'aucun'}`);
          
          try {
            // Vérifier que le chemin existe et est un répertoire
            const stats = await fs.stat(dirPath);
            if (!stats.isDirectory()) {
              console.error(`[ERROR] Le chemin n'est pas un répertoire: ${dirPath}`);
              return {
                path: dirPath,
                exists: false,
                error: `Le chemin spécifié n'est pas un répertoire: ${dirPath}`,
              };
            }

            console.error(`[DEBUG] Début du listage récursif pour ${dirPath}`);
            // Lister le contenu du répertoire avec les options de filtrage et de tri
            const contents = await this.listDirectoryContentsRecursive(
              dirPath,
              recursive,
              filePattern,
              sortBy,
              sortOrder,
              maxDepth
            );
            console.error(`[DEBUG] Fin du listage récursif pour ${dirPath}, ${contents.length} éléments trouvés`);
            
            return {
              path: dirPath,
              exists: true,
              contents,
              error: null,
              // Stocker les options de tri utilisées pour référence
              sortOptions: { sortBy, sortOrder }
            };
          } catch (error) {
            console.error(`[ERROR] Erreur lors du listage du répertoire ${dirPath}: ${(error as Error).message}`);
            return {
              path: dirPath,
              exists: false,
              contents: null,
              error: `Erreur lors du listage du répertoire: ${(error as Error).message}`,
            };
          }
        })
      );

      console.error(`[DEBUG] Tous les répertoires ont été traités, formatage de la réponse`);
      
      // Formatage de la réponse pour une meilleure lisibilité
      let formattedResponse = results.map((result, index) => {
        if (result.exists) {
          console.error(`[DEBUG] Formatage du répertoire #${index + 1}: ${result.path} (${result.contents.length} éléments)`);
          // Utiliser les contenus déjà triés
          return this.formatDirectoryContents(result.path, result.contents);
        } else {
          console.error(`[DEBUG] Erreur pour le répertoire #${index + 1}: ${result.path}`);
          return `## Répertoire: ${result.path}\n**ERREUR**: ${result.error}\n`;
        }
      }).join('\n');

      // Limiter le nombre de lignes dans la sortie
      const lines = formattedResponse.split('\n');
      console.error(`[DEBUG] Nombre total de lignes dans la réponse: ${lines.length}`);
      
      if (lines.length > max_lines) {
        console.error(`[DEBUG] Troncature de la réponse à ${max_lines} lignes`);
        formattedResponse = lines.slice(0, max_lines).join('\n') +
          `\n\n... (${lines.length - max_lines} lignes supplémentaires non affichées)`;
      }

      console.error(`[DEBUG] Réponse formatée avec succès`);
      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      console.error(`[ERROR] Erreur globale: ${(error as Error).message}`);
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors du listage des répertoires: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Formate le contenu d'un répertoire pour l'affichage
   *
   * @private
   * @method formatDirectoryContents
   * @param {string} dirPath - Chemin du répertoire
   * @param {any[]} contents - Contenu du répertoire
   * @returns {string} - Contenu formaté
   */
  /**
   * Formate le contenu d'un répertoire pour l'affichage
   *
   * @private
   * @method formatDirectoryContents
   * @param {string} dirPath - Chemin du répertoire
   * @param {any[]} contents - Contenu du répertoire (déjà trié)
   * @returns {string} - Contenu formaté
   */
  /**
   * Formate le contenu d'un répertoire pour l'affichage
   *
   * @private
   * @method formatDirectoryContents
   * @param {string} dirPath - Chemin du répertoire
   * @param {any[]} contents - Contenu du répertoire (déjà trié)
   * @returns {string} - Contenu formaté
   */
  private formatDirectoryContents(dirPath: string, contents: any[]): string {
    console.error(`[DEBUG] Formatage du répertoire: ${dirPath} avec ${contents.length} éléments`);
    
    // Compter les fichiers et répertoires pour le résumé
    const dirCount = contents.filter(item => item.type === 'directory').length;
    const fileCount = contents.filter(item => item.type === 'file').length;
    
    // Compter les fichiers markdown et leurs structures
    const markdownFiles = contents.filter(item =>
      item.type === 'file' &&
      (item.name.toLowerCase().endsWith('.md') || item.name.toLowerCase().endsWith('.markdown'))
    );
    const markdownCount = markdownFiles.length;
    
    // Créer l'en-tête avec des informations sur le contenu
    let result = `## Répertoire: ${dirPath}\n`;
    result += `> Contenu: ${contents.length} éléments (${dirCount} répertoires, ${fileCount} fichiers, dont ${markdownCount} fichiers markdown)\n\n`;
    
    // Fonction récursive pour formater le contenu
    const formatContents = (items: any[], indent: string = '', depth: number = 0): string => {
      let output = '';
      
      // Journaliser le nombre d'éléments à ce niveau
      console.error(`[DEBUG] Formatage de ${items.length} éléments au niveau ${depth}`);
      
      // Utiliser directement les items triés sans les retrier
      for (const item of items) {
        if (item.type === 'directory') {
          // Formater les répertoires
          output += `${indent}📁 ${item.name}/\n`;
          
          if (item.children && item.children.length > 0) {
            // Journaliser le nombre d'enfants
            console.error(`[DEBUG] Répertoire ${item.name} contient ${item.children.length} enfants`);
            output += formatContents(item.children, indent + '  ', depth + 1);
          }
        } else {
          // Formater les fichiers
          const sizeStr = this.formatFileSize(item.size);
          const modifiedStr = new Date(item.modified).toLocaleString();
          const lineCountStr = item.lineCount ? ` (${item.lineCount} lignes)` : '';
          
          // Ajouter des informations sur la structure markdown si disponible
          let markdownStructureStr = '';
          if (item.markdownStructure && item.markdownStructure.headings && item.markdownStructure.headings.length > 0) {
            const headingCounts = [0, 0, 0, 0, 0, 0]; // Compteurs pour h1-h6
            
            for (const heading of item.markdownStructure.headings) {
              if (heading.level >= 1 && heading.level <= 6) {
                headingCounts[heading.level - 1]++;
              }
            }
            
            const headingInfo = headingCounts
              .map((count, index) => count > 0 ? `h${index + 1}: ${count}` : null)
              .filter(Boolean)
              .join(', ');
              
            markdownStructureStr = ` [${headingInfo}]`;
          }
          
          output += `${indent}📄 ${item.name} - ${sizeStr}${lineCountStr}${markdownStructureStr} - Modifié: ${modifiedStr}\n`;
        }
      }
      
      return output;
    };
    
    // Ajouter le contenu formaté au résultat
    result += formatContents(contents);
    
    console.error(`[DEBUG] Formatage terminé pour ${dirPath}`);
    return result;
  }

  /**
   * Formate la taille d'un fichier en unités lisibles (B, KB, MB, GB)
   *
   * @private
   * @method formatFileSize
   * @param {number} bytes - Taille en octets
   * @returns {string} - Taille formatée
   */
  /**
   * Formate la taille d'un fichier en unités lisibles (B, KB, MB, GB, TB)
   * avec une précision adaptée à la taille
   *
   * @private
   * @method formatFileSize
   * @param {number} bytes - Taille en octets
   * @returns {string} - Taille formatée
   */
  private formatFileSize(bytes: number): string {
    // Constantes pour les conversions
    const KB = 1024;
    const MB = KB * 1024;
    const GB = MB * 1024;
    const TB = GB * 1024;
    
    // Journaliser la taille pour le débogage
    console.error(`[DEBUG] Formatage de la taille: ${bytes} octets`);
    
    // Formater avec une précision adaptée à la taille
    if (bytes === 0) return '0 B';
    if (bytes < KB) return `${bytes} B`;
    if (bytes < MB) {
      // Pour les KB, utiliser 1 décimale
      const kb = bytes / KB;
      return `${kb.toFixed(1)} KB`;
    }
    if (bytes < GB) {
      // Pour les MB, utiliser 2 décimales
      const mb = bytes / MB;
      return `${mb.toFixed(2)} MB`;
    }
    if (bytes < TB) {
      // Pour les GB, utiliser 2 décimales
      const gb = bytes / GB;
      return `${gb.toFixed(2)} GB`;
    }
    
    // Pour les TB, utiliser 3 décimales
    const tb = bytes / TB;
    return `${tb.toFixed(3)} TB`;
  }

  /**
   * Liste récursivement le contenu d'un répertoire avec options de filtrage et de tri
   *
   * @private
   * @method listDirectoryContentsRecursive
   * @param {string} dirPath - Chemin du répertoire à lister
   * @param {boolean} recursive - Lister récursivement les sous-répertoires
   * @param {string} [filePattern] - Motif glob pour filtrer les fichiers (ex: *.js, *.{js,ts})
   * @param {string} [sortBy='name'] - Critère de tri:
   *   - 'name': tri alphabétique par nom (insensible à la casse)
   *   - 'size': tri par taille (en octets)
   *   - 'modified': tri par date de modification
   *   - 'type': tri par type (répertoires d'abord, puis fichiers)
   * @param {string} [sortOrder='asc'] - Ordre de tri:
   *   - 'asc': ordre ascendant (A à Z, du plus petit au plus grand, du plus ancien au plus récent)
   *   - 'desc': ordre descendant (Z à A, du plus grand au plus petit, du plus récent au plus ancien)
   * @returns {Promise<any[]>} - Contenu du répertoire filtré et trié
   */
  private async listDirectoryContentsRecursive(
      dirPath: string,
      recursive: boolean,
      filePattern?: string,
      sortBy: 'name' | 'size' | 'modified' | 'type' = 'name',
      sortOrder: 'asc' | 'desc' = 'asc',
      maxDepth?: number,
      currentDepth: number = 1
    ): Promise<any> {
      // Journalisation détaillée pour le débogage
      console.error(`[DEBUG] Listage du répertoire: ${dirPath}`);
      console.error(`[DEBUG] Options: recursive=${recursive}, filePattern=${filePattern || 'none'}, sortBy=${sortBy}, sortOrder=${sortOrder}, maxDepth=${maxDepth || 'illimité'}, currentDepth=${currentDepth}`);
      
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      console.error(`[DEBUG] Nombre d'entrées trouvées: ${entries.length}`);
      
      const result: any[] = [];
  
      // Fonction pour vérifier si un fichier correspond au motif glob
      // Supporte les motifs suivants:
      // - * : correspond à n'importe quelle séquence de caractères
      // - ? : correspond à un seul caractère
      // - {a,b,c} : correspond à l'un des motifs a, b ou c
      // Exemples: "*.js", "*.{js,ts}", "data?.json"
      const matchesPattern = (filename: string, pattern?: string): boolean => {
        if (!pattern) return true; // Pas de filtrage si pas de motif
        
        // Convertir le motif glob en regex
        const regexPattern = pattern
          .replace(/\./g, '\\.')          // Échapper les points
          .replace(/\*/g, '.*')           // * devient .* (n'importe quelle séquence)
          .replace(/\?/g, '.')            // ? devient . (n'importe quel caractère)
          .replace(/\{([^}]+)\}/g, (_, group) => `(${group.split(',').join('|')})`); // {a,b} devient (a|b)
        
        const regex = new RegExp(`^${regexPattern}$`, 'i'); // Insensible à la casse
        return regex.test(filename);
      };
  
      // Calculer la taille totale d'un répertoire (somme des tailles des fichiers)
      const calculateDirectorySize = async (dirPath: string): Promise<number> => {
        try {
          let totalSize = 0;
          const entries = await fs.readdir(dirPath, { withFileTypes: true });
          
          for (const entry of entries) {
            const entryPath = path.join(dirPath, entry.name);
            const stats = await fs.stat(entryPath);
            
            if (entry.isDirectory()) {
              // Ajouter récursivement la taille des sous-répertoires
              totalSize += await calculateDirectorySize(entryPath);
            } else {
              // Ajouter la taille du fichier
              totalSize += stats.size;
            }
          }
          
          return totalSize;
        } catch (error) {
          console.error(`[ERROR] Erreur lors du calcul de la taille du répertoire ${dirPath}: ${(error as Error).message}`);
          return 0; // En cas d'erreur, retourner 0
        }
      };
  
      // Collecter toutes les entrées (fichiers et répertoires)
      for (const entry of entries) {
        const entryPath = path.join(dirPath, entry.name);
        const stats = await fs.stat(entryPath);
        
        if (entry.isDirectory()) {
          // Traitement des répertoires
          let directorySize = stats.size;
          
          // Récupérer les enfants si récursif et si la profondeur maximale n'est pas atteinte
          const shouldRecurse = recursive && (!maxDepth || currentDepth < maxDepth);
          const children = shouldRecurse ? await this.listDirectoryContentsRecursive(
            entryPath,
            recursive,
            filePattern,
            sortBy,
            sortOrder,
            maxDepth,
            currentDepth + 1
          ) : [];
          
          // Pour le tri par taille, calculer la taille totale du répertoire
          if (sortBy === 'size') {
            directorySize = await calculateDirectorySize(entryPath);
            console.error(`[DEBUG] Taille calculée pour le répertoire ${entry.name}: ${directorySize} octets`);
          }
          
          const item = {
            name: entry.name,
            path: entryPath,
            type: 'directory' as const,
            size: directorySize, // Utiliser la taille calculée pour les répertoires
            modified: stats.mtime.toISOString(),
            children
          };
          result.push(item);
        } else {
          // Traitement des fichiers
          // Filtrer les fichiers selon le motif glob si spécifié
          if (filePattern && !matchesPattern(entry.name, filePattern)) {
            console.error(`[DEBUG] Fichier ignoré (ne correspond pas au motif): ${entry.name}`);
            continue; // Ignorer ce fichier s'il ne correspond pas au motif
          }
          
          // Compter le nombre de lignes pour les fichiers texte
          let lineCount: number | undefined = undefined;
          let markdownStructure: any = null;
          
          try {
            // Vérifier si c'est probablement un fichier texte par l'extension
            const textFileExtensions = ['.txt', '.md', '.js', '.ts', '.html', '.css', '.json', '.xml', '.yaml', '.yml', '.py', '.java', '.c', '.cpp', '.h', '.cs', '.php', '.rb', '.go', '.rs', '.swift', '.kt', '.sh', '.bat', '.ps1'];
            const ext = path.extname(entry.name).toLowerCase();
            
            if (textFileExtensions.includes(ext) && stats.size < 10 * 1024 * 1024) { // Limiter à 10 Mo
              const content = await fs.readFile(entryPath, 'utf-8');
              lineCount = content.split('\n').length;
              
              // Analyser la structure markdown si c'est un fichier markdown
              if (ext === '.md' || ext === '.markdown') {
                markdownStructure = this.extractMarkdownHeadings(content, entryPath);
              }
            }
          } catch (error) {
            // Ignorer les erreurs de lecture de fichier
            console.error(`[DEBUG] Erreur lors du comptage des lignes pour ${entry.name}: ${(error as Error).message}`);
          }
          
          const item = {
            name: entry.name,
            path: entryPath,
            type: 'file' as const,
            size: stats.size,
            modified: stats.mtime.toISOString(),
            lineCount,
            ...(markdownStructure && markdownStructure.headings.length > 0 ? { markdownStructure } : {})
          };
          result.push(item);
        }
      }
  
      // Journaliser les éléments avant le tri
      console.error(`[DEBUG] Éléments avant tri (${result.length}):`);
      result.forEach((item, index) => {
        console.error(`[DEBUG]   ${index}. ${item.type === 'directory' ? 'DIR' : 'FILE'} ${item.name} (taille: ${item.size}, modifié: ${item.modified})`);
      });
  
      // Fonction de comparaison pour le tri des éléments (fichiers et répertoires)
      const compareItems = (a: any, b: any): number => {
        // Variable pour stocker le résultat de la comparaison
        let comparison = 0;
        
        // Appliquer le critère de tri principal
        switch (sortBy) {
          case 'name':
            // Tri alphabétique par nom (insensible à la casse)
            // Utilise localeCompare pour un tri correct des caractères accentués et spéciaux
            comparison = a.name.toLowerCase().localeCompare(b.name.toLowerCase(), undefined, {sensitivity: 'base'});
            break;
            
          case 'size':
            // Tri par taille en octets
            // Utilisation de la soustraction pour éviter les problèmes avec les grands nombres
            // Pour les répertoires, la taille est calculée comme la somme des tailles des fichiers contenus
            comparison = a.size - b.size;
            break;
            
          case 'modified':
            // Tri par date de modification
            // Convertit les dates ISO en timestamps pour la comparaison
            const timeA = new Date(a.modified).getTime();
            const timeB = new Date(b.modified).getTime();
            comparison = timeA - timeB;
            break;
            
          case 'type':
            // Tri par type: répertoires d'abord, puis fichiers
            if (a.type !== b.type) {
              comparison = a.type === 'directory' ? -1 : 1; // Répertoires avant fichiers
            } else {
              // Si même type, trier par nom comme critère secondaire
              comparison = a.name.toLowerCase().localeCompare(b.name.toLowerCase(), undefined, {sensitivity: 'base'});
            }
            break;
        }
        
        // Si le critère principal donne une égalité et que ce n'est pas déjà un tri par nom,
        // utiliser le nom comme critère secondaire pour un tri stable et prévisible
        if (comparison === 0 && sortBy !== 'name') {
          comparison = a.name.toLowerCase().localeCompare(b.name.toLowerCase(), undefined, {sensitivity: 'base'});
        }
        
        // Inverser l'ordre si descendant est demandé
        return sortOrder === 'desc' ? -comparison : comparison;
      };
  
      // Trier les résultats selon le critère et l'ordre spécifiés
      if (sortBy === 'type') {
        // Pour le tri par type, on utilise directement la fonction de comparaison
        result.sort(compareItems);
      } else {
        // Pour les autres critères, on trie d'abord par type (répertoires avant fichiers)
        // puis on applique le critère de tri à l'intérieur de chaque groupe
        const directories = result.filter(item => item.type === 'directory').sort(compareItems);
        const files = result.filter(item => item.type === 'file').sort(compareItems);
        
        // Réinitialiser le tableau result avec les éléments triés
        result.length = 0;
        result.push(...directories, ...files);
      }
      
      // Journaliser les éléments après le tri
      console.error(`[DEBUG] Éléments après tri (${result.length}):`);
      result.forEach((item, index) => {
        console.error(`[DEBUG]   ${index}. ${item.type === 'directory' ? 'DIR' : 'FILE'} ${item.name} (taille: ${item.size}, modifié: ${item.modified})`);
      });
  
      return result;
    }

  /**
   * Gère les requêtes pour l'outil delete_files
   *
   * @private
   * @method handleDeleteFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le résultat de la suppression
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleDeleteFiles(request: any) {
    if (!isValidDeleteFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour delete_files'
      );
    }

    const { paths } = request.params.arguments;

    try {
      const results = await Promise.all(
        paths.map(async (filePath: string) => {
          try {
            // Vérifier que le fichier existe avant de le supprimer
            await fs.access(filePath);
            await fs.unlink(filePath);
            
            return {
              path: filePath,
              success: true,
              error: null,
            };
          } catch (error) {
            return {
              path: filePath,
              success: false,
              error: `Erreur lors de la suppression du fichier: ${(error as Error).message}`,
            };
          }
        })
      );

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = results.map(result => {
        if (result.success) {
          return `✅ Fichier supprimé: ${result.path}`;
        } else {
          return `❌ Échec de suppression: ${result.path} - ${result.error}`;
        }
      }).join('\n');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de la suppression des fichiers: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil edit_multiple_files
   *
   * @private
   * @method handleEditMultipleFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le résultat de l'édition
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleEditMultipleFiles(request: any) {
    if (!isValidEditMultipleFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour edit_multiple_files'
      );
    }

    const { files } = request.params.arguments;

    try {
      const results = await Promise.all(
        files.map(async (file: FileEdit) => {
          try {
            // Lire le contenu du fichier
            const content = await fs.readFile(file.path, 'utf-8');
            let modifiedContent = content;
            let hasChanges = false;

            // Appliquer chaque diff
            for (const diff of file.diffs) {
              // Si start_line est spécifié, limiter la recherche à partir de cette ligne
              if (diff.start_line !== undefined) {
                const lines = modifiedContent.split('\n');
                const startIdx = Math.max(0, diff.start_line - 1);
                
                if (startIdx >= lines.length) {
                  continue; // Ignorer ce diff si start_line est hors limites
                }
                
                const beforeLines = lines.slice(0, startIdx).join('\n');
                const searchArea = lines.slice(startIdx).join('\n');
                
                // Appliquer le remplacement uniquement dans la zone de recherche
                const modifiedSearchArea = searchArea.replace(diff.search, diff.replace);
                
                if (searchArea !== modifiedSearchArea) {
                  modifiedContent = beforeLines + (beforeLines ? '\n' : '') + modifiedSearchArea;
                  hasChanges = true;
                }
              } else {
                // Appliquer le remplacement sur tout le contenu
                const newContent = modifiedContent.replace(diff.search, diff.replace);
                
                if (newContent !== modifiedContent) {
                  modifiedContent = newContent;
                  hasChanges = true;
                }
              }
            }

            // Écrire le contenu modifié si des changements ont été effectués
            if (hasChanges) {
              await fs.writeFile(file.path, modifiedContent, 'utf-8');
            }
            
            return {
              path: file.path,
              success: true,
              modified: hasChanges,
              error: null,
            };
          } catch (error) {
            return {
              path: file.path,
              success: false,
              modified: false,
              error: `Erreur lors de l'édition du fichier: ${(error as Error).message}`,
            };
          }
        })
      );

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = results.map(result => {
        if (result.success) {
          return result.modified
            ? `✅ Fichier modifié: ${result.path}`
            : `ℹ️ Aucune modification: ${result.path}`;
        } else {
          return `❌ Échec d'édition: ${result.path} - ${result.error}`;
        }
      }).join('\n');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de l'édition des fichiers: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil extract_markdown_structure
   *
   * @private
   * @method handleExtractMarkdownStructure
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec la structure des fichiers markdown
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleExtractMarkdownStructure(request: any) {
    if (!isValidExtractMarkdownStructureArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour extract_markdown_structure'
      );
    }

    const {
      paths,
      max_depth = 6,
      include_context = false,
      context_lines = 2
    } = request.params.arguments;

    try {
      const results = await Promise.all(
        paths.map(async (filePath: string) => {
          try {
            // Vérifier que le fichier existe et est un fichier markdown
            const stats = await fs.stat(filePath);
            if (!stats.isFile()) {
              return {
                path: filePath,
                exists: false,
                error: `Le chemin spécifié n'est pas un fichier: ${filePath}`,
              };
            }

            const ext = path.extname(filePath).toLowerCase();
            if (ext !== '.md' && ext !== '.markdown') {
              return {
                path: filePath,
                exists: true,
                error: `Le fichier n'est pas un fichier markdown: ${filePath}`,
              };
            }

            // Lire le contenu du fichier
            const content = await fs.readFile(filePath, 'utf-8');
            
            // Extraire les titres avec leurs numéros de ligne
            const { headings, fileInfo } = this.extractMarkdownHeadings(
              content,
              filePath,
              max_depth,
              include_context ? context_lines : 0
            );
            
            return {
              path: filePath,
              exists: true,
              headings,
              fileInfo,
              error: null,
            };
          } catch (error) {
            return {
              path: filePath,
              exists: false,
              headings: [],
              error: `Erreur lors de l'analyse du fichier markdown: ${(error as Error).message}`,
            };
          }
        })
      );

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = results.map(result => {
        if (result.exists && !result.error) {
          // Créer une représentation hiérarchique des titres
          let output = `## Fichier: ${result.path}\n`;
          
          if (result.headings.length === 0) {
            output += "Aucun titre trouvé dans ce fichier.\n";
          } else {
            output += `${result.headings.length} titres trouvés:\n\n`;
            
            for (const heading of result.headings) {
              // Indentation basée sur le niveau du titre
              const indent = '  '.repeat(heading.level - 1);
              output += `${indent}- [Ligne ${heading.line}] ${heading.text}\n`;
              
              // Ajouter le contexte si disponible
              if (heading.context && heading.context.length > 0) {
                output += `${indent}  \`\`\`\n`;
                for (const line of heading.context) {
                  output += `${indent}  ${line}\n`;
                }
                output += `${indent}  \`\`\`\n`;
              }
            }
          }
          
          // Ajouter des statistiques sur les niveaux de titres
          if (result.headings.length > 0) {
            const headingCounts = [0, 0, 0, 0, 0, 0]; // Compteurs pour h1-h6
            
            for (const heading of result.headings) {
              if (heading.level >= 1 && heading.level <= 6) {
                headingCounts[heading.level - 1]++;
              }
            }
            
            output += "\nRépartition des titres:\n";
            for (let i = 0; i < 6; i++) {
              if (headingCounts[i] > 0) {
                output += `- h${i + 1}: ${headingCounts[i]}\n`;
              }
            }
          }
          
          return output;
        } else {
          return `## Fichier: ${result.path}\n**ERREUR**: ${result.error}\n`;
        }
      }).join('\n');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de l'analyse des fichiers markdown: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Extrait les titres markdown d'un contenu avec leurs numéros de ligne
   *
   * @private
   * @method extractMarkdownHeadings
   * @param {string} content - Contenu du fichier markdown
   * @param {string} filePath - Chemin du fichier (pour les logs)
   * @param {number} [maxDepth=6] - Profondeur maximale des titres à extraire
   * @param {number} [contextLines=0] - Nombre de lignes de contexte à inclure
   * @returns {Object} - Objet contenant les titres extraits et des informations sur le fichier
   */
  private extractMarkdownHeadings(
    content: string,
    filePath: string,
    maxDepth: number = 6,
    contextLines: number = 0
  ): { headings: MarkdownHeading[], fileInfo: any } {
    const lines = content.split('\n');
    const headings: MarkdownHeading[] = [];
    
    console.error(`[DEBUG] Extraction des titres markdown de ${filePath} (max_depth=${maxDepth}, context_lines=${contextLines})`);
    
    // Expressions régulières pour les titres markdown
    // Format ATX: # Titre h1, ## Titre h2, etc.
    const atxHeadingRegex = /^(#{1,6})\s+(.+?)(?:\s+#+)?$/;
    
    // Format Setext: Titre h1\n=======, Titre h2\n------
    const setextH1Regex = /^=+\s*$/;
    const setextH2Regex = /^-+\s*$/;
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      let heading: MarkdownHeading | null = null;
      
      // Vérifier le format ATX (# Titre)
      const atxMatch = line.match(atxHeadingRegex);
      if (atxMatch) {
        const level = atxMatch[1].length;
        if (level <= maxDepth) {
          heading = {
            text: atxMatch[2].trim(),
            level,
            line: i + 1, // Les numéros de ligne commencent à 1
          };
        }
      }
      // Vérifier le format Setext (Titre\n====== ou Titre\n------)
      else if (i > 0) {
        if (setextH1Regex.test(line) && lines[i - 1].trim().length > 0) {
          if (1 <= maxDepth) {
            heading = {
              text: lines[i - 1].trim(),
              level: 1,
              line: i, // La ligne précédente est le titre
            };
          }
        } else if (setextH2Regex.test(line) && lines[i - 1].trim().length > 0) {
          if (2 <= maxDepth) {
            heading = {
              text: lines[i - 1].trim(),
              level: 2,
              line: i, // La ligne précédente est le titre
            };
          }
        }
      }
      
      // Si un titre a été trouvé, ajouter le contexte si demandé
      if (heading) {
        if (contextLines > 0) {
          const contextStart = Math.max(0, heading.line - contextLines - 1);
          const contextEnd = Math.min(lines.length - 1, heading.line + contextLines - 1);
          
          heading.context = [];
          for (let j = contextStart; j <= contextEnd; j++) {
            if (j !== heading.line - 1) { // Ne pas inclure la ligne du titre elle-même
              heading.context.push(lines[j]);
            }
          }
        }
        
        headings.push(heading);
      }
    }
    
    console.error(`[DEBUG] ${headings.length} titres extraits de ${filePath}`);
    
    // Collecter des informations sur le fichier
    const fileInfo = {
      totalLines: lines.length,
      headingCount: headings.length,
      headingsByLevel: [0, 0, 0, 0, 0, 0], // Compteurs pour h1-h6
    };
    
    // Compter les titres par niveau
    for (const heading of headings) {
      if (heading.level >= 1 && heading.level <= 6) {
        fileInfo.headingsByLevel[heading.level - 1]++;
      }
    }
    
    return { headings, fileInfo };
  }

  /**
   * Gère les requêtes pour l'outil copy_files
   *
   * @private
   * @method handleCopyFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le résultat de la copie
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleCopyFiles(request: any) {
    if (!isValidCopyFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour copy_files'
      );
    }

    const { operations } = request.params.arguments;

    try {
      const results = await Promise.all(
        operations.map(async (operation: FileCopyOperation) => {
          try {
            const { source, destination, transform, conflict_strategy = 'overwrite' } = operation;
            
            // Résoudre les motifs glob pour trouver tous les fichiers sources
            const sourcePaths = await glob(source);
            
            if (sourcePaths.length === 0) {
              return {
                source,
                success: false,
                error: `Aucun fichier ne correspond au motif: ${source}`,
                files: []
              };
            }
            
            // Déterminer si la destination est un répertoire
            let isDestDir = false;
            try {
              const destStat = await fs.stat(destination);
              isDestDir = destStat.isDirectory();
            } catch (error) {
              // Si la destination n'existe pas, vérifier si elle se termine par un séparateur
              // ou si on a plusieurs fichiers sources (auquel cas ce doit être un répertoire)
              isDestDir = destination.endsWith(path.sep) ||
                         destination.endsWith('/') ||
                         sourcePaths.length > 1;
              
              // Si c'est un répertoire qui n'existe pas, le créer
              if (isDestDir) {
                await fs.mkdir(destination, { recursive: true });
              }
            }
            
            // Copier chaque fichier source
            const fileResults = await Promise.all(
              sourcePaths.map(async (sourcePath) => {
                try {
                  // Déterminer le chemin de destination pour ce fichier
                  let destPath;
                  if (isDestDir) {
                    // Si la destination est un répertoire, utiliser le nom du fichier source
                    let fileName = path.basename(sourcePath);
                    
                    // Appliquer la transformation si spécifiée
                    if (transform) {
                      const regex = new RegExp(transform.pattern);
                      fileName = fileName.replace(regex, transform.replacement);
                    }
                    
                    destPath = path.join(destination, fileName);
                  } else {
                    // Si la destination est un fichier, utiliser directement le chemin de destination
                    destPath = destination;
                  }
                  
                  // Vérifier si le fichier de destination existe déjà
                  let fileExists = false;
                  try {
                    await fs.access(destPath);
                    fileExists = true;
                  } catch (error) {
                    // Le fichier n'existe pas, on peut continuer
                  }
                  
                  // Gérer les conflits selon la stratégie spécifiée
                  if (fileExists) {
                    if (conflict_strategy === 'ignore') {
                      return {
                        source: sourcePath,
                        destination: destPath,
                        success: true,
                        skipped: true,
                        message: 'Fichier ignoré car il existe déjà'
                      };
                    } else if (conflict_strategy === 'rename') {
                      // Générer un nouveau nom avec un suffixe numérique
                      let counter = 1;
                      const ext = path.extname(destPath);
                      const baseName = path.basename(destPath, ext);
                      const dirName = path.dirname(destPath);
                      
                      let newDestPath;
                      do {
                        newDestPath = path.join(dirName, `${baseName}_${counter}${ext}`);
                        counter++;
                        
                        try {
                          await fs.access(newDestPath);
                          // Le fichier existe, essayer avec un autre compteur
                        } catch (error) {
                          // Le fichier n'existe pas, on peut utiliser ce nom
                          break;
                        }
                      } while (counter < 1000); // Limite de sécurité
                      
                      destPath = newDestPath;
                    }
                    // Pour 'overwrite', on continue simplement avec le chemin existant
                  }
                  
                  // Copier le fichier
                  await fs.copyFile(sourcePath, destPath);
                  
                  return {
                    source: sourcePath,
                    destination: destPath,
                    success: true,
                    skipped: false,
                    message: fileExists && conflict_strategy === 'overwrite' ?
                      'Fichier écrasé' : 'Fichier copié avec succès'
                  };
                } catch (error) {
                  return {
                    source: sourcePath,
                    destination: isDestDir ? path.join(destination, path.basename(sourcePath)) : destination,
                    success: false,
                    error: `Erreur lors de la copie: ${(error as Error).message}`
                  };
                }
              })
            );
            
            // Calculer le résultat global pour cette opération
            const successCount = fileResults.filter(r => r.success).length;
            const skippedCount = fileResults.filter(r => r.success && r.skipped).length;
            const failedCount = fileResults.filter(r => !r.success).length;
            
            return {
              source,
              destination,
              success: failedCount === 0,
              summary: `${successCount} fichier(s) traité(s) (${skippedCount} ignoré(s), ${failedCount} échec(s))`,
              files: fileResults
            };
          } catch (error) {
            return {
              source: operation.source,
              destination: operation.destination,
              success: false,
              error: `Erreur lors de l'opération: ${(error as Error).message}`,
              files: []
            };
          }
        })
      );

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = results.map(result => {
        let output = `## Opération: ${result.source} → ${result.destination}\n`;
        
        if (result.success) {
          output += `✅ ${result.summary}\n\n`;
        } else {
          output += `❌ Échec: ${result.error || 'Erreur inconnue'}\n\n`;
        }
        
        if (result.files && result.files.length > 0) {
          output += "### Détails:\n";
          for (const file of result.files) {
            if (file.success) {
              output += file.skipped ?
                `- ⏭️ ${file.source} → ${file.destination} (${file.message})\n` :
                `- ✅ ${file.source} → ${file.destination} (${file.message})\n`;
            } else {
              output += `- ❌ ${file.source} → ${file.destination} (${file.error})\n`;
            }
          }
        }
        
        return output;
      }).join('\n');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de la copie des fichiers: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil move_files
   *
   * @private
   * @method handleMoveFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec le résultat du déplacement
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleMoveFiles(request: any) {
    if (!isValidMoveFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour move_files'
      );
    }

    const { operations } = request.params.arguments;

    try {
      const results = await Promise.all(
        operations.map(async (operation: FileCopyOperation) => {
          try {
            const { source, destination, transform, conflict_strategy = 'overwrite' } = operation;
            
            // Résoudre les motifs glob pour trouver tous les fichiers sources
            const sourcePaths = await glob(source);
            
            if (sourcePaths.length === 0) {
              return {
                source,
                success: false,
                error: `Aucun fichier ne correspond au motif: ${source}`,
                files: []
              };
            }
            
            // Déterminer si la destination est un répertoire
            let isDestDir = false;
            try {
              const destStat = await fs.stat(destination);
              isDestDir = destStat.isDirectory();
            } catch (error) {
              // Si la destination n'existe pas, vérifier si elle se termine par un séparateur
              // ou si on a plusieurs fichiers sources (auquel cas ce doit être un répertoire)
              isDestDir = destination.endsWith(path.sep) ||
                         destination.endsWith('/') ||
                         sourcePaths.length > 1;
              
              // Si c'est un répertoire qui n'existe pas, le créer
              if (isDestDir) {
                await fs.mkdir(destination, { recursive: true });
              }
            }
            
            // Déplacer chaque fichier source
            const fileResults = await Promise.all(
              sourcePaths.map(async (sourcePath) => {
                try {
                  // Déterminer le chemin de destination pour ce fichier
                  let destPath;
                  if (isDestDir) {
                    // Si la destination est un répertoire, utiliser le nom du fichier source
                    let fileName = path.basename(sourcePath);
                    
                    // Appliquer la transformation si spécifiée
                    if (transform) {
                      const regex = new RegExp(transform.pattern);
                      fileName = fileName.replace(regex, transform.replacement);
                    }
                    
                    destPath = path.join(destination, fileName);
                  } else {
                    // Si la destination est un fichier, utiliser directement le chemin de destination
                    destPath = destination;
                  }
                  
                  // Vérifier si le fichier de destination existe déjà
                  let fileExists = false;
                  try {
                    await fs.access(destPath);
                    fileExists = true;
                  } catch (error) {
                    // Le fichier n'existe pas, on peut continuer
                  }
                  
                  // Gérer les conflits selon la stratégie spécifiée
                  if (fileExists) {
                    if (conflict_strategy === 'ignore') {
                      return {
                        source: sourcePath,
                        destination: destPath,
                        success: true,
                        skipped: true,
                        message: 'Fichier ignoré car il existe déjà'
                      };
                    } else if (conflict_strategy === 'rename') {
                      // Générer un nouveau nom avec un suffixe numérique
                      let counter = 1;
                      const ext = path.extname(destPath);
                      const baseName = path.basename(destPath, ext);
                      const dirName = path.dirname(destPath);
                      
                      let newDestPath;
                      do {
                        newDestPath = path.join(dirName, `${baseName}_${counter}${ext}`);
                        counter++;
                        
                        try {
                          await fs.access(newDestPath);
                          // Le fichier existe, essayer avec un autre compteur
                        } catch (error) {
                          // Le fichier n'existe pas, on peut utiliser ce nom
                          break;
                        }
                      } while (counter < 1000); // Limite de sécurité
                      
                      destPath = newDestPath;
                    } else if (conflict_strategy === 'overwrite') {
                      // Supprimer le fichier existant avant de déplacer
                      await fs.unlink(destPath);
                    }
                  }
                  
                  // Déplacer le fichier
                  await fs.rename(sourcePath, destPath);
                  
                  return {
                    source: sourcePath,
                    destination: destPath,
                    success: true,
                    skipped: false,
                    message: fileExists && conflict_strategy === 'overwrite' ?
                      'Fichier écrasé' : 'Fichier déplacé avec succès'
                  };
                } catch (error) {
                  return {
                    source: sourcePath,
                    destination: isDestDir ? path.join(destination, path.basename(sourcePath)) : destination,
                    success: false,
                    error: `Erreur lors du déplacement: ${(error as Error).message}`
                  };
                }
              })
            );
            
            // Calculer le résultat global pour cette opération
            const successCount = fileResults.filter(r => r.success).length;
            const skippedCount = fileResults.filter(r => r.success && r.skipped).length;
            const failedCount = fileResults.filter(r => !r.success).length;
            
            return {
              source,
              destination,
              success: failedCount === 0,
              summary: `${successCount} fichier(s) traité(s) (${skippedCount} ignoré(s), ${failedCount} échec(s))`,
              files: fileResults
            };
          } catch (error) {
            return {
              source: operation.source,
              destination: operation.destination,
              success: false,
              error: `Erreur lors de l'opération: ${(error as Error).message}`,
              files: []
            };
          }
        })
      );

      // Formatage de la réponse pour une meilleure lisibilité
      const formattedResponse = results.map(result => {
        let output = `## Opération: ${result.source} → ${result.destination}\n`;
        
        if (result.success) {
          output += `✅ ${result.summary}\n\n`;
        } else {
          output += `❌ Échec: ${result.error || 'Erreur inconnue'}\n\n`;
        }
        
        if (result.files && result.files.length > 0) {
          output += "### Détails:\n";
          for (const file of result.files) {
            if (file.success) {
              output += file.skipped ?
                `- ⏭️ ${file.source} → ${file.destination} (${file.message})\n` :
                `- ✅ ${file.source} → ${file.destination} (${file.message})\n`;
            } else {
              output += `- ❌ ${file.source} → ${file.destination} (${file.error})\n`;
            }
          }
        }
        
        return output;
      }).join('\n');

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors du déplacement des fichiers: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil search_in_files
   *
   * @private
   * @method handleSearchInFiles
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec les résultats de la recherche
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleSearchInFiles(request: any) {
    if (!isValidSearchInFilesArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour search_in_files'
      );
    }

    const {
      paths,
      pattern,
      use_regex = true,
      case_sensitive = false,
      file_pattern,
      context_lines = 2,
      max_results_per_file = 100,
      max_total_results = 1000,
      recursive = true
    } = request.params.arguments;

    try {
      // Résultats de la recherche
      const results: any[] = [];
      let totalMatches = 0;
      let totalFilesWithMatches = 0;
      let totalFilesSearched = 0;
      let searchLimitReached = false;

      // Créer l'expression régulière pour la recherche
      let searchRegex: RegExp;
      if (use_regex) {
        try {
          searchRegex = new RegExp(pattern, case_sensitive ? 'g' : 'gi');
        } catch (error) {
          throw new McpError(
            ErrorCode.InvalidParams,
            `Expression régulière invalide: ${(error as Error).message}`
          );
        }
      } else {
        // Échapper les caractères spéciaux pour une recherche de texte littéral
        const escapedPattern = pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        searchRegex = new RegExp(escapedPattern, case_sensitive ? 'g' : 'gi');
      }

      // Fonction pour vérifier si un fichier correspond au motif glob
      const matchesPattern = (filename: string, pattern?: string): boolean => {
        if (!pattern) return true; // Pas de filtrage si pas de motif
        
        // Convertir le motif glob en regex
        const regexPattern = pattern
          .replace(/\./g, '\\.')          // Échapper les points
          .replace(/\*/g, '.*')           // * devient .* (n'importe quelle séquence)
          .replace(/\?/g, '.')            // ? devient . (n'importe quel caractère)
          .replace(/\{([^}]+)\}/g, (_, group) => `(${group.split(',').join('|')})`); // {a,b} devient (a|b)
        
        const regex = new RegExp(`^${regexPattern}$`, 'i'); // Insensible à la casse
        return regex.test(filename);
      };

      // Fonction récursive pour rechercher dans un répertoire
      const searchInDirectory = async (dirPath: string, currentDepth: number = 1): Promise<void> => {
        if (searchLimitReached) return;

        try {
          const entries = await fs.readdir(dirPath, { withFileTypes: true });
          
          for (const entry of entries) {
            if (searchLimitReached) break;
            
            const entryPath = path.join(dirPath, entry.name);
            
            if (entry.isDirectory()) {
              // Rechercher récursivement dans les sous-répertoires si demandé
              if (recursive) {
                await searchInDirectory(entryPath, currentDepth + 1);
              }
            } else if (entry.isFile()) {
              // Vérifier si le fichier correspond au motif glob
              if (file_pattern && !matchesPattern(entry.name, file_pattern)) {
                continue;
              }
              
              // Rechercher dans le fichier
              await searchInFile(entryPath);
            }
          }
        } catch (error) {
          console.error(`[ERROR] Erreur lors de la recherche dans le répertoire ${dirPath}: ${(error as Error).message}`);
        }
      };

      // Fonction pour rechercher dans un fichier
      const searchInFile = async (filePath: string): Promise<void> => {
        if (searchLimitReached) return;
        
        totalFilesSearched++;
        
        try {
          // Vérifier si c'est probablement un fichier texte par l'extension
          const ext = path.extname(filePath).toLowerCase();
          const textFileExtensions = ['.txt', '.md', '.js', '.ts', '.html', '.css', '.json', '.xml', '.yaml', '.yml', '.py', '.java', '.c', '.cpp', '.h', '.cs', '.php', '.rb', '.go', '.rs', '.swift', '.kt', '.sh', '.bat', '.ps1'];
          
          if (!textFileExtensions.includes(ext)) {
            return; // Ignorer les fichiers non texte
          }
          
          // Lire le contenu du fichier
          const content = await fs.readFile(filePath, 'utf-8');
          const lines = content.split('\n');
          
          // Rechercher les correspondances
          const fileMatches: any[] = [];
          
          // Réinitialiser lastIndex pour éviter les problèmes avec le flag 'g'
          searchRegex.lastIndex = 0;
          
          // Pour une recherche ligne par ligne
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            searchRegex.lastIndex = 0; // Réinitialiser pour chaque ligne
            
            let match;
            while ((match = searchRegex.exec(line)) !== null) {
              // Ajouter la correspondance avec son contexte
              const lineNumber = i + 1;
              const columnNumber = match.index + 1;
              const matchText = match[0];
              
              // Extraire le contexte autour de la correspondance
              const contextStart = Math.max(0, i - context_lines);
              const contextEnd = Math.min(lines.length - 1, i + context_lines);
              const contextLines = lines.slice(contextStart, contextEnd + 1).map((contextLine, idx) => {
                const lineNum = contextStart + idx + 1;
                const prefix = lineNum === lineNumber ? '> ' : '  ';
                return `${prefix}${lineNum}: ${contextLine}`;
              });
              
              fileMatches.push({
                lineNumber,
                columnNumber,
                matchText,
                context: contextLines.join('\n')
              });
              
              // Vérifier si on a atteint la limite de résultats par fichier
              if (fileMatches.length >= max_results_per_file) {
                break;
              }
              
              // Si l'expression régulière n'a pas le flag 'g', sortir après la première correspondance
              if (!searchRegex.global) break;
            }
            
            // Vérifier si on a atteint la limite de résultats par fichier
            if (fileMatches.length >= max_results_per_file) {
              break;
            }
          }
          
          // Si des correspondances ont été trouvées, ajouter le fichier aux résultats
          if (fileMatches.length > 0) {
            totalFilesWithMatches++;
            totalMatches += fileMatches.length;
            
            results.push({
              path: filePath,
              matches: fileMatches,
              matchCount: fileMatches.length,
              truncated: fileMatches.length >= max_results_per_file
            });
            
            // Vérifier si on a atteint la limite totale de résultats
            if (totalMatches >= max_total_results) {
              searchLimitReached = true;
            }
          }
        } catch (error) {
          console.error(`[ERROR] Erreur lors de la recherche dans le fichier ${filePath}: ${(error as Error).message}`);
        }
      };

      // Traiter chaque chemin spécifié
      for (const searchPath of paths) {
        if (searchLimitReached) break;
        
        try {
          const stats = await fs.stat(searchPath);
          
          if (stats.isDirectory()) {
            // Rechercher dans le répertoire
            await searchInDirectory(searchPath);
          } else if (stats.isFile()) {
            // Rechercher dans le fichier
            await searchInFile(searchPath);
          }
        } catch (error) {
          console.error(`[ERROR] Erreur lors de l'accès au chemin ${searchPath}: ${(error as Error).message}`);
        }
      }

      // Formatage de la réponse pour une meilleure lisibilité
      let formattedResponse = `# Résultats de la recherche pour: "${pattern}"\n\n`;
      formattedResponse += `- **Motif de recherche**: ${use_regex ? 'Expression régulière' : 'Texte littéral'} "${pattern}" ${case_sensitive ? '(sensible à la casse)' : '(insensible à la casse)'}\n`;
      formattedResponse += `- **Fichiers recherchés**: ${totalFilesSearched}\n`;
      formattedResponse += `- **Fichiers avec correspondances**: ${totalFilesWithMatches}\n`;
      formattedResponse += `- **Total des correspondances**: ${totalMatches}\n`;
      
      if (searchLimitReached) {
        formattedResponse += `\n⚠️ **Limite de recherche atteinte**: Seuls les ${max_total_results} premiers résultats sont affichés.\n`;
      }
      
      if (results.length === 0) {
        formattedResponse += "\nAucune correspondance trouvée.\n";
      } else {
        formattedResponse += "\n## Fichiers avec correspondances\n\n";
        
        for (const result of results) {
          formattedResponse += `### ${result.path} (${result.matchCount} correspondance${result.matchCount > 1 ? 's' : ''})\n\n`;
          
          for (const match of result.matches) {
            formattedResponse += `**Ligne ${match.lineNumber}, Colonne ${match.columnNumber}**: \`${match.matchText}\`\n\n`;
            formattedResponse += "```\n" + match.context + "\n```\n\n";
          }
          
          if (result.truncated) {
            formattedResponse += `⚠️ *Résultats tronqués: plus de ${max_results_per_file} correspondances dans ce fichier.*\n\n`;
          }
        }
      }

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors de la recherche: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Gère les requêtes pour l'outil search_and_replace
   *
   * @private
   * @method handleSearchAndReplace
   * @param {any} request - Requête MCP
   * @returns {Promise<any>} - Réponse formatée avec les résultats du remplacement
   * @throws {McpError} - Erreur si les paramètres sont invalides
   */
  private async handleSearchAndReplace(request: any) {
    if (!isValidSearchAndReplaceArgs(request.params.arguments)) {
      throw new McpError(
        ErrorCode.InvalidParams,
        'Paramètres invalides pour search_and_replace'
      );
    }

    const {
      files,
      paths,
      search,
      replace,
      use_regex = true,
      case_sensitive = false,
      file_pattern,
      recursive = true,
      preview = false
    } = request.params.arguments;

    try {
      // Résultats du remplacement
      const results: any[] = [];
      let totalFilesModified = 0;
      let totalReplacements = 0;

      // Fonction pour vérifier si un fichier correspond au motif glob
      const matchesPattern = (filename: string, pattern?: string): boolean => {
        if (!pattern) return true; // Pas de filtrage si pas de motif
        
        // Convertir le motif glob en regex
        const regexPattern = pattern
          .replace(/\./g, '\\.')          // Échapper les points
          .replace(/\*/g, '.*')           // * devient .* (n'importe quelle séquence)
          .replace(/\?/g, '.')            // ? devient . (n'importe quel caractère)
          .replace(/\{([^}]+)\}/g, (_, group) => `(${group.split(',').join('|')})`); // {a,b} devient (a|b)
        
        const regex = new RegExp(`^${regexPattern}$`, 'i'); // Insensible à la casse
        return regex.test(filename);
      };

      // Fonction pour effectuer le remplacement dans un fichier
      const replaceInFile = async (
        filePath: string,
        searchPattern: string,
        replacement: string,
        useRegex: boolean,
        caseSensitive: boolean,
        isPreview: boolean
      ): Promise<any> => {
        try {
          // Lire le contenu du fichier
          const content = await fs.readFile(filePath, 'utf-8');
          
          // Créer l'expression régulière pour la recherche
          let searchRegex: RegExp;
          if (useRegex) {
            try {
              searchRegex = new RegExp(searchPattern, caseSensitive ? 'g' : 'gi');
            } catch (error) {
              throw new Error(`Expression régulière invalide: ${(error as Error).message}`);
            }
          } else {
            // Échapper les caractères spéciaux pour une recherche de texte littéral
            const escapedPattern = searchPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            searchRegex = new RegExp(escapedPattern, caseSensitive ? 'g' : 'gi');
          }
          
          // Effectuer le remplacement et compter les occurrences
          let replacementCount = 0;
          const modifiedContent = content.replace(searchRegex, (match) => {
            replacementCount++;
            return replacement;
          });
          
          // Vérifier si des remplacements ont été effectués
          if (replacementCount > 0) {
            // Générer un diff pour la prévisualisation
            const diff = this.generateDiff(content, modifiedContent, filePath);
            
            // Écrire le contenu modifié si ce n'est pas une prévisualisation
            if (!isPreview) {
              await fs.writeFile(filePath, modifiedContent, 'utf-8');
              totalFilesModified++;
            }
            
            totalReplacements += replacementCount;
            
            return {
              path: filePath,
              replacementCount,
              modified: !isPreview && replacementCount > 0,
              diff
            };
          }
          
          return {
            path: filePath,
            replacementCount: 0,
            modified: false,
            diff: ''
          };
        } catch (error) {
          return {
            path: filePath,
            error: `Erreur lors du remplacement: ${(error as Error).message}`,
            modified: false,
            diff: ''
          };
        }
      };

      // Fonction récursive pour rechercher dans un répertoire
      const processDirectory = async (dirPath: string, currentDepth: number = 1): Promise<void> => {
        try {
          const entries = await fs.readdir(dirPath, { withFileTypes: true });
          
          for (const entry of entries) {
            const entryPath = path.join(dirPath, entry.name);
            
            if (entry.isDirectory()) {
              // Traiter récursivement les sous-répertoires si demandé
              if (recursive) {
                await processDirectory(entryPath, currentDepth + 1);
              }
            } else if (entry.isFile()) {
              // Vérifier si le fichier correspond au motif glob
              if (file_pattern && !matchesPattern(entry.name, file_pattern)) {
                continue;
              }
              
              // Effectuer le remplacement dans le fichier
              const result = await replaceInFile(
                entryPath,
                search,
                replace,
                use_regex,
                case_sensitive,
                preview
              );
              
              if (result.replacementCount > 0 || result.error) {
                results.push(result);
              }
            }
          }
        } catch (error) {
          console.error(`[ERROR] Erreur lors du traitement du répertoire ${dirPath}: ${(error as Error).message}`);
        }
      };

      // Traiter les fichiers spécifiés individuellement
      if (files && files.length > 0) {
        for (const file of files) {
          const result = await replaceInFile(
            file.path,
            file.search,
            file.replace,
            file.use_regex !== undefined ? file.use_regex : use_regex,
            file.case_sensitive !== undefined ? file.case_sensitive : case_sensitive,
            file.preview !== undefined ? file.preview : preview
          );
          
          if (result.replacementCount > 0 || result.error) {
            results.push(result);
          }
        }
      }
      
      // Traiter les chemins spécifiés
      if (paths && paths.length > 0 && search && replace) {
        for (const searchPath of paths) {
          try {
            const stats = await fs.stat(searchPath);
            
            if (stats.isDirectory()) {
              // Traiter le répertoire
              await processDirectory(searchPath);
            } else if (stats.isFile()) {
              // Traiter le fichier
              const result = await replaceInFile(
                searchPath,
                search,
                replace,
                use_regex,
                case_sensitive,
                preview
              );
              
              if (result.replacementCount > 0 || result.error) {
                results.push(result);
              }
            }
          } catch (error) {
            console.error(`[ERROR] Erreur lors de l'accès au chemin ${searchPath}: ${(error as Error).message}`);
          }
        }
      }

      // Formatage de la réponse pour une meilleure lisibilité
      let formattedResponse = `# Résultats du remplacement\n\n`;
      formattedResponse += `- **Mode**: ${preview ? 'Prévisualisation' : 'Remplacement effectif'}\n`;
      formattedResponse += `- **Fichiers modifiés**: ${preview ? '(simulation)' : totalFilesModified}\n`;
      formattedResponse += `- **Total des remplacements**: ${totalReplacements}\n\n`;
      
      if (results.length === 0) {
        formattedResponse += "Aucun remplacement effectué.\n";
      } else {
        for (const result of results) {
          if (result.error) {
            formattedResponse += `## ❌ ${result.path}\n\n**ERREUR**: ${result.error}\n\n`;
          } else if (result.replacementCount > 0) {
            formattedResponse += `## ${preview ? '🔍' : '✅'} ${result.path}\n\n`;
            formattedResponse += `${result.replacementCount} remplacement${result.replacementCount > 1 ? 's' : ''} ${preview ? 'à effectuer' : 'effectué(s)'}\n\n`;
            
            if (result.diff) {
              formattedResponse += "```diff\n" + result.diff + "\n```\n\n";
            }
          }
        }
      }

      return {
        content: [
          {
            type: 'text',
            text: formattedResponse,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Erreur lors du remplacement: ${(error as Error).message}`,
          },
        ],
        isError: true,
      };
    }
  }

  /**
   * Génère un diff entre deux contenus
   *
   * @private
   * @method generateDiff
   * @param {string} oldContent - Contenu original
   * @param {string} newContent - Contenu modifié
   * @param {string} filePath - Chemin du fichier
   * @returns {string} - Diff au format texte
   */
  private generateDiff(oldContent: string, newContent: string, filePath: string): string {
    const oldLines = oldContent.split('\n');
    const newLines = newContent.split('\n');
    
    // Limiter le nombre de lignes pour éviter des diffs trop volumineux
    const maxLines = 50;
    let diff = `--- ${filePath} (original)\n+++ ${filePath} (modifié)\n`;
    
    // Trouver les lignes différentes
    let diffLines = 0;
    let inDiff = false;
    let contextLines = 3; // Nombre de lignes de contexte avant et après les différences
    
    for (let i = 0; i < Math.max(oldLines.length, newLines.length); i++) {
      const oldLine = i < oldLines.length ? oldLines[i] : '';
      const newLine = i < newLines.length ? newLines[i] : '';
      
      if (oldLine !== newLine) {
        // Ajouter des lignes de contexte avant la différence
        if (!inDiff) {
          inDiff = true;
          const startContext = Math.max(0, i - contextLines);
          
          // Ajouter un séparateur si ce n'est pas le début du fichier
          if (startContext > 0) {
            diff += `@@ -${startContext + 1},${contextLines * 2 + 1} +${startContext + 1},${contextLines * 2 + 1} @@\n`;
          }
          
          // Ajouter les lignes de contexte avant
          for (let j = startContext; j < i; j++) {
            if (j < oldLines.length) {
              diff += ` ${oldLines[j]}\n`;
              diffLines++;
            }
          }
        }
        
        // Ajouter les lignes différentes
        if (oldLine) {
          diff += `-${oldLine}\n`;
          diffLines++;
        }
        if (newLine) {
          diff += `+${newLine}\n`;
          diffLines++;
        }
      } else if (inDiff) {
        // Ajouter des lignes de contexte après la différence
        diff += ` ${oldLine}\n`;
        diffLines++;
        
        // Vérifier si on est à la fin d'une section de différences
        const nextOldLine = i + 1 < oldLines.length ? oldLines[i + 1] : '';
        const nextNewLine = i + 1 < newLines.length ? newLines[i + 1] : '';
        
        if (nextOldLine === nextNewLine || i === Math.max(oldLines.length, newLines.length) - 1) {
          inDiff = false;
        }
      }
      
      // Limiter la taille du diff
      if (diffLines >= maxLines) {
        diff += "... (diff tronqué)\n";
        break;
      }
    }
    
    return diff;
  }

  /**
   * Démarre le serveur MCP sur stdio
   *
   * @method run
   * @returns {Promise<void>}
   */
  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('QuickFiles MCP server running on stdio');
  }
}

const server = new QuickFilesServer();
server.run().catch(console.error);
