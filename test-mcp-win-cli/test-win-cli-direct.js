/**
 * Script de test direct pour le MCP Win-CLI
 * 
 * Ce script est conçu pour être exécuté directement avec Node.js et teste les fonctionnalités
 * du MCP Win-CLI en exécutant des commandes réelles sur le système.
 * 
 * IMPORTANT: Ce script doit être exécuté avec Node.js, pas via Roo.
 * Il simule les appels que Roo ferait au MCP Win-CLI.
 */

const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const util = require('util');

// Promisify exec pour utiliser async/await
const execPromise = util.promisify(exec);

// Configuration
const CONFIG = {
    // Répertoire où les résultats des tests seront enregistrés
    outputDir: path.join(__dirname, 'results'),
    
    // Fichier de résultats
    resultsFile: 'direct-test-results.json',
    
    // Fichier de rapport
    reportFile: 'direct-test-report.md',
    
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
    },
    
    // Chemins des shells
    shellPaths: {
        powershell: 'powershell.exe',
        cmd: 'cmd.exe',
        gitbash: 'C:\\Program Files\\Git\\bin\\bash.exe' // Ajustez selon votre installation
    },
    
    // Arguments des shells
    shellArgs: {
        powershell: ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command'],
        cmd: ['/c'],
        gitbash: ['-c']
    }
};

