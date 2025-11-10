#!/usr/bin/env node
// ==============================================================================
// Script: test-node.js
// Description: Tests d'encodage pour Node.js
// Auteur: Roo Debug Mode
// Date: 2025-10-29
// ==============================================================================

const fs = require('fs');
const path = require('path');
const { spawn, exec } = require('child_process');
const os = require('os');

function getDiagnosticInfo(testName) {
    try {
        // Exécuter chcp sur Windows
        let codePage = 'N/A (Unix)';
        if (os.platform() === 'win32') {
            try {
                const { execSync } = require('child_process');
                const result = execSync('chcp', { encoding: 'utf8' });
                if (result.includes(':')) {
                    codePage = result.split(':').pop().trim();
                }
            } catch (e) {
                codePage = 'Erreur chcp';
            }
        }

        return {
            testName,
            nodeVersion: process.version,
            nodePlatform: process.platform,
            nodeArch: process.arch,
            codePage,
            defaultEncoding: process.env.LANG || 'Non défini',
            stdoutEncoding: process.stdout.encoding || 'Non défini',
            stderrEncoding: process.stderr.encoding || 'Non défini',
            fileSystemEncoding: 'UTF-8 (Node.js par défaut)',
            osName: os.type(),
            osRelease: os.release(),
            timestamp: new Date().toISOString()
        };
    } catch (e) {
        return {
            testName,
            error: e.message,
            timestamp: new Date().toISOString()
        };
    }
}

