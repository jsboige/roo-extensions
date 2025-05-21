/**
 * Tests unitaires pour les outils d'exécution du serveur Jupyter MCP
 * 
 * Ces tests vérifient les fonctionnalités des outils d'exécution, y compris :
 * - Exécution de code dans un kernel
 * - Exécution de toutes les cellules d'un notebook
 * - Exécution d'une cellule spécifique d'un notebook
 */

import { jest } from '@jest/globals';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur Jupyter MCP pour les tests unitaires
// Nous devons mocker le serveur car nous ne voulons pas dépendre d'un serveur Jupyter réel pour les tests
const mockKernelId = 'mock-kernel-id';

// Mock des résultats d'exécution
const mockExecutionResult = {
  status: 'ok',
  execution_count: 1,
  outputs: [
    {
      type: 'stream',
      name: 'stdout',
      text: 'Hello, world!'
    }
  ]
};

// Mock des fonctions du service Jupyter
const mockExecuteCode = jest.fn().mockImplementation((kernelId, code) => {
  if (kernelId === 'invalid-kernel-id') {
    return Promise.reject(new Error('Kernel non trouvé'));
  }
  if (code.includes('error')) {
    return Promise.resolve({
      status: 'error',
      execution_count: 1,
      outputs: [
        {
          type: 'error',
          name: 'NameError',
          value: 'name is not defined',
          traceback: ['Traceback...']
        }
      ]
    });
  }
  return Promise.resolve(mockExecutionResult);
});

// Mock du module jupyter.js
jest.mock('../dist/services/jupyter.js', () => ({
  initializeJupyterServices: jest.fn().mockResolvedValue(true),
  startKernel: jest.fn().mockResolvedValue(mockKernelId),
  stopKernel: jest.fn().mockResolvedValue(true),
  listAvailableKernels: jest.fn().mockResolvedValue([
    { name: 'python3', spec: { display_name: 'Python 3' } }
  ]),
  listActiveKernels: jest.fn().mockReturnValue([
    { id: mockKernelId, name: 'python3' }
  ]),
  executeCode: mockExecuteCode,
  interruptKernel: jest.fn().mockResolvedValue(true),
  restartKernel: jest.fn().mockResolvedValue(true),
  getKernel: jest.fn().mockReturnValue({})
}));

// Import des modules après le mock
import { JupyterMcpServer } from '../dist/index.js';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, '..', 'test-temp');

// Mocks pour les requêtes MCP
const mockRequest = (name, args) => ({
  params: {
    name,
    arguments: args
  }
});

// Exemple de notebook simple pour les tests
const sampleNotebook = {
  cells: [
    {
      cell_type: 'markdown',
      metadata: {},
      source: ['# Notebook de test']
    },
    {
      cell_type: 'code',
      execution_count: null,
      metadata: {},
      outputs: [],
      source: ['print("Hello, world!")']
    },
    {
      cell_type: 'code',
      execution_count: null,
      metadata: {},
      outputs: [],
      source: ['# Cellule avec une erreur', 'undefined_variable']
    }
  ],
  metadata: {
    kernelspec: {
      display_name: 'Python 3',
      language: 'python',
      name: 'python3'
    },
    language_info: {
      name: 'python',
      version: '3.8.0'
    }
  },
  nbformat: 4,
  nbformat_minor: 5
};

