/**
 * Script pour vérifier l'état du serveur MCP Jupyter
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// Fonction pour exécuter une commande et capturer sa sortie
function executeCommand(command, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, { shell: true });
    let stdout = '';
    let stderr = '';
    
    proc.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    proc.stderr.on('data', (data) => {
      stderr += data.toString();
    });
    
    proc.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
    
    proc.on('error', (err) => {
      reject(err);
    });
  });
}

// Fonction principale
async function main() {
  console.log("=== Vérification de l'état du serveur MCP Jupyter ===");
  
  // Vérifier les processus en cours d'exécution
  console.log("\n1. Vérification des processus en cours d'exécution...");
  try {
    const result = await executeCommand('tasklist', ['/fi', 'imagename eq node.exe']);
    console.log(result.stdout);
  } catch (error) {
    console.error("Erreur lors de la vérification des processus:", error);
  }
  
  // Vérifier la configuration
  console.log("\n2. Vérification de la configuration...");
  try {
    const configPath = path.join(__dirname, 'servers', 'jupyter-mcp-server', 'config.json');
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      console.log("Configuration du serveur MCP Jupyter:", config);
    } else {
      console.log("Fichier de configuration non trouvé:", configPath);
    }
  } catch (error) {
    console.error("Erreur lors de la vérification de la configuration:", error);
  }
  
  // Vérifier si le serveur Jupyter est accessible
  console.log("\n3. Vérification de l'accessibilité du serveur Jupyter...");
  try {
    const result = await executeCommand('curl', ['-s', '-o', '/dev/null', '-w', '"%{http_code}"', 'http://localhost:8888']);
    console.log(`Code de statut HTTP: ${result.stdout}`);
  } catch (error) {
    console.error("Erreur lors de la vérification de l'accessibilité du serveur Jupyter:", error);
  }
  
  console.log("\n=== Vérification terminée ===");
}

// Exécuter la fonction principale
main().catch(console.error);