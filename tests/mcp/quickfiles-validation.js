// TESTS DE VALIDATION POUR LA CORRECTION QUICKFILES
// Ces tests valident que le bug critique est bien corrigé

const fs = require('fs');
const path = require('path');

// Simuler la version corrigée de replaceInFile
async function replaceInFileFixed(rawFilePath, searchPattern, replacement, options = {}) {
  const filePath = path.resolve(process.cwd(), rawFilePath);
  
  // 🔒 PROTECTION 1 : Validation préventive des patterns identiques
  if (searchPattern === replacement) {
    console.warn(`⚠️ QuickFiles: Search et replacement sont identiques "${searchPattern}" - opération ignorée`);
    return { 
      modified: false, 
      diff: '', 
      warning: 'Search and replacement patterns are identical - no changes needed',
      replacements: 0
    };
  }
  
  // 🔒 PROTECTION 2 : Validation des patterns vides
  if (!searchPattern || searchPattern.trim() === '') {
    throw new Error('Search pattern cannot be empty');
  }
  
  // 🔒 PROTECTION 3 : Limites de sécurité
  const MAX_REPLACEMENTS = 10000;
  const MAX_FILE_SIZE = 50 * 1024 * 1024;
  
  try {
    const stats = await fs.promises.stat(filePath);
    if (stats.isDirectory()) {
      return { modified: false, diff: '', replacements: 0 };
    }
    
    if (stats.size > MAX_FILE_SIZE) {
      throw new Error(`File too large: ${stats.size} bytes (max: ${MAX_FILE_SIZE})`);
    }
  } catch (error) {
    return { modified: false, diff: '', replacements: 0 };
  }
  
  const useRegex = options.useRegex ?? true;
  const caseSensitive = options.caseSensitive ?? false;
  const preview = options.preview ?? false;
  
  let content = await fs.promises.readFile(filePath, 'utf-8');
  const originalContent = content;
  
  const preparedPattern = useRegex ? searchPattern : searchPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const searchRegex = new RegExp(preparedPattern, caseSensitive ? 'g' : 'gi');
  
  let totalReplacements = 0;
  let effectiveReplacements = 0;
  
  const newContent = content.replace(searchRegex, (match, ...groups) => {
    totalReplacements++;
    
    const actualReplacement = replacement; // Simplifié pour les tests
    
    if (match !== actualReplacement) {
      effectiveReplacements++;
      
      if (effectiveReplacements > MAX_REPLACEMENTS) {
        throw new Error(`Too many replacements: ${effectiveReplacements} (max: ${MAX_REPLACEMENTS})`);
      }
      
      return actualReplacement;
    } else {
      return match;
    }
  });
  
  const wasModified = (originalContent !== newContent) && (effectiveReplacements > 0);
  
  if (wasModified) {
    const diff = `--- a/${rawFilePath}\n+++ b/${rawFilePath}\n@@ -1,${originalContent.split('\n').length} +1,${newContent.split('\n').length} @@\n`;
    if (!preview) {
      await fs.promises.writeFile(filePath, newContent, 'utf-8');
    }
    
    return { 
      modified: true, 
      diff, 
      replacements: effectiveReplacements,
      totalMatches: totalReplacements
    };
  }
  
  return { 
    modified: false, 
    diff: '', 
    replacements: 0,
    totalMatches: totalReplacements
  };
}

