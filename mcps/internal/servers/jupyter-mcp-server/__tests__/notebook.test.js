/**
 * Tests unitaires pour les outils de notebook du serveur Jupyter MCP
 * 
 * Ces tests vérifient les fonctionnalités des outils de notebook, y compris :
 * - Lecture de notebooks
 * - Écriture de notebooks
 * - Création de notebooks
 * - Ajout de cellules
 * - Suppression de cellules
 * - Mise à jour de cellules
 */

import { jest } from '@jest/globals';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur Jupyter MCP pour les tests unitaires
// Nous devons mocker le serveur car nous ne voulons pas dépendre d'un serveur Jupyter réel pour les tests
jest.mock('../dist/services/jupyter.js', () => ({
  initializeJupyterServices: jest.fn().mockResolvedValue(true),
  startKernel: jest.fn().mockResolvedValue('mock-kernel-id'),
  stopKernel: jest.fn().mockResolvedValue(true),
  listAvailableKernels: jest.fn().mockResolvedValue([
    { name: 'python3', spec: { display_name: 'Python 3' } }
  ]),
  listActiveKernels: jest.fn().mockReturnValue([
    { id: 'mock-kernel-id', name: 'python3' }
  ]),
  executeCode: jest.fn().mockResolvedValue({
    status: 'ok',
    execution_count: 1,
    outputs: []
  }),
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

describe('Jupyter MCP Server - Outils de Notebook', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
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
        }, null, 2)
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

  // Tests pour read_notebook
  describe('read_notebook', () => {
    test('devrait lire un notebook avec succès', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb')
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.notebook).toBeDefined();
      expect(response.notebook.cells.length).toBe(2);
      expect(response.notebook.cells[0].cell_type).toBe('markdown');
      expect(response.notebook.cells[1].cell_type).toBe('code');
    });
    
    test('devrait gérer les notebooks inexistants', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'non-existent-notebook.ipynb')
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('read_notebook', {
        invalid_param: 'value'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour write_notebook
  describe('write_notebook', () => {
    test('devrait écrire un notebook avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'write-test.ipynb');
      const request = mockRequest('write_notebook', {
        path: notebookPath,
        content: sampleNotebook
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      
      // Vérifier que le fichier a été écrit
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells.length).toBe(2);
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'write-test.ipynb')
        // content manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour create_notebook
  describe('create_notebook', () => {
    test('devrait créer un notebook vide avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'create-test.ipynb');
      const request = mockRequest('create_notebook', {
        path: notebookPath,
        kernel: 'python3'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.notebook).toBeDefined();
      expect(response.notebook.cells.length).toBe(0);
      
      // Vérifier que le fichier a été créé
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.metadata.kernelspec.name).toBe('python3');
    });
    
    test('devrait utiliser python3 comme kernel par défaut', async () => {
      const notebookPath = path.join(TEST_DIR, 'create-default-test.ipynb');
      const request = mockRequest('create_notebook', {
        path: notebookPath
        // kernel non spécifié
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.notebook.metadata.kernelspec.name).toBe('python3');
    });
  });

  // Tests pour add_cell
  describe('add_cell', () => {
    test('devrait ajouter une cellule de code avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('add_cell', {
        path: notebookPath,
        cell_type: 'code',
        source: 'print("Nouvelle cellule")'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.cell_index).toBe(2); // Index de la nouvelle cellule
      
      // Vérifier que la cellule a été ajoutée
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells.length).toBe(3);
      expect(notebook.cells[2].cell_type).toBe('code');
      expect(notebook.cells[2].source.join('')).toBe('print("Nouvelle cellule")');
    });
    
    test('devrait ajouter une cellule markdown avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('add_cell', {
        path: notebookPath,
        cell_type: 'markdown',
        source: '## Titre secondaire'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      
      // Vérifier que la cellule a été ajoutée
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells.length).toBe(3);
      expect(notebook.cells[2].cell_type).toBe('markdown');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('add_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        // cell_type manquant
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour remove_cell
  describe('remove_cell', () => {
    test('devrait supprimer une cellule avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('remove_cell', {
        path: notebookPath,
        index: 1 // Supprimer la deuxième cellule
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      
      // Vérifier que la cellule a été supprimée
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells.length).toBe(1);
      expect(notebook.cells[0].cell_type).toBe('markdown');
    });
    
    test('devrait rejeter les index hors limites', async () => {
      const request = mockRequest('remove_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        index: 10 // Index invalide
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests pour update_cell
  describe('update_cell', () => {
    test('devrait mettre à jour une cellule avec succès', async () => {
      const notebookPath = path.join(TEST_DIR, 'test-notebook.ipynb');
      const request = mockRequest('update_cell', {
        path: notebookPath,
        index: 1, // Mettre à jour la deuxième cellule
        source: 'print("Cellule mise à jour")'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      
      // Vérifier que la cellule a été mise à jour
      const fileContent = await fs.readFile(notebookPath, 'utf-8');
      const notebook = JSON.parse(fileContent);
      expect(notebook.cells[1].source.join('')).toBe('print("Cellule mise à jour")');
    });
    
    test('devrait rejeter les index hors limites', async () => {
      const request = mockRequest('update_cell', {
        path: path.join(TEST_DIR, 'test-notebook.ipynb'),
        index: 10, // Index invalide
        source: 'print("Test")'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });

  // Tests de cas limites et d'erreurs
  describe('cas limites et erreurs', () => {
    test('devrait gérer les notebooks vides', async () => {
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'empty-notebook.ipynb')
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.notebook).toBeDefined();
      expect(response.notebook.cells.length).toBe(0);
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
      
      const request = mockRequest('write_notebook', {
        path: path.join(TEST_DIR, 'no-permission.ipynb'),
        content: sampleNotebook
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
    
    test('devrait gérer les formats de notebook invalides', async () => {
      // Créer un fichier avec un contenu JSON invalide
      await fs.writeFile(path.join(TEST_DIR, 'invalid-notebook.ipynb'), 'Not a valid JSON', 'utf-8');
      
      const request = mockRequest('read_notebook', {
        path: path.join(TEST_DIR, 'invalid-notebook.ipynb')
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
    });
  });
});