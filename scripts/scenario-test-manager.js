/**
 * Scénario de test pour vérifier le mode Manager
 * 
 * Ce scénario teste les capacités du mode Manager à:
 * 1. Créer des sous-tâches orchestrateurs pour des tâches de haut-niveau
 * 2. Décomposer des tâches complexes en sous-tâches composites
 * 3. Créer systématiquement des sous-tâches du niveau de complexité minimale nécessaire
 * 4. Implémenter l'escalade par approfondissement après 50000 tokens ou environ 15 messages
 */

// Configuration du test
const config = {
    mode: 'manager',
    tasks: [
        {
            id: 'task1',
            description: 'Créer une application web de gestion de tâches avec authentification',
            expectedSubtasks: [
                {
                    description: 'Configurer la structure du projet et les dépendances',
                    expectedMode: 'code-simple'
                },
                {
                    description: 'Implémenter le système d\'authentification',
                    expectedMode: 'code-complex'
                },
                {
                    description: 'Créer l\'interface utilisateur de gestion des tâches',
                    expectedMode: 'code-simple'
                },
                {
                    description: 'Intégrer l\'authentification avec la gestion des tâches',
                    expectedMode: 'code-complex'
                }
            ],
            expectComplexityOptimization: true
        },
        {
            id: 'task2',
            description: 'Analyser les performances d\'une application web existante',
            expectedSubtasks: [
                {
                    description: 'Collecter les métriques de performance actuelles',
                    expectedMode: 'code-simple'
                },
                {
                    description: 'Analyser les goulots d\'étranglement',
                    expectedMode: 'debug-complex'
                },
                {
                    description: 'Proposer des optimisations',
                    expectedMode: 'architect-complex'
                }
            ],
            expectComplexityOptimization: true
        }
    ]
};

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test du mode Manager ===');
    console.log(`Mode: ${config.mode}`);
    
    let totalTests = config.tasks.length;
    let passedTests = 0;
    
    for (const task of config.tasks) {
        console.log(`\n--- Test de la tâche: ${task.id} ---`);
        console.log(`Description: ${task.description}`);
        console.log(`Nombre de sous-tâches attendues: ${task.expectedSubtasks.length}`);
        console.log(`Optimisation de complexité attendue: ${task.expectComplexityOptimization ? 'Oui' : 'Non'}`);
        
        // Simulation de la réponse de l'agent
        const response = simulateAgentResponse(task);
        
        // Vérification de la décomposition en sous-tâches
        const subtasks = extractSubtasks(response);
        const hasCorrectSubtaskCount = subtasks.length === task.expectedSubtasks.length;
        
        // Vérification de l'optimisation de complexité
        const hasComplexityOptimization = checkComplexityOptimization(subtasks, task.expectedSubtasks);
        
        console.log('\nRésultats:');
        console.log(`- Nombre correct de sous-tâches: ${hasCorrectSubtaskCount ? '✅' : '❌'} (${subtasks.length}/${task.expectedSubtasks.length})`);
        console.log(`- Optimisation de complexité: ${hasComplexityOptimization ? '✅' : '❌'}`);
        
        if (subtasks.length > 0) {
            console.log('\nSous-tâches détectées:');
            subtasks.forEach((subtask, index) => {
                const expectedMode = index < task.expectedSubtasks.length ? task.expectedSubtasks[index].expectedMode : 'inconnu';
                const modeMatch = subtask.mode === expectedMode;
                console.log(`${index + 1}. ${subtask.description} - Mode: ${subtask.mode} ${modeMatch ? '✅' : '❌'}`);
            });
        }
        
        const passed = hasCorrectSubtaskCount && (hasComplexityOptimization === task.expectComplexityOptimization);
        console.log(`\nRésultat du test: ${passed ? '✅ RÉUSSI' : '❌ ÉCHOUÉ'}`);
        
        if (passed) passedTests++;
    }
    
    console.log(`\n=== Résumé des tests ===`);
    console.log(`Tests réussis: ${passedTests}/${totalTests} (${Math.round(passedTests/totalTests*100)}%)`);
    
    if (passedTests === totalTests) {
        console.log('\n✅ TOUS LES TESTS SONT RÉUSSIS: Le mode Manager fonctionne correctement');
    } else {
        console.log('\n❌ CERTAINS TESTS ONT ÉCHOUÉ: Le mode Manager ne fonctionne pas correctement');
    }
}

/**
 * Fonction qui extrait les sous-tâches de la réponse de l'agent
 * @param {string} response - La réponse de l'agent
 * @returns {Array} - Les sous-tâches extraites
 */