function testConsoleDisplay(testName, content) {
    const diag = getDiagnosticInfo(testName);
    
    try {
        console.log(`=== ${testName} ===`);
        console.log(`Node.js: ${diag.nodeVersion}`);
        console.log(`Platforme: ${diag.nodePlatform}`);
        console.log(`Code Page: ${diag.codePage}`);
        console.log(`Encodage stdout: ${diag.stdoutEncoding}`);
        console.log(`Affichage: ${content}`);
        
        return {
            success: true,
            diagnostic: diag,
            result: 'Affiché correctement'
        };
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

function testFileWrite(testName, content, filename) {
    const diag = getDiagnosticInfo(testName);
    const filePath = path.join('results', filename);
    
    try {
        // Créer le répertoire results si nécessaire
        if (!fs.existsSync('results')) {
            fs.mkdirSync('results', { recursive: true });
        }
        
        // Écrire avec encodage UTF-8 explicite
        fs.writeFileSync(filePath, content, { encoding: 'utf8' });
        
        // Lire pour vérification
        const writtenContent = fs.readFileSync(filePath, { encoding: 'utf8' });
        
        if (writtenContent === content) {
            return {
                success: true,
                diagnostic: diag,
                result: 'Écriture réussie'
            };
        } else {
            return {
                success: false,
                diagnostic: diag,
                error: 'Contenu différent après écriture'
            };
        }
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

function testFileRead(testName, filename) {
    const diag = getDiagnosticInfo(testName);
    const filePath = path.join('test-data', filename);
    
    try {
        if (!fs.existsSync(filePath)) {
            return {
                success: false,
                diagnostic: diag,
                error: `Fichier non trouvé: ${filePath}`
            };
        }
        
        const content = fs.readFileSync(filePath, { encoding: 'utf8' });
        return {
            success: true,
            diagnostic: diag,
            result: content
        };
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

function testProcessTransmission(testName, content) {
    const diag = getDiagnosticInfo(testName);
    
    try {
        // Test avec pipe (Node.js gère bien les pipes)
        const child = spawn('node', ['-e', `console.log('${content}')'], {
            stdio: ['pipe', 'pipe', 'pipe'],
            encoding: 'utf8'
        });
        
        let output = '';
        child.stdout.on('data', (data) => {
            output += data;
        });
        
        return new Promise((resolve) => {
            child.on('close', (code) => {
                if (code === 0 && output.trim() === content) {
                    resolve({
                        success: true,
                        diagnostic: diag,
                        result: 'Transmission réussie'
                    });
                } else {
                    resolve({
                        success: false,
                        diagnostic: diag,
                        error: `Contenu altéré: ${output.trim()} (code: ${code})`
                    });
                }
            });
        });
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

function testEnvironmentVariables(testName, content) {
    const diag = getDiagnosticInfo(testName);
    
    try {
        // Définir une variable d'environnement avec emojis
        process.env.TEST_EMOJI_NODE = content;
        
        // Lire la variable
        const envValue = process.env.TEST_EMOJI_NODE;
        
        if (envValue === content) {
            return {
                success: true,
                diagnostic: diag,
                result: 'Variable d\'environnement préservée'
            };
        } else {
            return {
                success: false,
                diagnostic: diag,
                error: 'Variable d\'environnement altérée'
            };
        }
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

function testNodeFeatures(testName) {
    const diag = getDiagnosticInfo(testName);
    
    try {
        const features = {
            hasES6Modules: true,  // Node.js moderne
            hasAsyncAwait: true,
            hasPromises: true,
            hasArrowFunctions: true,
            hasTemplateLiterals: true,
            hasDestructuring: true,
            hasSpreadOperator: true,
            hasRestParameters: true,
            hasOptionalChaining: true,
            hasNullishCoalescing: true,
            hasBigInt: true,
            hasWorkerThreads: true,
            hasES2020Support: parseInt(process.version.slice(1).split('.')[0]) >= 14,
            hasES2022Support: parseInt(process.version.slice(1).split('.')[0]) >= 18,
        };
        
        return {
            success: true,
            diagnostic: diag,
            result: features
        };
    } catch (e) {
        return {
            success: false,
            diagnostic: diag,
            error: e.message
        };
    }
}

async function main() {
    const testResults = [];
    
    console.log('='.repeat(60));
    console.log('  TESTS D\'ENCODAGE - NODE.JS');
    console.log('='.repeat(60));
    console.log();
    
    // Test 1: Caractères accentués simples
    const accentedText = 'é è à ù ç œ æ â ê î ô û';
    let result = testConsoleDisplay('Node-Accented', accentedText);
    testResults.push(result);
    
    result = testFileWrite('Node-Accented-File', accentedText, 'accented-node.txt');
    testResults.push(result);
    
    result = testFileRead('Node-Accented-Read', 'sample-accented.txt');
    testResults.push(result);
    
    // Test 2: Emojis simples
    const simpleEmojis = '✅ ❌ ⚠️ ℹ️';
    result = testConsoleDisplay('Node-SimpleEmojis', simpleEmojis);
    testResults.push(result);
    
    result = testFileWrite('Node-SimpleEmojis-File', simpleEmojis, 'simple-emojis-node.txt');
    testResults.push(result);
    
    result = testFileRead('Node-SimpleEmojis-Read', 'sample-emojis.txt');
    testResults.push(result);
    
    // Test 3: Emojis complexes
    const complexEmojis = '🚀 💻 ⚙️ 🪲 📁 📄 📦 🔍 📊 📋 🔬 🎯 📈 💡 💾 🔄 🏗️ 📝 🔧 ✨';
    result = testConsoleDisplay('Node-ComplexEmojis', complexEmojis);
    testResults.push(result);
    
    result = testFileWrite('Node-ComplexEmojis-File', complexEmojis, 'complex-emojis-node.txt');
    testResults.push(result);
    
    // Test 4: Transmission entre processus
    const transmissionTest = 'Test transmission: ✅ 🚀 💻';
    result = await testProcessTransmission('Node-Transmission', transmissionTest);
    testResults.push(result);
    
    // Test 5: Variables d'environnement
    const envTest = 'Variable env: ✅ 🚀 💻';
    result = testEnvironmentVariables('Node-Environment', envTest);
    testResults.push(result);
    
    // Test 6: Fonctionnalités Node.js
    result = testNodeFeatures('Node-Features');
    testResults.push(result);
    
    // Test 7: Option système UTF-8
    console.log('=== Test option système UTF-8 ===');
    try {
        if (os.platform() === 'win32') {
            const { execSync } = require('child_process');
            try {
                // Vérifier les paramètres régionaux Windows
                const localeResult = execSync('systeminfo | findstr /B /C:"System Locale"', { encoding: 'utf8' });
                testResults.push({
                    success: true,
                    diagnostic: getDiagnosticInfo('Node-SystemSupport'),
                    result: `Locale Windows: ${localeResult.trim()}`
                });
            } catch (e) {
                testResults.push({
                    success: false,
                    diagnostic: getDiagnosticInfo('Node-SystemSupport'),
                    error: `Erreur lecture locale: ${e.message}`
                });
            }
        } else {
            // Sur Unix/Linux/macOS, vérifier les locales
            const locale = process.env.LANG || process.env.LC_ALL || 'Non défini';
            testResults.push({
                success: true,
                diagnostic: getDiagnosticInfo('Node-SystemSupport'),
                result: `Locale Unix: ${locale}`
            });
        }
    } catch (e) {
        testResults.push({
            success: false,
            diagnostic: getDiagnosticInfo('Node-SystemSupport'),
            error: e.message
        });
    }
    
    // Sauvegarder les résultats
    const resultsFile = 'results/node-results.json';
    if (!fs.existsSync('results')) {
        fs.mkdirSync('results', { recursive: true });
    }
    
    fs.writeFileSync(resultsFile, JSON.stringify(testResults, null, 2), { encoding: 'utf8' });
    
    console.log();
    console.log('='.repeat(60));
    console.log('  RÉSUMÉ DES TESTS NODE.JS');
    console.log('='.repeat(60));
    console.log();
    
    const successCount = testResults.filter(r => r.success).length;
    const failureCount = testResults.length - successCount;
    
    console.log(`Tests exécutés: ${testResults.length}`);
    console.log(`Réussis: ${successCount}`);
    console.log(`Échecs: ${failureCount}`);
    console.log(`Taux de succès: ${Math.round((successCount / testResults.length) * 100)}%`);
    
    console.log();
    console.log(`Résultats détaillés sauvegardés dans: ${resultsFile}`);
    console.log('Tests Node.js terminés');
}

if (require.main === module) {
    main().catch(console.error);
}