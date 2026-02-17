#!/usr/bin/env node

/**
 * SCRIPT DE VALIDATION COMPLÈTE DES IMPLÉMENTATIONS MCP
 * 
 * Ce script effectue une validation complète de toutes les implémentations MCP
 * afin de garantir la robustesse et prévenir les régressions.
 * 
 * Usage: node scripts/validate-mcp-implementations.js [workspace-path]
 */

import { readFileSync, existsSync, readdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Configuration
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Couleurs pour la sortie
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  magenta: '\x1b[35m'
};

function colorLog(message, color = 'white') {
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

function colorHeader(message) {
  colorLog(`🔧 ${message}`, 'cyan');
}

function getWorkspacePath() {
  const args = process.argv.slice(2);
  if (args.length > 0) {
    return args[0];
  }
  return join(__dirname, '..');
}

// Validation des fichiers critiques
function validateCriticalFiles(workspacePath) {
  colorHeader('VALIDATION DES FICHIERS CRITIQUES');
  
  const criticalFiles = [
    'mcps/internal/servers/quickfiles-server/package.json',
    'mcps/internal/servers/quickfiles-server/jest.config.js',
    'mcps/internal/servers/quickfiles-server/__tests__/anti-regression.test.js',
    'mcps/internal/servers/quickfiles-server/src/index.ts',
    'mcps/internal/servers/quickfiles-server/build/index.js'
  ];
  
  let allValid = true;
  const issues = [];
  
  criticalFiles.forEach(filePath => {
    const fullPath = join(workspacePath, filePath);
    
    if (existsSync(fullPath)) {
      try {
        const stats = readFileSync(fullPath, 'utf-8');
        
        // Validation spécifique par type de fichier
        if (filePath.includes('package.json')) {
          validatePackageJson(stats, fullPath, issues);
        } else if (filePath.includes('jest.config.js')) {
          validateJestConfig(stats, fullPath, issues);
        } else if (filePath.includes('anti-regression.test.js')) {
          validateAntiRegressionTests(stats, fullPath, issues);
        } else if (filePath.includes('src/index.ts')) {
          validateSourceCode(stats, fullPath, issues);
        } else if (filePath.includes('build/index.js')) {
          validateBuildFile(stats, fullPath, issues);
        }
        
        colorSuccess(`✅ ${filePath}`);
      } catch (error) {
        colorError(`❌ ${filePath}: ${error.message}`);
        issues.push({ file: filePath, error: error.message });
        allValid = false;
      }
    } else {
      colorError(`❌ ${filePath}: FICHIER MANQUANT`);
      issues.push({ file: filePath, error: 'Fichier manquant' });
      allValid = false;
    }
  });
  
  return { allValid, issues };
}

function validatePackageJson(content, filePath, issues) {
  try {
    const pkg = JSON.parse(content);
    
    // Vérifier les scripts critiques
    const criticalScripts = ['test:anti-regression', 'validate', 'precommit'];
    criticalScripts.forEach(script => {
      if (!pkg.scripts || !pkg.scripts[script]) {
        issues.push({ file: filePath, error: `Script manquant: ${script}` });
      }
    });
    
    // Vérifier les dépendances critiques
    const criticalDeps = ['@modelcontextprotocol/sdk', 'jest', 'typescript'];
    criticalDeps.forEach(dep => {
      if (!pkg.dependencies || !pkg.dependencies[dep]) {
        issues.push({ file: filePath, error: `Dépendance manquante: ${dep}` });
      }
    });
    
  } catch (error) {
    issues.push({ file: filePath, error: `JSON invalide: ${error.message}` });
  }
}

function validateJestConfig(content, filePath, issues) {
  // Vérifier la présence des configurations critiques
  const criticalConfigs = [
    'testMatch',
    'coverageThreshold',
    'setupFilesAfterEnv',
    'globalSetup',
    'globalTeardown'
  ];
  
  criticalConfigs.forEach(config => {
    if (!content.includes(config)) {
      issues.push({ file: filePath, error: `Configuration Jest manquante: ${config}` });
    }
  });
  
  // Vérifier les seuils de couverture
  if (content.includes('coverageThreshold')) {
    const hasGoodThresholds = content.includes('branches: 70') && 
                           content.includes('functions: 80') && 
                           content.includes('lines: 80') && 
                           content.includes('statements: 80');
    
    if (!hasGoodThresholds) {
      issues.push({ file: filePath, error: 'Seuils de couverture inadéquats' });
    }
  }
}

function validateAntiRegressionTests(content, filePath, issues) {
  // Vérifier la présence des tests critiques
  const criticalTests = [
    'handleDeleteFiles',
    'handleEditMultipleFiles',
    'handleCopyFiles',
    'handleMoveFiles',
    'handleSearchInFiles',
    'handleSearchAndReplace'
  ];
  
  criticalTests.forEach(test => {
    if (!content.includes(test)) {
      issues.push({ file: filePath, error: `Test manquant: ${test}` });
    }
  });
  
  // Vérifier les patterns anti-stubs
  const stubPatterns = ['Not implemented', 'TODO: implement', 'stub'];
  stubPatterns.forEach(pattern => {
    if (content.includes(pattern)) {
      issues.push({ file: filePath, error: `Pattern de stub détecté: ${pattern}` });
    }
  });
}

function validateSourceCode(content, filePath, issues) {
  // Vérifier l'implémentation des 8 outils critiques
  const criticalTools = [
    'handleReadMultipleFiles',
    'handleListDirectoryContents',
    'handleDeleteFiles',
    'handleEditMultipleFiles',
    'handleExtractMarkdownStructure',
    'handleCopyFiles',
    'handleMoveFiles',
    'handleSearchInFiles',
    'handleSearchAndReplace',
    'handleRestartMcpServers'
  ];
  
  criticalTools.forEach(tool => {
    if (!content.includes(tool)) {
      issues.push({ file: filePath, error: `Outil manquant: ${tool}` });
    }
  });
  
  // Vérifier l'absence de patterns de stubs
  const stubPatterns = ['Not implemented', 'TODO: implement', 'STUB'];
  let stubCount = 0;
  
  stubPatterns.forEach(pattern => {
    const matches = (content.match(new RegExp(pattern, 'g')) || []).length;
    stubCount += matches;
  });
  
  if (stubCount > 0) {
    issues.push({ file: filePath, error: `${stubCount} pattern(s) de stub détecté(s)` });
  }
}

function validateBuildFile(content, filePath, issues) {
  // Vérifier que le build est récent
  try {
    const stats = readFileSync(filePath.replace('build/index.js', 'package.json'), 'utf-8');
    const pkg = JSON.parse(stats);
    const buildTime = new Date();
    const pkgTime = new Date(pkg.buildTime || '1970-01-01');
    
    if (buildTime < pkgTime) {
      issues.push({ file: filePath, error: 'Build obsolète' });
    }
  } catch (error) {
    // Ignorer l'erreur si le package.json n'existe pas
  }
}

// Validation des scripts de support
function validateSupportScripts(workspacePath) {
  colorHeader('VALIDATION DES SCRIPTS DE SUPPORT');
  
  const supportScripts = [
    'scripts/mcp-monitor.ps1',
    'scripts/pre-commit-hook.js',
    'scripts/setup-git-hooks.js',
    'scripts/validate-mcp-implementations.js'
  ];
  
  let allValid = true;
  const issues = [];
  
  supportScripts.forEach(script => {
    const fullPath = join(workspacePath, script);
    
    if (existsSync(fullPath)) {
      try {
        const content = readFileSync(fullPath, 'utf-8');
        
        // Validation basique
        if (content.length < 100) {
          issues.push({ file: script, error: 'Script trop court' });
        }
        
        if (!content.includes('function') && !content.includes('=>')) {
          issues.push({ file: script, error: 'Script invalide' });
        }
        
        colorSuccess(`✅ ${script}`);
      } catch (error) {
        colorError(`❌ ${script}: ${error.message}`);
        issues.push({ file: script, error: error.message });
        allValid = false;
      }
    } else {
      colorError(`❌ ${script}: MANQUANT`);
      issues.push({ file: script, error: 'Script manquant' });
      allValid = false;
    }
  });
  
  return { allValid, issues };
}

// Validation des tests
async function runTests(workspacePath) {
  colorHeader('EXÉCUTION DES TESTS');
  
  const quickfilesPath = join(workspacePath, 'mcps/internal/servers/quickfiles-server');
  
  if (!existsSync(quickfilesPath)) {
    colorError('❌ quickfiles-server non trouvé');
    return false;
  }
  
  try {
    const { spawn } = await import('child_process');
    
    return new Promise((resolve, reject) => {
      colorInfo('Exécution des tests Jest...');
      
      const testProcess = spawn('npm', ['test'], {
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
          colorSuccess('✅ Tests Jest réussis');
          resolve(true);
        } else {
          colorError(`❌ Tests Jest échoués (code: ${code})`);
          if (stderr) {
            console.error(stderr);
          }
          resolve(false);
        }
      });
      
      testProcess.on('error', (error) => {
        colorError(`❌ Erreur exécution tests: ${error.message}`);
        reject(error);
      });
    });
  } catch (error) {
    colorError(`❌ Erreur lancement tests: ${error.message}`);
    return false;
  }
}

