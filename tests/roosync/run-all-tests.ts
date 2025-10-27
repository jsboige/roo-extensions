/**
 * RooSync All Tests Runner - Phase 3
 * 
 * Exécute les 4 batteries de tests unitaires en mode dry-run :
 * - Test 1 : Logger Rotation
 * - Test 2 : Git Helpers
 * - Test 3 : Deployment Wrappers
 * - Test 4 : Task Scheduler (PowerShell)
 * 
 * Usage :
 *   npx ts-node tests/roosync/run-all-tests.ts
 *   npx ts-node tests/roosync/run-all-tests.ts --verbose
 */

import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { TestLogger, generateTestReport, TestResult } from './helpers/test-logger';

// ============================================================================
// CONFIGURATION
// ============================================================================

const RESULTS_DIR = './tests/results/roosync';
const RUNNER_LOG_FILE = path.join(RESULTS_DIR, 'run-all-tests.log');
const CONSOLIDATED_REPORT = path.join(RESULTS_DIR, 'all-tests-report.json');

const logger = new TestLogger(RUNNER_LOG_FILE);

// Tests à exécuter (ordre séquentiel)
const TESTS = [
  {
    name: 'Test 1 - Logger Rotation',
    command: 'npx ts-node tests/roosync/test-logger-rotation-dryrun.ts',
    reportPath: 'tests/results/roosync/logger-test-logs/test-report.json',
  },
  {
    name: 'Test 2 - Git Helpers',
    command: 'npx ts-node tests/roosync/test-git-helpers-dryrun.ts',
    reportPath: 'tests/results/roosync/test2-git-helpers-report.json',
  },
  {
    name: 'Test 3 - Deployment Wrappers',
    command: 'npx ts-node tests/roosync/test-deployment-wrappers-dryrun.ts',
    reportPath: 'tests/results/roosync/test3-deployment-report.json',
  },
  {
    name: 'Test 4 - Task Scheduler',
    command: 'pwsh -File tests/roosync/test-task-scheduler-dryrun.ps1',
    reportPath: null, // Pas de JSON généré (PowerShell)
  },
];

// ============================================================================
// EXÉCUTION TESTS
// ============================================================================

interface TestBatteryResult {
  testName: string;
  success: boolean;
  details: string;
  testsRun?: number;
  testsPassed?: number;
  testsFailed?: number;
  successRate?: number;
}

async function runTestBattery(test: typeof TESTS[0]): Promise<TestBatteryResult> {
  logger.section(`Exécution : ${test.name}`);
  logger.log(`Commande : ${test.command}`);

  try {
    // Exécuter test
    const startTime = Date.now();
    const output = execSync(test.command, {
      encoding: 'utf-8',
      stdio: 'pipe',
    });
    const duration = Date.now() - startTime;

    logger.log(`✅ Test terminé en ${duration}ms`);
    logger.log(`Output:\n${output}`);

    // Lire rapport si disponible
    if (test.reportPath && fs.existsSync(test.reportPath)) {
      const report = JSON.parse(fs.readFileSync(test.reportPath, 'utf-8'));
      logger.log(`📊 Rapport : ${report.testsPassed}/${report.testsRun} tests PASS (${report.successRate}%)`);

      return {
        testName: test.name,
        success: report.successRate === 100,
        details: `${report.testsPassed}/${report.testsRun} tests PASS (${report.successRate}%)`,
        testsRun: report.testsRun,
        testsPassed: report.testsPassed,
        testsFailed: report.testsFailed,
        successRate: report.successRate,
      };
    } else {
      // Pas de rapport JSON (PowerShell Test 4)
      logger.log('📊 Rapport : Succès (pas de rapport JSON)');
      return {
        testName: test.name,
        success: true,
        details: 'Test exécuté avec succès (pas de rapport JSON)',
      };
    }
  } catch (error: any) {
    logger.log(`❌ Échec du test : ${error.message}`);
    return {
      testName: test.name,
      success: false,
      details: `Échec : ${error.message}`,
    };
  }
}

async function runAllTests(): Promise<void> {
  logger.section('🚀 RooSync All Tests Runner - Démarrage');
  logger.log(`Nombre de batteries : ${TESTS.length}`);
  logger.log(`Mode : DRY-RUN (aucune modification production)`);

  const results: TestBatteryResult[] = [];

  // Exécuter tests séquentiellement
  for (const test of TESTS) {
    const result = await runTestBattery(test);
    results.push(result);

    // Pause entre tests
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  // ============================================================================
  // RAPPORT CONSOLIDÉ
  // ============================================================================

  logger.section('📊 Rapport Consolidé');

  const totalBatteries = results.length;
  const batteriesSuccess = results.filter((r) => r.success).length;
  const batteriesFailed = results.filter((r) => !r.success).length;
  const overallSuccessRate = Math.round((batteriesSuccess / totalBatteries) * 100);

  // Calculer total tests individuels (si rapport JSON disponible)
  const totalIndividualTests = results.reduce((sum, r) => sum + (r.testsRun || 0), 0);
  const totalIndividualPassed = results.reduce((sum, r) => sum + (r.testsPassed || 0), 0);
  const totalIndividualFailed = results.reduce((sum, r) => sum + (r.testsFailed || 0), 0);

  logger.log(`\n═════════════════════════════════════════════════════════════════════════`);
  logger.log(`                         RÉSULTATS CONSOLIDÉS`);
  logger.log(`═════════════════════════════════════════════════════════════════════════`);
  logger.log(`\nBatteries de tests :`);
  logger.log(`  Total          : ${totalBatteries}`);
  logger.log(`  Succès         : ${batteriesSuccess}`);
  logger.log(`  Échecs         : ${batteriesFailed}`);
  logger.log(`  Taux succès    : ${overallSuccessRate}%`);

  if (totalIndividualTests > 0) {
    logger.log(`\nTests individuels :`);
    logger.log(`  Total          : ${totalIndividualTests}`);
    logger.log(`  Succès         : ${totalIndividualPassed}`);
    logger.log(`  Échecs         : ${totalIndividualFailed}`);
  }

  logger.log(`\nDétail par batterie :`);
  results.forEach((r, idx) => {
    const status = r.success ? '✅ PASS' : '❌ FAIL';
    logger.log(`  ${idx + 1}. ${r.testName}: ${status}`);
    logger.log(`     ${r.details}`);
  });

  logger.log(`\n═════════════════════════════════════════════════════════════════════════`);

  // Sauvegarder rapport consolidé JSON
  const consolidatedReport = {
    timestamp: new Date().toISOString(),
    batteriesRun: totalBatteries,
    batteriesSuccess,
    batteriesFailed,
    overallSuccessRate,
    individualTests: {
      total: totalIndividualTests,
      passed: totalIndividualPassed,
      failed: totalIndividualFailed,
    },
    results,
  };

  fs.writeFileSync(CONSOLIDATED_REPORT, JSON.stringify(consolidatedReport, null, 2), 'utf8');
  logger.log(`\n✅ Rapport consolidé sauvegardé : ${CONSOLIDATED_REPORT}`);

  // Statut final
  if (overallSuccessRate === 100) {
    logger.log(`\n🎉 SUCCÈS : Tous les tests ont réussi !`);
    process.exit(0);
  } else {
    logger.log(`\n⚠️ ÉCHEC : ${batteriesFailed} batterie(s) ont échoué`);
    process.exit(1);
  }
}

// ============================================================================
// EXÉCUTION
// ============================================================================

runAllTests().catch((error) => {
  logger.log(`\n❌ ERREUR FATALE : ${error.message}`);
  process.exit(1);
});