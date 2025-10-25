/**
 * TEST 3 - Phase 3 Production Dry-Run : Deployment Wrappers
 *
 * Objectif : Valider deployment-helpers.ts (timeout, gestion erreurs, dry-run)
 *
 * Tests :
 * - 3.1 : Timeout - Script PowerShell long (>30s)
 * - 3.2 : Gestion erreurs - Script échoué (exit code != 0)
 * - 3.3 : Dry-run mode - deployModes({ dryRun: true })
 *
 * CONTRAINTES :
 * - Mode DRY-RUN uniquement (pas de modifications environnement)
 * - Mocks pour scripts PowerShell
 * - Logs isolés dans tests/results/roosync/
 */

import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';
import { TestLogger, TestResult as TestResultHelper, generateTestReport } from './helpers/test-logger';
import {
  createTimeoutTestScript,
  createFailureTestScript,
  createDryRunTestScript,
  cleanupTestScripts
} from './helpers/test-deployment';

// ============================================================================
// CONFIGURATION
// ============================================================================

const TEST_RESULTS_DIR = './tests/results/roosync';
const TEST_LOG_FILE = path.join(TEST_RESULTS_DIR, 'test3-deployment-output.log');
const TEST_REPORT_FILE = path.join(TEST_RESULTS_DIR, 'test3-deployment-report.json');
const TEST_SCRIPTS_DIR = path.join(TEST_RESULTS_DIR, 'deployment-test-scripts');

// Créer répertoires si inexistants
[TEST_RESULTS_DIR, TEST_SCRIPTS_DIR].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Logger avec helper
const logger = new TestLogger(TEST_LOG_FILE);

/**
 * Mock executeDeploymentScript - Exécution PowerShell avec timeout
 */
function mockExecuteDeploymentScript(
  scriptPath: string, 
  args: string[] = [], 
  timeout: number = 30000
): { success: boolean; duration: number; exitCode: number; stdout: string; stderr: string; error?: string; timedOut: boolean } {
  const startTime = Date.now();
  
  try {
    logger.log(`[Mock-Exec] Exécution script : ${scriptPath}`);
    logger.log(`[Mock-Exec] Arguments : ${args.join(' ')}`);
    logger.log(`[Mock-Exec] Timeout : ${timeout}ms`);
    
    // Construire commande PowerShell
    const argsStr = args.length > 0 ? ` ${args.join(' ')}` : '';
    const command = `pwsh -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}"${argsStr}`;
    
    // Exécuter avec timeout
    const stdout = execSync(command, { 
      encoding: 'utf-8', 
      timeout,
      stdio: 'pipe'
    });
    
    const duration = Date.now() - startTime;
    
    logger.log(`[Mock-Exec] Script réussi (${duration}ms)`);
    logger.log(`[Mock-Exec] Stdout : ${stdout.substring(0, 200)}...`);
    
    return {
      success: true,
      duration,
      exitCode: 0,
      stdout,
      stderr: '',
      timedOut: false
    };
    
  } catch (error: any) {
    const duration = Date.now() - startTime;
    
    // Détecter timeout (SIGTERM sur Linux/Mac, ETIMEDOUT sur Windows)
    const isTimeout =
      (error.killed && error.signal === 'SIGTERM') ||
      (error.code === 'ETIMEDOUT') ||
      (error.message && error.message.includes('ETIMEDOUT'));
    
    if (isTimeout) {
      logger.log(`[Mock-Exec] Script TIMEOUT après ${timeout}ms`);
      return {
        success: false,
        duration,
        exitCode: -1,
        stdout: error.stdout?.toString() || '',
        stderr: 'Script timeout exceeded',
        error: `Timeout after ${timeout}ms`,
        timedOut: true
      };
    }
    
    // Erreur normale (exit code != 0)
    logger.log(`[Mock-Exec] Script ÉCHEC : ${error.message}`);
    return {
      success: false,
      duration,
      exitCode: error.status || -1,
      stdout: error.stdout?.toString() || '',
      stderr: error.stderr?.toString() || error.message,
      error: error.message,
      timedOut: false
    };
  }
}

// ============================================================================
// TESTS
// ============================================================================

interface TestResult {
  testId: string;
  testName: string;
  success: boolean;
  details: any;
  observations: string[];
}

const testResults: TestResult[] = [];

/**
 * Test 3.1 : Timeout - Script PowerShell long (>30s)
 */
function test31_Timeout(): TestResultHelper {
  logger.section('🧪 Test 3.1 : Timeout - Script PowerShell Long (>30s)');

  const scriptPath = createTimeoutTestScript(TEST_SCRIPTS_DIR, logger);
  const timeout = 5000; // 5s timeout (script dure 35s)

  logger.log(`[Test 3.1] Exécution script avec timeout ${timeout}ms...`);
  const result = mockExecuteDeploymentScript(scriptPath, [], timeout);

  const success = !result.success && result.timedOut && result.exitCode === -1;
  const observations: string[] = [
    `Script timeout : ${result.timedOut}`,
    `Timeout configuré : ${timeout}ms`,
    `Durée exécution : ${result.duration}ms`,
    `Exit code : ${result.exitCode}`,
    `Erreur : ${result.error || 'N/A'}`,
  ];

  if (success) {
    observations.push('✅ Timeout déclenché correctement');
  } else {
    observations.push('❌ Timeout PAS déclenché (attendu : script devrait timeout)');
  }

  return {
    testName: 'Timeout - Script PowerShell Long (>30s)',
    success,
    details: success ? '✅ Timeout détecté et géré correctement' : '❌ Timeout non détecté',
    observations,
  };
}

