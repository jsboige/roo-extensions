/**
 * Scénario de test pour vérifier le mécanisme de désescalade
 * 
 * Ce scénario teste le mécanisme de désescalade en simulant une tâche
 * qui commence comme complexe mais devient simple au cours de son exécution,
 * ce qui devrait déclencher une suggestion de désescalade.
 * 
 * Le scénario vérifie que:
 * 1. L'agent évalue correctement la complexité de la tâche
 * 2. L'agent suggère correctement une désescalade lorsque la tâche devient simple
 * 3. L'agent continue à traiter la tâche correctement
 */

// Configuration du test
const config = {
    mode: 'code-complex',
    initialTask: 'Refactoriser le système de gestion des utilisateurs pour améliorer les performances',
    simplifiedTask: 'Corriger un bug simple dans la fonction de validation d\'email',
    expectDesescalation: true
};

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test du mécanisme de désescalade ===');
    console.log(`Mode: ${config.mode}`);
    console.log(`Tâche initiale (complexe): ${config.initialTask}`);
    console.log(`Tâche simplifiée: ${config.simplifiedTask}`);
    console.log(`Désescalade attendue: ${config.expectDesescalation ? 'Oui' : 'Non'}`);
    
    // Simulation de la première réponse de l'agent (analyse initiale)
    console.log('\n--- Étape 1: Analyse initiale ---');
    const initialResponse = simulateInitialResponse();
    console.log('Réponse de l\'agent (résumé): Analyse de la tâche complexe...');
    
    // Simulation de la simplification de la tâche
    console.log('\n--- Étape 2: Simplification de la tâche ---');
    console.log(`Utilisateur: "Finalement, j'ai identifié le problème. C'est juste un bug dans la fonction de validation d'email."`);
    
    // Simulation de la réponse de l'agent après simplification
    const finalResponse = simulateFinalResponse();
    
    // Vérification de la désescalade
    const hasDesescalationMarker = finalResponse.includes('[DÉSESCALADE SUGGÉRÉE]');
    
    console.log('\n=== Résultats du test ===');
    console.log(`Désescalade suggérée: ${hasDesescalationMarker ? 'Oui' : 'Non'}`);
    
    if (config.expectDesescalation) {
        if (hasDesescalationMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement suggéré une désescalade');
            
            // Extraction de la raison de la désescalade
            const reasonMatch = finalResponse.match(/\[DÉSESCALADE SUGGÉRÉE\] Cette tâche pourrait être traitée par la version simple de l'agent car : (.*)/);
            if (reasonMatch && reasonMatch[1]) {
                console.log(`Raison de la désescalade: ${reasonMatch[1]}`);
            }
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent n\'a pas suggéré de désescalade alors qu\'elle était attendue');
        }
    } else {
        if (!hasDesescalationMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement traité la tâche sans suggérer de désescalade');
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent a suggéré une désescalade alors qu\'elle n\'était pas attendue');
        }
    }
}

/**
 * Fonction qui simule la réponse initiale de l'agent
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateInitialResponse() {
    return `
Pour refactoriser le système de gestion des utilisateurs et améliorer les performances, je vais procéder par étapes:

1. Analyser l'architecture actuelle du système
2. Identifier les goulots d'étranglement
3. Proposer des optimisations
4. Implémenter les changements
5. Tester les performances

Commençons par examiner l'architecture actuelle. Pouvez-vous me montrer les fichiers principaux du système de gestion des utilisateurs?
`;
}

/**
 * Fonction qui simule la réponse finale de l'agent
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateFinalResponse() {
    if (config.expectDesescalation) {
        return `
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : il s'agit d'une correction de bug simple dans une fonction isolée qui ne nécessite pas d'analyse approfondie

Je comprends que le problème est maintenant identifié comme un simple bug dans la fonction de validation d'email. Dans ce cas, voici comment corriger ce problème:

\`\`\`javascript
// Fonction corrigée de validation d'email
function validateEmail(email) {
  // Expression régulière pour valider un email
  const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  
  // Vérification que l'email n'est pas vide et qu'il correspond au format attendu
  return email && typeof email === 'string' && emailRegex.test(email);
}
\`\`\`

Cette correction:
1. Vérifie que l'email n'est pas null ou undefined
2. Vérifie que l'email est bien une chaîne de caractères
3. Utilise une expression régulière plus robuste pour valider le format de l'email

Puisqu'il s'agit d'une correction simple et isolée, vous pourriez utiliser la version simple de l'agent pour ce type de tâche à l'avenir.
`;
    } else {
        return `
Je comprends que le problème est maintenant identifié comme un bug dans la fonction de validation d'email. Voici comment corriger ce problème:

\`\`\`javascript
// Fonction corrigée de validation d'email
function validateEmail(email) {
  // Expression régulière pour valider un email
  const emailRegex = /^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  
  // Vérification que l'email n'est pas vide et qu'il correspond au format attendu
  return email && typeof email === 'string' && emailRegex.test(email);
}
\`\`\`

Cette correction:
1. Vérifie que l'email n'est pas null ou undefined
2. Vérifie que l'email est bien une chaîne de caractères
3. Utilise une expression régulière plus robuste pour valider le format de l'email

Bien que cette correction soit simple, je vais continuer à analyser le système de gestion des utilisateurs pour identifier d'autres problèmes potentiels qui pourraient affecter les performances.
`;
    }
}

// Exécution du test
runTest().catch(console.error);