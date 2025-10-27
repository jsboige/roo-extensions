/**
 * TestLogger - Utilitaire de logging pour tests RooSync
 * 
 * Usage:
 * ```typescript
 * import { TestLogger } from './helpers/test-logger';
 * 
 * const logger = new TestLogger('./tests/results/roosync/my-test.log');
 * logger.section('Test Section');
 * logger.log('Test message');
 * ```
 */

import * as fs from 'fs';

export class TestLogger {
  private logFile: string;

  constructor(logFile: string) {
    this.logFile = logFile;
    // Créer répertoire parent si inexistant
    const logDir = logFile.substring(0, logFile.lastIndexOf('/'));
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
    // Reset log file
    fs.writeFileSync(this.logFile, '');
  }

  /**
   * Log un message avec timestamp
   */
  log(message: string): void {
    const timestamp = new Date().toISOString();
    const logLine = `[${timestamp}] ${message}\n`;
    console.log(message);
    fs.appendFileSync(this.logFile, logLine);
  }

  /**
   * Log une section avec séparateur
   */
  section(title: string): void {
    const separator = '='.repeat(80);
    this.log(`\n${separator}`);
    this.log(title);
    this.log(separator);
  }

  /**
   * Log un test avec statut
   */
  test(testName: string, success: boolean, details: string): void {
    const status = success ? '✅ PASS' : '❌ FAIL';
    this.log(`\n🧪 ${testName}: ${status}`);
    this.log(`   ${details}`);
  }

  /**
   * Log un résultat de test avec observations
   */
  result(result: { testName: string; success: boolean; details: string; observations?: string[] }): void {
    this.test(result.testName, result.success, result.details);
    if (result.observations && result.observations.length > 0) {
      this.log('   Observations:');
      result.observations.forEach((obs) => this.log(`     - ${obs}`));
    }
  }

  /**
   * Récupère le chemin du fichier log
   */
  getLogFile(): string {
    return this.logFile;
  }
}

/**
 * Interface pour les résultats de tests
 */
export interface TestResult {
  testName: string;
  success: boolean;
  details: string;
  observations?: string[];
}

/**
 * Génère un rapport JSON de tests
 */
export function generateTestReport(
  results: TestResult[],
  reportPath: string
): void {
  const report = {
    timestamp: new Date().toISOString(),
    testsRun: results.length,
    testsPassed: results.filter((r) => r.success).length,
    testsFailed: results.filter((r) => !r.success).length,
    successRate: Math.round((results.filter((r) => r.success).length / results.length) * 100),
    results: results,
  };

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), 'utf8');
  console.log(`\n📊 Rapport généré: ${reportPath}`);
}