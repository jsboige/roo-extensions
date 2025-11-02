#!/usr/bin/env node

/**
 * PRE-COMMIT HOOK POUR DÉTECTION AUTOMATIQUE DES STUBS
 * 
 * Ce script empêche les commits si des stubs "Not implemented" sont détectés
 * dans les serveurs MCP critiques. Il s'agit d'une protection contre les régressions.
 * 
 * Usage: node scripts/pre-commit-hook.js [workspace-path]
 */

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Configuration
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const CRITICAL_TOOLS = [
  'handleDeleteFiles',
  'handleEditMultipleFiles', 
  'handleExtractMarkdownStructure',
  'handleCopyFiles',
  'handleMoveFiles',
  'handleSearchInFiles',
  'handleSearchAndReplace',
  'handleRestartMcpServers'
];

const STUB_PATTERNS = [
  'Not implemented',
  'TODO: implement',
  'stub',
  'STUB',
  'throw new Error',
  'return Promise.reject'
];

const MCP_SERVERS_PATH = 'mcps/internal/servers';

// Couleurs pour la sortie
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  white: '\x1b[37m'
};

function colorLog(message, color = 'white') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function colorError(message) {
  colorLog(`❌ ${message}`, 'red');
}

function colorSuccess(message) {
  colorLog(`✅ ${message}`, 'green');
}

function colorWarning(message) {
  colorLog(`⚠️  ${message}`, 'yellow');
}

function colorInfo(message) {
  colorLog(`ℹ️  ${message}`, 'blue');
}

function getWorkspacePath() {
  // Récupérer le chemin depuis les arguments ou utiliser le répertoire courant
  const args = process.argv.slice(2);
  if (args.length > 0) {
    return args[0];
  }
  
  // Si dans un git hook, utiliser GIT_WORK_TREE
  const gitWorkTree = process.env.GIT_WORK_TREE;
  if (gitWorkTree) {
    return gitWorkTree;
  }
  
  // Sinon, utiliser le répertoire parent
  return join(__dirname, '..');
}

function analyzeFile(filePath) {
  try {
    const content = readFileSync(filePath, 'utf-8');
    const issues = [];
    
    // Analyser ligne par ligne
    const lines = content.split('\n');
    lines.forEach((line, index) => {
      const lineNumber = index + 1;
      
      // Vérifier les patterns de stubs
      STUB_PATTERNS.forEach(pattern => {
        if (line.includes(pattern)) {
          issues.push({
            line: lineNumber,
            content: line.trim(),
            pattern: pattern,
            type: 'stub'
          });
        }
      });
      
      // Vérifier les fonctions vides
      if (line.includes('function') && line.includes('{}')) {
        issues.push({
          line: lineNumber,
          content: line.trim(),
          pattern: 'empty function',
          type: 'empty_function'
        });
      }
      
      // Vérifier les returns immédiats sans logique
      if (line.includes('return') && 
          (line.includes('Not implemented') || line.includes('TODO'))) {
        issues.push({
          line: lineNumber,
          content: line.trim(),
          pattern: 'early return',
          type: 'early_return'
        });
      }
    });
    
    return issues;
  } catch (error) {
    colorError(`Erreur lecture fichier ${filePath}: ${error.message}`);
    return [];
  }
}

function analyzeMcpServer(serverPath, serverName) {
  colorInfo(`Analyse du serveur MCP: ${serverName}`);
  
  const srcPath = join(serverPath, 'src');
  const buildPath = join(serverPath, 'build');
  
  if (!existsSync(srcPath)) {
    colorError(`Répertoire source manquant: ${srcPath}`);
    return { issues: [], critical: false };
  }
  
  // Analyser les fichiers source TypeScript
  const tsFiles = ['index.ts'];
  const allIssues = [];
  let criticalIssues = 0;
  
  tsFiles.forEach(file => {
    const filePath = join(srcPath, file);
    if (existsSync(filePath)) {
      const issues = analyzeFile(filePath);
      issues.forEach(issue => {
        issue.file = file;
        issue.server = serverName;
        allIssues.push(issue);
        
        if (issue.type === 'stub') {
          criticalIssues++;
        }
      });
    }
  });
  
  return {
    server: serverName,
    issues: allIssues,
    criticalIssues: criticalIssues,
    hasCriticalIssues: criticalIssues > 0
  };
}

function checkCriticalTools(serverPath, serverName) {
  colorInfo(`Vérification des outils critiques: ${serverName}`);
  
  const srcPath = join(serverPath, 'src');
  if (!existsSync(srcPath)) {
    return false;
  }
  
  try {
    const content = readFileSync(join(srcPath, 'index.ts'), 'utf-8');
    
    // Vérifier que tous les outils critiques sont implémentés
    const missingTools = [];
    CRITICAL_TOOLS.forEach(tool => {
      if (!content.includes(tool)) {
        missingTools.push(tool);
      }
    });
    
    if (missingTools.length > 0) {
      colorError(`Outils manquants dans ${serverName}:`);
      missingTools.forEach(tool => {
        colorError(`  • ${tool}`);
      });
      return false;
    }
    
    return true;
  } catch (error) {
    colorError(`Erreur vérification outils ${serverName}: ${error.message}`);
    return false;
  }
}

