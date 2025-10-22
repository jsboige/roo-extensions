const fs = require('fs');
const path = require('path');

// Importer les fonctions nécessaires
const { computeInstructionPrefix } = require('../mcps/internal/servers/roo-state-manager/src/utils/task-instruction-index.js');
const Trie = require('exact-trie');

console.log('🔍 DÉBUT DEBUG MATCHING HIERARCHIQUE');
console.log('');

// Instructions des deux tâches
const parentInstruction = "Bonjour,\n\n**Mission :**\nValider à nouveau le fonctionnement complet du serveur `github-projects-mcp` après la recompilation.\n\n**Contexte :**\nLe code a été refactorisé pour initialiser le client...";
const childInstruction = "Bonjour. Nous sommes à la dernière étape de la résolution d'un problème critique de stabilité de l'extension Roo. Après une refactorisation majeure, votre mission est de valider que la solution est efficace et que le problème originel est bien corrigé.";

console.log('📋 INSTRUCTIONS ORIGINALES:');
console.log('Parent (cb7e564f):', parentInstruction.substring(0, 100) + '...');
console.log('Enfant (18141742):', childInstruction.substring(0, 100) + '...');
console.log('');

// Normaliser les préfixes avec la même fonction que le système
const parentPrefix = computeInstructionPrefix(parentInstruction, 192);
const childPrefix = computeInstructionPrefix(childInstruction, 192);

console.log('🔄 PRÉFIXES NORMALISÉS (K=192):');
console.log('Parent:', `"${parentPrefix}"`);
console.log('Enfant:', `"${childPrefix}"`);
console.log('');

// Vérifier si l'enfant commence par le préfixe du parent
const startsWithMatch = childInstruction.toLowerCase().startsWith(parentPrefix.toLowerCase());
const includesMatch = childInstruction.toLowerCase().includes(parentPrefix.toLowerCase().substring(0, 20)); // 20 premiers chars

console.log('🔍 ANALYSE MATCHING:');
console.log('Enfant commence par préfixe parent?', startsWithMatch);
console.log('Enfant contient 20 premiers chars du parent?', includesMatch);
console.log('');

// Créer un trie pour tester la recherche exacte
const trie = new Trie();
const prefixToEntry = new Map();

// Ajouter le préfixe parent à l'index
const entry = { parentTaskIds: ['cb7e564f'], instructions: [{ mode: 'debug', message: parentInstruction, timestamp: Date.now() }] };
prefixToEntry.set(parentPrefix, entry);
trie.put(parentPrefix, entry);

console.log('🏗️ INDEX CRÉÉ AVEC PARENT:');
console.log('  - Préfixe indexé:', `"${parentPrefix}"`);
console.log('  - Tâche parente:', 'cb7e564f');
console.log('');

// Rechercher avec la méthode longest prefix match
const searchPrefix = computeInstructionPrefix(childInstruction, 192);
console.log('🔍 RECHERCHE AVEC ENFANT:');
console.log('  - Préfixe recherché:', `"${searchPrefix}"`);
console.log('');

// Méthode 1: getWithCheckpoints (comme dans le code réel)
const checkpointResult = trie.getWithCheckpoints(searchPrefix);
console.log('🎯 RÉSULTAT getWithCheckpoints():');
if (checkpointResult) {
    console.log('  - Trouvé:', 'OUI');
    console.log('  - Tâches parentes:', checkpointResult.parentTaskIds);
} else {
    console.log('  - Trouvé:', 'NON');
}

// Méthode 2: get exact
const exactResult = trie.get(searchPrefix);
console.log('🎯 RÉSULTAT get() exact:');
if (exactResult) {
    console.log('  - Trouvé:', 'OUI');
    console.log('  - Tâches parentes:', exactResult.parentTaskIds);
} else {
    console.log('  - Trouvé:', 'NON');
}

// Méthode 3: Comparaison directe des préfixes
const directMatch = searchPrefix.startsWith(parentPrefix) || parentPrefix.startsWith(searchPrefix);
console.log('🎯 COMPARAISON DIRECTE DES PRÉFIXES:');
console.log('  - Les préfixes se correspondent?', directMatch);

console.log('');
console.log('❌ CONCLUSION: Aucun matching n\'est possible car les instructions sont fondamentalement différentes');
console.log('   - Parent: "Bonjour," + "Mission: Valider..."');
console.log('   - Enfant: "Bonjour." + "Nous sommes à la dernière étape..."');
console.log('   - Ce sont des instructions différentes, pas une relation parent-enfant directe via contenu');
console.log('');
console.log('💡 SOLUTION: Le système doit détecter la relation via l\'appel newTask dans les ui_messages.json');
console.log('   du parent, pas par similarité de contenu entre les instructions.');

// Test de la vraie méthode d'extraction
console.log('');
console.log('🔧 TEST MÉTHODE D\'EXTRACTION DE SOUS-TÂCHES:');
console.log('Normalement, le parent devrait contenir un appel newTask avec l\'instruction de l\'enfant');
console.log('Cela devrait être extrait via extractSubtaskInstructions() et indexé séparément');