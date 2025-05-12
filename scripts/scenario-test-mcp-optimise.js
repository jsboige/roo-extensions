/**
 * Scénario de test pour vérifier l'utilisation optimisée des MCPs
 * 
 * Ce scénario teste l'utilisation optimisée des MCPs en simulant des tâches
 * qui peuvent être résolues efficacement en utilisant les MCPs disponibles.
 * 
 * Le scénario vérifie que:
 * 1. L'agent utilise les MCPs de manière appropriée
 * 2. L'agent regroupe les opérations similaires en une seule commande MCP
 * 3. L'agent utilise les outils de lecture/écriture multiple plutôt que des opérations individuelles
 * 4. L'agent filtre les données à la source plutôt que de tout lire puis filtrer
 */

// Configuration du test
const config = {
    mode: 'code-simple',
    tasks: [
        {
            id: 'task1',
            description: 'Lire le contenu de plusieurs fichiers JavaScript dans le répertoire src',
            expectedMCP: 'quickfiles',
            expectedTool: 'read_multiple_files',
            optimizationExpected: true
        },
        {
            id: 'task2',
            description: 'Modifier plusieurs fichiers pour remplacer les occurrences de "function" par "const"',
            expectedMCP: 'quickfiles',
            expectedTool: 'edit_multiple_files',
            optimizationExpected: true
        },
        {
            id: 'task3',
            description: 'Extraire des informations de plusieurs pages web sur JavaScript',
            expectedMCP: 'jinavigator',
            expectedTool: 'multi_convert',
            optimizationExpected: true
        },
        {
            id: 'task4',
            description: 'Rechercher des informations sur les dernières fonctionnalités de JavaScript',
            expectedMCP: 'searxng',
            expectedTool: 'searxng_web_search',
            optimizationExpected: true
        }
    ]
};

/**
 * Fonction qui simule l'exécution du test
 * Dans un environnement réel, cette fonction serait remplacée par
 * l'interaction avec l'agent Roo via l'API de VS Code
 */
async function runTest() {
    console.log('=== Test de l\'utilisation optimisée des MCPs ===');
    console.log(`Mode: ${config.mode}`);
    
    let totalTests = config.tasks.length;
    let passedTests = 0;
    
    for (const task of config.tasks) {
        console.log(`\n--- Test de la tâche: ${task.id} ---`);
        console.log(`Description: ${task.description}`);
        console.log(`MCP attendu: ${task.expectedMCP}`);
        console.log(`Outil attendu: ${task.expectedTool}`);
        console.log(`Optimisation attendue: ${task.optimizationExpected ? 'Oui' : 'Non'}`);
        
        // Simulation de la réponse de l'agent
        const response = simulateAgentResponse(task);
        
        // Vérification de l'utilisation du MCP
        const usesMCP = response.includes(`<server_name>${task.expectedMCP}</server_name>`);
        const usesCorrectTool = response.includes(`<tool_name>${task.expectedTool}</tool_name>`);
        const isOptimized = checkOptimization(response, task);
        
        console.log('\nRésultats:');
        console.log(`- Utilise le MCP ${task.expectedMCP}: ${usesMCP ? '✅' : '❌'}`);
        console.log(`- Utilise l'outil ${task.expectedTool}: ${usesCorrectTool ? '✅' : '❌'}`);
        console.log(`- Optimisation détectée: ${isOptimized ? '✅' : '❌'}`);
        
        const passed = usesMCP && usesCorrectTool && (isOptimized === task.optimizationExpected);
        console.log(`\nRésultat du test: ${passed ? '✅ RÉUSSI' : '❌ ÉCHOUÉ'}`);
        
        if (passed) passedTests++;
    }
    
    console.log(`\n=== Résumé des tests ===`);
    console.log(`Tests réussis: ${passedTests}/${totalTests} (${Math.round(passedTests/totalTests*100)}%)`);
    
    if (passedTests === totalTests) {
        console.log('\n✅ TOUS LES TESTS SONT RÉUSSIS: L\'agent utilise correctement les MCPs de manière optimisée');
    } else {
        console.log('\n❌ CERTAINS TESTS ONT ÉCHOUÉ: L\'agent n\'utilise pas correctement les MCPs de manière optimisée');
    }
}

