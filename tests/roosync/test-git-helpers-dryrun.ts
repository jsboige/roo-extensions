/**
 * TEST 2 - Phase 3 Production Dry-Run : Git Helpers
 * 
 * Objectif : Valider verifyGitAvailable(), safePull(), safeCheckout() en mode dry-run
 * 
 * Tests :
 * - 2.1 : verifyGitAvailable() avec Git présent/absent
 * - 2.2 : safePull() avec mock (succès/échec + rollback)
 * - 2.3 : safeCheckout() avec mock (succès/échec + rollback)
 * 
 * CONTRAINTES :
 * - Mode DRY-RUN uniquement (pas de modifications repo Git)
 * - Mocks pour opérations Git dangereuses
 * - Logs isolés dans tests/results/roosync/
 */

import { TestLogger, TestResult, generateTestReport } from './helpers/test-logger';
import { mockVerifyGitAvailable, mockSafePull, mockSafeCheckout } from './helpers/test-git';

// ============================================================================
// CONFIGURATION
// ============================================================================

const TEST_LOG_FILE = './tests/results/roosync/test2-git-helpers-output.log';
const TEST_REPORT_FILE = './tests/results/roosync/test2-git-helpers-report.json';

const logger = new TestLogger(TEST_LOG_FILE);
const testResults: TestResult[] = [];

// ============================================================================
// TESTS
// ============================================================================

/**
 * Test 2.1 : verifyGitAvailable() avec Git présent
 */
function test21_VerifyGitAvailable(): TestResult {
  logger.section('🧪 Test 2.1 : verifyGitAvailable() - Git Présent');

  const result = mockVerifyGitAvailable(logger);

  const success = result.available && result.version !== null;
  const observations: string[] = [
    `Git disponible : ${result.available}`,
    `Version : ${result.version}`,
    `Cache utilisé : ${result.cached}`,
  ];

  if (success) {
    observations.push('✅ Git détecté dans PATH');
  } else {
    observations.push('❌ Git NON détecté dans PATH');
  }

  logger.log(`Résultat : ${success ? '✅ SUCCÈS' : '❌ ÉCHEC'}`);
  observations.forEach((obs) => logger.log(`  - ${obs}`));

  return {
    testName: 'verifyGitAvailable() - Git Présent',
    success,
    details: `Git ${result.available ? 'détecté' : 'non détecté'} - ${result.version || 'N/A'}`,
    observations,
  };
}

/**
 * Test 2.2 : safePull() avec mock succès/échec
 */
function test22_SafePull(): TestResult {
  logger.section('🧪 Test 2.2 : safePull() - Succès et Échec Mock');

  const repoPath = process.cwd(); // Repo actuel (roo-extensions)

  // Test succès
  logger.log('[Test 2.2.1] Mock safePull() SUCCÈS...');
  const resultSuccess = mockSafePull(repoPath, 'success', logger);

  // Test échec + rollback
  logger.log('[Test 2.2.2] Mock safePull() ÉCHEC + Rollback...');
  const resultFailure = mockSafePull(repoPath, 'failure', logger);

  const success = 
    resultSuccess.success && 
    !resultSuccess.rolledBack && 
    !resultFailure.success && 
    resultFailure.rolledBack;

  const observations: string[] = [
    `Test succès : ${resultSuccess.success ? '✅' : '❌'}`,
    `Test échec + rollback : ${resultFailure.rolledBack ? '✅' : '❌'}`,
    `SHA avant pull (succès) : ${resultSuccess.shaBeforePull}`,
    `SHA après pull (succès) : ${resultSuccess.shaAfterPull}`,
    `SHA avant pull (échec) : ${resultFailure.shaBeforePull}`,
    `SHA après rollback (échec) : ${resultFailure.shaAfterPull}`,
    `Rollback déclenché : ${resultFailure.rolledBack}`,
  ];

  logger.log(`Résultat : ${success ? '✅ SUCCÈS' : '❌ ÉCHEC'}`);
  observations.forEach((obs) => logger.log(`  - ${obs}`));

  return {
    testName: 'safePull() - Succès et Échec Mock',
    success,
    details: `Succès: ${resultSuccess.success}, Rollback échec: ${resultFailure.rolledBack}`,
    observations,
  };
}

/**
 * Test 2.3 : safeCheckout() avec mock succès/échec
 */
function test23_SafeCheckout(): TestResult {
  logger.section('🧪 Test 2.3 : safeCheckout() - Succès et Échec Mock');

  const repoPath = process.cwd(); // Repo actuel (roo-extensions)
  const testBranch = 'main'; // Branch existante (safe)

  // Test succès
  logger.log(`[Test 2.3.1] Mock safeCheckout(${testBranch}) SUCCÈS...`);
  const resultSuccess = mockSafeCheckout(repoPath, testBranch, 'success', logger);

  // Test échec + rollback
  logger.log(`[Test 2.3.2] Mock safeCheckout(${testBranch}) ÉCHEC + Rollback...`);
  const resultFailure = mockSafeCheckout(repoPath, testBranch, 'failure', logger);

  const success = 
    resultSuccess.success && 
    !resultSuccess.rolledBack && 
    !resultFailure.success && 
    resultFailure.rolledBack;

  const observations: string[] = [
    `Test succès : ${resultSuccess.success ? '✅' : '❌'}`,
    `Test échec + rollback : ${resultFailure.rolledBack ? '✅' : '❌'}`,
    `SHA avant checkout (succès) : ${resultSuccess.shaBeforeCheckout}`,
    `SHA après checkout (succès) : ${resultSuccess.shaAfterCheckout}`,
    `SHA avant checkout (échec) : ${resultFailure.shaBeforeCheckout}`,
    `SHA après rollback (échec) : ${resultFailure.shaAfterCheckout}`,
    `Rollback déclenché : ${resultFailure.rolledBack}`,
  ];

  logger.log(`Résultat : ${success ? '✅ SUCCÈS' : '❌ ÉCHEC'}`);
  observations.forEach((obs) => logger.log(`  - ${obs}`));

  return {
    testName: 'safeCheckout() - Succès et Échec Mock',
    success,
    details: `Succès: ${resultSuccess.success}, Rollback échec: ${resultFailure.rolledBack}`,
    observations,
  };
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  logger.section('🚀 TEST 2 - Phase 3 Production Dry-Run : Git Helpers');
  logger.log('🔒 Mode: DRY-RUN (mocks uniquement, pas de modifications Git)');
  logger.log('='.repeat(80));

  try {
    testResults.push(test21_VerifyGitAvailable());
    testResults.push(test22_SafePull());
    testResults.push(test23_SafeCheckout());

    // Générer rapport consolidé
    generateTestReport(testResults, TEST_REPORT_FILE);

    logger.log('');
    logger.log('⚠️  Tests complétés. Logs conservés dans: ' + TEST_LOG_FILE);

    // Exit code basé sur succès
    const allPassed = testResults.every((r) => r.success);
    process.exit(allPassed ? 0 : 1);
  } catch (error: any) {
    logger.log(`❌ Erreur fatale: ${error.message}`);
    logger.log(error.stack);
    process.exit(1);
  }
}

main();