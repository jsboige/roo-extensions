/**
 * Démonstration pratique du MCP QuickFiles avec Roo
 * 
 * Ce script montre comment utiliser les fonctionnalités du MCP QuickFiles
 * directement avec l'API MCP de Roo.
 */

// Fonction pour exécuter la démonstration
async function runQuickFilesDemo() {
  console.log("=== DÉMONSTRATION DU MCP QUICKFILES AVEC ROO ===");
  
  // Créer le dossier de démonstration et les fichiers nécessaires
  await setupDemoFiles();
  
  try {
    // 1. Démonstration de read_multiple_files
    await demoReadMultipleFiles();
    
    // 2. Démonstration de list_directory_contents
    await demoListDirectoryContents();
    
    // 3. Démonstration de edit_multiple_files
    await demoEditMultipleFiles();
    
    // 4. Démonstration de delete_files
    await demoDeleteFiles();
    
    console.log("\n=== DÉMONSTRATION TERMINÉE AVEC SUCCÈS ===");
  } catch (error) {
    console.error(`Erreur lors de la démonstration: ${error.message}`);
  } finally {
    // Nettoyer les fichiers de démonstration
    await cleanupDemoFiles();
  }
}

// Fonction pour configurer les fichiers de démonstration
async function setupDemoFiles() {
  console.log("\n=== Configuration des fichiers de démonstration ===");
  
  // Créer le dossier demo-files
  const demoDir = "./demo-quickfiles/demo-files";
  
  // Créer des fichiers pour read_multiple_files
  const file1Content = "Titre du document\n\nCeci est le premier paragraphe du document.\n\nCeci est le deuxième paragraphe avec des informations importantes.\n\nConclusion du document.";
  const file2Content = "Liste des tâches:\n1. Première tâche à accomplir\n2. Deuxième tâche importante\n3. Tâche finale à terminer\n\nNotes supplémentaires:\n- Point important à retenir\n- Autre point à considérer";
  
  // Créer un fichier long pour tester les limites de lignes
  let longFileContent = "";
  for (let i = 1; i <= 200; i++) {
    longFileContent += `Ligne ${i}: Ceci est un exemple de contenu pour tester la limitation du nombre de lignes.\n`;
  }
  
  // Créer des fichiers pour edit_multiple_files
  const editFile1 = "Texte à modifier: première occurrence.\nCette ligne reste inchangée.\nTexte à modifier: deuxième occurrence.";
  const editFile2 = "Autre texte à modifier dans un fichier différent.\nCette ligne reste aussi inchangée.";
  
  // Créer des fichiers pour delete_files
  const deleteFile1 = "Ce fichier sera supprimé";
  const deleteFile2 = "Ce fichier sera également supprimé";
  
  // Écrire les fichiers
  await writeToFile(`${demoDir}/document.txt`, file1Content);
  await writeToFile(`${demoDir}/tasks.txt`, file2Content);
  await writeToFile(`${demoDir}/long-file.txt`, longFileContent);
  await writeToFile(`${demoDir}/edit-file1.txt`, editFile1);
  await writeToFile(`${demoDir}/edit-file2.txt`, editFile2);
  await writeToFile(`${demoDir}/to-delete1.tmp`, deleteFile1);
  await writeToFile(`${demoDir}/to-delete2.tmp`, deleteFile2);
  
  // Créer une structure de répertoires pour list_directory_contents
  await createDirectory(`${demoDir}/subdir1`);
  await createDirectory(`${demoDir}/subdir2`);
  await createDirectory(`${demoDir}/subdir1/nested`);
  
  await writeToFile(`${demoDir}/subdir1/file1.txt`, "Contenu du fichier 1");
  await writeToFile(`${demoDir}/subdir1/file2.js`, "console.log(\"Hello from JS file\");");
  await writeToFile(`${demoDir}/subdir2/file3.txt`, "Contenu du fichier 3");
  await writeToFile(`${demoDir}/subdir1/nested/nested-file.txt`, "Fichier dans un sous-dossier imbriqué");
  
  console.log("✓ Fichiers de démonstration créés avec succès");
}

// Fonction pour nettoyer les fichiers de démonstration
async function cleanupDemoFiles() {
  console.log("\n=== Nettoyage des fichiers de démonstration ===");
  // Dans un environnement réel, on supprimerait le dossier demo-files
  console.log("✓ Fichiers de démonstration nettoyés");
}

// Fonction pour démontrer read_multiple_files
async function demoReadMultipleFiles() {
  console.log("\n=== 1. DÉMONSTRATION DE READ_MULTIPLE_FILES ===");
  
  // 1.1 Lecture simple de plusieurs fichiers
  console.log("\n1.1 Lecture simple de plusieurs fichiers");
  const readResult1 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "read_multiple_files",
    arguments: {
      paths: [
        "./demo-quickfiles/demo-files/document.txt",
        "./demo-quickfiles/demo-files/tasks.txt"
      ],
      show_line_numbers: true
    }
  });
  console.log("Résultat:");
  console.log(readResult1.content[0].text);
  
  // 1.2 Lecture avec limitation du nombre de lignes
  console.log("\n1.2 Lecture avec limitation du nombre de lignes");
  const readResult2 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "read_multiple_files",
    arguments: {
      paths: [
        "./demo-quickfiles/demo-files/long-file.txt"
      ],
      max_lines_per_file: 10,
      show_line_numbers: true
    }
  });
  console.log("Résultat (limité à 10 lignes):");
  console.log(readResult2.content[0].text);
  
  // 1.3 Lecture d'extraits spécifiques
  console.log("\n1.3 Lecture d'extraits spécifiques");
  const readResult3 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "read_multiple_files",
    arguments: {
      paths: [
        {
          path: "./demo-quickfiles/demo-files/long-file.txt",
          excerpts: [
            { start: 50, end: 55 },
            { start: 100, end: 105 }
          ]
        }
      ],
      show_line_numbers: true
    }
  });
  console.log("Résultat (extraits spécifiques):");
  console.log(readResult3.content[0].text);
}