/**
 * Fonction qui vérifie si la réponse est optimisée
 * @param {string} response - La réponse de l'agent
 * @param {Object} task - La tâche en cours de test
 * @returns {boolean} - True si la réponse est optimisée, false sinon
 */
function checkOptimization(response, task) {
    switch (task.expectedMCP) {
        case 'quickfiles':
            if (task.expectedTool === 'read_multiple_files') {
                // Vérifie si l'agent lit plusieurs fichiers en une seule opération
                return response.includes('"paths": [') && response.includes('"],');
            } else if (task.expectedTool === 'edit_multiple_files') {
                // Vérifie si l'agent modifie plusieurs fichiers en une seule opération
                return response.includes('"files": [') && response.includes(']}');
            }
            break;
        case 'jinavigator':
            if (task.expectedTool === 'multi_convert') {
                // Vérifie si l'agent convertit plusieurs pages en une seule opération
                return response.includes('"urls": [') && response.includes(']}');
            }
            break;
        case 'searxng':
            // Pas d'optimisation spécifique à vérifier pour searxng
            return true;
    }
    return false;
}

/**
 * Fonction qui simule la réponse de l'agent
 * Dans un environnement réel, cette fonction serait remplacée par
 * la réponse réelle de l'agent Roo
 * @param {Object} task - La tâche en cours de test
 * @returns {string} - La réponse simulée de l'agent
 */
function simulateAgentResponse(task) {
    switch (task.id) {
        case 'task1':
            return `
Pour lire le contenu de plusieurs fichiers JavaScript dans le répertoire src, je vais utiliser le MCP quickfiles qui permet de lire plusieurs fichiers en une seule opération:

<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>read_multiple_files</tool_name>
<arguments>
{
  "paths": [
    "src/app.js",
    "src/utils.js",
    "src/components/header.js",
    "src/components/footer.js"
  ],
  "show_line_numbers": true
}
</arguments>
</use_mcp_tool>
`;
        case 'task2':
            return `
Pour modifier plusieurs fichiers et remplacer les occurrences de "function" par "const", je vais utiliser le MCP quickfiles qui permet d'éditer plusieurs fichiers en une seule opération:

<use_mcp_tool>
<server_name>quickfiles</server_name>
<tool_name>edit_multiple_files</tool_name>
<arguments>
{
  "files": [
    {
      "path": "src/app.js",
      "diffs": [
        {
          "search": "function ",
          "replace": "const "
        }
      ]
    },
    {
      "path": "src/utils.js",
      "diffs": [
        {
          "search": "function ",
          "replace": "const "
        }
      ]
    }
  ]
}
</arguments>
</use_mcp_tool>
`;
        case 'task3':
            return `
Pour extraire des informations de plusieurs pages web sur JavaScript, je vais utiliser le MCP jinavigator qui permet de convertir plusieurs pages web en une seule opération:

<use_mcp_tool>
<server_name>jinavigator</server_name>
<tool_name>multi_convert</tool_name>
<arguments>
{
  "urls": [
    {"url": "https://developer.mozilla.org/fr/docs/Web/JavaScript"},
    {"url": "https://javascript.info/"},
    {"url": "https://www.w3schools.com/js/"}
  ]
}
</arguments>
</use_mcp_tool>
`;
        case 'task4':
            return `
Pour rechercher des informations sur les dernières fonctionnalités de JavaScript, je vais utiliser le MCP searxng:

<use_mcp_tool>
<server_name>searxng</server_name>
<tool_name>searxng_web_search</tool_name>
<arguments>
{
  "query": "JavaScript latest features ES2023"
}
</arguments>
</use_mcp_tool>
`;
        default:
            return '';
    }
}

// Exécution du test
runTest().catch(console.error);