/**
 * Tests de performance pour le serveur JinaNavigator
 * 
 * Ces tests vérifient les performances du serveur JinaNavigator avec :
 * - Conversion de pages web volumineuses
 * - Conversion de plusieurs URLs en parallèle
 * - Filtrage efficace du contenu par numéros de ligne
 * - Mesure des temps de réponse
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

// Fonction utilitaire pour créer une requête MCP simulée
const createMockRequest = (toolName, args) => ({
  params: {
    name: toolName,
    arguments: args
  }
});

// Fonction utilitaire pour créer un grand contenu Markdown
const createLargeMarkdown = (size) => {
  let content = '# Grand document Markdown\n\n';
  for (let i = 1; i <= size; i++) {
    content += `## Section ${i}\n\nCeci est le contenu de la section ${i}.\n\n`;
  }
  return content;
};

// Fonction utilitaire pour mesurer le temps d'exécution
const measureExecutionTime = async (fn) => {
  const start = process.hrtime.bigint();
  const result = await fn();
  const end = process.hrtime.bigint();
  const duration = Number(end - start) / 1_000_000; // en millisecondes
  return { result, duration };
};

describe('JinaNavigator Server - Tests de Performance', () => {
  let server;
  let handleConvertWebToMarkdown;
  let handleAccessJinaResource;
  let handleMultiConvert;
  
  // Contenu Markdown volumineux pour les tests
  const LARGE_MARKDOWN = createLargeMarkdown(1000); // 1000 sections
  
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
  
  // Tests de performance pour convert_web_to_markdown
  describe('convert_web_to_markdown - Performance', () => {
    test('devrait traiter efficacement une page web volumineuse', async () => {
      // Mock de la réponse d'axios avec un contenu volumineux
      axios.get.mockResolvedValue({ data: LARGE_MARKDOWN });
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com/large-page'
      });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleConvertWebToMarkdown(request);
      });
      
      // Vérifier que le traitement est efficace
      console.log(`Temps d'exécution pour traiter une page volumineuse: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
      expect(result.result).toBe(LARGE_MARKDOWN);
    });
    
    test('devrait filtrer efficacement le contenu par numéros de ligne', async () => {
      // Mock de la réponse d'axios avec un contenu volumineux
      axios.get.mockResolvedValue({ data: LARGE_MARKDOWN });
      
      // Configurer la requête avec des bornes
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com/large-page',
        start_line: 500,
        end_line: 600
      });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleConvertWebToMarkdown(request);
      });
      
      // Vérifier que le filtrage est efficace
      console.log(`Temps d'exécution pour filtrer une page volumineuse: ${duration}ms`);
      expect(duration).toBeLessThan(500); // Devrait prendre moins de 500ms
      
      // Vérifier que le contenu est correctement filtré
      const expectedLines = LARGE_MARKDOWN.split('\n').slice(499, 600).join('\n');
      expect(result.result).toBe(expectedLines);
    });
  });
  
  // Tests de performance pour access_jina_resource
  describe('access_jina_resource - Performance', () => {
    test('devrait accéder efficacement à une ressource volumineuse', async () => {
      // Mock de la réponse d'axios avec un contenu volumineux
      axios.get.mockResolvedValue({ data: LARGE_MARKDOWN });
      
      // Configurer la requête
      const request = createMockRequest('access_jina_resource', {
        uri: 'jina://https://example.com/large-page'
      });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleAccessJinaResource(request);
      });
      
      // Vérifier que l'accès est efficace
      console.log(`Temps d'exécution pour accéder à une ressource volumineuse: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
      expect(result.result.content).toBe(LARGE_MARKDOWN);
    });
  });
  
  // Tests de performance pour multi_convert
  describe('multi_convert - Performance', () => {
    test('devrait convertir efficacement plusieurs URLs en parallèle', async () => {
      // Créer une liste d'URLs à convertir
      const urls = [];
      for (let i = 1; i <= 10; i++) {
        urls.push({ url: `https://example.com/page${i}` });
      }
      
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: 'Contenu de test' });
      
      // Configurer la requête
      const request = createMockRequest('multi_convert', { urls });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleMultiConvert(request);
      });
      
      // Vérifier que la conversion parallèle est efficace
      console.log(`Temps d'exécution pour convertir 10 URLs en parallèle: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
      expect(result.result).toHaveLength(10);
    });
    
    test('devrait convertir efficacement un grand nombre d\'URLs en parallèle', async () => {
      // Créer une liste de nombreuses URLs à convertir
      const urls = [];
      for (let i = 1; i <= 50; i++) {
        urls.push({ url: `https://example.com/page${i}` });
      }
      
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: 'Contenu de test' });
      
      // Configurer la requête
      const request = createMockRequest('multi_convert', { urls });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleMultiConvert(request);
      });
      
      // Vérifier que la conversion parallèle est efficace même avec beaucoup d'URLs
      console.log(`Temps d'exécution pour convertir 50 URLs en parallèle: ${duration}ms`);
      expect(duration).toBeLessThan(3000); // Devrait prendre moins de 3 secondes
      expect(result.result).toHaveLength(50);
    });
    
    test('devrait convertir efficacement des URLs avec différentes bornes', async () => {
      // Créer une liste d'URLs avec différentes bornes
      const urls = [];
      for (let i = 1; i <= 10; i++) {
        urls.push({
          url: `https://example.com/page${i}`,
          start_line: i * 10,
          end_line: i * 10 + 10
        });
      }
      
      // Mock de la réponse d'axios avec un contenu volumineux
      axios.get.mockResolvedValue({ data: LARGE_MARKDOWN });
      
      // Configurer la requête
      const request = createMockRequest('multi_convert', { urls });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleMultiConvert(request);
      });
      
      // Vérifier que la conversion avec bornes est efficace
      console.log(`Temps d'exécution pour convertir 10 URLs avec bornes: ${duration}ms`);
      expect(duration).toBeLessThan(2000); // Devrait prendre moins de 2 secondes
      expect(result.result).toHaveLength(10);
      
      // Vérifier que chaque URL a été correctement filtrée
      for (let i = 0; i < 10; i++) {
        const startLine = (i + 1) * 10;
        const endLine = startLine + 10;
        const expectedLines = LARGE_MARKDOWN.split('\n').slice(startLine - 1, endLine).join('\n');
        expect(result.result[i].content).toBe(expectedLines);
      }
    });
  });
  
  // Tests de performance pour les cas limites
  describe('Cas limites - Performance', () => {
    test('devrait gérer efficacement un contenu extrêmement volumineux', async () => {
      // Créer un contenu extrêmement volumineux
      const hugeMarkdown = createLargeMarkdown(5000); // 5000 sections
      
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: hugeMarkdown });
      
      // Configurer la requête
      const request = createMockRequest('convert_web_to_markdown', {
        url: 'https://example.com/huge-page'
      });
      
      // Mesurer le temps d'exécution
      const { duration, result } = await measureExecutionTime(async () => {
        return await handleConvertWebToMarkdown(request);
      });
      
      // Vérifier que le traitement est efficace même avec un contenu énorme
      console.log(`Temps d'exécution pour traiter une page énorme: ${duration}ms`);
      expect(duration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
      expect(result.result).toBe(hugeMarkdown);
    });
    
    test('devrait gérer efficacement de nombreuses requêtes simultanées', async () => {
      // Mock de la réponse d'axios
      axios.get.mockResolvedValue({ data: 'Contenu de test' });
      
      // Créer de nombreuses requêtes
      const requests = [];
      for (let i = 1; i <= 20; i++) {
        requests.push(createMockRequest('convert_web_to_markdown', {
          url: `https://example.com/page${i}`
        }));
      }
      
      // Mesurer le temps d'exécution pour traiter toutes les requêtes en parallèle
      const { duration } = await measureExecutionTime(async () => {
        return await Promise.all(requests.map(request => handleConvertWebToMarkdown(request)));
      });
      
      // Vérifier que le traitement parallèle est efficace
      console.log(`Temps d'exécution pour traiter 20 requêtes simultanées: ${duration}ms`);
      expect(duration).toBeLessThan(5000); // Devrait prendre moins de 5 secondes
    });
  });
});