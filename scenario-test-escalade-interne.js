/**
 * Scénario de test pour vérifier le mécanisme d'escalade interne
 * 
 * Ce scénario teste le mécanisme d'escalade interne en simulant une tâche
 * qui est à la limite entre simple et complexe, mais qui peut être traitée
 * par le mode simple avec une escalade interne.
 * 
 * Le scénario vérifie que:
 * 1. L'agent détecte correctement la complexité de la tâche
 * 2. L'agent signale correctement l'escalade interne
 * 3. L'agent traite correctement la tâche malgré sa complexité
 * 4. L'agent ajoute le marqueur [SIGNALER_ESCALADE_INTERNE] à la fin
 */

// Configuration du test
const config = {
    mode: 'code-simple',
    task: 'Optimiser la fonction de tri ci-dessous pour améliorer ses performances',
    complexity: 'medium', // À la limite entre simple et complexe
    expectEscalation: true
};

// Fonction à optimiser (exemple de code complexe mais pas trop)
function sortComplexArray(array) {
    // Implémentation naïve d'un tri à bulles
    for (let i = 0; i < array.length; i++) {
        for (let j = 0; j < array.length - i - 1; j++) {
            if (array[j] > array[j + 1]) {
                // Échange des éléments
                const temp = array[j];
                array[j] = array[j + 1];
                array[j + 1] = temp;
            }
        }
    }
    return array;
}

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test du mécanisme d\'escalade interne ===');
    console.log(`Mode: ${config.mode}`);
    console.log(`Tâche: ${config.task}`);
    console.log(`Complexité: ${config.complexity}`);
    console.log(`Escalade attendue: ${config.expectEscalation ? 'Oui' : 'Non'}`);
    
    // Simulation de la réponse de l'agent
    const response = simulateAgentResponse();
    
    // Vérification de l'escalade interne
    const hasEscalationMarker = response.includes('[ESCALADE INTERNE]');
    const hasSignalMarker = response.includes('[SIGNALER_ESCALADE_INTERNE]');
    
    console.log('\n=== Résultats du test ===');
    console.log(`Escalade interne détectée: ${hasEscalationMarker ? 'Oui' : 'Non'}`);
    console.log(`Marqueur de signalement présent: ${hasSignalMarker ? 'Oui' : 'Non'}`);
    
    if (config.expectEscalation) {
        if (hasEscalationMarker && hasSignalMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement effectué une escalade interne');
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent n\'a pas correctement effectué une escalade interne');
            if (!hasEscalationMarker) console.log('   - Marqueur [ESCALADE INTERNE] manquant');
            if (!hasSignalMarker) console.log('   - Marqueur [SIGNALER_ESCALADE_INTERNE] manquant');
        }
    } else {
        if (!hasEscalationMarker && !hasSignalMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement traité la tâche sans escalade');
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent a effectué une escalade interne alors qu\'elle n\'était pas nécessaire');
        }
    }
}

/**
 * Fonction qui simule la réponse de l'agent
 * Dans un environnement réel, cette fonction serait remplacée par
 * la réponse réelle de l'agent Roo
 */
function simulateAgentResponse() {
    // Simulation d'une réponse avec escalade interne
    if (config.expectEscalation) {
        return `
[ESCALADE INTERNE] Cette tâche est traitée en mode avancé car : l'optimisation de l'algorithme de tri nécessite une analyse de complexité et des techniques avancées

Voici une version optimisée de la fonction de tri qui utilise l'algorithme quicksort au lieu du tri à bulles :

\`\`\`javascript
function sortComplexArray(array) {
    // Cas de base
    if (array.length <= 1) {
        return array;
    }
    
    // Choix du pivot (élément du milieu)
    const pivotIndex = Math.floor(array.length / 2);
    const pivot = array[pivotIndex];
    
    // Partitionnement
    const less = [];
    const equal = [];
    const greater = [];
    
    for (let i = 0; i < array.length; i++) {
        if (array[i] < pivot) {
            less.push(array[i]);
        } else if (array[i] > pivot) {
            greater.push(array[i]);
        } else {
            equal.push(array[i]);
        }
    }
    
    // Récursion et combinaison des résultats
    return [...sortComplexArray(less), ...equal, ...sortComplexArray(greater)];
}
\`\`\`

Cette implémentation est beaucoup plus efficace que le tri à bulles initial :
- Complexité moyenne : O(n log n) au lieu de O(n²)
- Utilisation de la récursion et du principe "diviser pour régner"
- Partitionnement autour d'un pivot pour réduire le nombre de comparaisons

L'algorithme quicksort est généralement plus rapide que le tri à bulles pour les grands tableaux, bien que sa complexité dans le pire des cas reste O(n²). Pour une implémentation encore plus robuste, on pourrait utiliser une combinaison de quicksort et d'insertion sort pour les petits sous-tableaux.

[SIGNALER_ESCALADE_INTERNE]
`;
    } else {
        // Simulation d'une réponse sans escalade interne
        return `
Voici une version optimisée de la fonction de tri :

\`\`\`javascript
function sortComplexArray(array) {
    // Utilisation de la méthode de tri native de JavaScript
    return array.sort((a, b) => a - b);
}
\`\`\`

Cette implémentation est beaucoup plus efficace car elle utilise l'algorithme de tri natif de JavaScript, qui est généralement une implémentation optimisée de quicksort ou timsort selon les navigateurs.
`;
    }
}

// Exécution du test
runTest().catch(console.error);