#!/usr/bin/env node

/**
 * Script de reproduction du bug d'auto-detection workspace
 *
 * Problème: codebase_search utilise le mauvais workspace
 * - Attends: C:/dev/roo-extensions (workspace réel)
 * - Reçoit: C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager (cwd du serveur)
 */

const path = require('path');
const fs = require('fs');

console.log('=== REPRODUCTION DU BUG AUTO-DETECTION WORKSPACE ===\n');

// 1. Simuler l'appel depuis différents workspaces
const testWorkspaces = [
    'C:/dev/roo-extensions',  // Workspace réel
    'C:/dev/roo-extensions/.claude/worktrees/wt-worker-myia-web1-20260430-200749',  // Worktree
    '/home/user/projects/roo-extensions',  // Linux hypothétique
    'D:/projects/roo-extensions',  // Autre drive Windows
];

console.log('1. Test des détections simulées:\n');

testWorkspaces.forEach(workspace => {
    console.log(`Workspace attendu: ${workspace}`);

    // Simulation de ce que voit le MCP wrapper
    const originalCwd = workspace; // Ce que Claude Code envoie
    const serverCwd = __dirname;   // Où tourne le serveur
    const workspacePath = process.env.WORKSPACE_PATH || originalCwd;

    console.log(`  - process.cwd() (wrapper): ${originalCwd}`);
    console.log(`  - __dirname (server):      ${serverCwd}`);
    console.log(`  - WORKSPACE_PATH:           ${workspacePath}`);
    console.log(`  - Détection finale:         ${workspacePath === workspace ? '✅ CORRECT' : '❌ BUG'}\n`);
});

// 2. Test de la logique actuelle dans server-config.ts
console.log('2. Logique de détection actuelle (server-config.ts):\n');

const testConfigs = [
    { WORKSPACE_PATH: 'C:/dev/roo-extensions', cwd: __dirname },
    { WORKSPACE_PATH: undefined, cwd: __dirname },
    { WORKSPACE_PATH: '', cwd: __dirname },
];

testConfigs.forEach(config => {
    process.env.WORKSPACE_PATH = config.WORKSPACE_PATH;

    // Simuler la logique de server-config.ts
    const detectedWorkspace = process.env.WORKSPACE_PATH || process.cwd();

    console.log(`Cas: WORKSPACE_PATH=${config.WORKSPACE_PATH || 'undefined'}`);
    console.log(`  - process.cwd() = ${process.cwd()}`);
    console.log(`  - Résultat: ${detectedWorkspace}`);
    console.log(`  - Est-ce le workspace réel? ${detectedWorkspace === testWorkspaces[0] ? '✅' : '❌'}\n`);
});

// 3. Solutions proposées
console.log('3. Solutions possibles:\n');

console.log('A) Toujours passer workspace explicitement (workaround actuel):');
console.log('   codebase_search(query: "...", workspace: "C:/dev/roo-extensions")\n');

console.log('B) Détecter le workspace parent (si WORKSPACE_PATH non défini):');
console.log('   - Aller up depuis __dirname jusqu\'à trouver un marqueur (.git, CLAUDE.md)');
console.log('   - Ex: mcps/internal/servers/roo-state-manager → roo-extensions\n');

console.log('C) Lire depuis un fichier de marqueur:');
console.log('   - .claude/workspace.txt (écrit par Claude Code)');
console.log('   - Ou utiliser process.argv pour détecter le workspace original\n');

// 4. Vérifier si les workspaces ont des index Qdrant
console.log('4. Vérification des collections existantes:\n');

const { execSync } = require('child_process');
try {
    const qdrantCmd = 'curl -s "https://qdrant.myia.io/collections" | node -e "const r=require(\'fs\').readFileSync(0,\'utf8\'); try{const j=JSON.parse(r);console.log(JSON.stringify(j.collections.map(c=>c.name),null,2))}catch{}"';
    const output = execSync(qdrantCmd, { encoding: 'utf8', timeout: 5000 });
    console.log('Collections Qdrant disponibles:');
    console.log(output);
} catch (error) {
    console.log('❌ Impossible de se connecter à Qdrant:', error.message);
}

console.log('\n=== FIN DE LA REPRODUCTION ===');