/**
 * Tests unitaires pour les outils de kernel du serveur Jupyter MCP
 * 
 * Ces tests vérifient les fonctionnalités des outils de kernel, y compris :
 * - Listage des kernels disponibles et actifs
 * - Démarrage de kernels
 * - Arrêt de kernels
 * - Interruption de kernels
 * - Redémarrage de kernels
 */

import { jest } from '@jest/globals';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur Jupyter MCP pour les tests unitaires
// Nous devons mocker le serveur car nous ne voulons pas dépendre d'un serveur Jupyter réel pour les tests
const mockKernelId = 'mock-kernel-id';
const mockKernelId2 = 'mock-kernel-id-2';

// Mock des fonctions du service Jupyter
const mockStartKernel = jest.fn().mockImplementation((kernelName) => {
  return Promise.resolve(mockKernelId);
});

const mockStopKernel = jest.fn().mockImplementation((kernelId) => {
  if (kernelId === 'invalid-kernel-id') {
    return Promise.reject(new Error('Kernel non trouvé'));
  }
  return Promise.resolve(true);
});

const mockListAvailableKernels = jest.fn().mockResolvedValue([
  { name: 'python3', spec: { display_name: 'Python 3' } },
  { name: 'ir', spec: { display_name: 'R' } }
]);

const mockListActiveKernels = jest.fn().mockReturnValue([
  { id: mockKernelId, name: 'python3' }
]);

const mockInterruptKernel = jest.fn().mockImplementation((kernelId) => {
  if (kernelId === 'invalid-kernel-id') {
    return Promise.reject(new Error('Kernel non trouvé'));
  }
  return Promise.resolve(true);
});

const mockRestartKernel = jest.fn().mockImplementation((kernelId) => {
  if (kernelId === 'invalid-kernel-id') {
    return Promise.reject(new Error('Kernel non trouvé'));
  }
  return Promise.resolve(true);
});

// Mock du module jupyter.js
jest.mock('../dist/services/jupyter.js', () => ({
  initializeJupyterServices: jest.fn().mockResolvedValue(true),
  startKernel: mockStartKernel,
  stopKernel: mockStopKernel,
  listAvailableKernels: mockListAvailableKernels,
  listActiveKernels: mockListActiveKernels,
  executeCode: jest.fn().mockResolvedValue({
    status: 'ok',
    execution_count: 1,
    outputs: []
  }),
  interruptKernel: mockInterruptKernel,
  restartKernel: mockRestartKernel,
  getKernel: jest.fn().mockReturnValue({})
}));

// Import des modules après le mock
import { JupyterMcpServer } from '../dist/index.js';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Mocks pour les requêtes MCP
const mockRequest = (name, args) => ({
  params: {
    name,
    arguments: args
  }
});

