/**
 * Exemple simple d'utilisation du MCP QuickFiles avec Roo
 * 
 * Ce script montre comment utiliser les fonctionnalités du MCP QuickFiles
 * directement avec l'API MCP de Roo.
 */

// Fonction principale
async function main() {
  console.log("=== EXEMPLE D'UTILISATION DU MCP QUICKFILES ===");
  
  try {
    // 1. Lire plusieurs fichiers
    console.log("\n1. Lecture de plusieurs fichiers");
    const readResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "read_multiple_files",
      arguments: {
        paths: ["./README.md", "./package.json"],
        show_line_numbers: true,
        max_lines_per_file: 20
      }
    });
    
    console.log("Résultat de la lecture :");
    console.log(readResult.content[0].text);
    
    // 2. Lister le contenu d'un répertoire
    console.log("\n2. Listage du contenu d'un répertoire");
    const listResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "list_directory_contents",
      arguments: {
        paths: [
          { path: "./servers", recursive: false }
        ]
      }
    });
    
    console.log("Contenu du répertoire servers :");
    console.log(listResult.content[0].text);
    
    // 3. Créer et modifier un fichier temporaire
    console.log("\n3. Création et modification d'un fichier temporaire");
    
    // Créer un fichier temporaire
    const fs = require('fs').promises;
    await fs.writeFile("./temp-example.txt", "Ligne 1: Texte original\nLigne 2: Autre texte original");
    console.log("Fichier temporaire créé");
    
    // Modifier le fichier
    const editResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "edit_multiple_files",
      arguments: {
        files: [
          {
            path: "./temp-example.txt",
            diffs: [
              {
                search: "Texte original",
                replace: "Texte modifié"
              }
            ]
          }
        ]
      }
    });
    
    console.log("Résultat de la modification :");
    console.log(editResult.content[0].text);
    
    // Lire le fichier modifié
    const modifiedContent = await fs.readFile("./temp-example.txt", "utf-8");
    console.log("Contenu du fichier après modification :");
    console.log(modifiedContent);
    
    // 4. Supprimer le fichier temporaire
    console.log("\n4. Suppression du fichier temporaire");
    const deleteResult = await useMcpTool({
      server_name: "quickfiles",
      tool_name: "delete_files",
      arguments: {
        paths: ["./temp-example.txt"]
      }
    });
    
    console.log("Résultat de la suppression :");
    console.log(deleteResult.content[0].text);
    
    console.log("\n=== EXEMPLE TERMINÉ AVEC SUCCÈS ===");
  } catch (error) {
    console.error(`Erreur : ${error.message}`);
  }
}

// Fonction simulée pour l'exemple
async function useMcpTool(params) {
  console.log(`Appel à l'outil MCP ${params.tool_name} du serveur ${params.server_name}`);
  console.log(`Arguments : ${JSON.stringify(params.arguments, null, 2)}`);
  
  // Dans un environnement Roo réel, cette fonction appellerait l'API MCP
  // et retournerait le résultat de l'appel
  
  // Pour cet exemple, nous simulons une réponse
  return {
    content: [
      {
        text: `Résultat simulé de l'appel à ${params.tool_name}`
      }
    ]
  };
}

// Exécuter l'exemple
main().catch(console.error);