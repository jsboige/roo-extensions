import { Tool } from '@modelcontextprotocol/sdk/types.js';

// Définir ToolSchema comme un type
type ToolSchema = {
  type: string;
  properties: Record<string, any>;
  required?: string[];
};
import { executeCode, getKernel } from '../services/jupyter.js';
import { readNotebookFile, writeNotebookFile } from './notebook.js';
import * as nbformat from 'nbformat';

/**
 * Exécute une cellule de code dans un kernel spécifique
 * @param kernelId ID du kernel
 * @param code Code à exécuter
 * @returns Résultat de l'exécution
 */
async function executeCellCode(kernelId: string, code: string): Promise<any> {
  try {
    return await executeCode(kernelId, code);
  } catch (error) {
    console.error('Erreur lors de l\'exécution de la cellule:', error);
    throw error;
  }
}

/**
 * Exécute toutes les cellules de code d'un notebook
 * @param notebookPath Chemin du fichier notebook
 * @param kernelId ID du kernel
 * @returns Notebook avec les résultats d'exécution
 */
async function executeNotebookCells(notebookPath: string, kernelId: string): Promise<nbformat.INotebookContent> {
  try {
    // Lire le notebook
    const notebook = await readNotebookFile(notebookPath);
    
    // Exécuter chaque cellule de code
    for (let i = 0; i < notebook.cells.length; i++) {
      const cell = notebook.cells[i];
      
      if (cell.cell_type === 'code') {
        // Récupérer le code de la cellule
        const code = Array.isArray(cell.source) ? cell.source.join('') : cell.source;
        
        // Exécuter le code
        const result = await executeCode(kernelId, code);
        
        // Mettre à jour la cellule avec les résultats
        cell.execution_count = result.execution_count;
        cell.outputs = result.outputs;
      }
    }
    
    // Sauvegarder le notebook avec les résultats
    await writeNotebookFile(notebookPath, notebook);
    
    return notebook;
  } catch (error) {
    console.error('Erreur lors de l\'exécution du notebook:', error);
    throw error;
  }
}

// Schéma pour l'outil execute_cell
const executeCellSchema: ToolSchema = {
  type: 'object',
  properties: {
    kernel_id: {
      type: 'string',
      description: 'ID du kernel sur lequel exécuter le code'
    },
    code: {
      type: 'string',
      description: 'Code à exécuter'
    }
  },
  required: ['kernel_id', 'code']
};

// Schéma pour l'outil execute_notebook
const executeNotebookSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    kernel_id: {
      type: 'string',
      description: 'ID du kernel sur lequel exécuter le notebook'
    }
  },
  required: ['path', 'kernel_id']
};

// Schéma pour l'outil execute_notebook_cell
const executeNotebookCellSchema: ToolSchema = {
  type: 'object',
  properties: {
    path: {
      type: 'string',
      description: 'Chemin du fichier notebook (.ipynb)'
    },
    cell_index: {
      type: 'number',
      description: 'Index de la cellule à exécuter'
    },
    kernel_id: {
      type: 'string',
      description: 'ID du kernel sur lequel exécuter la cellule'
    }
  },
  required: ['path', 'cell_index', 'kernel_id']
};

// Définition des outils MCP pour l'exécution de code
export const executionTools: Tool[] = [
  {
    name: 'execute_cell',
    description: 'Exécute du code dans un kernel spécifique',
    schema: executeCellSchema,
    handler: async ({ kernel_id, code }) => {
      try {
        const result = await executeCellCode(kernel_id, code);
        
        return {
          execution_count: result.execution_count,
          status: result.status,
          outputs: result.outputs
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'exécution du code: ${error}`);
      }
    }
  },
  {
    name: 'execute_notebook',
    description: 'Exécute toutes les cellules de code d\'un notebook',
    schema: executeNotebookSchema,
    handler: async ({ path, kernel_id }) => {
      try {
        const notebook = await executeNotebookCells(path, kernel_id);
        
        return {
          success: true,
          message: `Notebook exécuté avec succès: ${path}`,
          cell_count: notebook.cells.length
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'exécution du notebook: ${error}`);
      }
    }
  },
  {
    name: 'execute_notebook_cell',
    description: 'Exécute une cellule spécifique d\'un notebook',
    schema: executeNotebookCellSchema,
    handler: async ({ path, cell_index, kernel_id }) => {
      try {
        // Lire le notebook
        const notebook = await readNotebookFile(path);
        
        if (cell_index < 0 || cell_index >= notebook.cells.length) {
          throw new Error(`Index de cellule invalide: ${cell_index}`);
        }
        
        const cell = notebook.cells[cell_index];
        
        if (cell.cell_type !== 'code') {
          throw new Error(`La cellule à l'index ${cell_index} n'est pas une cellule de code`);
        }
        
        // Récupérer le code de la cellule
        const code = Array.isArray(cell.source) ? cell.source.join('') : cell.source;
        
        // Exécuter le code
        const result = await executeCode(kernel_id, code);
        
        // Mettre à jour la cellule avec les résultats
        cell.execution_count = result.execution_count;
        cell.outputs = result.outputs;
        
        // Sauvegarder le notebook avec les résultats
        await writeNotebookFile(path, notebook);
        
        return {
          success: true,
          message: `Cellule exécutée avec succès: ${path}[${cell_index}]`,
          execution_count: result.execution_count,
          outputs: result.outputs
        };
      } catch (error) {
        throw new Error(`Erreur lors de l'exécution de la cellule: ${error}`);
      }
    }
  }
];