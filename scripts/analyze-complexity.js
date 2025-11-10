#!/usr/bin/env node

/**
 * Script d'analyse de la complexité cyclomatique des méthodes critiques
 * Utilisé pour identifier les méthodes qui dépassent la limite de 20
 */

const fs = require('fs');
const path = require('path');

// Lire le fichier source TypeScript directement
const sourcePath = path.join(__dirname, '../mcps/internal/servers/quickfiles-server/src/index.ts');
const sourceCode = fs.readFileSync(sourcePath, 'utf-8');

const CRITICAL_TOOLS = [
  'handleDeleteFiles',
  'handleEditMultipleFiles',
  'handleExtractMarkdownStructure',
  'handleCopyFiles',
  'handleMoveFiles',
  'handleSearchInFiles',
  'handleSearchAndReplace',
  'handleRestartMcpServers'
];

function extractMethodCode(sourceCode, methodName) {
  // Chercher la définition de la méthode
  const methodRegex = new RegExp(`private\\s+async\\s+${methodName}\\s*\\([^)]*\\)\\s*[:][^{]*\\{([\\s\\S]*?)(?=private\\s+async\\s+\\w+|\\}\\s*$)`, 'g');
  const match = methodRegex.exec(sourceCode);
  
  if (match) {
    return match[1];
  }
  
  // Alternative: chercher sans le type de retour
  const altRegex = new RegExp(`private\\s+async\\s+${methodName}\\s*\\([^)]*\\)\\s*\\{([\\s\\S]*?)(?=private\\s+async\\s+\\w+|\\}\\s*$)`, 'g');
  const altMatch = altRegex.exec(sourceCode);
  
  return altMatch ? altMatch[1] : '';
}

function analyzeComplexity() {
  console.log('Analyse de la complexité cyclomatique des méthodes critiques:\n');
  
  const results = [];
  
  CRITICAL_TOOLS.forEach(toolName => {
    const methodCode = extractMethodCode(sourceCode, toolName);
    
    if (!methodCode) {
      console.log(`${toolName}: Méthode non trouvée`);
      return;
    }
    
    // Compter les branches (if, else, for, while, case, catch, &&, ||)
    const branchCount = (methodCode.match(/\b(if|else|for|while|case|catch)\b|\&\&|\|\|/g) || []).length;
    
    results.push({ toolName, branchCount, methodCode });
    
    console.log(`${toolName}: ${branchCount} branches`);
    
    if (branchCount >= 20) {
      console.log(`  🚨 COMPLEXITÉ ÉLEVÉE DÉTECTÉE!`);
    }
  });
  
  // Trier par complexité décroissante
  results.sort((a, b) => b.branchCount - a.branchCount);
  
  console.log('\n=== RÉSUMÉ ===');
  if (results.length > 0) {
    console.log('Méthode la plus complexe:', results[0].toolName, `(${results[0].branchCount} branches)`);
    
    if (results[0].branchCount >= 20) {
      console.log('\n🚨 MÉTHODE À REFACTORISER:', results[0].toolName);
      console.log(`Complexité actuelle: ${results[0].branchCount} (limite: 20)`);
    }
  }
  
  return results;
}

if (require.main === module) {
  analyzeComplexity();
}

module.exports = { analyzeComplexity };