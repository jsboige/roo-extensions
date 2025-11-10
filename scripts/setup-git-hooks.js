#!/usr/bin/env node

/**
 * SCRIPT D'INSTALLATION DES GIT HOOKS
 * 
 * Ce script configure automatiquement les hooks Git pour les MCPs
 * afin de prévenir les régressions et les commits de stubs.
 * 
 * Usage: node scripts/setup-git-hooks.js [workspace-path]
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Configuration
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const HOOKS_DIR = '.git/hooks';
const HOOKS = [
  {
    name: 'pre-commit',
    source: 'scripts/pre-commit-hook.js',
    description: 'Détection automatique des stubs avant chaque commit'
  },
  {
    name: 'pre-push',
    source: 'scripts/pre-push-hook.js',
    description: 'Validation complète avant chaque push'
  }
];

function colorLog(message, color = 'white') {
  const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    white: '\x1b[37m'
  };
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function colorSuccess(message) {
  colorLog(`✅ ${message}`, 'green');
}

function colorError(message) {
  colorLog(`❌ ${message}`, 'red');
}

function colorWarning(message) {
  colorLog(`⚠️  ${message}`, 'yellow');
}

function colorInfo(message) {
  colorLog(`ℹ️  ${message}`, 'blue');
}

function getWorkspacePath() {
  const args = process.argv.slice(2);
  if (args.length > 0) {
    return args[0];
  }
  return join(__dirname, '..');
}

function checkGitRepository(workspacePath) {
  const gitPath = join(workspacePath, '.git');
  
  if (!existsSync(gitPath)) {
    colorError(`Ce n'est pas un dépôt Git: ${workspacePath}`);
    return false;
  }
  
  return true;
}

function createHooksDirectory(workspacePath) {
  const hooksDir = join(workspacePath, HOOKS_DIR);
  
  if (!existsSync(hooksDir)) {
    mkdirSync(hooksDir, { recursive: true });
    colorSuccess(`Répertoire hooks créé: ${hooksDir}`);
  }
  
  return hooksDir;
}

function installHook(hooksDir, hook) {
  const hookPath = join(hooksDir, hook.name);
  const sourcePath = join(__dirname, '..', hook.source);
  
  if (!existsSync(sourcePath)) {
    colorWarning(`Source hook manquant: ${sourcePath}`);
    return false;
  }
  
  // Créer le contenu du hook
  const hookContent = `#!/bin/sh
# ${hook.description}
# Généré automatiquement par setup-git-hooks.js
# Date: ${new Date().toISOString()}

node "${join(__dirname, '..', hook.source)}" "$@"
`;
  
  try {
    writeFileSync(hookPath, hookContent, { mode: 0o755 });
    colorSuccess(`Hook installé: ${hook.name}`);
    return true;
  } catch (error) {
    colorError(`Erreur installation hook ${hook.name}: ${error.message}`);
    return false;
  }
}

async function configureGitHooksPath(workspacePath) {
  colorInfo('Configuration du chemin des hooks Git...');
  
  try {
    const { spawn } = await import('child_process');
    
    return new Promise((resolve, reject) => {
      const process = spawn('git', ['config', 'core.hooksPath', '.git/hooks'], {
        cwd: workspacePath,
        stdio: 'pipe'
      });
      
      let output = '';
      let error = '';
      
      process.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      process.stderr.on('data', (data) => {
        error += data.toString();
      });
      
      process.on('close', (code) => {
        if (code === 0) {
          colorSuccess('Chemin des hooks configuré');
          resolve(true);
        } else {
          colorError(`Erreur configuration hooks: ${error}`);
          reject(new Error(error));
        }
      });
      
      process.on('error', (err) => {
        reject(err);
      });
    });
  } catch (error) {
    colorError(`Erreur configuration Git: ${error.message}`);
    return false;
  }
}

function verifyHooks(hooksDir) {
  colorInfo('Vérification des hooks installés...');
  
  let allValid = true;
  
  HOOKS.forEach(hook => {
    const hookPath = join(hooksDir, hook.name);
    
    if (existsSync(hookPath)) {
      try {
        const stats = readFileSync(hookPath, 'utf-8');
        if (stats.includes('node "') && stats.includes(hook.source)) {
          colorSuccess(`✅ ${hook.name}: valide`);
        } else {
          colorError(`❌ ${hook.name}: invalide ou corrompu`);
          allValid = false;
        }
      } catch (error) {
        colorError(`❌ ${hook.name}: erreur lecture: ${error.message}`);
        allValid = false;
      }
    } else {
      colorWarning(`⚠️  ${hook.name}: manquant`);
      allValid = false;
    }
  });
  
  return allValid;
}

function showUsage() {
  colorLog('🔧 SETUP GIT HOOKS', 'cyan');
  colorLog('=========================', 'cyan');
  colorLog('Usage:', 'white');
  colorLog('  node scripts/setup-git-hooks.js [workspace-path]', 'yellow');
  colorLog('\nOptions:', 'white');
  colorLog('  --help, -h     Affiche cette aide', 'yellow');
  colorLog('  --verbose       Mode verbeux', 'yellow');
  colorLog('  --force         Force la réinstallation', 'yellow');
  colorLog('\nExemples:', 'white');
  colorLog('  node scripts/setup-git-hooks.js .', 'green');
  colorLog('  node scripts/setup-git-hooks.js /path/to/project', 'green');
}

async function main() {
  const args = process.argv.slice(2);
  const workspacePath = getWorkspacePath();
  
  // Gérer les options
  if (args.includes('--help') || args.includes('-h')) {
    showUsage();
    process.exit(0);
  }
  
  const verbose = args.includes('--verbose');
  const force = args.includes('--force');
  
  colorLog('🔧 INSTALLATION DES GIT HOOKS MCP', 'cyan');
  colorLog('=====================================', 'cyan');
  colorInfo(`Espace de travail: ${workspacePath}`);
  
  // 1. Vérifier que c'est un dépôt Git
  if (!checkGitRepository(workspacePath)) {
    process.exit(1);
  }
  
  // 2. Créer le répertoire des hooks
  const hooksDir = createHooksDirectory(workspacePath);
  
  // 3. Configurer le chemin des hooks Git
  if (!configureGitHooksPath(workspacePath)) {
    process.exit(1);
  }
  
  // 4. Installer les hooks
  colorInfo('\nInstallation des hooks...');
  let successCount = 0;
  
  for (const hook of HOOKS) {
    if (installHook(hooksDir, hook)) {
      successCount++;
    }
  }
  
  // 5. Vérifier l'installation
  colorInfo('\nVérification de l\'installation...');
  const allValid = verifyHooks(hooksDir);
  
  // 6. Résultat
  colorLog('\n📋 RÉSUMÉ:', 'cyan');
  colorLog('================', 'cyan');
  
  if (allValid && successCount === HOOKS.length) {
    colorSuccess(`✅ Tous les hooks (${successCount}/${HOOKS.length}) installés avec succès`);
    colorSuccess('🎉 Les commits sont maintenant protégés contre les stubs');
    
    if (verbose) {
      colorInfo('\nHooks installés:');
      HOOKS.forEach(hook => {
        colorInfo(`  • ${hook.name}: ${hook.description}`);
      });
    }
  } else {
    colorError(`❌ Échec installation: ${successCount}/${HOOKS.length} hooks valides`);
    
    if (force) {
      colorWarning('\n⚠️  Mode force activé - certains hooks peuvent être corrompus');
    }
    
    process.exit(1);
  }
  
  // 7. Recommandations
  colorLog('\n📌 RECOMMANDATIONS:', 'yellow');
  colorLog('=====================', 'yellow');
  colorLog('1. Exécuter "npm run precommit:test" pour tester', 'white');
  colorLog('2. Configurer votre IDE pour ignorer .git/hooks/', 'white');
  colorLog('3. Les hooks s\'exécutent automatiquement avant chaque commit', 'white');
}

// Gestion des erreurs
process.on('uncaughtException', (error) => {
  colorError(`Erreur non capturée: ${error.message}`);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  colorError(`Promesse rejetée non gérée: ${reason}`);
  process.exit(1);
});

// Point d'entrée
if (import.meta.url) {
  main();
} else {
  colorError('Ce script doit être exécuté avec ES modules');
  process.exit(1);
}