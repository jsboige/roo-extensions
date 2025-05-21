/**
 * Tests unitaires pour le serveur QuickFiles
 * 
 * Ces tests vérifient les fonctionnalités du serveur QuickFiles, y compris :
 * - Lecture de fichiers multiples
 * - Listage de répertoires
 * - Suppression de fichiers
 * - Édition de fichiers multiples
 * - Gestion des erreurs
 * - Cas limites
 * - Performance
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

// Fonction utilitaire pour créer un grand fichier
const createLargeFile = (size) => {
  let content = '';
  for (let i = 1; i <= size; i++) {
    content += `Ligne ${i} du fichier de test\n`;
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

describe('QuickFiles Server', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'file1.txt': 'Contenu du fichier 1\nDeuxième ligne\nTroisième ligne',
        'file2.txt': 'Contenu du fichier 2\nDeuxième ligne',
        'empty-file.txt': '',
        'big-file.txt': createLargeFile(3000),
        'special-chars-file-éèàç.txt': 'Fichier avec caractères spéciaux',
        'subdir': {
          'file3.txt': 'Contenu du fichier 3',
          'file4.txt': 'Contenu du fichier 4',
          'nested': {
            'file5.txt': 'Contenu du fichier 5'
          }
        },
        'edit-test.txt': 'Ligne 1 à modifier\nLigne 2 à conserver\nLigne 3 à modifier',
        'delete-test.txt': 'Ce fichier sera supprimé',
        // Fichier avec un chemin très long
        ['long-path-'.repeat(20) + 'file.txt']: 'Fichier avec un chemin très long'
      }
    });
    
    // Créer une instance du serveur QuickFiles
    server = new QuickFilesServer();
  });
  
  // Nettoyer le système de fichiers simulé après chaque test
  afterEach(() => {
    mockFs.restore();
  });

  // Tests pour read_multiple_files
  describe('read_multiple_files', () => {
    test('devrait lire plusieurs fichiers avec succès', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [
          path.join(TEST_DIR, 'file1.txt'),
          path.join(TEST_DIR, 'file2.txt')
        ]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Contenu du fichier 1');
      expect(response.content[0].text).toContain('Contenu du fichier 2');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers inexistants', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [
          path.join(TEST_DIR, 'file1.txt'),
          path.join(TEST_DIR, 'non-existent-file.txt')
        ]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Contenu du fichier 1');
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('non-existent-file.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait limiter le nombre de lignes par fichier', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'big-file.txt')],
        max_lines_per_file: 50
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('lignes supplémentaires non affichées');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait afficher les numéros de ligne si demandé', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'file1.txt')],
        show_line_numbers: true
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('1 | Contenu');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait lire des extraits de fichiers', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [{
          path: path.join(TEST_DIR, 'big-file.txt'),
          excerpts: [
            { start: 10, end: 15 },
            { start: 100, end: 105 }
          ]
        }]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Ligne 10');
      expect(response.content[0].text).toContain('Ligne 100');
      expect(response.content[0].text).toContain('...');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers avec des caractères spéciaux dans le nom', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'special-chars-file-éèàç.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier avec caractères spéciaux');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers avec des chemins très longs', async () => {
      const longPathFile = path.join(TEST_DIR, 'long-path-'.repeat(20) + 'file.txt');
      const request = mockRequest('read_multiple_files', {
        paths: [longPathFile]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier avec un chemin très long');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers vides', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'empty-file.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('empty-file.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('read_multiple_files', {
        invalid_param: 'value'
      });
      
      await expect(server.handleReadMultipleFiles(request)).rejects.toThrow();
    });
    
    test('performance: devrait lire efficacement un grand fichier', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'big-file.txt')]
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleReadMultipleFiles(request);
      });
      
      console.log(`Temps d'exécution pour lire un fichier de 3000 lignes: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
    });
  });

  // Tests pour list_directory_contents
  describe('list_directory_contents', () => {
    test('devrait lister le contenu d\'un répertoire avec succès', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [TEST_DIR]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('file2.txt');
      expect(response.content[0].text).toContain('subdir');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait lister récursivement si demandé', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [{
          path: TEST_DIR,
          recursive: true
        }]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('file3.txt');
      expect(response.content[0].text).toContain('file5.txt');
      expect(response.content[0].text).toContain('nested');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait respecter la profondeur maximale spécifiée', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [{
          path: TEST_DIR,
          recursive: true,
          max_depth: 1 // Limiter à la profondeur 1 (seulement les fichiers et répertoires directs)
        }]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      // Devrait contenir les fichiers et répertoires du premier niveau
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('subdir');
      
      // Ne devrait pas contenir les fichiers du sous-répertoire 'nested'
      expect(response.content[0].text).not.toContain('file5.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait respecter la profondeur maximale globale', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [TEST_DIR],
        recursive: true,
        max_depth: 2 // Limiter à la profondeur 2 (fichiers et répertoires directs + un niveau de sous-répertoires)
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      // Devrait contenir les fichiers et répertoires du premier et deuxième niveau
      expect(response.content[0].text).toContain('file1.txt');
      expect(response.content[0].text).toContain('subdir');
      expect(response.content[0].text).toContain('file3.txt');
      
      // Ne devrait pas contenir les fichiers du sous-répertoire 'nested' (niveau 3)
      expect(response.content[0].text).not.toContain('file5.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les répertoires inexistants', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [path.join(TEST_DIR, 'non-existent-dir')]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('non-existent-dir');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait limiter le nombre de lignes dans la sortie', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [{
          path: TEST_DIR,
          recursive: true
        }],
        max_lines: 5
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('lignes supplémentaires non affichées');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('list_directory_contents', {
        invalid_param: 'value'
      });
      
      await expect(server.handleListDirectoryContents(request)).rejects.toThrow();
    });
    
    test('performance: devrait lister efficacement un répertoire avec beaucoup de fichiers', async () => {
      // Créer un répertoire avec beaucoup de fichiers pour le test de performance
      const perfDir = {};
      for (let i = 0; i < 100; i++) {
        perfDir[`file${i}.txt`] = `Contenu du fichier ${i}`;
      }
      
      mockFs.restore();
      mockFs({
        [TEST_DIR]: {
          'perf-test': perfDir
        }
      });
      
      const request = mockRequest('list_directory_contents', {
        paths: [path.join(TEST_DIR, 'perf-test')]
      });
      
      const { duration } = await measureExecutionTime(async () => {
        return await server.handleListDirectoryContents(request);
      });
      
      console.log(`Temps d'exécution pour lister un répertoire avec 100 fichiers: ${duration}ms`);
      expect(duration).toBeLessThan(1000); // Devrait prendre moins de 1 seconde
    });
  });

  // Tests pour delete_files
  describe('delete_files', () => {
    test('devrait supprimer un fichier avec succès', async () => {
      const filePath = path.join(TEST_DIR, 'delete-test.txt');
      const request = mockRequest('delete_files', {
        paths: [filePath]
      });
      
      const response = await server.handleDeleteFiles(request);
      
      expect(response.content[0].text).toContain('Fichier supprimé');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été supprimé
      await expect(fs.access(filePath)).rejects.toThrow();
    });
    
    test('devrait gérer les fichiers inexistants', async () => {
      const request = mockRequest('delete_files', {
        paths: [path.join(TEST_DIR, 'non-existent-file.txt')]
      });
      
      const response = await server.handleDeleteFiles(request);
      
      expect(response.content[0].text).toContain('Échec de suppression');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('delete_files', {
        invalid_param: 'value'
      });
      
      await expect(server.handleDeleteFiles(request)).rejects.toThrow();
    });
  });

  // Tests pour edit_multiple_files
  describe('edit_multiple_files', () => {
    test('devrait modifier un fichier avec succès', async () => {
      const filePath = path.join(TEST_DIR, 'edit-test.txt');
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: filePath,
          diffs: [{
            search: 'Ligne 1 à modifier',
            replace: 'Ligne 1 modifiée'
          }, {
            search: 'Ligne 3 à modifier',
            replace: 'Ligne 3 modifiée'
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier modifié');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été modifié
      const content = await fs.readFile(filePath, 'utf-8');
      expect(content).toContain('Ligne 1 modifiée');
      expect(content).toContain('Ligne 2 à conserver');
      expect(content).toContain('Ligne 3 modifiée');
    });
    
    test('devrait gérer les fichiers inexistants', async () => {
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: path.join(TEST_DIR, 'non-existent-file.txt'),
          diffs: [{
            search: 'texte',
            replace: 'nouveau texte'
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Échec d\'édition');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les motifs de recherche non trouvés', async () => {
      const filePath = path.join(TEST_DIR, 'edit-test.txt');
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: filePath,
          diffs: [{
            search: 'Texte qui n\'existe pas',
            replace: 'Nouveau texte'
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Aucune modification');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait appliquer des diffs avec start_line', async () => {
      const filePath = path.join(TEST_DIR, 'edit-test.txt');
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: filePath,
          diffs: [{
            search: 'Ligne 3 à modifier',
            replace: 'Ligne 3 modifiée',
            start_line: 3
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier modifié');
      expect(response.isError).toBeUndefined();
      
      // Vérifier que le fichier a été modifié
      const content = await fs.readFile(filePath, 'utf-8');
      expect(content).toContain('Ligne 1 à modifier');
      expect(content).toContain('Ligne 2 à conserver');
      expect(content).toContain('Ligne 3 modifiée');
    });
    
    test('devrait rejeter les paramètres invalides', async () => {
      const request = mockRequest('edit_multiple_files', {
        invalid_param: 'value'
      });
      
      await expect(server.handleEditMultipleFiles(request)).rejects.toThrow();
    });
  });

  // Tests de cas limites et d'erreurs
  describe('cas limites et erreurs', () => {
    test('devrait gérer les chemins relatifs et absolus', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [
          './test-temp/file1.txt',
          path.resolve(TEST_DIR, 'file2.txt')
        ]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      // Les deux fichiers devraient générer des erreurs car mockFs ne gère pas bien les chemins relatifs
      // mais le serveur ne devrait pas planter
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les permissions insuffisantes', async () => {
      // Simuler un fichier sans permission de lecture
      mockFs.restore();
      mockFs({
        [TEST_DIR]: {
          'no-permission.txt': mockFs.file({
            content: 'Contenu protégé',
            mode: 0 // Aucune permission
          })
        }
      });
      
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'no-permission.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('permission');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les erreurs de validation', async () => {
      const invalidRequests = [
        // read_multiple_files avec paths non valide
        mockRequest('read_multiple_files', { paths: 'not-an-array' }),
        // list_directory_contents avec paths non valide
        mockRequest('list_directory_contents', { paths: 123 }),
        // delete_files avec paths non valide
        mockRequest('delete_files', { paths: [123] }),
        // edit_multiple_files avec files non valide
        mockRequest('edit_multiple_files', { files: 'not-an-array' })
      ];
      
      for (const request of invalidRequests) {
        const handler = request.params.name === 'read_multiple_files' ? server.handleReadMultipleFiles :
                        request.params.name === 'list_directory_contents' ? server.handleListDirectoryContents :
                        request.params.name === 'delete_files' ? server.handleDeleteFiles :
                        server.handleEditMultipleFiles;
        
        await expect(handler.call(server, request)).rejects.toThrow();
      }
    });
  });
});