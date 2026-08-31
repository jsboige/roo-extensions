import fs from 'fs';
import path from 'path';

// Pour tester les fonctions du système, nous devons les copier directement
// car elles sont dans des modules ES

/**
 * Fonction de normalisation des instructions (copiée depuis task-instruction-index.ts)
 */
function computeInstructionPrefix(raw, K = 192) {
    if (!raw) return '';

    // Normalisations robustes avant troncature
    let s = String(raw);

    // 1) Retirer un éventuel BOM UTF-8 en tête
    s = s.replace(/^\uFEFF/, '');

    // 2) Dé-échappements simples courants (contenus provenant de JSON échappé)
    //    Ne pas faire de parsing JSON ici pour rester ultra-robuste
    s = s
        .replace(/\\r\\n/g, '\n')
        .replace(/\\n/g, '\n')
        .replace(/\\t/g, '\t')
        .replace(/\\\\/g, '\\')
        .replace(/\\"/g, '"')
        .replace(/\\'/g, "'");

    // 3) Décodage des entités HTML (nommées + numériques)
    // Ordre important pour éviter double-décodage
    s = s
        .replace(/</gi, '<')
        .replace(/>/gi, '>')
        .replace(/"/gi, '"')
        .replace(/'/gi, "'")
        .replace(/'/gi, "'")
        .replace(/&/gi, '&');

    // Entités numériques décimales
    s = s.replace(/&#(\d+);/g, (_m, d) => {
        const code = parseInt(d, 10);
        return Number.isFinite(code) ? String.fromCharCode(code) : _m;
    });
    // Entités numériques hexadécimales
    s = s.replace(/&#x([0-9a-fA-F]+);/g, (_m, h) => {
        const code = parseInt(h, 16);
        return Number.isFinite(code) ? String.fromCharCode(code) : _m;
    });

    // 4) Nettoyer les restes de JSON du parsing parent (content:", etc.)
    s = s
        .replace(/^["']?content["']?\s*:\s*["']?/i, '')  // Enlever "content": ou 'content': au début
        .replace(/["']$/,'');  // Enlever guillemet final éventuel

    // 5) Supprimer explicitement les balises de délégation fréquemment vues
    //    et les wrappers <task> / <new_task> même non fermés
    s = s
        .replace(/<\s*task\s*>/gi, ' ')
        .replace(/<\s*\/\s*task\s*>/gi, ' ')
        .replace(/<\s*new_task\b[^>]*>/gi, ' ')
        .replace(/<\s*\/\s*new_task\s*>/gi, ' ');

    // 6) Purge générique de toutes les balises HTML/XML restantes
    s = s.replace(/<[^>]+>/g, ' ');

    // 7) Normalisations finales, minuscules + espaces
    s = s
        .toLowerCase()
        .replace(/\s+/g, ' ')
        .trim();

    // 8) Troncature à K
    // ATTENTION: Ne pas faire de trim() après substring() car cela change la longueur !
    // On fait le trim() AVANT pour normaliser, mais pas APRÈS pour préserver K
    const truncated = s.substring(0, K);
    
    // Si le dernier caractère est un espace, on peut le garder ou le supprimer
    // Pour cohérence avec les tests, on le supprime SEULEMENT si c'est le dernier
    return truncated.trimEnd();
}

// Simuler la structure de exact-trie pour le test
class SimpleTrie {
    constructor() {
        this.entries = new Map();
    }
    
    put(key, value) {
        this.entries.set(key, value);
    }
    
    get(key) {
        return this.entries.get(key);
    }
    
    getWithCheckpoints(searchKey) {
        // Pour ce test simple, on cherche une correspondance exacte
        // dans la vraie implémentation, cela ferait du longest prefix match
        return this.entries.get(searchKey);
    }
}

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
const trie = new SimpleTrie();
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