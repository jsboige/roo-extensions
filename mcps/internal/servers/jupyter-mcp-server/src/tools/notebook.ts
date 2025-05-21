import { Tool } from '@modelcontextprotocol/sdk/types.js';

// Définir ToolSchema comme un type
type ToolSchema = {
  type: string;
  properties: Record<string, any>;
  required?: string[];
};
import * as fs from 'fs/promises';
import * as path from 'path';
import * as nbformat from 'nbformat';

/**
 * Lit un notebook Jupyter à partir d'un fichier
 * @param filePath Chemin du fichier notebook
 * @returns Contenu du notebook
 */
export async function readNotebookFile(filePath: string): Promise<nbformat.INotebookContent> {
  try {
    const absolutePath = path.resolve(filePath);
    const content = await fs.readFile(absolutePath, 'utf-8');
    return JSON.parse(content) as nbformat.INotebookContent;
  } catch (error) {
    console.error(`Erreur lors de la lecture du notebook: ${filePath}`, error);
    throw new Error(`Impossible de lire le notebook: ${error}`);
  }
}

/**
 * Écrit un notebook Jupyter dans un fichier
 * @param filePath Chemin du fichier notebook
 * @param notebook Contenu du notebook
 */
export async function writeNotebookFile(filePath: string, notebook: nbformat.INotebookContent): Promise<void> {
  try {
    const absolutePath = path.resolve(filePath);
    const content = JSON.stringify(notebook, null, 2);
    await fs.writeFile(absolutePath, content, 'utf-8');
  } catch (error) {
    console.error(`Erreur lors de l'écriture du notebook: ${filePath}`, error);
    throw new Error(`Impossible d'écrire le notebook: ${error}`);
  }
}

/**
 * Crée un nouveau notebook vide
 * @param kernelName Nom du kernel (ex: 'python3')
 * @returns Nouveau notebook
 */
function createEmptyNotebook(kernelName: string = 'python3'): nbformat.INotebookContent {
  return {
    cells: [],
    metadata: {
      kernelspec: {
        display_name: kernelName,
        language: kernelName.includes('python') ? 'python' : kernelName,
        name: kernelName
      },
      language_info: {
        name: kernelName.includes('python') ? 'python' : kernelName,
        version: ''
      }
    },
    nbformat: 4,
    nbformat_minor: 5
  };
}

/**
 * Ajoute une cellule à un notebook
 * @param notebook Notebook à modifier
 * @param cellType Type de cellule ('code', 'markdown', 'raw')
 * @param source Contenu de la cellule
 * @param metadata Métadonnées de la cellule (optionnel)
 * @returns Notebook modifié
 */
function addCell(
  notebook: nbformat.INotebookContent,
  cellType: 'code' | 'markdown' | 'raw',
  source: string,
  metadata: any = {}
): nbformat.INotebookContent {
  const cell: any = {
    cell_type: cellType,
    metadata: metadata,
    source: source.split('\n')
  };

  if (cellType === 'code') {
    cell.execution_count = null;
    cell.outputs = [];
  }

  notebook.cells.push(cell);
  return notebook;
}

/**
 * Supprime une cellule d'un notebook
 * @param notebook Notebook à modifier
 * @param index Index de la cellule à supprimer
 * @returns Notebook modifié
 */
function removeCell(notebook: nbformat.INotebookContent, index: number): nbformat.INotebookContent {
  if (index < 0 || index >= notebook.cells.length) {
    throw new Error(`Index de cellule invalide: ${index}`);
  }

  notebook.cells.splice(index, 1);
  return notebook;
}

/**
 * Modifie une cellule d'un notebook
 * @param notebook Notebook à modifier
 * @param index Index de la cellule à modifier
 * @param source Nouveau contenu de la cellule
 * @returns Notebook modifié
 */
function updateCell(
  notebook: nbformat.INotebookContent,
  index: number,
  source: string
): nbformat.INotebookContent {
  if (index < 0 || index >= notebook.cells.length) {
    throw new Error(`Index de cellule invalide: ${index}`);
  }

  notebook.cells[index].source = source.split('\n');
  return notebook;
}

// Schéma pour l'outil read_notebook
const readNotebookSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    }
  },
  required: ['path']
};

// Schéma pour l'outil write_notebook
const writeNotebookSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    content: {
      type: 'object',
      description: 'Contenu du notebook au format nbformat'
    }
  },
  required: ['path', 'content']
};

