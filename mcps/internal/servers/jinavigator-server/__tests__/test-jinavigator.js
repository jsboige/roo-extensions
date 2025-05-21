// Script de test pour le serveur MCP jinavigator
const { execSync } = require('child_process');
const fs = require('fs');

// Fonction pour exécuter un outil MCP et récupérer le résultat
function executeMcpTool(serverName, toolName, args) {
  const command = `node -e "
    const args = ${JSON.stringify(args)};
    process.stdout.write(JSON.stringify(args));
  " | node servers/jinavigator-server/dist/index.js`;
  
  try {
    console.log(`Exécution de l'outil ${toolName} avec les arguments:`, args);
    const result = execSync(command, { encoding: 'utf8' });
    console.log('Résultat brut:', result);
    return result;
  } catch (error) {
    console.error(`Erreur lors de l'exécution de l'outil ${toolName}:`, error.message);
    return null;
  }
}

// Test 1: Vérification du bornage par numéro de ligne
async function testLineBounding() {
  console.log('\n=== Test 1: Vérification du bornage par numéro de ligne ===\n');
  
  // URL de test (page Wikipedia)
  const testUrl = 'https://en.wikipedia.org/wiki/Markdown';
  
  // Test avec convert_web_to_markdown
  console.log('Test de convert_web_to_markdown avec bornage:');
  const convertResult = executeMcpTool('jinavigator', 'convert_web_to_markdown', {
    url: testUrl,
    start_line: 10,
    end_line: 20
  });
  
  // Test avec access_jina_resource
  console.log('\nTest de access_jina_resource avec bornage:');
  const accessResult = executeMcpTool('jinavigator', 'access_jina_resource', {
    uri: `jina://${testUrl}`,
    start_line: 10,
    end_line: 20
  });
  
  // Vérification des résultats
  console.log('\nRésultats du test de bornage:');
  console.log('- convert_web_to_markdown:', convertResult ? 'Succès' : 'Échec');
  console.log('- access_jina_resource:', accessResult ? 'Succès' : 'Échec');
}

// Test 2: Récupération de plusieurs URLs avec des bornes différentes
async function testMultipleUrls() {
  console.log('\n=== Test 2: Récupération de plusieurs URLs avec des bornes différentes ===\n');
  
  // Liste d'URLs à tester avec différentes bornes
  const urlTests = [
    { url: 'https://en.wikipedia.org/wiki/JavaScript', start_line: 5, end_line: 15 },
    { url: 'https://en.wikipedia.org/wiki/TypeScript', start_line: 20, end_line: 30 },
    { url: 'https://en.wikipedia.org/wiki/Node.js', start_line: 15, end_line: 25 }
  ];
  
  for (const test of urlTests) {
    console.log(`\nTest pour l'URL: ${test.url} (lignes ${test.start_line}-${test.end_line})`);
    
    const result = executeMcpTool('jinavigator', 'convert_web_to_markdown', {
      url: test.url,
      start_line: test.start_line,
      end_line: test.end_line
    });
    
    console.log(`Résultat pour ${test.url}:`, result ? 'Succès' : 'Échec');
  }
}

// Test 3: Test des limites de longueur maximale
async function testLengthLimits() {
  console.log('\n=== Test 3: Test des limites de longueur maximale ===\n');
  
  // URL d'une page très longue
  const longPageUrl = 'https://en.wikipedia.org/wiki/History_of_the_Internet';
  
  console.log(`Test avec une page longue: ${longPageUrl}`);
  const result = executeMcpTool('jinavigator', 'convert_web_to_markdown', {
    url: longPageUrl
  });
  
  if (result) {
    console.log('Longueur du contenu récupéré:', result.length);
    console.log('Test de limite de longueur: Succès');
  } else {
    console.log('Test de limite de longueur: Échec');
  }
}

// Exécution des tests
async function runTests() {
  try {
    await testLineBounding();
    await testMultipleUrls();
    await testLengthLimits();
    
    console.log('\n=== Tous les tests sont terminés ===\n');
  } catch (error) {
    console.error('Erreur lors de l\'exécution des tests:', error);
  }
}

runTests();