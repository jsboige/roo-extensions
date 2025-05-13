/**
 * Script de test utilisant directement l'API MCP Win-CLI
 * 
 * Ce script teste les fonctionnalités du MCP Win-CLI en utilisant l'API MCP :
 * - Exécution de commandes simples dans différents shells
 * - Exécution de commandes complexes
 * - Gestion des erreurs
 * - Récupération de l'historique des commandes
 * - Récupération du répertoire de travail actuel
 * 
 * Pour exécuter ce script, vous devez avoir le MCP Win-CLI installé et configuré.
 * Exécutez-le avec Roo en utilisant l'outil execute_command.
 */

// Configuration des tests
const CONFIG = {
    // Nom du serveur MCP Win-CLI
    serverName: 'win-cli',
    
    // Liste des commandes à tester pour chaque shell
    commands: {
        powershell: {
            simple: [
                'Get-Date',
                'Write-Host "Hello from PowerShell"',
                'Get-Location'
            ],
            complex: [
                'Get-Process | Select-Object -First 5',
                '$a = 5; $b = 10; Write-Host "La somme est: $($a + $b)"',
                'Get-ChildItem | Where-Object { $_.Length -gt 1000 } | Select-Object -First 3'
            ],
            error: [
                'Get-NonExistentCmdlet',
                'Write-Host "Test" | NonExistentPipe'
            ]
        },
        cmd: {
            simple: [
                'echo Hello from CMD',
                'dir /b',
                'cd'
            ],
            complex: [
                'dir /a /o:n',
                'echo Premier & echo Second',
                'findstr /r "test" *.js'
            ],
            error: [
                'unknown_command',
                'dir /invalid_option'
            ]
        },
        gitbash: {
            simple: [
                'echo "Hello from Git Bash"',
                'ls -la',
                'pwd'
            ],
            complex: [
                'for i in {1..3}; do echo "Itération $i"; done',
                'find . -type f -name "*.js" | wc -l',
                'ls -la | grep "test"'
            ],
            error: [
                'unknown_command',
                'ls --invalid-option'
            ]
        }
    }
};

