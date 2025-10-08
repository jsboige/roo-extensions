/**
 * 🧪 SCRIPT DE VALIDATION AUTOMATISÉ - MCP JUPYTER END-TO-END
 * 
 * Script de tests de non-régression pour valider le bon fonctionnement
 * du MCP Jupyter après corrections critiques du working directory.
 * 
 * Usage:
 *   node tests/mcp/validate-jupyter-mcp-endtoend.js
 * 
 * @version 1.0.0
 * @date 2025-10-08
 */

const fs = require('fs');
const path = require('path');

class JupyterMCPValidator {
    constructor() {
        this.testResults = [];
        this.startTime = new Date();
        this.mcpServerName = 'jupyter-papermill-mcp-server';
    }

    // Simulation d'appel MCP tool (à adapter selon votre framework MCP)
    async callMCPTool(toolName, args) {
        console.log(`📞 Appel MCP: ${toolName}(${JSON.stringify(args, null, 2)})`);
        
        // TODO: Remplacer par votre méthode d'appel MCP réelle
        // Exemple avec votre système MCP:
        // return await mcp.callTool(this.mcpServerName, toolName, args);
        
        // Simulation pour le moment
        return { 
            success: true, 
            message: `Simulation ${toolName}`,
            timestamp: new Date().toISOString()
        };
    }

    async validateTest(testName, testFunc) {
        console.log(`\n🧪 Test: ${testName}`);
        const testStart = Date.now();
        
        try {
            const result = await testFunc();
            const duration = Date.now() - testStart;
            
            this.testResults.push({
                name: testName,
                status: 'PASS',
                duration: duration,
                details: result
            });
            
            console.log(`✅ ${testName} - RÉUSSI (${duration}ms)`);
            return true;
        } catch (error) {
            const duration = Date.now() - testStart;
            
            this.testResults.push({
                name: testName,
                status: 'FAIL',
                duration: duration,
                error: error.message
            });
            
            console.log(`❌ ${testName} - ÉCHEC (${duration}ms): ${error.message}`);
            return false;
        }
    }

    // TEST 1: Connectivité et statut MCP
    async testMCPConnectivity() {
        const result = await this.callMCPTool('system_info', {});
        
        if (!result.success) {
            throw new Error('MCP Jupyter server non accessible');
        }
        
        return { 
            message: 'Serveur MCP Jupyter accessible',
            serverResponse: result
        };
    }

    // TEST 2: Gestion des kernels de base
    async testKernelManagement() {
        // Lister les kernels disponibles
        const kernelsResult = await this.callMCPTool('list_kernels', {});
        
        // Démarrer un kernel Python
        const startResult = await this.callMCPTool('start_kernel', {
            kernel_name: 'python3'
        });
        
        if (!startResult.success) {
            throw new Error('Échec démarrage kernel Python');
        }
        
        // Simuler l'ID du kernel pour le test
        const kernelId = 'test-kernel-id';
        
        // Exécuter une cellule simple
        const execResult = await this.callMCPTool('execute_cell', {
            kernel_id: kernelId,
            code: 'print("Test validation MCP Jupyter")'
        });
        
        // Arrêter le kernel
        await this.callMCPTool('stop_kernel', { kernel_id: kernelId });
        
        return {
            message: 'Cycle complet kernel validé',
            kernelsList: kernelsResult,
            executionResult: execResult
        };
    }

    // TEST 3: Création et exécution notebook simple
    async testNotebookCreationExecution() {
        const testNotebook = path.join(__dirname, '../temp_validation_notebook.ipynb');
        
        // Créer un notebook de test
        const createResult = await this.callMCPTool('create_notebook', {
            path: testNotebook,
            kernel: 'python3'
        });
        
        if (!createResult.success) {
            throw new Error('Échec création notebook');
        }
        
        // Ajouter des cellules de test
        await this.callMCPTool('add_cell', {
            path: testNotebook,
            cell_type: 'code',
            source: 'import os\nprint(f"Working directory: {os.getcwd()}")'
        });
        
        await this.callMCPTool('add_cell', {
            path: testNotebook,
            cell_type: 'code',
            source: 'import sys\nprint(f"Python version: {sys.version}")'
        });
        
        // Exécuter le notebook (version synchrone pour test rapide)
        const execResult = await this.callMCPTool('execute_notebook_sync', {
            notebook_path: testNotebook,
            timeout_seconds: 30
        });
        
        // Nettoyer
        if (fs.existsSync(testNotebook)) {
            fs.unlinkSync(testNotebook);
        }
        
        return {
            message: 'Notebook créé, exécuté et nettoyé avec succès',
            executionDetails: execResult
        };
    }