describe('Jupyter MCP Server - Outils d\'Exécution', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Réinitialiser les mocks
    mockExecuteCode.mockClear();
    
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'test-notebook.ipynb': JSON.stringify(sampleNotebook, null, 2)
      }
    });
    
    // Créer une instance du serveur Jupyter MCP
    server = new JupyterMcpServer();
  });
  
  // Nettoyer le système de fichiers simulé après chaque test
  afterEach(() => {
    mockFs.restore();
    jest.clearAllMocks();
  });

  // Tests pour execute_cell
  describe('execute_cell', () => {
    test('devrait exécuter du code avec succès', async () => {
      const request = mockRequest('execute_cell', {
        kernel_id: mockKernelId,
        code: 'print("Hello, world!")'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.execution_count).toBe(1);
      expect(response.status).toBe('ok');
      expect(response.outputs).toBeDefined();
      expect(response.outputs.length).toBe(1);
      expect(response.outputs[0].text).toBe('Hello, world!');
      
      expect(mockExecuteCode).toHaveBeenCalledTimes(1);
      expect(mockExecuteCode).toHaveBeenCalledWith(mockKernelId, 'print("Hello, world!")');
    });
    
    test('devrait gérer les erreurs d\'exécution', async () => {
      const request = mockRequest('execute_cell', {
        kernel_id: mockKernelId,
        code: 'error_code'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.status).toBe('error');
      expect(response.outputs).toBeDefined();
      expect(response.outputs.length).toBe(1);
      expect(response.outputs[0].type).toBe('error');
      
      expect(mockExecuteCode).toHaveBeenCalledTimes(1);
    });
    
    test('devrait gérer les kernels inexistants', async () => {
      const request = mockRequest('execute_cell', {
        kernel_id: 'invalid-kernel-id',
        code: 'print("Hello, world!")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockExecuteCode).toHaveBeenCalledTimes(1);
      expect(mockExecuteCode).toHaveBeenCalledWith('invalid-kernel-id', 'print("Hello, world!")');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const invalidRequests = [
        // kernel_id manquant
        mockRequest('execute_cell', {
          code: 'print("Hello, world!")'
        }),
        // code manquant
        mockRequest('execute_cell', {
          kernel_id: mockKernelId
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
  });

  // Tests pour execute_notebook
  describe('execute_notebook', () => {
    test('devrait exécuter toutes les cellules d\'un notebook avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('execute_notebook', {
        path: notebookPath,
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.message).toContain('Notebook exécuté avec succès');
      expect(response.cell_count).toBe(3); // 1 markdown + 2 code
      
      // Vérifier que executeCode a été appelé pour chaque cellule de code
      expect(mockExecuteCode).toHaveBeenCalledTimes(2);
      
      // Vérifier que le notebook a été mis à jour avec les résultats
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells[1].execution_count).toBe(1); // Première cellule de code
      expect(notebook.cells[1].outputs).toBeDefined();
      expect(notebook.cells[2].execution_count).toBe(1); // Deuxième cellule de code
      expect(notebook.cells[2].outputs).toBeDefined();
    });
    
    test('devrait gérer les notebooks inexistants', async () => {
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
    
    test('devrait gérer les kernels inexistants', async () => {
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        kernel_id: 'invalid-kernel-id'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('execute_notebook', {
          kernel_id: mockKernelId
        }),
        // kernel_id manquant
        mockRequest('execute_notebook', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb')
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
  });

  // Tests pour execute_notebook_cell
  describe('execute_notebook_cell', () => {
    test('devrait exécuter une cellule spécifique d\'un notebook avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('execute_notebook_cell', {
        path: notebookPath,
        cell_index: 1, // Deuxième cellule (première cellule de code)
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.message).toContain('Cellule exécutée avec succès');
      expect(response.execution_count).toBe(1);
      expect(response.outputs).toBeDefined();
      
      expect(mockExecuteCode).toHaveBeenCalledTimes(1);
      expect(mockExecuteCode).toHaveBeenCalledWith(mockKernelId, 'print("Hello, world!")');
      
      // Vérifier que le notebook a été mis à jour avec les résultats
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells[1].execution_count).toBe(1);
      expect(notebook.cells[1].outputs).toBeDefined();
    });
    
    test('devrait gérer les index de cellule invalides', async () => {
      const request = mockRequest('execute_notebook_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        cell_index: 10, // Index invalide
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
    
    test('devrait gérer les cellules non-code', async () => {
      const request = mockRequest('execute_notebook_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        cell_index: 0, // Cellule markdown
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
    
    test('devrait gérer les erreurs d\'exécution', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('execute_notebook_cell', {
        path: notebookPath,
        cell_index: 2, // Cellule avec une erreur
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.outputs).toBeDefined();
      expect(response.outputs[0].type).toBe('error');
      
      expect(mockExecuteCode).toHaveBeenCalledTimes(1);
      
      // Vérifier que le notebook a été mis à jour avec les résultats d'erreur
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells[2].execution_count).toBe(1);
      expect(notebook.cells[2].outputs).toBeDefined();
      expect(notebook.cells[2].outputs[0].type).toBe('error');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('execute_notebook_cell', {
          cell_index: 1,
          kernel_id: mockKernelId
        }),
        // cell_index manquant
        mockRequest('execute_notebook_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          kernel_id: mockKernelId
        }),
        // kernel_id manquant
        mockRequest('execute_notebook_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          cell_index: 1
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
  });

  // Tests de cas limites et d'erreurs
  describe('cas limites et erreurs', () => {
    test('devrait gérer les formats de notebook invalides', async () => {
      // Créer un fichier avec un contenu JSON invalide
      await fs.writeFile(path.join(TEST_DIR, 'invalid-notebook.ipynb'), 'Not a valid JSON', 'utf-8');
      
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'invalid-notebook.ipynb'),
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
    
    test('devrait gérer les erreurs de permission', async () => {
      // Simuler un fichier sans permission d'écriture
      mockFs.restore();
      mockFs({
        [TEST_DIR]: {
          'no-permission.ipynb': mockFs.file({
            content: JSON.stringify(sampleNotebook, null, 2),
            mode: 0o444 // Lecture seule
          })
        }
      });
      
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks vides', async () => {
      // Créer un notebook vide
      const emptyNotebook = {
        cells: [],
        metadata: {
          kernelspec: {
            display_name: 'Python 3',
            language: 'python',
            name: 'python3'
          }
        },
        nbformat: 4,
        nbformat_minor: 5
      };
      
      await fs.writeFile(path.join(TEST_DIR, 'empty-notebook.ipynb'), JSON.stringify(emptyNotebook, null, 2), 'utf-8');
      
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'empty-notebook.ipynb'),
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.cell_count).toBe(0);
      
      expect(mockExecuteCode).not.toHaveBeenCalled();
    });
  });
});