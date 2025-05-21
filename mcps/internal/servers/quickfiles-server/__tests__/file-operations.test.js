/**
 * Tests unitaires pour les opérations de fichiers avancées du serveur QuickFiles
 * 
 * Ces tests vérifient les fonctionnalités des outils copy_files et move_files, y compris :
 * - Copie et déplacement de fichiers simples
 * - Support des motifs glob
 * - Transformations de noms de fichiers
 * - Gestion des conflits (écraser, ignorer, renommer)
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

describe('QuickFiles Server - Opérations de fichiers avancées', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'source': {
          'file1.txt': 'Contenu du fichier 1',
          'file2.txt': 'Contenu du fichier 2',
          'file3.md': '# Titre markdown',
          'script.js': 'console.log("Hello");',
          'subdir': {
            'nested1.txt': 'Fichier imbriqué 1',
            'nested2.txt': 'Fichier imbriqué 2'
          }
        },
        'destination': {
          'existing.txt': 'Fichier existant'
        },
        'empty': {}
      }
    });
    
    // Créer une instance du serveur QuickFiles
    server = new QuickFilesServer();
  });
  
  // Nettoyer le système de fichiers simulé après chaque test
  afterEach(() => {
    mockFs.restore();
  });

  // Tests pour copy_files
  describe('copy_files', () => {
    test('devrait copier un fichier simple', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file1.txt'),
          destination: path.join(TEST_DIR, 'destination/file1_copy.txt')
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Opération:');
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été copié
      const destContent = await fs.readFile(path.join(TEST_DIR, 'destination/file1_copy.txt'), 'utf-8');
      expect(destContent).toBe('Contenu du fichier 1');
    });
    
    test('devrait copier plusieurs fichiers avec motif glob', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/*.txt'),
          destination: path.join(TEST_DIR, 'destination/')
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que les fichiers ont été copiés
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination'));
      expect(destFiles).toContain('file1.txt');
      expect(destFiles).toContain('file2.txt');
      
      const file1Content = await fs.readFile(path.join(TEST_DIR, 'destination/file1.txt'), 'utf-8');
      expect(file1Content).toBe('Contenu du fichier 1');
    });
    
    test('devrait appliquer une transformation de nom de fichier', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file*.txt'),
          destination: path.join(TEST_DIR, 'destination/'),
          transform: {
            pattern: 'file(\\d+)',
            replacement: 'document$1'
          }
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que les fichiers ont été copiés avec les noms transformés
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination'));
      expect(destFiles).toContain('document1.txt');
      expect(destFiles).toContain('document2.txt');
    });
    
    test('devrait gérer la stratégie de conflit "overwrite"', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file1.txt'),
          destination: path.join(TEST_DIR, 'destination/existing.txt'),
          conflict_strategy: 'overwrite'
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Fichier écrasé');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été écrasé
      const destContent = await fs.readFile(path.join(TEST_DIR, 'destination/existing.txt'), 'utf-8');
      expect(destContent).toBe('Contenu du fichier 1');
    });
    
    test('devrait gérer la stratégie de conflit "ignore"', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file1.txt'),
          destination: path.join(TEST_DIR, 'destination/existing.txt'),
          conflict_strategy: 'ignore'
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('ignoré');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier n'a pas été modifié
      const destContent = await fs.readFile(path.join(TEST_DIR, 'destination/existing.txt'), 'utf-8');
      expect(destContent).toBe('Fichier existant');
    });
    
    test('devrait gérer la stratégie de conflit "rename"', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file1.txt'),
          destination: path.join(TEST_DIR, 'destination/existing.txt'),
          conflict_strategy: 'rename'
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Fichier copié avec succès');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier original existe toujours
      const originalContent = await fs.readFile(path.join(TEST_DIR, 'destination/existing.txt'), 'utf-8');
      expect(originalContent).toBe('Fichier existant');
      
      // Vérifier qu'un nouveau fichier a été créé avec un suffixe
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination'));
      const renamedFile = destFiles.find(file => file.startsWith('existing_') && file.endsWith('.txt'));
      expect(renamedFile).toBeDefined();
      
      const renamedContent = await fs.readFile(path.join(TEST_DIR, 'destination', renamedFile), 'utf-8');
      expect(renamedContent).toBe('Contenu du fichier 1');
    });
    
    test('devrait gérer les erreurs de fichier source inexistant', async () => {
      const request = mockRequest('copy_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/non-existent.txt'),
          destination: path.join(TEST_DIR, 'destination/')
        }]
      });
      
      const response = await server.handleCopyFiles(request);
      
      // Vérifier que la réponse indique une erreur
      expect(response.content[0].text).toContain('Aucun fichier ne correspond au motif');
      expect(response.isError).toBeUndefined();
    });
  });

  // Tests pour move_files
  describe('move_files', () => {
    test('devrait déplacer un fichier simple', async () => {
      const request = mockRequest('move_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/file1.txt'),
          destination: path.join(TEST_DIR, 'destination/file1_moved.txt')
        }]
      });
      
      const response = await server.handleMoveFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('Opération:');
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été déplacé
      const destContent = await fs.readFile(path.join(TEST_DIR, 'destination/file1_moved.txt'), 'utf-8');
      expect(destContent).toBe('Contenu du fichier 1');
      
      // Vérifier que le fichier source n'existe plus
      await expect(fs.access(path.join(TEST_DIR, 'source/file1.txt'))).rejects.toThrow();
    });
    
    test('devrait déplacer plusieurs fichiers avec motif glob', async () => {
      const request = mockRequest('move_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/*.md'),
          destination: path.join(TEST_DIR, 'destination/')
        }]
      });
      
      const response = await server.handleMoveFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que les fichiers ont été déplacés
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination'));
      expect(destFiles).toContain('file3.md');
      
      const fileContent = await fs.readFile(path.join(TEST_DIR, 'destination/file3.md'), 'utf-8');
      expect(fileContent).toBe('# Titre markdown');
      
      // Vérifier que les fichiers sources n'existent plus
      await expect(fs.access(path.join(TEST_DIR, 'source/file3.md'))).rejects.toThrow();
    });
    
    test('devrait appliquer une transformation de nom de fichier lors du déplacement', async () => {
      const request = mockRequest('move_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/script.js'),
          destination: path.join(TEST_DIR, 'destination/'),
          transform: {
            pattern: '(.*)\\.js',
            replacement: '$1.min.js'
          }
        }]
      });
      
      const response = await server.handleMoveFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été déplacé avec le nom transformé
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination'));
      expect(destFiles).toContain('script.min.js');
      
      // Vérifier que le fichier source n'existe plus
      await expect(fs.access(path.join(TEST_DIR, 'source/script.js'))).rejects.toThrow();
    });
    
    test('devrait gérer les répertoires imbriqués', async () => {
      const request = mockRequest('move_files', {
        operations: [{
          source: path.join(TEST_DIR, 'source/subdir/*.txt'),
          destination: path.join(TEST_DIR, 'destination/nested/')
        }]
      });
      
      const response = await server.handleMoveFiles(request);
      
      // Vérifier que la réponse est correcte
      expect(response.content[0].text).toContain('fichier(s) traité(s)');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que les fichiers ont été déplacés dans le répertoire imbriqué
      const destFiles = await fs.readdir(path.join(TEST_DIR, 'destination/nested'));
      expect(destFiles).toContain('nested1.txt');
      expect(destFiles).toContain('nested2.txt');
      
      // Vérifier que les fichiers sources n'existent plus
      await expect(fs.access(path.join(TEST_DIR, 'source/subdir/nested1.txt'))).rejects.toThrow();
      await expect(fs.access(path.join(TEST_DIR, 'source/subdir/nested2.txt'))).rejects.toThrow();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('move_files', {
        invalid_param: 'value'
      });
      
      await expect(server.handleMoveFiles(request)).rejects.toThrow();
    });
  });
});