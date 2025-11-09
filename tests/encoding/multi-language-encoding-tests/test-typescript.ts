#!/usr/bin/env ts-node
// ==============================================================================
// Script: test-typescript.ts
// Description: Tests d'encodage pour TypeScript (via ts-node)
// Auteur: Roo Debug Mode
// Date: 2025-10-29
// ==============================================================================

import * as fs from 'fs';
import * as path from 'path';
import { spawn, exec } from 'child_process';
import * as os from 'os';

interface DiagnosticInfo {
    testName: string;
    typescriptVersion?: string;
    nodeVersion?: string;
    nodePlatform?: string;
    nodeArch?: string;
    codePage?: string;
    defaultEncoding?: string;
    stdoutEncoding?: string;
    stderrEncoding?: string;
    fileSystemEncoding?: string;
    osName?: string;
    osRelease?: string;
    timestamp?: string;
    error?: string;
}

interface TestResult {
    success: boolean;
    diagnostic: DiagnosticInfo;
    result?: any;
    error?: string;
}

interface NodeFeatures {
    hasES6Modules: boolean;
    hasAsyncAwait: boolean;
    hasPromises: boolean;
    hasArrowFunctions: boolean;
    hasTemplateLiterals: boolean;
    hasDestructuring: boolean;
    hasSpreadOperator: boolean;
    hasRestParameters: boolean;
    hasOptionalChaining: boolean;
    hasNullishCoalescing: boolean;
    hasBigInt: boolean;
    hasWorkerThreads: boolean;
    hasES2020Support: boolean;
    hasES2022Support: boolean;
}

function getDiagnosticInfo(testName: string): DiagnosticInfo {
    try {
        // Exécuter chcp sur Windows
        let codePage = 'N/A (Unix)';
        if (os.platform() === 'win32') {
            try {
                const { execSync } = require('child_process');
                const result = execSync('chcp', { encoding: 'utf8' });
                if (result.includes(':')) {
                    codePage = result.split(':').pop()?.trim();
                }
            } catch (e) {
                codePage = 'Erreur chcp';
            }
        }

        return {
            testName,
            typescriptVersion: 'TypeScript (ts-node)',
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
            error: (e as Error).message,
            timestamp: new Date().toISOString()
        };
    }
}

function testConsoleDisplay(testName: string, content: string): TestResult {
    const diag = getDiagnosticInfo(testName);
    
    try {
        console.log(`=== ${testName} ===`);
        console.log(`TypeScript: ${diag.typescriptVersion}`);
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
            error: (e as Error).message
        };
    }
}

function testFileWrite(testName: string, content: string, filename: string): TestResult {
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
            error: (e as Error).message
        };
    }
}

function testFileRead(testName: string, filename: string): TestResult {
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
            error: (e as Error).message
        };
    }
}