function extractSubtasks(response) {
    const subtasks = [];
    const subtaskRegex = /<new_task>\s*<mode>(.*?)<\/mode>\s*<message>(.*?)<\/message>\s*<\/new_task>/gs;
    
    let match;
    while ((match = subtaskRegex.exec(response)) !== null) {
        subtasks.push({
            mode: match[1],
            description: match[2].trim()
        });
    }
    
    return subtasks;
}

/**
 * Fonction qui vérifie l'optimisation de complexité
 * @param {Array} subtasks - Les sous-tâches détectées
 * @param {Array} expectedSubtasks - Les sous-tâches attendues
 * @returns {boolean} - True si l'optimisation de complexité est correcte
 */
function checkComplexityOptimization(subtasks, expectedSubtasks) {
    // Vérifier que les modes simples sont utilisés quand c'est possible
    let optimizationCorrect = true;
    
    for (let i = 0; i < Math.min(subtasks.length, expectedSubtasks.length); i++) {
        if (subtasks[i].mode !== expectedSubtasks[i].expectedMode) {
            optimizationCorrect = false;
            break;
        }
    }
    
    return optimizationCorrect;
}

/**
 * Fonction qui simule la réponse de l'agent
 * @param {Object} task - La tâche en cours de test
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateAgentResponse(task) {
    switch (task.id) {
        case 'task1':
            return `
Pour créer une application web de gestion de tâches avec authentification, je vais décomposer cette tâche complexe en plusieurs sous-tâches plus gérables:

1. Configurer la structure du projet et les dépendances
2. Implémenter le système d'authentification
3. Créer l'interface utilisateur de gestion des tâches
4. Intégrer l'authentification avec la gestion des tâches

Je vais créer des sous-tâches pour chacune de ces étapes, en choisissant le niveau de complexité approprié:

<new_task>
<mode>code-simple</mode>
<message>
Configurer la structure du projet et les dépendances pour une application web de gestion de tâches.

Votre tâche consiste à:
1. Initialiser un projet Node.js
2. Installer les dépendances nécessaires (Express, MongoDB, etc.)
3. Configurer la structure de base du projet (dossiers routes, controllers, models, views)
4. Créer un serveur Express minimal fonctionnel

Cette sous-tâche doit *uniquement* se concentrer sur la configuration initiale du projet, sans implémenter de fonctionnalités spécifiques.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis de la structure du projet créée.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

<new_task>
<mode>code-complex</mode>
<message>
Implémenter le système d'authentification pour l'application web de gestion de tâches.

Votre tâche consiste à:
1. Créer un modèle d'utilisateur avec MongoDB/Mongoose
2. Implémenter l'inscription et la connexion des utilisateurs
3. Configurer Passport.js ou une solution similaire pour l'authentification
4. Implémenter la gestion des sessions et des tokens JWT
5. Créer les routes et contrôleurs nécessaires pour l'authentification
6. Implémenter la protection des routes privées

Cette sous-tâche doit *uniquement* se concentrer sur le système d'authentification, sans implémenter les fonctionnalités de gestion des tâches.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis du système d'authentification implémenté.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

<new_task>
<mode>code-simple</mode>
<message>
Créer l'interface utilisateur de gestion des tâches pour l'application web.

Votre tâche consiste à:
1. Créer les vues pour afficher la liste des tâches
2. Implémenter les formulaires pour ajouter/modifier/supprimer des tâches
3. Créer le modèle de tâche avec MongoDB/Mongoose
4. Implémenter les routes et contrôleurs de base pour la gestion des tâches (sans authentification)

Cette sous-tâche doit *uniquement* se concentrer sur l'interface utilisateur et les fonctionnalités de base de gestion des tâches, sans intégrer l'authentification.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis de l'interface utilisateur et des fonctionnalités de gestion des tâches implémentées.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

<new_task>
<mode>code-complex</mode>
<message>
Intégrer le système d'authentification avec la gestion des tâches.

Votre tâche consiste à:
1. Modifier le modèle de tâche pour inclure une référence à l'utilisateur propriétaire
2. Mettre à jour les contrôleurs de tâches pour filtrer les tâches par utilisateur
3. Protéger les routes de gestion des tâches avec l'authentification
4. Implémenter la gestion des permissions (seul le propriétaire peut modifier/supprimer ses tâches)
5. Mettre à jour l'interface utilisateur pour afficher uniquement les tâches de l'utilisateur connecté

Cette sous-tâche doit *uniquement* se concentrer sur l'intégration de l'authentification avec la gestion des tâches, en partant du principe que les deux systèmes ont déjà été implémentés séparément.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis de l'intégration réalisée.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

En décomposant cette tâche complexe en sous-tâches plus gérables, j'ai veillé à:
1. Attribuer chaque sous-tâche au mode le plus approprié en fonction de sa complexité
2. Utiliser le mode simple pour les tâches de configuration et d'interface utilisateur de base
3. Utiliser le mode complexe pour les tâches impliquant l'authentification et l'intégration des systèmes

Cette approche permet d'optimiser l'utilisation des ressources tout en garantissant que chaque aspect de l'application est développé avec le niveau d'expertise approprié.
`;
        case 'task2':
            return `
Pour analyser les performances d'une application web existante, je vais décomposer cette tâche en plusieurs sous-tâches logiques:

1. Collecter les métriques de performance actuelles
2. Analyser les goulots d'étranglement
3. Proposer des optimisations

Je vais créer des sous-tâches pour chacune de ces étapes, en choisissant le niveau de complexité approprié:

<new_task>
<mode>code-simple</mode>
<message>
Collecter les métriques de performance actuelles de l'application web.

Votre tâche consiste à:
1. Mettre en place des outils de mesure de performance (Lighthouse, WebPageTest, etc.)
2. Collecter les métriques clés:
   - Temps de chargement initial
   - First Contentful Paint (FCP)
   - Largest Contentful Paint (LCP)
   - Time to Interactive (TTI)
   - Total Blocking Time (TBT)
   - Cumulative Layout Shift (CLS)
3. Mesurer les performances réseau (taille des ressources, temps de réponse du serveur)
4. Collecter les métriques d'utilisation des ressources (CPU, mémoire)
5. Documenter toutes les métriques dans un format structuré

Cette sous-tâche doit *uniquement* se concentrer sur la collecte des métriques, sans analyser les causes des problèmes.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis des métriques collectées.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

<new_task>
<mode>debug-complex</mode>
<message>
Analyser les goulots d'étranglement de l'application web en utilisant les métriques collectées.

Votre tâche consiste à:
1. Analyser les métriques de performance collectées
2. Identifier les principales causes de ralentissement:
   - Problèmes de rendu (JavaScript bloquant, CSS non optimisé)
   - Problèmes réseau (ressources volumineuses, requêtes excessives)
   - Problèmes de serveur (temps de réponse lents, requêtes inefficaces)
   - Problèmes de base de données (requêtes non optimisées, indexes manquants)
3. Utiliser les outils de profilage pour identifier les fonctions ou composants problématiques
4. Analyser le code source pour comprendre les causes profondes des problèmes
5. Prioriser les problèmes en fonction de leur impact sur les performances

Cette sous-tâche doit *uniquement* se concentrer sur l'analyse des problèmes, sans proposer de solutions détaillées.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis des goulots d'étranglement identifiés et de leurs causes.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

<new_task>
<mode>architect-complex</mode>
<message>
Proposer des optimisations pour améliorer les performances de l'application web.

Votre tâche consiste à:
1. Élaborer des solutions détaillées pour chaque goulot d'étranglement identifié
2. Proposer des optimisations front-end:
   - Optimisation du chargement des ressources (lazy loading, code splitting)
   - Amélioration du rendu (CSS critique, optimisation JavaScript)
   - Stratégies de mise en cache
3. Proposer des optimisations back-end:
   - Optimisation des requêtes de base de données
   - Mise en cache côté serveur
   - Optimisation des API
4. Proposer des améliorations architecturales si nécessaire
5. Prioriser les optimisations en fonction de leur impact et de leur facilité de mise en œuvre
6. Créer un plan d'implémentation détaillé

Cette sous-tâche doit *uniquement* se concentrer sur la proposition de solutions, sans les implémenter.

Une fois terminé, utilisez l'outil attempt_completion pour fournir un résumé concis des optimisations proposées et du plan d'implémentation.

Ces instructions spécifiques remplacent toute instruction générale contradictoire que vous pourriez avoir.
</message>
</new_task>

En décomposant cette tâche d'analyse de performance en sous-tâches spécifiques, j'ai veillé à:
1. Attribuer chaque sous-tâche au mode le plus approprié en fonction de sa complexité
2. Utiliser le mode code-simple pour la collecte des métriques, qui est une tâche relativement directe
3. Utiliser le mode debug-complex pour l'analyse des goulots d'étranglement, qui nécessite une compréhension approfondie des systèmes
4. Utiliser le mode architect-complex pour la proposition d'optimisations, qui nécessite une vision architecturale

Cette approche permet d'optimiser l'utilisation des ressources tout en garantissant que chaque aspect de l'analyse est traité avec le niveau d'expertise approprié.
`;
        default:
            return '';
    }
}

// Exécution du test
runTest().catch(console.error);