/**
 * Script de test pour l'intégration du serveur MCP Jupyter avec Roo
 * Ce script teste les fonctionnalités de base du serveur MCP Jupyter
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Fonction pour simuler un appel d'outil MCP
async function callMcpTool(serverName, toolName, args) {
  console.log(`\n=== Test de l'outil ${toolName} ===`);
  console.log(`Arguments: ${JSON.stringify(args, null, 2)}`);
  
  // Dans un vrai environnement, cela serait fait via Roo
  // Ici, nous simulons l'appel en affichant les informations
  console.log(`<use_mcp_tool>
<server_name>${serverName}</server_name>
<tool_name>${toolName}</tool_name>
<arguments>
${JSON.stringify(args, null, 2)}
</arguments>
</use_mcp_tool>`);
  
  console.log("Cet appel serait normalement traité par Roo et envoyé au serveur MCP Jupyter");
  console.log("Pour tester réellement, copiez la commande ci-dessus dans Roo");
}

// Fonction principale de test
async function runTests() {
  console.log("=== Tests d'intégration du serveur MCP Jupyter avec Roo ===");
  
  // Test 1: Création d'un notebook
  await callMcpTool("jupyter", "create_notebook", {
    path: "./test_notebook_roo.ipynb",
    kernel: "python3"
  });
  
  // Test 2: Démarrage d'un kernel
  await callMcpTool("jupyter", "start_kernel", {
    kernel_name: "python3"
  });
  
  // Note: Dans un vrai test, nous récupérerions l'ID du kernel retourné
  // Pour ce test, nous utilisons un ID fictif
  const kernelId = "kernel-id-fictif";
  
  // Test 3: Ajout d'une cellule au notebook
  await callMcpTool("jupyter", "add_cell", {
    path: "./test_notebook_roo.ipynb",
    cell_type: "code",
    source: "print('Hello from Roo!')"
  });
  
  // Test 4: Exécution de code
  await callMcpTool("jupyter", "execute_cell", {
    kernel_id: kernelId,
    code: "import sys\nprint(f'Python version: {sys.version}')"
  });
  
  // Test 5: Arrêt du kernel
  await callMcpTool("jupyter", "stop_kernel", {
    kernel_id: kernelId
  });
  
  console.log("\n=== Tests terminés ===");
  console.log("Pour tester réellement l'intégration avec Roo, copiez les commandes ci-dessus dans Roo");
  console.log("Assurez-vous que les serveurs Jupyter et MCP Jupyter sont en cours d'exécution");
}

// Exécuter les tests
runTests().catch(err => {
  console.error("Erreur lors des tests:", err);
});