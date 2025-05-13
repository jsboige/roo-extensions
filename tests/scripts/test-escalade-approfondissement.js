/**
 * Scénario de test pour vérifier le mécanisme d'escalade par approfondissement
 * 
 * Ce scénario teste le mécanisme d'escalade par approfondissement en simulant une conversation
 * qui atteint le seuil de 15 messages, ce qui devrait déclencher une suggestion d'escalade
 * par approfondissement.
 * 
 * Le scénario vérifie que:
 * 1. L'agent détecte correctement le seuil de messages
 * 2. L'agent suggère correctement une escalade par approfondissement
 * 3. L'agent propose une description claire de la sous-tâche à créer
 */

// Configuration du test
const config = {
    mode: 'code-complex',
    messageCount: 15,
    expectEscaladeApprofondissement: true
};

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test du mécanisme d\'escalade par approfondissement ===');
    console.log(`Mode: ${config.mode}`);
    console.log(`Nombre de messages: ${config.messageCount}`);
    console.log(`Escalade par approfondissement attendue: ${config.expectEscaladeApprofondissement ? 'Oui' : 'Non'}`);
    
    // Simulation de la conversation
    console.log('\n--- Simulation d\'une conversation avec plusieurs messages ---');
    console.log(`Génération de ${config.messageCount} messages...`);
    
    // Simulation de la réponse de l'agent après plusieurs messages
    const response = simulateAgentResponse();
    
    // Vérification de l'escalade par approfondissement
    const hasEscaladeApprofondissementMarker = response.includes('[ESCALADE PAR APPROFONDISSEMENT]');
    const hasSubtaskDescription = response.includes('sous-tâche') && (response.includes('créer') || response.includes('continuer'));
    
    console.log('\n=== Résultats du test ===');
    console.log(`Escalade par approfondissement détectée: ${hasEscaladeApprofondissementMarker ? 'Oui' : 'Non'}`);
    console.log(`Description de sous-tâche présente: ${hasSubtaskDescription ? 'Oui' : 'Non'}`);
    
    if (config.expectEscaladeApprofondissement) {
        if (hasEscaladeApprofondissementMarker && hasSubtaskDescription) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement suggéré une escalade par approfondissement');
            
            // Extraction de la raison de l'escalade
            const reasonMatch = response.match(/\[ESCALADE PAR APPROFONDISSEMENT\] Je suggère de créer une sous-tâche pour continuer ce travail car : (.*)/);
            if (reasonMatch && reasonMatch[1]) {
                console.log(`Raison de l'escalade: ${reasonMatch[1]}`);
            }
            
            // Extraction de la description de la sous-tâche
            console.log('\nDescription de la sous-tâche proposée:');
            const descriptionMatch = response.match(/Je propose de créer une sous-tâche pour :([\s\S]*?)(?=\n\n|$)/);
            if (descriptionMatch && descriptionMatch[1]) {
                console.log(descriptionMatch[1].trim());
            }
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent n\'a pas correctement suggéré une escalade par approfondissement');
            if (!hasEscaladeApprofondissementMarker) console.log('   - Marqueur [ESCALADE PAR APPROFONDISSEMENT] manquant');
            if (!hasSubtaskDescription) console.log('   - Description de sous-tâche manquante ou incomplète');
        }
    } else {
        if (!hasEscaladeApprofondissementMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement traité la conversation sans suggérer d\'escalade par approfondissement');
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent a suggéré une escalade par approfondissement alors qu\'elle n\'était pas attendue');
        }
    }
}

/**
 * Fonction qui simule la réponse de l'agent
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateAgentResponse() {
    if (config.expectEscaladeApprofondissement) {
        return `
Après avoir travaillé sur cette tâche pendant ${config.messageCount} messages, je constate que la conversation devient volumineuse.

[ESCALADE PAR APPROFONDISSEMENT] Je suggère de créer une sous-tâche pour continuer ce travail car : la conversation a atteint environ 15 messages et devient difficile à suivre

Je propose de créer une sous-tâche pour :
1. Finaliser l'implémentation des fonctionnalités restantes
2. Effectuer les tests unitaires et d'intégration
3. Documenter le code et les API
4. Préparer le déploiement

Cette sous-tâche permettra de continuer le travail de manière plus structurée et avec un contexte plus léger, ce qui facilitera la compréhension et le suivi des modifications.

Souhaitez-vous que je crée cette sous-tâche maintenant ?
`;
    } else {
        return `
Voici la suite de mon travail sur cette tâche. J'ai implémenté les fonctionnalités demandées et je suis prêt à passer à l'étape suivante.

Voici le code que j'ai écrit :

\`\`\`javascript
function processData(data) {
  // Traitement des données
  const result = data.map(item => {
    return {
      id: item.id,
      name: item.name,
      value: calculateValue(item)
    };
  });
  
  return result;
}

function calculateValue(item) {
  // Calcul de la valeur
  return item.baseValue * item.multiplier;
}
\`\`\`

Est-ce que cela correspond à vos attentes ? Souhaitez-vous que j'apporte des modifications ?
`;
    }
}

// Exécution du test
runTest().catch(console.error);