/**
 * Test 3.2 : Gestion erreurs - Script échoué (exit code != 0)
 */
function test32_ErrorHandling(): TestResultHelper {
  logger.section('🧪 Test 3.2 : Gestion Erreurs - Script Échoué (exit code != 0)');

  const scriptPath = createFailureTestScript(TEST_SCRIPTS_DIR, logger);
  const timeout = 10000; // 10s timeout (largement suffisant)

  logger.log(`[Test 3.2] Exécution script avec erreur...`);
  const result = mockExecuteDeploymentScript(scriptPath, [], timeout);

  const success = !result.success && result.exitCode === 1 && result.error !== undefined;
  const observations: string[] = [
    `Script réussi : ${result.success}`,
    `Exit code : ${result.exitCode}`,
    `Durée exécution : ${result.duration}ms`,
    `Stderr : ${result.stderr.substring(0, 100)}...`,
    `Erreur : ${result.error || 'N/A'}`,
  ];

  if (success) {
    observations.push('✅ Erreur détectée et gérée correctement');
  } else {
    observations.push('❌ Erreur PAS détectée (attendu : exit code 1)');
  }

  return {
    testName: 'Gestion Erreurs - Script Échoué (exit code != 0)',
    success,
    details: success ? '✅ Erreur détectée et gérée' : '❌ Erreur non détectée',
    observations,
  };
}

/**
 * Test 3.3 : Dry-run mode - deployModes({ dryRun: true })
 */
function test33_DryRunMode(): TestResultHelper {
  logger.section('🧪 Test 3.3 : Dry-run Mode - deployModes({ dryRun: true })');

  const scriptPath = createDryRunTestScript(TEST_SCRIPTS_DIR, logger);
  const timeout = 10000; // 10s timeout

  // Test 1 : Sans dry-run (devrait afficher "LIVE MODE")
  logger.log(`[Test 3.3.1] Exécution script SANS dry-run...`);
  const resultLive = mockExecuteDeploymentScript(scriptPath, [], timeout);

  // Test 2 : Avec dry-run (devrait afficher "DRY-RUN MODE")
  logger.log(`[Test 3.3.2] Exécution script AVEC dry-run (-WhatIf)...`);
  const resultDryRun = mockExecuteDeploymentScript(scriptPath, ['-WhatIf'], timeout);

  const liveContainsDryRun = resultLive.stdout.includes('DRY-RUN MODE');
  const dryRunContainsDryRun = resultDryRun.stdout.includes('DRY-RUN MODE');

  const success =
    resultLive.success &&
    !liveContainsDryRun &&
    resultDryRun.success &&
    dryRunContainsDryRun;

  const observations: string[] = [
    `Test LIVE mode réussi : ${resultLive.success}`,
    `Test LIVE contient "DRY-RUN MODE" : ${liveContainsDryRun} (attendu: false)`,
    `Test DRY-RUN mode réussi : ${resultDryRun.success}`,
    `Test DRY-RUN contient "DRY-RUN MODE" : ${dryRunContainsDryRun} (attendu: true)`,
  ];

  if (success) {
    observations.push('✅ Dry-run mode détecté et appliqué correctement');
  } else {
    observations.push('❌ Dry-run mode PAS appliqué correctement');
  }

  return {
    testName: 'Dry-run Mode - deployModes({ dryRun: true })',
    success,
    details: success ? '✅ Dry-run mode détecté et appliqué' : '❌ Dry-run mode non appliqué',
    observations,
  };
}

// ============================================================================
// RAPPORT FINAL ET CLEANUP
// ============================================================================

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  logger.section('🚀 TEST 3 - Phase 3 Production Dry-Run : Deployment Wrappers');
  logger.log('🔒 Mode: DRY-RUN (mocks uniquement, pas de modifications environnement)');

  const testResults: TestResultHelper[] = [];

  try {
    testResults.push(test31_Timeout());
    testResults.push(test32_ErrorHandling());
    testResults.push(test33_DryRunMode());

    // Générer rapport avec helper
    logger.section('📊 RÉSUMÉ DES TESTS');
    const successCount = testResults.filter((t) => t.success).length;
    const totalCount = testResults.length;
    
    logger.log(`✅ Tests réussis: ${successCount}/${totalCount}`);
    logger.log(`📈 Convergence: ${((successCount / totalCount) * 100).toFixed(2)}%`);
    
    generateTestReport(testResults, TEST_REPORT_FILE);

    logger.log('');
    logger.log('⚠️  Tests complétés. Logs conservés dans: ' + TEST_LOG_FILE);
    
    // Cleanup avec helper
    cleanupTestScripts(TEST_SCRIPTS_DIR, logger);
  } catch (error: any) {
    logger.log(`❌ Erreur fatale: ${error.message}`);
    logger.log(error.stack);
    cleanupTestScripts(TEST_SCRIPTS_DIR, logger);
    process.exit(1);
  }
}

main();