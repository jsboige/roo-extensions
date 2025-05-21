/**
 * Tests de performance pour le serveur Jupyter MCP
 * 
 * Ces tests vérifient les performances du serveur Jupyter MCP avec de grands volumes de données :
 * - Lecture de notebooks volumineux
 * - Écriture de notebooks volumineux
 * - Exécution de nombreuses cellules
 * - Gestion de nombreux kernels
 */

import { jest } from '@jest/globals';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur Jupyter MCP pour les tests unitaires
const mockKernelId = 'mock-kernel-id';

// Mock des fonctions du service Jupyter
const mockStartKernel = jest.fn().mockResolvedValue(mockKernelId);
const mockStopKernel = jest.fn().mockResolvedValue(true);
const mockListAvailableKernels = jest.fn().mockResolvedValue([
  { name: 'python3', spec: { display_name: 'Python 3' } }
]);
const mockListActiveKernels = jest.fn().mockReturnValue([
  { id: mockKernelId, name: 'python3' }
]);
const mockExecuteCode = jest.fn().mockResolvedValue({
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

// Mock du module jupyter.js
jest.mock('../dist/services/jupyter.js', () => ({
  initializeJupyterServices: jest.fn().mockResolvedValue(true),
  startKernel: mockStartKernel,
  stopKernel: mockStopKernel,
  listAvailableKernels: mockListAvailableKernels,
  listActiveKernels: mockListActiveKernels,
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
const TEST_DIR = path.join(__dirname, '..', 'test-temp-perf');

// Mocks pour les requêtes MCP
const mockRequest = (name, args) => ({
  params: {
    name,
    arguments: args
  }
});

// Fonction utilitaire pour créer un grand notebook
const createLargeNotebook = (cellCount) => {
  const cells = [];
  
  // Ajouter une cellule markdown d'en-tête
  cells.push({
    cell_type: 'markdown',
    metadata: {},
    source: ['# Notebook de test volumineux']
  });
  
  // Ajouter des cellules de code
  for (let i = 1; i <= cellCount; i++) {
    cells.push({
      cell_type: 'code',
      execution_count: null,
      metadata: {},
      outputs: [],
      source: [`# Cellule ${i}`, `print("Cellule ${i}")`]
    });
  }
  
  return {
    cells,
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
};

// Fonction utilitaire pour mesurer le temps d'exécution
const measureExecutionTime = async (fn) => {
  const start = process.hrtime.bigint();
  const result = await fn();
  const end = process.hrtime.bigint();
  const duration = Number(end - start) / 1_000_000; // en millisecondes
  return { result, duration };
};

describe('Jupyter MCP Server - Tests de Performance', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant tous les tests
  beforeAll(() => {
    // Créer un système de fichiers simulé avec mockFs
    const perfFiles = {};
    
    // Créer des notebooks de différentes tailles
    perfFiles['small-notebook.ipynb'] = JSON.stringify(createLargeNotebook(10), null, 2);
    perfFiles['medium-notebook.ipynb'] = JSON.stringify(createLargeNotebook(100), null, 2);
    perfFiles['large-notebook.ipynb'] = JSON.stringify(createLargeNotebook(1000), null, 2);
    
    mockFs({
      [TEST_DIR]: perfFiles
    });
    
    // Créer une instance du serveur Jupyter MCP
    server = new JupyterMcpServer();
  });
  
  // Nettoyer le système de fichiers simulé après tous les tests
  afterAll(() => {
    mockFs.restore();
  });
  
  // Réinitialiser les mocks avant chaque test
  beforeEach(() => {
    mockStartKernel.mockClear();
    mockStopKernel.mockClear();
    mockListAvailableKernels.mockClear();
    mockListActiveKernels.mockClear();
    mockExecuteCode.mockClear();
  });

  // Tests de performance pour read_notebook
  describe('read_notebook - Performance', () => {
    test('devrait lire efficacement un petit notebook', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'small-notebook.ipynb')
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour lire un notebook de 10 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(500); // Devrait prendre moins de 500ms
    });
    
    test('devrait lire efficacement un notebook moyen', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'medium-notebook.ipynb')
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour lire un notebook de 100 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
    });
    
    test('devrait lire efficacement un grand notebook', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'large-notebook.ipynb')
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour lire un notebook de 1000 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(3000); // Devrait prendre moins de 3 secondes
    });
  });

  // Tests de performance pour write_notebook
  describe('write_notebook - Performance', () => {
    test('devrait écrire efficacement un petit notebook', async () => {
      const notebook = createLargeNotebook(10);
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'write-small.ipynb'),
        content: notebook
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour écrire un notebook de 10 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(500); // Devrait prendre moins de 500ms
    });
    
    test('devrait écrire efficacement un notebook moyen', async () => {
      const notebook = createLargeNotebook(100);
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'write-medium.ipynb'),
        content: notebook
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour écrire un notebook de 100 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
    });
    
    test('devrait écrire efficacement un grand notebook', async () => {
      const notebook = createLargeNotebook(1000);
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'write-large.ipynb'),
        content: notebook
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour écrire un notebook de 1000 cellules: ${duration}ms`);
      expect(duration).toBeLessThan(3000); // Devrait prendre moins de 3 secondes
    });
  });

  // Tests de performance pour add_cell
  describe('add_cell - Performance', () => {
    test('devrait ajouter efficacement des cellules à un notebook', async () => {
      // Créer un notebook vide pour les tests
      await fs.writeFile(
        path.join(TEST_DIR, 'add-cell-test.ipynb'),
        JSON.stringify(createLargeNotebook(0), null, 2),
        'utf-8'
      );
      
      const durations = [];
      
      // Ajouter 100 cellules et mesurer le temps pour chaque ajout
      for (let i = 1; i <= 100; i++) {
        const request = mockRequest('add_cell', {
          path: path.join(TEST_DIR, 'add-cell-test.ipynb'),
          cell_type: 'code',
          source: `print("Cellule ${i}")`
        });
        
        const { duration } = await measureExecutionTime(async () => {
          return await server.handleCallTool(request);
        });
        
        durations.push(duration);
      }
      
      // Calculer la durée moyenne
      const averageDuration = durations.reduce((a, b) => a + b, 0) / durations.length;
      console.log(`Temps d'exécution moyen pour ajouter une cellule: ${averageDuration}ms`);
      
      // Vérifier que le temps moyen est raisonnable
      expect(averageDuration).toBeLessThan(500); // Devrait prendre moins de 500ms en moyenne
    });
  });

  // Tests de performance pour execute_notebook
  describe('execute_notebook - Performance', () => {
    test('devrait exécuter efficacement un notebook avec de nombreuses cellules', async () => {
      // Créer un notebook avec de nombreuses cellules pour les tests
      await fs.writeFile(
        path.join(TEST_DIR, 'execute-test.ipynb'),
        JSON.stringify(createLargeNotebook(50), null, 2),
        'utf-8'
      );
      
      const request = mockRequest('execute_notebook', {
        path: path.join(TEST_DIR, 'execute-test.ipynb'),
        kernel_id: mockKernelId
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(request);
      });
      
      console.log(`Temps d'exécution pour exécuter un notebook de 50 cellules: ${duration}ms`);
      
      // Vérifier que executeCode a été appelé pour chaque cellule de code
      expect(mockExecuteCode).toHaveBeenCalledTimes(50);
      
      // Vérifier que le temps total est raisonnable
      expect(duration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
    });
  });

  // Tests de performance pour la gestion des kernels
  describe('Gestion des kernels - Performance', () => {
    test('devrait démarrer et arrêter efficacement de nombreux kernels', async () => {
      const kernelCount = 10;
      const kernelIds = [];
      
      // Mesurer le temps pour démarrer plusieurs kernels
      const startTime = process.hrtime.bigint();
      
      for (let i = 0; i < kernelCount; i++) {
        const request = mockRequest('start_kernel', {
          kernel_name: 'python3'
        });
        
        const response = await server.handleCallTool(request);
        kernelIds.push(response.kernel_id);
      }
      
      const midTime = process.hrtime.bigint();
      
      // Arrêter tous les kernels
      for (const kernelId of kernelIds) {
        const request = mockRequest('stop_kernel', {
          kernel_id: kernelId
        });
        
        await server.handleCallTool(request);
      }
      
      const endTime = process.hrtime.bigint();
      
      const startDuration = Number(midTime - startTime) / 1_000_000;
      const stopDuration = Number(endTime - midTime) / 1_000_000;
      
      console.log(`Temps d'exécution pour démarrer ${kernelCount} kernels: ${startDuration}ms`);
      console.log(`Temps d'exécution pour arrêter ${kernelCount} kernels: ${stopDuration}ms`);
      
      // Vérifier que les temps sont raisonnables
      expect(startDuration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
      expect(stopDuration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
      
      // Vérifier que les fonctions ont été appelées le bon nombre de fois
      expect(mockStartKernel).toHaveBeenCalledTimes(kernelCount);
      expect(mockStopKernel).toHaveBeenCalledTimes(kernelCount);
    });
  });

  // Tests de performance pour les opérations en parallèle
  describe('Opérations en parallèle - Performance', () => {
    test('devrait gérer efficacement des opérations en parallèle', async () => {
      // Créer plusieurs requêtes à exécuter en parallèle
      const requests = [
        mockRequest('read_notebook', {
          path: path.join(TEST_DIR, 'small-notebook.ipynb')
        }),
        mockRequest('read_notebook', {
          path: path.join(TEST_DIR, 'medium-notebook.ipynb')
        }),
        mockRequest('list_kernels', {}),
        mockRequest('start_kernel', {
          kernel_name: 'python3'
        }),
        mockRequest('start_kernel', {
          kernel_name: 'python3'
        })
      ];
      
      const { duration } = await measureExecutionTime(async () => {
        return await Promise.all(requests.map(request => server.handleCallTool(request)));
      });
      
      console.log(`Temps d'exécution pour 5 opérations en parallèle: ${duration}ms`);
      
      // Vérifier que le temps total est raisonnable
      expect(duration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
    });
  });

  // Tests de performance pour les cas limites
  describe('Cas limites - Performance', () => {
    test('devrait gérer efficacement un très grand notebook', async () => {
      // Créer un très grand notebook (2000 cellules)
      const hugeNotebook = createLargeNotebook(2000);
      
      // Mesurer le temps pour écrire le notebook
      const writeRequest = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'huge-notebook.ipynb'),
        content: hugeNotebook
      });
      
      const { duration: writeDuration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(writeRequest);
      });
      
      console.log(`Temps d'exécution pour écrire un notebook de 2000 cellules: ${writeDuration}ms`);
      
      // Mesurer le temps pour lire le notebook
      const readRequest = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'huge-notebook.ipynb')
      });
      
      const { duration: readDuration } = await measureExecutionTime(async () => {
        return await server.handleCallTool(readRequest);
      });
      
      console.log(`Temps d'exécution pour lire un notebook de 2000 cellules: ${readDuration}ms`);
      
      // Vérifier que les temps sont raisonnables
      expect(writeDuration).toBeLessThan(10000); // Devrait prendre moins de 10 secondes
      expect(readDuration).toBeLessThan(10000); // Devrait prendre moins de 10 secondes
    });
  });
});