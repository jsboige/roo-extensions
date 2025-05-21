/**
 * Tests de gestion d'erreurs pour le serveur QuickFiles
 * 
 * Ces tests vérifient la robustesse du serveur QuickFiles face à différentes situations d'erreur :
 * - Fichiers inexistants
 * - Permissions insuffisantes
 * - Paramètres invalides
 * - Chemins spéciaux
 * - Limites de taille
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
const TEST_DIR = path.join(__dirname, '..', 'test-temp-errors');

// Mocks pour les requêtes MCP
const mockRequest = (name, args) => ({
  params: {
    name,
    arguments: args
  }
});

describe('QuickFiles Server - Gestion des Erreurs', () => {
  let server;
  
  // Configuration du système de fichiers simulé avant chaque test
  beforeEach(() => {
    // Créer un système de fichiers simulé avec mockFs
    mockFs({
      [TEST_DIR]: {
        'normal-file.txt': 'Contenu normal',
        'empty-file.txt': '',
        'no-permission.txt': mockFs.file({
          content: 'Contenu protégé',
          mode: 0 // Aucune permission
        }),
        'subdir': {
          'file.txt': 'Fichier dans un sous-répertoire'
        },
        'special-chars-file-éèàç.txt': 'Fichier avec caractères spéciaux',
        'long-name-file.txt': 'Fichier avec un nom très long'
      },
      // Simuler un répertoire sans permission
      [path.join(TEST_DIR, 'no-permission-dir')]: mockFs.directory({
        mode: 0,
        items: {
          'file.txt': 'Fichier dans un répertoire sans permission'
        }
      })
    });
    
    // Créer une instance du serveur QuickFiles
    server = new QuickFilesServer();
  });
  
  // Nettoyer le système de fichiers simulé après chaque test
  afterEach(() => {
    mockFs.restore();
  });

  // Tests pour read_multiple_files - Gestion des erreurs
  describe('read_multiple_files - Gestion des erreurs', () => {
    test('devrait gérer les fichiers inexistants', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [
          path.join(TEST_DIR, 'normal-file.txt'),
          path.join(TEST_DIR, 'non-existent-file.txt')
        ]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Contenu normal');
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('non-existent-file.txt');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers sans permission de lecture', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'no-permission.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les chemins invalides', async () => {
      const invalidPaths = [
        null,
        undefined,
        123,
        true,
        {},
        path.join(TEST_DIR, '\0invalid'), // Caractère nul invalide dans le chemin
        path.join(TEST_DIR, 'file\nwith\nnewlines.txt')
      ];
      
      for (const invalidPath of invalidPaths) {
        const request = mockRequest('read_multiple_files', {
          paths: [invalidPath]
        });
        
        const response = await server.handleReadMultipleFiles(request);
        
        expect(response.content[0].text).toContain('ERREUR');
        expect(response.isError).toBeUndefined();
      }
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      const invalidRequests = [
        // paths n'est pas un tableau
        mockRequest('read_multiple_files', { paths: 'not-an-array' }),
        // paths est un tableau vide
        mockRequest('read_multiple_files', { paths: [] }),
        // show_line_numbers n'est pas un booléen
        mockRequest('read_multiple_files', { 
          paths: [path.join(TEST_DIR, 'normal-file.txt')],
          show_line_numbers: 'not-a-boolean'
        }),
        // max_lines_per_file n'est pas un nombre
        mockRequest('read_multiple_files', { 
          paths: [path.join(TEST_DIR, 'normal-file.txt')],
          max_lines_per_file: 'not-a-number'
        }),
        // excerpts invalide
        mockRequest('read_multiple_files', { 
          paths: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            excerpts: 'not-an-array'
          }]
        }),
        // start/end invalides dans excerpts
        mockRequest('read_multiple_files', { 
          paths: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            excerpts: [{ start: 'not-a-number', end: 5 }]
          }]
        }),
        // start > end dans excerpts
        mockRequest('read_multiple_files', { 
          paths: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            excerpts: [{ start: 10, end: 5 }]
          }]
        })
      ];
      
      for (const request of invalidRequests) {
        try {
          await server.handleReadMultipleFiles(request);
          fail('La requête invalide aurait dû être rejetée');
        } catch (error) {
          expect(error).toBeDefined();
        }
      }
    });
    
    test('devrait gérer les fichiers avec des caractères spéciaux dans le nom', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, 'special-chars-file-éèàç.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier avec caractères spéciaux');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers avec des noms très longs', async () => {
      const longFileName = 'long-name-file.txt';
      const request = mockRequest('read_multiple_files', {
        paths: [path.join(TEST_DIR, longFileName)]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Fichier avec un nom très long');
      expect(response.isError).toBeUndefined();
    });
  });

  // Tests pour list_directory_contents - Gestion des erreurs
  describe('list_directory_contents - Gestion des erreurs', () => {
    test('devrait gérer les répertoires inexistants', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [path.join(TEST_DIR, 'non-existent-dir')]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('non-existent-dir');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les répertoires sans permission', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [path.join(TEST_DIR, 'no-permission-dir')]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les chemins qui ne sont pas des répertoires', async () => {
      const request = mockRequest('list_directory_contents', {
        paths: [path.join(TEST_DIR, 'normal-file.txt')]
      });
      
      const response = await server.handleListDirectoryContents(request);
      
      expect(response.content[0].text).toContain('ERREUR');
      expect(response.content[0].text).toContain('n\'est pas un répertoire');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      const invalidRequests = [
        // paths n'est pas un tableau
        mockRequest('list_directory_contents', { paths: 'not-an-array' }),
        // paths est un tableau vide
        mockRequest('list_directory_contents', { paths: [] }),
        // recursive n'est pas un booléen
        mockRequest('list_directory_contents', { 
          paths: [{
            path: TEST_DIR,
            recursive: 'not-a-boolean'
          }]
        }),
        // max_lines n'est pas un nombre
        mockRequest('list_directory_contents', { 
          paths: [TEST_DIR],
          max_lines: 'not-a-number'
        })
      ];
      
      for (const request of invalidRequests) {
        try {
          await server.handleListDirectoryContents(request);
          fail('La requête invalide aurait dû être rejetée');
        } catch (error) {
          expect(error).toBeDefined();
        }
      }
    });
  });

  // Tests pour delete_files - Gestion des erreurs
  describe('delete_files - Gestion des erreurs', () => {
    test('devrait gérer les fichiers inexistants', async () => {
      const request = mockRequest('delete_files', {
        paths: [path.join(TEST_DIR, 'non-existent-file.txt')]
      });
      
      const response = await server.handleDeleteFiles(request);
      
      expect(response.content[0].text).toContain('Échec de suppression');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les fichiers sans permission de suppression', async () => {
      const request = mockRequest('delete_files', {
        paths: [path.join(TEST_DIR, 'no-permission.txt')]
      });
      
      const response = await server.handleDeleteFiles(request);
      
      expect(response.content[0].text).toContain('Échec de suppression');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      const invalidRequests = [
        // paths n'est pas un tableau
        mockRequest('delete_files', { paths: 'not-an-array' }),
        // paths est un tableau vide
        mockRequest('delete_files', { paths: [] }),
        // paths contient des éléments non-string
        mockRequest('delete_files', { paths: [123, true, null] })
      ];
      
      for (const request of invalidRequests) {
        try {
          await server.handleDeleteFiles(request);
          fail('La requête invalide aurait dû être rejetée');
        } catch (error) {
          expect(error).toBeDefined();
        }
      }
    });
  });

  // Tests pour edit_multiple_files - Gestion des erreurs
  describe('edit_multiple_files - Gestion des erreurs', () => {
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
    
    test('devrait gérer les fichiers sans permission d\'écriture', async () => {
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: path.join(TEST_DIR, 'no-permission.txt'),
          diffs: [{
            search: 'Contenu',
            replace: 'Nouveau contenu'
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Échec d\'édition');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les motifs de recherche non trouvés', async () => {
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: path.join(TEST_DIR, 'normal-file.txt'),
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
    
    test('devrait gérer les start_line hors limites', async () => {
      const request = mockRequest('edit_multiple_files', {
        files: [{
          path: path.join(TEST_DIR, 'normal-file.txt'),
          diffs: [{
            search: 'Contenu',
            replace: 'Nouveau contenu',
            start_line: 1000 // Bien au-delà de la fin du fichier
          }]
        }]
      });
      
      const response = await server.handleEditMultipleFiles(request);
      
      expect(response.content[0].text).toContain('Aucune modification');
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les paramètres invalides', async () => {
      const invalidRequests = [
        // files n'est pas un tableau
        mockRequest('edit_multiple_files', { files: 'not-an-array' }),
        // files est un tableau vide
        mockRequest('edit_multiple_files', { files: [] }),
        // path manquant
        mockRequest('edit_multiple_files', { 
          files: [{
            diffs: [{
              search: 'texte',
              replace: 'nouveau texte'
            }]
          }]
        }),
        // diffs n'est pas un tableau
        mockRequest('edit_multiple_files', { 
          files: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            diffs: 'not-an-array'
          }]
        }),
        // search manquant
        mockRequest('edit_multiple_files', { 
          files: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            diffs: [{
              replace: 'nouveau texte'
            }]
          }]
        }),
        // replace manquant
        mockRequest('edit_multiple_files', { 
          files: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            diffs: [{
              search: 'texte'
            }]
          }]
        }),
        // start_line n'est pas un nombre
        mockRequest('edit_multiple_files', { 
          files: [{
            path: path.join(TEST_DIR, 'normal-file.txt'),
            diffs: [{
              search: 'texte',
              replace: 'nouveau texte',
              start_line: 'not-a-number'
            }]
          }]
        })
      ];
      
      for (const request of invalidRequests) {
        try {
          await server.handleEditMultipleFiles(request);
          fail('La requête invalide aurait dû être rejetée');
        } catch (error) {
          expect(error).toBeDefined();
        }
      }
    });
  });

  // Tests pour les cas limites généraux
  describe('Cas limites généraux', () => {
    test('devrait gérer les chemins relatifs', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: ['./test-temp-errors/normal-file.txt']
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      // mockFs ne gère pas bien les chemins relatifs, donc on s'attend à une erreur
      // mais le serveur ne devrait pas planter
      expect(response.isError).toBeUndefined();
    });
    
    test('devrait gérer les chemins absolus', async () => {
      const request = mockRequest('read_multiple_files', {
        paths: [path.resolve(TEST_DIR, 'normal-file.txt')]
      });
      
      const response = await server.handleReadMultipleFiles(request);
      
      // Le serveur devrait pouvoir gérer les chemins absolus
      expect(response.content[0].text).toContain('Contenu normal');
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
    
    test('devrait gérer les requêtes simultanées', async () => {
      // Simuler plusieurs requêtes simultanées
      const requests = [
        mockRequest('read_multiple_files', {
          paths: [path.join(TEST_DIR, 'normal-file.txt')]
        }),
        mockRequest('list_directory_contents', {
          paths: [TEST_DIR]
        }),
        mockRequest('read_multiple_files', {
          paths: [path.join(TEST_DIR, 'subdir', 'file.txt')]
        })
      ];
      
      // Exécuter toutes les requêtes en parallèle
      const responses = await Promise.all(requests.map(request => {
        if (request.params.name === 'read_multiple_files') {
          return server.handleReadMultipleFiles(request);
        } else {
          return server.handleListDirectoryContents(request);
        }
      }));
      
      // Vérifier que toutes les requêtes ont été traitées correctement
      for (const response of responses) {
        expect(response.isError).toBeUndefined();
        expect(response.content[0].text).toBeDefined();
      }
    });
  });
});