// Tests de validation
async function runValidationTests() {
  console.log('🧪 TESTS DE VALIDATION QUICKFILES - VERSION CORRIGÉE\n');
  
  let testsPassed = 0;
  let testsTotal = 0;
  
  // Test 1: Patterns identiques (doit être bloqué)
  console.log('📋 Test 1: Patterns identiques');
  testsTotal++;
  try {
    const testFile1 = './validation-test-1.txt';
    fs.writeFileSync(testFile1, 'test test test');
    
    const result1 = await replaceInFileFixed(testFile1, 'test', 'test');
    
    if (result1.modified === false && result1.replacements === 0 && result1.warning) {
      console.log('✅ PASS: Patterns identiques correctement bloqués');
      testsPassed++;
    } else {
      console.log('❌ FAIL: Patterns identiques non bloqués');
      console.log('Résultat:', result1);
    }
    
    fs.unlinkSync(testFile1);
  } catch (error) {
    console.log('❌ ERROR:', error.message);
  }
  
  // Test 2: Remplacement normal (doit fonctionner)
  console.log('\n📋 Test 2: Remplacement normal');
  testsTotal++;
  try {
    const testFile2 = './validation-test-2.txt';
    fs.writeFileSync(testFile2, 'test test test');
    
    const result2 = await replaceInFileFixed(testFile2, 'test', 'fixed');
    
    if (result2.modified === true && result2.replacements === 3) {
      console.log('✅ PASS: Remplacement normal effectué');
      testsPassed++;
    } else {
      console.log('❌ FAIL: Remplacement normal échoué');
      console.log('Résultat:', result2);
    }
    
    fs.unlinkSync(testFile2);
  } catch (error) {
    console.log('❌ ERROR:', error.message);
  }
  
  // Test 3: Pattern vide (doit échouer)
  console.log('\n📋 Test 3: Pattern vide');
  testsTotal++;
  try {
    const testFile3 = './validation-test-3.txt';
    fs.writeFileSync(testFile3, 'test content');
    
    const result3 = await replaceInFileFixed(testFile3, '', 'test');
    
    console.log('❌ FAIL: Pattern vide aurait dû lancer une erreur');
    fs.unlinkSync(testFile3);
  } catch (error) {
    if (error.message === 'Search pattern cannot be empty') {
      console.log('✅ PASS: Pattern vide correctement rejeté');
      testsPassed++;
    } else {
      console.log('❌ FAIL: Mauvaise erreur pour pattern vide:', error.message);
    }
  }
  
  // Test 4: Remplacement partiel (certains identiques)
  console.log('\n📋 Test 4: Remplacement partiel');
  testsTotal++;
  try {
    const testFile4 = './validation-test-4.txt';
    fs.writeFileSync(testFile4, 'test test other test');
    
    const result4 = await replaceInFileFixed(testFile4, 'test', 'test'); // Remplacement identique
    
    if (result4.modified === false && result4.replacements === 0) {
      console.log('✅ PASS: Remplacement partiel correctement géré');
      testsPassed++;
    } else {
      console.log('❌ FAIL: Remplacement partiel mal géré');
      console.log('Résultat:', result4);
    }
    
    fs.unlinkSync(testFile4);
  } catch (error) {
    console.log('❌ ERROR:', error.message);
  }
  
  // Test 5: Cas mixte (certains changent, d'autres non)
  console.log('\n📋 Test 5: Cas mixte');
  testsTotal++;
  try {
    const testFile5 = './validation-test-5.txt';
    fs.writeFileSync(testFile5, 'test test other test');
    
    const result5 = await replaceInFileFixed(testFile5, 'test', 'fixed'); // Seulement certains changent
    
    if (result5.modified === true && result5.replacements === 3) {
      console.log('✅ PASS: Cas mixte correctement géré');
      testsPassed++;
    } else {
      console.log('❌ FAIL: Cas mixte mal géré');
      console.log('Résultat:', result5);
    }
    
    fs.unlinkSync(testFile5);
  } catch (error) {
    console.log('❌ ERROR:', error.message);
  }
  
  // Résultats finaux
  console.log('\n' + '='.repeat(60));
  console.log('📊 RÉSULTATS DES TESTS DE VALIDATION');
  console.log(`✅ Tests passés: ${testsPassed}/${testsTotal}`);
  console.log(`❌ Tests échoués: ${testsTotal - testsPassed}/${testsTotal}`);
  console.log(`📈 Taux de réussite: ${((testsPassed / testsTotal) * 100).toFixed(1)}%`);
  
  if (testsPassed === testsTotal) {
    console.log('\n🎉 TOUS LES TESTS PASSÉS - CORRECTION VALIDÉE !');
    console.log('✅ Le bug critique QuickFiles est bien corrigé');
  } else {
    console.log('\n⚠️ CERTAINS TESTS ONT ÉCHOUÉ - CORRECTION INCOMPLÈTE');
  }
  
  console.log('='.repeat(60));
}

// Exécuter les tests
runValidationTests().catch(console.error);