async function runJestTests(workspacePath) {
  colorInfo(`Exécution des tests Jest anti-régression...`);
  
  const quickfilesPath = join(workspacePath, MCP_SERVERS_PATH, 'quickfiles-server');
  
  try {
    const { spawn } = await import('child_process');
    
    return new Promise((resolve, reject) => {
      const testProcess = spawn('npm', ['test', '--', '--testPathPattern=anti-regression.test.js'], {
        cwd: quickfilesPath,
        stdio: 'pipe',
        shell: true
      });
      
      let stdout = '';
      let stderr = '';
      
      testProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      testProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      testProcess.on('close', (code) => {
        if (code === 0) {
          colorSuccess('Tests Jest réussis');
          resolve(true);
        } else {
          colorError(`Tests Jest échoués (code: ${code})`);
          if (stderr) {
            colorError(stderr);
          }
          resolve(false);
        }
      });
      
      testProcess.on('error', (error) => {
        colorError(`Erreur exécution tests: ${error.message}`);
        reject(error);
      });
    });
  } catch (error) {
    colorError(`Erreur lancement tests: ${error.message}`);
    return false;
  }
}

function main() {
  colorLog('🔍 PRE-COMMIT HOOK - DÉTECTION AUTOMATIQUE DES STUBS', 'cyan');
  colorLog('================================================', 'cyan');
  
  const workspacePath = getWorkspacePath();
  colorInfo(`Espace de travail: ${workspacePath}`);
  
  const mcpServersPath = join(workspacePath, MCP_SERVERS_PATH);
  
  if (!existsSync(mcpServersPath)) {
    colorError(`Répertoire MCP servers manquant: ${mcpServersPath}`);
    process.exit(1);
  }
  
  // Analyser tous les serveurs MCP critiques
  const servers = ['quickfiles-server'];
  let totalCriticalIssues = 0;
  let allServersValid = true;
  
  for (const serverName of servers) {
    const serverPath = join(mcpServersPath, serverName);
    
    if (existsSync(serverPath)) {
      // 1. Vérifier les outils critiques
      const hasAllTools = checkCriticalTools(serverPath, serverName);
      if (!hasAllTools) {
        allServersValid = false;
        continue;
      }
      
      // 2. Analyser le code source
      const analysis = analyzeMcpServer(serverPath, serverName);
      
      if (analysis.hasCriticalIssues) {
        totalCriticalIssues += analysis.criticalIssues;
        allServersValid = false;
        
        colorError(`\n🚨 PROBLÈMES CRITIQUES DÉTECTÉS DANS ${serverName.toUpperCase()}:`);
        analysis.issues.forEach(issue => {
          colorError(`  Ligne ${issue.line}: ${issue.content}`);
          colorError(`    Pattern: ${issue.pattern}`);
          colorError(`    Type: ${issue.type}`);
        });
      } else {
        colorSuccess(`✅ ${serverName}: Aucun problème critique détecté`);
      }
    } else {
      colorWarning(`⚠️  Serveur ${serverName} non trouvé: ${serverPath}`);
    }
  }
  
  // 3. Exécuter les tests Jest si demandé
  const runTests = process.argv.includes('--test');
  if (runTests) {
    const testsPassed = runJestTests(workspacePath);
    if (!testsPassed) {
      totalCriticalIssues++;
      allServersValid = false;
    }
  }
  
  // 4. Résultat final
  colorLog('\n📋 RÉSUMÉ DE L\'ANALYSE:', 'cyan');
  colorLog('================================', 'cyan');
  
  if (allServersValid && totalCriticalIssues === 0) {
    colorSuccess('✅ Aucun stub détecté - Commit autorisé');
    colorSuccess('🎉 Tous les serveurs MCP sont valides');
    process.exit(0);
  } else {
    colorError(`❌ ${totalCriticalIssues} problème(s) critique(s) détecté(s)`);
    colorError('🚫 COMMIT BLOQUÉ - Corrigez les problèmes avant de committer');
    
    colorLog('\n🔧 ACTIONS RECOMMANDÉES:', 'yellow');
    colorLog('=============================', 'yellow');
    colorLog('1. Implémenter les fonctions manquantes', 'white');
    colorLog('2. Remplacer les stubs par du code fonctionnel', 'white');
    colorLog('3. Exécuter: npm run test:anti-regression', 'white');
    colorLog('4. Valider avec: node scripts/pre-commit-hook.js --test', 'white');
    
    process.exit(1);
  }
}

// Gestion des erreurs non capturées
process.on('uncaughtException', (error) => {
  colorError(`Erreur non capturée: ${error.message}`);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  colorError(`Promesse rejetée non gérée: ${reason}`);
  process.exit(1);
});

// Exécuter le programme principal
if (import.meta.url) {
  main();
} else {
  colorError('Ce script doit être exécuté avec ES modules');
  process.exit(1);
}