// Schéma pour l'outil create_notebook
const createNotebookSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    kernel: {
      type: 'string',
      description: 'Nom du kernel (ex: python3)',
      default: 'python3'
    }
  },
  required: ['path']
};

// Schéma pour l'outil add_cell
const addCellSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    cell_type: {
      type: 'string',
      enum: ['code', 'markdown', 'raw'],
      description: 'Type de cellule'
    },
    source: {
      type: 'string',
      description: 'Contenu de la cellule'
    },
    metadata: {
      type: 'object',
      description: 'Métadonnées de la cellule (optionnel)'
    }
  },
  required: ['path', 'cell_type', 'source']
};

// Schéma pour l'outil remove_cell
const removeCellSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    index: {
      type: 'number',
      description: 'Index de la cellule à supprimer'
    }
  },
  required: ['path', 'index']
};

// Schéma pour l'outil update_cell
const updateCellSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    index: {
      type: 'number',
      description: 'Index de la cellule à modifier'
    },
    source: {
      type: 'string',
      description: 'Nouveau contenu de la cellule'
    }
  },
  required: ['path', 'index', 'source']
};

// Définition des outils MCP pour la gestion des notebooks
export const notebookTools: Tool[] = [
  {
    name: 'read_notebook',
    description: 'Lit un notebook Jupyter à partir d\'un fichier',
    schema: readNotebookSchema,
    handler: async ({ path }) => {
      try {
        const notebook = await readNotebookFile(path);
        return {
          notebook,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: notebook.cells
        };
      } catch (error) {
        throw new Error(`Erreur lors de la lecture du notebook: ${error}`);
      }
    }
  },
  {
    name: 'write_notebook',
    description: 'Écrit un notebook Jupyter dans un fichier',
    schema: writeNotebookSchema,
    handler: async ({ path, content }) => {
      try {
        await writeNotebookFile(path, content);
        return {
          success: true,
          message: `Notebook écrit avec succès: ${path}`,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: content.cells || []
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'écriture du notebook: ${error}`);
      }
    }
  },
  {
    name: 'create_notebook',
    description: 'Crée un nouveau notebook vide',
    schema: createNotebookSchema,
    handler: async ({ path, kernel = 'python3' }) => {
      try {
        const notebook = createEmptyNotebook(kernel);
        await writeNotebookFile(path, notebook);
        return {
          success: true,
          message: `Notebook créé avec succès: ${path}`,
          notebook,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: notebook.cells
        };
      } catch (error) {
        throw new Error(`Erreur lors de la création du notebook: ${error}`);
      }
    }
  },
  {
    name: 'add_cell',
    description: 'Ajoute une cellule à un notebook',
    schema: addCellSchema,
    handler: async ({ path, cell_type, source, metadata = {} }) => {
      try {
        const notebook = await readNotebookFile(path);
        const updatedNotebook = addCell(notebook, cell_type as any, source, metadata);
        await writeNotebookFile(path, updatedNotebook);
        return {
          success: true,
          message: `Cellule ajoutée avec succès au notebook: ${path}`,
          cell_index: updatedNotebook.cells.length - 1,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: updatedNotebook.cells
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'ajout de la cellule: ${error}`);
      }
    }
  },
  {
    name: 'remove_cell',
    description: 'Supprime une cellule d\'un notebook',
    schema: removeCellSchema,
    handler: async ({ path, index }) => {
      try {
        const notebook = await readNotebookFile(path);
        const updatedNotebook = removeCell(notebook, index);
        await writeNotebookFile(path, updatedNotebook);
        return {
          success: true,
          message: `Cellule supprimée avec succès du notebook: ${path}`,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: updatedNotebook.cells
        };
      } catch (error) {
        throw new Error(`Erreur lors de la suppression de la cellule: ${error}`);
      }
    }
  },
  {
    name: 'update_cell',
    description: 'Modifie une cellule d\'un notebook',
    schema: updateCellSchema,
    handler: async ({ path, index, source }) => {
      try {
        const notebook = await readNotebookFile(path);
        const updatedNotebook = updateCell(notebook, index, source);
        await writeNotebookFile(path, updatedNotebook);
        return {
          success: true,
          message: `Cellule modifiée avec succès dans le notebook: ${path}`,
          // Ajout du champ content pour résoudre l'erreur de validation de schéma
          content: updatedNotebook.cells
        };
      } catch (error) {
        throw new Error(`Erreur lors de la modification de la cellule: ${error}`);
      }
    }
  }
];