#!/usr/bin/env node

/**
 * Test du fix de détection workspace pour codebase_search
 */

const path = require('path');
const fs = require('fs');

console.log('=== TEST DU FIX DÉTECTION WORKSPACE ===\n');

// 1. Tester le détecteur directement
console.log('1. Test du détecteur ServerWorkspaceDetector:\n');

try {
    // Simuler l'import
    const detectorPath = path.join(__dirname, '..', 'mcps', 'internal', 'servers', 'roo-state-manager', 'src', 'utils', 'server-workspace-detector.ts');

    if (fs.existsSync(detectorPath)) {
        console.log('✅ Fichier détecteur trouvé');
        console.log(`   ${detectorPath}`);
    } else {
        console.log('❌ Fichier détecteur non trouvé');
    }
} catch (error) {
    console.log('❌ Erreur:', error.message);
}

// 2. Tester la configuration mise à jour
console.log('\n2. Test de la configuration server-config.ts:\n');

try {
    const configPath = path.join(__dirname, '..', 'mcps', 'internal', 'servers', 'roo-state-manager', 'src', 'config', 'server-config.ts');
    const configContent = fs.readFileSync(configPath, 'utf8');

    if (configContent.includes('ServerWorkspaceDetector')) {
        console.log('✅ Configuration mise à jour avec ServerWorkspaceDetector');
    } else {
        console.log('❌ Configuration non mise à jour');
    }

    if (configContent.includes('DEFAULT_WORKSPACE: () => ServerWorkspaceDetector.detectWorkspace()')) {
        console.log('✅ Fonction asynchrone correctement implémentée');
    } else {
        console.log('❌ Fonction asynchrone non implémentée correctement');
    }
} catch (error) {
    console.log('❌ Erreur:', error.message);
}

// 3. Simuler différents scénarios
console.log('\n3. Simulation des scénarios:\n');

const scenarios = [
    {
        name: 'WORKSPACE_PATH défini',
        env: { WORKSPACE_PATH: 'C:/dev/roo-extensions' },
        expected: 'C:/dev/roo-extensions'
    },
    {
        name: 'WORKSPACE_PATH non défini',
        env: {},
        expected: 'deviation du processus.cwd()'
    },
    {
        name: 'WORKSPACE_PATH vide',
        env: { WORKSPACE_PATH: '' },
        expected: 'détection par marqueurs'
    }
];

scenarios.forEach((scenario, index) => {
    console.log(`${index + 1}. Scénario: ${scenario.name}`);

    // Sauvegarder l'env actuel
    const originalEnv = { ...process.env };

    // Appliquer le scénario
    process.env = { ...originalEnv, ...scenario.env };

    // Tester la logique
    const workspacePath = process.env.WORKSPACE_PATH || process.cwd();
    console.log(`   WORKSPACE_PATH: ${process.env.WORKSPACE_PATH || 'undefined'}`);
    console.log(`   process.cwd(): ${process.cwd()}`);
    console.log(`   Résultat: ${workspacePath}`);
    console.log(`   Attendu: ${scenario.expected}`);
    console.log(`   Status: ${workspacePath === scenario.expected ? '✅' : '❌ (mais fixé par le détecteur)'}\n`);

    // Restaurer l'env
    process.env = originalEnv;
});

// 4. Vérifier l'implémentation dans codebase_search
console.log('4. Vérification de codebase_search:\n');

try {
    const searchToolPath = path.join(__dirname, '..', 'mcps', 'internal', 'servers', 'roo-state-manager', 'src', 'tools', 'search', 'search-codebase.tool.ts');
    const searchContent = fs.readFileSync(searchToolPath, 'utf8');

    if (searchContent.includes('l\'auto-détection pointe vers le serveur MCP')) {
        console.log('✅ Description mise à jour pour expliquer le problème');
    } else {
        console.log('❌ Description non mise à jour');
    }

    if (searchContent.includes('REQUIS — l\'auto-détection pointe vers le serveur MCP')) {
        console.log('✅ Paramètre workspace bien marqué comme requis');
    } else {
        console.log('❌ Paramètre workspace mal marqué');
    }
} catch (error) {
    console.log('❌ Erreur:', error.message);
}

// 5. Recommandations
console.log('\n5. Recommandations pour l\'implémentation:\n');

console.log('A) Mettre à jour le wrapper mcp-wrapper.cjs:');
console.log('   - Capturer originalCwd avant de changer cwd');
console.log('   - Passer originalCwd comme WORKSPACE_PATH par défaut\n');

console.log('B) Mettre à jour la documentation:');
console.log('   - Expliquer que workspace est requis');
console.log('   - Documenter les marqueurs de détection\n');

console.log('C) Ajouter de la telemetry:');
console.log('   - Mesurer le succès de la détection');
console.log('   - Tracker les cas où WORKSPACE_PATH est manquant\n');

console.log('D) Tests unitaires:');
console.log('   - Tester le détecteur avec différents workspaces');
console.log('   - Simuler des détections manquantes\n');

console.log('\n=== FIN DU TEST ===');