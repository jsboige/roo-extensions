/**
 * Scénario de test pour vérifier le mécanisme de désescalade systématique
 * 
 * Ce scénario teste le mécanisme de désescalade systématique en simulant une tâche
 * complexe dont l'étape suivante est de complexité inférieure, ce qui devrait
 * déclencher une suggestion de désescalade.
 * 
 * Le scénario vérifie que:
 * 1. L'agent évalue correctement la complexité de l'étape suivante
 * 2. L'agent suggère correctement une désescalade lorsque l'étape suivante est plus simple
 * 3. L'agent continue à traiter la tâche correctement
 */

// Configuration du test
const config = {
    mode: 'code-complex',
    initialTask: 'Refactoriser l\'architecture de l\'application pour utiliser un pattern MVC',
    nextStep: 'Ajouter des commentaires de documentation aux fichiers modifiés',
    expectDesescalade: true
};

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test du mécanisme de désescalade systématique ===');
    console.log(`Mode: ${config.mode}`);
    console.log(`Tâche initiale (complexe): ${config.initialTask}`);
    console.log(`Étape suivante (plus simple): ${config.nextStep}`);
    console.log(`Désescalade attendue: ${config.expectDesescalade ? 'Oui' : 'Non'}`);
    
    // Simulation de la première réponse de l'agent (tâche complexe)
    console.log('\n--- Étape 1: Tâche complexe ---');
    const initialResponse = simulateInitialResponse();
    console.log('Réponse de l\'agent (résumé): Refactorisation de l\'architecture terminée...');
    
    // Simulation de la transition vers l'étape suivante
    console.log('\n--- Étape 2: Transition vers l\'étape suivante (plus simple) ---');
    console.log(`Utilisateur: "Maintenant, pouvez-vous ajouter des commentaires de documentation aux fichiers modifiés?"`);
    
    // Simulation de la réponse de l'agent pour l'étape suivante
    const finalResponse = simulateFinalResponse();
    
    // Vérification de la désescalade
    const hasDesescaladeMarker = finalResponse.includes('[DÉSESCALADE SUGGÉRÉE]');
    
    console.log('\n=== Résultats du test ===');
    console.log(`Désescalade suggérée: ${hasDesescaladeMarker ? 'Oui' : 'Non'}`);
    
    if (config.expectDesescalade) {
        if (hasDesescaladeMarker) {
            console.log('\n✅ TEST RÉUSSI: L\'agent a correctement suggéré une désescalade systématique');
            
            // Extraction de la raison de la désescalade
            const reasonMatch = finalResponse.match(/\[DÉSESCALADE SUGGÉRÉE\] Cette tâche pourrait être traitée par la version simple de l'agent car : (.*)/);
            if (reasonMatch && reasonMatch[1]) {
                console.log(`Raison de la désescalade: ${reasonMatch[1]}`);
            }
        } else {
            console.log('\n❌ TEST ÉCHOUÉ: L\'agent n\'a pas suggéré de désescalade alors qu\'elle était attendue');
        }
    } else {
        if (!hasDesescaladeMarker) {
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
J'ai terminé la refactorisation de l'architecture de l'application pour utiliser le pattern MVC. Voici un résumé des modifications effectuées:

1. Création de la structure de répertoires MVC:
   - /models: Contient les modèles de données
   - /views: Contient les templates et vues
   - /controllers: Contient la logique de contrôle

2. Refactorisation des fichiers existants:
   - Séparation de la logique métier dans les modèles
   - Extraction de la logique de présentation dans les vues
   - Création de contrôleurs pour gérer les interactions

3. Mise à jour des routes pour utiliser les nouveaux contrôleurs

4. Implémentation d'un système de chargement automatique des classes

5. Mise à jour des tests pour refléter la nouvelle architecture

Tous les tests passent et l'application fonctionne comme prévu avec la nouvelle architecture.
`;
}

/**
 * Fonction qui simule la réponse finale de l'agent
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateFinalResponse() {
    if (config.expectDesescalade) {
        return `
[DÉSESCALADE SUGGÉRÉE] Cette tâche pourrait être traitée par la version simple de l'agent car : l'ajout de commentaires de documentation est une tâche simple qui ne nécessite pas d'analyse approfondie de l'architecture

Je comprends que vous souhaitez maintenant ajouter des commentaires de documentation aux fichiers modifiés. Cette tâche est relativement simple et pourrait être traitée par la version simple de l'agent.

Néanmoins, je vais procéder à l'ajout des commentaires de documentation. Voici comment je vais structurer les commentaires:

1. Pour les classes:
   \`\`\`php
   /**
    * Class UserModel
    * 
    * Représente un utilisateur dans le système et gère les interactions avec la base de données.
    * Fait partie de la couche Modèle du pattern MVC.
    */
   class UserModel {
       // ...
   }
   \`\`\`

2. Pour les méthodes:
   \`\`\`php
   /**
    * Récupère un utilisateur par son identifiant
    * 
    * @param int $id Identifiant de l'utilisateur
    * @return User|null L'utilisateur trouvé ou null si aucun utilisateur n'est trouvé
    */
   public function getUserById($id) {
       // ...
   }
   \`\`\`

3. Pour les fichiers:
   \`\`\`php
   /**
    * Fichier: UserController.php
    * 
    * Ce fichier contient le contrôleur des utilisateurs qui gère toutes les actions
    * liées aux utilisateurs (création, modification, suppression, etc.).
    * Fait partie de la couche Contrôleur du pattern MVC.
    * 
    * @author Votre Nom
    * @version 1.0
    */
   \`\`\`

Je vais appliquer ce format de documentation à tous les fichiers modifiés lors de la refactorisation.

Puisque cette tâche est relativement simple, vous pourriez envisager d'utiliser la version simple de l'agent pour des tâches similaires à l'avenir, ce qui permettrait d'optimiser l'utilisation des ressources.
`;
    } else {
        return `
Je vais ajouter des commentaires de documentation aux fichiers modifiés. Voici comment je vais structurer les commentaires:

1. Pour les classes:
   \`\`\`php
   /**
    * Class UserModel
    * 
    * Représente un utilisateur dans le système et gère les interactions avec la base de données.
    * Fait partie de la couche Modèle du pattern MVC.
    */
   class UserModel {
       // ...
   }
   \`\`\`

2. Pour les méthodes:
   \`\`\`php
   /**
    * Récupère un utilisateur par son identifiant
    * 
    * @param int $id Identifiant de l'utilisateur
    * @return User|null L'utilisateur trouvé ou null si aucun utilisateur n'est trouvé
    */
   public function getUserById($id) {
       // ...
   }
   \`\`\`

3. Pour les fichiers:
   \`\`\`php
   /**
    * Fichier: UserController.php
    * 
    * Ce fichier contient le contrôleur des utilisateurs qui gère toutes les actions
    * liées aux utilisateurs (création, modification, suppression, etc.).
    * Fait partie de la couche Contrôleur du pattern MVC.
    * 
    * @author Votre Nom
    * @version 1.0
    */
   \`\`\`

Je vais appliquer ce format de documentation à tous les fichiers modifiés lors de la refactorisation.
`;
    }
}

// Exécution du test
runTest().catch(console.error);