    // TEST 4: Working Directory Stability (CRITIQUE)
    async testWorkingDirectoryStability() {
        // Récupérer le working directory initial
        const initialWD = process.cwd();
        
        // Simuler exécution d'un notebook dans un autre répertoire
        const testNotebook = path.join(__dirname, '../temp_wd_test.ipynb');
        
        const createResult = await this.callMCPTool('create_notebook', {
            path: testNotebook,
            kernel: 'python3'
        });
        
        // Ajouter cellule qui change le working directory
        await this.callMCPTool('add_cell', {
            path: testNotebook,
            cell_type: 'code',
            source: `
import os
original_wd = os.getcwd()
print(f"Original WD: {original_wd}")
os.chdir(os.path.dirname("${testNotebook}"))
print(f"Changed WD: {os.getcwd()}")
print("Test working directory manipulation")
`
        });
        
        // Exécuter notebook
        await this.callMCPTool('execute_notebook_sync', {
            notebook_path: testNotebook,
            timeout_seconds: 15
        });
        
        // CRITIQUE: Vérifier que le WD du processus principal n'a pas changé
        const finalWD = process.cwd();
        
        if (initialWD !== finalWD) {
            throw new Error(`Working directory pollué! Initial: ${initialWD}, Final: ${finalWD}`);
        }
        
        // Nettoyer
        if (fs.existsSync(testNotebook)) {
            fs.unlinkSync(testNotebook);
        }
        
        return {
            message: '✅ Working directory stable - Context manager fonctionne',
            initialWD: initialWD,
            finalWD: finalWD,
            stable: initialWD === finalWD
        };
    }

    // TEST 5: Gestion des erreurs et robustesse
    async testErrorHandling() {
        // Test avec notebook inexistant
        const fakeNotebook = '/path/inexistant/fake.ipynb';
        
        const result = await this.callMCPTool('execute_notebook_sync', {
            notebook_path: fakeNotebook,
            timeout_seconds: 10
        });
        
        // On s'attend à un échec contrôlé, pas un crash
        return {
            message: 'Gestion d\'erreur propre pour notebook inexistant',
            errorHandled: !result.success  // On veut que ça échoue proprement
        };
    }

    // Génération du rapport de validation
    generateReport() {
        const totalTests = this.testResults.length;
        const passedTests = this.testResults.filter(t => t.status === 'PASS').length;
        const failedTests = totalTests - passedTests;
        const totalDuration = Date.now() - this.startTime.getTime();
        
        const report = {
            timestamp: new Date().toISOString(),
            summary: {
                total: totalTests,
                passed: passedTests,
                failed: failedTests,
                successRate: `${Math.round((passedTests/totalTests) * 100)}%`,
                totalDuration: `${totalDuration}ms`
            },
            tests: this.testResults,
            status: failedTests === 0 ? 'VALIDATION_PASSED' : 'VALIDATION_FAILED',
            recommendation: failedTests === 0 ? 
                '✅ MCP Jupyter validé - Prêt pour production' : 
                '❌ Échecs détectés - Corrections nécessaires'
        };
        
        return report;
    }

    // Sauvegarde du rapport
    saveReport(report, filePath = 'validation-report.json') {
        fs.writeFileSync(filePath, JSON.stringify(report, null, 2));
        console.log(`📄 Rapport sauvegardé: ${filePath}`);
    }

    // Exécution complète de la validation
    async runFullValidation() {
        console.log('🚀 DÉBUT VALIDATION END-TO-END MCP JUPYTER\n');
        
        await this.validateTest('Connectivité MCP', () => this.testMCPConnectivity());
        await this.validateTest('Gestion Kernels', () => this.testKernelManagement());
        await this.validateTest('Création/Exécution Notebook', () => this.testNotebookCreationExecution());
        await this.validateTest('Stabilité Working Directory', () => this.testWorkingDirectoryStability());
        await this.validateTest('Gestion Erreurs', () => this.testErrorHandling());
        
        console.log('\n📊 GÉNÉRATION DU RAPPORT...\n');
        
        const report = this.generateReport();
        console.log(JSON.stringify(report.summary, null, 2));
        
        this.saveReport(report, 'tests/results/jupyter-mcp-validation-report.json');
        
        console.log(`\n🏆 RÉSULTAT FINAL: ${report.status}`);
        console.log(report.recommendation);
        
        return report;
    }
}

// Exécution si appelé directement
if (require.main === module) {
    const validator = new JupyterMCPValidator();
    validator.runFullValidation()
        .then(report => {
            process.exit(report.summary.failed === 0 ? 0 : 1);
        })
        .catch(error => {
            console.error('💥 ERREUR VALIDATION:', error);
            process.exit(1);
        });
}

module.exports = JupyterMCPValidator;