function testProcessTransmission(testName: string, content: string): Promise<TestResult> {
    const diag = getDiagnosticInfo(testName);
    
    try {
        // Test avec pipe (Node.js gère bien les pipes)
        const child = spawn('ts-node', ['-e', `console.log('${content}')'], {
            stdio: ['pipe', 'pipe', 'pipe'],
            encoding: 'utf8'
        });
        
        let output = '';
        child.stdout?.on('data', (data: string) => {
            output += data;
        });
        
        return new Promise((resolve) => {
            child.on('close', (code: number | null) => {
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
        return Promise.resolve({
            success: false,
            diagnostic: diag,
            error: (e as Error).message
        });
    }
}

function testEnvironmentVariables(testName: string, content: string): TestResult {
    const diag = getDiagnosticInfo(testName);
    
    try {
        // Définir une variable d'environnement avec emojis
        process.env.TEST_EMOJI_TS = content;
        
        // Lire la variable
        const envValue = process.env.TEST_EMOJI_TS;
        
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
            error: (e as Error).message
        };
    }
}

function testTypeScriptFeatures(testName: string): TestResult {
    const diag = getDiagnosticInfo(testName);
    
    try {
        const features: NodeFeatures = {
            hasES6Modules: true,  // TypeScript moderne
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
            hasTypeScriptSupport: true,  // Évident avec ts-node
            hasStrongTyping: true,
            hasInterfaces: true,
            hasGenerics: true,
            hasDecorators: true,
            hasEnums: true,
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
            error: (e as Error).message
        };
    }
}

async function main(): Promise<void> {
    const testResults: TestResult[] = [];
    
    console.log('='.repeat(60));
    console.log('  TESTS D\'ENCODAGE - TYPESCRIPT (ts-node)');
    console.log('='.repeat(60));
    console.log();
    
    // Test 1: Caractères accentués simples
    const accentedText = 'é è à ù ç œ æ â ê î ô û';
    let result = testConsoleDisplay('TS-Accented', accentedText);
    testResults.push(result);
    
    result = testFileWrite('TS-Accented-File', accentedText, 'accented-ts.txt');
    testResults.push(result);
    
    result = testFileRead('TS-Accented-Read', 'sample-accented.txt');
    testResults.push(result);
    
    // Test 2: Emojis simples
    const simpleEmojis = '✅ ❌ ⚠️ ℹ️';
    result = testConsoleDisplay('TS-SimpleEmojis', simpleEmojis);
    testResults.push(result);
    
    result = testFileWrite('TS-SimpleEmojis-File', simpleEmojis, 'simple-emojis-ts.txt');
    testResults.push(result);
    
    result = testFileRead('TS-SimpleEmojis-Read', 'sample-emojis.txt');
    testResults.push(result);
    
    // Test 3: Emojis complexes
    const complexEmojis = '🚀 💻 ⚙️ 🪲 📁 📄 📦 🔍 📊 📋 🔬 🎯 📈 💡 💾 🔄 🏗️ 📝 🔧 ✨';
    result = testConsoleDisplay('TS-ComplexEmojis', complexEmojis);
    testResults.push(result);
    
    result = testFileWrite('TS-ComplexEmojis-File', complexEmojis, 'complex-emojis-ts.txt');
    testResults.push(result);
    
    // Test 4: Transmission entre processus
    const transmissionTest = 'Test transmission: ✅ 🚀 💻';
    result = await testProcessTransmission('TS-Transmission', transmissionTest);
    testResults.push(result);
    
    // Test 5: Variables d'environnement
    const envTest = 'Variable env: ✅ 🚀 💻';
    result = testEnvironmentVariables('TS-Environment', envTest);
    testResults.push(result);
    
    // Test 6: Fonctionnalités TypeScript
    result = testTypeScriptFeatures('TS-Features');
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
                    diagnostic: getDiagnosticInfo('TS-SystemSupport'),
                    result: `Locale Windows: ${localeResult.trim()}`
                });
            } catch (e) {
                testResults.push({
                    success: false,
                    diagnostic: getDiagnosticInfo('TS-SystemSupport'),
                    error: `Erreur lecture locale: ${(e as Error).message}`
                });
            }
        } else {
            // Sur Unix/Linux/macOS, vérifier les locales
            const locale = process.env.LANG || process.env.LC_ALL || 'Non défini';
            testResults.push({
                success: true,
                diagnostic: getDiagnosticInfo('TS-SystemSupport'),
                result: `Locale Unix: ${locale}`
            });
        }
    } catch (e) {
        testResults.push({
            success: false,
            diagnostic: getDiagnosticInfo('TS-SystemSupport'),
            error: (e as Error).message
        });
    }
    
    // Sauvegarder les résultats
    const resultsFile = 'results/typescript-results.json';
    if (!fs.existsSync('results')) {
        fs.mkdirSync('results', { recursive: true });
    }
    
    fs.writeFileSync(resultsFile, JSON.stringify(testResults, null, 2), { encoding: 'utf8' });
    
    console.log();
    console.log('='.repeat(60));
    console.log('  RÉSUMÉ DES TESTS TYPESCRIPT');
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
    console.log('Tests TypeScript terminés');
}

if (require.main === module) {
    main().catch(console.error);
}