#!/usr/bin/env node
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Obtenir le chemin du répertoire actuel
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Chemin vers le dossier de démonstration
const DEMO_DIR = path.join(__dirname, 'demo-files');

// Fonction pour créer les fichiers de démonstration
async function setupDemo() {
  console.log('=== Configuration de la démonstration QuickFiles ===');
  
  // Créer le dossier de démonstration s'il n'existe pas
  try {
    await fs.mkdir(DEMO_DIR, { recursive: true });
    console.log(`✓ Dossier de démonstration créé: ${DEMO_DIR}`);
  } catch (error) {
    console.error(`✗ Erreur lors de la création du dossier de démonstration: ${error.message}`);
    process.exit(1);
  }

  try {
    // Créer des fichiers pour read_multiple_files
    const file1Content = 'Titre du document\n\nCeci est le premier paragraphe du document.\n\nCeci est le deuxième paragraphe avec des informations importantes.\n\nConclusion du document.';
    const file2Content = 'Liste des tâches:\n1. Première tâche à accomplir\n2. Deuxième tâche importante\n3. Tâche finale à terminer\n\nNotes supplémentaires:\n- Point important à retenir\n- Autre point à considérer';
    
    await fs.writeFile(path.join(DEMO_DIR, 'document.txt'), file1Content);
    await fs.writeFile(path.join(DEMO_DIR, 'tasks.txt'), file2Content);
    console.log('✓ Fichiers pour read_multiple_files créés');

    // Créer un fichier long pour tester les limites de lignes
    let longFileContent = '';
    for (let i = 1; i <= 200; i++) {
      longFileContent += `Ligne ${i}: Ceci est un exemple de contenu pour tester la limitation du nombre de lignes.\n`;
    }
    await fs.writeFile(path.join(DEMO_DIR, 'long-file.txt'), longFileContent);
    console.log('✓ Fichier long créé avec 200 lignes');

    // Créer des fichiers pour edit_multiple_files
    const editFile1 = 'Texte à modifier: première occurrence.\nCette ligne reste inchangée.\nTexte à modifier: deuxième occurrence.';
    const editFile2 = 'Autre texte à modifier dans un fichier différent.\nCette ligne reste aussi inchangée.';
    
    await fs.writeFile(path.join(DEMO_DIR, 'edit-file1.txt'), editFile1);
    await fs.writeFile(path.join(DEMO_DIR, 'edit-file2.txt'), editFile2);
    console.log('✓ Fichiers pour edit_multiple_files créés');

    // Créer des fichiers pour delete_files
    await fs.writeFile(path.join(DEMO_DIR, 'to-delete1.tmp'), 'Ce fichier sera supprimé');
    await fs.writeFile(path.join(DEMO_DIR, 'to-delete2.tmp'), 'Ce fichier sera également supprimé');
    console.log('✓ Fichiers pour delete_files créés');

    // Créer une structure de répertoires pour list_directory_contents
    await fs.mkdir(path.join(DEMO_DIR, 'subdir1'), { recursive: true });
    await fs.mkdir(path.join(DEMO_DIR, 'subdir2'), { recursive: true });
    await fs.mkdir(path.join(DEMO_DIR, 'subdir1', 'nested'), { recursive: true });
    
    await fs.writeFile(path.join(DEMO_DIR, 'subdir1', 'file1.txt'), 'Contenu du fichier 1');
    await fs.writeFile(path.join(DEMO_DIR, 'subdir1', 'file2.js'), 'console.log("Hello from JS file");');
    await fs.writeFile(path.join(DEMO_DIR, 'subdir2', 'file3.txt'), 'Contenu du fichier 3');
    await fs.writeFile(path.join(DEMO_DIR, 'subdir1', 'nested', 'nested-file.txt'), 'Fichier dans un sous-dossier imbriqué');
    
    console.log('✓ Structure de répertoires pour list_directory_contents créée');

    console.log('=== Configuration terminée avec succès ===');
  } catch (error) {
    console.error(`✗ Erreur lors de la création des fichiers de démonstration: ${error.message}`);
    process.exit(1);
  }
}

// Exécuter la configuration
setupDemo().catch(error => {
  console.error(`Erreur non gérée: ${error.message}`);
  process.exit(1);
});