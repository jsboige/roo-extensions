const { execSync } = require('child_process');

console.log('=== Diagnostic des variables d\'environnement RooSync ===\n');

const requiredVars = [
  'ROOSYNC_SHARED_PATH',
  'ROOSYNC_MACHINE_ID', 
  'ROOSYNC_AUTO_SYNC',
  'ROOSYNC_CONFLICT_STRATEGY',
  'ROOSYNC_LOG_LEVEL'
];

console.log('Variables d\'environnement requises:');
requiredVars.forEach(varName => {
  const value = process.env[varName];
  console.log(`  ${varName}: ${value ? '✓' : '✗'} ${value || 'NON DÉFINIE'}`);
});

console.log('\n=== Variables d\'environnement PowerShell ===');
try {
  const powershellOutput = execSync('powershell -c "Get-ChildItem Env: | Where-Object { $_.Name -like \\"*ROOSYNC*\\" } | Select-Object Name,Value | ConvertTo-Json"', { encoding: 'utf8' });
  console.log(powershellOutput);
} catch (error) {
  console.log('Erreur lors de la lecture des variables PowerShell:', error.message);
}

console.log('\n=== Test de chargement de la configuration RooSync ===');
try {
  // Simuler le chargement comme dans le serveur MCP
  const configPath = './mcps/internal/servers/roo-state-manager/dist/config/roosync-config.js';
  console.log('Tentative de chargement de:', configPath);
  
  // Vérifier si le fichier existe
  const fs = require('fs');
  if (fs.existsSync(configPath)) {
    console.log('✓ Fichier de configuration trouvé');
    const { loadRooSyncConfig } = require(configPath);
    const config = loadRooSyncConfig();
    console.log('✓ Configuration chargée avec succès:', JSON.stringify(config, null, 2));
  } else {
    console.log('✗ Fichier de configuration non trouvé');
  }
} catch (error) {
  console.log('✗ Erreur lors du chargement:', error.message);
  console.log('Stack:', error.stack);
}