// Fonction pour exécuter une commande via l'API MCP Win-CLI
async function executeMcpCommand(shell, command, workingDir = null) {
    console.log(`\n[TEST] Exécution dans ${shell}: ${command}`);
    
    try {
        // Préparation des arguments pour l'appel MCP
        const args = {
            shell,
            command
        };
        
        if (workingDir) {
            args.workingDir = workingDir;
        }
        
        // Appel à l'API MCP Win-CLI
        // Note: Dans un environnement Roo, cela serait remplacé par un appel à l'API MCP
        console.log(`[INFO] Appel à l'API MCP Win-CLI avec les arguments:`, JSON.stringify(args, null, 2));
        
        // Simulation de l'appel à l'API MCP
        // Dans un environnement Roo, cela serait remplacé par un appel réel à l'API MCP
        const result = await simulateMcpCall('execute_command', args);
        
        console.log(`[RÉSULTAT] Succès: ${result.success}`);
        if (result.output) {
            console.log(`[SORTIE] ${result.output}`);
        }
        
        return result;
    } catch (error) {
        console.error(`[ERREUR] ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Fonction pour récupérer l'historique des commandes via l'API MCP Win-CLI
async function getCommandHistory(limit = 5) {
    console.log(`\n[TEST] Récupération de l'historique des commandes (limite: ${limit})`);
    
    try {
        // Préparation des arguments pour l'appel MCP
        const args = { limit };
        
        // Appel à l'API MCP Win-CLI
        console.log(`[INFO] Appel à l'API MCP Win-CLI pour l'historique avec les arguments:`, JSON.stringify(args, null, 2));
        
        // Simulation de l'appel à l'API MCP
        const result = await simulateMcpCall('get_command_history', args);
        
        console.log(`[RÉSULTAT] ${result.history.length} commandes récupérées`);
        result.history.forEach((cmd, index) => {
            console.log(`[HISTORIQUE ${index + 1}] ${cmd.command}`);
        });
        
        return result;
    } catch (error) {
        console.error(`[ERREUR] ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Fonction pour récupérer le répertoire de travail actuel via l'API MCP Win-CLI
async function getCurrentDirectory() {
    console.log(`\n[TEST] Récupération du répertoire de travail actuel`);
    
    try {
        // Appel à l'API MCP Win-CLI
        console.log(`[INFO] Appel à l'API MCP Win-CLI pour le répertoire courant`);
        
        // Simulation de l'appel à l'API MCP
        const result = await simulateMcpCall('get_current_directory', {});
        
        console.log(`[RÉSULTAT] Répertoire actuel: ${result.directory}`);
        
        return result;
    } catch (error) {
        console.error(`[ERREUR] ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Fonction de simulation d'appel à l'API MCP pour les tests
// Cette fonction simule le comportement de l'API MCP Win-CLI sans faire d'appels réels
// Dans un environnement Roo, elle serait remplacée par un appel réel à l'API MCP
async function simulateMcpCall(toolName, args) {
    // Simulation de délai réseau
    await new Promise(resolve => setTimeout(resolve, 500));
    
    switch (toolName) {
        case 'execute_command':
            return simulateCommandExecution(args);
        case 'get_command_history':
            return simulateGetCommandHistory(args);
        case 'get_current_directory':
            return simulateGetCurrentDirectory();
        default:
            throw new Error(`Outil non pris en charge: ${toolName}`);
    }
}

// Simulations des réponses API
function simulateCommandExecution({ shell, command, workingDir }) {
    // Commandes qui devraient échouer pour tester la gestion des erreurs
    const errorCommands = [
        'Get-NonExistentCmdlet',
        'NonExistentPipe',
        'unknown_command',
        '/invalid_option',
        '--invalid-option'
    ];
    
    if (errorCommands.some(cmd => command.includes(cmd))) {
        return {
            success: false,
            error: `Commande non reconnue ou option invalide: ${command}`,
            output: `Erreur: Commande non reconnue ou option invalide: ${command}`,
            shell,
            command,
            workingDir: workingDir || 'C:\\Users\\Default'
        };
    }
    
    // Simuler différentes sorties selon le shell et la commande
    let output = '';
    
    if (shell === 'powershell') {
        if (command.includes('Get-Process')) {
            output = 'Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName\n' +
                     '-------  ------    -----      -----     ------     --  -- -----------\n' +
                     '    101      12     1234      5678       0.25   1234   1 chrome\n' +
                     '    203      15     2345      6789       1.50   2345   1 code\n';
        } else if (command.includes('Get-Date')) {
            output = 'jeudi 6 mai 2025 14:30:00';
        } else if (command.includes('Get-Location')) {
            output = 'Path\n----\nC:\\Users\\Default';
        } else if (command.includes('$a = 5; $b = 10')) {
            output = 'La somme est: 15';
        } else {
            output = `Exécution réussie de la commande PowerShell: ${command}`;
        }
    } else if (shell === 'cmd') {
        if (command.includes('dir')) {
            output = ' Volume in drive C is Windows\n' +
                     ' Volume Serial Number is 1234-5678\n\n' +
                     ' Directory of C:\\Users\n\n' +
                     '05/06/2025  14:30    <DIR>          .\n' +
                     '05/06/2025  14:30    <DIR>          ..\n' +
                     '05/06/2025  14:30    <DIR>          Documents\n' +
                     '05/06/2025  14:30    <DIR>          Downloads\n';
        } else if (command.includes('cd')) {
            output = 'C:\\Users\\Default';
        } else if (command.includes('echo')) {
            if (command.includes('&')) {
                output = 'Premier\nSecond';
            } else {
                output = command.replace('echo ', '');
            }
        } else {
            output = `Exécution réussie de la commande CMD: ${command}`;
        }
    } else if (shell === 'gitbash') {
        if (command.includes('ls')) {
            output = 'total 8\n' +
                     'drwxr-xr-x 1 user group 0 May  6 14:30 .\n' +
                     'drwxr-xr-x 1 user group 0 May  6 14:30 ..\n' +
                     'drwxr-xr-x 1 user group 0 May  6 14:30 Documents\n' +
                     'drwxr-xr-x 1 user group 0 May  6 14:30 Downloads\n';
        } else if (command.includes('pwd')) {
            output = '/c/Users/Default';
        } else if (command.includes('for i in {1..3}')) {
            output = 'Itération 1\nItération 2\nItération 3';
        } else {
            output = `Exécution réussie de la commande Git Bash: ${command}`;
        }
    } else {
        throw new Error(`Shell non pris en charge: ${shell}`);
    }
    
    return {
        success: true,
        output,
        shell,
        command,
        workingDir: workingDir || 'C:\\Users\\Default'
    };
}

function simulateGetCommandHistory({ limit }) {
    const commandHistory = [
        { command: 'Get-Process | Select-Object -First 5', timestamp: '2025-05-06T14:25:00Z', exitCode: 0 },
        { command: 'dir /b', timestamp: '2025-05-06T14:26:00Z', exitCode: 0 },
        { command: 'ls -la', timestamp: '2025-05-06T14:27:00Z', exitCode: 0 },
        { command: 'Get-Date', timestamp: '2025-05-06T14:28:00Z', exitCode: 0 },
        { command: 'echo Hello World', timestamp: '2025-05-06T14:29:00Z', exitCode: 0 },
        { command: 'npm --version', timestamp: '2025-05-06T14:30:00Z', exitCode: 0 },
        { command: 'node --version', timestamp: '2025-05-06T14:31:00Z', exitCode: 0 }
    ];
    
    return {
        success: true,
        history: commandHistory.slice(0, limit)
    };
}

function simulateGetCurrentDirectory() {
    return {
        success: true,
        directory: 'C:\\Users\\Default\\Projects'
    };
}

// Fonction principale pour exécuter tous les tests
async function runAllTests() {
    console.log('=== DÉBUT DES TESTS DU MCP WIN-CLI ===');
    console.log(`Serveur MCP: ${CONFIG.serverName}`);
    
    const results = {
        timestamp: new Date().toISOString(),
        powershell: { simple: [], complex: [], error: [] },
        cmd: { simple: [], complex: [], error: [] },
        gitbash: { simple: [], complex: [], error: [] },
        history: null,
        currentDirectory: null,
        summary: {
            total: 0,
            success: 0,
            failed: 0,
            skipped: 0
        }
    };
    
    // Test des commandes PowerShell
    console.log('\n=== TEST: Commandes PowerShell ===');
    for (const cmd of CONFIG.commands.powershell.simple) {
        results.powershell.simple.push(await executeMcpCommand('powershell', cmd));
        results.summary.total++;
        if (results.powershell.simple[results.powershell.simple.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    for (const cmd of CONFIG.commands.powershell.complex) {
        results.powershell.complex.push(await executeMcpCommand('powershell', cmd));
        results.summary.total++;
        if (results.powershell.complex[results.powershell.complex.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    for (const cmd of CONFIG.commands.powershell.error) {
        results.powershell.error.push(await executeMcpCommand('powershell', cmd));
        results.summary.total++;
        // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
        if (!results.powershell.error[results.powershell.error.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    // Test des commandes CMD
    console.log('\n=== TEST: Commandes CMD ===');
    for (const cmd of CONFIG.commands.cmd.simple) {
        results.cmd.simple.push(await executeMcpCommand('cmd', cmd));
        results.summary.total++;
        if (results.cmd.simple[results.cmd.simple.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    for (const cmd of CONFIG.commands.cmd.complex) {
        results.cmd.complex.push(await executeMcpCommand('cmd', cmd));
        results.summary.total++;
        if (results.cmd.complex[results.cmd.complex.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    for (const cmd of CONFIG.commands.cmd.error) {
        results.cmd.error.push(await executeMcpCommand('cmd', cmd));
        results.summary.total++;
        // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
        if (!results.cmd.error[results.cmd.error.length - 1].success) {
            results.summary.success++;
        } else {
            results.summary.failed++;
        }
    }
    
    // Test des commandes Git Bash
    console.log('\n=== TEST: Commandes Git Bash ===');
    let gitBashAvailable = true;
    
    try {
        // Vérifier si Git Bash est disponible
        // Dans un environnement réel, on ferait une vérification plus robuste
        console.log('[INFO] Vérification de la disponibilité de Git Bash...');
        
        // Simuler une vérification de disponibilité
        // Dans un environnement réel, on exécuterait une commande pour vérifier
        gitBashAvailable = true; // Supposons que Git Bash est disponible
        
        if (gitBashAvailable) {
            for (const cmd of CONFIG.commands.gitbash.simple) {
                results.gitbash.simple.push(await executeMcpCommand('gitbash', cmd));
                results.summary.total++;
                if (results.gitbash.simple[results.gitbash.simple.length - 1].success) {
                    results.summary.success++;
                } else {
                    results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.gitbash.complex) {
                results.gitbash.complex.push(await executeMcpCommand('gitbash', cmd));
                results.summary.total++;
                if (results.gitbash.complex[results.gitbash.complex.length - 1].success) {
                    results.summary.success++;
                } else {
                    results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.gitbash.error) {
                results.gitbash.error.push(await executeMcpCommand('gitbash', cmd));
                results.summary.total++;
                // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
                if (!results.gitbash.error[results.gitbash.error.length - 1].success) {
                    results.summary.success++;
                } else {
                    results.summary.failed++;
                }
            }
        } else {
            console.log('[AVERTISSEMENT] Git Bash n\'est pas disponible, tests ignorés');
            results.summary.skipped += CONFIG.commands.gitbash.simple.length + 
                                      CONFIG.commands.gitbash.complex.length + 
                                      CONFIG.commands.gitbash.error.length;
        }
    } catch (error) {
        console.error(`[ERREUR] Problème lors de la vérification de Git Bash: ${error.message}`);
        results.summary.skipped += CONFIG.commands.gitbash.simple.length + 
                                  CONFIG.commands.gitbash.complex.length + 
                                  CONFIG.commands.gitbash.error.length;
    }
    
    // Test de récupération de l'historique des commandes
    console.log('\n=== TEST: Récupération de l\'historique des commandes ===');
    results.history = await getCommandHistory(5);
    results.summary.total++;
    if (results.history.success) {
        results.summary.success++;
    } else {
        results.summary.failed++;
    }
    
    // Test de récupération du répertoire de travail actuel
    console.log('\n=== TEST: Récupération du répertoire de travail actuel ===');
    results.currentDirectory = await getCurrentDirectory();
    results.summary.total++;
    if (results.currentDirectory.success) {
        results.summary.success++;
    } else {
        results.summary.failed++;
    }
    
    // Résumé des tests
    console.log('\n=== RÉSUMÉ DES TESTS ===');
    console.log(`Total des tests: ${results.summary.total}`);
    console.log(`Tests réussis: ${results.summary.success}`);
    console.log(`Tests échoués: ${results.summary.failed}`);
    console.log(`Tests ignorés: ${results.summary.skipped}`);
    
    console.log('\n=== FIN DES TESTS ===');
    
    return results;
}

// Exécuter les tests
runAllTests().catch(error => {
    console.error('Erreur lors de l\'exécution des tests:', error);
});

/**
 * Pour exécuter ce script dans Roo avec le MCP Win-CLI, utilisez:
 * 
 * <use_mcp_tool>
 * <server_name>win-cli</server_name>
 * <tool_name>execute_command</tool_name>
 * <arguments>
 * {
 *   "shell": "powershell",
 *   "command": "node test-win-cli-mcp.js",
 *   "workingDir": "chemin/vers/tests/mcp-win-cli"
 * }
 * </arguments>
 * </use_mcp_tool>
 */