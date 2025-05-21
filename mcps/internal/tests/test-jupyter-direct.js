/**
 * Script de test direct pour le serveur MCP Jupyter
 */

const net = require('net');

// Fonction pour tester si le serveur est en écoute sur un port
function testServerConnection(port) {
  return new Promise((resolve, reject) => {
    const socket = new net.Socket();
    
    // Définir un timeout de 2 secondes
    const timeout = setTimeout(() => {
      socket.destroy();
      reject(new Error(`Timeout en essayant de se connecter au port ${port}`));
    }, 2000);
    
    socket.connect(port, '127.0.0.1', () => {
      clearTimeout(timeout);
      socket.destroy();
      resolve(true);
    });
    
    socket.on('error', (err) => {
      clearTimeout(timeout);
      reject(err);
    });
  });
}

// Fonction principale
async function main() {
  console.log("Test de connexion au serveur MCP Jupyter...");
  
  try {
    // Le serveur MCP Jupyter utilise stdio, donc nous ne pouvons pas nous y connecter directement
    // Mais nous pouvons vérifier si le serveur Jupyter est en cours d'exécution
    await testServerConnection(8888);
    console.log("Le serveur Jupyter est accessible sur le port 8888");
  } catch (error) {
    console.error("Erreur lors du test de connexion au serveur Jupyter:", error.message);
  }
  
  // Vérifier si le fichier de configuration existe
  const fs = require('fs');
  const path = require('path');
  
  const configPath = path.join(__dirname, 'servers', 'jupyter-mcp-server', 'config.json');
  if (fs.existsSync(configPath)) {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    console.log("Configuration du serveur MCP Jupyter:", config);
  } else {
    console.log("Fichier de configuration non trouvé:", configPath);
  }
}

// Exécuter la fonction principale
main().catch(console.error);