// Fonction principale
async function main() {
  colorLog('🔍 VALIDATION COMPLÈTE DES IMPLÉMENTATIONS MCP', 'cyan');
  colorLog('================================================', 'cyan');
  
  const workspacePath = getWorkspacePath();
  colorInfo(`Espace de travail: ${workspacePath}`);
  
  const allIssues = [];
  let totalIssues = 0;
  
  // 1. Validation des fichiers critiques
  const criticalValidation = validateCriticalFiles(workspacePath);
  if (!criticalValidation.allValid) {
    allIssues.push(...criticalValidation.issues);
    totalIssues += criticalValidation.issues.length;
  }
  
  // 2. Validation des scripts de support
  const supportValidation = validateSupportScripts(workspacePath);
  if (!supportValidation.allValid) {
    allIssues.push(...supportValidation.issues);
    totalIssues += supportValidation.issues.length;
  }
  
  // 3. Exécution des tests
  const runTests = process.argv.includes('--test');
  if (runTests) {
    const testsPassed = await runTests(workspacePath);
    if (!testsPassed) {
      totalIssues++;
    }
  }
  
  // 4. Rapport final
  colorHeader('RAPPORT DE VALIDATION');
  colorLog('=============================', 'cyan');
  
  if (totalIssues === 0) {
    colorSuccess('🎉 AUCUN PROBLÈME DÉTECTÉ');
    colorSuccess('✅ Toutes les implémentations sont valides');
    colorSuccess('🚀 Le système MCP est prêt pour la production');
  } else {
    colorError(`❌ ${totalIssues} PROBLÈME(S) DÉTECTÉ(S)`);
    
    colorLog('\n📋 DÉTAIL DES PROBLÈMES:', 'yellow');
    allIssues.forEach((issue, index) => {
      colorLog(`${index + 1}. ${issue.file}: ${issue.error}`, 'white');
    });
    
    colorLog('\n🔧 RECOMMANDATIONS:', 'blue');
    colorLog('1. Corriger les fichiers manquants ou invalides', 'white');
    colorLog('2. Implémenter les fonctions manquantes', 'white');
    colorLog('3. Exécuter: npm run test:anti-regression', 'white');
    colorLog('4. Valider avec: node scripts/validate-mcp-implementations.js --test', 'white');
  }
  
  colorLog('\n📈 MÉTRIQUES:', 'magenta');
  colorLog(`Fichiers validés: ${criticalValidation.allValid ? 'OK' : 'ÉCHEC'}`, 'white');
  colorLog(`Scripts validés: ${supportValidation.allValid ? 'OK' : 'ÉCHEC'}`, 'white');
  colorLog(`Tests exécutés: ${runTests ? 'OUI' : 'NON'}`, 'white');
  colorLog(`Total problèmes: ${totalIssues}`, 'white');
  
  return totalIssues === 0;
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
  main().then(success => {
    process.exit(success ? 0 : 1);
  }).catch(error => {
    colorError(`Erreur fatale: ${error.message}`);
    process.exit(1);
  });
} else {
  colorError('Ce script doit être exécuté avec ES modules');
  process.exit(1);
}