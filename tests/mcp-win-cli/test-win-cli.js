/**
 * Script de test automatisé pour le MCP Win-CLI
 * 
 * Ce script teste les fonctionnalités du MCP Win-CLI :
 * - Exécution de commandes simples dans différents shells
 * - Exécution de commandes complexes
 * - Gestion des erreurs
 * - Récupération de l'historique des commandes
 * - Récupération du répertoire de travail actuel
 */

// Simuler l'utilisation du MCP Win-CLI via des appels d'API
// Dans un environnement réel, ces fonctions feraient des appels au serveur MCP
async function executeMcpCommand(shell, command, workingDir = null) {
    console.log(`\n[TEST] Exécution dans ${shell}: ${command}`);
    
    try {
        // Simulation d'un appel au MCP Win-CLI
        // Dans un environnement réel, cela serait remplacé par un appel à l'API MCP
        const result = await simulateApiCall('execute_command', {
            shell,
            command,
            workingDir
        });
        
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

async function getCommandHistory(limit = 5) {
    console.log(`\n[TEST] Récupération de l'historique des commandes (limite: ${limit})`);
    
    try {
        const result = await simulateApiCall('get_command_history', { limit });
        
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

async function getCurrentDirectory() {
    console.log(`\n[TEST] Récupération du répertoire de travail actuel`);
    
    try {
        const result = await simulateApiCall('get_current_directory', {});
        
        console.log(`[RÉSULTAT] Répertoire actuel: ${result.directory}`);
        
        return result;
    } catch (error) {
        console.error(`[ERREUR] ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Fonction de simulation d'appel API pour les tests
// Cette fonction simule le comportement du MCP Win-CLI sans faire d'appels réels
async function simulateApiCall(toolName, args) {
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
        'commande-inexistante',
        'rm -rf /',
        'del /f /s /q C:\\Windows\\*'
    ];
    
    if (errorCommands.some(cmd => command.includes(cmd))) {
        throw new Error(`Commande non autorisée ou inexistante: ${command}`);
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
    console.log('Ces tests simulent l\'utilisation du MCP Win-CLI');
    console.log('Dans un environnement réel, ils feraient des appels au serveur MCP');
    
    const testResults = {
        powershell: { simple: [], complex: [], error: [] },
        cmd: { simple: [], complex: [], error: [] },
        gitbash: { simple: [], complex: [], error: [] },
        history: null,
        currentDirectory: null
    };
    
    // Test 1: Commandes simples dans PowerShell
    console.log('\n=== TEST 1: Commandes simples dans PowerShell ===');
    testResults.powershell.simple.push(await executeMcpCommand('powershell', 'Get-Date'));
    testResults.powershell.simple.push(await executeMcpCommand('powershell', 'Write-Host "Hello from PowerShell"'));
    
    // Test 2: Commandes simples dans CMD
    console.log('\n=== TEST 2: Commandes simples dans CMD ===');
    testResults.cmd.simple.push(await executeMcpCommand('cmd', 'echo Hello from CMD'));
    testResults.cmd.simple.push(await executeMcpCommand('cmd', 'dir /b'));
    
    // Test 3: Commandes simples dans Git Bash
    console.log('\n=== TEST 3: Commandes simples dans Git Bash ===');
    testResults.gitbash.simple.push(await executeMcpCommand('gitbash', 'echo "Hello from Git Bash"'));
    testResults.gitbash.simple.push(await executeMcpCommand('gitbash', 'ls -la'));
    
    // Test 4: Commandes complexes dans PowerShell
    console.log('\n=== TEST 4: Commandes complexes dans PowerShell ===');
    testResults.powershell.complex.push(await executeMcpCommand('powershell', 'Get-Process | Select-Object -First 5'));
    testResults.powershell.complex.push(await executeMcpCommand('powershell', '$a = 5; $b = 10; Write-Host "La somme est: $($a + $b)"'));
    
    // Test 5: Commandes complexes dans CMD
    console.log('\n=== TEST 5: Commandes complexes dans CMD ===');
    testResults.cmd.complex.push(await executeMcpCommand('cmd', 'dir /a /o:n'));
    testResults.cmd.complex.push(await executeMcpCommand('cmd', 'echo Premier & echo Second'));
    
    // Test 6: Commandes complexes dans Git Bash
    console.log('\n=== TEST 6: Commandes complexes dans Git Bash ===');
    testResults.gitbash.complex.push(await executeMcpCommand('gitbash', 'for i in {1..3}; do echo "Itération $i"; done'));
    testResults.gitbash.complex.push(await executeMcpCommand('gitbash', 'find . -type f -name "*.js" | wc -l'));
    
    // Test 7: Gestion des erreurs
    console.log('\n=== TEST 7: Gestion des erreurs ===');
    try {
        testResults.powershell.error.push(await executeMcpCommand('powershell', 'commande-inexistante'));
    } catch (error) {
        console.log(`[ATTENDU] Erreur capturée: ${error.message}`);
    }
    
    try {
        testResults.cmd.error.push(await executeMcpCommand('cmd', 'del /f /s /q C:\\Windows\\*'));
    } catch (error) {
        console.log(`[ATTENDU] Erreur capturée: ${error.message}`);
    }
    
    try {
        testResults.gitbash.error.push(await executeMcpCommand('gitbash', 'rm -rf /'));
    } catch (error) {
        console.log(`[ATTENDU] Erreur capturée: ${error.message}`);
    }
    
    // Test 8: Récupération de l'historique des commandes
    console.log('\n=== TEST 8: Récupération de l\'historique des commandes ===');
    testResults.history = await getCommandHistory(5);
    
    // Test 9: Récupération du répertoire de travail actuel
    console.log('\n=== TEST 9: Récupération du répertoire de travail actuel ===');
    testResults.currentDirectory = await getCurrentDirectory();
    
    // Résumé des tests
    console.log('\n=== RÉSUMÉ DES TESTS ===');
    console.log(`PowerShell - Commandes simples: ${testResults.powershell.simple.filter(r => r.success).length}/${testResults.powershell.simple.length} réussies`);
    console.log(`PowerShell - Commandes complexes: ${testResults.powershell.complex.filter(r => r.success).length}/${testResults.powershell.complex.length} réussies`);
    console.log(`CMD - Commandes simples: ${testResults.cmd.simple.filter(r => r.success).length}/${testResults.cmd.simple.length} réussies`);
    console.log(`CMD - Commandes complexes: ${testResults.cmd.complex.filter(r => r.success).length}/${testResults.cmd.complex.length} réussies`);
    console.log(`Git Bash - Commandes simples: ${testResults.gitbash.simple.filter(r => r.success).length}/${testResults.gitbash.simple.length} réussies`);
    console.log(`Git Bash - Commandes complexes: ${testResults.gitbash.complex.filter(r => r.success).length}/${testResults.gitbash.complex.length} réussies`);
    console.log(`Récupération de l'historique: ${testResults.history?.success ? 'Réussie' : 'Échouée'}`);
    console.log(`Récupération du répertoire actuel: ${testResults.currentDirectory?.success ? 'Réussie' : 'Échouée'}`);
    
    console.log('\n=== FIN DES TESTS ===');
    
    return testResults;
}

// Exécuter les tests
runAllTests().catch(error => {
    console.error('Erreur lors de l\'exécution des tests:', error);
});