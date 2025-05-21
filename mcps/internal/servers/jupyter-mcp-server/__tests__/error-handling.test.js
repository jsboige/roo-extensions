/**
 * Tests de gestion d'erreurs pour le serveur Jupyter MCP
 * 
 * Ces tests vérifient la robustesse du serveur Jupyter MCP face à différentes situations d'erreur :
 * - Paramètres invalides
 * - Fichiers inexistants
 * - Permissions insuffisantes
 * - Erreurs de connexion au serveur Jupyter
 * - Formats de notebook invalides
 * - Limites et cas particuliers
 */

import { jest } from '@jest/globals';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur Jupyter MCP pour les tests unitaires
const mockKernelId = 'mock-kernel-id';

// Mock des fonctions du service Jupyter avec des erreurs
const mockStartKernel = jest.fn().mockImplementation((kernelName) => {
  if (kernelName === 'invalid-kernel') {
    return Promise.reject(new Error('Kernel non disponible'));
  }
  return Promise.resolve(mockKernelId);
});

const mockStopKernel = jest.fn().mockImplementation((kernelId) => {
  if (kernelId === 'invalid-kernel-id') {
    return Promise.reject(new Error('Kernel non trouvé'));
  }
  return Promise.resolve(true);
});

const mockListAvailableKernels = jest.fn().mockImplementation(() => {
  if (process.env.SIMULATE_CONNECTION_ERROR === 'true') {
    return Promise.reject(new Error('Erreur de connexion au serveur Jupyter'));
  }
  return Promise.resolve([
    { name: 'python3', spec: { display_name: 'Python 3' } }
  ]);
});

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
  return Promise.resolve({
    status: 'ok',
    execution_count: 1,
    outputs: [
      {
        type: 'stream',
        name: 'stdout',
        text: 'Hello, world!'
      }
    ]
  });
});

// Mock du module jupyter.js
jest.mock('../dist/services/jupyter.js', () => ({
  initializeJupyterServices: jest.fn().mockImplementation(() => {
    if (process.env.SIMULATE_CONNECTION_ERROR === 'true') {
      return Promise.reject(new Error('Erreur de connexion au serveur Jupyter'));
    }
    return Promise.resolve(true);
  }),
  startKernel: mockStartKernel,
  stopKernel: mockStopKernel,
  listAvailableKernels: mockListAvailableKernels,
  listActiveKernels: jest.fn().mockReturnValue([
    { id: mockKernelId, name: 'python3' }
  ]),
  executeCode: mockExecuteCode,
  interruptKernel: jest.fn().mockImplementation((kernelId) => {
    if (kernelId === 'invalid-kernel-id') {
      return Promise.reject(new Error('Kernel non trouvé'));
    }
    return Promise.resolve(true);
  }),
  restartKernel: jest.fn().mockImplementation((kernelId) => {
    if (kernelId === 'invalid-kernel-id') {
      return Promise.reject(new Error('Kernel non trouvé'));
    }
    return Promise.resolve(true);
  }),
  getKernel: jest.fn().mockImplementation((kernelId) => {
    if (kernelId === 'invalid-kernel-id') {
      throw new Error('Kernel non trouvé');
    }
    return {};
  })
}));

// Import des modules après le mock
import { JupyterMcpServer } from '../dist/index.js';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de test temporaire
const TEST_DIR = path.join(__dirname, '..', 'test-temp-errors');

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

