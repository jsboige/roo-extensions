/**
 * Tests de gestion d'erreurs pour le serveur JinaNavigator
 * 
 * Ces tests vérifient la robustesse du serveur JinaNavigator face à différentes situations d'erreur :
 * - URLs invalides
 * - Timeouts de requêtes
 * - Erreurs de réseau
 * - Paramètres invalides
 * - Limites de taille
 */

import { jest } from '@jest/globals';
import axios from 'axios';

// Importer le serveur JinaNavigator
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { McpError, ErrorCode } from '@modelcontextprotocol/sdk/types.js';

// Mock pour axios
jest.mock('axios');

// Mock pour le SDK MCP
jest.mock('@modelcontextprotocol/sdk/server/index.js');
jest.mock('@modelcontextprotocol/sdk/server/stdio.js');

// Fonction utilitaire pour créer une requête MCP simulée
const createMockRequest = (toolName, args) => ({
  params: {
    name: toolName,
    arguments: args
  }
});

describe('JinaNavigator Server - Gestion des Erreurs', () => {
  let server;
  let handleConvertWebToMarkdown;
  let handleAccessJinaResource;
  let handleMultiConvert;
  
  beforeEach(() => {
    // Réinitialiser les mocks
    jest.clearAllMocks();
    
    // Importer le serveur JinaNavigator (réimporté à chaque test pour éviter les effets de bord)
    jest.isolateModules(() => {
      const JinaNavigatorServer = require('../dist/index.js');
      server = JinaNavigatorServer.server;
      
      // Extraire les handlers des outils
      handleConvertWebToMarkdown = server.setRequestHandler.mock.calls.find(
        call => call[0].name === 'convert_web_to_markdown'
      )?.[1];
      
      handleAccessJinaResource = server.setRequestHandler.mock.calls.find(
        call => call[0].name === 'access_jina_resource'
      )?.[1];
      
      handleMultiConvert = server.setRequestHandler.mock.calls.find(
        call => call[0].name === 'multi_convert'
      )?.[1];
    });
  });
  
  // Tests pour convert_web_to_markdown - Gestion des erreurs
  describe('convert_web_to_markdown - Gestion des erreurs', () => {
    test('devrait gérer les URLs invalides', async () => {
      // Simuler une erreur pour une URL invalide
      axios.get.mockRejectedValue(new Error('URL invalide'));
      
      // Configurer la requête avec une URL invalide
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'invalid://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('URL invalide');
    });
    
    test('devrait gérer les timeouts de requêtes', async () => {
      // Simuler une erreur de timeout
      const timeoutError = new Error('Timeout de 30000ms dépassé');
      timeoutError.code = 'ECONNABORTED';
      axios.get.mockRejectedValue(timeoutError);
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('Timeout');
    });
    
    test('devrait gérer les erreurs de réseau', async () => {
      // Simuler une erreur de réseau
      const networkError = new Error('Erreur réseau');
      networkError.code = 'ENOTFOUND';
      axios.get.mockRejectedValue(networkError);
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('Erreur réseau');
    });
    
    test('devrait gérer les erreurs HTTP', async () => {
      // Simuler une erreur HTTP 404
      const httpError = new Error('Request failed with status code 404');
      httpError.response = { status: 404, data: 'Not Found' };
      axios.isAxiosError = jest.fn().mockReturnValue(true);
      axios.get.mockRejectedValue(httpError);
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com/not-found'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('404');
      expect(response.error.details).toBe('Not Found');
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      // Configurer la requête sans URL (paramètre obligatoire)
      const request = createMockRequest('convert_web_to_markdown', {});
      
      // Exécuter l'outil et vérifier qu'il rejette la requête
      await expect(handleConvertWebToMarkdown(request)).rejects.toThrow();
    });
    
    test('devrait gérer les numéros de ligne invalides', async () => {
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({
        data: 'Ligne 1\nLigne 2\nLigne 3\nLigne 4\nLigne 5'
      });
      
      // Configurer la requête avec des numéros de ligne invalides
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com',
        start_line: 10, // Au-delà de la fin du contenu
        end_line: 20
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que le résultat est vide mais ne génère pas d'erreur
      expect(response.result).toBe('');
    });
  });
  
  // Tests pour access_jina_resource - Gestion des erreurs
  describe('access_jina_resource - Gestion des erreurs', () => {
    test('devrait rejeter les URI invalides', async () => {
      // Configurer la requête avec un URI invalide
      const request = createMockRequest('access_jina_resource', {
        uri: 'invalid-uri'
      });
      
      // Exécuter l'outil
      const response = await handleAccessJinaResource(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('URI invalide');
    });
    
    test('devrait gérer les URI sans préfixe jina://', async () => {
      // Configurer la requête avec un URI sans préfixe jina://
      const request = createMockRequest('access_jina_resource', {
        uri: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleAccessJinaResource(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('URI invalide');
    });
    
    test('devrait gérer les erreurs de requête HTTP', async () => {
      // Simuler une erreur HTTP
      axios.get.mockRejectedValue(new Error('Erreur HTTP simulée'));
      
      // Configurer la requête
      const request = createMockRequest('access_jina_resource', {
        uri: 'jina://https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleAccessJinaResource(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('Erreur HTTP simulée');
    });
    
    test('devrait gérer les paramètres manquants', async () => {
      // Configurer la requête sans URI (paramètre obligatoire)
      const request = createMockRequest('access_jina_resource', {});
      
      // Exécuter l'outil et vérifier qu'il rejette la requête
      await expect(handleAccessJinaResource(request)).rejects.toThrow();
    });
  });
  
  // Tests pour multi_convert - Gestion des erreurs
  describe('multi_convert - Gestion des erreurs', () => {
    test('devrait gérer les erreurs pour certaines URLs tout en traitant les autres', async () => {
      // Simuler des réponses mixtes (succès et erreurs)
      axios.get
        .mockResolvedValueOnce({ data: 'Contenu 1' }) // Première URL réussit
        .mockRejectedValueOnce(new Error('Erreur pour URL 2')) // Deuxième URL échoue
        .mockResolvedValueOnce({ data: 'Contenu 3' }); // Troisième URL réussit
      
      // Configurer la requête
      const request = createMockRequest('multi_convert', {
        urls: [
          { url: 'https://example.com/page1' },
          { url: 'https://example.com/page2' },
          { url: 'https://example.com/page3' }
        ]
      });
      
      // Exécuter l'outil
      const response = await handleMultiConvert(request);
      
      // Vérifier la réponse
      expect(response.result).toHaveLength(3);
      expect(response.result[0].success).toBe(true);
      expect(response.result[1].success).toBe(false);
      expect(response.result[1].error).toContain('Erreur pour URL 2');
      expect(response.result[2].success).toBe(true);
    });
    
    test('devrait gérer une liste vide d\'URLs', async () => {
      // Configurer la requête avec une liste vide
      const request = createMockRequest('multi_convert', {
        urls: []
      });
      
      // Exécuter l'outil
      const response = await handleMultiConvert(request);
      
      // Vérifier que le résultat est un tableau vide
      expect(response.result).toEqual([]);
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      // Configurer la requête avec des paramètres invalides
      const invalidRequests = [
        // urls manquant
        createMockRequest('multi_convert', {}),
        // urls n'est pas un tableau
        createMockRequest('multi_convert', { urls: 'not-an-array' }),
        // url manquant dans un élément
        createMockRequest('multi_convert', { urls: [{ start_line: 1, end_line: 10 }] })
      ];
      
      // Vérifier que chaque requête invalide est rejetée
      for (const request of invalidRequests) {
        await expect(handleMultiConvert(request)).rejects.toThrow();
      }
    });
    
    test('devrait gérer les erreurs pour toutes les URLs', async () => {
      // Simuler des erreurs pour toutes les URLs
      axios.get.mockRejectedValue(new Error('Erreur générale'));
      
      // Configurer la requête
      const request = createMockRequest('multi_convert', {
        urls: [
          { url: 'https://example.com/page1' },
          { url: 'https://example.com/page2' }
        ]
      });
      
      // Exécuter l'outil
      const response = await handleMultiConvert(request);
      
      // Vérifier que toutes les URLs ont échoué mais que la fonction retourne quand même un résultat
      expect(response.result).toHaveLength(2);
      expect(response.result[0].success).toBe(false);
      expect(response.result[1].success).toBe(false);
    });
  });
  
  // Tests pour les cas limites généraux
  describe('Cas limites généraux', () => {
    test('devrait gérer les URLs très longues', async () => {
      // Créer une URL très longue
      const longUrl = 'https://example.com/' + 'a'.repeat(2000);
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: longUrl
      });
      
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: 'Contenu de test' });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'URL longue est traitée correctement
      expect(response.result).toBe('Contenu de test');
    });
    
    test('devrait gérer les contenus très volumineux', async () => {
      // Créer un contenu très volumineux
      const largeContent = 'Ligne\n'.repeat(100000);
      
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: largeContent });
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que le contenu volumineux est traité correctement
      expect(response.result).toBe(largeContent);
    });
    
    test('devrait gérer les requêtes simultanées', async () => {
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: 'Contenu de test' });
      
      // Créer plusieurs requêtes
      const requests = [
        createMockRequest('convert_web_to_markdown', { url: 'https://example.com/1' }),
        createMockRequest('convert_web_to_markdown', { url: 'https://example.com/2' }),
        createMockRequest('convert_web_to_markdown', { url: 'https://example.com/3' })
      ];
      
      // Exécuter toutes les requêtes en parallèle
      const responses = await Promise.all(requests.map(request => handleConvertWebToMarkdown(request)));
      
      // Vérifier que toutes les requêtes ont été traitées correctement
      for (const response of responses) {
        expect(response.result).toBe('Contenu de test');
      }
    });
  });
});