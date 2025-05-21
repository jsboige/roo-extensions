/**
 * Tests unitaires pour le serveur JinaNavigator
 * 
 * Ces tests vérifient les fonctionnalités de base du serveur JinaNavigator, y compris :
 * - Conversion de pages web en Markdown
 * - Filtrage du contenu par numéros de ligne
 * - Accès via URI au format jina://{url}
 * - Conversion de plusieurs URLs en parallèle
 */

import { jest } from '@jest/globals';
import axios from 'axios';

// Importer le serveur JinaNavigator
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

// Mock pour axios
jest.mock('axios');

// Mock pour le SDK MCP
jest.mock('@modelcontextprotocol/sdk/server/index.js');
jest.mock('@modelcontextprotocol/sdk/server/stdio.js');

// Données de test
const TEST_MARKDOWN_CONTENT = `# Titre de test
## Sous-titre
Ceci est un contenu Markdown de test.
- Point 1
- Point 2
- Point 3

### Section 1
Contenu de la section 1.

### Section 2
Contenu de la section 2.
`;

// Fonction utilitaire pour créer une requête MCP simulée
const createMockRequest = (toolName, args) => ({
  params: {
    name: toolName,
    arguments: args
  }
});

describe('JinaNavigator Server', () => {
  let server;
  let handleConvertWebToMarkdown;
  let handleAccessJinaResource;
  let handleMultiConvert;
  
  beforeEach(() => {
    // Réinitialiser les mocks
    jest.clearAllMocks();
    
    // Mock de la réponse d'axios
    axios.get.mockResolvedValue({
      data: TEST_MARKDOWN_CONTENT
    });
    
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
  
  // Tests pour convert_web_to_markdown
  describe('convert_web_to_markdown', () => {
    test('devrait convertir une page web en Markdown avec succès', async () => {
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que axios.get a été appelé avec la bonne URL
      expect(axios.get).toHaveBeenCalledWith('https://r.jina.ai/https://example.com');
      
      // Vérifier la réponse
      expect(response.result).toBe(TEST_MARKDOWN_CONTENT);
      expect(response.content[0].text).toBe(TEST_MARKDOWN_CONTENT);
      expect(response.content[0].mime).toBe('text/markdown');
    });
    
    test('devrait filtrer le contenu par numéros de ligne', async () => {
      // Configurer la requête avec des bornes
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com',
        start_line: 3,
        end_line: 6
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que le contenu est filtré correctement
      const expectedContent = TEST_MARKDOWN_CONTENT.split('\n').slice(2, 6).join('\n');
      expect(response.result).toBe(expectedContent);
    });
    
    test('devrait gérer les erreurs de requête HTTP', async () => {
      // Simuler une erreur HTTP
      axios.get.mockRejectedValue(new Error('Erreur HTTP simulée'));
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleConvertWebToMarkdown(request);
      
      // Vérifier que l'erreur est gérée correctement
      expect(response.error).toBeDefined();
      expect(response.error.message).toContain('Erreur HTTP simulée');
    });
  });
  
  // Tests pour access_jina_resource
  describe('access_jina_resource', () => {
    test('devrait accéder à une ressource via URI avec succès', async () => {
      // Configurer la requête
      const request = createMockRequest('access_jina_resource', {
        uri: 'jina://https://example.com'
      });
      
      // Exécuter l'outil
      const response = await handleAccessJinaResource(request);
      
      // Vérifier que axios.get a été appelé avec la bonne URL
      expect(axios.get).toHaveBeenCalledWith('https://r.jina.ai/https://example.com');
      
      // Vérifier la réponse
      expect(response.result.content).toBe(TEST_MARKDOWN_CONTENT);
      expect(response.result.contentType).toBe('text/markdown');
    });
    
    test('devrait filtrer le contenu par numéros de ligne', async () => {
      // Configurer la requête avec des bornes
      const request = createMockRequest('access_jina_resource', {
        uri: 'jina://https://example.com',
        start_line: 3,
        end_line: 6
      });
      
      // Exécuter l'outil
      const response = await handleAccessJinaResource(request);
      
      // Vérifier que le contenu est filtré correctement
      const expectedContent = TEST_MARKDOWN_CONTENT.split('\n').slice(2, 6).join('\n');
      expect(response.result.content).toBe(expectedContent);
    });
    
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
  });
  
  // Tests pour multi_convert
  describe('multi_convert', () => {
    test('devrait convertir plusieurs URLs en parallèle', async () => {
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
      
      // Vérifier que axios.get a été appelé pour chaque URL
      expect(axios.get).toHaveBeenCalledTimes(3);
      expect(axios.get).toHaveBeenCalledWith('https://r.jina.ai/https://example.com/page1');
      expect(axios.get).toHaveBeenCalledWith('https://r.jina.ai/https://example.com/page2');
      expect(axios.get).toHaveBeenCalledWith('https://r.jina.ai/https://example.com/page3');
      
      // Vérifier la réponse
      expect(response.result).toHaveLength(3);
      expect(response.result[0].url).toBe('https://example.com/page1');
      expect(response.result[0].success).toBe(true);
      expect(response.result[0].content).toBe(TEST_MARKDOWN_CONTENT);
    });
    
    test('devrait gérer les erreurs pour certaines URLs', async () => {
      // Simuler une erreur pour la deuxième URL
      axios.get
        .mockResolvedValueOnce({ data: TEST_MARKDOWN_CONTENT }) // Première URL réussit
        .mockRejectedValueOnce(new Error('Erreur HTTP simulée')) // Deuxième URL échoue
        .mockResolvedValueOnce({ data: TEST_MARKDOWN_CONTENT }); // Troisième URL réussit
      
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
      expect(response.result[1].error).toContain('Erreur HTTP simulée');
      expect(response.result[2].success).toBe(true);
    });
    
    test('devrait appliquer les bornes de lignes pour chaque URL', async () => {
      // Configurer la requête avec des bornes différentes pour chaque URL
      const request = createMockRequest('multi_convert', {
        urls: [
          { url: 'https://example.com/page1', start_line: 1, end_line: 3 },
          { url: 'https://example.com/page2', start_line: 3, end_line: 6 },
          { url: 'https://example.com/page3', start_line: 6, end_line: 9 }
        ]
      });
      
      // Exécuter l'outil
      const response = await handleMultiConvert(request);
      
      // Vérifier que le contenu est filtré correctement pour chaque URL
      expect(response.result[0].content).toBe(TEST_MARKDOWN_CONTENT.split('\n').slice(0, 3).join('\n'));
      expect(response.result[1].content).toBe(TEST_MARKDOWN_CONTENT.split('\n').slice(2, 6).join('\n'));
      expect(response.result[2].content).toBe(TEST_MARKDOWN_CONTENT.split('\n').slice(5, 9).join('\n'));
    });
  });
});