// Classe pour les tests directs du MCP Win-CLI
class DirectWinCliTester {
    constructor() {
        this.results = {
            timestamp: new Date().toISOString(),
            powershell: { simple: [], complex: [], error: [] },
            cmd: { simple: [], complex: [], error: [] },
            gitbash: { simple: [], complex: [], error: [] },
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
    
    // Méthode pour exécuter une commande directement
    async executeCommand(shell, command, workingDir = null) {
        console.log(`\n[TEST] Exécution dans ${shell}: ${command}`);
        
        try {
            // Vérifier si le shell est disponible
            if (!CONFIG.shellPaths[shell]) {
                throw new Error(`Shell non configuré: ${shell}`);
            }
            
            // Construire la commande complète
            const shellPath = CONFIG.shellPaths[shell];
            const shellArgs = CONFIG.shellArgs[shell];
            
            // Options pour exec
            const options = {};
            if (workingDir) {
                options.cwd = workingDir;
            }
            
            // Exécuter la commande
            let fullCommand;
            if (shell === 'powershell') {
                fullCommand = `${shellPath} ${shellArgs.join(' ')} "${command.replace(/"/g, '\\"')}"`;
            } else if (shell === 'cmd') {
                fullCommand = `${shellPath} ${shellArgs.join(' ')} "${command.replace(/"/g, '\\"')}"`;
            } else if (shell === 'gitbash') {
                fullCommand = `${shellPath} ${shellArgs.join(' ')} "${command.replace(/"/g, '\\"')}"`;
            } else {
                throw new Error(`Shell non pris en charge: ${shell}`);
            }
            
            console.log(`[INFO] Exécution de la commande: ${fullCommand}`);
            
            const { stdout, stderr } = await execPromise(fullCommand, options);
            
            const result = {
                success: stderr.length === 0,
                output: stdout,
                error: stderr,
                shell,
                command,
                workingDir: workingDir || process.cwd(),
                timestamp: new Date().toISOString()
            };
            
            if (result.success) {
                console.log(`[RÉSULTAT] Succès`);
                console.log(`[SORTIE] ${result.output}`);
            } else {
                console.error(`[ERREUR] ${result.error}`);
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
    
    // Méthode pour exécuter tous les tests
    async runAllTests() {
        console.log('=== DÉBUT DES TESTS DIRECTS DU WIN-CLI ===');
        
        // Test des commandes PowerShell
        console.log('\n=== TEST: Commandes PowerShell ===');
        try {
            for (const cmd of CONFIG.commands.powershell.simple) {
                this.results.powershell.simple.push(await this.executeCommand('powershell', cmd));
                this.results.summary.total++;
                if (this.results.powershell.simple[this.results.powershell.simple.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.powershell.complex) {
                this.results.powershell.complex.push(await this.executeCommand('powershell', cmd));
                this.results.summary.total++;
                if (this.results.powershell.complex[this.results.powershell.complex.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.powershell.error) {
                this.results.powershell.error.push(await this.executeCommand('powershell', cmd));
                this.results.summary.total++;
                // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
                if (!this.results.powershell.error[this.results.powershell.error.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
        } catch (error) {
            console.error(`[ERREUR] Problème lors des tests PowerShell: ${error.message}`);
            this.results.summary.skipped += CONFIG.commands.powershell.simple.length + 
                                          CONFIG.commands.powershell.complex.length + 
                                          CONFIG.commands.powershell.error.length - 
                                          this.results.powershell.simple.length - 
                                          this.results.powershell.complex.length - 
                                          this.results.powershell.error.length;
        }
        
        // Test des commandes CMD
        console.log('\n=== TEST: Commandes CMD ===');
        try {
            for (const cmd of CONFIG.commands.cmd.simple) {
                this.results.cmd.simple.push(await this.executeCommand('cmd', cmd));
                this.results.summary.total++;
                if (this.results.cmd.simple[this.results.cmd.simple.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.cmd.complex) {
                this.results.cmd.complex.push(await this.executeCommand('cmd', cmd));
                this.results.summary.total++;
                if (this.results.cmd.complex[this.results.cmd.complex.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
            
            for (const cmd of CONFIG.commands.cmd.error) {
                this.results.cmd.error.push(await this.executeCommand('cmd', cmd));
                this.results.summary.total++;
                // Pour les tests d'erreur, on s'attend à un échec, donc on inverse la logique
                if (!this.results.cmd.error[this.results.cmd.error.length - 1].success) {
                    this.results.summary.success++;
                } else {
                    this.results.summary.failed++;
                }
            }
        } catch (error) {
            console.error(`[ERREUR] Problème lors des tests CMD: ${error.message}`);
            this.results.summary.skipped += CONFIG.commands.cmd.simple.length + 
                                          CONFIG.commands.cmd.complex.length + 
                                          CONFIG.commands.cmd.error.length - 
                                          this.results.cmd.simple.length - 
                                          this.results.cmd.complex.length - 
                                          this.results.cmd.error.length;
        }
        
        // Test des commandes Git Bash
        console.log('\n=== TEST: Commandes Git Bash ===');
        let gitBashAvailable = true;
        
        try {
            // Vérifier si Git Bash est disponible
            console.log('[INFO] Vérification de la disponibilité de Git Bash...');
            
            try {
                await execPromise(`"${CONFIG.shellPaths.gitbash}" --version`);
                gitBashAvailable = true;
            } catch (error) {
                console.error(`[ERREUR] Git Bash n'est pas disponible: ${error.message}`);
                gitBashAvailable = false;
            }
            
            if (gitBashAvailable) {
                for (const cmd of CONFIG.commands.gitbash.simple) {
                    this.results.gitbash.simple.push(await this.executeCommand('gitbash', cmd));
                    this.results.summary.total++;
                    if (this.results.gitbash.simple[this.results.gitbash.simple.length - 1].success) {
                        this.results.summary.success++;
                    } else {
                        this.results.summary.failed++;
                    }
                }
                
                for (const cmd of CONFIG.commands.gitbash.complex) {
                    this.results.gitbash.complex.push(await this.executeCommand('gitbash', cmd));
                    this.results.summary.total++;
                    if (this.results.gitbash.complex[this.results.gitbash.complex.length - 1].success) {
                        this.results.summary.success++;
                    } else {
                        this.results.summary.failed++;
                    }
                }
                
                for (const cmd of CONFIG.commands.gitbash.error) {
                    this.results.gitbash.error.push(await this.executeCommand('gitbash', cmd));
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
            console.error(`[ERREUR] Problème lors des tests Git Bash: ${error.message}`);
            this.results.summary.skipped += CONFIG.commands.gitbash.simple.length + 
                                          CONFIG.commands.gitbash.complex.length + 
                                          CONFIG.commands.gitbash.error.length - 
                                          this.results.gitbash.simple.length - 
                                          this.results.gitbash.complex.length - 
                                          this.results.gitbash.error.length;
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
        
        let report = `# Rapport de test direct du Win-CLI\n\n`;
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
            const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Commandes complexes\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.powershell.complex) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Tests d'erreur\n\n`;
        report += `| Commande | Résultat | Message d'erreur |\n`;
        report += `|----------|----------|------------------|\n`;
        for (const result of this.results.powershell.error) {
            // Pour les tests d'erreur, on s'attend à un échec
            const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
            const error = result.error ? result.error.substring(0, 50) + '...' : 'Aucune erreur';
            report += `| \`${result.command}\` | ${status} | ${error} |\n`;
        }
        
        // CMD
        report += `\n### CMD\n\n`;
        report += `#### Commandes simples\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.cmd.simple) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Commandes complexes\n\n`;
        report += `| Commande | Résultat | Sortie |\n`;
        report += `|----------|----------|--------|\n`;
        for (const result of this.results.cmd.complex) {
            const status = result.success ? '✅ Succès' : '❌ Échec';
            const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
            report += `| \`${result.command}\` | ${status} | ${output} |\n`;
        }
        
        report += `\n#### Tests d'erreur\n\n`;
        report += `| Commande | Résultat | Message d'erreur |\n`;
        report += `|----------|----------|------------------|\n`;
        for (const result of this.results.cmd.error) {
            // Pour les tests d'erreur, on s'attend à un échec
            const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
            const error = result.error ? result.error.substring(0, 50) + '...' : 'Aucune erreur';
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
                const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
                report += `| \`${result.command}\` | ${status} | ${output} |\n`;
            }
            
            report += `\n#### Commandes complexes\n\n`;
            report += `| Commande | Résultat | Sortie |\n`;
            report += `|----------|----------|--------|\n`;
            for (const result of this.results.gitbash.complex) {
                const status = result.success ? '✅ Succès' : '❌ Échec';
                const output = result.output ? result.output.split('\n')[0].substring(0, 50) + '...' : 'N/A';
                report += `| \`${result.command}\` | ${status} | ${output} |\n`;
            }
            
            report += `\n#### Tests d'erreur\n\n`;
            report += `| Commande | Résultat | Message d'erreur |\n`;
            report += `|----------|----------|------------------|\n`;
            for (const result of this.results.gitbash.error) {
                // Pour les tests d'erreur, on s'attend à un échec
                const status = !result.success ? '✅ Échec attendu' : '❌ Succès inattendu';
                const error = result.error ? result.error.substring(0, 50) + '...' : 'Aucune erreur';
                report += `| \`${result.command}\` | ${status} | ${error} |\n`;
            }
        } else {
            report += `Git Bash n'est pas disponible ou les tests ont été ignorés.\n\n`;
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
const tester = new DirectWinCliTester();
tester.runAllTests().catch(error => {
    console.error('Erreur lors de l\'exécution des tests:', error);
});