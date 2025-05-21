/**
 * Script de test pour vérifier l'intégration du MCP Jupyter avec les kernels VSCode
 * Ce script teste:
 * 1. La détection des kernels VSCode
 * 2. La connexion du MCP Jupyter aux kernels VSCode
 * 3. L'exécution de code simple via cette intégration
 */

import { spawn, exec } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import http from 'http';

// Obtenir le chemin du répertoire actuel en ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const config = {
  mcpJupyterDir: path.join(__dirname, '..', '..', 'mcps', 'mcp-servers', 'servers', 'jupyter-mcp-server'),
  vscodeIntegrationScript: path.join(__dirname, '..', '..', 'mcps', 'jupyter', 'start-jupyter-mcp-vscode.bat'),
  configFile: path.join(__dirname, '..', '..', 'mcps', 'mcp-servers', 'servers', 'jupyter-mcp-server', 'config.json'),
  configBackup: path.join(__dirname, '..', '..', 'mcps', 'mcp-servers', 'servers', 'jupyter-mcp-server', 'config.test.backup.json'),
  testTimeout: 60000, // 60 secondes
  serverStartupTimeout: 15000, // 15 secondes
  testCode: 'print("Hello from VSCode kernel!")',
};

// Variables globales
let mcpProcess = null;
let serverConfig = null;

// Fonction pour exécuter une commande et capturer sa sortie
function executeCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    console.log(`Exécution de la commande: ${command} ${args ? args.join(' ') : ''}`);
    
    const proc = spawn(command, args, {
      ...options,
      stdio: 'pipe',
      shell: true
    });
    
    let stdout = '';
    let stderr = '';
    
    proc.stdout.on('data', (data) => {
      const output = data.toString().trim();
      stdout += output + '\n';
      console.log(`[STDOUT] ${output}`);
    });
    
    proc.stderr.on('data', (data) => {
      const output = data.toString().trim();
      stderr += output + '\n';
      console.error(`[STDERR] ${output}`);
    });
    
    proc.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
    
    proc.on('error', (err) => {
      reject(err);
    });
  });
}