// Fonction pour démontrer list_directory_contents
async function demoListDirectoryContents() {
  console.log("\n=== 2. DÉMONSTRATION DE LIST_DIRECTORY_CONTENTS ===");
  
  // 2.1 Listage simple d'un répertoire
  console.log("\n2.1 Listage simple d'un répertoire");
  const listResult1 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "list_directory_contents",
    arguments: {
      paths: [
        { path: "./demo-quickfiles/demo-files", recursive: false }
      ]
    }
  });
  console.log("Résultat (non récursif):");
  console.log(listResult1.content[0].text);
  
  // 2.2 Listage récursif
  console.log("\n2.2 Listage récursif");
  const listResult2 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "list_directory_contents",
    arguments: {
      paths: [
        { path: "./demo-quickfiles/demo-files", recursive: true }
      ]
    }
  });
  console.log("Résultat (récursif):");
  console.log(listResult2.content[0].text);
  
  // 2.3 Listage avec filtrage par motif
  console.log("\n2.3 Listage avec filtrage par motif");
  const listResult3 = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "list_directory_contents",
    arguments: {
      paths: [
        { path: "./demo-quickfiles/demo-files", recursive: true, file_pattern: "*.txt" }
      ]
    }
  });
  console.log("Résultat (filtré par *.txt):");
  console.log(listResult3.content[0].text);
}

// Fonction pour démontrer edit_multiple_files
async function demoEditMultipleFiles() {
  console.log("\n=== 3. DÉMONSTRATION DE EDIT_MULTIPLE_FILES ===");
  
  // 3.1 Édition de fichiers multiples
  console.log("\n3.1 Édition de fichiers multiples");
  
  // Lire le contenu avant modification
  const beforeEdit1 = await readFile("./demo-quickfiles/demo-files/edit-file1.txt");
  const beforeEdit2 = await readFile("./demo-quickfiles/demo-files/edit-file2.txt");
  
  console.log("Contenu avant modification:");
  console.log(`edit-file1.txt:\n${beforeEdit1}\n`);
  console.log(`edit-file2.txt:\n${beforeEdit2}\n`);
  
  // Effectuer les modifications
  const editResult = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "edit_multiple_files",
    arguments: {
      files: [
        {
          path: "./demo-quickfiles/demo-files/edit-file1.txt",
          diffs: [
            {
              search: "Texte à modifier: première occurrence.",
              replace: "Texte MODIFIÉ: première occurrence."
            },
            {
              search: "Texte à modifier: deuxième occurrence.",
              replace: "Texte MODIFIÉ: deuxième occurrence."
            }
          ]
        },
        {
          path: "./demo-quickfiles/demo-files/edit-file2.txt",
          diffs: [
            {
              search: "Autre texte à modifier dans un fichier différent.",
              replace: "Autre texte MODIFIÉ dans un fichier différent."
            }
          ]
        }
      ]
    }
  });
  
  console.log("Résultat de l'édition:");
  console.log(editResult.content[0].text);
  
  // Lire le contenu après modification
  const afterEdit1 = await readFile("./demo-quickfiles/demo-files/edit-file1.txt");
  const afterEdit2 = await readFile("./demo-quickfiles/demo-files/edit-file2.txt");
  
  console.log("Contenu après modification:");
  console.log(`edit-file1.txt:\n${afterEdit1}\n`);
  console.log(`edit-file2.txt:\n${afterEdit2}\n`);
}

// Fonction pour démontrer delete_files
async function demoDeleteFiles() {
  console.log("\n=== 4. DÉMONSTRATION DE DELETE_FILES ===");
  
  // 4.1 Suppression de fichiers
  console.log("\n4.1 Suppression de fichiers");
  
  // Vérifier l'existence des fichiers avant suppression
  const fileExists1Before = await fileExists("./demo-quickfiles/demo-files/to-delete1.tmp");
  const fileExists2Before = await fileExists("./demo-quickfiles/demo-files/to-delete2.tmp");
  
  console.log("Avant suppression:");
  console.log(`to-delete1.tmp existe: ${fileExists1Before}`);
  console.log(`to-delete2.tmp existe: ${fileExists2Before}`);
  
  // Supprimer les fichiers
  const deleteResult = await useMcpTool({
    server_name: "quickfiles",
    tool_name: "delete_files",
    arguments: {
      paths: [
        "./demo-quickfiles/demo-files/to-delete1.tmp",
        "./demo-quickfiles/demo-files/to-delete2.tmp"
      ]
    }
  });
  
  console.log("Résultat de la suppression:");
  console.log(deleteResult.content[0].text);
  
  // Vérifier l'existence des fichiers après suppression
  const fileExists1After = await fileExists("./demo-quickfiles/demo-files/to-delete1.tmp");
  const fileExists2After = await fileExists("./demo-quickfiles/demo-files/to-delete2.tmp");
  
  console.log("Après suppression:");
  console.log(`to-delete1.tmp existe: ${fileExists1After}`);
  console.log(`to-delete2.tmp existe: ${fileExists2After}`);
}

// Fonction utilitaire pour vérifier si un fichier existe
async function fileExists(filePath) {
  try {
    await readFile(filePath);
    return true;
  } catch {
    return false;
  }
}

// Exécuter la démonstration
runQuickFilesDemo();