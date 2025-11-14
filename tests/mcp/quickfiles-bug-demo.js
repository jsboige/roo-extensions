// Démonstration du bug critique QuickFiles
// Ce test montre comment le remplacement identique peut causer des problèmes

const { QuickFilesServer } = require('./mcps/internal/servers/quickfiles-server/src/index.ts');

async function demonstrateBug() {
  console.log('🚨 DÉMONSTRATION DU BUG CRITIQUE QUICKFILES 🚨\n');
  
  // Créer un fichier de test
  const fs = require('fs');
  const path = require('path');
  
  const testFile = './bug-demo.txt';
  const content = `test test test test test`;
  fs.writeFileSync(testFile, content);
  
  console.log('📁 Fichier créé :', testFile);
  console.log('📝 Contenu initial :', content);
  console.log('🔢 Nombre de "test" dans le contenu :', (content.match(/test/g) || []).length);
  
  // Simuler le comportement de replaceInFile avec un remplacement identique
  const searchPattern = 'test';
  const replacement = 'test'; // IDENTIQUE !
  const useRegex = false;
  const caseSensitive = false;
  
  console.log('\n⚠️  SCÉNARIO DANGEREUX :');
  console.log('Search pattern :', searchPattern);
  console.log('Replacement :', replacement);
  console.log('Use regex :', useRegex);
  console.log('Case sensitive :', caseSensitive);
  
  // Simuler la logique actuelle de QuickFiles
  const preparedPattern = useRegex ? searchPattern : searchPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const searchRegex = new RegExp(preparedPattern, caseSensitive ? 'g' : 'gi');
  
  let totalReplacements = 0;
  const newContent = content.replace(searchRegex, (match, ...groups) => {
    totalReplacements++;
    console.log(`💥 Remplacement #${totalReplacements}: "${match}" -> "${replacement}"`);
    return replacement; // Toujours identique !
  });
  
  console.log('\n📊 RÉSULTATS :');
  console.log('Total replacements comptées :', totalReplacements);
  console.log('Contenu modifié :', newContent);
  console.log('Contenu identique ? :', content === newContent);
  console.log('Fichier réellement modifié ? :', content !== newContent);
  
  if (content === newContent && totalReplacements > 0) {
    console.log('\n🚨 BUG CONFIRMÉ !');
    console.log('❌ Le code compte des remplacements mais ne modifie rien');
    console.log('❌ Ceci peut provoquer des boucles infinies dans certains cas');
    console.log('❌ Risque de corruption massive des fichiers');
  }
  
  // Nettoyer
  fs.unlinkSync(testFile);
  console.log('\n🧹 Fichier de test nettoyé');
}

demonstrateBug().catch(console.error);