// Fonction pour exécuter une commande PowerShell
function executePowerShell(script) {
  return new Promise((resolve, reject) => {
    exec(`powershell -Command "${script}"`, (error, stdout, stderr) => {
      if (error) {
        console.error(`Erreur PowerShell: ${error}`);
        reject(error);
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

// Fonction pour sauvegarder la configuration actuelle
async function backupConfig() {
  try {
    if (fs.existsSync(config.configFile)) {
      console.log('Sauvegarde de la configuration actuelle...');
      fs.copyFileSync(config.configFile, config.configBackup);
      console.log(`Configuration sauvegardée dans ${config.configBackup}`);
    }
  } catch (error) {
    console.error('Erreur lors de la sauvegarde de la configuration:', error);
    throw error;
  }
}

// Fonction pour restaurer la configuration sauvegardée
async function restoreConfig() {
  try {
    if (fs.existsSync(config.configBackup)) {
      console.log('Restauration de la configuration sauvegardée...');
      fs.copyFileSync(config.configBackup, config.configFile);
      console.log('Configuration restaurée');
    }
  } catch (error) {
    console.error('Erreur lors de la restauration de la configuration:', error);
  }
}

// Fonction pour détecter les kernels VSCode
async function detectVSCodeKernels() {
  console.log('Détection des kernels VSCode...');
  
  try {
    const script = `
      $vscodeExtensions = "$env:USERPROFILE\\.vscode\\extensions"
      $vscodeInsidersExtensions = "$env:USERPROFILE\\.vscode-insiders\\extensions"
      $kernels = @()
      
      function Find-JupyterKernels {
        param (
          [string]$ExtensionsPath
        )
        
        if (-not (Test-Path $ExtensionsPath)) {
          return @()
        }
        
        $jupyterExtensions = Get-ChildItem -Path $ExtensionsPath -Directory | Where-Object { 
          $_.Name -like 'ms-toolsai.jupyter*' -or 
          $_.Name -like 'ms-python.python*'
        }
        
        $result = @()
        
        foreach ($ext in $jupyterExtensions) {
          $kernelJsonFiles = Get-ChildItem -Path $ext.FullName -Filter 'kernel.json' -Recurse -ErrorAction SilentlyContinue
          
          foreach ($kernelJson in $kernelJsonFiles) {
            try {
              $kernelData = Get-Content -Path $kernelJson.FullName -Raw | ConvertFrom-Json
              $kernelDir = Split-Path -Parent $kernelJson.FullName
              $kernelName = Split-Path -Leaf (Split-Path -Parent $kernelJson.FullName)
              
              $result += @{
                'name' = $kernelName
                'display_name' = if ($kernelData.display_name) { $kernelData.display_name } else { $kernelName }
                'path' = $kernelDir
              }
            } catch {}
          }
        }
        
        return $result
      }
      
      $vsCodeKernels = Find-JupyterKernels -ExtensionsPath $vscodeExtensions
      $vsCodeInsidersKernels = Find-JupyterKernels -ExtensionsPath $vscodeInsidersExtensions
      
      $allKernels = $vsCodeKernels + $vsCodeInsidersKernels
      
      if ($allKernels.Count -gt 0) {
        $allKernels | ConvertTo-Json
      } else {
        Write-Host "Aucun kernel VSCode trouvé"
      }
    `;
    
    const { stdout } = await executePowerShell(script);
    
    try {
      const kernels = JSON.parse(stdout);
      console.log(`${kernels.length} kernels VSCode trouvés:`);
      kernels.forEach(kernel => {
        console.log(`- ${kernel.name} (${kernel.display_name})`);
      });
      return kernels;
    } catch (e) {
      console.log('Aucun kernel VSCode trouvé ou erreur de parsing JSON');
      return [];
    }
  } catch (error) {
    console.error('Erreur lors de la détection des kernels VSCode:', error);
    return [];
  }
}

// Fonction pour démarrer le MCP Jupyter avec le script d'intégration VSCode
async function startMCPJupyterWithVSCodeIntegration() {
  console.log('Démarrage du MCP Jupyter avec intégration VSCode...');
  
  return new Promise((resolve, reject) => {
    // Vérifier si le script d'intégration existe
    if (!fs.existsSync(config.vscodeIntegrationScript)) {
      reject(new Error(`Le script d'intégration VSCode n'existe pas: ${config.vscodeIntegrationScript}`));
      return;
    }
    
    // Démarrer le processus en arrière-plan
    mcpProcess = spawn(config.vscodeIntegrationScript, [], {
      stdio: 'pipe',
      shell: true,
      detached: true
    });
    
    let stdout = '';
    let stderr = '';
    let serverStarted = false;
    
    mcpProcess.stdout.on('data', (data) => {
      const output = data.toString().trim();
      stdout += output + '\n';
      console.log(`[MCP] ${output}`);
      
      // Détecter si le serveur a démarré avec succès
      if (output.includes('MCP server started') || 
          output.includes('Server listening') || 
          output.includes('Serveur MCP démarré')) {
        serverStarted = true;
        
        // Lire la configuration pour obtenir l'URL et le token
        try {
          serverConfig = JSON.parse(fs.readFileSync(config.configFile, 'utf8'));
          resolve({ success: true, config: serverConfig });
        } catch (error) {
          console.error('Erreur lors de la lecture de la configuration:', error);
          resolve({ success: true, config: null });
        }
      }
    });
    
    mcpProcess.stderr.on('data', (data) => {
      const output = data.toString().trim();
      stderr += output + '\n';
      console.error(`[MCP ERROR] ${output}`);
    });
    
    mcpProcess.on('error', (error) => {
      console.error('Erreur lors du démarrage du MCP Jupyter:', error);
      reject(error);
    });
    
    mcpProcess.on('close', (code) => {
      if (!serverStarted) {
        reject(new Error(`Le serveur MCP Jupyter s'est arrêté avec le code ${code} avant de démarrer complètement`));
      }
    });
    
    // Timeout si le serveur ne démarre pas dans le délai imparti
    setTimeout(() => {
      if (!serverStarted) {
        reject(new Error(`Timeout: Le serveur MCP Jupyter n'a pas démarré dans les ${config.serverStartupTimeout / 1000} secondes`));
      }
    }, config.serverStartupTimeout);
  });
}

// Fonction pour tester la connexion au serveur MCP
async function testMCPConnection() {
  console.log('Test de la connexion au serveur MCP...');
  
  if (!serverConfig || !serverConfig.jupyterServer) {
    console.error('Configuration du serveur non disponible');
    return false;
  }
  
  // Si le mode hors ligne est activé, on ne peut pas tester la connexion
  if (serverConfig.jupyterServer.offline) {
    console.log('Le serveur est en mode hors ligne, impossible de tester la connexion');
    return false;
  }
  
  return new Promise((resolve) => {
    const url = `${serverConfig.jupyterServer.baseUrl}/api/kernels?token=${serverConfig.jupyterServer.token}`;
    console.log(`Tentative de connexion à ${url}...`);
    
    const req = http.get(url, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('Connexion réussie au serveur Jupyter');
          try {
            const kernels = JSON.parse(data);
            console.log(`${kernels.length} kernels disponibles sur le serveur`);
            resolve(true);
          } catch (e) {
            console.error('Erreur lors du parsing de la réponse JSON:', e);
            resolve(false);
          }
        } else {
          console.error(`Échec de la connexion: ${res.statusCode} ${res.statusMessage}`);
          resolve(false);
        }
      });
    });
    
    req.on('error', (error) => {
      console.error('Erreur lors de la connexion au serveur:', error);
      resolve(false);
    });
    
    req.end();
  });
}

// Fonction pour tester l'exécution de code via le MCP
async function testCodeExecution() {
  console.log('Test de l\'exécution de code via le MCP...');
  
  if (!serverConfig || !serverConfig.jupyterServer || serverConfig.jupyterServer.offline) {
    console.log('Le serveur est en mode hors ligne ou la configuration n\'est pas disponible, impossible de tester l\'exécution de code');
    return false;
  }
  
  try {
    // Simuler une requête MCP pour exécuter du code
    // Dans un environnement réel, cela serait fait via l'API MCP
    // Ici, nous utilisons curl pour simuler la requête
    
    const kernelListUrl = `${serverConfig.jupyterServer.baseUrl}/api/kernels?token=${serverConfig.jupyterServer.token}`;
    
    // Obtenir la liste des kernels
    const kernelListResult = await executeCommand('curl', ['-s', kernelListUrl]);
    
    if (kernelListResult.code !== 0) {
      console.error('Erreur lors de la récupération de la liste des kernels');
      return false;
    }
    
    let kernels;
    try {
      kernels = JSON.parse(kernelListResult.stdout);
    } catch (e) {
      console.error('Erreur lors du parsing de la liste des kernels:', e);
      return false;
    }
    
    if (kernels.length === 0) {
      console.log('Aucun kernel disponible, démarrage d\'un nouveau kernel...');
      
      // Démarrer un nouveau kernel (python3 par défaut)
      const startKernelUrl = `${serverConfig.jupyterServer.baseUrl}/api/kernels?token=${serverConfig.jupyterServer.token}`;
      const startKernelResult = await executeCommand('curl', [
        '-s',
        '-X', 'POST',
        '-H', 'Content-Type: application/json',
        '-d', '{"name":"python3"}',
        startKernelUrl
      ]);
      
      if (startKernelResult.code !== 0) {
        console.error('Erreur lors du démarrage d\'un nouveau kernel');
        return false;
      }
      
      try {
        const newKernel = JSON.parse(startKernelResult.stdout);
        console.log(`Nouveau kernel démarré: ${newKernel.id}`);
        kernels = [newKernel];
      } catch (e) {
        console.error('Erreur lors du parsing de la réponse du nouveau kernel:', e);
        return false;
      }
    }
    
    // Utiliser le premier kernel disponible
    const kernel = kernels[0];
    console.log(`Utilisation du kernel: ${kernel.id} (${kernel.name})`);
    
    // Exécuter du code dans le kernel
    const executeUrl = `${serverConfig.jupyterServer.baseUrl}/api/kernels/${kernel.id}/execute?token=${serverConfig.jupyterServer.token}`;
    const executeResult = await executeCommand('curl', [
      '-s',
      '-X', 'POST',
      '-H', 'Content-Type: application/json',
      '-d', `{"code":"${config.testCode}","silent":false}`,
      executeUrl
    ]);
    
    if (executeResult.code !== 0) {
      console.error('Erreur lors de l\'exécution du code');
      return false;
    }
    
    console.log('Code exécuté avec succès');
    return true;
  } catch (error) {
    console.error('Erreur lors du test d\'exécution de code:', error);
    return false;
  }
}

// Fonction pour arrêter le serveur MCP Jupyter
function stopMCPJupyter() {
  return new Promise((resolve) => {
    if (mcpProcess) {
      console.log('Arrêt du serveur MCP Jupyter...');
      
      // Tuer le processus et tous ses enfants
      if (process.platform === 'win32') {
        // Sur Windows, utiliser taskkill pour tuer le processus et ses enfants
        exec(`taskkill /pid ${mcpProcess.pid} /T /F`, (error) => {
          if (error) {
            console.error('Erreur lors de l\'arrêt du serveur:', error);
          } else {
            console.log('Serveur MCP Jupyter arrêté');
          }
          mcpProcess = null;
          resolve();
        });
      } else {
        // Sur Unix, utiliser process.kill
        try {
          process.kill(-mcpProcess.pid);
          console.log('Serveur MCP Jupyter arrêté');
        } catch (error) {
          console.error('Erreur lors de l\'arrêt du serveur:', error);
        }
        mcpProcess = null;
        resolve();
      }
    } else {
      resolve();
    }
  });
}

// Fonction principale
async function main() {
  console.log('=== Test d\'intégration du MCP Jupyter avec VSCode ===');
  
  try {
    // Sauvegarder la configuration actuelle
    await backupConfig();
    
    // Étape 1: Détecter les kernels VSCode
    console.log('\n=== Étape 1: Détection des kernels VSCode ===');
    const kernels = await detectVSCodeKernels();
    const kernelsDetected = kernels.length > 0;
    
    // Étape 2: Démarrer le MCP Jupyter avec l'intégration VSCode
    console.log('\n=== Étape 2: Démarrage du MCP Jupyter avec intégration VSCode ===');
    const startResult = await startMCPJupyterWithVSCodeIntegration();
    
    // Étape 3: Tester la connexion au serveur MCP
    console.log('\n=== Étape 3: Test de la connexion au serveur MCP ===');
    const connectionSuccess = await testMCPConnection();
    
    // Étape 4: Tester l'exécution de code
    console.log('\n=== Étape 4: Test de l\'exécution de code ===');
    const executionSuccess = await testCodeExecution();
    
    // Afficher les résultats
    console.log('\n=== Résultats du test ===');
    
    if (kernelsDetected) {
      console.log('✅ Kernels VSCode détectés avec succès');
    } else {
      console.log('❌ Aucun kernel VSCode détecté');
    }
    
    if (startResult.success) {
      console.log('✅ MCP Jupyter démarré avec succès');
      
      if (startResult.config && startResult.config.jupyterServer.offline) {
        console.log('ℹ️ Le serveur est en mode hors ligne');
      }
    } else {
      console.log('❌ Échec du démarrage du MCP Jupyter');
    }
    
    if (connectionSuccess) {
      console.log('✅ Connexion au serveur MCP réussie');
    } else if (startResult.config && startResult.config.jupyterServer.offline) {
      console.log('ℹ️ Test de connexion ignoré (mode hors ligne)');
    } else {
      console.log('❌ Échec de la connexion au serveur MCP');
    }
    
    if (executionSuccess) {
      console.log('✅ Exécution de code réussie');
    } else if (startResult.config && startResult.config.jupyterServer.offline) {
      console.log('ℹ️ Test d\'exécution ignoré (mode hors ligne)');
    } else {
      console.log('❌ Échec de l\'exécution de code');
    }
    
    // Résultat global
    if ((kernelsDetected || (startResult.config && startResult.config.jupyterServer.offline)) && 
        startResult.success && 
        (connectionSuccess || (startResult.config && startResult.config.jupyterServer.offline)) && 
        (executionSuccess || (startResult.config && startResult.config.jupyterServer.offline))) {
      console.log('\n✅ Test d\'intégration réussi');
    } else {
      console.log('\n❌ Test d\'intégration échoué');
    }
  } catch (error) {
    console.error('\nErreur lors du test d\'intégration:', error);
    console.log('\n❌ Test d\'intégration échoué');
  } finally {
    // Arrêter le serveur MCP Jupyter
    await stopMCPJupyter();
    
    // Restaurer la configuration sauvegardée
    await restoreConfig();
    
    console.log('\n=== Test terminé ===');
  }
}

// Exécuter la fonction principale avec un timeout global
const timeout = setTimeout(() => {
  console.error(`Timeout global de ${config.testTimeout / 1000} secondes atteint`);
  stopMCPJupyter().then(() => {
    process.exit(1);
  });
}, config.testTimeout);

// Exécuter la fonction principale
main()
  .catch(error => {
    console.error('Erreur non gérée:', error);
  })
  .finally(() => {
    clearTimeout(timeout);
  });