describe('Jupyter MCP Server - Gestion des Erreurs', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Réinitialiser les variables d'environnement
    process.env.SIMULATE_CONNECTION_ERROR = 'false';
    
    // Réinitialiser les mocks
    mockStartKernel.mockClear();
    mockStopKernel.mockClear();
    mockListAvailableKernels.mockClear();
    mockExecuteCode.mockClear();
    
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'test-notebook.ipynb': JSON.stringify(sampleNotebook, null, 2),
        'empty-notebook.ipynb': JSON.stringify({
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
        }, null, 2),
        'no-permission.ipynb': mockFs.file({
          content: JSON.stringify(sampleNotebook, null, 2),
          mode: 0o444 // Lecture seule
        }),
        'invalid-notebook.ipynb': 'Not a valid JSON'
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

  // Tests pour les paramètres invalides
  describe('Paramètres invalides', () => {
    test('devrait rejeter les paramètres manquants pour read_notebook', async () => {
      const request = mockRequest('read_notebook', {
        // path manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres manquants pour write_notebook', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('write_notebook', {
          content: sampleNotebook
        }),
        // content manquant
        mockRequest('write_notebook', {
          path: path.join(TEST_DIR, 'write-test.ipynb')
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour add_cell', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('add_cell', {
          cell_type: 'code',
          source: 'print("Test")'
        }),
        // cell_type manquant
        mockRequest('add_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          source: 'print("Test")'
        }),
        // source manquant
        mockRequest('add_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          cell_type: 'code'
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour remove_cell', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('remove_cell', {
          index: 0
        }),
        // index manquant
        mockRequest('remove_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb')
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour update_cell', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('update_cell', {
          index: 0,
          source: 'print("Test")'
        }),
        // index manquant
        mockRequest('update_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          source: 'print("Test")'
        }),
        // source manquant
        mockRequest('update_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          index: 0
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour execute_cell', async () => {
      const invalidRequests = [
        // kernel_id manquant
        mockRequest('execute_cell', {
          code: 'print("Test")'
        }),
        // code manquant
        mockRequest('execute_cell', {
          kernel_id: mockKernelId
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour execute_notebook', async () => {
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
    });
    
    test('devrait rejeter les paramètres manquants pour execute_notebook_cell', async () => {
      const invalidRequests = [
        // path manquant
        mockRequest('execute_notebook_cell', {
          cell_index: 0,
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
          cell_index: 0
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait rejeter les paramètres manquants pour stop_kernel', async () => {
      const request = mockRequest('stop_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres manquants pour interrupt_kernel', async () => {
      const request = mockRequest('interrupt_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres manquants pour restart_kernel', async () => {
      const request = mockRequest('restart_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les fichiers inexistants
  describe('Fichiers inexistants', () => {
    test('devrait gérer les notebooks inexistants pour read_notebook', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb')
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks inexistants pour update_cell', async () => {
      const request = mockRequest('update_cell', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        index: 0,
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks inexistants pour remove_cell', async () => {
      const request = mockRequest('remove_cell', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        index: 0
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks inexistants pour add_cell', async () => {
      const request = mockRequest('add_cell', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        cell_type: 'code',
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks inexistants pour execute_notebook', async () => {
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks inexistants pour execute_notebook_cell', async () => {
      const request = mockRequest('execute_notebook_cell', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb'),
        cell_index: 0,
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les permissions insuffisantes
  describe('Permissions insuffisantes', () => {
    test('devrait gérer les notebooks sans permission d\'écriture pour write_notebook', async () => {
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        content: sampleNotebook
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks sans permission d\'écriture pour add_cell', async () => {
      const request = mockRequest('add_cell', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        cell_type: 'code',
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks sans permission d\'écriture pour remove_cell', async () => {
      const request = mockRequest('remove_cell', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        index: 0
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks sans permission d\'écriture pour update_cell', async () => {
      const request = mockRequest('update_cell', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        index: 0,
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks sans permission d\'écriture pour execute_notebook', async () => {
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks sans permission d\'écriture pour execute_notebook_cell', async () => {
      const request = mockRequest('execute_notebook_cell', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        cell_index: 1,
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les erreurs de connexion au serveur Jupyter
  describe('Erreurs de connexion au serveur Jupyter', () => {
    test('devrait gérer les erreurs de connexion pour list_kernels', async () => {
      process.env.SIMULATE_CONNECTION_ERROR = 'true';
      
      const request = mockRequest('list_kernels', {});
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les erreurs de connexion pour start_kernel', async () => {
      const request = mockRequest('start_kernel', {
        kernel_name: 'invalid-kernel'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les erreurs de connexion pour stop_kernel', async () => {
      const request = mockRequest('stop_kernel', {
        kernel_id: 'invalid-kernel-id'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les erreurs de connexion pour execute_cell', async () => {
      const request = mockRequest('execute_cell', {
        kernel_id: 'invalid-kernel-id',
        code: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les formats de notebook invalides
  describe('Formats de notebook invalides', () => {
    test('devrait gérer les notebooks avec un format JSON invalide', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'invalid-notebook.ipynb')
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les notebooks avec un format nbformat invalide', async () => {
      // Créer un notebook avec un format invalide
      await fs.writeFile(
        path.join(TEST_DIR, 'invalid-format.ipynb'),
        JSON.stringify({ invalid: 'format' }, null, 2),
        'utf-8'
      );
      
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'invalid-format.ipynb')
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les limites et cas particuliers
  describe('Limites et cas particuliers', () => {
    test('devrait gérer les index de cellule hors limites', async () => {
      const invalidRequests = [
        // Index négatif
        mockRequest('remove_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          index: -1
        }),
        // Index trop grand
        mockRequest('remove_cell', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb'),
          index: 100
        })
      ];
      
      for (const request of invalidRequests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait gérer les notebooks vides', async () => {
      const request = mockRequest('remove_cell', {
        path: path.join(TEST_DIR, 'empty-notebook.ipynb'),
        index: 0
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les cellules non-code pour execute_notebook_cell', async () => {
      const request = mockRequest('execute_notebook_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        cell_index: 0, // Cellule markdown
        kernel_id: mockKernelId
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les outils inconnus', async () => {
      const request = mockRequest('unknown_tool', {});
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour les requêtes simultanées
  describe('Requêtes simultanées', () => {
    test('devrait gérer plusieurs requêtes simultanées', async () => {
      // Simuler plusieurs requêtes simultanées
      const requests = [
        mockRequest('read_notebook', {
          path: path.join(TEST_DIR, 'test-notebook.ipynb')
        }),
        mockRequest('list_kernels', {}),
        mockRequest('start_kernel', {
          kernel_name: 'python3'
        })
      ];
      
      // Exécuter toutes les requêtes en parallèle
      const results = await Promise.allSettled(
        requests.map(request => server.handleCallTool(request))
      );
      
      // Vérifier que toutes les requêtes ont été traitées
      expect(results.filter(r => r.status === 'fulfilled').length).toBe(3);
    });
  });
});