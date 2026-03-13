#!/usr/bin/env node

/**
 * Script pour vérifier la présence de BOM UTF-8 dans un ou plusieurs fichiers
 *
 * Usage:
 *   node check-bom-in-file.js <chemin_fichier>           # Vérifier un seul fichier
 *   node check-bom-in-file.js --batch                     # Vérifier tous les fichiers critiques
 *   node check-bom-in-file.js --batch --config custom.json # Vérifier avec config personnalisée
 *
 * Issue #664: BOM UTF-8 récurrent dans mcp_settings.json
 */

const fs = require('fs');
const path = require('path');

// Fichiers de configuration critiques à vérifier (chemins Windows)
const CRITICAL_CONFIGS = [
    {
        path: process.env.APPDATA + '\\Code\\User\\globalStorage\\rooveterinaryinc.roo-cline\\settings\\mcp_settings.json',
        name: 'mcp_settings.json',
        critical: true
    },
    {
        path: process.env.APPDATA + '\\Code\\User\\globalStorage\\rooveterinaryinc.roo-cline\\settings\\custom_modes.yaml',
        name: 'custom_modes.yaml',
        critical: true
    },
    {
        path: path.join(__dirname, '..', '..', '.roo', 'schedules.json'),
        name: 'schedules.json',
        critical: false
    },
    {
        path: path.join(__dirname, '..', '.env'),
        name: '.env',
        critical: true
    }
];

/**
 * Vérifie la présence de BOM UTF-8 dans un fichier
 * @param {string} filePath - Chemin du fichier à vérifier
 * @returns {object} - Résultat de la vérification
 */
function checkBOM(filePath) {
    try {
        const bytes = fs.readFileSync(filePath);
        const bomPresent = bytes[0] === 0xEF && bytes[1] === 0xBB && bytes[2] === 0xBF;

        return {
            path: filePath,
            exists: true,
            bomPresent,
            firstBytes: `${bytes[0].toString(16).padStart(2, '0')} ${bytes[1].toString(16).padStart(2, '0')} ${bytes[2].toString(16).padStart(2, '0')}`,
            size: bytes.length
        };
    } catch (error) {
        if (error.code === 'ENOENT') {
            return { path: filePath, exists: false, error: 'File not found' };
        }
        return { path: filePath, exists: true, error: error.message };
    }
}

/**
 * Résout les variables d'environnement dans un chemin
 * @param {string} filePath - Chemin avec variables d'environnement
 * @returns {string} - Chemin résolu
 */
function resolveEnvVars(filePath) {
    // Remplacer %APPDATA% sur Windows
    if (process.platform === 'win32' && filePath.includes('%APPDATA%')) {
        return filePath.replace(/%APPDATA%/gi, process.env.APPDATA);
    }
    return filePath;
}

/**
 * Affiche le résultat d'une vérification de fichier
 * @param {object} result - Résultat de checkBOM
 * @param {string} name - Nom du fichier pour l'affichage
 * @param {boolean} critical - Si le fichier est critique
 */
function printResult(result, name, critical) {
    if (!result.exists) {
        if (critical) {
            console.log(`[${name}] ⚠️  FILE NOT FOUND: ${result.path}`);
        } else {
            console.log(`[${name}] ⊘ Skipping (optional, not found)`);
        }
        return false;
    }

    if (result.error) {
        console.log(`[${name}] ❌ ERROR: ${result.error}`);
        return false;
    }

    if (result.bomPresent) {
        console.log(`[${name}] ❌ BOM DETECTED!`);
        console.log(`  Path: ${result.path}`);
        console.log(`  Size: ${result.size} bytes`);
        console.log(`  First 3 bytes: ${result.firstBytes}`);
        console.log(`  Expected BOM pattern: EF BB BF (UTF-8)`);
        console.log(``);
        console.log(`  >> CORRECTION REQUIRED:`);
        console.log(`     1. Remove BOM:`);
        console.log(`        .\\scripts\\encoding\\Remove-UTF8BOM.ps1 "${result.path}"`);
        console.log(`     2. Or fix with fix-file-encoding:`);
        console.log(`        .\\scripts\\encoding\\fix-file-encoding.ps1 "${result.path}"`);
        return true;
    } else {
        console.log(`[${name}] ✅ OK (no BOM)`);
        console.log(`  First 3 bytes: ${result.firstBytes}`);
        return false;
    }
}

/**
 * Mode batch : vérifie tous les fichiers critiques
 */
function batchMode() {
    console.log('=== Roo Critical Config BOM Check (Issue #664) ===');
    console.log('');

    let hasBOM = false;
    let checkedCount = 0;
    let notFoundCount = 0;
    let okCount = 0;

    for (const config of CRITICAL_CONFIGS) {
        const result = checkBOM(config.path);
        const bomDetected = printResult(result, config.name, config.critical);

        if (bomDetected) {
            hasBOM = true;
        } else if (result.exists && !result.error) {
            okCount++;
            checkedCount++;
        } else if (!result.exists && config.critical) {
            notFoundCount++;
        }

        console.log('');
    }

    console.log('=== Summary ===');
    console.log(`Files checked: ${checkedCount}`);
    console.log(`OK: ${okCount}, Issues: ${hasBOM ? 'BOM DETECTED' : 'None'}`);
    if (notFoundCount > 0) {
        console.log(`NOT FOUND: ${notFoundCount} critical files`);
    }
    console.log('');

    if (hasBOM) {
        console.log('STATUS: BOM DETECTED in critical config files!');
        console.log('');
        console.log('IMPACT:');
        console.log('  - roo-state-manager MCP will FAIL to start');
        console.log('  - Roo scheduler will be NON-FUNCTIONAL');
        console.log('  - Machine will appear SILENT in RooSync');
        console.log('');
        console.log('CORRECTION:');
        console.log('  Run Remove-UTF8BOM.ps1 on affected files (see above)');
        console.log('  Prevent recurrence: Fix #664 - sync-alwaysallow.ps1 line 134');
        console.log('');
        process.exit(1);
    } else {
        console.log('STATUS: All critical configs are BOM-free');
        console.log('');
        process.exit(0);
    }
}

/**
 * Mode single file : vérifie un seul fichier
 */
function singleMode(filePath) {
    if (!filePath) {
        console.error('Usage: node check-bom-in-file.js <chemin_fichier>');
        console.error('   or: node check-bom-in-file.js --batch');
        process.exit(1);
    }

    const result = checkBOM(filePath);
    printResult(result, path.basename(filePath), true);

    if (result.bomPresent) {
        process.exit(1);
    } else if (result.error) {
        process.exit(1);
    } else {
        process.exit(0);
    }
}

// Main
const args = process.argv.slice(2);

if (args.length === 0) {
    console.error('Usage: node check-bom-in-file.js <chemin_fichier>');
    console.error('   or: node check-bom-in-file.js --batch');
    process.exit(1);
}

if (args[0] === '--batch') {
    batchMode();
} else {
    singleMode(args[0]);
}
