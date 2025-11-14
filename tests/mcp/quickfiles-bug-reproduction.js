// Test de reproduction du bug critique QuickFiles
// Scénario : explosion de fichiers avec répétition infinie

const fs = require('fs');
const path = require('path');

// Créer un environnement de test
const testDir = './test-quickfiles-bug';
if (fs.existsSync(testDir)) {
  fs.rmSync(testDir, { recursive: true, force: true });
}
fs.mkdirSync(testDir, { recursive: true });

// Créer un fichier de test susceptible au bug
const testFile = path.join(testDir, 'test.txt');
const testContent = `function oldFunction() {
  console.log("old function called");
}

// Appel de oldFunction
oldFunction();
`;

fs.writeFileSync(testFile, testContent);

console.log('🧪 Fichier de test créé :', testFile);
console.log('📝 Contenu initial :');
console.log(testContent);

// Scénario qui pourrait déclencher le bug :
// 1. Remplacer "oldFunction" par "oldFunction" (même pattern)
// 2. Avec useRegex=true et un pattern qui pourrait matcher infiniment

const maliciousPattern = 'oldFunction'; // Pattern simple
const replacement = 'oldFunction';     // Remplacement identique

console.log('\n⚠️  SCÉNARIO À RISQUE :');
console.log('Pattern :', maliciousPattern);
console.log('Replacement :', replacement);
console.log('Ce scénario pourrait provoquer une boucle infinie si le code ne vérifie pas les remplacements identiques');

// Export pour utilisation avec QuickFiles
module.exports = {
  testDir,
  testFile,
  testContent,
  maliciousPattern,
  replacement
};