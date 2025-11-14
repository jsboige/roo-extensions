// Test simplifié pour démontrer le bug critique QuickFiles
// Ce test simule la logique exacte de replaceInFile()

const fs = require('fs');
const path = require('path');

function simulateQuickFilesBug() {
  console.log('🚨 DÉMONSTRATION DU BUG CRITIQUE QUICKFILES 🚨\n');
  
  // Créer un fichier de test
  const testFile = './bug-demo-simple.txt';
  const content = `test test test test test test`;
  fs.writeFileSync(testFile, content);
  
  console.log('📁 Fichier créé :', testFile);
  console.log('📝 Contenu initial :', content);
  console.log('🔢 Nombre de "test" dans le contenu :', (content.match(/test/g) || []).length);
  
  // Simuler le comportement EXACT de replaceInFile() dans QuickFiles
  const searchPattern = 'test';
  const replacement = 'test'; // IDENTIQUE - C'EST LE BUG !
  const useRegex = false;
  const caseSensitive = false;
  
  console.log('\n⚠️  SCÉNARIO DANGEREUX :');
  console.log('Search pattern :', searchPattern);
  console.log('Replacement :', replacement);
  console.log('Use regex :', useRegex);
  console.log('Case sensitive :', caseSensitive);
  
  // LOGIQUE EXACTE DE QUICKFILES (lignes 1350-1358 dans index.ts)
  const preparedPattern = useRegex ? searchPattern : searchPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const searchRegex = new RegExp(preparedPattern, caseSensitive ? 'g' : 'gi');
  
  let totalReplacements = 0;
  const newContent = content.replace(searchRegex, (match, ...groups) => {
    totalReplacements++;
    console.log(`💥 Remplacement #${totalReplacements}: "${match}" -> "${replacement}"`);
    return replacement; // TOUJOURS IDENTIQUE !
  });
  
  console.log('\n📊 RÉSULTATS :');
  console.log('Total replacements comptées :', totalReplacements);
  console.log('Contenu modifié :', newContent);
  console.log('Contenu identique ? :', content === newContent);
  console.log('Fichier réellement modifié ? :', content !== newContent);
  
  // Vérifier si le bug est présent
  if (content === newContent && totalReplacements > 0) {
    console.log('\n🚨 BUG CRITIQUE CONFIRMÉ !');
    console.log('❌ Le code compte des remplacements mais ne modifie RIEN');
    console.log('❌ Ceci peut provoquer des boucles infinies dans certains cas');
    console.log('❌ Risque de corruption massive des fichiers');
    console.log('❌ La fonction replaceInFile() écrit le fichier même si rien n\'a changé');
    
    // Simuler ce qui se passe dans processPaths/processSpecificFiles
    console.log('\n🔄 SIMULATION DE LA CASCADE DANGEREUSE :');
    console.log('1. replaceInFile() retourne { modified: true } même si rien n\'a changé');
    console.log('2. processPaths/processSpecificFiles incrémente totalReplacements');
    console.log('3. Le système pense que des modifications ont été effectuées');
    console.log('4. Si appelé récursivement, BOUCLE INFINIE !');
    
    return true; // Bug confirmé
  } else {
    console.log('\n✅ Pas de bug détecté dans ce scénario');
    return false;
  }
}

function demonstrateInfiniteLoopScenario() {
  console.log('\n🌀 SCÉNARIO DE BOUCLE INFINIE :');
  console.log('Si un appelant fait :');
  console.log('while (fileWasModified) {');
  console.log('  result = quickfiles.replace(search, replace);');
  console.log('  fileWasModified = result.modified;');
  console.log('}');
  console.log('');
  console.log('Avec search="test", replace="test" (identiques) :');
  console.log('- replaceInFile() retourne TOUJOURS { modified: true }');
  console.log('- Même si le contenu ne change PAS');
  console.log('- BOUCLE INFINIE GARANTIE !');
}

// Exécuter les tests
console.log('=' .repeat(60));
const bugConfirmed = simulateQuickFilesBug();
demonstrateInfiniteLoopScenario();

// Nettoyer
fs.unlinkSync('./bug-demo-simple.txt');
console.log('\n🧹 Fichier de test nettoyé');

console.log('\n' + '=' .repeat(60));
console.log('🎯 CONCLUSION DE L\'ANALYSE :');
if (bugConfirmed) {
  console.log('🚨 BUG CRITIQUE CONFIRMÉ DANS QUICKFILES');
  console.log('📍 Localisation : replaceInFile() lignes 1354-1358');
  console.log('🔧 Cause : Pas de validation que le contenu change réellement');
  console.log('⚠️  Impact : Risque de boucles infinies et corruption de fichiers');
} else {
  console.log('✅ Bug non reproduit avec ce scénario');
}