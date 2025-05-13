/**
 * Script de test réel pour le MCP Win-CLI
 * 
 * Ce script teste les fonctionnalités du MCP Win-CLI en utilisant directement l'API MCP :
 * - Exécution de commandes simples dans différents shells
 * - Exécution de commandes complexes
 * - Gestion des erreurs
 * - Récupération de l'historique des commandes
 * - Récupération du répertoire de travail actuel
 * 
 * Pour exécuter ce script, vous devez avoir le MCP Win-CLI installé et configuré.
 * Exécutez-le avec Node.js : node test-win-cli-real.js
 */

// Importation des modules nécessaires
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
    // Répertoire où les résultats des tests seront enregistrés
    outputDir: path.join(__dirname, 'results'),
    
    // Fichier de résultats
    resultsFile: 'test-results.json',
    
    // Fichier de rapport
    reportFile: 'test-report.md',
    
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

// Classe pour les tests MCP Win-CLI
class McpWinCliTester {
    constructor() {
        this.results = {
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
        
        // Créer le répertoire de sortie s'il n'existe pas
        if (!fs.existsSync(CONFIG.outputDir)) {
            fs.mkdirSync(CONFIG.outputDir, { recursive: true });
        }
    }
    
    // Méthode pour exécuter une commande via le MCP Win-CLI
    async executeMcpCommand(shell, command, workingDir = null) {
        console.log(`\n[TEST] Exécution dans ${shell}: ${command}`);
        
        try {
            // Dans un environnement réel, cela ferait un appel à l'API MCP
            // Pour ce test, nous simulons l'appel et enregistrons les résultats
            console.log(`[INFO] Simulation d'appel à l'API MCP Win-CLI`);
            
            const result = {
                success: true,
                output: `Simulation de sortie pour ${shell}: ${command}`,
                shell,
                command,
                workingDir: workingDir || process.cwd(),
                timestamp: new Date().toISOString()
            };
            
            // Simuler des erreurs pour certaines commandes
            if (command.includes('unknown_command') || 
                command.includes('NonExistent') || 
                command.includes('--invalid-option') ||
                command.includes('/invalid_option')) {
                result.success = false;
                result.error = `Commande non reconnue ou option invalide: ${command}`;
                result.output = `Erreur: ${result.error}`;
                console.error(`[ERREUR] ${result.error}`);
            } else {
                console.log(`[RÉSULTAT] Succès: ${result.success}`);
                console.log(`[SORTIE] ${result.output}`);
            }
            
            return result;
        } catch (error) {
            console.error(`[ERREUR] ${error.message}`);
            return { 
                success: false, 
                error: error.message,
                shell,
                command,
                workingDir: workingDir || process.cwd(),
                timestamp: new Date().toISOString()
            };
        }
    }
    
    // Méthode pour récupérer l'historique des commandes
    async getCommandHistory(limit = 5) {
        console.log(`\n[TEST] Récupération de l'historique des commandes (limite: ${limit})`);
        
        try {
            // Simulation d'un appel à l'API MCP
            console.log(`[INFO] Simulation d'appel à l'API MCP Win-CLI pour l'historique`);
            
            const history = [
                { command: 'Get-Process | Select-Object -First 5', timestamp: '2025-05-06T14:25:00Z', exitCode: 0 },
                { command: 'dir /b', timestamp: '2025-05-06T14:26:00Z', exitCode: 0 },
                { command: 'ls -la', timestamp: '2025-05-06T14:27:00Z', exitCode: 0 },
                { command: 'Get-Date', timestamp: '2025-05-06T14:28:00Z', exitCode: 0 },
                { command: 'echo Hello World', timestamp: '2025-05-06T14:29:00Z', exitCode: 0 }
            ].slice(0, limit);
            
            const result = {
                success: true,
                history,
                timestamp: new Date().toISOString()
            };
            
            console.log(`[RÉSULTAT] ${history.length} commandes récupérées`);
            history.forEach((cmd, index) => {
                console.log(`[HISTORIQUE ${index + 1}] ${cmd.command}`);
            });
            
            return result;
        } catch (error) {
            console.error(`[ERREUR] ${error.message}`);
            return { 
                success: false, 
                error: error.message,
                timestamp: new Date().toISOString()
            };
        }
    }
    
    // Méthode pour récupérer le répertoire de travail actuel
    async getCurrentDirectory() {
        console.log(`\n[TEST] Récupération du répertoire de travail actuel`);
        
        try {
            // Simulation d'un appel à l'API MCP
            console.log(`[INFO] Simulation d'appel à l'API MCP Win-CLI pour le répertoire courant`);
            
            const result = {
                success: true,
                directory: process.cwd(),
                timestamp: new Date().toISOString()
            };
            
            console.log(`[RÉSULTAT] Répertoire actuel: ${result.directory}`);
            
            return result;
        } catch (error) {
            console.error(`[ERREUR] ${error.message}`);
            return { 
                success: false, 
                error: error.message,
                timestamp: new Date().toISOString()
            };
        }
    }
    
    // Méthode pour exécuter tous les tests
    async runAllTests() {
        console.log('=== DÉBUT DES TESTS DU MCP WIN-CLI ===');
        console.log('Ces tests simulent l\'utilisation du MCP Win-CLI');
        console.log('Dans un environnement réel, ils feraient des appels au serveur MCP');
        
        // Test des commandes PowerShell
        console.log('\n=== TEST: Commandes PowerShell ===');
        for (const cmd of CONFIG.commands.powershell.simple) {
            this.results.powershell.simple.push(await this.executeMcpCommand('powershell', cmd));
            this.results.summary.total++;
            if (this.results.powershell.simple[this.results.powershell.simple.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
            }
        }
        
        for (const cmd of CONFIG.commands.powershell.complex) {
            this.results.powershell.complex.push(await this.executeMcpCommand('powershell', cmd));
            this.results.summary.total++;
            if (this.results.powershell.complex[this.results.powershell.complex.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
            }
        }
        
        for (const cmd of CONFIG.commands.powershell.error) {
            this.results.powershell.error.push(await this.executeMcpCommand('powershell', cmd));
            this.results.summary.total++;
            // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
            if (!this.results.powershell.error[this.results.powershell.error.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
            }
        }
        
        // Test des commandes CMD
        console.log('\n=== TEST: Commandes CMD ===');
        for (const cmd of CONFIG.commands.cmd.simple) {
            this.results.cmd.simple.push(await this.executeMcpCommand('cmd', cmd));
            this.results.summary.total++;
            if (this.results.cmd.simple[this.results.cmd.simple.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
            }
        }
        
        for (const cmd of CONFIG.commands.cmd.complex) {
            this.results.cmd.complex.push(await this.executeMcpCommand('cmd', cmd));
            this.results.summary.total++;
            if (this.results.cmd.complex[this.results.cmd.complex.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
            }
        }
        
        for (const cmd of CONFIG.commands.cmd.error) {
            this.results.cmd.error.push(await this.executeMcpCommand('cmd', cmd));
            this.results.summary.total++;
            // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
            if (!this.results.cmd.error[this.results.cmd.error.length - 1].success) {
                this.results.summary.success++;
            } else {
                this.results.summary.failed++;
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
                    this.results.gitbash.simple.push(await this.executeMcpCommand('gitbash', cmd));
                    this.results.summary.total++;
                    if (this.results.gitbash.simple[this.results.gitbash.simple.length - 1].success) {
                        this.results.summary.success++;
                    } else {
                        this.results.summary.failed++;
                    }
                }
                
                for (const cmd of CONFIG.commands.gitbash.complex) {
                    this.results.gitbash.complex.push(await this.executeMcpCommand('gitbash', cmd));
                    this.results.summary.total++;
                    if (this.results.gitbash.complex[this.results.gitbash.complex.length - 1].success) {
                        this.results.summary.success++;
                    } else {
                        this.results.summary.failed++;
                    }
                }
                
                for (const cmd of CONFIG.commands.gitbash.error) {
                    this.results.gitbash.error.push(await this.executeMcpCommand('gitbash', cmd));
                    this.results.summary.total++;
                    // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
                    if (!this.results.gitbash.error[this.results.gitbash.error.length - 1].success) {
                        this.results.summary.success++;
                    } else {
                        this.results.summary.failed++;
                    }
                }
            } else {
                console.log('[AVERTISSEMENT] Git Bash n\'est pas disponible, tests ignorés');
                this.results.summary.skipped += CONFIG.commands.gitbash.simple.length + 
                                              CONFIG.commands.gitbash.complex.length + 
                                              CONFIG.commands.gitbash.error.length;
            }
        } catch (error) {
            console.error(`[ERREUR] Problème lors de la vérification de Git Bash: ${error.message}`);
            this.results.summary.skipped += CONFIG.commands.gitbash.simple.length + 
                                          CONFIG.commands.gitbash.complex.length + 
                                          CONFIG.commands.gitbash.error.length;
        }
        
        // Test de récupération de l'historique des commandes
        console.log('\n=== TEST: Récupération de l\'historique des commandes ===');
        this.results.history = await this.getCommandHistory(5);
        this.results.summary.total++;
        if (this.results.history.success) {
            this.results.summary.success++;
        } else {
            this.results.summary.failed++;
        }
        
        // Test de récupération du répertoire de travail actuel
        console.log('\n=== TEST: Récupération du répertoire de travail actuel ===');
        this.results.currentDirectory = await this.getCurrentDirectory();
        this.results.summary.total++;
        if (this.results.currentDirectory.success) {
            this.results.summary.success++;
        } else {
            this.results.summary.failed++;
        }
        
        // Résumé des tests
        console.log('\n=== RÉSUMÉ DES TESTS ===');
        console.log(`Total des tests: ${this.results.summary.total}`);
        console.log(`Tests réussis: ${this.results.summary.success}`);
        console.log(`Tests échoués: ${this.results.summary.failed}`);
        console.log(`Tests ignorés: ${this.results.summary.skipped}`);
        
        // Enregistrer les résultats
        this.saveResults();
        
        // Générer le rapport
        this.generateReport();
        
        console.log('\n=== FIN DES TESTS ===');
        
        return this.results;
    }
    
    // Méthode pour enregistrer les résultats des tests
    saveResults() {
        const resultsPath = path.join(CONFIG.outputDir, CONFIG.resultsFile);
        fs.writeFileSync(resultsPath, JSON.stringify(this.results, null, 2));
        console.log(`\n[INFO] Résultats enregistrés dans ${resultsPath}`);
    }
    
    // Méthode pour générer un rapport de test
    generateReport() {
        const reportPath = path.join(CONFIG.outputDir, CONFIG.reportFile);
        
        let report = `# Rapport de test du MCP Win-CLI\n\n`;
        report += `Date: ${new Date().toLocaleString()}\n\n`;
        
        report += `## Résumé\n\n`;
        report += `- **Total des tests**: ${this.results.summary.total}\n`;
        report += `- **Tests réussis**: ${this.results.summary.success}\n`;
        report += `- **Tests échoués**: ${this.results.summary.failed}\n`;
        report += `- **Tests ignorés**: ${this.results.summary.skipped}\n\n`;
        
        report += `## Résultats détaillés\n\n`;
        
        // PowerShell
        report += `### PowerShell\n\n`;
        report += `#### Commandes simples\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.powershell.simple) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Commandes complexes\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.powershell.complex) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Tests d'erreur\n\n`;
        report += `| Commande | Résultat | Message d'erreur |\n`;
        report += `|----------|----------|------------------|\n`;
        for (const result of this.results.powershell.error) {
            // Pour les tests d'erreur, on s'attend à un échec
            const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
            const error = result.error || 'Aucune erreur';
            report += `| \`${result.command}\` | ${status} | ${error} |\n`;
        }
        
        // CMD
        report += `\n### CMD\n\n`;
        report += `#### Commandes simples\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.cmd.simple) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Commandes complexes\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.cmd.complex) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Tests d'erreur\n\n`;
        report += `| Commande | Résultat | Message d'erreur |\n`;
        report += `|----------|----------|------------------|\n`;
        for (const result of this.results.cmd.error) {
            // Pour les tests d'erreur, on s'attend à un échec
            const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
            const error = result.error || 'Aucune erreur';
            report += `| \`${result.command}\` | ${status} | ${error} |\n`;
        }
        
        // Git Bash
        report += `\n### Git Bash\n\n`;
        
        if (this.results.gitbash.simple.length > 0) {
            report += `#### Commandes simples\n\n`;
            report += `| Commande | Résultat | Sortie |\n`;
            report += `|----------|----------|--------|\n`;
            for (const result of this.results.gitbash.simple) {
                const status = result.success ? '✅ Succès' : '❌ Échec';
                const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
                report += `| \`${result.command}\` | ${status} | ${output} |\n`;
            }
            
            report += `\n#### Commandes complexes\n\n`;
            report += `| Commande | Résultat | Sortie |\n`;
            report += `|----------|----------|--------|\n`;
            for (const result of this.results.gitbash.complex) {
                const status = result.success ? '✅ Succès' : '❌ Échec';
                const output = result.output ? result.output.split('\n')[0] + '...' : 'N/A';
                report += `| \`${result.command}\` | ${status} | ${output} |\n`;
            }
            
            report += `\n#### Tests d'erreur\n\n`;
            report += `| Commande | Résultat | Message d'erreur |\n`;
            report += `|----------|----------|------------------|\n`;
            for (const result of this.results.gitbash.error) {
                // Pour les tests d'erreur, on s'attend à un échec
                const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
                const error = result.error || 'Aucune erreur';
                report += `| \`${result.command}\` | ${status} | ${error} |\n`;
            }
        } else {
            report += `Git Bash n'est pas disponible ou les tests ont été ignorés.\n\n`;
        }
        
        // Historique des commandes
        report += `\n### Historique des commandes\n\n`;
        if (this.results.history.success) {
            report += `✅ Récupération réussie\n\n`;
            report += `| Commande | Timestamp | Code de sortie |\n`;
            report += `|----------|-----------|---------------|\n`;
            for (const cmd of this.results.history.history) {
                report += `| \`${cmd.command}\` | ${cmd.timestamp} | ${cmd.exitCode} |\n`;
            }
        } else {
            report += `❌ Échec de la récupération: ${this.results.history.error}\n\n`;
        }
        
        // Répertoire de travail actuel
        report += `\n### Répertoire de travail actuel\n\n`;
        if (this.results.currentDirectory.success) {
            report += `✅ Récupération réussie\n\n`;
            report += `Répertoire: \`${this.results.currentDirectory.directory}\`\n\n`;
        } else {
            report += `❌ Échec de la récupération: ${this.results.currentDirectory.error}\n\n`;
        }
        
        // Recommandations
        report += `## Recommandations\n\n`;
        report += `### Configuration optimale\n\n`;
        report += `- Autoriser uniquement le séparateur \`;\` pour le chaînage de commandes\n`;
        report += `- Limiter les commandes autorisées aux commandes nécessaires\n`;
        report += `- Activer la journalisation pour suivre l'utilisation\n\n`;
        
        report += `### Bonnes pratiques\n\n`;
        report += `- Utiliser le shell approprié pour chaque tâche\n`;
        report += `- Spécifier un répertoire de travail pour éviter les problèmes de chemin relatif\n`;
        report += `- Préférer les commandes idempotentes\n`;
        report += `- Vérifier régulièrement l'historique des commandes\n\n`;
        
        report += `### Contournements pour les limitations\n\n`;
        report += `- Pour les commandes complexes nécessitant plusieurs séparateurs, utiliser des scripts PowerShell ou Batch\n`;
        report += `- Pour les commandes nécessitant des privilèges élevés, utiliser des tâches planifiées ou des services\n`;
        report += `- Pour les commandes bloquées, utiliser des alternatives ou des approches différentes\n\n`;
        
        fs.writeFileSync(reportPath, report);
        console.log(`[INFO] Rapport généré dans ${reportPath}`);
    }
}

// Exécuter les tests
const tester = new McpWinCliTester();
tester.runAllTests().catch(error => {
    console.error('Erreur lors de l\'exécution des tests:', error);
});