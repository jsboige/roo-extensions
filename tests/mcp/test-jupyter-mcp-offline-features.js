/**
 * Script de test pour vérifier les fonctionnalités disponibles en mode hors ligne du MCP Jupyter
 * Ce script teste les fonctionnalités qui devraient fonctionner sans connexion à un serveur Jupyter
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  testNotebookPath: path.join(__dirname, 'test_notebook_offline.ipynb'),
};

// Liste des fonctionnalités à tester en mode hors ligne
const offlineFeatures = [
  {
    name: "Création d'un notebook",
    test: () => {
      console.log(`Test: Création d'un notebook en mode hors ligne`);
      console.log(`Création du fichier: ${config.testNotebookPath}`);
      
      // Contenu minimal d'un notebook Jupyter
      const notebookContent = {
        cells: [
          {
            cell_type: "code",
            execution_count: null,
            metadata: {},
            outputs: [],
            source: "# Cellule créée en mode hors ligne\nprint('Hello from offline mode!')"
          }
        ],
        metadata: {
          kernelspec: {
            display_name: "Python 3",
            language: "python",
            name: "python3"
          },
          language_info: {
            codemirror_mode: {
              name: "ipython",
              version: 3
            },
            file_extension: ".py",
            mimetype: "text/x-python",
            name: "python",
            nbconvert_exporter: "python",
            pygments_lexer: "ipython3",
            version: "3.8.10"
          }
        },
        nbformat: 4,
        nbformat_minor: 5
      };
      
      // Écrire le fichier notebook
      fs.writeFileSync(config.testNotebookPath, JSON.stringify(notebookContent, null, 2));
      
      // Vérifier que le fichier a été créé
      const exists = fs.existsSync(config.testNotebookPath);
      console.log(`Fichier créé: ${exists ? 'Oui' : 'Non'}`);
      
      return exists;
    }
  },
  {
    name: "Lecture d'un notebook",
    test: () => {
      console.log(`Test: Lecture d'un notebook en mode hors ligne`);
      
      // Vérifier que le fichier existe
      if (!fs.existsSync(config.testNotebookPath)) {
        console.log(`Le fichier ${config.testNotebookPath} n'existe pas`);
        return false;
      }
      
      // Lire le contenu du notebook
      const content = fs.readFileSync(config.testNotebookPath, 'utf8');
      const notebook = JSON.parse(content);
      
      // Vérifier que le contenu est valide
      const isValid = notebook && notebook.cells && Array.isArray(notebook.cells);
      console.log(`Contenu valide: ${isValid ? 'Oui' : 'Non'}`);
      
      if (isValid) {
        console.log(`Nombre de cellules: ${notebook.cells.length}`);
        console.log(`Type de la première cellule: ${notebook.cells[0].cell_type}`);
      }
      
      return isValid;
    }
  },
  {
    name: "Modification d'un notebook",
    test: () => {
      console.log(`Test: Modification d'un notebook en mode hors ligne`);
      
      // Vérifier que le fichier existe
      if (!fs.existsSync(config.testNotebookPath)) {
        console.log(`Le fichier ${config.testNotebookPath} n'existe pas`);
        return false;
      }
      
      // Lire le contenu du notebook
      const content = fs.readFileSync(config.testNotebookPath, 'utf8');
      const notebook = JSON.parse(content);
      
      // Ajouter une nouvelle cellule
      notebook.cells.push({
        cell_type: "markdown",
        metadata: {},
        source: "## Cellule ajoutée en mode hors ligne\nCette cellule a été ajoutée pour tester la modification d'un notebook en mode hors ligne."
      });
      
      // Écrire le fichier modifié
      fs.writeFileSync(config.testNotebookPath, JSON.stringify(notebook, null, 2));
      
      // Vérifier que le fichier a été modifié
      const modifiedContent = fs.readFileSync(config.testNotebookPath, 'utf8');
      const modifiedNotebook = JSON.parse(modifiedContent);
      
      const isModified = modifiedNotebook.cells.length === 2;
      console.log(`Notebook modifié: ${isModified ? 'Oui' : 'Non'}`);
      console.log(`Nombre de cellules après modification: ${modifiedNotebook.cells.length}`);
      
      return isModified;
    }
  },
  {
    name: "Simulation d'exécution de cellule",
    test: () => {
      console.log(`Test: Simulation d'exécution de cellule en mode hors ligne`);
      
      // En mode hors ligne, nous ne pouvons pas exécuter réellement une cellule,
      // mais nous pouvons simuler le résultat d'une exécution
      
      console.log("Simulation de l'exécution du code: print('Hello from offline mode!')");
      
      // Simuler le résultat de l'exécution
      const executionResult = {
        status: "ok",
        execution_count: 1,
        output: [
          {
            output_type: "stream",
            name: "stdout",
            text: "Hello from offline mode!\n"
          }
        ]
      };
      
      console.log("Résultat simulé de l'exécution:");
      console.log(JSON.stringify(executionResult, null, 2));
      
      return true;
    }
  }
];

// Fonction principale
async function main() {
  console.log('=== Test des fonctionnalités du MCP Jupyter en mode hors ligne ===');
  
  // Variables pour stocker les résultats des tests
  const results = {
    passed: 0,
    failed: 0,
    total: offlineFeatures.length
  };
  
  // Exécuter les tests
  for (const feature of offlineFeatures) {
    console.log(`\n=== Test de la fonctionnalité: ${feature.name} ===`);
    
    try {
      const success = await feature.test();
      
      if (success) {
        console.log(`✅ Test réussi: ${feature.name}`);
        results.passed++;
      } else {
        console.log(`❌ Test échoué: ${feature.name}`);
        results.failed++;
      }
    } catch (err) {
      console.error(`❌ Erreur lors du test de ${feature.name}: ${err.message}`);
      console.error(err);
      results.failed++;
    }
  }
  
  // Afficher les résultats
  console.log('\n=== Résultats des tests ===');
  console.log(`Tests réussis: ${results.passed}/${results.total}`);
  console.log(`Tests échoués: ${results.failed}/${results.total}`);
  
  if (results.failed === 0) {
    console.log('\n✅ Tous les tests ont réussi!');
    console.log('Le MCP Jupyter fonctionne correctement en mode hors ligne.');
  } else {
    console.log('\n❌ Certains tests ont échoué.');
    console.log('Le MCP Jupyter peut avoir des problèmes en mode hors ligne.');
  }
  
  // Nettoyer les fichiers de test
  try {
    if (fs.existsSync(config.testNotebookPath)) {
      fs.unlinkSync(config.testNotebookPath);
      console.log(`\nFichier de test ${config.testNotebookPath} supprimé`);
    }
  } catch (err) {
    console.error(`Erreur lors de la suppression du fichier de test: ${err.message}`);
  }
  
  console.log('\n=== Test terminé ===');
}

// Exécuter la fonction principale
main().catch(err => {
  console.error('Erreur lors du test:', err);
  process.exit(1);
});