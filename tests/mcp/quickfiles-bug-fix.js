// SOLUTION CORRECTIVE POUR LE BUG CRITIQUE QUICKFILES
// Ce fichier contient la version corrigée de replaceInFile()

/**
 * VERSION CORRIGÉE - replaceInFile avec protections anti-bug
 * 
 * Corrections apportées :
 * 1. Validation préventive search !== replace
 * 2. Comptage correct des remplacements EFFECTIFS
 * 3. Limites de sécurité anti-boucle infinie
 * 4. Logs détaillés pour debugging
 * 5. Gestion robuste des cas edge
 */
async function replaceInFileFixed(
  rawFilePath,
  searchPattern,
  replacement,
  options = {}
) {
  const fs = require('fs').promises;
  const path = require('path');
  
  // 🔒 PROTECTION 1 : Validation préventive
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
  const MAX_REPLACEMENTS = 10000; // Protection anti-boucle infinie
  const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB max
  
  const filePath = path.resolve(process.cwd(), rawFilePath);
  
  try {
    // Vérifier si c'est un répertoire
    const stats = await fs.stat(filePath);
    if (stats.isDirectory()) {
      return { modified: false, diff: '', replacements: 0 };
    }
    
    // 🔒 PROTECTION 4 : Taille de fichier maximale
    if (stats.size > MAX_FILE_SIZE) {
      throw new Error(`File too large: ${stats.size} bytes (max: ${MAX_FILE_SIZE})`);
    }
  } catch (error) {
    return { modified: false, diff: '', replacements: 0 };
  }
  
  const useRegex = options.useRegex ?? true;
  const caseSensitive = options.caseSensitive ?? false;
  const preview = options.preview ?? false;
  
  let content = await fs.readFile(filePath, 'utf-8');
  const originalContent = content;
  
  // Préparer le pattern de recherche
  const preparedPattern = useRegex ? searchPattern : searchPattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const searchRegex = new RegExp(preparedPattern, caseSensitive ? 'g' : 'gi');
  
  let totalReplacements = 0;
  let effectiveReplacements = 0; // 🎯 CORRECTION : Comptage EFFECTIF
  
  // 🔒 PROTECTION 5 : Remplacement avec comptage correct
  const newContent = content.replace(searchRegex, (match, ...groups) => {
    totalReplacements++;
    
    // 🎯 CORRECTION : Vérifier si le remplacement change réellement
    const actualReplacement = applyCaptureGroups(replacement, groups, useRegex);
    
    if (match !== actualReplacement) {
      effectiveReplacements++;
      
      // 🔒 PROTECTION 6 : Limite anti-boucle
      if (effectiveReplacements > MAX_REPLACEMENTS) {
        console.warn(`⚠️ QuickFiles: Trop de remplacements (${effectiveReplacements}) - arrêt forcé`);
        throw new Error(`Too many replacements: ${effectiveReplacements} (max: ${MAX_REPLACEMENTS})`);
      }
      
      return actualReplacement;
    } else {
      // Le remplacement est identique - ne pas compter
      return match;
    }
  });
  
  // 🎯 CORRECTION : Vérification basée sur les remplacements EFFECTIFS
  const wasModified = (originalContent !== newContent) && (effectiveReplacements > 0);
  
  if (wasModified) {
    const diff = generateDiff(originalContent, newContent, rawFilePath) + '\n';
    if (!preview) {
      await fs.writeFile(filePath, newContent, 'utf-8');
    }
    
    console.log(`✅ QuickFiles: ${effectiveReplacements} remplacements effectifs dans ${rawFilePath}`);
    
    return { 
      modified: true, 
      diff, 
      replacements: effectiveReplacements,
      totalMatches: totalReplacements
    };
  }
  
  console.log(`ℹ️ QuickFiles: Aucune modification nécessaire dans ${rawFilePath}`);
  return { 
    modified: false, 
    diff: '', 
    replacements: 0,
    totalMatches: totalReplacements
  };
}

// Fonctions utilitaires (versions simplifiées)
function applyCaptureGroups(replacement, groups, useRegex) {
  if (!useRegex || groups.length === 0) {
    return replacement;
  }
  
  let result = replacement;
  for (let i = 0; i < groups.length - 2; i++) {
    result = result.replace(new RegExp(`\\$${i + 1}`, 'g'), groups[i] || '');
  }
  return result;
}

function generateDiff(oldContent, newContent, filePath) {
  return `--- a/${filePath}\n+++ b/${filePath}\n@@ -1,${oldContent.split('\n').length} +1,${newContent.split('\n').length} @@\n`;
}

// Test de la version corrigée
async function testFixedVersion() {
  console.log('🧪 TEST DE LA VERSION CORRIGÉE\n');
  
  const fs = require('fs');
  const testFile = './test-fixed.txt';
  
  // Test 1: Remplacement identique (doit être bloqué)
  console.log('📋 Test 1: Remplacement identique');
  fs.writeFileSync(testFile, 'test test test');
  
  const result1 = await replaceInFileFixed(testFile, 'test', 'test');
  console.log('Résultat:', result1);
  console.log('✅ Attendu: modified=false, replacements=0\n');
  
  // Test 2: Remplacement normal (doit fonctionner)
  console.log('📋 Test 2: Remplacement normal');
  const result2 = await replaceInFileFixed(testFile, 'test', 'fixed');
  console.log('Résultat:', result2);
  console.log('✅ Attendu: modified=true, replacements=3\n');
  
  // Test 3: Pattern vide (doit échouer)
  console.log('📋 Test 3: Pattern vide');
  try {
    const result3 = await replaceInFileFixed(testFile, '', 'test');
    console.log('❌ Échec: aurait dû lancer une erreur');
  } catch (error) {
    console.log('✅ Succès: erreur correctement lancée:', error.message);
  }
  
  // Nettoyer
  fs.unlinkSync(testFile);
  console.log('🧹 Test terminé');
}

// Exporter pour utilisation
module.exports = {
  replaceInFileFixed,
  testFixedVersion
};

// Exécuter le test si appelé directement
if (require.main === module) {
  testFixedVersion().catch(console.error);
}