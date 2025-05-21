/**
 * Tests unitaires pour les fonctionnalités de recherche et remplacement du serveur QuickFiles
 * 
 * Ces tests vérifient les fonctionnalités des outils search_in_files et search_and_replace, y compris :
 * - Recherche simple et avec expressions régulières
 * - Recherche sensible/insensible à la casse
 * - Recherche dans plusieurs fichiers/répertoires
 * - Remplacement simple et avec expressions régulières
 * - Prévisualisation des remplacements
 */

import { jest } from '@jest/globals';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import mockFs from 'mock-fs';

// Simuler le serveur QuickFiles pour les tests unitaires
import { QuickFilesServer } from '../build/index.js';

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

describe('QuickFiles Server - Recherche et remplacement', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'source': {
          'file1.txt': 'Ceci est un exemple de texte.\nIl contient plusieurs lignes.\nCertaines lignes contiennent le mot exemple.',
          'file2.txt': 'Un autre fichier texte.\nSans le mot recherché.',
          'file3.md': '# Titre markdown\n\nCeci est un exemple de document markdown.\n\n## Section 1\n\nContenu de la section 1.',
          'script.js': 'console.log("Ceci est un exemple");\nconst exemple = "test";\nfunction exempleFunction() { return true; }',
          'subdir': {
            'nested1.txt': 'Fichier imbriqué avec exemple dedans.',
            'nested2.txt': 'Fichier imbriqué sans le terme.'
          }
        },
        'destination': {
          'existing.txt': 'Fichier existant avec exemple dedans.'
        }
      }
    });
    
    // Créer une instance du serveur QuickFiles
    server = new QuickFilesServer();
  });
  
  // Nettoyer le système de fichiers simulé après chaque test
  afterEach(() => {
    mockFs.restore();
  });

  // Tests pour search_in_files
  describe('search_in_files', () => {
    test('devrait trouver des correspondances simples', async () => {
      const request = mockRequest('search_in_files', {
        paths: [path.join(TEST_DIR, 'source')],
        pattern: 'exemple',
        use_regex: false,
        case_sensitive: false
      });
      
      const response = await server.handleSearchInFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Résultats de recherche');
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('file3.md');
      expect(response.content[0].text).toContain('script.js');
      expect(response.content[0].text).toContain('nested1.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait respecter la sensibilité à la casse', async () => {
      const request = mockRequest('search_in_files', {
        paths: [path.join(TEST_DIR, 'source')],
        pattern: 'Exemple', // Majuscule au début
        use_regex: false,
        case_sensitive: true
      });
      
      const response = await server.handleSearchInFiles(request);
      
      // Vérifier que seules les correspondances exactes sont trouvées
      expect(response.content[0].text).toContain('Résultats de recherche');
      expect(response.content[0].text).toContain('file1.txt'); // Contient "Exemple" avec majuscule
      expect(response.content[0].text).not.toContain('script.js'); // Contient "exemple" sans majuscule
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait utiliser des expressions régulières', async () => {
      const request = mockRequest('search_in_files', {
        paths: [path.join(TEST_DIR, 'source')],
        pattern: 'exemple\\w*', // Recherche "exemple" suivi de caractères alphanumériques
        use_regex: true,
        case_sensitive: false
      });
      
      const response = await server.handleSearchInFiles(request);
      
      // Vérifier que les correspondances regex sont trouvées
      expect(response.content[0].text).toContain('Résultats de recherche');
      expect(response.content[0].text).toContain('script.js'); // Contient "exempleFunction"
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait filtrer par motif de fichier', async () => {
      const request = mockRequest('search_in_files', {
        paths: [path.join(TEST_DIR, 'source')],
        pattern: 'exemple',
        use_regex: false,
        case_sensitive: false,
        file_pattern: '*.txt' // Uniquement les fichiers .txt
      });
      
      const response = await server.handleSearchInFiles(request);
      
      // Vérifier que seuls les fichiers .txt sont inclus
      expect(response.content[0].text).toContain('Résultats de recherche');
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('nested1.txt');
      expect(response.content[0].text).not.toContain('file3.md');
      expect(response.content[0].text).not.toContain('script.js');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait limiter le nombre de résultats', async () => {
      const request = mockRequest('search_in_files', {
        paths: [path.join(TEST_DIR, 'source')],
        pattern: 'exemple',
        use_regex: false,
        case_sensitive: false,
        max_results_per_file: 1, // Limiter à 1 résultat par fichier
        max_total_results: 2 // Limiter à 2 résultats au total
      });
      
      const response = await server.handleSearchInFiles(request);
      
      // Vérifier que les résultats sont limités
      expect(response.content[0].text).toContain('Résultats de recherche');
      expect(response.content[0].text).toContain('limite atteinte');
      expect(response.isError).toBeUndefined();
    });
  });

  // Tests pour search_and_replace
  describe('search_and_replace', () => {
    test('devrait remplacer du texte dans un fichier spécifique', async () => {
      const request = mockRequest('search_and_replace', {
        files: [{
          path: path.join(TEST_DIR, 'source/file1.txt'),
          search: 'exemple',
          replace: 'échantillon',
          use_regex: false,
          case_sensitive: false
        }]
      });
      
      const response = await server.handleSearchAndReplace(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Modifications effectuées');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été modifié
      const content = await fs.readFile(path.join(TEST_DIR, 'source/file1.txt'), 'utf-8');
      expect(content).toContain('échantillon');
      expect(content).not.toContain('exemple');
    });
    
    test('devrait remplacer du texte dans plusieurs fichiers', async () => {
      const request = mockRequest('search_and_replace', {
        paths: [path.join(TEST_DIR, 'source')],
        search: 'exemple',
        replace: 'échantillon',
        use_regex: false,
        case_sensitive: false,
        file_pattern: '*.txt'
      });
      
      const response = await server.handleSearchAndReplace(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Modifications effectuées');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que les fichiers ont été modifiés
      const content1 = await fs.readFile(path.join(TEST_DIR, 'source/file1.txt'), 'utf-8');
      expect(content1).toContain('échantillon');
      expect(content1).not.toContain('exemple');
      
      const content2 = await fs.readFile(path.join(TEST_DIR, 'source/subdir/nested1.txt'), 'utf-8');
      expect(content2).toContain('échantillon');
      expect(content2).not.toContain('exemple');
    });
    
    test('devrait utiliser des expressions régulières pour le remplacement', async () => {
      const request = mockRequest('search_and_replace', {
        files: [{
          path: path.join(TEST_DIR, 'source/script.js'),
          search: 'exemple(Function)?',
          replace: 'sample$1',
          use_regex: true,
          case_sensitive: false
        }]
      });
      
      const response = await server.handleSearchAndReplace(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Modifications effectuées');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été modifié avec les captures de regex
      const content = await fs.readFile(path.join(TEST_DIR, 'source/script.js'), 'utf-8');
      expect(content).toContain('sample = "test"');
      expect(content).toContain('sampleFunction');
      expect(content).not.toContain('exemple');
    });
    
    test('devrait prévisualiser les modifications sans les appliquer', async () => {
      const request = mockRequest('search_and_replace', {
        files: [{
          path: path.join(TEST_DIR, 'source/file1.txt'),
          search: 'exemple',
          replace: 'échantillon',
          use_regex: false,
          case_sensitive: false,
          preview: true
        }]
      });
      
      const response = await server.handleSearchAndReplace(request);
      
      // Vérifier que la réponse contient la prévisualisation
      expect(response.content[0].text).toContain('Prévisualisation des modifications');
      expect(response.content[0].text).toContain('diff');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier n'a pas été modifié
      const content = await fs.readFile(path.join(TEST_DIR, 'source/file1.txt'), 'utf-8');
      expect(content).toContain('exemple');
      expect(content).not.toContain('échantillon');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('search_and_replace', {
        invalid_param: 'value'
      });
      
      await expect(server.handleSearchAndReplace(request)).rejects.toThrow();
    });
  });
});