describe('Jupyter MCP Server - Outils de Kernel', () => {
  let server;
  
  // Configuration avant chaque test
  beforeEach(() => {
    // Réinitialiser les mocks
    mockStartKernel.mockClear();
    mockStopKernel.mockClear();
    mockListAvailableKernels.mockClear();
    mockListActiveKernels.mockClear();
    mockInterruptKernel.mockClear();
    mockRestartKernel.mockClear();
    
    // Créer une instance du serveur Jupyter MCP
    server = new JupyterMcpServer();
  });
  
  // Nettoyage après chaque test
  afterEach(() => {
    jest.clearAllMocks();
  });

  // Tests pour list_kernels
  describe('list_kernels', () => {
    test('devrait lister les kernels disponibles et actifs', async () => {
      const request = mockRequest('list_kernels', {});
      
      const response = await server.handleCallTool(request);
      
      expect(response.available_kernels).toBeDefined();
      expect(response.available_kernels.length).toBe(2);
      expect(response.available_kernels[0].name).toBe('python3');
      
      expect(response.active_kernels).toBeDefined();
      expect(response.active_kernels.length).toBe(1);
      expect(response.active_kernels[0].id).toBe(mockKernelId);
      
      expect(mockListAvailableKernels).toHaveBeenCalledTimes(1);
      expect(mockListActiveKernels).toHaveBeenCalledTimes(1);
    });
    
    test('devrait gérer les erreurs lors de la récupération des kernels', async () => {
      // Simuler une erreur lors de la récupération des kernels disponibles
      mockListAvailableKernels.mockRejectedValueOnce(new Error('Erreur de connexion'));
      
      const request = mockRequest('list_kernels', {});
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockListAvailableKernels).toHaveBeenCalledTimes(1);
    });
  });

  // Tests pour start_kernel
  describe('start_kernel', () => {
    test('devrait démarrer un kernel avec succès', async () => {
      const request = mockRequest('start_kernel', {
        kernel_name: 'python3'
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.kernel_id).toBe(mockKernelId);
      expect(response.kernel_name).toBe('python3');
      expect(response.message).toContain('Kernel démarré avec succès');
      
      expect(mockStartKernel).toHaveBeenCalledTimes(1);
      expect(mockStartKernel).toHaveBeenCalledWith('python3');
    });
    
    test('devrait utiliser python3 comme kernel par défaut', async () => {
      const request = mockRequest('start_kernel', {
        // kernel_name non spécifié
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.kernel_id).toBe(mockKernelId);
      expect(response.kernel_name).toBe('python3');
      
      expect(mockStartKernel).toHaveBeenCalledTimes(1);
      expect(mockStartKernel).toHaveBeenCalledWith('python3');
    });
    
    test('devrait gérer les erreurs lors du démarrage du kernel', async () => {
      // Simuler une erreur lors du démarrage du kernel
      mockStartKernel.mockRejectedValueOnce(new Error('Erreur de démarrage'));
      
      const request = mockRequest('start_kernel', {
        kernel_name: 'python3'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockStartKernel).toHaveBeenCalledTimes(1);
    });
  });

  // Tests pour stop_kernel
  describe('stop_kernel', () => {
    test('devrait arrêter un kernel avec succès', async () => {
      const request = mockRequest('stop_kernel', {
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.message).toContain('Kernel arrêté avec succès');
      
      expect(mockStopKernel).toHaveBeenCalledTimes(1);
      expect(mockStopKernel).toHaveBeenCalledWith(mockKernelId);
    });
    
    test('devrait gérer les kernels inexistants', async () => {
      const request = mockRequest('stop_kernel', {
        kernel_id: 'invalid-kernel-id'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockStopKernel).toHaveBeenCalledTimes(1);
      expect(mockStopKernel).toHaveBeenCalledWith('invalid-kernel-id');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('stop_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockStopKernel).not.toHaveBeenCalled();
    });
  });

  // Tests pour interrupt_kernel
  describe('interrupt_kernel', () => {
    test('devrait interrompre un kernel avec succès', async () => {
      const request = mockRequest('interrupt_kernel', {
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.message).toContain('Kernel interrompu avec succès');
      
      expect(mockInterruptKernel).toHaveBeenCalledTimes(1);
      expect(mockInterruptKernel).toHaveBeenCalledWith(mockKernelId);
    });
    
    test('devrait gérer les kernels inexistants', async () => {
      const request = mockRequest('interrupt_kernel', {
        kernel_id: 'invalid-kernel-id'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockInterruptKernel).toHaveBeenCalledTimes(1);
      expect(mockInterruptKernel).toHaveBeenCalledWith('invalid-kernel-id');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('interrupt_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockInterruptKernel).not.toHaveBeenCalled();
    });
  });

  // Tests pour restart_kernel
  describe('restart_kernel', () => {
    test('devrait redémarrer un kernel avec succès', async () => {
      const request = mockRequest('restart_kernel', {
        kernel_id: mockKernelId
      });
      
      const response = await server.handleCallTool(request);
      
      expect(response.success).toBe(true);
      expect(response.message).toContain('Kernel redémarré avec succès');
      
      expect(mockRestartKernel).toHaveBeenCalledTimes(1);
      expect(mockRestartKernel).toHaveBeenCalledWith(mockKernelId);
    });
    
    test('devrait gérer les kernels inexistants', async () => {
      const request = mockRequest('restart_kernel', {
        kernel_id: 'invalid-kernel-id'
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockRestartKernel).toHaveBeenCalledTimes(1);
      expect(mockRestartKernel).toHaveBeenCalledWith('invalid-kernel-id');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('restart_kernel', {
        // kernel_id manquant
      });
      
      await expect(server.handleCallTool(request)).rejects.toThrow();
      
      expect(mockRestartKernel).not.toHaveBeenCalled();
    });
  });

  // Tests de cas limites et d'erreurs
  describe('cas limites et erreurs', () => {
    test('devrait gérer les erreurs de connexion au serveur Jupyter', async () => {
      // Simuler une erreur de connexion pour toutes les fonctions
      mockListAvailableKernels.mockRejectedValueOnce(new Error('Erreur de connexion'));
      mockStartKernel.mockRejectedValueOnce(new Error('Erreur de connexion'));
      mockStopKernel.mockRejectedValueOnce(new Error('Erreur de connexion'));
      mockInterruptKernel.mockRejectedValueOnce(new Error('Erreur de connexion'));
      mockRestartKernel.mockRejectedValueOnce(new Error('Erreur de connexion'));
      
      // Tester chaque outil avec l'erreur de connexion
      const requests = [
        mockRequest('list_kernels', {}),
        mockRequest('start_kernel', { kernel_name: 'python3' }),
        mockRequest('stop_kernel', { kernel_id: mockKernelId }),
        mockRequest('interrupt_kernel', { kernel_id: mockKernelId }),
        mockRequest('restart_kernel', { kernel_id: mockKernelId })
      ];
      
      for (const request of requests) {
        await expect(server.handleCallTool(request)).rejects.toThrow();
      }
    });
    
    test('devrait gérer les appels simultanés', async () => {
      // Simuler plusieurs requêtes simultanées
      const requests = [
        mockRequest('start_kernel', { kernel_name: 'python3' }),
        mockRequest('list_kernels', {}),
        mockRequest('start_kernel', { kernel_name: 'ir' })
      ];
      
      // Exécuter toutes les requêtes en parallèle
      const results = await Promise.allSettled(
        requests.map(request => server.handleCallTool(request))
      );
      
      // Vérifier que toutes les requêtes ont été traitées
      expect(results.filter(r => r.status === 'fulfilled').length).toBe(3);
      
      // Vérifier que les fonctions ont été appelées le bon nombre de fois
      expect(mockStartKernel).toHaveBeenCalledTimes(2);
      expect(mockListAvailableKernels).toHaveBeenCalledTimes(1);
      expect(mockListActiveKernels).toHaveBeenCalledTimes(1);
    });
  });
});